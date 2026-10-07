#include <pipewire/pipewire.h>
#include <spa/param/audio/format-utils.h>
#include <spa/utils/result.h>

#include <algorithm>
#include <array>
#include <atomic>
#include <cerrno>
#include <cmath>
#include <csignal>
#include <cstdint>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

#include <fcntl.h>
#include <poll.h>
#include <sys/eventfd.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

namespace {

constexpr std::size_t kBandCount = 96;
constexpr float kLowHz = 20.0F;
constexpr float kHighHz = 20000.0F;
constexpr float kFloorDb = -72.0F;
constexpr float kAttackSeconds = 0.004F;
constexpr float kReleaseSeconds = 0.045F;
constexpr float kRmsSeconds = 0.030F;
constexpr unsigned kPublishHz = 120;

struct Biquad {
    float b0 = 0.0F;
    float b1 = 0.0F;
    float b2 = 0.0F;
    float a1 = 0.0F;
    float a2 = 0.0F;
    float z1 = 0.0F;
    float z2 = 0.0F;

    void configure(float sampleRate, float frequency, float q) {
        constexpr float pi = 3.14159265358979323846F;
        const float omega = 2.0F * pi * frequency / sampleRate;
        const float sinOmega = std::sin(omega);
        const float cosOmega = std::cos(omega);
        const float alpha = sinOmega / (2.0F * q);
        const float a0 = 1.0F + alpha;

        b0 = alpha / a0;
        b1 = 0.0F;
        b2 = -alpha / a0;
        a1 = (-2.0F * cosOmega) / a0;
        a2 = (1.0F - alpha) / a0;
        z1 = 0.0F;
        z2 = 0.0F;
    }

    float process(float input) {
        const float output = b0 * input + z1;
        z1 = b1 * input - a1 * output + z2;
        z2 = b2 * input - a2 * output;
        return output;
    }
};

class Analyzer {
  public:
    explicit Analyzer(int eventFd) : eventFd_(eventFd) {
        for (auto &value : publishedBands_)
            value.store(0.0F, std::memory_order_relaxed);
    }

    void setClientCount(std::size_t clients) {
        clientCount_.store(clients, std::memory_order_relaxed);
    }

    void configure(uint32_t sampleRate, uint32_t channels) {
        if (sampleRate == 0 || channels == 0)
            return;

        sampleRate_ = sampleRate;
        channels_ = channels;

        const float ratio = std::pow(kHighHz / kLowHz, 1.0F / static_cast<float>(kBandCount - 1));
        const float sqrtRatio = std::sqrt(ratio);
        const float q = 1.0F / (sqrtRatio - 1.0F / sqrtRatio);

        float frequency = kLowHz;
        for (std::size_t i = 0; i < kBandCount; ++i) {
            centers_[i] = frequency;
            filters_[i].configure(static_cast<float>(sampleRate_), frequency, q);
            envelopes_[i] = 0.0F;
            frequency *= ratio;
        }

        attackAlpha_ = 1.0F - std::exp(-1.0F / (static_cast<float>(sampleRate_) * kAttackSeconds));
        releaseAlpha_ = 1.0F - std::exp(-1.0F / (static_cast<float>(sampleRate_) * kReleaseSeconds));
        rmsAlpha_ = 1.0F - std::exp(-1.0F / (static_cast<float>(sampleRate_) * kRmsSeconds));
        publishEveryFrames_ = std::max<uint32_t>(1, sampleRate_ / kPublishHz);
        framesSincePublish_ = 0;
        configured_.store(true, std::memory_order_release);
    }

    void process(const float *samples, std::size_t frames) {
        if (!configured_.load(std::memory_order_acquire) ||
            clientCount_.load(std::memory_order_relaxed) == 0 || channels_ == 0)
            return;

        float localPeak = peakEnvelope_;

        for (std::size_t frame = 0; frame < frames; ++frame) {
            float mono = 0.0F;
            for (uint32_t channel = 0; channel < channels_; ++channel)
                mono += samples[frame * channels_ + channel];
            mono /= static_cast<float>(channels_);

            const float absolute = std::abs(mono);
            const float peakAlpha = absolute > localPeak ? attackAlpha_ : releaseAlpha_;
            localPeak += (absolute - localPeak) * peakAlpha;
            rmsPower_ += (mono * mono - rmsPower_) * rmsAlpha_;

            for (std::size_t band = 0; band < kBandCount; ++band) {
                const float filtered = std::abs(filters_[band].process(mono));
                const float alpha = filtered > envelopes_[band] ? attackAlpha_ : releaseAlpha_;
                envelopes_[band] += (filtered - envelopes_[band]) * alpha;
            }
        }

        peakEnvelope_ = localPeak;
        framesSincePublish_ += static_cast<uint32_t>(frames);
        if (framesSincePublish_ < publishEveryFrames_)
            return;

        framesSincePublish_ %= publishEveryFrames_;
        publish();
    }

    std::array<float, kBandCount> bands() const {
        std::array<float, kBandCount> values{};
        for (std::size_t i = 0; i < kBandCount; ++i)
            values[i] = publishedBands_[i].load(std::memory_order_relaxed);
        return values;
    }

    float rms() const {
        return publishedRms_.load(std::memory_order_relaxed);
    }

    float peak() const {
        return publishedPeak_.load(std::memory_order_relaxed);
    }

    float sub() const {
        return publishedSub_.load(std::memory_order_relaxed);
    }

    float bass() const {
        return publishedBass_.load(std::memory_order_relaxed);
    }

    float mid() const {
        return publishedMid_.load(std::memory_order_relaxed);
    }

    float high() const {
        return publishedHigh_.load(std::memory_order_relaxed);
    }

    uint32_t sampleRate() const {
        return sampleRate_;
    }

    uint64_t nextSequence() {
        return sequence_.fetch_add(1, std::memory_order_relaxed) + 1;
    }

  private:
    static float normalize(float amplitude) {
        const float db = 20.0F * std::log10(std::max(amplitude, 1.0e-7F));
        return std::clamp((db - kFloorDb) / -kFloorDb, 0.0F, 1.0F);
    }

    void publish() {
        float sub = 0.0F;
        float bass = 0.0F;
        float mid = 0.0F;
        float high = 0.0F;
        unsigned subCount = 0;
        unsigned bassCount = 0;
        unsigned midCount = 0;
        unsigned highCount = 0;

        for (std::size_t i = 0; i < kBandCount; ++i) {
            const float value = normalize(envelopes_[i]);
            publishedBands_[i].store(value, std::memory_order_relaxed);

            if (centers_[i] < 60.0F) {
                sub += value;
                ++subCount;
            } else if (centers_[i] < 250.0F) {
                bass += value;
                ++bassCount;
            } else if (centers_[i] < 4000.0F) {
                mid += value;
                ++midCount;
            } else {
                high += value;
                ++highCount;
            }
        }

        publishedSub_.store(subCount ? sub / static_cast<float>(subCount) : 0.0F, std::memory_order_relaxed);
        publishedBass_.store(bassCount ? bass / static_cast<float>(bassCount) : 0.0F, std::memory_order_relaxed);
        publishedMid_.store(midCount ? mid / static_cast<float>(midCount) : 0.0F, std::memory_order_relaxed);
        publishedHigh_.store(highCount ? high / static_cast<float>(highCount) : 0.0F, std::memory_order_relaxed);
        publishedRms_.store(normalize(std::sqrt(std::max(rmsPower_, 0.0F))), std::memory_order_relaxed);
        publishedPeak_.store(normalize(peakEnvelope_), std::memory_order_relaxed);

        uint64_t one = 1;
        if (::write(eventFd_, &one, sizeof(one)) < 0 && errno != EAGAIN)
            std::cerr << "spectrum: eventfd write failed: " << std::strerror(errno) << '\n';
    }

    int eventFd_;
    std::atomic<bool> configured_{false};
    std::atomic<std::size_t> clientCount_{0};
    std::atomic<uint64_t> sequence_{0};

    uint32_t sampleRate_ = 48000;
    uint32_t channels_ = 2;
    uint32_t publishEveryFrames_ = 400;
    uint32_t framesSincePublish_ = 0;

    float attackAlpha_ = 0.0F;
    float releaseAlpha_ = 0.0F;
    float rmsAlpha_ = 0.0F;
    float rmsPower_ = 0.0F;
    float peakEnvelope_ = 0.0F;

    std::array<float, kBandCount> centers_{};
    std::array<Biquad, kBandCount> filters_{};
    std::array<float, kBandCount> envelopes_{};
    std::array<std::atomic<float>, kBandCount> publishedBands_{};

    std::atomic<float> publishedRms_{0.0F};
    std::atomic<float> publishedPeak_{0.0F};
    std::atomic<float> publishedSub_{0.0F};
    std::atomic<float> publishedBass_{0.0F};
    std::atomic<float> publishedMid_{0.0F};
    std::atomic<float> publishedHigh_{0.0F};
};

class SocketPublisher {
  public:
    SocketPublisher(Analyzer &analyzer, int eventFd, std::string socketPath)
        : analyzer_(analyzer), eventFd_(eventFd), socketPath_(std::move(socketPath)) {}

    ~SocketPublisher() {
        stop();
    }

    bool start() {
        listenFd_ = ::socket(AF_UNIX, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
        if (listenFd_ < 0) {
            std::cerr << "spectrum: socket failed: " << std::strerror(errno) << '\n';
            return false;
        }

        sockaddr_un address{};
        address.sun_family = AF_UNIX;
        if (socketPath_.size() >= sizeof(address.sun_path)) {
            std::cerr << "spectrum: socket path too long: " << socketPath_ << '\n';
            return false;
        }

        std::strncpy(address.sun_path, socketPath_.c_str(), sizeof(address.sun_path) - 1);
        ::unlink(socketPath_.c_str());

        if (::bind(listenFd_, reinterpret_cast<sockaddr *>(&address), sizeof(address)) < 0) {
            std::cerr << "spectrum: bind failed: " << std::strerror(errno) << '\n';
            return false;
        }

        if (::chmod(socketPath_.c_str(), 0600) < 0) {
            std::cerr << "spectrum: chmod failed: " << std::strerror(errno) << '\n';
            return false;
        }

        if (::listen(listenFd_, 4) < 0) {
            std::cerr << "spectrum: listen failed: " << std::strerror(errno) << '\n';
            return false;
        }

        running_.store(true, std::memory_order_release);
        thread_ = std::thread([this] { run(); });
        return true;
    }

    void stop() {
        if (!running_.exchange(false, std::memory_order_acq_rel))
            return;

        uint64_t one = 1;
        const ssize_t wakeResult = ::write(eventFd_, &one, sizeof(one));
        if (wakeResult < 0 && errno != EAGAIN)
            std::cerr << "spectrum: shutdown wake failed: " << std::strerror(errno) << '\n';

        if (thread_.joinable())
            thread_.join();

        for (int client : clients_)
            ::close(client);
        clients_.clear();

        if (listenFd_ >= 0) {
            ::close(listenFd_);
            listenFd_ = -1;
        }

        ::unlink(socketPath_.c_str());
        analyzer_.setClientCount(0);
    }

  private:
    std::string frame() {
        const auto bands = analyzer_.bands();

        std::ostringstream output;
        output << std::fixed << std::setprecision(4);
        output << "{\"seq\":" << analyzer_.nextSequence();
        output << ",\"rate\":" << analyzer_.sampleRate();
        output << ",\"lowHz\":20,\"highHz\":20000";
        output << ",\"rms\":" << analyzer_.rms();
        output << ",\"peak\":" << analyzer_.peak();
        output << ",\"sub\":" << analyzer_.sub();
        output << ",\"bass\":" << analyzer_.bass();
        output << ",\"mid\":" << analyzer_.mid();
        output << ",\"high\":" << analyzer_.high();
        output << ",\"bands\":[";

        for (std::size_t i = 0; i < bands.size(); ++i) {
            if (i)
                output << ',';
            output << bands[i];
        }

        output << "]}\n";
        return output.str();
    }

    void acceptClients() {
        while (true) {
            const int client = ::accept4(listenFd_, nullptr, nullptr, SOCK_NONBLOCK | SOCK_CLOEXEC);
            if (client < 0) {
                if (errno != EAGAIN && errno != EWOULDBLOCK)
                    std::cerr << "spectrum: accept failed: " << std::strerror(errno) << '\n';
                break;
            }

            clients_.push_back(client);
        }

        analyzer_.setClientCount(clients_.size());
    }

    void publishFrame() {
        uint64_t value = 0;
        while (::read(eventFd_, &value, sizeof(value)) > 0) {
        }

        if (!running_.load(std::memory_order_acquire) || clients_.empty())
            return;

        const std::string payload = frame();

        auto it = clients_.begin();
        while (it != clients_.end()) {
            const ssize_t written =
                ::send(*it, payload.data(), payload.size(), MSG_NOSIGNAL | MSG_DONTWAIT);

            if (written == static_cast<ssize_t>(payload.size())) {
                ++it;
                continue;
            }

            if (written < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
                ++it;
                continue;
            }

            ::close(*it);
            it = clients_.erase(it);
        }

        analyzer_.setClientCount(clients_.size());
    }

    void run() {
        while (running_.load(std::memory_order_acquire)) {
            pollfd fds[2] = {
                {listenFd_, POLLIN, 0},
                {eventFd_, POLLIN, 0},
            };

            const int result = ::poll(fds, 2, -1);
            if (result < 0) {
                if (errno == EINTR)
                    continue;
                std::cerr << "spectrum: poll failed: " << std::strerror(errno) << '\n';
                break;
            }

            if (fds[0].revents & POLLIN)
                acceptClients();
            if (fds[1].revents & POLLIN)
                publishFrame();
        }
    }

    Analyzer &analyzer_;
    int eventFd_;
    std::string socketPath_;
    int listenFd_ = -1;
    std::vector<int> clients_;
    std::atomic<bool> running_{false};
    std::thread thread_;
};

struct App {
    pw_main_loop *loop = nullptr;
    pw_stream *stream = nullptr;
    spa_hook listener{};
    Analyzer *analyzer = nullptr;
    uint32_t channels = 2;
};

pw_main_loop *gLoop = nullptr;

void handleSignal(int) {
    if (gLoop)
        pw_main_loop_quit(gLoop);
}

void onParamChanged(void *userdata, uint32_t id, const spa_pod *param) {
    auto *app = static_cast<App *>(userdata);
    if (id != SPA_PARAM_Format || param == nullptr)
        return;

    spa_audio_info_raw info{};
    if (spa_format_audio_raw_parse(param, &info) < 0)
        return;

    app->channels = info.channels;
    app->analyzer->configure(info.rate, info.channels);
    std::cerr << "spectrum: format " << info.rate << " Hz, " << info.channels << " channels\n";
}

void onProcess(void *userdata) {
    auto *app = static_cast<App *>(userdata);
    pw_buffer *buffer = pw_stream_dequeue_buffer(app->stream);
    if (!buffer)
        return;

    spa_buffer *spaBuffer = buffer->buffer;
    if (!spaBuffer || spaBuffer->n_datas == 0 || !spaBuffer->datas[0].data) {
        pw_stream_queue_buffer(app->stream, buffer);
        return;
    }

    spa_data &data = spaBuffer->datas[0];
    const auto *chunk = data.chunk;
    if (!chunk || chunk->size == 0 || app->channels == 0) {
        pw_stream_queue_buffer(app->stream, buffer);
        return;
    }

    const auto *samples =
        reinterpret_cast<const float *>(static_cast<const uint8_t *>(data.data) + chunk->offset);
    const std::size_t sampleCount = chunk->size / sizeof(float);
    const std::size_t frames = sampleCount / app->channels;

    app->analyzer->process(samples, frames);
    pw_stream_queue_buffer(app->stream, buffer);
}

const pw_stream_events kStreamEvents = [] {
    pw_stream_events events{};
    events.version = PW_VERSION_STREAM_EVENTS;
    events.param_changed = onParamChanged;
    events.process = onProcess;
    return events;
}();

} // namespace

int main() {
    const char *runtimeDir = std::getenv("XDG_RUNTIME_DIR");
    if (!runtimeDir || *runtimeDir == '\0') {
        std::cerr << "spectrum: XDG_RUNTIME_DIR is not set\n";
        return 1;
    }

    const std::string socketPath = std::string(runtimeDir) + "/linux-desktop-spectrum.sock";

    const int eventFd = ::eventfd(0, EFD_NONBLOCK | EFD_CLOEXEC);
    if (eventFd < 0) {
        std::cerr << "spectrum: eventfd failed: " << std::strerror(errno) << '\n';
        return 1;
    }

    Analyzer analyzer(eventFd);
    SocketPublisher publisher(analyzer, eventFd, socketPath);
    if (!publisher.start()) {
        ::close(eventFd);
        return 1;
    }

    pw_init(nullptr, nullptr);

    App app;
    app.loop = pw_main_loop_new(nullptr);
    if (!app.loop) {
        std::cerr << "spectrum: failed to create PipeWire main loop\n";
        publisher.stop();
        ::close(eventFd);
        pw_deinit();
        return 1;
    }

    app.analyzer = &analyzer;
    gLoop = app.loop;

    std::signal(SIGINT, handleSignal);
    std::signal(SIGTERM, handleSignal);

    pw_properties *properties = pw_properties_new(
        PW_KEY_MEDIA_TYPE, "Audio",
        PW_KEY_MEDIA_CATEGORY, "Capture",
        PW_KEY_MEDIA_ROLE, "Music",
        PW_KEY_STREAM_CAPTURE_SINK, "true",
        PW_KEY_STREAM_MONITOR, "true",
        PW_KEY_NODE_LATENCY, "128/48000",
        nullptr);

    app.stream = pw_stream_new_simple(
        pw_main_loop_get_loop(app.loop),
        "linux-desktop-spectrum",
        properties,
        &kStreamEvents,
        &app);

    if (!app.stream) {
        std::cerr << "spectrum: failed to create PipeWire stream\n";
        pw_main_loop_destroy(app.loop);
        publisher.stop();
        ::close(eventFd);
        pw_deinit();
        return 1;
    }

    uint8_t podBuffer[1024];
    spa_pod_builder builder = SPA_POD_BUILDER_INIT(podBuffer, sizeof(podBuffer));
    spa_audio_info_raw audioInfo{};
    audioInfo.format = SPA_AUDIO_FORMAT_F32;

    const spa_pod *params[1];
    params[0] = spa_format_audio_raw_build(&builder, SPA_PARAM_EnumFormat, &audioInfo);

    const int result = pw_stream_connect(
        app.stream,
        PW_DIRECTION_INPUT,
        PW_ID_ANY,
        static_cast<pw_stream_flags>(
            PW_STREAM_FLAG_AUTOCONNECT |
            PW_STREAM_FLAG_MAP_BUFFERS |
            PW_STREAM_FLAG_RT_PROCESS),
        params,
        1);

    if (result < 0) {
        std::cerr << "spectrum: stream connect failed: " << spa_strerror(result) << '\n';
        pw_stream_destroy(app.stream);
        pw_main_loop_destroy(app.loop);
        publisher.stop();
        ::close(eventFd);
        pw_deinit();
        return 1;
    }

    std::cerr << "spectrum: listening on " << socketPath << '\n';
    pw_main_loop_run(app.loop);

    gLoop = nullptr;
    pw_stream_destroy(app.stream);
    pw_main_loop_destroy(app.loop);
    publisher.stop();
    ::close(eventFd);
    pw_deinit();
    return 0;
}

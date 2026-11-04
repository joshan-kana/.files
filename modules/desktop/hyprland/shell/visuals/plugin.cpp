
#include <QElapsedTimer>
#include <QQmlExtensionPlugin>
#include <QQuickItem>
#include <QQuickWindow>
#include <QSGGeometryNode>
#include <QSGVertexColorMaterial>
#include <QVariantList>
#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <qqml.h>
#include <vector>

class VisualsPlugin final : public QQmlExtensionPlugin {
  Q_OBJECT
  Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface/1.0")
public:
  void registerTypes(const char *uri) override;
};

class SpectrumBarsItem : public QQuickItem {
  Q_OBJECT
  Q_PROPERTY(QVariantList targetBands READ targetBands WRITE setTargetBands
                 NOTIFY targetBandsChanged)
  Q_PROPERTY(QVariantList edges READ edges WRITE setEdges NOTIFY edgesChanged)
  Q_PROPERTY(
      QVariantList palette READ palette WRITE setPalette NOTIFY paletteChanged)
  Q_PROPERTY(double lowHz READ lowHz WRITE setLowHz NOTIFY lowHzChanged)
  Q_PROPERTY(double highHz READ highHz WRITE setHighHz NOTIFY highHzChanged)
  Q_PROPERTY(
      bool decaying READ decaying WRITE setDecaying NOTIFY decayingChanged)
public:
  explicit SpectrumBarsItem(QQuickItem *parent = nullptr) : QQuickItem(parent) {
    setFlag(ItemHasContents, true);
    connect(this, &QQuickItem::windowChanged, this, [this](QQuickWindow *w) {
      if (frameConnection_)
        QObject::disconnect(frameConnection_);
      if (w)
        frameConnection_ = connect(
            w, &QQuickWindow::frameSwapped, this,
            [this] {
              if (isVisible() && animating_.load(std::memory_order_relaxed))
                update();
            },
            Qt::QueuedConnection);
    });
  }
  QVariantList targetBands() const { return targetBands_; }
  QVariantList edges() const { return edges_; }
  QVariantList palette() const { return palette_; }
  double lowHz() const { return lowHz_; }
  double highHz() const { return highHz_; }
  bool decaying() const { return decaying_; }

  void setTargetBands(const QVariantList &v) {
    if (targetBands_ == v)
      return;
    targetBands_ = v;
    animating_.store(true, std::memory_order_relaxed);
    emit targetBandsChanged();
    update();
  }
  void setEdges(const QVariantList &v) {
    if (edges_ == v)
      return;
    edges_ = v;
    emit edgesChanged();
    update();
  }
  void setPalette(const QVariantList &v) {
    if (palette_ == v)
      return;
    palette_ = v;
    emit paletteChanged();
    update();
  }
  void setLowHz(double v) {
    if (lowHz_ != v) {
      lowHz_ = v;
      emit lowHzChanged();
      update();
    }
  }
  void setHighHz(double v) {
    if (highHz_ != v) {
      highHz_ = v;
      emit highHzChanged();
      update();
    }
  }
  void setDecaying(bool v) {
    if (decaying_ != v) {
      decaying_ = v;
      emit decayingChanged();
      update();
    }
  }

signals:
  void targetBandsChanged();
  void edgesChanged();
  void paletteChanged();
  void lowHzChanged();
  void highHzChanged();
  void decayingChanged();

protected:
  QSGNode *updatePaintNode(QSGNode *old, UpdatePaintNodeData *) override {
    constexpr int kSteps = 6, kCorners = 4, kSegments = kSteps * kCorners;
    const int count = std::min(int(edges_.size()) - 1, int(palette_.size()));
    const int binCount = targetBands_.size();
    if (count < 1 || binCount < 2 || width() <= 0 || height() <= 0) {
      delete old;
      return nullptr;
    }
    if (int(current_.size()) != binCount) {
      current_.resize(binCount);
      for (int i = 0; i < binCount; ++i)
        current_[i] = targetBands_[i].toFloat();
      frameClock_.start();
    }
    float delta = 1.0f / 60.0f;
    if (frameClock_.isValid()) {
      delta = std::clamp(float(frameClock_.nsecsElapsed()) / 1000000000.0f,
                         0.0f, 0.05f);
      frameClock_.restart();
    } else
      frameClock_.start();

    const float bassEnd =
        binCount * std::log(250.0f / std::max(1.0f, float(lowHz_))) /
        std::log(std::max(2.0f, float(highHz_ / std::max(1.0, lowHz_))));
    const float bassAttack = 1 - std::exp(-delta * 320);
    const float bassRelease = 1 - std::exp(-delta * 110);
    const float highAttack = 1 - std::exp(-delta * 120);
    const float highRelease = 1 - std::exp(-delta * 45);
    const float decay = decaying_ ? 1 - std::exp(-delta * 10) : 0;
    float diff = 0;
    for (int i = 0; i < binCount; ++i) {
      const float target = targetBands_[i].toFloat(), previous = current_[i];
      const float alpha = decaying_ ? decay
                          : i <= bassEnd
                              ? (target > previous ? bassAttack : bassRelease)
                              : (target > previous ? highAttack : highRelease);
      current_[i] = previous + (target - previous) * alpha;
      diff = std::max(diff, std::abs(target - current_[i]));
    }
    const bool settled = diff < 0.002f;
    if (settled) {
      for (int i = 0; i < binCount; ++i)
        current_[i] = targetBands_[i].toFloat();
    }
    animating_.store(!settled, std::memory_order_relaxed);

    auto *node = static_cast<QSGGeometryNode *>(old);
    if (!node) {
      node = new QSGGeometryNode;
      auto *g =
          new QSGGeometry(QSGGeometry::defaultAttributes_ColoredPoint2D(), 0);
      g->setDrawingMode(QSGGeometry::DrawTriangles);
      node->setGeometry(g);
      node->setFlag(QSGNode::OwnsGeometry);
      node->setMaterial(new QSGVertexColorMaterial);
      node->setFlag(QSGNode::OwnsMaterial);
    }
    std::vector<float> levels(count, 0);
    for (int i = 0; i < count; ++i) {
      const int lo =
          std::max(0, int(std::floor(edges_[i].toFloat() * (binCount - 1))));
      const int hi =
          std::min(binCount - 1,
                   int(std::ceil(edges_[i + 1].toFloat() * (binCount - 1))));
      const float peak =
          *std::max_element(current_.begin() + lo, current_.begin() + hi + 1);
      levels[i] = std::pow(std::clamp(peak, 0.0f, 1.0f), 0.88f);
    }
    const int active =
        std::count_if(levels.begin(), levels.end(),
                      [](float level) { return level > 0.003f; });
    QSGGeometry *g = node->geometry();
    g->allocate(active * kSegments * 3);
    auto *v = g->vertexDataAsColoredPoint2D();
    static const auto dirs = [] {
      std::array<std::array<float, 2>, kSegments> a{};
      for (int j = 0; j < kSegments; ++j) {
        const float angle =
            3.14159265358979323846f * (1 + 2.0f * j / kSegments);
        a[j] = {std::cos(angle), std::sin(angle)};
      }
      return a;
    }();
    const float w = float(width()), h = float(height()),
                bw = std::max(1.0f, w / count * 0.72f);
    int pos = 0;
    auto emitVertex = [&](float x, float y, const QColor &c) {
      v[pos++].set(x, y, c.red(), c.green(), c.blue(), c.alpha());
    };
    for (int i = 0; i < count; ++i) {
      const float level = levels[i];
      if (level <= 0.003f)
        continue;
      const QColor c = palette_[i].value<QColor>();
      const float bh = std::max(2.0f, level * h),
                  x = (i + 0.5f) * w / count - bw / 2.0f, y = h - bh;
      const float r = std::min({bw / 2.0f, bh / 2.0f, 3.0f});
      const std::array<std::array<float, 2>, 4> corners = {
          {{x + r, y + r},
           {x + bw - r, y + r},
           {x + bw - r, y + bh - r},
           {x + r, y + bh - r}}};
      auto point = [&](int j) {
        const auto &center = corners[(j % kSegments) / kSteps],
                   &direction = dirs[j % kSegments];
        return std::array<float, 2>{center[0] + r * direction[0],
                                    center[1] + r * direction[1]};
      };
      for (int j = 0; j < kSegments; ++j) {
        const auto a = point(j), b = point(j + 1);
        emitVertex(x + bw / 2.0f, y + bh / 2.0f, c);
        emitVertex(a[0], a[1], c);
        emitVertex(b[0], b[1], c);
      }
    }
    node->markDirty(QSGNode::DirtyGeometry);
    return node;
  }

private:
  QVariantList targetBands_, edges_, palette_;
  std::vector<float> current_;
  double lowHz_ = 20.0, highHz_ = 20000.0;
  bool decaying_ = false;
  QElapsedTimer frameClock_;
  QMetaObject::Connection frameConnection_;
  std::atomic<bool> animating_{false};
};
void VisualsPlugin::registerTypes(const char *uri) {
  qmlRegisterType<SpectrumBarsItem>(uri, 1, 0, "SpectrumBarsItem");
}
#include "plugin.moc"

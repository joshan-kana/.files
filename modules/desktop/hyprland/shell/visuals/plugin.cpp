
#include <QElapsedTimer>
#include <QQmlExtensionPlugin>
#include <QQuickItem>
#include <QQuickWindow>
#include <QSGGeometryNode>
#include <QSGVertexColorMaterial>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>
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

class SpectrumItem : public QQuickItem {
  Q_OBJECT
  QML_NAMED_ELEMENT(SpectrumItem)
  Q_PROPERTY(bool curve READ curve WRITE setCurve NOTIFY curveChanged)
  Q_PROPERTY(QVariantList targetBands READ targetBands WRITE setTargetBands
                 NOTIFY targetBandsChanged)
  Q_PROPERTY(QVariantList edges READ edges WRITE setEdges NOTIFY edgesChanged)
  Q_PROPERTY(QVariantList barColors READ barColors WRITE setBarColors NOTIFY
                 barColorsChanged)
  Q_PROPERTY(double lowHz READ lowHz WRITE setLowHz NOTIFY lowHzChanged)
  Q_PROPERTY(double highHz READ highHz WRITE setHighHz NOTIFY highHzChanged)
  Q_PROPERTY(
      bool decaying READ decaying WRITE setDecaying NOTIFY decayingChanged)
  Q_PROPERTY(double sensitivity READ sensitivity WRITE setSensitivity NOTIFY
                 sensitivityChanged)
  Q_PROPERTY(double attackMultiplier READ attackMultiplier WRITE
                 setAttackMultiplier NOTIFY attackMultiplierChanged)
  Q_PROPERTY(double releaseMultiplier READ releaseMultiplier WRITE
                 setReleaseMultiplier NOTIFY releaseMultiplierChanged)
public:
  explicit SpectrumItem(QQuickItem *parent = nullptr) : QQuickItem(parent) {
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
  bool curve() const { return curve_; }
  void setCurve(bool value) {
    if (curve_ == value)
      return;
    curve_ = value;
    emit curveChanged();
    update();
  }
  QVariantList targetBands() const { return targetBands_; }
  QVariantList edges() const { return edges_; }
  QVariantList barColors() const { return barColors_; }
  double lowHz() const { return lowHz_; }
  double highHz() const { return highHz_; }
  bool decaying() const { return decaying_; }
  double sensitivity() const { return sensitivity_; }
  double attackMultiplier() const { return attackMultiplier_; }
  double releaseMultiplier() const { return releaseMultiplier_; }

  void setTargetBands(const QVariantList &v) {
    if (targetBands_ == v)
      return;
    targetBands_ = v;
    if (v.isEmpty())
      resetPending_ = true;
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
  void setBarColors(const QVariantList &v) {
    if (barColors_ == v)
      return;
    barColors_ = v;
    emit barColorsChanged();
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

  void setSensitivity(double value) {
    if (sensitivity_ == value)
      return;
    sensitivity_ = value;
    emit sensitivityChanged();
    update();
  }
  void setAttackMultiplier(double value) {
    if (attackMultiplier_ == value)
      return;
    attackMultiplier_ = value;
    emit attackMultiplierChanged();
    update();
  }
  void setReleaseMultiplier(double value) {
    if (releaseMultiplier_ == value)
      return;
    releaseMultiplier_ = value;
    emit releaseMultiplierChanged();
    update();
  }
signals:
  void curveChanged();
  void targetBandsChanged();
  void sensitivityChanged();
  void attackMultiplierChanged();
  void releaseMultiplierChanged();
  void edgesChanged();
  void barColorsChanged();
  void lowHzChanged();
  void highHzChanged();
  void decayingChanged();

protected:
  QSGNode *updatePaintNode(QSGNode *old, UpdatePaintNodeData *) override {
    constexpr int kSteps = 6, kCorners = 4, kSegments = kSteps * kCorners;
    const int count = std::min(int(edges_.size()) - 1, int(barColors_.size()));
    const int binCount = targetBands_.size();
    if (count < 1 || binCount < 2 || width() <= 0 || height() <= 0) {
      current_.clear();
      frameClock_.invalidate();
      animating_.store(false, std::memory_order_relaxed);
      delete old;
      return nullptr;
    }
    if (resetPending_ || int(current_.size()) != binCount) {
      resetPending_ = false;
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
    const float bassAttack = 1 - std::exp(-delta * 320 * attackMultiplier_);
    const float bassRelease = 1 - std::exp(-delta * 110 * releaseMultiplier_);
    const float highAttack = 1 - std::exp(-delta * 120 * attackMultiplier_);
    const float highRelease = 1 - std::exp(-delta * 45 * releaseMultiplier_);
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
    levels_.resize(count);
    for (int i = 0; i < count; ++i) {
      const int lo =
          std::max(0, int(std::floor(edges_[i].toFloat() * (binCount - 1))));
      const int hi =
          std::min(binCount - 1,
                   int(std::ceil(edges_[i + 1].toFloat() * (binCount - 1))));
      const float peak =
          *std::max_element(current_.begin() + lo, current_.begin() + hi + 1);
      levels_[i] =
          std::pow(std::clamp(peak * float(sensitivity_), 0.0f, 1.0f), 0.88f);
    }
    if (curve_) {
      renderCurve(node, count);
      return node;
    }
    QSGGeometry *g = node->geometry();
    // Keep one fixed buffer for the entire spectrum. Counting only visible
    // bars would repeatedly reallocate this GPU-backed geometry as notes
    // start and decay, even though the number of frequency bins never moves.
    // Inactive bars use transparent, zero-area triangles instead.
    const int vertexCount = count * kSegments * 3;
    if (g->vertexCount() != vertexCount)
      g->allocate(vertexCount);
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
      const float level = levels_[i];
      const bool audible = level > 0.003f;
      const QColor c =
          audible ? barColors_[i].value<QColor>() : QColor(Qt::transparent);
      const float bh = audible ? std::max(2.0f, level * h) : 0.0f;
      const float x = (i + 0.5f) * w / count - bw / 2.0f, y = h - bh;
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
  // Both presentations use the same interpolated levels and bin boundaries.
  // Tessellate a quadratic outline into a fixed vertex buffer; the translucent
  // fill and coloured ribbon retain the former curve's visual language.
  void renderCurve(QSGGeometryNode *node, int count) {
    const int subdivisions =
        std::clamp(int(width() / std::max(1, count - 1) / 3), 6, 24);
    const int segmentCount = std::max(1, count - 1) * subdivisions;
    constexpr int verticesPerSegment = 18;
    auto *geometry = node->geometry();
    const int vertexCount = segmentCount * verticesPerSegment;
    if (geometry->vertexCount() != vertexCount)
      geometry->allocate(vertexCount);
    auto *vertices = geometry->vertexDataAsColoredPoint2D();
    const float w = float(width()), h = float(height());
    const float thickness = std::min(2.2f, h / 3);
    const float feather = std::min(0.65f, thickness / 2);
    int pos = 0;
    auto sample = [&](int index) {
      const float x = count > 1 ? float(index) * w / (count - 1) : 0;
      const float amplitude = std::max(2.0f, levels_[index] * h * 0.92f);
      return QPointF(x, std::max(0.0f, h - amplitude));
    };
    auto colorAt = [&](float x) {
      // Interpolate the same theme colours used by the bars.
      const float index =
          std::clamp(x / w * (count - 1), 0.0f, float(count - 1));
      const int left = int(index), right = std::min(count - 1, left + 1);
      const float t = index - left;
      const QColor a = barColors_[left].value<QColor>();
      const QColor b = barColors_[right].value<QColor>();
      return QColor::fromRgbF(a.redF() + (b.redF() - a.redF()) * t,
                              a.greenF() + (b.greenF() - a.greenF()) * t,
                              a.blueF() + (b.blueF() - a.blueF()) * t,
                              a.alphaF() + (b.alphaF() - a.alphaF()) * t);
    };
    auto add = [&](float x, float y, QColor color, float alpha) {
      color.setAlphaF(std::clamp(float(color.alphaF()) * alpha, 0.0f, 1.0f));
      const QRgb rgba = qPremultiply(color.rgba());
      vertices[pos++].set(x, y, qRed(rgba), qGreen(rgba), qBlue(rgba),
                          qAlpha(rgba));
    };
    auto strip = [&](QPointF a, QPointF b, float ay, float by, float topAlpha,
                     float bottomAlpha) {
      const QColor ca = colorAt(float(a.x())), cb = colorAt(float(b.x()));
      add(a.x(), a.y(), ca, topAlpha);
      add(b.x(), b.y(), cb, topAlpha);
      add(a.x(), ay, ca, bottomAlpha);
      add(a.x(), ay, ca, bottomAlpha);
      add(b.x(), b.y(), cb, topAlpha);
      add(b.x(), by, cb, bottomAlpha);
    };
    QPointF previous = sample(0);
    for (int i = 0; i < std::max(1, count - 1); ++i) {
      const QPointF start = previous;
      const bool last = i + 1 >= count - 1;
      const QPointF next = count > 1 ? sample(std::min(count - 1, i + 2))
                                     : QPointF(w, start.y());
      const QPointF control = last ? (start + next) * 0.5 : sample(i + 1);
      const QPointF end = last ? next : (control + next) * 0.5;
      for (int j = 1; j <= subdivisions; ++j) {
        const float t = float(j) / subdivisions, u = 1 - t;
        const QPointF point =
            start * (u * u) + control * (2 * u * t) + end * (t * t);
        // Fill starts below the ribbon so the stroke retains its colour.
        const QPointF fillA(previous.x(),
                            std::min(double(h), previous.y() + thickness));
        const QPointF fillB(point.x(),
                            std::min(double(h), point.y() + thickness));
        strip(fillA, fillB, h, h, 0.12f, 0.12f);
        strip(previous, point, fillA.y(), fillB.y(), 1, 1);
        const QPointF outerA(previous.x(),
                             std::max(0.0, previous.y() - feather));
        const QPointF outerB(point.x(), std::max(0.0, point.y() - feather));
        strip(outerA, outerB, previous.y(), point.y(), 0, 1);
        previous = point;
      }
    }
    node->markDirty(QSGNode::DirtyGeometry);
  }

  QVariantList targetBands_, edges_, barColors_;
  std::vector<float> current_, levels_;
  double lowHz_ = 20.0, highHz_ = 20000.0;
  bool decaying_ = false, curve_ = false, resetPending_ = false;
  double sensitivity_ = 1.0, attackMultiplier_ = 1.0, releaseMultiplier_ = 1.0;
  QElapsedTimer frameClock_;
  QMetaObject::Connection frameConnection_;
  std::atomic<bool> animating_{false};
};

// Scene-graph-owned squircle fill. Stable vertex storage replaces multiple
// dynamically tessellated ShapePaths during a morph while retaining the SVG
// contour's cubic approximation and the existing radial light treatment.
class SquircleFillItem : public QQuickItem {
  Q_OBJECT
  QML_NAMED_ELEMENT(SquircleFillItem)
  Q_PROPERTY(QColor fillColor MEMBER fillColor_ NOTIFY fillColorChanged)
  Q_PROPERTY(double fillOpacity MEMBER fillOpacity_ NOTIFY fillOpacityChanged)
  Q_PROPERTY(
      double gradientStrength MEMBER gradientStrength_ NOTIFY gradientChanged)
  Q_PROPERTY(
      QColor gradientLowColor MEMBER gradientLowColor_ NOTIFY gradientChanged)
  Q_PROPERTY(
      QColor gradientMidColor MEMBER gradientMidColor_ NOTIFY gradientChanged)
  Q_PROPERTY(
      QColor gradientHighColor MEMBER gradientHighColor_ NOTIFY gradientChanged)
  Q_PROPERTY(QColor lightColor MEMBER lightColor_ NOTIFY lightColorChanged)
  Q_PROPERTY(
      double lightStrength MEMBER lightStrength_ NOTIFY lightStrengthChanged)
  Q_PROPERTY(double lightSpread MEMBER lightSpread_ NOTIFY lightSpreadChanged)
  Q_PROPERTY(
      double cornerRadius MEMBER cornerRadius_ NOTIFY cornerRadiusChanged)
  Q_PROPERTY(double exponent MEMBER exponent_ NOTIFY exponentChanged)

public:
  explicit SquircleFillItem(QQuickItem *parent = nullptr) : QQuickItem(parent) {
    setFlag(ItemHasContents, true);
    connect(this, &SquircleFillItem::fillColorChanged, this,
            &QQuickItem::update);
    connect(this, &SquircleFillItem::fillOpacityChanged, this,
            &QQuickItem::update);
    connect(this, &SquircleFillItem::gradientChanged, this,
            &QQuickItem::update);
    connect(this, &SquircleFillItem::lightColorChanged, this,
            &QQuickItem::update);
    connect(this, &SquircleFillItem::lightStrengthChanged, this,
            &QQuickItem::update);
    connect(this, &SquircleFillItem::lightSpreadChanged, this,
            &QQuickItem::update);
    connect(this, &SquircleFillItem::cornerRadiusChanged, this,
            &QQuickItem::update);
    connect(this, &SquircleFillItem::exponentChanged, this,
            &QQuickItem::update);
  }

signals:
  void fillColorChanged();
  void fillOpacityChanged();
  void gradientChanged();
  void lightColorChanged();
  void lightStrengthChanged();
  void lightSpreadChanged();
  void cornerRadiusChanged();
  void exponentChanged();

protected:
  QSGNode *updatePaintNode(QSGNode *old, UpdatePaintNodeData *) override {
    constexpr int kCurveSteps = 12;
    const float w = float(width()), h = float(height());
    const float r =
        std::min({std::max(0.0f, float(cornerRadius_)), w / 2, h / 2});
    const float baseAlpha =
        float(fillColor_.alphaF() * std::clamp(fillOpacity_, 0.0, 1.0));
    const float lightAlpha =
        float(lightColor_.alphaF() * std::clamp(lightStrength_, 0.0, 1.0));
    if (w <= 0 || h <= 0 || r <= 0 ||
        (baseAlpha <= 0.00001f && lightAlpha <= 0.00001f)) {
      delete old;
      return nullptr;
    }

    const float power = std::clamp(float(exponent_), 2.0f, 12.0f);
    constexpr float pi = 3.14159265358979323846f;
    const float handle = r * (std::pow(2.0f, -1.0f / power) - 0.5f) / 0.375f;
    auto cornerPoint = [power, r](float cx, float cy, float angle) {
      const float c = std::cos(angle), s = std::sin(angle);
      return QPointF(
          cx + r * std::copysign(std::pow(std::abs(c), 2 / power), c),
          cy + r * std::copysign(std::pow(std::abs(s), 2 / power), s));
    };
    std::vector<QPointF> contour;
    contour.reserve(4 * (kCurveSteps + 1));
    const std::array<std::array<float, 4>, 4> corners = {{
        {w - r, r, -pi / 2, 0},
        {w - r, h - r, 0, pi / 2},
        {r, h - r, pi / 2, pi},
        {r, r, pi, pi * 1.5f},
    }};
    for (const auto &corner : corners) {
      const float cx = corner[0], cy = corner[1];
      const float start = corner[2], end = corner[3];
      const QPointF first = cornerPoint(cx, cy, start);
      const QPointF last = cornerPoint(cx, cy, end);
      const QPointF a(first.x() - handle * std::sin(start),
                      first.y() + handle * std::cos(start));
      const QPointF b(last.x() + handle * std::sin(end),
                      last.y() - handle * std::cos(end));
      if (!contour.empty() && gradientStrength_ > 0.001) {
        const QPointF previous = contour.back();
        const int subdivisions = std::max(
            1, std::min(24, int(std::ceil(std::hypot(first.x() - previous.x(),
                                                     first.y() - previous.y()) /
                                          std::max(16.0f, w / 18.0f)))));
        for (int j = 1; j < subdivisions; ++j)
          contour.push_back(previous +
                            (first - previous) * (double(j) / subdivisions));
      }
      contour.push_back(first);
      for (int j = 1; j <= kCurveSteps; ++j) {
        const float t = float(j) / kCurveSteps;
        const float u = 1 - t;
        contour.push_back(first * (u * u * u) + a * (3 * u * u * t) +
                          b * (3 * u * t * t) + last * (t * t * t));
      }
    }

    auto *node = static_cast<QSGGeometryNode *>(old);
    if (!node) {
      node = new QSGGeometryNode;
      auto *geometry =
          new QSGGeometry(QSGGeometry::defaultAttributes_ColoredPoint2D(), 0);
      geometry->setDrawingMode(QSGGeometry::DrawTriangles);
      node->setGeometry(geometry);
      node->setFlag(QSGNode::OwnsGeometry);
      node->setMaterial(new QSGVertexColorMaterial);
      node->setFlag(QSGNode::OwnsMaterial);
    }

    const int steps = lightStrength_ > 0.0001 ? 8 : 1;
    const int segments = int(contour.size());
    const int triangles = segments * (1 + (steps - 1) * 2 + 2);
    auto *geometry = node->geometry();
    if (geometry->vertexCount() != triangles * 3)
      geometry->allocate(triangles * 3);
    auto *vertices = geometry->vertexDataAsColoredPoint2D();
    int position = 0;
    const QPointF center(w * 0.5, h * 0.5);
    const float radius =
        std::max(0.001f, std::max(w * 0.9f, h * 2.0f) * float(lightSpread_));
    const QPointF lightCenter(w * 0.15, h * -0.16);
    const float gradientStrength =
        std::clamp(float(gradientStrength_), 0.0f, 1.0f);
    auto colorAt = [&](const QPointF &point) {
      float baseRed = fillColor_.redF(), baseGreen = fillColor_.greenF(),
            baseBlue = fillColor_.blueF();
      if (gradientStrength > 0.00001f) {
        const float position = std::clamp(float(point.x()) / w, 0.0f, 1.0f);
        const QColor &left =
            position < 0.5f ? gradientLowColor_ : gradientMidColor_;
        const QColor &right =
            position < 0.5f ? gradientMidColor_ : gradientHighColor_;
        const float t = position < 0.5f ? position * 2 : (position - 0.5f) * 2;
        const auto mix = [t](float a, float b) { return a + (b - a) * t; };
        baseRed +=
            (mix(left.redF(), right.redF()) - baseRed) * gradientStrength;
        baseGreen +=
            (mix(left.greenF(), right.greenF()) - baseGreen) * gradientStrength;
        baseBlue +=
            (mix(left.blueF(), right.blueF()) - baseBlue) * gradientStrength;
      }
      const double distance =
          std::hypot(point.x() - lightCenter.x(), point.y() - lightCenter.y());
      const double t = std::clamp(distance / radius, 0.0, 1.0);
      const double intensity =
          t < 0.44 ? 1 - 0.72 * t / 0.44 : 0.28 * (1 - (t - 0.44) / 0.56);
      const double lightAlpha =
          lightColor_.alphaF() * lightStrength_ * intensity;
      const double baseWeight = baseAlpha * (1 - lightAlpha);
      const double alpha = lightAlpha + baseWeight;
      if (alpha < 0.00001)
        return QColor(Qt::transparent);
      QColor color;
      color.setRgbF(
          (lightColor_.redF() * lightAlpha + baseRed * baseWeight) / alpha,
          (lightColor_.greenF() * lightAlpha + baseGreen * baseWeight) / alpha,
          (lightColor_.blueF() * lightAlpha + baseBlue * baseWeight) / alpha,
          alpha);
      return color;
    };
    auto add = [&](const QPointF &point, const QColor &color) {
      // Scene-graph vertex colours use premultiplied alpha; sending straight
      // RGB would brighten translucent surfaces over their background.
      const QRgb rgba = qPremultiply(color.rgba());
      vertices[position++].set(float(point.x()), float(point.y()), qRed(rgba),
                               qGreen(rgba), qBlue(rgba), qAlpha(rgba));
    };
    auto triangle = [&](const QPointF &a, const QPointF &b, const QPointF &c,
                        const QColor &ca, const QColor &cb, const QColor &cc) {
      add(a, ca);
      add(b, cb);
      add(c, cc);
    };

    std::vector<QPointF> inner;
    std::vector<QPointF> outer;
    inner.reserve(contour.size());
    outer.reserve(contour.size());
    for (int i = 0; i < segments; ++i) {
      const QPointF before = contour[(i + segments - 1) % segments];
      const QPointF after = contour[(i + 1) % segments];
      const QPointF tangent = after - before;
      const double length =
          std::max(0.00001, std::hypot(tangent.x(), tangent.y()));
      const QPointF normal(tangent.y() / length, -tangent.x() / length);
      inner.push_back(contour[i] - normal * 0.5);
      outer.push_back(contour[i] + normal * 0.5);
    }

    const QColor middleColor = colorAt(center);
    for (int i = 0; i < segments; ++i) {
      const int next = (i + 1) % segments;
      const QPointF edge0 = inner[i], edge1 = inner[next];
      for (int radial = 0; radial < steps; ++radial) {
        const float t0 = float(radial) / steps;
        const float t1 = float(radial + 1) / steps;
        const QPointF a = center + (edge0 - center) * t0;
        const QPointF b = center + (edge1 - center) * t0;
        const QPointF c = center + (edge0 - center) * t1;
        const QPointF d = center + (edge1 - center) * t1;
        const QColor ca = radial == 0 ? middleColor : colorAt(a);
        const QColor cb = radial == 0 ? middleColor : colorAt(b);
        const QColor cc = colorAt(c);
        const QColor cd = colorAt(d);
        if (radial == 0)
          triangle(a, c, d, ca, cc, cd);
        else {
          triangle(a, c, b, ca, cc, cb);
          triangle(b, c, d, cb, cc, cd);
        }
      }
      const QColor inside0 = colorAt(edge0), inside1 = colorAt(edge1);
      QColor outside0 = inside0, outside1 = inside1;
      outside0.setAlpha(0);
      outside1.setAlpha(0);
      triangle(edge0, outer[i], edge1, inside0, outside0, inside1);
      triangle(edge1, outer[i], outer[next], inside1, outside0, outside1);
    }
    node->markDirty(QSGNode::DirtyGeometry);
    return node;
  }

private:
  QColor fillColor_{Qt::transparent}, lightColor_{Qt::transparent};
  QColor gradientLowColor_{Qt::transparent}, gradientMidColor_{Qt::transparent},
      gradientHighColor_{Qt::transparent};
  double fillOpacity_ = 1, gradientStrength_ = 0;
  double lightStrength_ = 0, lightSpread_ = 1;
  double cornerRadius_ = 28, exponent_ = 4.5;
};

// Keep the hub's QML content tree stationary while the visible viewport
// changes. Updating the clip geometry does not move or relayout descendants.
class ContentClipItem : public QQuickItem {
  Q_OBJECT
  QML_NAMED_ELEMENT(ContentClipItem)
  Q_PROPERTY(QRectF clipBounds READ clipBounds WRITE setClipBounds NOTIFY
                 clipBoundsChanged)
public:
  explicit ContentClipItem(QQuickItem *parent = nullptr) : QQuickItem(parent) {
    setClip(true);
  }

  QRectF clipBounds() const { return bounds_; }
  QRectF clipRect() const override { return bounds_; }

  void setClipBounds(const QRectF &bounds) {
    if (bounds_ == bounds)
      return;
    bounds_ = bounds;
    // Batch the two independently animated edges into one clip update.
    polish();
    emit clipBoundsChanged();
  }

signals:
  void clipBoundsChanged();

protected:
  void updatePolish() override {
    // Qt refreshes an existing clip node on an item-size change. A width-only
    // or position-only morph must also mark it dirty without toggling clip.
    if (height() == bounds_.height())
      setHeight(bounds_.height() + 1);
    setHeight(bounds_.height());
  }

private:
  QRectF bounds_;
};

void VisualsPlugin::registerTypes(const char *uri) {
  qmlRegisterType<SpectrumItem>(uri, 1, 0, "SpectrumItem");
  qmlRegisterType<SquircleFillItem>(uri, 1, 0, "SquircleFillItem");
  qmlRegisterType<ContentClipItem>(uri, 1, 0, "ContentClipItem");
}
#include "plugin.moc"

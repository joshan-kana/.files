const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");
const src = fs.readFileSync(
  path.join(__dirname, "../modules/desktop/hyprland/shell/visuals/plugin.cpp"),
  "utf8",
);

test("native spectrum bars reuse the scene-graph vertex buffer while audio animates", () => {
  assert.match(src, /auto \*node = static_cast<QSGGeometryNode \*>\(old\)/);
  assert.match(src, /const int vertexCount = count \* kSegments \* 3;/);
  assert.match(
    src,
    /if \(g->vertexCount\(\) != vertexCount\)\s*g->allocate\(vertexCount\);/,
  );
  assert.doesNotMatch(src, /g->allocate\(active \* kSegments \* 3\)/);
  assert.match(src, /const bool audible = level > 0\.003f;/);
  assert.match(
    src,
    /audible \? barColors_\[i\]\.value<QColor>\(\) : QColor\(Qt::transparent\)/,
  );
  assert.match(
    src,
    /const float bh = audible \? std::max\(2\.0f, level \* h\) : 0\.0f/,
  );
  assert.doesNotMatch(src, /if \(level <= 0\.003f\)\s*continue;/);

  assert.match(src, /node->markDirty\(QSGNode::DirtyGeometry\)/);
});

test("native curves reuse fixed geometry and avoid QML SVG path churn", () => {
  assert.match(
    src,
    /const int vertexCount = segmentCount \* verticesPerSegment;/,
  );
  assert.match(
    src,
    /if \(geometry->vertexCount\(\) != vertexCount\)\s*geometry->allocate\(vertexCount\);/,
  );
  const wrapper = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/qml/SpectrumVisualizer.qml",
    ),
    "utf8",
  );
  assert.equal([...wrapper.matchAll(/SpectrumRenderer \{/g)].length, 3);
  assert.match(wrapper, /curve: true/);
});

test("radial spectrum reuses vertices and directions while levels change", () => {
  assert.match(src, /const int vertexCount = 2 \* count \* verticesPerBand;/);
  assert.match(
    src,
    /if \(radialDirections_\.size\(\) != size_t\(2 \* count\)\)/,
  );
  assert.match(src, /radialDirections_\[side \* count \+ i\]/);
  assert.match(src, /if \(radial_\) \{\s*renderRadial\(node, count\)/);
});

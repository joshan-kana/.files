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

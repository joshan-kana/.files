import QtQuick

AnchorAnimation {
    id: root

    enum Type {
        FastSpatial,
        DefaultSpatial,
        SlowSpatial
    }

    required property Motion motion
    property int type: AnchorAnim.DefaultSpatial

    duration: {
        switch (type) {
        case AnchorAnim.FastSpatial:
            return motion.spatialFast;
        case AnchorAnim.SlowSpatial:
            return motion.spatialSlow;
        default:
            return motion.spatialNormal;
        }
    }

    easing.type: motion.spatialType
}

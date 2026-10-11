import QtQuick

NumberAnimation {
    id: root

    enum Type {
        FastSpatial,
        DefaultSpatial,
        SlowSpatial,
        FastEffects,
        DefaultEffects,
        SlowEffects
    }

    required property Motion motion
    property int type: Anim.DefaultSpatial

    duration: {
        switch (type) {
        case Anim.FastSpatial:
            return motion.spatialFast;
        case Anim.SlowSpatial:
            return motion.spatialSlow;
        case Anim.FastEffects:
            return motion.effectsFast;
        case Anim.DefaultEffects:
            return motion.effectsNormal;
        case Anim.SlowEffects:
            return motion.effectsSlow;
        default:
            return motion.spatialNormal;
        }
    }

    easing.type: {
        switch (type) {
        case Anim.FastEffects:
        case Anim.DefaultEffects:
        case Anim.SlowEffects:
            return motion.effectsType;
        default:
            return motion.spatialType;
        }
    }

    easing.bezierCurve: {
        switch (type) {
        case Anim.FastEffects:
        case Anim.DefaultEffects:
        case Anim.SlowEffects:
            return motion.effectsCurve;
        default:
            return motion.spatialCurve;
        }
    }
}

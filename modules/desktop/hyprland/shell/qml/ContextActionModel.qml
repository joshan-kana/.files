pragma ComponentBehavior: Bound
import QtQuick
import "ContextActions.js" as ContextActions

QtObject {
    property var actions: []
    property string query: ""
    readonly property var matches: ContextActions.filtered(actions, query)
}

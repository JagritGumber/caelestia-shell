import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

ColumnLayout {
    id: root

    required property color colour
    required property int parentSpacing

    property real capsHeight: Hypr.capsLock ? capslockIcon.implicitHeight : 0
    property real numHeight: Hypr.numLock ? numlockIcon.implicitHeight : 0
    property real touchpadHeight: !Hypr.touchpadEnabled ? touchpadIcon.implicitHeight : 0
    property real numGap: Hypr.numLock && Hypr.capsLock ? parentSpacing : 0
    property real touchpadGap: !Hypr.touchpadEnabled && (Hypr.capsLock || Hypr.numLock) ? parentSpacing : 0

    spacing: 0

    Behavior on numGap {
        Anim {
            type: Anim.SlowEffects
        }
    }

    Behavior on touchpadGap {
        Anim {
            type: Anim.SlowEffects
        }
    }

    Behavior on capsHeight {
        Anim {
            type: Anim.SlowEffects
        }
    }

    Behavior on numHeight {
        Anim {
            type: Anim.SlowEffects
        }
    }

    Item {
        implicitWidth: capslockIcon.implicitWidth
        implicitHeight: Math.round(root.capsHeight)

        MaterialIcon {
            id: capslockIcon

            anchors.centerIn: parent

            scale: Hypr.capsLock ? 1 : 0.5
            opacity: Hypr.capsLock ? 1 : 0

            text: "keyboard_capslock_badge"
            color: root.colour
            fill: 1
            grade: 25

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on scale {
                Anim {}
            }
        }
    }

    Item {
        Layout.topMargin: Math.round(root.numGap)
        implicitWidth: numlockIcon.implicitWidth
        implicitHeight: Math.round(root.numHeight)

        MaterialIcon {
            id: numlockIcon

            anchors.centerIn: parent

            scale: Hypr.numLock ? 1 : 0.5
            opacity: Hypr.numLock ? 1 : 0

            text: "looks_one"
            color: root.colour
            fill: 1
            grade: 25

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on scale {
                Anim {}
            }
        }
    }

    Item {
        Layout.topMargin: Math.round(root.touchpadGap)
        implicitWidth: touchpadIcon.implicitWidth
        implicitHeight: Math.round(root.touchpadHeight)

        MaterialIcon {
            id: touchpadIcon

            anchors.centerIn: parent

            scale: !Hypr.touchpadEnabled ? 1 : 0.5
            opacity: !Hypr.touchpadEnabled ? 1 : 0

            text: "mouse"
            color: root.colour
            fill: 1
            grade: 25

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on scale {
                Anim {}
            }
        }
    }
}

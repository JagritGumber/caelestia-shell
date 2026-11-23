import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

ColumnLayout {
    id: root

    required property color colour
    required property int parentSpacing

    // Fold inter-icon gaps into each row's height. Animating Layout.topMargin
    // on a collapsing row is left behind by ColumnLayout (empty hole after
    // unlocking the touchpad while Num Lock is still on).
    property real capsRowHeight: Hypr.capsLock ? capslockIcon.implicitHeight : 0
    property real numRowHeight: (Hypr.numLock ? numlockIcon.implicitHeight : 0) + (Hypr.numLock && Hypr.capsLock ? parentSpacing : 0)
    property real touchpadRowHeight: (!Hypr.touchpadEnabled ? touchpadIcon.implicitHeight : 0) + (!Hypr.touchpadEnabled && (Hypr.capsLock || Hypr.numLock) ? parentSpacing : 0)

    spacing: 0

    Behavior on capsRowHeight {
        Anim {
            type: Anim.SlowEffects
        }
    }

    Behavior on numRowHeight {
        Anim {
            type: Anim.SlowEffects
        }
    }

    Behavior on touchpadRowHeight {
        Anim {
            type: Anim.SlowEffects
        }
    }

    Item {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: Math.round(root.capsRowHeight)
        Layout.minimumHeight: 0
        implicitWidth: capslockIcon.implicitWidth
        implicitHeight: Math.round(root.capsRowHeight)
        clip: true
        visible: root.capsRowHeight > 0

        MaterialIcon {
            id: capslockIcon

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom

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
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: Math.round(root.numRowHeight)
        Layout.minimumHeight: 0
        implicitWidth: numlockIcon.implicitWidth
        implicitHeight: Math.round(root.numRowHeight)
        clip: true
        visible: root.numRowHeight > 0

        MaterialIcon {
            id: numlockIcon

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom

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
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: Math.round(root.touchpadRowHeight)
        Layout.minimumHeight: 0
        implicitWidth: touchpadIcon.implicitWidth
        implicitHeight: Math.round(root.touchpadRowHeight)
        clip: true
        visible: root.touchpadRowHeight > 0

        MaterialIcon {
            id: touchpadIcon

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom

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

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Caelestia.Config
import qs.components
import qs.services

// A small picture of what an item is about, beside the sheet's detail
// (layoutMode "sheet"): a soft blob, an object, and a badge. Drawn here from
// shapes and Material symbols and coloured only from his scheme (container
// roles for the objects, primary for the badge), so it follows the
// wallpaper. Nothing is loaded from anywhere.
// intent: security, calendar, payment, ci, review, comment, delivery, or
// anything else (a bell).
Item {
    id: root

    property string intent
    // For "ci": a passing run gets a check, a failing one a re-run arrow.
    property bool good

    readonly property color blob: Colours.palette.m3secondaryContainer
    readonly property color body: Colours.palette.m3surfaceContainerHighest
    readonly property color line: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.35)

    implicitWidth: NotifDockState.pxi(240)
    implicitHeight: NotifDockState.pxi(210)

    // The blob behind everything.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Qt.alpha(root.blob, 0.75)
            strokeWidth: NotifDockState.pxi(-1)
            scale: Qt.size(root.width / 260, root.height / 220)

            PathSvg {
                path: "M 62 28 C 112 -6, 204 8, 230 62 C 254 112, 238 172, 186 196 C 134 220, 58 212, 28 166 C -2 120, 12 62, 62 28 Z"
            }
        }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: {
            switch (root.intent) {
            case "security":
                return security;
            case "calendar":
                return calendar;
            case "payment":
                return payment;
            case "ci":
                return ci;
            case "review":
                return review;
            case "comment":
                return comment;
            case "delivery":
                return delivery;
            default:
                return bell;
            }
        }
    }

    // A round badge with a symbol, bottom right of the object.
    component Badge: StyledRect {
        property string icon

        implicitWidth: NotifDockState.pxi(64)
        implicitHeight: NotifDockState.pxi(64)
        radius: NotifDockState.pxi(Tokens.rounding.full)
        color: Colours.palette.m3primary

        MaterialIcon {
            anchors.centerIn: parent
            text: parent.icon
            fill: 1
            color: Colours.palette.m3onPrimary
            fontStyle: NotifDockState.ifont(Tokens.font.icon.builders.small.size(24))
        }
    }

    // Rows of soft bars, like text.
    component Lines: Column {
        property var widths: [1, 0.8, 0.6]
        property color colour: root.line

        spacing: NotifDockState.pxi(8)

        Repeater {
            model: parent.widths

            StyledRect {
                required property real modelData

                width: parent.width * modelData
                height: NotifDockState.pxi(8)
                radius: NotifDockState.pxi(4)
                color: parent.colour
            }
        }
    }

    Component {
        id: security

        Item {
            // A laptop: screen and base.
            StyledRect {
                id: screen

                x: NotifDockState.pxi(46)
                y: NotifDockState.pxi(42)
                width: NotifDockState.pxi(148)
                height: NotifDockState.pxi(100)
                radius: NotifDockState.pxi(12)
                color: root.body

                StyledRect {
                    anchors.fill: parent
                    anchors.margins: NotifDockState.pxi(7)
                    radius: NotifDockState.pxi(7)
                    color: Colours.palette.m3primaryContainer

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "lock_person"
                        fill: 1
                        color: Colours.palette.m3onPrimaryContainer
                        fontStyle: NotifDockState.ifont(Tokens.font.icon.builders.small.size(30))
                    }
                }
            }

            StyledRect {
                x: NotifDockState.pxi(30)
                y: screen.y + screen.height + NotifDockState.pxi(2)
                width: NotifDockState.pxi(180)
                height: NotifDockState.pxi(12)
                radius: NotifDockState.pxi(6)
                color: root.body
            }

            Badge {
                x: NotifDockState.pxi(160)
                y: NotifDockState.pxi(116)
                icon: "shield"
            }
        }
    }

    Component {
        id: calendar

        Item {
            StyledClippingRect {
                x: NotifDockState.pxi(52)
                y: NotifDockState.pxi(34)
                width: NotifDockState.pxi(140)
                height: NotifDockState.pxi(134)
                radius: NotifDockState.pxi(16)
                color: root.body

                StyledRect {
                    width: parent.width
                    height: NotifDockState.pxi(34)
                    color: Colours.palette.m3tertiaryContainer
                }

                Grid {
                    x: NotifDockState.pxi(18)
                    y: NotifDockState.pxi(50)
                    columns: 4
                    spacing: NotifDockState.pxi(12)
                    rowSpacing: NotifDockState.pxi(12)

                    Repeater {
                        model: 12

                        StyledRect {
                            required property int index

                            width: NotifDockState.pxi(16)
                            height: NotifDockState.pxi(16)
                            radius: NotifDockState.pxi(5)
                            color: index === 6 ? Colours.palette.m3primary : root.line
                        }
                    }
                }
            }

            Badge {
                x: NotifDockState.pxi(160)
                y: NotifDockState.pxi(118)
                icon: "schedule"
            }
        }
    }

    Component {
        id: payment

        Item {
            StyledRect {
                x: NotifDockState.pxi(34)
                y: NotifDockState.pxi(46)
                width: NotifDockState.pxi(150)
                height: NotifDockState.pxi(94)
                radius: NotifDockState.pxi(14)
                rotation: -9
                color: Colours.palette.m3primaryContainer
            }

            StyledClippingRect {
                x: NotifDockState.pxi(56)
                y: NotifDockState.pxi(74)
                width: NotifDockState.pxi(150)
                height: NotifDockState.pxi(94)
                radius: NotifDockState.pxi(14)
                rotation: 5
                color: Colours.palette.m3tertiaryContainer

                StyledRect {
                    y: NotifDockState.pxi(20)
                    width: parent.width
                    height: NotifDockState.pxi(16)
                    color: Qt.alpha(Colours.palette.m3onTertiaryContainer, 0.35)
                }

                StyledRect {
                    x: NotifDockState.pxi(16)
                    y: NotifDockState.pxi(50)
                    width: NotifDockState.pxi(28)
                    height: NotifDockState.pxi(20)
                    radius: NotifDockState.pxi(5)
                    color: Qt.alpha(Colours.palette.m3onTertiaryContainer, 0.5)
                }
            }

            Badge {
                x: NotifDockState.pxi(166)
                y: NotifDockState.pxi(124)
                icon: "payments"
            }
        }
    }

    Component {
        id: ci

        Item {
            StyledClippingRect {
                x: NotifDockState.pxi(38)
                y: NotifDockState.pxi(40)
                width: NotifDockState.pxi(164)
                height: NotifDockState.pxi(118)
                radius: NotifDockState.pxi(14)
                color: root.body

                Row {
                    x: NotifDockState.pxi(14)
                    y: NotifDockState.pxi(12)
                    spacing: NotifDockState.pxi(6)

                    Repeater {
                        model: [Colours.palette.m3tertiary, Colours.palette.m3primary, Colours.palette.m3secondary]

                        StyledRect {
                            required property color modelData

                            width: NotifDockState.pxi(10)
                            height: NotifDockState.pxi(10)
                            radius: NotifDockState.pxi(5)
                            color: modelData
                        }
                    }
                }

                StyledText {
                    x: NotifDockState.pxi(14)
                    y: NotifDockState.pxi(38)
                    text: "›"
                    font: NotifDockState.ifont(Tokens.font.mono.builders.medium.size(18).weight(Font.Bold))
                    color: Colours.palette.m3primary
                }

                Lines {
                    x: NotifDockState.pxi(34)
                    y: NotifDockState.pxi(46)
                    width: NotifDockState.pxi(112)
                    widths: [1, 0.7, 0.85, 0.5]
                }
            }

            Badge {
                x: NotifDockState.pxi(162)
                y: NotifDockState.pxi(122)
                icon: root.good ? "check" : "replay"
            }
        }
    }

    Component {
        id: review

        Item {
            StyledRect {
                x: NotifDockState.pxi(64)
                y: NotifDockState.pxi(28)
                width: NotifDockState.pxi(118)
                height: NotifDockState.pxi(150)
                radius: NotifDockState.pxi(14)
                color: root.body

                Lines {
                    x: NotifDockState.pxi(16)
                    y: NotifDockState.pxi(22)
                    width: parent.width - NotifDockState.pxi(32)
                    widths: [0.9, 1, 0.7, 1, 0.55, 0.8]
                    colour: root.line
                }
            }

            Badge {
                x: NotifDockState.pxi(156)
                y: NotifDockState.pxi(120)
                icon: "merge"
            }
        }
    }

    Component {
        id: comment

        Item {
            StyledRect {
                x: NotifDockState.pxi(34)
                y: NotifDockState.pxi(44)
                width: NotifDockState.pxi(146)
                height: NotifDockState.pxi(74)
                radius: NotifDockState.pxi(22)
                bottomLeftRadius: 6
                color: Colours.palette.m3primaryContainer

                Lines {
                    x: NotifDockState.pxi(18)
                    y: NotifDockState.pxi(20)
                    width: parent.width - NotifDockState.pxi(36)
                    widths: [1, 0.7, 0.85]
                    colour: Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.45)
                }
            }

            StyledRect {
                x: NotifDockState.pxi(92)
                y: NotifDockState.pxi(128)
                width: NotifDockState.pxi(118)
                height: NotifDockState.pxi(56)
                radius: NotifDockState.pxi(20)
                bottomRightRadius: 6
                color: Colours.palette.m3tertiaryContainer

                Lines {
                    x: NotifDockState.pxi(16)
                    y: NotifDockState.pxi(16)
                    width: parent.width - NotifDockState.pxi(32)
                    widths: [1, 0.6]
                    colour: Qt.alpha(Colours.palette.m3onTertiaryContainer, 0.45)
                }
            }
        }
    }

    Component {
        id: delivery

        Item {
            StyledClippingRect {
                x: NotifDockState.pxi(64)
                y: NotifDockState.pxi(52)
                width: NotifDockState.pxi(116)
                height: NotifDockState.pxi(104)
                radius: NotifDockState.pxi(12)
                color: Colours.palette.m3tertiaryContainer

                StyledRect {
                    x: parent.width / 2 - NotifDockState.pxi(12)
                    width: NotifDockState.pxi(24)
                    height: parent.height
                    color: Qt.alpha(Colours.palette.m3onTertiaryContainer, 0.25)
                }
            }

            Badge {
                x: NotifDockState.pxi(156)
                y: NotifDockState.pxi(122)
                icon: "local_shipping"
            }
        }
    }

    Component {
        id: bell

        Item {
            StyledRect {
                anchors.centerIn: parent
                width: NotifDockState.pxi(112)
                height: NotifDockState.pxi(112)
                radius: NotifDockState.pxi(Tokens.rounding.full)
                color: Colours.palette.m3primaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "notifications"
                    fill: 1
                    color: Colours.palette.m3onPrimaryContainer
                    fontStyle: NotifDockState.ifont(Tokens.font.icon.builders.small.size(40))
                }
            }
        }
    }
}

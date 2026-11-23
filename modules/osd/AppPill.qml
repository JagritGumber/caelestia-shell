pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Templates
import Quickshell.Services.Pipewire
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// One app in the OSD's mixer: a pill the size of the OSD's own, with the app's
// icon on top (click it to mute) and its volume below (drag, or the scroll
// wheel anywhere on the pill).
CustomMouseArea {
    id: root

    required property PwNode stream

    readonly property var props: stream?.properties ?? {}
    readonly property real volume: stream?.audio?.volume ?? 0
    readonly property bool muted: !!stream?.audio?.muted

    // Like a notification's icon: the stream's own icon name, else the desktop
    // entry of its app name, binary or id; none gives the distro logo.
    readonly property string appIcon: {
        const icon = props["application.icon-name"] ?? "";
        for (const name of [props["application.name"], props["application.process.binary"], props["application.id"]]) {
            const found = Notifs.resolveAppIcon(String(name ?? ""), icon, "");
            if (found)
                return found;
        }
        return "";
    }

    signal interacted

    function setVolume(value: real): void {
        Audio.setStreamVolume(stream, value);
        interacted();
    }

    // One wheel notch up (1) or down (-1).
    function stepVolume(direction: int): void {
        setVolume(volume + direction * GlobalConfig.services.audioIncrement);
    }

    function onWheel(event: WheelEvent) {
        if (event.angleDelta.y > 0)
            stepVolume(1);
        else if (event.angleDelta.y < 0)
            stepVolume(-1);
    }

    implicitWidth: Tokens.sizes.osd.sliderWidth
    implicitHeight: Tokens.sizes.osd.sliderHeight

    onVolumeChanged: {
        percent.opacity = 1;
        percentTimer.restart();
    }

    StyledRect {
        anchors.fill: parent
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
        radius: Tokens.rounding.full
    }

    Slider {
        id: slider

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: iconButton.bottom
        anchors.bottom: parent.bottom

        orientation: Qt.Vertical
        from: 0
        to: GlobalConfig.services.maxVolume
        value: root.volume
        onMoved: root.setVolume(value)

        background: Item {
            StyledRect {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                // As in the OSD's own pills (FilledSlider): a circle at 0, full at the top.
                implicitHeight: parent.height - slider.visualPosition * (parent.height - width)
                color: root.muted ? Qt.alpha(Colours.palette.m3onSurface, 0.38) : Colours.palette.m3secondary
                radius: Tokens.rounding.full

                Behavior on implicitHeight {
                    Anim {
                        type: Anim.StandardLarge
                    }
                }
            }
        }

        handle: Item {}
    }

    // The volume in percent while it changes, like the OSD's own pills.
    StyledText {
        id: percent

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.padding.small
        text: Math.round(root.volume * 100)
        font: Tokens.font.body.small
        color: root.muted ? Colours.palette.m3onSurface : Colours.palette.m3onSecondary
        opacity: 0

        Timer {
            id: percentTimer

            interval: 800
            onTriggered: percent.opacity = 0
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Item {
        id: iconButton

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        implicitHeight: width

        StateLayer {
            radius: Tokens.rounding.full
            color: Colours.palette.m3onSurface
            onClicked: {
                Audio.setStreamMuted(root.stream, !root.muted);
                root.interacted();
            }
        }

        NotifAppIcon {
            anchors.centerIn: parent
            implicitSize: parent.width * 0.62
            icon: root.appIcon
            colour: Colours.palette.m3onSurfaceVariant
            opacity: root.muted ? 0.38 : 1
        }

        // Muted: a small badge on the icon.
        StyledRect {
            visible: root.muted
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            implicitWidth: badge.implicitWidth + Tokens.padding.extraSmall
            implicitHeight: implicitWidth
            radius: Tokens.rounding.full
            color: Colours.palette.m3error

            MaterialIcon {
                id: badge

                anchors.centerIn: parent
                text: root.stream?.properties["media.class"]?.startsWith("Stream/Input") ? "mic_off" : "no_sound"
                color: Colours.palette.m3onError
                fontStyle: Tokens.font.icon.small
            }
        }
    }
}

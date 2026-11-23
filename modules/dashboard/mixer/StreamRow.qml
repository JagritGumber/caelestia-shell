pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Caelestia.Config
import qs.components
import qs.services

// One app that is playing or recording: its icon (click to mute), its name
// with what it plays or its window's title, and its volume.
StyledRect {
    id: root

    required property PwNode stream

    readonly property var props: stream?.properties ?? {}
    readonly property string appName: Audio.getStreamName(stream)
    readonly property bool recording: String(props["media.class"] ?? "").startsWith("Stream/Input")
    readonly property bool muted: !!stream?.audio?.muted

    // Like a notification's icon: the stream's own icon name, else the desktop
    // entry of its app, binary or id; none gives the distro logo.
    readonly property string appIcon: {
        const icon = props["application.icon-name"] ?? "";
        for (const name of [appName, props["application.process.binary"], props["application.id"]]) {
            const found = Notifs.resolveAppIcon(String(name ?? ""), icon, "");
            if (found)
                return found;
        }
        return "";
    }

    // What it plays (media.name), unless that is a generic label such as
    // "Playback" or "RecordStream", else the title of the app's window.
    readonly property string detail: {
        const media = String(props["media.name"] ?? "").trim();
        const generic = /^(audio|play|playback|record|recording|capture|input|output|sound)?\s*(stream|callback driver)?$|^(simple dbus api|webrtc voiceengine|cubeb|alsa playback|alsa capture)$/i;
        if (!generic.test(media) && media.toLowerCase() !== appName.toLowerCase())
            return media;
        const pid = parseInt(props["application.process.id"] ?? "", 10);
        if (!pid)
            return "";
        const window = Hypr.toplevels?.values.find(t => t.lastIpcObject?.pid === pid);
        return window?.title ?? "";
    }

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.large
    implicitHeight: row.implicitHeight + Tokens.padding.medium * 2

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.padding.medium
        anchors.rightMargin: Tokens.padding.large
        spacing: Tokens.spacing.medium

        Item {
            readonly property real iconSize: Tokens.font.icon.extraLarge.pointSize * 1.4

            implicitWidth: iconSize + Tokens.padding.small * 2
            implicitHeight: implicitWidth

            StateLayer {
                radius: Tokens.rounding.full
                color: Colours.palette.m3onSurface
                onClicked: Audio.setStreamMuted(root.stream, !root.muted)
            }

            NotifAppIcon {
                anchors.centerIn: parent
                implicitSize: parent.iconSize
                icon: root.appIcon
                colour: Colours.palette.m3onSurfaceVariant
                opacity: root.muted ? 0.38 : 1
            }

            // Muted, or a recording stream: a small badge on the icon.
            StyledRect {
                visible: root.muted || root.recording
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitWidth: badge.implicitWidth + Tokens.padding.extraSmall
                implicitHeight: implicitWidth
                radius: Tokens.rounding.full
                color: root.muted ? Colours.palette.m3error : Colours.palette.m3primary

                MaterialIcon {
                    id: badge

                    anchors.centerIn: parent
                    text: root.muted ? (root.recording ? "mic_off" : "no_sound") : "mic"
                    color: root.muted ? Colours.palette.m3onError : Colours.palette.m3onPrimary
                    fontStyle: Tokens.font.icon.small
                }
            }
        }

        ColumnLayout {
            Layout.preferredWidth: root.width * 0.34
            Layout.maximumWidth: root.width * 0.34
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.appName
                font: Tokens.font.body.medium
                color: Colours.palette.m3onSurface
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.detail
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }
        }

        VolumeRow {
            Layout.fillWidth: true
            node: root.stream
            isInput: root.recording
            showIcon: false
        }
    }
}

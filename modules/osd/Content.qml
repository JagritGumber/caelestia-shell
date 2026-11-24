pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property Brightness.Monitor monitor
    required property ScreenState screenState

    required property real volume
    required property bool muted
    required property real sourceVolume
    required property bool sourceMuted
    required property real brightness

    // The per-app mixer beside the volume ("output") or microphone ("input")
    // pill, only on demand: resting the pointer on that pill for 400 ms (the mic
    // pill only while an app is recording), right-clicking it, or the osd IPC
    // target. It closes with the OSD, 400 ms after the pointer leaves, or after
    // 4 s if the pointer never comes; never on a volume change.
    readonly property string mixer: screenState.osdMixer
    property string shownMixer
    property real mixerProgress: mixer ? 1 : 0
    property bool mixerHovered
    // The app pills line up with their pill; the device chip sits above them,
    // so beside the volume pill the OSD grows upwards by the chip's height.
    readonly property real mixerTop: (shownMixer === "input" ? micLoader.y : volumePill.y) - ((mixerLoader.item as MixerColumn)?.pillsTop ?? 0)
    readonly property real mixerOverflow: Math.max(0, -mixerTop) * mixerProgress
    // Apps making sound now, by their stream's media class: playing
    // (Stream/Output/Audio) or recording (Stream/Input/Audio). Their stream is
    // not corked (paused), and the shell's own streams (level meters, monitors)
    // are not apps.
    readonly property list<PwNode> playingApps: Audio.streams.filter(s => isApp(s, "Stream/Output/Audio"))
    readonly property list<PwNode> recordingApps: Audio.streams.filter(s => isApp(s, "Stream/Input/Audio"))
    readonly property real centreOffset: CUtils.clamp(Tokens.padding.large - Config.border.thickness, 0, Tokens.padding.large) / 2

    function isApp(node: PwNode, mediaClass: string): bool {
        const props = node?.properties ?? {};
        return props["media.class"] === mediaClass && String(props["pulse.corked"]) !== "true" && props["stream.monitor"] !== "true" && String(props["application.process.id"] ?? "") !== String(Quickshell.processId);
    }

    function toggleMixer(kind: string): void {
        screenState.osdMixer = mixer === kind ? "" : kind;
    }

    onMixerChanged: {
        if (mixer)
            shownMixer = mixer;
        mixerHovered = hover.hovered;
        idleTimer.restart();
    }

    implicitWidth: layout.implicitWidth + Tokens.padding.large + centreOffset * 2 + (mixerLoader.implicitWidth + Tokens.spacing.medium) * mixerProgress
    implicitHeight: Tokens.padding.large * 2 + mixerOverflow + Math.max(layout.implicitHeight, (mixerTop + mixerLoader.implicitHeight) * mixerProgress)

    Behavior on mixerProgress {
        Anim {
            type: Anim.Emphasized
        }
    }

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hovered) {
                root.mixerHovered = true;
                leaveTimer.stop();
            } else if (root.mixer && root.mixerHovered) {
                leaveTimer.restart();
            }
        }
    }

    Timer {
        id: leaveTimer

        interval: 400
        onTriggered: {
            if (!hover.hovered)
                root.screenState.osdMixer = "";
        }
    }

    // Opened without the pointer (the IPC target): close it, and the OSD,
    // unless the pointer arrives.
    Timer {
        id: idleTimer

        interval: 4000
        onTriggered: {
            if (!root.mixer || root.mixerHovered)
                return;
            root.screenState.osdMixer = "";
            if (!hover.hovered)
                root.screenState.osd = false;
        }
    }

    // The mixer, sliding out to the left of its pill.
    Item {
        anchors.right: layout.left
        anchors.rightMargin: Tokens.spacing.medium * root.mixerProgress
        y: layout.y + root.mixerTop
        implicitWidth: mixerLoader.implicitWidth * root.mixerProgress
        implicitHeight: mixerLoader.implicitHeight
        clip: true
        visible: root.mixerProgress > 0
        opacity: root.mixerProgress

        Loader {
            id: mixerLoader

            anchors.right: parent.right
            active: !!root.mixer || root.mixerProgress > 0

            sourceComponent: MixerColumn {
                input: root.shownMixer === "input"
                streams: root.shownMixer === "input" ? root.recordingApps : root.playingApps
                onInteracted: idleTimer.restart()
            }
        }
    }

    ColumnLayout {
        id: layout

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Tokens.padding.large / 2
        anchors.topMargin: Tokens.padding.large + root.mixerOverflow
        spacing: Tokens.spacing.medium

        // Speaker volume
        CustomMouseArea {
            id: volumePill

            function onWheel(event: WheelEvent) {
                if (event.angleDelta.y > 0)
                    Audio.incrementVolume();
                else if (event.angleDelta.y < 0)
                    Audio.decrementVolume();
            }

            implicitWidth: Tokens.sizes.osd.sliderWidth
            implicitHeight: Tokens.sizes.osd.sliderHeight

            MixerHover {
                screenState: root.screenState
                kind: "output"
            }

            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: root.toggleMixer("output")
            }

            FilledSlider {
                anchors.fill: parent

                icon: Icons.getVolumeIcon(value, root.muted)
                value: root.volume
                to: GlobalConfig.services.maxVolume
                onMoved: Audio.setVolume(value)
            }
        }

        // Microphone volume
        WrappedLoader {
            id: micLoader

            shouldBeActive: Config.osd.enableMicrophone && (!Config.osd.enableBrightness || !root.screenState.session)

            sourceComponent: CustomMouseArea {
                function onWheel(event: WheelEvent) {
                    if (event.angleDelta.y > 0)
                        Audio.incrementSourceVolume();
                    else if (event.angleDelta.y < 0)
                        Audio.decrementSourceVolume();
                }

                implicitWidth: Tokens.sizes.osd.sliderWidth
                implicitHeight: Tokens.sizes.osd.sliderHeight

                // Nothing recording: the column would be empty, and the
                // pointer crosses this middle pill on its way into the OSD.
                MixerHover {
                    enabled: root.recordingApps.length > 0
                    screenState: root.screenState
                    kind: "input"
                }

                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: root.toggleMixer("input")
                }

                FilledSlider {
                    anchors.fill: parent

                    icon: Icons.getMicVolumeIcon(value, root.sourceMuted)
                    value: root.sourceVolume
                    to: GlobalConfig.services.maxVolume
                    onMoved: Audio.setSourceVolume(value)
                }
            }
        }

        // Brightness
        WrappedLoader {
            shouldBeActive: Config.osd.enableBrightness

            sourceComponent: CustomMouseArea {
                function onWheel(event: WheelEvent) {
                    const monitor = root.monitor;
                    if (!monitor)
                        return;
                    if (event.angleDelta.y > 0)
                        monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
                    else if (event.angleDelta.y < 0)
                        monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
                }

                implicitWidth: Tokens.sizes.osd.sliderWidth
                implicitHeight: Tokens.sizes.osd.sliderHeight

                FilledSlider {
                    anchors.fill: parent

                    icon: `brightness_${(Math.round(value * 6) + 1)}`
                    value: root.brightness
                    onMoved: root.monitor?.setBrightness(value)
                }
            }
        }
    }

    component WrappedLoader: Loader {
        required property bool shouldBeActive

        asynchronous: true
        Layout.preferredHeight: shouldBeActive ? Tokens.sizes.osd.sliderHeight : 0
        opacity: shouldBeActive ? 1 : 0
        active: opacity > 0
        visible: active

        Behavior on Layout.preferredHeight {
            Anim {
                type: Anim.Emphasized
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }
}

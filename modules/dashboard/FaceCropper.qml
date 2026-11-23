pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// After picking a profile picture: choose what's in the circle. Drag to move,
// scroll or use the slider to zoom. "Set picture" cuts that square from the
// original image (full resolution, via ImageMagick) into ~/.face at 512 px.
LazyLoader {
    id: loader

    property string source
    readonly property string facePath: `${Paths.home}/.face`

    function open(path: string): void {
        source = path;
        activeAsync = true;
    }

    function close(): void {
        activeAsync = false;
    }

    FloatingWindow {
        id: root

        // The square the circle sits in, on screen.
        readonly property int view: 440
        readonly property real naturalWidth: picture.implicitWidth
        readonly property real naturalHeight: picture.implicitHeight
        readonly property bool ready: picture.status === Image.Ready && naturalWidth > 0 && naturalHeight > 0
        // Scale at which the picture just covers the square; zoom multiplies it.
        readonly property real coverScale: ready ? Math.max(view / naturalWidth, view / naturalHeight) : 1
        readonly property real maxZoom: 8
        property real zoom: 1
        readonly property real scale: coverScale * zoom
        // The picture's top-left corner in the square.
        property real offsetX: 0
        property real offsetY: 0
        property bool saving: false

        // Keeps the square covered: the picture never slides off an edge.
        function clampOffsets(): void {
            offsetX = Math.min(0, Math.max(view - naturalWidth * scale, offsetX));
            offsetY = Math.min(0, Math.max(view - naturalHeight * scale, offsetY));
        }

        // Zooms keeping the point (px, py) of the square still.
        function zoomTo(next: real, px: real, py: real): void {
            next = Math.max(1, Math.min(maxZoom, next));
            const imageX = (px - offsetX) / scale;
            const imageY = (py - offsetY) / scale;
            zoom = next;
            offsetX = px - imageX * scale;
            offsetY = py - imageY * scale;
            clampOffsets();
        }

        function centre(): void {
            // Computed here, not read from coverScale: this runs as the picture
            // loads, before that binding has caught up.
            const cover = Math.max(view / naturalWidth, view / naturalHeight);
            zoom = 1;
            offsetX = (view - naturalWidth * cover) / 2;
            // Portraits keep their top third in view: that's usually the face.
            offsetY = naturalHeight > naturalWidth ? -(naturalHeight * cover - view) / 6 : (view - naturalHeight * cover) / 2;
            clampOffsets();
        }

        function save(): void {
            if (!ready || saving)
                return;
            const size = Math.max(1, Math.round(view / scale));
            const x = Math.max(0, Math.min(Math.round(naturalWidth) - size, Math.round(-offsetX / scale)));
            const y = Math.max(0, Math.min(Math.round(naturalHeight) - size, Math.round(-offsetY / scale)));
            saving = true;
            cut.command = ["sh", "-c", 'magick "$1" -auto-orient -crop "$2" +repage -resize "512x512^" -gravity center -extent 512x512 "PNG:$3.tmp" && mv -f "$3.tmp" "$3"', "sh", loader.source, `${size}x${size}+${x}+${y}`, loader.facePath];
            cut.running = true;
        }

        implicitWidth: view + 48
        implicitHeight: view + 190
        color: Colours.tPalette.m3surface
        surfaceFormat.opaque: false
        title: qsTr("Crop profile picture")

        onReadyChanged: if (ready)
            Qt.callLater(centre)
        onVisibleChanged: if (!visible)
            loader.close()

        Shortcut {
            sequence: "Escape"
            onActivated: loader.close()
        }

        Process {
            id: cut

            onExited: code => {
                root.saving = false;
                if (code === 0)
                    Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-u", "low", "-h", `STRING:image-path:${loader.facePath}`, "Profile picture changed", `Cropped from ${Paths.shortenHome(loader.source)}`]);
                else
                    Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-u", "critical", "Unable to change profile picture", `Couldn't crop ${Paths.shortenHome(loader.source)}`]);
                loader.close();
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: Tokens.spacing.medium

            StyledText {
                text: qsTr("Drag to move, scroll to zoom")
                color: Colours.palette.m3onSurfaceVariant
            }

            // The picture, the circle that will show, and the dimmed rest.
            Item {
                id: frame

                Layout.alignment: Qt.AlignHCenter
                implicitWidth: root.view
                implicitHeight: root.view
                clip: true

                Image {
                    id: picture

                    x: root.offsetX
                    y: root.offsetY
                    width: root.naturalWidth * root.scale
                    height: root.naturalHeight * root.scale
                    source: loader.source ? Qt.resolvedUrl(loader.source) : ""
                    autoTransform: true
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }

                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const context = getContext("2d");
                        context.reset();
                        context.fillStyle = Qt.alpha(Colours.palette.m3scrim, 0.55);
                        context.fillRule = Qt.OddEvenFill;
                        context.beginPath();
                        context.rect(0, 0, width, height);
                        context.arc(width / 2, height / 2, width / 2 - 1, 0, 2 * Math.PI);
                        context.fill();
                        context.strokeStyle = Qt.alpha("#ffffff", 0.85);
                        context.lineWidth = 2;
                        context.beginPath();
                        context.arc(width / 2, height / 2, width / 2 - 1, 0, 2 * Math.PI);
                        context.stroke();
                    }
                }

                MouseArea {
                    property real lastX
                    property real lastY

                    anchors.fill: parent
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: mouse => {
                        lastX = mouse.x;
                        lastY = mouse.y;
                    }
                    onPositionChanged: mouse => {
                        root.offsetX += mouse.x - lastX;
                        root.offsetY += mouse.y - lastY;
                        lastX = mouse.x;
                        lastY = mouse.y;
                        root.clampOffsets();
                    }
                    onWheel: wheel => root.zoomTo(root.zoom * Math.pow(1.0015, wheel.angleDelta.y), wheel.x, wheel.y)
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: picture.status === Image.Error
                    text: qsTr("Couldn't open that picture")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "zoom_out"
                    color: Colours.palette.m3onSurfaceVariant
                }

                // Zoom on a log scale, so each step feels the same.
                StyledSlider {
                    Layout.fillWidth: true
                    implicitHeight: 24
                    value: Math.log(root.zoom) / Math.log(root.maxZoom)
                    onInteraction: value => root.zoomTo(Math.pow(root.maxZoom, value), root.view / 2, root.view / 2)
                }

                MaterialIcon {
                    text: "zoom_in"
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                TextButton {
                    Layout.fillWidth: true
                    Layout.minimumHeight: Tokens.font.body.medium.pointSize + Tokens.padding.medium * 2
                    inactiveColour: Colours.palette.m3secondaryContainer
                    inactiveOnColour: Colours.palette.m3onSecondaryContainer
                    text: qsTr("Cancel")
                    onClicked: loader.close()
                }

                TextButton {
                    Layout.fillWidth: true
                    Layout.minimumHeight: Tokens.font.body.medium.pointSize + Tokens.padding.medium * 2
                    inactiveColour: Colours.palette.m3primary
                    inactiveOnColour: Colours.palette.m3onPrimary
                    disabled: !root.ready || root.saving
                    text: root.saving ? qsTr("Saving…") : qsTr("Set picture")
                    onClicked: root.save()
                }
            }
        }
    }
}

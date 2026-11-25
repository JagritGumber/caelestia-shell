pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import "kit.js" as Kit

// An item's actions as buttons, the same way on every card: the renderer,
// not the feed, decides how each looks.
// - role primary: filled; secondary and danger: tonal (the error colour is
//   kept for failures, never for a button); quiet: text only. A confirm
//   waiting for its second click is filled in the tertiary accent.
// - type url opens the link (http(s) only); command and confirm run
//   `courier-notify action`; confirm needs a second click within 4 s; input
//   asks the card for text (`input` signal) and is sent from there.
// Under the buttons, the last outcome: "✓ Approved", or Junco's error.
ColumnLayout {
    id: root

    required property var item
    property var unit
    property var actions: []
    // Equal widths across the card (two big answers), else natural widths.
    property bool equal
    property bool big
    // Symbols only (quick answers beside a reply field).
    property bool iconOnly
    property string armed

    signal input(var action)

    readonly property var result: NotifDockState.resultFor(unit)
    // The sheet (layoutMode "sheet"): Material 3 pill buttons; the primary
    // filled, the others outlined.
    readonly property bool m3: NotifDockState.layoutMode === "sheet"

    function press(action: var): void {
        const type = action.type ?? (action.url ? "url" : "command");
        if (type === "input") {
            input(action);
            return;
        }
        if (type === "confirm" && armed !== action.id) {
            armed = action.id;
            disarm.restart();
            return;
        }
        armed = "";
        NotifDockState.act(item, action, "", false);
    }

    spacing: NotifDockState.px(Tokens.spacing.small)

    Timer {
        id: disarm

        interval: 4000
        onTriggered: root.armed = ""
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: NotifDockState.px(Tokens.spacing.small)

        Repeater {
            model: root.actions

            IconTextButton {
                id: button

                required property var modelData
                required property int index

                readonly property string role: modelData.role ?? (index === 0 ? "primary" : "secondary")
                readonly property bool isArmed: root.armed === modelData.id
                readonly property bool running: NotifDockState.results[`${root.item?.id}|${modelData.id}`]?.state === "running"

                Layout.fillWidth: root.equal
                Layout.preferredWidth: implicitWidth
                readonly property bool outlined: root.m3 && (role === "secondary" || role === "danger")

                type: outlined || role === "quiet" ? TextButton.Text : role === "secondary" || role === "danger" ? TextButton.Tonal : TextButton.Filled
                isRound: root.m3
                border.width: outlined ? 1 : 0
                border.color: Colours.palette.m3outline
                inactiveColour: isArmed ? Colours.palette.m3tertiary : type === TextButton.Filled ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer
                inactiveOnColour: isArmed ? Colours.palette.m3onTertiary : type === TextButton.Filled ? Colours.palette.m3onPrimary : type === TextButton.Text ? Colours.palette.m3primary : Colours.palette.m3onSecondaryContainer
                icon: isArmed ? "warning" : modelData.icon ?? ((modelData.type ?? "") === "url" ? "open_in_new" : "")
                iconLabel.visible: icon !== ""
                label.visible: !root.iconOnly || isArmed
                text: isArmed ? "Confirm" : running ? `${modelData.label}…` : modelData.label
                font: root.big ? NotifDockState.dfont(Tokens.font.label.builders.large.weight(Font.Medium)) : NotifDockState.dfont(Tokens.font.label.builders.large)
                horizontalPadding: root.m3 ? NotifDockState.px(Tokens.padding.large + 8) : NotifDockState.px(Tokens.padding.medium)
                verticalPadding: NotifDockState.pad(root.big || root.m3 ? Tokens.padding.medium : Tokens.padding.small + 2, Math.max(label.implicitHeight, iconLabel.visible ? iconLabel.implicitHeight : 0))
                disabled: running
                onClicked: root.press(modelData)
                Component.onCompleted: NotifDockState.registerButton(`${root.item?.id}|${modelData.id}`, button)
                Component.onDestruction: NotifDockState.forget(button)

                // Waiting for the second click: a hint floats above the
                // button, so nothing on the card moves.
                StyledRect {
                    anchors.bottom: parent.top
                    anchors.left: parent.left
                    anchors.bottomMargin: NotifDockState.px(6)
                    visible: button.isArmed
                    implicitWidth: hint.implicitWidth + NotifDockState.px(Tokens.padding.medium) * 2
                    implicitHeight: hint.implicitHeight + NotifDockState.px(Tokens.padding.small)
                    radius: NotifDockState.px(Tokens.rounding.small)
                    color: Colours.palette.m3inverseSurface

                    StyledText {
                        id: hint

                        anchors.centerIn: parent
                        text: button.modelData.hint || "Click again to confirm"
                        font: NotifDockState.dfont(Tokens.font.label.builders.large)
                        color: Colours.palette.m3inverseOnSurface
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: !root.equal
            visible: !root.iconOnly
        }
    }

    Row {
        visible: !!root.result && root.result.state !== "running" && root.armed === ""
        spacing: NotifDockState.px(4)

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.result?.state === "failed" ? "error" : "check_circle"
            fill: 1
            color: root.result?.state === "failed" ? Colours.palette.m3error : Colours.palette.m3success
            fontStyle: NotifDockState.dfont(Tokens.font.icon.builders.small.size(11))
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.result ? `${root.result.action}: ${root.result.message}` : ""
            font: NotifDockState.dfont(Tokens.font.label.builders.large)
            color: root.result?.state === "failed" ? Colours.palette.m3error : Colours.palette.m3success
        }
    }
}

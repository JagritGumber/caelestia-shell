pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Templates as T
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// A reply field that is always on the card, as its main action. Clicking it
// gives the panel the keyboard (and keeps it up) until it is sent or left
// with Escape; Ctrl+Enter or the send button posts it through the item's
// input action. A draft survives Escape.
StyledRect {
    id: root

    required property var item
    required property var action
    property string hint: "Reply…"

    readonly property bool active: NotifDockState.typing && NotifDockState.typingId === (item?.id ?? "")
    readonly property bool sending: NotifDockState.results[`${item?.id}|${action?.id}`]?.state === "running"

    function start(): void {
        NotifDockState.typingId = item?.id ?? "";
        NotifDockState.typing = true;
        Qt.callLater(() => input.forceActiveFocus());
    }

    function stop(): void {
        NotifDockState.setDraft(item?.id ?? "", input.text);
        NotifDockState.typing = false;
    }

    function send(): void {
        if (!input.text.trim() || sending)
            return;
        NotifDockState.act(item, action, input.text, false);
    }

    implicitHeight: Math.max(NotifDockState.compact ? 42 : 44, NotifDockState.px(44), Math.min(NotifDockState.px(96), input.implicitHeight) + NotifDockState.px(8))
    radius: NotifDockState.px(Tokens.rounding.large)
    color: Colours.palette.m3surfaceContainerHighest
    border.width: active ? 1 : 0
    border.color: Colours.palette.m3primary

    Component.onCompleted: input.text = NotifDockState.drafts[item?.id ?? ""] ?? ""

    Connections {
        // Sent: clear the field and give the keyboard back.
        function onResultsChanged(): void {
            const r = NotifDockState.results[`${root.item?.id}|${root.action?.id}`];
            if (r?.state === "done" && input.text && !root.sending) {
                input.text = "";
                if (root.active)
                    NotifDockState.typing = false;
            }
        }

        target: NotifDockState
    }

    T.TextArea {
        id: input

        anchors.left: parent.left
        anchors.right: send.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: NotifDockState.px(Tokens.padding.small)
        // Templates' TextArea doesn't size itself to its text.
        implicitHeight: contentHeight + topPadding + bottomPadding
        wrapMode: TextEdit.Wrap
        textFormat: TextEdit.PlainText
        color: Colours.palette.m3onSurface
        selectionColor: Qt.alpha(Colours.palette.m3primary, 0.4)
        placeholderText: root.hint
        placeholderTextColor: Colours.palette.m3onSurfaceVariant
        font: NotifDockState.dfont(Tokens.font.body.builders.medium)
        readOnly: root.sending
        padding: NotifDockState.px(Tokens.padding.small)
        cursorDelegate: StyledRect {
            implicitWidth: NotifDockState.px(1.5)
            color: Colours.palette.m3primary
            visible: input.activeFocus
        }

        Keys.onPressed: event => {
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                event.accepted = true;
                root.send();
            } else if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                root.stop();
            }
        }
    }

    StyledText {
        anchors.left: input.left
        anchors.right: input.right
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: input.leftPadding
        visible: !input.text
        text: root.hint
        elide: Text.ElideRight
        font: NotifDockState.dfont(Tokens.font.body.builders.medium)
        color: Colours.palette.m3onSurfaceVariant
    }

    // Until it's active, a click anywhere on the field (the whole box left
    // of the send button, so it is at least 42 px tall) starts a reply.
    MouseArea {
        id: starter

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: send.left
        visible: !root.active
        cursorShape: Qt.IBeamCursor
        onClicked: root.start()
        Component.onCompleted: NotifDockState.registerButton(`${root.item?.id}|${root.action?.id}|field`, starter)
        Component.onDestruction: NotifDockState.forget(starter)
    }

    IconButton {
        id: send

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: NotifDockState.px(6)
        type: IconButton.Filled
        icon: root.sending ? "hourglass_top" : "send"
        font: NotifDockState.dfont(Tokens.font.icon.builders.small)
        padding: NotifDockState.pad(Tokens.padding.small, label.implicitHeight)
        disabled: !input.text.trim() || root.sending
        onClicked: root.send()
        Component.onCompleted: NotifDockState.registerButton(`${root.item?.id}|${root.action?.id}`, send)
        Component.onDestruction: NotifDockState.forget(send)
    }
}

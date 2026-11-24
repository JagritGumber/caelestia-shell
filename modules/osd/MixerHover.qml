import QtQuick
import qs.components

// Hovering a pill for 400 ms opens its mixer (ScreenState.osdMixer). It sits on
// the pill itself: the slider inside takes hover, so nothing under it gets any.
// Its own file rather than an inline component of Content.qml: a running shell
// did not pick up a new inline component on hot reload.
HoverHandler {
    id: root

    required property ScreenState screenState
    required property string kind
    readonly property Timer delay: Timer {
        interval: 400
        onTriggered: root.screenState.osdMixer = root.kind
    }

    onHoveredChanged: {
        if (hovered)
            delay.restart();
        else
            delay.stop();
    }
}

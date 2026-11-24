import QtQuick
import qs.components

// Resting the pointer on a pill for 400 ms opens its mixer (ScreenState.osdMixer).
// Each move of the pointer restarts the wait, so crossing a pill on the way to
// another opens nothing. A pill that slides in under a still pointer (the OSD
// shown by a volume key) is not a request either: it opens only once the
// pointer moves.
// It sits on the pill itself: the slider inside takes hover, so nothing under
// it gets any. Its own file rather than an inline component of Content.qml: a
// running shell did not pick up a new inline component on hot reload.
HoverHandler {
    id: root

    required property ScreenState screenState
    required property string kind

    // Scene positions stay put when the pill moves under the pointer.
    property point lastPointer
    property point pillAtEntry
    property bool moved

    readonly property Timer delay: Timer {
        interval: 400
        onTriggered: {
            const pill = root.parent.mapToItem(null, 0, 0);
            if (root.moved || (pill.x === root.pillAtEntry.x && pill.y === root.pillAtEntry.y))
                root.screenState.osdMixer = root.kind;
        }
    }

    onHoveredChanged: {
        if (!hovered) {
            delay.stop();
            return;
        }
        lastPointer = point.scenePosition;
        pillAtEntry = parent.mapToItem(null, 0, 0);
        moved = false;
        delay.restart();
    }

    onPointChanged: {
        const p = point.scenePosition;
        if (!hovered || (p.x === lastPointer.x && p.y === lastPointer.y))
            return;
        lastPointer = p;
        moved = true;
        delay.restart();
    }
}

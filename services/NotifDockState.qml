pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services
import qs.utils
import "../modules/notifdock/kit/adapt.js" as Adapt

// The notification dock's data (modules/notifdock): Junco's work items, read
// from the feed Junco writes, ${XDG_STATE_HOME}/courier/dock.json (the
// contract, version 2: Kibby's notes, notif-dock/CONTRACT.md). Items are
// grouped by source (the panel's tabs) and by unit of work (its cards).
// Normal notifications never come here. The dock never writes the feed:
// actions go back to Junco through `courier-notify` (a reply's text on its
// stdin), links open with xdg-open, and each action's outcome is kept for its
// card to show.
Singleton {
    id: root

    // shell.json: "notifs": {"dock": false} turns the dock off, and
    // "dockRevealDelay" is how long (ms) the pointer rests on the bottom edge
    // before the bar shows: 50 by default. The dashboard opens on hover
    // with none, but with none a pointer only touching the bottom edge
    // (30 ms, in the rig) opened the dock; 50 ms still feels instant. Read from the file: the installed plugin's
    // schema has no such keys (it logs them as unknown options).
    property bool enabled: true
    property int revealDelay: 50
    // How long after it arrives or changes an item counts as fresh: the
    // source icon shows a small dot.
    readonly property int freshMinutes: 10

    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || `${Paths.home}/.local/state`
    // Junco's notmuch config, for courier-notify's runs: its mark-read opens
    // the mail index before it sets NOTMUCH_CONFIG itself, and with no
    // default notmuch config that failed for every real item (2026-11-26;
    // the Junco fix is its own). Kept if the shell already has one.
    readonly property string notmuchConfig: Quickshell.env("NOTMUCH_CONFIG") || `${Quickshell.env("XDG_CONFIG_HOME") || `${Paths.home}/.config`}/courier/notmuch-config`

    // Why a run failed, in one line: a Python traceback's last line (the
    // error itself, without its type), else stderr's first line.
    function reason(text: string): string {
        const lines = String(text ?? "").split("\n").map(l => l.trim()).filter(l => l);
        if (!lines.length)
            return "";
        if (lines[0].startsWith("Traceback (most recent call last)"))
            return lines[lines.length - 1].replace(/^[\w.]+(Error|Exception|Exit): /, "");
        return lines[0];
    }

    // The feed's items, as last read whole.
    property var feed: []
    property bool feedRead
    // Items hidden at once after a dismiss or a resolving action, until the
    // feed catches up: id to the `updated` it had.
    property var hidden: ({})
    // Which id/updated pairs have been read, to tell a new arrival.
    property var known: ({})
    // Moves on every 30 s, for ages and freshness.
    property real now: Date.now()

    readonly property var items: enabled ? feed.filter(i => (i.status ?? "open") === "open" && hidden[i.id] !== i.updated) : []
    // Units of work, each the newest first: {unit, label, source, icon,
    // items, count, critical, fresh, newest}.
    readonly property var units: {
        const map = new Map();
        for (const item of items) {
            if (!map.has(item.unit))
                map.set(item.unit, []);
            map.get(item.unit).push(item);
        }
        const out = [];
        for (const [unit, list] of map) {
            list.sort((a, b) => timeOf(b.updated) - timeOf(a.updated));
            out.push({
                unit: unit,
                label: list[0].unitLabel || list[0].source,
                source: list[0].source,
                icon: list[0].icon || "courier",
                items: list,
                count: list.reduce((n, i) => n + Math.max(1, Number(i.count) || 1), 0),
                critical: list.some(i => i.urgency === "critical"),
                fresh: list.some(i => isFresh(i)),
                newest: timeOf(list[0].updated)
            });
        }
        return out.sort((a, b) => (b.critical - a.critical) || (b.newest - a.newest));
    }
    // The bar's tabs, one per source: the one with a critical item first,
    // then the one with the newest: {source, icon, units, count, critical, newest}.
    readonly property var sources: {
        const map = new Map();
        for (const unit of units) {
            if (!map.has(unit.source))
                map.set(unit.source, {
                    source: unit.source,
                    icon: unit.icon,
                    units: [],
                    count: 0,
                    critical: false,
                    newest: 0
                });
            const tab = map.get(unit.source);
            tab.units.push(unit);
            tab.count += unit.count;
            tab.critical = tab.critical || unit.critical;
            tab.newest = Math.max(tab.newest, unit.newest);
        }
        return [...map.values()].sort((a, b) => (b.critical - a.critical) || (b.newest - a.newest));
    }
    readonly property int count: units.reduce((n, u) => n + u.count, 0)
    readonly property bool critical: units.some(u => u.critical)
    readonly property bool fresh: units.some(u => u.fresh)
    // The tab the panel shows. The panel picks the first one each time it opens.
    property string activeSource
    // A reply box is open: the panel takes the keyboard and stays up.
    property bool typing
    // How the revealed dock lays out: "sheet" (a Material 3 list-detail
    // sheet, his pick) or "deck" (one card at a time). shell.json:
    // "notifs": {"dockLayout": "deck"} switches to the deck (the plugin's
    // schema doesn't know the key, so it is only set to change the default).
    property string layoutMode: "sheet"
    // The sheet's chosen unit (for IPC).
    property string selection
    // The sheet's size: shell.json "notifs": {"dockScale": 1.1} makes it 10%
    // bigger, 0.9 10% smaller (0.6 to 1.6). 1 is the compact size: about
    // 990 x 480 px on his screen, its type one Material step down (a hero
    // title.large 22 pt becomes 17 pt, about 22 px; title.small 14 pt
    // becomes 11 pt, about 14 px), and its padding and gaps about 0.75 of
    // Caelestia's. Buttons stay at least 36 px tall. The deck keeps
    // Caelestia's sizes: there every helper below returns what it is given.
    property real dockScale: 1
    readonly property bool compact: layoutMode === "sheet"
    readonly property real ui: compact ? 0.75 * dockScale : 1
    readonly property real typeScale: compact ? 0.78 * dockScale : 1
    // The detail pane's type (the kit's components) is smaller still, so a
    // card carries more: a hero title.large 22 pt is 16 pt (about 21 px),
    // body.medium 14 pt is 10 pt (about 13 px).
    readonly property real detailTypeScale: compact ? 0.72 * dockScale : 1
    readonly property int minHit: 36
    // Unsent replies, by item id, kept when a reply box closes.
    property var drafts: ({})
    // Each action's outcome, by "item id|action id": {state: "running" |
    // "done" | "failed", message}.
    property var results: ({})

    // Layers that draw along the bottom edge: Wispr Flow's glow (Kibby's
    // wispr-glow, mapped only while you dictate) puts its voice bars there.
    // The sliver stays down while one is mapped.
    readonly property list<string> bottomEdgeLayers: ["quickshell:kibby-edge-aura"]
    property int bottomEdgeLayersOpen
    readonly property bool bottomEdgeBusy: bottomEdgeLayersOpen > 0

    // v6 (contract v3). How the shelf's tabs split the work: "lanes" (All /
    // Actions / Updates) or "sources" (a tab per source), and the tab shown:
    // all, actions, updates, or a source's name.
    property string tabsMode: "lanes"
    property string view: "all"
    // One unit (or item id) alone, for looking at a single component.
    property string solo
    // Which item's reply field has the keyboard.
    property string typingId
    // The shelf's sections, in order. An item's section comes from its lane
    // and due time (sectionOf), so "Overdue" needs no rewrite from Junco.
    readonly property var sectionKinds: [
        {
            key: "overdue",
            label: qsTr("Overdue"),
            icon: "error",
            tone: "error"
        },
        {
            key: "needs",
            label: qsTr("Needs you"),
            icon: "front_hand",
            tone: "primary"
        },
        {
            key: "upcoming",
            label: qsTr("Upcoming"),
            icon: "event_upcoming",
            tone: "tertiary"
        },
        {
            key: "updates",
            label: qsTr("Updates"),
            icon: "notifications",
            tone: ""
        }
    ]
    readonly property var laneCounts: ({
            all: units.length,
            actions: units.filter(u => laneOf(u.items[0]) === "action").length,
            updates: units.filter(u => laneOf(u.items[0]) === "update").length
        })
    // Cards and buttons on screen, by unit and by "item id|action id", for
    // the `geom` IPC call (the rig's clicks and crops). Mutated in place.
    property var cardsMap: ({})
    property var buttonsMap: ({})

    // A new item, or one Junco changed: the sliver pulses once.
    signal arrived
    // IPC: scroll the shelf to x, or to a section.
    signal scrollRequested(real x)
    signal sectionRequested(string key)

    // v7: the deck. Cards left for later go to the back, in the order they
    // were left (laterSeq: unit to a running number). `pinned` puts one
    // unit in front (IPC, the rig's shots). While the deck is open, a card
    // whose action completed it flies off first (`completed`); the deck
    // then hides it.
    property var laterSeq: ({})
    property int laterCount
    property string pinned
    property bool deckOpen
    signal completed(string unit)

    // A tab's deck, front first: pinned; then anything not left for later;
    // critical; Overdue, Needs you, Upcoming, Updates; newest.
    function deckOf(view: string): var {
        const rank = {
            overdue: 1,
            needs: 2,
            upcoming: 3,
            updates: 4
        };
        return unitsIn(view).slice().sort((a, b) => ((b.unit === pinned) - (a.unit === pinned)) || ((laterSeq[a.unit] ?? 0) - (laterSeq[b.unit] ?? 0)) || (b.critical - a.critical) || (rank[sectionOf(a.items[0])] - rank[sectionOf(b.items[0])]) || (b.newest - a.newest));
    }

    // Leave for now: to the back of every deck it is in, still unread.
    function later(unit: var): void {
        if (!unit)
            return;
        laterCount++;
        const next = Object.assign({}, laterSeq);
        next[unit.unit] = laterCount;
        laterSeq = next;
        if (pinned === unit.unit)
            pinned = "";
    }

    // Done with: by an action that resolves it, or by the card's primary
    // action. The open deck flies it off first.
    function complete(item: var): void {
        if (deckOpen)
            completed(item.unit);
        else
            hide([item]);
    }

    function laneOf(item: var): string {
        return item?.lane === "update" ? "update" : "action";
    }

    // overdue: its due time has passed; upcoming: due more than a day from
    // now; needs: any other action; updates: the update lane.
    function sectionOf(item: var): string {
        if (laneOf(item) === "update")
            return "updates";
        const due = timeOf(item?.due ?? "");
        if (due && due < now)
            return "overdue";
        if (due && due - now > 86400000)
            return "upcoming";
        return "needs";
    }

    function unitsIn(view: string): var {
        if (solo)
            return units.filter(u => u.unit === solo || u.items.some(i => i.id === solo));
        if (view === "actions")
            return units.filter(u => laneOf(u.items[0]) === "action");
        if (view === "updates")
            return units.filter(u => laneOf(u.items[0]) === "update");
        if (view && view !== "all")
            return units.filter(u => u.source === view);
        return units;
    }

    function registerCard(key: string, card: var): void {
        if (card)
            cardsMap[key] = card;
        else
            delete cardsMap[key];
    }

    function registerButton(key: string, button: var): void {
        if (button)
            buttonsMap[key] = button;
        else
            delete buttonsMap[key];
    }

    // An object going away: every entry that points at it. (By object, not
    // by key: a button's key is made from its item, which may already be the
    // next item by the time the button is destroyed.)
    function forget(object: var): void {
        for (const map of [cardsMap, buttonsMap])
            for (const key of Object.keys(map))
                if (map[key] === object)
                    delete map[key];
    }

    // The footer's "Mark all read": the updates in view. Actions stay until
    // they are done: marking them read would lose them.
    function markAllRead(list: var): void {
        for (const unit of list)
            if (laneOf(unit.items[0]) === "update")
                dismissUnit(unit);
    }

    // The deck's Mark read: the item's own `mark-read` action when it has
    // one (Junco marks the mail read and lets the item go), else `courier-
    // notify dismiss` (out of the dock, the mail untouched). Hidden at once;
    // a mark-read that fails brings the card back, with the reason on it.
    function markRead(unit: var): void {
        for (const item of unit?.items ?? []) {
            const action = item.deckActions?.markRead;
            if (action)
                act(item, action, "", true);
            else
                Quickshell.execDetached(["courier-notify", "dismiss", item.id]);
        }
        hide(unit?.items ?? []);
    }

    // The deck's "Open in Junco": the front item's `open-junco` action.
    function openInJunco(unit: var): void {
        const item = (unit?.items ?? []).find(i => i.deckActions?.openJunco);
        if (item)
            act(item, item.deckActions.openJunco, "", false);
    }

    function unhide(list: var): void {
        const next = Object.assign({}, hidden);
        for (const item of list)
            delete next[item.id];
        hidden = next;
    }

    function timeOf(iso: string): real {
        return Date.parse(iso) || 0;
    }

    function isFresh(item: var): bool {
        return now - timeOf(item.updated) < freshMinutes * 60000;
    }

    // A logo that exists: a file URL, or a theme icon the theme has, else
    // Junco's own icon, else "" (the views then show the distro logo).
    function iconFor(icon: string): string {
        if (icon?.startsWith("file:"))
            return icon;
        if (icon?.startsWith("/"))
            return `file://${icon}`;
        if (icon && Quickshell.iconPath(icon, true))
            return icon;
        return Quickshell.iconPath("courier", true) ? "courier" : "";
    }

    function unitOf(key: string): var {
        return units.find(u => u.unit === key) ?? null;
    }

    // The card's main button: the first action that doesn't resolve.
    function mainAction(item: var): var {
        return item?.actions?.find(a => !a.resolves) ?? null;
    }

    // The card's ✓: the first action that resolves the item.
    function resolveAction(item: var): var {
        return item?.actions?.find(a => a.resolves) ?? null;
    }

    // url: xdg-open (http/https only). command, confirm and v1 actions:
    // `courier-notify action <id> <action-id>`. input: the same, with `text`
    // on stdin. A resolving action hides the item once it has succeeded.
    function act(item: var, action: var, text: string, restoreOnFail: bool): void {
        if (!item || !action)
            return;
        const type = action.type ?? (action.url ? "url" : "command");
        const key = `${item.id}|${action.id}`;
        if (type === "url") {
            if (/^https?:\/\//i.test(action.url ?? "")) {
                Quickshell.execDetached(["xdg-open", action.url]);
                setResult(key, "done", qsTr("Opened"));
            } else {
                console.warn("notifdock: not opening a link that isn't http(s):", action.url);
                setResult(key, "failed", qsTr("Not an http(s) link"));
            }
            return;
        }
        if (type === "input" && !String(text ?? "").trim())
            return;
        if (results[key]?.state === "running")
            return;
        setResult(key, "running", "");
        runner.createObject(root, {
            key: key,
            item: item,
            action: action,
            restoreOnFail: !!restoreOnFail,
            input: type === "input" ? text : "",
            command: ["courier-notify", "action", item.id, action.id]
        });
    }

    function setResult(key: string, state: string, message: string): void {
        const next = Object.assign({}, results);
        next[key] = {
            state: state,
            message: message,
            at: Date.now()
        };
        results = next;
    }

    // The latest outcome among a unit's items, for its card: {state, message, action}.
    function resultFor(unit: var): var {
        let latest = null;
        for (const item of unit?.items ?? [])
            for (const action of item.actions ?? []) {
                const r = results[`${item.id}|${action.id}`];
                if (r && (!latest || r.at >= latest.at))
                    latest = Object.assign({
                        action: action.label
                    }, r);
            }
        return latest;
    }

    function setDraft(id: string, text: string): void {
        const next = Object.assign({}, drafts);
        if (text)
            next[id] = text;
        else
            delete next[id];
        drafts = next;
    }

    // The card's ✓: every open item in the unit that can be resolved.
    function resolveUnit(unit: var): void {
        for (const item of unit?.items ?? [])
            act(item, resolveAction(item), "", false);
    }

    // The card's ×: Junco removes the unit's items, or marks them resolved.
    function dismissUnit(unit: var): void {
        for (const item of unit?.items ?? [])
            Quickshell.execDetached(["courier-notify", "dismiss", item.id]);
        hide(unit?.items ?? []);
    }

    function hide(list: var): void {
        const next = Object.assign({}, hidden);
        for (const item of list)
            next[item.id] = item.updated;
        hidden = next;
    }

    function read(text: string): void {
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            console.warn("notifdock: the feed isn't valid JSON; keeping the last one");
            return;
        }
        if (![1, 2, 3].includes(data?.version) || !Array.isArray(data.items)) {
            console.warn("notifdock: the feed isn't version 1, 2 or 3; keeping the last one");
            return;
        }
        // Every version as v3 (kit/adapt.js): v1 and v2 items mapped to a
        // component and its sections, v3 as sent.
        const valid = data.items.filter(i => i && typeof i.id === "string" && i.id && typeof i.unit === "string" && typeof i.source === "string" && typeof i.title === "string").map(i => Adapt.adapt(i));
        const keys = {};
        let fresh = false;
        for (const item of valid) {
            const key = `${item.id}|${item.updated}`;
            keys[key] = true;
            if (feedRead && !known[key] && (item.status ?? "open") === "open")
                fresh = true;
        }
        // Forget hidden items that changed or left the feed.
        const stillHidden = {};
        for (const item of valid)
            if (hidden[item.id] === item.updated)
                stillHidden[item.id] = item.updated;
        hidden = stillHidden;
        known = keys;
        feed = valid;
        feedRead = true;
        if (fresh)
            arrived();
    }

    onEnabledChanged: {
        if (enabled)
            alive.setText(`${new Date().toISOString()}\n`);
    }

    // One action's run: `courier-notify action <id> <action-id>`, a reply's
    // text written to its stdin, then its outcome kept in `results`: exit 0
    // and stdout's first line ("Sent"), or the failure and stderr's first line.
    Component {
        id: runner

        Process {
            id: proc

            property string key
            property var item
            property var action
            property string input
            property bool finished
            // Hidden before it ran (Mark read): shown again if it fails.
            property bool restoreOnFail
            // Junco answers within seconds; after a minute, give up.
            property Timer timeout: Timer {
                running: true
                interval: 60000
                onTriggered: {
                    proc.signal(15);
                    proc.fail(qsTr("No answer from Junco in a minute"));
                }
            }

            function fail(message: string): void {
                if (finished)
                    return;
                finished = true;
                root.setResult(key, "failed", message);
                if (restoreOnFail)
                    root.unhide([item]);
                destroy();
            }

            running: true
            environment: ({
                    NOTMUCH_CONFIG: root.notmuchConfig
                })
            // Open even with nothing to write: Quickshell closes a disabled
            // stdin before the process starts, which Qt doesn't apply, so it
            // would stay open and a command reading it would wait forever.
            // Closed right after start instead, after the reply's text.
            stdinEnabled: true
            stdout: StdioCollector {
                id: out
            }
            stderr: StdioCollector {
                id: err
            }
            onStarted: {
                if (input.length > 0)
                    write(input);
                stdinEnabled = false;
            }
            // Couldn't start (no courier-notify on PATH): no exit comes.
            onRunningChanged: {
                if (!running)
                    Qt.callLater(() => {
                        if (proc && !proc.finished)
                            proc.fail(qsTr("Couldn't run courier-notify"));
                    });
            }
            onExited: (code, status) => {
                if (finished)
                    return;
                finished = true;
                const first = text => String(text ?? "").trim().split("\n")[0];
                if (code === 0) {
                    root.setResult(key, "done", first(out.text) || qsTr("Done"));
                    // v7: a card's primary action completes it too (not a
                    // link: opening a page isn't doing the work).
                    // An action without a role is primary when it comes first,
                    // as the cards draw it.
                    const role = action.role ?? ((item.actions ?? [])[0]?.id === action.id ? "primary" : "secondary");
                    if (action.resolves || (role === "primary" && (action.type ?? "") !== "url"))
                        root.complete(item);
                    if ((action.type ?? "") === "input")
                        root.setDraft(item.id, "");
                } else {
                    root.setResult(key, "failed", root.reason(err.text) || qsTr("Failed (exit %1)").arg(code));
                    if (restoreOnFail)
                        root.unhide([item]);
                }
                destroy();
            }
        }
    }

    FileView {
        id: feedFile

        path: `${root.stateHome}/courier/dock.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.read(text())
    }

    // Until the feed has been read (Junco not set up yet), look again now
    // and then; after that, watching the file is enough.
    Timer {
        running: !root.feedRead
        repeat: true
        interval: 10000
        onTriggered: feedFile.reload()
    }

    // A length in the dock (padding, a gap, a radius, a fixed size).
    function px(n: real): real {
        return compact ? Math.round(n * ui) : n;
    }

    // A font from a token's builder (Tokens.font.<role>.builders.<size>,
    // with any .size/.weight), built one step down in the sheet: rounded to
    // a whole point, and never under 9 pt (12 px) unless it was smaller.
    function font(builder: var): font {
        if (!compact)
            return builder.build();
        const base = builder.build().pointSize;
        return builder.size(Math.max(Math.min(base, 9), Math.round(base * typeScale))).build();
    }

    // The sheet's illustration (kit/Illustration.qml) is smaller still: 0.6
    // of the compact size (108 x 95 px), so it fits beside the item.
    readonly property real illustrationScale: 0.6

    function pxi(n: real): real {
        return compact ? Math.round(n * ui * illustrationScale) : n;
    }

    function ifont(builder: var): font {
        if (!compact)
            return builder.build();
        return builder.size(Math.max(1, Math.round(builder.build().pointSize * typeScale * illustrationScale))).build();
    }

    // The detail's fonts (the kit): font(), at detailTypeScale.
    function dfont(builder: var): font {
        if (!compact)
            return builder.build();
        const base = builder.build().pointSize;
        return builder.size(Math.max(Math.min(base, 9), Math.round(base * detailTypeScale))).build();
    }

    // An emphasis on a token's size (a hero at 1.15x title.large): in the
    // sheet a hero is plain title.large, and only a big figure (2x, a
    // payment's amount) stays clearly bigger.
    function emph(m: real): real {
        return compact ? (m >= 1.8 ? m * 0.75 : 1) : m;
    }

    // A button's vertical padding: base scaled, but enough that a control
    // whose content is `content` px tall is at least minHit px tall.
    function pad(base: real, content: real): real {
        return compact ? Math.max(Math.round(base * ui), Math.ceil((minHit - content) / 2)) : base;
    }

    FileView {
        path: `${Paths.config}/shell.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const notifs = JSON.parse(text())?.notifs ?? {};
                root.enabled = notifs.dock !== false;
                root.revealDelay = Number.isFinite(notifs.dockRevealDelay) ? Math.max(0, notifs.dockRevealDelay) : 50;
                root.layoutMode = notifs.dockLayout === "deck" ? "deck" : "sheet";
                root.dockScale = Number.isFinite(notifs.dockScale) ? Math.max(0.6, Math.min(1.6, notifs.dockScale)) : 1;
            } catch (e) {
                // A file mid-edit; the plugin reports parse errors itself.
            }
        }
        onLoadFailed: root.enabled = true
    }

    // The heartbeat Junco checks: while the dock runs and is on, this file
    // is rewritten every 30 s. Older than 90 s, Junco falls back to a normal
    // desktop notification.
    FileView {
        id: alive

        path: `${Paths.state}/notifdock.alive`
        printErrors: false
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 30000
        onTriggered: {
            root.now = Date.now();
            if (root.enabled)
                alive.setText(`${new Date().toISOString()}\n`);
        }
    }

    Connections {
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name !== "openlayer" && event.name !== "closelayer")
                return;
            if (!root.bottomEdgeLayers.includes(event.data.trim()))
                return;
            root.bottomEdgeLayersOpen = Math.max(0, root.bottomEdgeLayersOpen + (event.name === "openlayer" ? 1 : -1));
        }

        target: Hyprland
    }

    // `qs -c caelestia ipc call notifdock count`: open work items; `tabs`:
    // each tab and its count; `tab`: the tab shown. `drawers toggle
    // notifDock` shows or hides the bar.
    IpcHandler {
        function count(): int {
            return root.count;
        }

        function tabs(): string {
            return root.sources.map(s => `${s.source}\t${s.count}${s.critical ? "\tcritical" : ""}`).join("\n");
        }

        function tab(): string {
            return root.activeSource;
        }

        // v6: the shelf's tab (all, actions, updates, or a source).
        function view(name: string): string {
            root.view = name;
            return root.view;
        }

        // v6: "lanes" or "sources".
        function tabsMode(mode: string): string {
            root.tabsMode = mode;
            return root.tabsMode;
        }

        // v6: one unit or item alone ("" for all).
        function solo(key: string): string {
            root.solo = key;
            return root.solo;
        }

        function scroll(x: string): void {
            root.scrollRequested(Number(x) || 0);
        }

        function scrollTo(section: string): void {
            root.sectionRequested(section);
        }

        // v7: the shown tab's deck, front first, as JSON {view, order}.
        function deck(): string {
            return JSON.stringify({
                view: root.view,
                order: root.deckOf(root.view).map(u => u.unit)
            });
        }

        // The sheet's chosen unit.
        function selected(): string {
            return root.selection;
        }

        // The layout in use.
        function layoutNow(): string {
            return root.layoutMode;
        }

        // "deck" or "sheet" (until shell.json changes).
        function layout(mode: string): string {
            root.layoutMode = mode === "sheet" ? "sheet" : "deck";
            return root.layoutMode;
        }

        // v7: forget what was left for later, and any pinned card.
        function deckReset(): void {
            root.laterSeq = {};
            root.pinned = "";
        }

        // v7: put one unit in front ("" for the normal order).
        function front(unit: string): string {
            root.pinned = unit;
            return root.pinned;
        }

        // v6: where each card and button is on screen, as JSON:
        // {cards: {unit: [x, y, w, h]}, buttons: {"id|action": [...]}}.
        function geom(): string {
            const rect = o => {
                const p = o.mapToItem(null, 0, 0);
                return [Math.round(p.x), Math.round(p.y), Math.round(o.width), Math.round(o.height), o.visible ? 1 : 0];
            };
            const out = {
                cards: {},
                buttons: {}
            };
            // An entry whose object is gone is dropped, not fatal.
            for (const [map, into] of [[root.cardsMap, out.cards], [root.buttonsMap, out.buttons]])
                for (const key of Object.keys(map)) {
                    try {
                        into[key] = rect(map[key]);
                    } catch (e) {
                        delete map[key];
                    }
                }
            return JSON.stringify(out);
        }

        target: "notifdock"
    }

    // The layers already mapped when the shell (re)starts.
    Process {
        running: true
        command: ["hyprctl", "-j", "layers"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let open = 0;
                    for (const mon of Object.values(JSON.parse(text)))
                        for (const level of Object.values(mon.levels ?? {}))
                            open += level.filter(l => root.bottomEdgeLayers.includes(l.namespace)).length;
                    root.bottomEdgeLayersOpen = open;
                } catch (e) {
                    root.bottomEdgeLayersOpen = 0;
                }
            }
        }
    }
}

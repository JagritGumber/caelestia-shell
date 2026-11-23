import { readFileSync } from "node:fs";

const source = readFileSync(new URL("../modules/bar/TrayIntent.js", import.meta.url), "utf8")
    .replace(/^\.pragma library\s*/, "");
const trayIntent = new Function(`${source}; return { menuName, isTrayMenu, shouldDelayActivation, inMenuCorridor, shouldPreserveOpenMenu, shouldQueueCorridorSwitch, shouldDeferLeave };`)();

function assert(condition, message) {
    if (!condition)
        throw new Error(message);
}

const steamId = ":1.42/org/ayatana/NotificationItem/steam";
const slackId = ":1.7/org/chromium/StatusNotifierItem/1";
assert(trayIntent.menuName(steamId) === trayIntent.menuName(steamId), "Steam's menu identity changed");
assert(trayIntent.menuName(steamId) !== trayIntent.menuName(slackId), "Different tray items received the same menu identity");
assert(trayIntent.isTrayMenu(trayIntent.menuName(steamId)), "Stable tray name was not recognised");
assert(trayIntent.shouldDelayActivation({ x: 20, y: 100 }, { x: 20, y: 130 }, 16), "Fast transit should delay an intermediate flyout");
assert(!trayIntent.shouldDelayActivation({ x: 20, y: 100 }, { x: 20, y: 102 }, 50), "Slow hover should activate immediately");

const origin = { x: 28, y: 180 };
const target = { left: 64, top: 80, bottom: 280 };
assert(trayIntent.inMenuCorridor(origin, { x: 40, y: 160 }, target), "Early diagonal movement closed the popout");
assert(trayIntent.inMenuCorridor(origin, { x: 54, y: 125 }, target), "Movement near the menu closed the popout");
assert(!trayIntent.inMenuCorridor(origin, { x: 18, y: 180 }, target), "Movement back across the bar stayed in the corridor");
assert(!trayIntent.inMenuCorridor(origin, { x: 48, y: 310 }, target), "Movement below the menu stayed in the corridor");

const steamMenu = trayIntent.menuName(steamId);
const slackMenu = trayIntent.menuName(slackId);
assert(trayIntent.shouldPreserveOpenMenu(steamMenu, steamMenu, origin, { x: 34, y: 165 }, target), "Diagonal movement inside a vertical sidebar switched to an intermediate icon");
assert(!trayIntent.shouldPreserveOpenMenu(steamMenu, steamMenu, origin, { x: 28, y: 150 }, target), "Vertical sidebar movement could not intentionally switch icons");
assert(!trayIntent.shouldPreserveOpenMenu(slackMenu, steamMenu, origin, { x: 34, y: 165 }, target), "A stale aim corridor preserved the wrong app");
assert(trayIntent.shouldQueueCorridorSwitch(steamMenu, slackMenu, true), "A stopped pointer over Slack preserved Steam's menu indefinitely");
assert(!trayIntent.shouldQueueCorridorSwitch(steamMenu, steamMenu, true), "The open tray item queued a redundant switch");
assert(!trayIntent.shouldQueueCorridorSwitch(steamMenu, slackMenu, false), "A pointer outside the bar queued a tray switch");
assert(trayIntent.shouldDeferLeave(true, steamMenu, 1), "A base tray menu closed across the shaped-window gap");
assert(!trayIntent.shouldDeferLeave(true, "audio", 1), "A non-tray popout inherited tray leave behaviour");
assert(!trayIntent.shouldDeferLeave(true, steamMenu, 2), "A focused tray submenu inherited hover leave behaviour");

console.log("PASS: tray identity and diagonal hover intent");

.pragma library

var menuPrefix = "traymenu:"

function menuName(itemId) {
    return menuPrefix + String(itemId ?? "")
}

function isTrayMenu(name) {
    return String(name ?? "").startsWith(menuPrefix)
}

function shouldDelayActivation(previous, pointer, elapsedMs) {
    if (elapsedMs <= 0 || previous.x < 0 || previous.y < 0)
        return false

    const distance = Math.hypot(pointer.x - previous.x, pointer.y - previous.y)
    return distance / elapsedMs > 0.7
}

function inMenuCorridor(origin, pointer, target, padding) {
    const margin = padding ?? 8
    const width = target.left - origin.x

    if (width <= 0 || pointer.x < origin.x || pointer.x > target.left + margin)
        return false

    const progress = Math.max(0, Math.min(1, (pointer.x - origin.x) / width))
    const upper = origin.y + (target.top - margin - origin.y) * progress - margin
    const lower = origin.y + (target.bottom + margin - origin.y) * progress + margin

    return pointer.y >= upper && pointer.y <= lower
}

function shouldPreserveOpenMenu(openMenuName, aimMenuName, origin, pointer, target) {
    return isTrayMenu(openMenuName)
        && openMenuName === aimMenuName
        && inMenuCorridor(origin, pointer, target)
}

function shouldQueueCorridorSwitch(openMenuName, candidateName, pointerInsideBar) {
    return pointerInsideBar
        && isTrayMenu(openMenuName)
        && isTrayMenu(candidateName)
        && candidateName !== openMenuName
}

function shouldDeferLeave(hasCurrent, currentName, menuDepth) {
    return hasCurrent && isTrayMenu(currentName) && menuDepth <= 1
}

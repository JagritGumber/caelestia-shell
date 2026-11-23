import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Caelestia

// Memory and battery alerts as Caelestia toasts (bottom right). Warning and error
// toasts also show over fullscreen windows: utilities.toasts.fullscreen is
// "important" in shell.json, and drawers/ContentWindow.qml lifts the drawers above
// fullscreen while one is up. Nothing here acts on its own; Caelestia's battery
// toasts and hibernate are switched off in shell.json.
Scope {
    id: root

    readonly property int memWarnAt: 80
    readonly property int memResetBelow: 75
    readonly property int batteryWarnAt: 10

    property bool memArmed: true
    property bool batteryArmed: true
    property int memPercent: 0
    property real memUsedKib: 0
    property real memTotalKib: 0

    readonly property int batteryPercent: Math.round(UPower.displayDevice.percentage * 100)

    function gb(kib: real): string {
        return `${(kib / 1048576).toFixed(1)} GB`;
    }

    function timeLeft(seconds: real): string {
        const minutes = Math.round(seconds / 60);
        if (minutes >= 60)
            return `${Math.floor(minutes / 60)} h ${minutes % 60} min left. `;
        return `${minutes} min left. `;
    }

    function toastMemory(test: bool): void {
        Toaster.toast(`Memory ${memPercent}% used${test ? " (test)" : ""}`, `${gb(memUsedKib)} of ${gb(memTotalKib)}. Close a heavy app.`, "memory", Toast.Warning, 10000);
    }

    function toastBattery(test: bool): void {
        const left = UPower.displayDevice.timeToEmpty > 0 ? timeLeft(UPower.displayDevice.timeToEmpty) : "";
        Toaster.toast(`Battery at ${batteryPercent}%${test ? " (test)" : ""}`, `${left}Plug in a charger.`, "battery_android_alert", Toast.Error, 20000);
    }

    function applyMemReading(reading: string): void {
        const fields = reading.trim().split(" ");
        if (fields.length < 3)
            return;

        memPercent = Number(fields[0]);
        memUsedKib = Number(fields[1]);
        memTotalKib = Number(fields[2]);

        // One alert per climb past 80%; it re-arms once usage drops below 75%
        if (memPercent < memResetBelow)
            memArmed = true;
        else if (memArmed && memPercent >= memWarnAt) {
            memArmed = false;
            toastMemory(false);
        }
    }

    function checkBattery(): void {
        if (!UPower.displayDevice.ready)
            return;

        // Plugging in re-arms the alert for the next time it runs low
        if (!UPower.onBattery) {
            batteryArmed = true;
            return;
        }

        if (batteryArmed && batteryPercent <= batteryWarnAt) {
            batteryArmed = false;
            toastBattery(false);
        }
    }

    Component.onCompleted: checkBattery()

    IpcHandler {
        target: "systemAlerts"

        function testMemory(): void {
            root.toastMemory(true);
        }

        function testBattery(): void {
            root.toastBattery(true);
        }
    }

    Connections {
        target: UPower

        function onOnBatteryChanged(): void {
            root.checkBattery();
        }
    }

    Connections {
        target: UPower.displayDevice

        function onPercentageChanged(): void {
            root.checkBattery();
        }

        function onReadyChanged(): void {
            root.checkBattery();
        }
    }

    Process {
        id: memProcess

        // RAM in use is MemTotal minus MemAvailable; free page cache counts as available
        command: ["awk", '/^MemTotal:/ { t = $2 } /^MemAvailable:/ { a = $2 } END { printf "%d %d %d\\n", (t - a) * 100 / t, t - a, t }', "/proc/meminfo"]
        stdout: SplitParser {
            onRead: data => root.applyMemReading(data)
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!memProcess.running)
                memProcess.running = true;
        }
    }
}

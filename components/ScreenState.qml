import Quickshell

PersistentProperties {
    required property ShellScreen modelData

    // Drawer visibilities
    property bool bar
    property bool osd
    property bool session
    property bool launcher
    property bool dashboard
    property bool utilities
    property bool sidebar
    property bool notifDock // the notification dock's bar is up (modules/notifdock)

    // Dashboard state
    property int dashboardTab
    property string osdMixer // "output" or "input": the OSD's per-app mixer is open
    property date dashboardDate: new Date()
}

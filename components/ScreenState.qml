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

    // Dashboard state
    property int dashboardTab
    property string dashboardTabId // the current tab's id, e.g. "mixer"
    property string dashboardTabRequest // set to an id to switch to that tab
    property date dashboardDate: new Date()
}

pragma Singleton

import Quickshell
import Caelestia.Config
import Caelestia.Models
import qs.utils

Searcher {
    id: root

    property var resolvedIcons: ({})

    // On every rescan of the applications folders (any file added, removed or
    // renamed there or in a parent such as ~ or ~/.local/share), Quickshell
    // builds a new DesktopEntry for each id that a ~/.local/share/applications
    // file overrides, and AppDb then drops that app until its 300 ms timer adds
    // it back. VS Code, Helium and Wispr Flow left the launcher that way several
    // times a minute. Until AppDb has it again, such an app is listed through
    // its DesktopEntry, in the place it had.
    property list<string> lastOrder: []

    readonly property var steadyApps: {
        const apps = appDb.apps.filter(a => a.entry);
        const listed = new Set(apps.map(a => a.id));
        const gaps = appDb.entries.filter(e => !listed.has(e.id));
        if (gaps.length === 0)
            return apps;

        const out = [...apps];
        for (const entry of gaps) {
            // Before the first app that followed it last time and is still listed.
            const was = lastOrder.indexOf(entry.id);
            const next = was < 0 ? -1 : lastOrder.slice(was + 1).findIndex(id => listed.has(id));
            const before = next < 0 ? -1 : out.findIndex(a => a.id === lastOrder[was + 1 + next]);
            if (before < 0)
                out.push(entry);
            else
                out.splice(before, 0, entry);
        }
        return out;
    }

    function resolvedIcon(name: string): string {
        return resolvedIcons[name] ?? "";
    }

    function rememberIcon(name: string, path: string): void {
        if (!name || !path)
            return;

        const icons = Object.assign({}, resolvedIcons);
        icons[name] = path.startsWith("/") ? `file://${path}` : path;
        resolvedIcons = icons;
    }

    function launch(entry: DesktopEntry): void {
        appDb.incrementFrequency(entry.id);

        if (entry.runInTerminal)
            Quickshell.execDetached({
                command: [...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...entry.command],
                workingDirectory: entry.workingDirectory
            });
        else
            entry.execute();
    }

    function search(search: string): var {
        const prefix = GlobalConfig.launcher.specialPrefix;

        if (search.startsWith(`${prefix}i `)) {
            keys = ["id", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}c `)) {
            keys = ["categories", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}d `)) {
            keys = ["comment", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}e `)) {
            keys = ["execString", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}w `)) {
            keys = ["startupClass", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}g `)) {
            keys = ["genericName", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}k `)) {
            keys = ["keywords", "name"];
            weights = [0.9, 0.1];
        } else {
            keys = ["name"];
            weights = [1];

            if (!search.startsWith(`${prefix}t `))
                return query(search).map(e => e.entry ?? e);
        }

        const results = query(search.slice(prefix.length + 2)).map(e => e.entry ?? e);
        if (search.startsWith(`${prefix}t `))
            return results.filter(a => a.runInTerminal);
        return results;
    }

    function selector(item: var): string {
        return keys.map(k => item[k]).join(" ");
    }

    list: steadyApps
    useFuzzy: GlobalConfig.launcher.useFuzzy.apps
    onSteadyAppsChanged: {
        if (steadyApps.every(a => a.entry))
            lastOrder = steadyApps.map(a => a.id);
    }

    AppDb {
        id: appDb

        path: `${Paths.state}/apps.sqlite`
        favouriteApps: GlobalConfig.launcher.favouriteApps
        entries: DesktopEntries.applications.values.filter(a => !Strings.testRegexList(GlobalConfig.launcher.hiddenApps, a.id))
    }
}

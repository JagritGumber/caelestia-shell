.pragma library

// Feed items of any version as the deck draws them (contract v3).
// - v3 items (with `component`) pass through as Junco sent them.
// - v1 and v2 items (Junco's feed before v3) are mapped from their kind and
//   fields to a component and its sections, so they get the same cards:
//   ci-* → StatusSummary, review-requested → ReviewPanel, comment /
//   review-comment / review → CommentPanel, anything else (security alerts,
//   logins, payments...) → Summary with its fields as fact tiles.
// Either way, the actions `mark-read` and `open-junco` come off the card's
// buttons into `deckActions`: the deck's Mark read and its "Open in Junco"
// run them. Everything stays plain text.

function field(item, key) {
    const list = item.fields || [];
    for (let i = 0; i < list.length; i++)
        if (list[i] && list[i].key === key)
            return list[i].value;
    return undefined;
}

function text(item, key) {
    const v = field(item, key);
    if (v === undefined || v === null)
        return "";
    return Array.isArray(v) ? v.join(", ") : String(v);
}

function list(item, key) {
    const v = field(item, key);
    return Array.isArray(v) ? v.map(String) : v ? [String(v)] : [];
}

function num(v) {
    const n = Number(v);
    return isFinite(n) ? n : 0;
}

// The v2 markup subset as plain text: fences and backticks go, the rest
// stays as written.
function plain(markup) {
    return String(markup || "").split("\n").filter(l => !/^\s*```/.test(l)).join("\n").replace(/`([^`]*)`/g, "$1").trim();
}

function capital(s) {
    s = String(s || "");
    return s ? s[0].toUpperCase() + s.slice(1) : s;
}

const ICONS = {
    approve: "check",
    "rerun-failed": "replay",
    "react-plus1": "thumb_up",
    "react-+1": "thumb_up",
    "resolve-thread": "check",
    resolve: "check"
};
const LABELS = {
    "react-plus1": "+1",
    "react-+1": "+1",
    "resolve-thread": "Resolve"
};
const DECK_IDS = ["mark-read", "open-junco"];

// Roles for v1/v2 actions: what does the work comes first (primary, then
// secondary); a link is a quiet button when `keepLinks`, else it becomes
// the card's `original` link; with nothing but links, the first is primary.
function roles(actions, keepLinks) {
    const work = actions.filter(a => a.type !== "url");
    const links = actions.filter(a => a.type === "url");
    const out = [];
    let original = null;
    for (const a of work)
        out.push(Object.assign({}, a, {
            role: out.length === 0 ? "primary" : "secondary",
            icon: a.icon || ICONS[a.id] || "",
            label: LABELS[a.id] || a.label
        }));
    if (!work.length && links.length)
        out.push(Object.assign({}, links.shift(), {
            role: "primary"
        }));
    for (const a of links) {
        if (keepLinks)
            out.push(Object.assign({}, a, {
                role: "quiet"
            }));
        else if (!original)
            original = {
                label: a.label,
                url: a.url
            };
    }
    return {
        actions: out,
        original: original
    };
}

// The first failing test (or error) in a CI log tail: {title, detail,
// location}. Vitest/Jest marks (✗ ×), then GitHub's ##[error] lines.
function failure(log, job, fallback) {
    const mark = /^\s*(✗|×)\s+/;
    for (let i = 0; i < log.length; i++) {
        if (!mark.test(log[i]))
            continue;
        const out = {
            title: log[i].replace(mark, "").trim(),
            detail: "",
            location: ""
        };
        const next = log[i + 1] || "";
        if (/error|expected|assert/i.test(next))
            out.detail = next.trim();
        for (const l of log.slice(i + 1, i + 4))
            if (/^\s*(❯|at )/.test(l)) {
                out.location = l.replace(/^\s*(❯|at)\s*/, "").trim();
                break;
            }
        return out;
    }
    const error = log.find(l => /##\[error\]|AssertionError|^\s*Error(?!: Process completed)/.test(l));
    return {
        title: job || fallback || "Failed",
        detail: error ? error.replace(/.*##\[error\]/, "").trim() : "",
        location: ""
    };
}

// A review comment's hunk as numbered diff lines, near the line it's on.
function hunk(context) {
    const lines = (context && context.hunk) || [];
    const out = [];
    let oldLine = 0, newLine = 0;
    for (const l of lines) {
        const m = /^@@ -(\d+)(?:,\d+)? \+(\d+)/.exec(l);
        if (m) {
            oldLine = num(m[1]);
            newLine = num(m[2]);
            continue;
        }
        const sign = l[0];
        if (sign === "+")
            out.push({
                n: newLine++,
                kind: "add",
                text: l.slice(1)
            });
        else if (sign === "-")
            out.push({
                n: oldLine++,
                kind: "del",
                text: l.slice(1)
            });
        else {
            out.push({
                n: newLine++,
                kind: "ctx",
                text: l.slice(1)
            });
            oldLine++;
        }
    }
    const at = num(context && context.line);
    const i = Math.max(0, out.findIndex(l => l.kind !== "del" && l.n >= at));
    return out.slice(Math.max(0, i - 6), i + 4);
}

const FACT_ICONS = {
    device: "computer",
    place: "location_on",
    where: "location_on",
    location: "location_on",
    city: "location_on",
    at: "schedule",
    time: "schedule",
    when: "schedule",
    event: "bolt",
    account: "account_circle",
    email: "account_circle",
    ip: "lan",
    amount: "payments",
    card: "credit_card",
    domain: "language",
    expires: "event"
};
const NOT_FACTS = ["service", "notice", "comment", "who", "jobs", "pr-title"];

function symbolOf(kind) {
    if (/security|login|sign-?in/.test(kind))
        return "shield";
    if (/payment|card|bill/.test(kind))
        return "credit_card";
    if (/domain/.test(kind))
        return "language";
    return "notifications";
}

function adapt(raw) {
    if (!raw || typeof raw !== "object")
        return raw;
    const item = Object.assign({}, raw);
    const actions = (Array.isArray(raw.actions) ? raw.actions : []).filter(a => a && a.id && a.label).map(a => Object.assign({}, a, {
                type: a.type || (a.url ? "url" : "command")
            }));
    item.deckActions = {
        markRead: actions.find(a => a.id === "mark-read") || null,
        openJunco: actions.find(a => a.id === "open-junco") || null
    };
    const rest = actions.filter(a => DECK_IDS.indexOf(a.id) < 0);
    if (raw.component) {
        item.actions = rest;
        return item;
    }

    const kind = String(raw.kind || "");
    const repo = text(raw, "repo"), pr = text(raw, "pr");
    const who = text(raw, "who") || raw.who || "";
    item.lane = kind === "ci-passed" ? "update" : "action";
    item.v2 = true;

    if (/^ci-/.test(kind)) {
        const failed = kind !== "ci-passed";
        const jobs = list(raw, "jobs").map(j => ({
                    name: j.split(" · ")[0],
                    state: failed ? "failed" : "passed"
                }));
        const log = Array.isArray(raw.log) ? raw.log.map(String) : [];
        const r = roles(rest, true);
        item.component = "StatusSummary";
        item.kind = "CI";
        item.subtitle = [repo, text(raw, "branch"), text(raw, "commit")].filter(s => s).join(" · ");
        item.sections = [{
                type: "status",
                state: failed ? "failed" : "passed",
                label: failed ? (jobs.length === 1 ? "1 job failed" : jobs.length ? `${jobs.length} jobs failed` : "Failed") : "Passed"
            }, {
                type: "jobs",
                items: jobs
            }];
        if (failed)
            item.sections.push(Object.assign({
                type: "failure"
            }, failure(log, jobs.length ? jobs[0].name : "", raw.detail)));
        if (log.length)
            item.sections.push({
                type: "log",
                lines: log
            });
        item.actions = r.actions;
        item.original = r.original;
        return item;
    }

    if (kind === "review-requested") {
        const m = raw.meta || {};
        const r = roles(rest, true);
        item.component = "ReviewPanel";
        item.kind = "Review request";
        item.title = text(raw, "pr-title") || raw.title;
        item.subtitle = [repo, pr].filter(s => s).join(" ");
        item.sections = [{
                type: "person",
                name: who,
                image: raw.image || ""
            }];
        if (m.ci)
            item.sections.push({
                type: "status",
                state: m.ci === "passing" ? "passed" : m.ci === "failing" ? "failed" : "running",
                label: `CI ${m.ci}`
            });
        if (m.base && m.head)
            item.sections.push({
                type: "branch",
                base: String(m.base),
                head: String(m.head)
            });
        if (m.additions !== undefined || m.deletions !== undefined)
            item.sections.push({
                type: "size",
                additions: num(m.additions),
                deletions: num(m.deletions)
            });
        const stats = [];
        if (m.files !== undefined)
            stats.push({
                icon: "description",
                value: num(m.files),
                label: num(m.files) === 1 ? "file" : "files"
            });
        if (m.commits !== undefined)
            stats.push({
                icon: "commit",
                value: num(m.commits),
                label: num(m.commits) === 1 ? "commit" : "commits"
            });
        if (stats.length)
            item.sections.push({
                type: "stats",
                items: stats
            });
        if (raw.body)
            item.sections.push({
                type: "text",
                text: plain(raw.body)
            });
        // Approve first: it's the work. The link stays a button here.
        item.actions = r.actions.map(a => a.type === "url" ? Object.assign({}, a, {
                role: "secondary"
            }) : a);
        return item;
    }

    if (["comment", "review-comment", "review"].indexOf(kind) >= 0) {
        const ctx = raw.context || null;
        const r = roles(rest, false);
        const thread = Array.isArray(raw.thread) ? raw.thread : [];
        item.component = "CommentPanel";
        item.kind = kind === "review-comment" ? "Review comment" : kind === "review" ? "Review" : "Comment";
        const where = ctx && ctx.file ? `on ${String(ctx.file).split("/").pop()}${ctx.line ? ":" + ctx.line : ""}` : text(raw, "pr-title");
        item.subtitle = [where, [repo, pr].filter(s => s).join(" ")].filter(s => s).join(" · ");
        item.sections = [{
                type: "person",
                name: who,
                image: raw.image || ""
            }, {
                type: "comment",
                text: plain(raw.body) || raw.summary || ""
            }];
        if (ctx && Array.isArray(ctx.hunk) && ctx.hunk.length)
            item.sections.push({
                type: "diff",
                file: `${ctx.file || ""}${ctx.line ? ":" + ctx.line : ""}`,
                lines: hunk(ctx)
            });
        if (thread.length)
            item.sections.push({
                type: "thread",
                count: thread.length,
                people: thread.map(t => ({
                            name: t.who || "",
                            image: t.avatar || ""
                        }))
            });
        item.actions = r.actions;
        item.original = r.original;
        return item;
    }

    // Alerts and anything else: what happened, big; the fields that are
    // facts (short values), as tiles; the whole message behind Details.
    const r = roles(rest, false);
    const facts = (raw.fields || []).filter(f => f && f.key && NOT_FACTS.indexOf(f.key) < 0 && f.value !== undefined && String(f.value).length <= 32).map(f => ({
                icon: FACT_ICONS[f.key] || "info",
                label: f.label || capital(f.key),
                value: Array.isArray(f.value) ? f.value.join(", ") : String(f.value)
            }));
    item.component = "Summary";
    item.kind = capital(kind.replace(/-/g, " "));
    item.symbol = raw.symbol || symbolOf(kind);
    item.title = raw.headline || raw.title;
    item.subtitle = raw.summary && raw.summary !== item.title ? raw.summary : "";
    item.sections = [];
    if (facts.length)
        item.sections.push({
            type: "facts",
            items: facts
        });
    if (raw.body)
        item.sections.push({
            type: "text",
            text: plain(raw.body)
        });
    item.actions = r.actions;
    item.original = r.original;
    return item;
}

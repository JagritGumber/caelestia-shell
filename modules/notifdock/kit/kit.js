.pragma library

// Helpers shared by the dock's component vocabulary (contract v3): times,
// tones and section lookup. Plain functions, no state.

function section(item, type) {
    const list = item && item.sections ? item.sections : [];
    for (let i = 0; i < list.length; i++)
        if (list[i] && list[i].type === type)
            return list[i];
    return null;
}

function timeOf(iso) {
    return Date.parse(iso) || 0;
}

function pad(n) {
    return n < 10 ? `0${n}` : `${n}`;
}

const DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const LONG_DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

function clock(iso) {
    const t = timeOf(iso);
    if (!t)
        return "";
    const d = new Date(t);
    return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function dayStart(t) {
    const d = new Date(t);
    d.setHours(0, 0, 0, 0);
    return d.getTime();
}

// "Today", "Tomorrow", "Yesterday", else "Thu 27 Nov".
function day(iso, now) {
    const t = timeOf(iso);
    if (!t)
        return "";
    const days = Math.round((dayStart(t) - dayStart(now)) / 86400000);
    if (days === 0)
        return "Today";
    if (days === 1)
        return "Tomorrow";
    if (days === -1)
        return "Yesterday";
    const d = new Date(t);
    return `${DAYS[d.getDay()]} ${d.getDate()} ${MONTHS[d.getMonth()]}`;
}

// A step's time: the clock today, else the weekday.
function stamp(iso, now) {
    const t = timeOf(iso);
    if (!t)
        return "";
    if (dayStart(t) === dayStart(now))
        return clock(iso);
    return DAYS[new Date(t).getDay()];
}

function longDay(iso) {
    const t = timeOf(iso);
    if (!t)
        return "";
    const d = new Date(t);
    return `${LONG_DAYS[d.getDay()]} ${d.getDate()} ${MONTHS[d.getMonth()]}`;
}

function age(iso, now) {
    const t = timeOf(iso);
    if (!t)
        return "";
    const m = Math.max(0, Math.floor((now - t) / 60000));
    if (m < 1)
        return "just now";
    if (m < 60)
        return `${m} min ago`;
    const h = Math.floor(m / 60);
    if (h < 24)
        return `${h} h ago`;
    return `${Math.floor(h / 24)} d ago`;
}

// How far off a due time is, as the coloured line under a card's head says it.
function due(iso, now) {
    const t = timeOf(iso);
    if (!t)
        return "";
    if (t < now) {
        const days = Math.round((dayStart(now) - dayStart(t)) / 86400000);
        if (days < 1)
            return `Overdue since ${clock(iso)}`;
        return days === 1 ? "1 day overdue" : `${days} days overdue`;
    }
    const days = Math.round((dayStart(t) - dayStart(now)) / 86400000);
    if (days === 0)
        return `Today ${clock(iso)}`;
    if (days === 1)
        return `Tomorrow ${clock(iso)}`;
    return `${day(iso, now)} · in ${days} days`;
}

function minutes(mins) {
    if (mins < 60)
        return `${mins} min`;
    const h = Math.floor(mins / 60), m = mins % 60;
    return m ? `${h} h ${m} min` : `${h} h`;
}

// A tone name from the feed to the scheme's colour (p: Colours.palette).
// Urgency ("critical", "warn", "upcoming") is a scheme accent; the error
// colour is only for something that failed ("error", "failed"), and the
// cards keep it to small marks.
function tone(p, name) {
    switch (name) {
    case "error":
    case "failed":
        return p.m3error;
    case "critical":
        return p.m3tertiary;
    case "success":
    case "passed":
    case "done":
        return p.m3success;
    case "primary":
    case "action":
        return p.m3primary;
    case "tertiary":
    case "upcoming":
    case "warn":
        return p.m3tertiary;
    default:
        return p.m3onSurfaceVariant;
    }
}

// Faces get one of four container colours, fixed per name.
function hue(name) {
    let h = 0;
    const s = String(name || "");
    for (let i = 0; i < s.length; i++)
        h = (h * 31 + s.charCodeAt(i)) >>> 0;
    return h % 4;
}

function initials(name) {
    return String(name || "").replace(/^@/, "").split(/[\s._-]+/).filter(w => w).slice(0, 2).map(w => w[0].toUpperCase()).join("");
}

function money(value, currency) {
    const n = Number(value);
    if (!isFinite(n))
        return String(value || "");
    const symbols = {
        INR: "₹",
        USD: "$",
        EUR: "€",
        GBP: "£"
    };
    const whole = Math.round(n).toString();
    // Indian grouping for rupees (18,240 / 1,18,240), thousands otherwise.
    let grouped;
    if (currency === "INR" && whole.length > 3) {
        const last = whole.slice(-3);
        grouped = whole.slice(0, -3).replace(/\B(?=(\d{2})+(?!\d))/g, ",") + "," + last;
    } else {
        grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    }
    return `${symbols[currency] || ""}${grouped}`;
}

// How much room a card gets in the shelf: its width, and whether it takes
// the shelf's full height or half (two halves stack in one column).
const SIZES = {
    DecisionPanel: [500, "full"],
    ReviewPanel: [460, "full"],
    SchedulingPanel: [580, "full"],
    CommentPanel: [440, "full"],
    StatusSummary: [420, "full"],
    Timeline: [380, "half"],
    DataTable: [380, "half"],
    Summary: [360, "half"]
};

function size(item) {
    let s = SIZES[item && item.component] || SIZES.Summary;
    const status = section(item, "status");
    if (item && item.component === "StatusSummary" && status && status.state === "passed")
        s = [380, "half"];
    // Numbers with something to do about them (a bill to pay) get the room
    // for their buttons; numbers to know (a payment in) stay small.
    if (item && item.component === "DataTable" && (item.actions || []).length > 0)
        s = [380, "full"];
    return {
        width: s[0],
        span: s[1]
    };
}

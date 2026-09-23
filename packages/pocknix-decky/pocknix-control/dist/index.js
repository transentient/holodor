const manifest = {"name":"Pocknix Control"};
const API_VERSION = 2;
const internalAPIConnection = window.__DECKY_SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED_deckyLoaderAPIInit;
if (!internalAPIConnection) {
    throw new Error('[@decky/api]: Failed to connect to the loader as as the loader API was not initialized. This is likely a bug in Decky Loader.');
}
let api;
try {
    api = internalAPIConnection.connect(API_VERSION, manifest.name);
}
catch {
    api = internalAPIConnection.connect(1, manifest.name);
    console.warn(`[@decky/api] Requested API version ${API_VERSION} but the running loader only supports version 1. Some features may not work.`);
}
if (api._version != API_VERSION) {
    console.warn(`[@decky/api] Requested API version ${API_VERSION} but the running loader only supports version ${api._version}. Some features may not work.`);
}
const call = api.call;
const toaster = api.toaster;
const openFilePicker = api.openFilePicker;
const definePlugin = (fn) => {
    return (...args) => {
        return fn(...args);
    };
};

const getConfig = () => call("get_config");
const setFanMode = (mode) => call("set_fan_mode", mode);
const saveFanCurve = (name, label, curve) => call("save_fan_curve", name, label, curve);
const deleteFanCurve = (name) => call("delete_fan_curve", name);
const getFanStatus = () => call("fan_status");
const setPowerMode = (mode) => call("set_power_mode", mode);
const setChargeLimit = (pct) => call("set_charge_limit", pct);
const setLedColor = (hex) => call("set_led_color", hex);
const setLedMode = (mode) => call("set_led_mode", mode);
const setDownloadInhibitMode = (mode) => call("set_download_inhibit_mode", mode);
const setLavdMode = (mode) => call("set_lavd_mode", mode);
const saveTweaks = (data) => call("save_tweaks", data);
const detectSdcard = () => call("detect_sdcard");
const formatSdcard = (label) => call("format_sdcard", label);
const checkUpdates = () => call("check_updates");
const startUpdate = () => call("start_update");
const updateStatus = () => call("update_status");

function useDebouncedSave(options) {
    const { config, field, snapshot, save, setConfig, onError, delay = 900 } = options;
    const value = config ? config[field] : undefined;
    // Latest unsaved edit; written by the debounce timer or the unmount flush below.
    const pending = SP_REACT.useRef(null);
    const flush = SP_REACT.useCallback(async () => {
        const entry = pending.current;
        if (!entry)
            return;
        pending.current = null;
        try {
            const next = await save(entry.value);
            snapshot.current = JSON.stringify(next[field]);
            setConfig((stored) => {
                if (!stored)
                    return next;
                if (JSON.stringify(stored[field]) !== entry.serialized)
                    return stored;
                return { ...stored, [field]: next[field] };
            });
        }
        catch (error) {
            onError?.(error);
        }
    }, [save, field, snapshot, setConfig, onError]);
    const flushRef = SP_REACT.useRef(flush);
    flushRef.current = flush;
    SP_REACT.useEffect(() => {
        if (!config || !snapshot.current)
            return;
        const current = JSON.stringify(value);
        if (current === snapshot.current) {
            pending.current = null;
            return;
        }
        pending.current = { value, serialized: current };
        const timer = window.setTimeout(() => flushRef.current(), delay);
        return () => window.clearTimeout(timer);
    }, [value]);
    // QAM panels unmount the moment the menu closes. The cleanup above clears the only
    // pending timer, so without this unmount flush any edit made <delay ms before closing
    // was silently dropped (how the first on-device Audio Buffer edit got lost, 2026-07-05).
    SP_REACT.useEffect(() => () => void flushRef.current(), []);
}

function Icon({ path }) {
    return (SP_JSX.jsx("svg", { style: { display: "block" }, width: "20", height: "20", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: "2", strokeLinecap: "round", strokeLinejoin: "round", children: path }));
}
const tabIcons = {
    Games: (SP_JSX.jsx(Icon, { path: SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx("line", { x1: "6", x2: "10", y1: "11", y2: "11" }), SP_JSX.jsx("line", { x1: "8", x2: "8", y1: "9", y2: "13" }), SP_JSX.jsx("line", { x1: "15", x2: "15.01", y1: "12", y2: "12" }), SP_JSX.jsx("line", { x1: "18", x2: "18.01", y1: "10", y2: "10" }), SP_JSX.jsx("path", { d: "M17.32 5H6.68a4 4 0 0 0-3.978 3.59c-.006.052-.01.101-.017.152C2.604 9.416 2 14.456 2 16a3 3 0 0 0 3 3c1 0 1.5-.5 2-1l1.414-1.414A2 2 0 0 1 9.828 16h4.344a2 2 0 0 1 1.414.586L17 18c.5.5 1 1 2 1a3 3 0 0 0 3-3c0-1.545-.604-6.584-.685-7.258-.007-.05-.011-.1-.017-.151A4 4 0 0 0 17.32 5z" })] }) })),
    Power: (SP_JSX.jsx(Icon, { path: SP_JSX.jsx(SP_JSX.Fragment, { children: SP_JSX.jsx("path", { d: "M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z" }) }) })),
    Updater: (SP_JSX.jsx(Icon, { path: SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx("path", { d: "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" }), SP_JSX.jsx("polyline", { points: "7 10 12 15 17 10" }), SP_JSX.jsx("line", { x1: "12", x2: "12", y1: "15", y2: "3" })] }) })),
    Storage: (SP_JSX.jsx(Icon, { path: SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx("line", { x1: "22", x2: "2", y1: "12", y2: "12" }), SP_JSX.jsx("path", { d: "M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z" }), SP_JSX.jsx("line", { x1: "6", x2: "6.01", y1: "16", y2: "16" }), SP_JSX.jsx("line", { x1: "10", x2: "10.01", y1: "16", y2: "16" })] }) })),
};

function gameDisplayName(game) {
    if (!game?.appid)
        return "";
    return game.name || `App ${game.appid}`;
}
// The backend lists every appmanifest in steamapps, which includes tools (Proton, Steam Linux
// Runtime, Steamworks Common Redistributables, …). Steam's own appStore overview knows the type
// (app_type 1 = game, 4 = tool); fall back to name patterns when the overview isn't available.
const NON_GAME_NAME = /^(Proton[ 0-9]|Proton (Hotfix|EasyAntiCheat|BattlEye)|Steam Linux Runtime|Steamworks Common)/i;
function isGame(appid, name) {
    try {
        const overview = window.appStore?.GetAppOverviewByAppID?.(Number(appid));
        if (typeof overview?.app_type === "number")
            return overview.app_type !== 4;
    }
    catch (error) {
    }
    return !NON_GAME_NAME.test(name);
}
// Non-Steam shortcuts have no appmanifest, so the backend scan can't see them; Steam's
// deckDesktopApps collection holds their appids (unsigned; force with >>> in case a build
// hands out the signed-int32 form) and appStore resolves the names.
function nonSteamShortcuts() {
    try {
        const ids = window.collectionStore?.deckDesktopApps?.apps;
        if (!ids?.values)
            return [];
        const shortcuts = [];
        for (const id of Array.from(ids.values())) {
            const appid = String(Number(id) >>> 0);
            if (!appid || appid === "0")
                continue;
            let name = "";
            try {
                name = window.appStore?.GetAppOverviewByAppID?.(Number(appid))?.display_name || "";
            }
            catch (error) {
            }
            shortcuts.push({ appid, name: name || `App ${appid}`, nonSteam: true });
        }
        return shortcuts;
    }
    catch (error) {
        return [];
    }
}
function availableGames(config) {
    const games = new Map();
    for (const game of config.installedGames || []) {
        if (game?.appid && isGame(String(game.appid), game.name || "")) {
            games.set(String(game.appid), { appid: String(game.appid), name: game.name || `App ${game.appid}` });
        }
    }
    for (const shortcut of nonSteamShortcuts()) {
        games.set(shortcut.appid, shortcut);
    }
    // Games with saved tweaks stay listed even if the lookups above miss them —
    // existing per-game config must remain reachable. Shortcut appids sit above 2^31.
    for (const [appid, game] of Object.entries(config.tweaks?.games || {})) {
        if (game && typeof game === "object" && !games.has(String(appid))) {
            games.set(String(appid), { appid: String(appid), name: game.name || `App ${appid}`, nonSteam: Number(appid) >= 0x80000000 });
        }
    }
    return Array.from(games.values()).sort((a, b) => (a.nonSteam ? 1 : 0) - (b.nonSteam ? 1 : 0) || gameDisplayName(a).localeCompare(gameDisplayName(b)));
}
function editTargetOptions(config) {
    return [
        { data: "", label: "Default" },
        ...availableGames(config).map((game) => ({
            data: game.appid,
            label: game.nonSteam ? `${gameDisplayName(game)} · non-Steam` : gameDisplayName(game),
        })),
    ];
}
function currentGame() {
    const running = DFL.Router?.MainRunningApp || window.Router?.MainRunningApp;
    const appid = running?.appid;
    if (!appid)
        return null;
    const id = String(appid);
    let name = running?.display_name || running?.displayName || "";
    try {
        const details = window.appDetailsStore?.GetAppDetails?.(Number(id));
        name = details?.strDisplayName || details?.strName || details?.name || name;
    }
    catch (error) {
    }
    return { appid: id, name: name || `App ${id}` };
}

const styles = `
      .pocknix-control-tabs {
        height: 95%;
        width: 316px;
        position: fixed;
        margin-top: -12px;
        margin-left: -8px;
        overflow: hidden;
      }
      .pocknix-control-tabs > div > div:first-child::before {
        background: #0D141C;
        box-shadow: none;
        backdrop-filter: none;
      }
      .pocknix-control-tabs [role="tabpanel"] {
        padding-left: 0 !important;
        padding-right: 0 !important;
      }
      .pocknix-control-tabs .pocknix-control-tab-content {
        padding-bottom: 24px;
      }
      .pocknix-control-tabs .pocknix-log {
        font-family: monospace;
        font-size: 10px;
        line-height: 14px;
        word-break: break-all;
        white-space: pre-wrap;
      }
      .pk-fan-graph {
        margin: 6px 16px 2px;
        padding: 4px;
        border-radius: 6px;
        border: 2px solid transparent;
      }
      .pocknix-control-tabs-modal .pk-fan-graph {
        max-width: 480px;
        margin: 4px auto;
      }
      .pk-fan-graph-focused {
        border-color: rgba(255,255,255,0.6);
      }
      .pk-fan-graph-editing {
        border-color: #ffd166;
      }
      .pk-fan-hint, .pocknix-control-tabs-modal .pocknix-note {
        padding: 4px 8px;
        font-size: 12px;
        line-height: 16px;
        opacity: 0.7;
      }
      .pk-fan-title {
        margin: 0 0 8px 16px;
        font-size: 18px;
      }
      .pk-fan-error {
        margin: 4px 16px;
        color: #ff6b6b;
        font-size: 12px;
      }
      .pocknix-control-tabs .pocknix-note {
        box-sizing: border-box;
        width: 100%;
        padding: 8px 16px 8px;
        font-size: 12px;
        line-height: 16px;
        opacity: 0.62;
        text-align: left;
        justify-content: flex-start;
        align-self: stretch;
      }
    `;

// Non-Steam shortcut creation via SteamClient.Apps. The Steam file browser can't open a
// new window under the Plasma Mobile X11 session, so Decky's in-UI file picker plus this
// module replace the stock "Add a Non-Steam Game" flow.
const WINDOWS_EXE = /\.(exe|bat|msi)$/i;
// Constant internal name from proton-cachyos' compatibilitytool.vdf; survives version bumps.
const PROTON_TOOL = "proton-cachyos";
function isWindowsExe(path) {
    return WINDOWS_EXE.test(path);
}
function defaultShortcutName(path) {
    const base = path.split("/").pop() || path;
    const cleaned = base.replace(/\.[^.]+$/, "").replace(/_+/g, " ").trim();
    return cleaned || base;
}
const quote = (value) => `"${value.replace(/"/g, '\\"')}"`;
async function addShortcut(name, path, useProton) {
    const apps = window.SteamClient?.Apps;
    if (!apps?.AddShortcut)
        throw new Error("Steam shortcut API unavailable");
    const dir = path.slice(0, path.lastIndexOf("/") + 1) || "/";
    const appId = await apps.AddShortcut(name, path, "", "");
    if (typeof appId !== "number" || !appId)
        throw new Error("Steam refused to create the shortcut");
    apps.SetShortcutName?.(appId, name);
    apps.SetShortcutExe?.(appId, quote(path));
    apps.SetShortcutStartDir?.(appId, quote(dir));
    if (useProton)
        apps.SpecifyCompatTool?.(appId, PROTON_TOOL);
    return appId;
}

function AddGameModal({ path, closeModal }) {
    const [name, setName] = SP_REACT.useState(defaultShortcutName(path));
    const [proton, setProton] = SP_REACT.useState(isWindowsExe(path));
    const [busy, setBusy] = SP_REACT.useState(false);
    const submit = async () => {
        if (busy || !name.trim())
            return;
        setBusy(true);
        try {
            await addShortcut(name.trim(), path, proton);
            toaster.toast({ title: "Added to library", body: name.trim() });
            closeModal?.();
        }
        catch (error) {
            toaster.toast({ title: "Could not add game", body: String(error) });
            setBusy(false);
        }
    };
    return (SP_JSX.jsxs(DFL.ConfirmModal, { strTitle: "Add Non-Steam Game", strDescription: path, strOKButtonText: busy ? "Adding…" : "Add to Library", bOKDisabled: busy || !name.trim(), onCancel: () => closeModal?.(), onOK: submit, children: [SP_JSX.jsx(DFL.TextField, { label: "Name", value: name, disabled: busy, onChange: (event) => setName(event.target.value) }), SP_JSX.jsx(DFL.ToggleField, { label: "Launch with Proton", description: "Needed for Windows games (.exe)", checked: proton, disabled: busy, onChange: setProton })] }));
}
function AddGameSection() {
    const pick = async () => {
        try {
            // 0 = FileSelectionType.FILE (const enum in @decky/api typings, no runtime export).
            const result = await openFilePicker(0, "/home/deck", true, true);
            if (result?.path)
                DFL.showModal(SP_JSX.jsx(AddGameModal, { path: result.path }));
        }
        catch (error) {
            // Picker closed without a selection.
        }
    };
    return (SP_JSX.jsxs(DFL.PanelSection, { title: "LIBRARY", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: pick, children: "Add Non-Steam Game" }) }), SP_JSX.jsx("div", { className: "pocknix-note", children: "Pick an executable to add it to your Steam library" })] }));
}

function SelectEdit({ label, value, options, onChange }) {
    const rgOptions = options.map((option) => (typeof option === "string" ? { data: option, label: option } : option));
    return (SP_JSX.jsx(DFL.PanelSectionRow, { children: label === undefined ? (SP_JSX.jsx(DFL.Dropdown, { selectedOption: value, rgOptions: rgOptions, onChange: (option) => onChange(option.data) })) : (SP_JSX.jsx(DFL.DropdownItem, { label: label, selectedOption: value, rgOptions: rgOptions, onChange: (option) => onChange(option.data) })) }));
}
/** True when a check/glyph drawn over #RRGGBB needs to be dark to stay readable. */
function isBright(hex) {
    const n = parseInt(hex, 16);
    if (Number.isNaN(n))
        return false;
    const r = (n >> 16) & 0xff, g = (n >> 8) & 0xff, b = n & 0xff;
    return 0.299 * r + 0.587 * g + 0.114 * b > 150;
}
/**
 * Row of preset color swatches. Steam's gamepad focus style repaints button
 * backgrounds, so each swatch keeps its color inline (inline beats the class)
 * and shows focus via its own border + selection via a check glyph.
 */
function ColorPalette({ colors, value, onChange }) {
    const [focused, setFocused] = SP_REACT.useState(null);
    return (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Focusable, { style: { display: "flex", flexWrap: "wrap", gap: "8px", padding: "6px 0" }, children: colors.map(({ data, label }) => (SP_JSX.jsx(DFL.DialogButton, { onClick: () => onChange(data), onGamepadFocus: () => setFocused(data), onGamepadBlur: () => setFocused((current) => (current === data ? null : current)), style: {
                    width: "30px",
                    minWidth: "30px",
                    height: "30px",
                    padding: 0,
                    borderRadius: "15px",
                    backgroundColor: `#${data}`,
                    border: focused === data ? "2px solid #ffffff" : "2px solid rgba(255,255,255,0.25)",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    fontSize: "16px",
                    lineHeight: "1",
                    color: isBright(data) ? "#000000" : "#ffffff",
                }, children: value === data ? "✓" : "" }, data))) }) }));
}

function clone(obj) {
    return JSON.parse(JSON.stringify(obj));
}

// Audio buffer (PULSE_LATENCY_MSEC): absorbs FEX-mixer overruns (SFX-burst crackle) at the
// cost of audio latency — keep rhythm games on Game default. 60 measured ~10x fewer underruns.
const audioLatencyOptions = [
    { data: "", label: "Game default" },
    { data: "60", label: "60 ms" },
    { data: "90", label: "90 ms" },
    { data: "120", label: "120 ms" },
];
// Per-flag FEX toggles (Armada Control parity). Order and labels match their
// panel; each overrides the selected preset's value for that flag only.
const lsfgMultiplierOptions = [
    { data: "2", label: "2x (recommended)" },
    { data: "3", label: "3x" },
    { data: "4", label: "4x" },
];
const fexFlagDefs = [
    { key: "TSOEnabled", label: "TSO Enabled" },
    { key: "X87ReducedPrecision", label: "X87 Reduced Precision" },
    { key: "Multiblock", label: "Multiblock" },
    { key: "VectorTSOEnabled", label: "Vector TSO Enabled" },
    { key: "MemcpySetTSOEnabled", label: "Memcpy Set TSO Enabled" },
    { key: "HalfBarrierTSOEnabled", label: "Half Barrier TSO Enabled" },
];
function Games({ config, setConfig }) {
    const runtimeGame = config.game;
    const games = availableGames(config);
    const game = config.selectedGame || runtimeGame || null;
    const tweaks = config.tweaks;
    const gameSettings = game?.appid ? tweaks.games[game.appid] || {} : {};
    const editingDefault = !game?.appid;
    const perGameEnabled = !!(game?.appid && gameSettings.enabled === true);
    const values = editingDefault || !perGameEnabled ? tweaks.global : { ...tweaks.global, ...gameSettings };
    const patchSettings = (patch) => {
        setConfig((current) => {
            if (!current)
                return current;
            const next = clone(current);
            if (editingDefault) {
                Object.assign(next.tweaks.global, patch);
            }
            else if (perGameEnabled) {
                const existing = next.tweaks.games[game.appid] || {};
                next.tweaks.games[game.appid] = { ...existing, enabled: true, name: game.name || "", ...patch };
            }
            return next;
        });
    };
    const setPerGameEnabled = (enabled) => {
        if (!game?.appid)
            return;
        setConfig((current) => {
            if (!current)
                return current;
            const next = clone(current);
            next.tweaks.games[game.appid] = {
                ...(next.tweaks.games[game.appid] || {}),
                enabled,
                name: game.name || "",
            };
            return next;
        });
    };
    // "" is the explicit Default target, not "nothing selected"; store a sentinel
    // so it doesn't fall back to the running game in the selectedGame derivation.
    const setSelectedGame = (appid) => {
        const id = String(appid);
        if (!id) {
            setConfig((current) => (current ? { ...current, selectedGame: { appid: "", name: "Default" } } : current));
            return;
        }
        const saved = games.find((candidate) => candidate.appid === id);
        setConfig((current) => (current ? { ...current, selectedGame: saved || null } : current));
    };
    const presets = config.fexProfiles || {};
    const storedProfile = values.fexProfile;
    const fexValue = storedProfile && presets[storedProfile] ? storedProfile : "default";
    const fexOptions = Object.entries(presets).map(([id, profile]) => ({ data: id, label: profile.label }));
    const storedLatency = String(values.audioLatency ?? "");
    const audioValue = audioLatencyOptions.some((option) => option.data === storedLatency) ? storedLatency : "";
    const lsfgSettings = (values.lsfg || {});
    const lsfgEnabled = lsfgSettings.enabled === true;
    const lsfgMultiplier = ["2", "3", "4"].includes(String(lsfgSettings.multiplier)) ? String(lsfgSettings.multiplier) : "2";
    const presetConfig = presets[fexValue]?.config || {};
    const flagOverrides = (values.fexFlags || {});
    const effectiveFlag = (key) => (flagOverrides[key] ?? presetConfig[key] ?? "0") === "1";
    const setFlag = (key, on) => {
        const next = { ...flagOverrides };
        const presetValue = presetConfig[key] ?? "0";
        const wanted = on ? "1" : "0";
        // Store only real deviations; matching the preset removes the override so
        // preset switches keep working predictably.
        if (wanted === presetValue)
            delete next[key];
        else
            next[key] = wanted;
        patchSettings({ fexFlags: next });
    };
    return (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsxs(DFL.PanelSection, { title: "GAME TWEAKS", children: [SP_JSX.jsx(SelectEdit, { label: "Game", value: game?.appid || "", options: editTargetOptions(config), onChange: setSelectedGame }), SP_JSX.jsx("div", { className: "pocknix-note", children: "Changes apply on next game launch" }), !editingDefault ? SP_JSX.jsx(DFL.ToggleField, { label: "Use Per-Game Settings", checked: perGameEnabled, onChange: setPerGameEnabled }) : null, editingDefault || perGameEnabled ? (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx(SelectEdit, { label: "FEX Preset", value: fexValue, options: fexOptions, onChange: (id) => patchSettings({ fexProfile: id, fexFlags: {} }) }), SP_JSX.jsx(SelectEdit, { label: "Audio Buffer", value: audioValue, options: audioLatencyOptions, onChange: (id) => patchSettings({ audioLatency: id }) }), SP_JSX.jsx(DFL.ToggleField, { label: "Frame Insertion (LSFG)", description: "Doubles presented fps by interpolation. Needs Lossless Scaling installed from Steam. Adds a little input latency.", checked: lsfgEnabled, onChange: (on) => patchSettings({ lsfg: { ...lsfgSettings, enabled: on } }) }), lsfgEnabled ? (SP_JSX.jsx(SelectEdit, { label: "Insertion Multiplier", value: lsfgMultiplier, options: lsfgMultiplierOptions, onChange: (m) => patchSettings({ lsfg: { ...lsfgSettings, enabled: true, multiplier: String(m) } }) })) : null, SP_JSX.jsxs("div", { className: "pocknix-note", children: ["Advanced FEX flags", Object.keys(flagOverrides).length ? " (modified)" : ""] }), fexFlagDefs.map(({ key, label }) => (SP_JSX.jsx(DFL.ToggleField, { label: label, checked: effectiveFlag(key), onChange: (on) => setFlag(key, on) }, key)))] })) : null] }), SP_JSX.jsx(AddGameSection, {})] }));
}

const TEMP_MIN = 0;
const TEMP_MAX = 120;
const PWM_MIN = 0;
const PWM_MAX = 255;
const MAX_POINTS = 16;
const DEFAULT_POINT = { temp: 60, pwm: 128 };
const clamp = (value, min, max) => Math.min(max, Math.max(min, value));
const pwmToPercent = (pwm) => Math.round((clamp(pwm, PWM_MIN, PWM_MAX) / PWM_MAX) * 100);
const percentToPwm = (percent) => Math.round((clamp(percent, 0, 100) / 100) * PWM_MAX);
function parseCurve(text) {
    if (!text)
        return [];
    return text
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean)
        .map((item) => {
        const [tempPart, pwmPart] = item.split(":");
        return { temp: parseInt(tempPart, 10), pwm: parseInt(pwmPart, 10) };
    })
        .filter((point) => Number.isFinite(point.temp) && Number.isFinite(point.pwm))
        .sort((a, b) => a.temp - b.temp);
}
function formatCurve(points) {
    return [...points]
        .sort((a, b) => a.temp - b.temp)
        .map((point) => `${Math.round(point.temp)}:${Math.round(point.pwm)}`)
        .join(",");
}
/** What the daemon will do at a given temperature (linear between points, flat outside). */
function interpolate(points, temp) {
    const sorted = [...points].sort((a, b) => a.temp - b.temp);
    if (!sorted.length)
        return 0;
    const first = sorted[0];
    const last = sorted[sorted.length - 1];
    if (temp <= first.temp)
        return first.pwm;
    if (temp >= last.temp)
        return last.pwm;
    for (let i = 0; i < sorted.length - 1; i += 1) {
        const a = sorted[i];
        const b = sorted[i + 1];
        if (temp >= a.temp && temp <= b.temp) {
            const t = b.temp === a.temp ? 0 : (temp - a.temp) / (b.temp - a.temp);
            return a.pwm + t * (b.pwm - a.pwm);
        }
    }
    return last.pwm;
}
/** Curve file names: lowercase letters, digits, underscores; must start with a letter. */
function slugifyCurveName(value) {
    const slug = value
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9_]+/g, "_")
        .replace(/^_+|_+$/g, "")
        .replace(/^[^a-z]+/, "")
        .slice(0, 32);
    return slug;
}

const WIDTH = 280;
const HEIGHT = 150;
const PAD_LEFT = 26;
const PAD_RIGHT = 8;
const PAD_TOP = 10;
const PAD_BOTTOM = 16;
const PLOT_W = WIDTH - PAD_LEFT - PAD_RIGHT;
const PLOT_H = HEIGHT - PAD_TOP - PAD_BOTTOM;
const TEMP_TICKS = [0, 20, 40, 60, 80, 100, 120];
const PWM_TICK_PERCENTS = [0, 25, 50, 75, 100];
const DPAD_TEMP_STEP = 1;
const DPAD_PWM_STEP = 5;
const xForTemp = (temp) => PAD_LEFT + ((clamp(temp, TEMP_MIN, TEMP_MAX) - TEMP_MIN) / (TEMP_MAX - TEMP_MIN)) * PLOT_W;
const yForPwm = (pwm) => PAD_TOP + (1 - (clamp(pwm, PWM_MIN, PWM_MAX) - PWM_MIN) / (PWM_MAX - PWM_MIN)) * PLOT_H;
function FanCurveGraph({ points, onChange, currentTemp, selectedIndex, onSelect }) {
    const editable = !!onChange;
    const svgRef = SP_REACT.useRef(null);
    const dragRef = SP_REACT.useRef(null);
    const [livePoints, setLivePoints] = SP_REACT.useState(null);
    const [padActive, setPadActive] = SP_REACT.useState(false);
    const shown = livePoints ?? points;
    const sorted = SP_REACT.useMemo(() => [...shown].sort((a, b) => a.temp - b.temp), [shown]);
    if (!sorted.length)
        return null;
    const selected = clamp(selectedIndex ?? 0, 0, points.length - 1);
    const eventToPoint = (e) => {
        const svg = svgRef.current;
        if (!svg)
            return null;
        const rect = svg.getBoundingClientRect();
        const fracX = clamp((e.clientX - rect.left) / rect.width, 0, 1);
        const fracY = clamp((e.clientY - rect.top) / rect.height, 0, 1);
        const temp = Math.round(TEMP_MIN + clamp((fracX * WIDTH - PAD_LEFT) / PLOT_W, 0, 1) * (TEMP_MAX - TEMP_MIN));
        const pwm = Math.round(PWM_MAX - clamp((fracY * HEIGHT - PAD_TOP) / PLOT_H, 0, 1) * (PWM_MAX - PWM_MIN));
        return { temp, pwm };
    };
    const onPointerDown = (index) => (e) => {
        if (!editable)
            return;
        e.currentTarget.setPointerCapture(e.pointerId);
        dragRef.current = { points: points.map((p) => ({ ...p })), index };
        onSelect?.(index);
        setLivePoints(points.map((p) => ({ ...p })));
    };
    const onPointerMove = (e) => {
        const drag = dragRef.current;
        if (!drag)
            return;
        const next = eventToPoint(e);
        if (!next)
            return;
        drag.points[drag.index] = next;
        setLivePoints([...drag.points]);
    };
    const endDrag = (e) => {
        const drag = dragRef.current;
        if (!drag)
            return;
        dragRef.current = null;
        setLivePoints(null);
        onChange?.(drag.points);
        try {
            e.currentTarget.releasePointerCapture(e.pointerId);
        }
        catch {
            // already released
        }
    };
    const movePoint = (deltaTemp, deltaPwm) => {
        if (!editable || !points.length)
            return;
        const ordered = [...points].sort((a, b) => a.temp - b.temp);
        const current = ordered[selected];
        const lower = selected > 0 ? ordered[selected - 1].temp + 1 : TEMP_MIN;
        const upper = selected < ordered.length - 1 ? ordered[selected + 1].temp - 1 : TEMP_MAX;
        const nextTemp = clamp(current.temp + deltaTemp, Math.max(TEMP_MIN, lower), Math.min(TEMP_MAX, upper));
        const nextPwm = clamp(current.pwm + deltaPwm, PWM_MIN, PWM_MAX);
        if (nextTemp === current.temp && nextPwm === current.pwm)
            return;
        onChange?.(ordered.map((point, i) => (i === selected ? { temp: nextTemp, pwm: nextPwm } : point)));
    };
    const onButtonDown = (e) => {
        switch (e.detail.button) {
            case DFL.GamepadButton.BUMPER_LEFT:
                onSelect?.((selected - 1 + points.length) % points.length);
                break;
            case DFL.GamepadButton.BUMPER_RIGHT:
                onSelect?.((selected + 1) % points.length);
                break;
            default: return;
        }
        e.preventDefault();
        e.stopPropagation();
    };
    const onDirection = (e) => {
        switch (e.detail.button) {
            case DFL.GamepadButton.DIR_UP:
                movePoint(0, DPAD_PWM_STEP);
                break;
            case DFL.GamepadButton.DIR_DOWN:
                movePoint(0, -DPAD_PWM_STEP);
                break;
            case DFL.GamepadButton.DIR_RIGHT:
                movePoint(DPAD_TEMP_STEP, 0);
                break;
            case DFL.GamepadButton.DIR_LEFT:
                movePoint(-DPAD_TEMP_STEP, 0);
                break;
            default: return;
        }
        e.preventDefault();
        e.stopPropagation();
    };
    const first = sorted[0];
    const last = sorted[sorted.length - 1];
    const pathD = [
        `M ${PAD_LEFT} ${yForPwm(first.pwm)}`,
        `L ${xForTemp(first.temp)} ${yForPwm(first.pwm)}`,
        ...sorted.slice(1).map((p) => `L ${xForTemp(p.temp)} ${yForPwm(p.pwm)}`),
        `L ${PAD_LEFT + PLOT_W} ${yForPwm(last.pwm)}`,
    ].join(" ");
    const hasTemp = typeof currentTemp === "number" && Number.isFinite(currentTemp);
    const tempX = hasTemp ? xForTemp(currentTemp) : 0;
    const tempY = hasTemp ? yForPwm(interpolate(sorted, currentTemp)) : 0;
    const svg = (SP_JSX.jsxs("svg", { ref: svgRef, viewBox: `0 0 ${WIDTH} ${HEIGHT}`, style: { width: "100%", height: "auto", display: "block", touchAction: "none", userSelect: "none" }, children: [SP_JSX.jsx("rect", { x: PAD_LEFT, y: PAD_TOP, width: PLOT_W, height: PLOT_H, fill: "rgba(255,255,255,0.04)", stroke: "rgba(255,255,255,0.15)" }), PWM_TICK_PERCENTS.map((percent) => (SP_JSX.jsxs("g", { children: [SP_JSX.jsx("line", { x1: PAD_LEFT, x2: PAD_LEFT + PLOT_W, y1: yForPwm(percentToPwm(percent)), y2: yForPwm(percentToPwm(percent)), stroke: "rgba(255,255,255,0.08)" }), SP_JSX.jsx("text", { x: PAD_LEFT - 4, y: yForPwm(percentToPwm(percent)) + 3, fontSize: "7", textAnchor: "end", fill: "rgba(255,255,255,0.55)", children: `${percent}%` })] }, `pwm-${percent}`))), TEMP_TICKS.map((temp) => (SP_JSX.jsxs("g", { children: [SP_JSX.jsx("line", { x1: xForTemp(temp), x2: xForTemp(temp), y1: PAD_TOP, y2: PAD_TOP + PLOT_H, stroke: "rgba(255,255,255,0.06)" }), SP_JSX.jsx("text", { x: xForTemp(temp), y: HEIGHT - 4, fontSize: "7", textAnchor: "middle", fill: "rgba(255,255,255,0.55)", children: temp })] }, `temp-${temp}`))), SP_JSX.jsx("path", { d: pathD, fill: "none", stroke: "#5cc8ff", strokeWidth: 2 }), hasTemp ? (SP_JSX.jsxs("g", { pointerEvents: "none", children: [SP_JSX.jsx("circle", { cx: tempX, cy: tempY, r: 7, fill: "rgba(255,255,255,0.18)" }), SP_JSX.jsx("circle", { cx: tempX, cy: tempY, r: 3.5, fill: "#ffffff", stroke: "#0D141C", strokeWidth: 1.5 }), SP_JSX.jsx("text", { x: clamp(tempX, PAD_LEFT + 14, PAD_LEFT + PLOT_W - 14), y: tempY - 10 < PAD_TOP ? tempY + 15 : tempY - 10, fontSize: "7", textAnchor: "middle", fill: "#ffffff", children: `${currentTemp}°C` })] })) : null, sorted.map((point, index) => {
                const isActive = editable && (livePoints ? dragRef.current?.index === index : padActive && index === selected);
                const cx = xForTemp(point.temp);
                const cy = yForPwm(point.pwm);
                return (SP_JSX.jsxs("g", { children: [editable ? (SP_JSX.jsx("circle", { cx: cx, cy: cy, r: 14, fill: "transparent", onPointerDown: onPointerDown(index), onPointerMove: onPointerMove, onPointerUp: endDrag, onPointerCancel: endDrag, style: { cursor: "grab", touchAction: "none" } })) : null, SP_JSX.jsx("circle", { cx: cx, cy: cy, r: isActive ? 6 : 4.5, fill: isActive ? "#ffd166" : "#5cc8ff", stroke: "#0D141C", strokeWidth: 1.5, pointerEvents: "none" }), isActive ? (SP_JSX.jsx("text", { x: cx, y: cy - 12 < PAD_TOP ? cy + 14 : cy - 12, fontSize: "8", textAnchor: "middle", fill: "#ffd166", children: `${point.temp}°C / ${pwmToPercent(point.pwm)}%` })) : null] }, `point-${index}`));
            })] }));
    if (!editable)
        return SP_JSX.jsx("div", { className: "pk-fan-graph", children: svg });
    return (SP_JSX.jsxs(DFL.Focusable, { className: padActive ? "pk-fan-graph pk-fan-graph-editing" : "pk-fan-graph", focusClassName: "pk-fan-graph-focused", onActivate: () => setPadActive(true), onOKButton: () => setPadActive(true), onCancelButton: padActive ? () => setPadActive(false) : undefined, onButtonDown: padActive ? onButtonDown : undefined, onGamepadDirection: padActive ? onDirection : undefined, onGamepadBlur: padActive ? () => setPadActive(false) : undefined, onOKActionDescription: padActive ? undefined : "Move Points", onCancelActionDescription: padActive ? "Done" : undefined, children: [svg, padActive ? (SP_JSX.jsx("div", { className: "pk-fan-hint", children: `D-pad moves point ${selected + 1} of ${points.length} · LB/RB picks a point · B when done` })) : null] }));
}

function FanCurveModal({ name, curve, existing, onSaved, closeModal }) {
    const factory = curve.factory;
    const [label, setLabel] = SP_REACT.useState(factory ? `My ${curve.label.replace(/ \(.*\)$/, "")}` : curve.label);
    const [points, setPoints] = SP_REACT.useState(() => parseCurve(curve.curve));
    const [selected, setSelected] = SP_REACT.useState(0);
    const [busy, setBusy] = SP_REACT.useState(false);
    const [error, setError] = SP_REACT.useState("");
    const [confirmDelete, setConfirmDelete] = SP_REACT.useState(false);
    const [temp, setTemp] = SP_REACT.useState(null);
    SP_REACT.useEffect(() => {
        let cancelled = false;
        const poll = async () => {
            try {
                const status = await getFanStatus();
                if (!cancelled)
                    setTemp(status.temp);
            }
            catch {
                // status is decorative
            }
        };
        poll();
        const timer = window.setInterval(poll, 2000);
        return () => {
            cancelled = true;
            window.clearInterval(timer);
        };
    }, []);
    const targetName = factory ? slugifyCurveName(label) : name;
    const nameTaken = factory && (!!existing[targetName]?.factory || (!!existing[targetName] && targetName !== name));
    const sorted = [...points].sort((a, b) => a.temp - b.temp);
    const index = clamp(selected, 0, sorted.length - 1);
    const point = sorted[index];
    const commit = (next) => setPoints([...next].sort((a, b) => a.temp - b.temp));
    const setPoint = (key, value) => {
        if (!point)
            return;
        let next = value;
        if (key === "temp") {
            const lower = index > 0 ? sorted[index - 1].temp + 1 : TEMP_MIN;
            const upper = index < sorted.length - 1 ? sorted[index + 1].temp - 1 : TEMP_MAX;
            next = clamp(value, lower, upper);
        }
        commit(sorted.map((p, i) => (i === index ? { ...p, [key]: next } : p)));
    };
    const addPoint = () => {
        if (sorted.length >= MAX_POINTS)
            return;
        const used = new Set(sorted.map((p) => p.temp));
        // Slot the new point halfway to the next one when there is room, else at the default.
        let t = point && index < sorted.length - 1 ? Math.round((point.temp + sorted[index + 1].temp) / 2) : DEFAULT_POINT.temp;
        while (used.has(t) && t < TEMP_MAX)
            t += 1;
        if (used.has(t))
            return;
        const pwm = point ? point.pwm : DEFAULT_POINT.pwm;
        const next = [...sorted, { temp: t, pwm }].sort((a, b) => a.temp - b.temp);
        commit(next);
        setSelected(next.findIndex((p) => p.temp === t));
    };
    const removePoint = () => {
        if (sorted.length <= 1)
            return;
        commit(sorted.filter((_, i) => i !== index));
        setSelected(Math.max(0, index - 1));
    };
    const save = async () => {
        if (busy)
            return;
        setBusy(true);
        setError("");
        try {
            const next = await saveFanCurve(targetName, label, formatCurve(sorted));
            onSaved(next);
            closeModal?.();
        }
        catch (e) {
            setError(String(e));
            setBusy(false);
        }
    };
    const remove = async () => {
        if (busy)
            return;
        setBusy(true);
        try {
            const next = await deleteFanCurve(name);
            onSaved(next);
            closeModal?.();
        }
        catch (e) {
            setError(String(e));
            setBusy(false);
        }
    };
    const canSave = sorted.length > 0 && !!targetName && !nameTaken && !busy;
    return (SP_JSX.jsxs(DFL.ModalRoot, { bAllowFullSize: true, onCancel: () => closeModal?.(), children: [SP_JSX.jsx("style", { children: styles }), SP_JSX.jsxs(DFL.DialogBody, { className: "pocknix-control-tabs-modal", children: [SP_JSX.jsx("h2", { className: "pk-fan-title", children: factory ? `Customize "${curve.label}"` : `Edit "${curve.label}"` }), SP_JSX.jsxs(DFL.PanelSection, { children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "Name", childrenLayout: "below", childrenContainerWidth: "max", children: SP_JSX.jsx(DFL.TextField, { value: label, disabled: busy, onChange: (event) => setLabel(event.target.value) }) }) }), factory ? SP_JSX.jsx("div", { className: "pocknix-note", children: "Built-in curves stay as they are; this saves a new curve and switches to it." }) : null, nameTaken ? SP_JSX.jsx("div", { className: "pk-fan-error", children: "A curve with that name already exists." }) : null] }), SP_JSX.jsx(FanCurveGraph, { points: sorted, onChange: commit, currentTemp: temp, selectedIndex: index, onSelect: setSelected }), point ? (SP_JSX.jsxs(DFL.PanelSection, { title: `POINT ${index + 1} OF ${sorted.length}`, children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.SliderField, { label: "Temperature", value: point.temp, min: TEMP_MIN, max: TEMP_MAX, step: 1, showValue: true, valueSuffix: "\u00B0C", onChange: (v) => setPoint("temp", v) }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.SliderField, { label: "Fan speed", value: pwmToPercent(point.pwm), min: 0, max: 100, step: 5, showValue: true, valueSuffix: "%", onChange: (v) => setPoint("pwm", percentToPwm(v)) }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: () => setSelected((index + 1) % sorted.length), disabled: sorted.length < 2, children: "Next point" }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: addPoint, disabled: sorted.length >= MAX_POINTS, children: "Add point" }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: removePoint, disabled: sorted.length <= 1, children: "Remove this point" }) })] })) : null, SP_JSX.jsxs("div", { className: "pocknix-note", children: ["Speed is 0 to 100% of the fan's full speed (", PWM_MAX, " PWM). Below the first point the fan holds the first speed; above the last point it holds the last."] }), error ? SP_JSX.jsx("div", { className: "pk-fan-error", children: error }) : null] }), SP_JSX.jsxs(DFL.DialogFooter, { children: [!factory ? (confirmDelete ? (SP_JSX.jsx(DFL.DialogButton, { onClick: remove, disabled: busy, children: "Really delete" })) : (SP_JSX.jsx(DFL.DialogButton, { onClick: () => setConfirmDelete(true), disabled: busy, children: "Delete curve" }))) : null, SP_JSX.jsx(DFL.DialogButton, { onClick: () => closeModal?.(), disabled: busy, children: "Cancel" }), SP_JSX.jsx(DFL.DialogButton, { onClick: save, disabled: !canSave, children: busy ? "Saving..." : factory ? "Save as new curve" : "Save" })] })] }));
}

// Modes the stick-LED daemon understands (pocknix-stick-ledsd reads /var/lib/pocknix/led-mode).
const ledEffectOptions = [
    { data: "off", label: "Off" },
    { data: "static", label: "Static" },
    { data: "rainbow", label: "Rainbow" },
    { data: "breathe", label: "Breathing" },
];
const ledColorPresets = [
    { data: "ff6600", label: "Hodor Orange" },
    { data: "ff0000", label: "Red" },
    { data: "ffff00", label: "Yellow" },
    { data: "00ff00", label: "Green" },
    { data: "00ffff", label: "Cyan" },
    { data: "0066ff", label: "Blue" },
    { data: "8800ff", label: "Purple" },
    { data: "ff00aa", label: "Pink" },
    { data: "ffffff", label: "White" },
];
const chargeOptions = [
    { data: 80, label: "80% (longest battery lifespan)" },
    { data: 85, label: "85%" },
    { data: 90, label: "90%" },
    { data: 100, label: "100% (charge to full)" },
];
const powerOptions = [
    { data: "eco", label: "Eco (cool & quiet, ~60% clocks)" },
    { data: "balanced", label: "Balanced (~80% clocks)" },
    { data: "performance", label: "Performance (uncapped)" },
];
// Built-in curves first (the backend lists them in that order), then the user's own.
const fanOptions = (config) => Object.entries(config.fanCurves || {}).map(([name, curve]) => ({ data: name, label: curve.label }));
const downloadInhibitOptions = [
    { data: "always", label: "Always (also on battery)" },
    { data: "plugged", label: "Only on charger" },
    { data: "never", label: "Never" },
];
const lavdOptions = [
    { data: "autopilot", label: "Autopilot" },
    { data: "performance", label: "Performance" },
];
function Power({ config, setConfig, reload }) {
    const applyLedMode = async (mode) => {
        try {
            const next = await setLedMode(mode);
            setConfig((current) => (current ? { ...current, ledMode: next.ledMode } : current));
        }
        catch (error) {
            reload();
        }
    };
    const applyLed = async (hex) => {
        try {
            const next = await setLedColor(hex);
            setConfig((current) => (current ? { ...current, ledColor: next.ledColor } : current));
        }
        catch (error) {
            reload();
        }
    };
    const applyCharge = async (pct) => {
        try {
            const next = await setChargeLimit(pct);
            setConfig((current) => (current ? { ...current, chargeLimit: next.chargeLimit } : current));
        }
        catch (error) {
            reload();
        }
    };
    const applyMode = async (setter, mode) => {
        try {
            const next = await setter(mode);
            setConfig((current) => (current ? { ...current, fanMode: next.fanMode, fanCurves: next.fanCurves, powerMode: next.powerMode, lavdMode: next.lavdMode, downloadInhibitMode: next.downloadInhibitMode } : current));
        }
        catch (error) {
            reload();
        }
    };
    // Rainbow ignores the color; off shows nothing — only offer the palette when it matters.
    const ledColorRelevant = config.ledMode === "static" || config.ledMode === "breathe";
    // Live fan readout while the tab is open (the daemon drives the fan from the same hottest zone).
    const [fan, setFan] = SP_REACT.useState(null);
    SP_REACT.useEffect(() => {
        let cancelled = false;
        const poll = async () => {
            try {
                const status = await getFanStatus();
                if (!cancelled)
                    setFan(status);
            }
            catch {
                // decorative
            }
        };
        poll();
        const timer = window.setInterval(poll, 2000);
        return () => {
            cancelled = true;
            window.clearInterval(timer);
        };
    }, []);
    const activeCurve = config.fanCurves?.[config.fanMode] || config.fanCurves?.quiet;
    const openEditor = () => {
        if (!activeCurve)
            return;
        DFL.showModal(SP_JSX.jsx(FanCurveModal, { name: config.fanMode, curve: activeCurve, existing: config.fanCurves, onSaved: (next) => setConfig((current) => (current ? { ...current, fanMode: next.fanMode, fanCurves: next.fanCurves } : current)) }));
    };
    return (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsxs(DFL.PanelSection, { title: "PERFORMANCE", children: [SP_JSX.jsx(SelectEdit, { label: "Power Profile", value: config.powerMode, options: powerOptions, onChange: (mode) => applyMode(setPowerMode, mode) }), SP_JSX.jsx(SelectEdit, { label: "Charge Limit (experimental)", value: config.chargeLimit, options: chargeOptions, onChange: (pct) => applyCharge(pct) }), SP_JSX.jsx(SelectEdit, { label: "CPU Scheduler", value: config.lavdMode, options: lavdOptions, onChange: (mode) => applyMode(setLavdMode, mode) })] }), SP_JSX.jsxs(DFL.PanelSection, { title: "DOWNLOADS", children: [SP_JSX.jsx(SelectEdit, { label: "Stay awake for downloads", value: config.downloadInhibitMode || "always", options: downloadInhibitOptions, onChange: (mode) => applyMode(setDownloadInhibitMode, mode) }), SP_JSX.jsx("div", { className: "pocknix-note", children: "A download that is interrupted by sleep does not resume on its own. While one is running and this is on, the device stays awake and the power button will not put it to sleep. Below 5% on battery it powers off regardless." })] }), SP_JSX.jsxs(DFL.PanelSection, { title: "FAN", children: [SP_JSX.jsx(SelectEdit, { label: "Fan Curve", value: config.fanMode, options: fanOptions(config), onChange: (mode) => applyMode(setFanMode, mode) }), activeCurve ? SP_JSX.jsx(FanCurveGraph, { points: parseCurve(activeCurve.curve), currentTemp: fan?.temp ?? null }) : null, SP_JSX.jsx("div", { className: "pocknix-note", children: fan && fan.temp !== null && fan.percent !== null ? `Now: ${fan.temp}°C, fan at ${fan.percent}%` : "Fan readout unavailable" }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: openEditor, disabled: !activeCurve, children: activeCurve?.factory ? "Customize this curve..." : "Edit this curve..." }) })] }), SP_JSX.jsxs(DFL.PanelSection, { title: "STICK LEDS", children: [SP_JSX.jsx(SelectEdit, { label: "Effect", value: config.ledMode, options: ledEffectOptions, onChange: (mode) => applyLedMode(mode) }), ledColorRelevant && (SP_JSX.jsx(ColorPalette, { colors: ledColorPresets, value: config.ledColor, onChange: (hex) => applyLed(hex) }))] })] }));
}

function cardSummary(card) {
    if (!card)
        return "Checking…";
    if (!card.present)
        return "No SD card detected";
    const size = card.sizeBytes ? `${(card.sizeBytes / 1e9).toFixed(1)} GB` : "";
    const state = card.fstype === "ext4" ? (card.mountpoint ? "mounted" : "") : "not formatted for Steam";
    return [card.label || "unlabeled", size, card.fstype || "no filesystem", state].filter(Boolean).join(" · ");
}
// showModal injects closeModal into this wrapper. We deliberately do NOT forward it to
// ConfirmModal: its internal OK handler would close the dialog immediately, and we want
// it held open (with the confirm button greyed out) until the format finishes.
function FormatConfirmModal({ summary, onConfirm, closeModal }) {
    const [text, setText] = SP_REACT.useState("");
    const [running, setRunning] = SP_REACT.useState(false);
    const armedRef = SP_REACT.useRef(false);
    const runningRef = SP_REACT.useRef(false);
    armedRef.current = text.trim().toLowerCase() === "format";
    runningRef.current = running;
    const start = async () => {
        if (!armedRef.current || runningRef.current)
            return;
        setRunning(true);
        await onConfirm();
        closeModal?.();
    };
    return (SP_JSX.jsx(DFL.ConfirmModal, { strTitle: "Format SD Card", strDescription: running
            ? "Formatting… This can take a minute. Do not remove the card."
            : `This erases ALL data on the card (${summary}) and formats it for Steam. Type "format" and press Enter to confirm.`, strOKButtonText: running ? "Formatting…" : "Erase and Format", bDestructiveWarning: true, bOKDisabled: !armedRef.current || running, bCancelDisabled: running, bDisableBackgroundDismiss: true, bHideCloseIcon: true, onCancel: () => {
            if (!runningRef.current)
                closeModal?.();
        }, onOK: start, children: !running ? (SP_JSX.jsx(DFL.TextField, { value: text, focusOnMount: true, onChange: (event) => setText(event.target.value), onKeyDown: (event) => {
                if (event.key === "Enter")
                    start();
            } })) : null }));
}
function Storage() {
    const [card, setCard] = SP_REACT.useState(null);
    const [label, setLabel] = SP_REACT.useState("SDCARD");
    const [busy, setBusy] = SP_REACT.useState(false);
    const [status, setStatus] = SP_REACT.useState("");
    const busyRef = SP_REACT.useRef(false);
    busyRef.current = busy;
    SP_REACT.useEffect(() => {
        let cancelled = false;
        const refresh = async () => {
            if (busyRef.current)
                return;
            try {
                const next = await detectSdcard();
                if (!cancelled && !busyRef.current)
                    setCard(next);
            }
            catch (error) {
                if (!cancelled)
                    setStatus(String(error));
            }
        };
        refresh();
        const timer = window.setInterval(refresh, 5000);
        return () => {
            cancelled = true;
            window.clearInterval(timer);
        };
    }, []);
    const runFormat = async () => {
        if (busyRef.current)
            return;
        setBusy(true);
        setStatus("");
        try {
            const next = await formatSdcard(label);
            setCard(next);
        }
        catch (error) {
            setStatus(String(error));
        }
        finally {
            setBusy(false);
        }
    };
    const confirmFormat = () => DFL.showModal(SP_JSX.jsx(FormatConfirmModal, { summary: cardSummary(card), onConfirm: runFormat }));
    return (SP_JSX.jsxs(DFL.PanelSection, { title: "SD CARD", children: [SP_JSX.jsx(DFL.Field, { label: "Card", description: cardSummary(card) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.TextField, { label: "Label", value: label, disabled: busy, onChange: (event) => setLabel(event.target.value.replace(/[^A-Za-z0-9_-]/g, "").slice(0, 16)) }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", disabled: !card?.present || busy, onClick: confirmFormat, children: busy ? "Formatting…" : "Format SD Card" }) }), status ? SP_JSX.jsx(DFL.Field, { label: "", description: status }) : null] }));
}

const SHOWN_UPDATES = 8;
function Updater() {
    const [updates, setUpdates] = SP_REACT.useState(null);
    const [checking, setChecking] = SP_REACT.useState(false);
    const [status, setStatus] = SP_REACT.useState(null);
    const [error, setError] = SP_REACT.useState("");
    const busyRef = SP_REACT.useRef(false);
    const running = !!status?.running;
    busyRef.current = checking || running;
    // Re-attach to an update that survived a QAM close (or a Steam restart).
    SP_REACT.useEffect(() => {
        let cancelled = false;
        updateStatus()
            .then((next) => {
            if (!cancelled && (next.running || next.exitCode !== null))
                setStatus(next);
        })
            .catch(() => { });
        return () => {
            cancelled = true;
        };
    }, []);
    SP_REACT.useEffect(() => {
        if (!running)
            return;
        const timer = window.setInterval(async () => {
            try {
                const next = await updateStatus();
                setStatus(next);
                if (!next.running && next.exitCode === 0)
                    setUpdates([]);
            }
            catch (err) {
                setError(String(err));
            }
        }, 2000);
        return () => window.clearInterval(timer);
    }, [running]);
    const check = async () => {
        if (busyRef.current)
            return;
        setChecking(true);
        setError("");
        try {
            setUpdates(await checkUpdates());
        }
        catch (err) {
            setError(String(err));
        }
        finally {
            setChecking(false);
        }
    };
    const start = async () => {
        if (busyRef.current)
            return;
        setError("");
        try {
            setStatus(await startUpdate());
        }
        catch (err) {
            setError(String(err));
        }
    };
    const confirmStart = () => DFL.showModal(SP_JSX.jsx(DFL.ConfirmModal, { strTitle: "Install Updates", strDescription: "Downloads and installs all available system updates. Keep the device powered; a running game may stutter. Restart after it finishes.", strOKButtonText: "Install", onOK: start }));
    const finished = !running && status?.exitCode !== null && status?.exitCode !== undefined;
    const summary = updates === null
        ? "Not checked yet"
        : updates.length === 0
            ? "System is up to date"
            : `${updates.length} update${updates.length === 1 ? "" : "s"} available`;
    return (SP_JSX.jsxs(DFL.PanelSection, { title: "SYSTEM UPDATES", children: [!running ? SP_JSX.jsx(DFL.Field, { label: "Status", description: summary }) : null, !running && updates && updates.length > 0 ? (SP_JSX.jsxs("div", { className: "pocknix-note", children: [updates.slice(0, SHOWN_UPDATES).map((update) => (SP_JSX.jsx("div", { children: `${update.name} ${update.current} → ${update.latest}` }, update.name))), updates.length > SHOWN_UPDATES ? SP_JSX.jsx("div", { children: `… and ${updates.length - SHOWN_UPDATES} more` }) : null] })) : null, SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", disabled: checking || running, onClick: check, children: checking ? "Checking…" : "Check for Updates" }) }), !running && updates && updates.length > 0 ? (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: confirmStart, children: "Install Updates" }) })) : null, running ? SP_JSX.jsx(DFL.Field, { label: "Updating\u2026", description: "Safe to close this menu. Do not power off." }) : null, finished ? (SP_JSX.jsx(DFL.Field, { label: status.exitCode === 0 ? "Update complete" : `Update failed (code ${status.exitCode})`, description: status.exitCode === 0 ? "Restart to finish applying updates." : "See the log below." })) : null, (running || (finished && status.exitCode !== 0)) && status?.log ? (SP_JSX.jsx("div", { className: "pocknix-note pocknix-log", children: status.log })) : null, error ? SP_JSX.jsx(DFL.Field, { label: "Error", description: error }) : null] }));
}

function Content() {
    const [tab, setTab] = SP_REACT.useState("Games");
    const [config, setConfig] = SP_REACT.useState(null);
    const [message, setMessage] = SP_REACT.useState("Loading");
    const savedTweaksSnapshot = SP_REACT.useRef("");
    const load = SP_REACT.useCallback(async () => {
        try {
            const next = await getConfig();
            next.game = currentGame();
            next.selectedGame = next.game || null;
            savedTweaksSnapshot.current = JSON.stringify(next.tweaks);
            setConfig(next);
        }
        catch (error) {
            setMessage(String(error));
        }
    }, []);
    SP_REACT.useEffect(() => {
        load();
    }, [load]);
    // Track the running game so opening the QAM mid-game edits that game's profile.
    SP_REACT.useEffect(() => {
        if (!config)
            return;
        let cancelled = false;
        const refreshRuntime = () => {
            try {
                const runtimeGame = currentGame();
                if (cancelled)
                    return;
                setConfig((current) => {
                    if (!current)
                        return current;
                    if ((current.game?.appid || "") === (runtimeGame?.appid || "") && (current.game?.name || "") === (runtimeGame?.name || ""))
                        return current;
                    return { ...current, game: runtimeGame };
                });
            }
            catch (error) {
            }
        };
        const timer = window.setInterval(refreshRuntime, 2000);
        refreshRuntime();
        return () => {
            cancelled = true;
            window.clearInterval(timer);
        };
    }, [!!config]);
    useDebouncedSave({ config, field: "tweaks", snapshot: savedTweaksSnapshot, save: saveTweaks, setConfig, onError: load });
    if (!config)
        return SP_JSX.jsx(DFL.PanelSection, { title: "Pocknix Control", children: SP_JSX.jsx(DFL.Field, { label: message }) });
    const tabContent = (content) => (SP_JSX.jsx("div", { className: "pocknix-control-tab-content", children: content }));
    return (SP_JSX.jsxs("div", { className: "pocknix-control-tabs", children: [SP_JSX.jsx("style", { children: styles }), SP_JSX.jsx(DFL.Tabs, { activeTab: tab, onShowTab: setTab, tabs: [
                    { id: "Games", title: tabIcons.Games, content: tabContent(SP_JSX.jsx(Games, { config: config, setConfig: setConfig })) },
                    { id: "Power", title: tabIcons.Power, content: tabContent(SP_JSX.jsx(Power, { config: config, setConfig: setConfig, reload: load })) },
                    { id: "Storage", title: tabIcons.Storage, content: tabContent(SP_JSX.jsx(Storage, {})) },
                    { id: "Updater", title: tabIcons.Updater, content: tabContent(SP_JSX.jsx(Updater, {})) },
                ] })] }));
}

var index = definePlugin(() => ({
    name: "Pocknix Control",
    content: SP_JSX.jsx(Content, {}),
    icon: SP_JSX.jsx("div", { style: { fontWeight: 700 }, children: "P" }),
    alwaysRender: true,
}));

export { index as default };
//# sourceMappingURL=index.js.map

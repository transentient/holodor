import { PanelSection, ToggleField } from "@decky/ui";
import type { Dispatch, SetStateAction } from "react";
import { AddGameSection } from "../components/AddGame";
import { SelectEdit } from "../components/widgets";
import { availableGames, editTargetOptions } from "../lib/games";
import { clone } from "../lib/util";
import type { Config } from "../types";

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

const fexFlagDefs: Array<{ key: string; label: string }> = [
  { key: "TSOEnabled", label: "TSO Enabled" },
  { key: "X87ReducedPrecision", label: "X87 Reduced Precision" },
  { key: "Multiblock", label: "Multiblock" },
  { key: "VectorTSOEnabled", label: "Vector TSO Enabled" },
  { key: "MemcpySetTSOEnabled", label: "Memcpy Set TSO Enabled" },
  { key: "HalfBarrierTSOEnabled", label: "Half Barrier TSO Enabled" },
];

export function Games({ config, setConfig }: { config: Config; setConfig: Dispatch<SetStateAction<Config | null>> }) {
  const runtimeGame = config.game;
  const games = availableGames(config);
  const game = config.selectedGame || runtimeGame || null;
  const tweaks = config.tweaks;
  const gameSettings = game?.appid ? tweaks.games[game.appid] || {} : {};
  const editingDefault = !game?.appid;
  const perGameEnabled = !!(game?.appid && gameSettings.enabled === true);
  const values = editingDefault || !perGameEnabled ? tweaks.global : { ...tweaks.global, ...gameSettings };
  const patchSettings = (patch: Record<string, any>) => {
    setConfig((current) => {
      if (!current) return current;
      const next = clone(current);
      if (editingDefault) {
        Object.assign(next.tweaks.global, patch);
      } else if (perGameEnabled) {
        const existing = next.tweaks.games[game!.appid] || {};
        next.tweaks.games[game!.appid] = { ...existing, enabled: true, name: game!.name || "", ...patch };
      }
      return next;
    });
  };
  const setPerGameEnabled = (enabled: boolean) => {
    if (!game?.appid) return;
    setConfig((current) => {
      if (!current) return current;
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
  const setSelectedGame = (appid: any) => {
    const id = String(appid);
    if (!id) {
      setConfig((current) => (current ? { ...current, selectedGame: { appid: "", name: "Default" } } : current));
      return;
    }
    const saved = games.find((candidate) => candidate.appid === id);
    setConfig((current) => (current ? { ...current, selectedGame: saved || null } : current));
  };

  const presets = config.fexProfiles || {};
  const storedProfile = values.fexProfile as string | undefined;
  const fexValue = storedProfile && presets[storedProfile] ? storedProfile : "default";
  const fexOptions = Object.entries(presets).map(([id, profile]) => ({ data: id, label: profile.label }));
  const storedLatency = String(values.audioLatency ?? "");
  const audioValue = audioLatencyOptions.some((option) => option.data === storedLatency) ? storedLatency : "";
  const lsfgSettings = (values.lsfg || {}) as Record<string, any>;
  const lsfgEnabled = lsfgSettings.enabled === true;
  const lsfgMultiplier = ["2", "3", "4"].includes(String(lsfgSettings.multiplier)) ? String(lsfgSettings.multiplier) : "2";
  const presetConfig = presets[fexValue]?.config || {};
  const flagOverrides = (values.fexFlags || {}) as Record<string, string>;
  const effectiveFlag = (key: string) => (flagOverrides[key] ?? presetConfig[key] ?? "0") === "1";
  const setFlag = (key: string, on: boolean) => {
    const next: Record<string, string> = { ...flagOverrides };
    const presetValue = presetConfig[key] ?? "0";
    const wanted = on ? "1" : "0";
    // Store only real deviations; matching the preset removes the override so
    // preset switches keep working predictably.
    if (wanted === presetValue) delete next[key];
    else next[key] = wanted;
    patchSettings({ fexFlags: next });
  };

  return (
    <>
      <PanelSection title="GAME TWEAKS">
        <SelectEdit label="Game" value={game?.appid || ""} options={editTargetOptions(config)} onChange={setSelectedGame} />
        <div className="pocknix-note">Changes apply on next game launch</div>
        {!editingDefault ? <ToggleField label="Use Per-Game Settings" checked={perGameEnabled} onChange={setPerGameEnabled} /> : null}
        {editingDefault || perGameEnabled ? (
          <>
            <SelectEdit label="FEX Preset" value={fexValue} options={fexOptions} onChange={(id) => patchSettings({ fexProfile: id, fexFlags: {} })} />
            <SelectEdit label="Audio Buffer" value={audioValue} options={audioLatencyOptions} onChange={(id) => patchSettings({ audioLatency: id })} />
            <ToggleField
              label="Frame Insertion (LSFG)"
              description="Doubles presented fps by interpolation. Needs Lossless Scaling installed from Steam. Adds a little input latency."
              checked={lsfgEnabled}
              onChange={(on) => patchSettings({ lsfg: { ...lsfgSettings, enabled: on } })}
            />
            {lsfgEnabled ? (
              <SelectEdit label="Insertion Multiplier" value={lsfgMultiplier} options={lsfgMultiplierOptions} onChange={(m) => patchSettings({ lsfg: { ...lsfgSettings, enabled: true, multiplier: String(m) } })} />
            ) : null}
            <div className="pocknix-note">Advanced FEX flags{Object.keys(flagOverrides).length ? " (modified)" : ""}</div>
            {fexFlagDefs.map(({ key, label }) => (
              <ToggleField key={key} label={label} checked={effectiveFlag(key)} onChange={(on) => setFlag(key, on)} />
            ))}
          </>
        ) : null}
      </PanelSection>
      <AddGameSection />
    </>
  );
}

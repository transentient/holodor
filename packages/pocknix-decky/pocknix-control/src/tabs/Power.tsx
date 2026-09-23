import { ButtonItem, PanelSection, PanelSectionRow, showModal } from "@decky/ui";
import { useEffect, useState } from "react";
import type { Dispatch, SetStateAction } from "react";
import { getFanStatus, setDownloadInhibitMode, setFanMode, setLavdMode, setPowerMode, setChargeLimit, setLedColor, setLedMode } from "../backend";
import { FanCurveGraph } from "../components/FanCurveGraph";
import { FanCurveModal } from "../components/FanCurveModal";
import { ColorPalette, SelectEdit } from "../components/widgets";
import { parseCurve } from "../lib/fanCurve";
import type { Config, FanStatus } from "../types";

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
const fanOptions = (config: Config) =>
  Object.entries(config.fanCurves || {}).map(([name, curve]) => ({ data: name, label: curve.label }));
const downloadInhibitOptions = [
  { data: "always", label: "Always (also on battery)" },
  { data: "plugged", label: "Only on charger" },
  { data: "never", label: "Never" },
];
const lavdOptions = [
  { data: "autopilot", label: "Autopilot" },
  { data: "performance", label: "Performance" },
];

export function Power({ config, setConfig, reload }: {
  config: Config;
  setConfig: Dispatch<SetStateAction<Config | null>>;
  reload: () => void;
}) {
  const applyLedMode = async (mode: string) => {
    try {
      const next = await setLedMode(mode);
      setConfig((current) => (current ? { ...current, ledMode: next.ledMode } : current));
    } catch (error) {
      reload();
    }
  };
  const applyLed = async (hex: string) => {
    try {
      const next = await setLedColor(hex);
      setConfig((current) => (current ? { ...current, ledColor: next.ledColor } : current));
    } catch (error) {
      reload();
    }
  };
  const applyCharge = async (pct: number) => {
    try {
      const next = await setChargeLimit(pct);
      setConfig((current) => (current ? { ...current, chargeLimit: next.chargeLimit } : current));
    } catch (error) {
      reload();
    }
  };
  const applyMode = async (setter: (mode: string) => Promise<Config>, mode: string) => {
    try {
      const next = await setter(mode);
      setConfig((current) => (current ? { ...current, fanMode: next.fanMode, fanCurves: next.fanCurves, powerMode: next.powerMode, lavdMode: next.lavdMode, downloadInhibitMode: next.downloadInhibitMode } : current));
    } catch (error) {
      reload();
    }
  };
  // Rainbow ignores the color; off shows nothing — only offer the palette when it matters.
  const ledColorRelevant = config.ledMode === "static" || config.ledMode === "breathe";
  // Live fan readout while the tab is open (the daemon drives the fan from the same hottest zone).
  const [fan, setFan] = useState<FanStatus | null>(null);
  useEffect(() => {
    let cancelled = false;
    const poll = async () => {
      try {
        const status = await getFanStatus();
        if (!cancelled) setFan(status);
      } catch {
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
    if (!activeCurve) return;
    showModal(
      <FanCurveModal
        name={config.fanMode}
        curve={activeCurve}
        existing={config.fanCurves}
        onSaved={(next) => setConfig((current) => (current ? { ...current, fanMode: next.fanMode, fanCurves: next.fanCurves } : current))}
      />,
    );
  };
  return (
    <>
      <PanelSection title="PERFORMANCE">
        <SelectEdit label="Power Profile" value={config.powerMode} options={powerOptions} onChange={(mode) => applyMode(setPowerMode, mode)} />
        <SelectEdit label="Charge Limit (experimental)" value={config.chargeLimit} options={chargeOptions} onChange={(pct) => applyCharge(pct as number)} />
        <SelectEdit label="CPU Scheduler" value={config.lavdMode} options={lavdOptions} onChange={(mode) => applyMode(setLavdMode, mode)} />
      </PanelSection>
      <PanelSection title="DOWNLOADS">
        <SelectEdit label="Stay awake for downloads" value={config.downloadInhibitMode || "always"} options={downloadInhibitOptions} onChange={(mode) => applyMode(setDownloadInhibitMode, mode)} />
        <div className="pocknix-note">
          A download that is interrupted by sleep does not resume on its own. While one is running and this is on, the device stays awake and the power button will not put it to sleep. Below 5% on battery it powers off regardless.
        </div>
      </PanelSection>
      <PanelSection title="FAN">
        <SelectEdit label="Fan Curve" value={config.fanMode} options={fanOptions(config)} onChange={(mode) => applyMode(setFanMode, mode)} />
        {activeCurve ? <FanCurveGraph points={parseCurve(activeCurve.curve)} currentTemp={fan?.temp ?? null} /> : null}
        <div className="pocknix-note">
          {fan && fan.temp !== null && fan.percent !== null ? `Now: ${fan.temp}°C, fan at ${fan.percent}%` : "Fan readout unavailable"}
        </div>
        <PanelSectionRow>
          <ButtonItem layout="below" onClick={openEditor} disabled={!activeCurve}>
            {activeCurve?.factory ? "Customize this curve..." : "Edit this curve..."}
          </ButtonItem>
        </PanelSectionRow>
      </PanelSection>
      <PanelSection title="STICK LEDS">
        <SelectEdit label="Effect" value={config.ledMode} options={ledEffectOptions} onChange={(mode) => applyLedMode(mode as string)} />
        {ledColorRelevant && (
          <ColorPalette colors={ledColorPresets} value={config.ledColor} onChange={(hex) => applyLed(hex)} />
        )}
      </PanelSection>
    </>
  );
}

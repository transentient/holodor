// Fullscreen fan curve editor. Edits a copy; nothing reaches the daemon until Save, which
// writes the user curve and makes it the active one.
import { ButtonItem, DialogBody, DialogButton, DialogFooter, Field, ModalRoot, PanelSection, PanelSectionRow, SliderField, TextField } from "@decky/ui";
import { useEffect, useState } from "react";
import { deleteFanCurve, getFanStatus, saveFanCurve } from "../backend";
import { FanCurveGraph } from "./FanCurveGraph";
import { DEFAULT_POINT, MAX_POINTS, PWM_MAX, TEMP_MAX, TEMP_MIN, clamp, formatCurve, parseCurve, percentToPwm, pwmToPercent, slugifyCurveName } from "../lib/fanCurve";
import type { CurvePoint } from "../lib/fanCurve";
import { styles } from "../styles";
import type { Config, FanCurve } from "../types";

export function FanCurveModal({ name, curve, existing, onSaved, closeModal }: {
  /** Curve being edited; a factory curve is copied into a new user curve on save. */
  name: string;
  curve: FanCurve;
  existing: Record<string, FanCurve>;
  onSaved: (next: Config) => void;
  closeModal?: () => void;
}) {
  const factory = curve.factory;
  const [label, setLabel] = useState(factory ? `My ${curve.label.replace(/ \(.*\)$/, "")}` : curve.label);
  const [points, setPoints] = useState<CurvePoint[]>(() => parseCurve(curve.curve));
  const [selected, setSelected] = useState(0);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [temp, setTemp] = useState<number | null>(null);
  useEffect(() => {
    let cancelled = false;
    const poll = async () => {
      try {
        const status = await getFanStatus();
        if (!cancelled) setTemp(status.temp);
      } catch {
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
  const commit = (next: CurvePoint[]) => setPoints([...next].sort((a, b) => a.temp - b.temp));
  const setPoint = (key: "temp" | "pwm", value: number) => {
    if (!point) return;
    let next = value;
    if (key === "temp") {
      const lower = index > 0 ? sorted[index - 1].temp + 1 : TEMP_MIN;
      const upper = index < sorted.length - 1 ? sorted[index + 1].temp - 1 : TEMP_MAX;
      next = clamp(value, lower, upper);
    }
    commit(sorted.map((p, i) => (i === index ? { ...p, [key]: next } : p)));
  };
  const addPoint = () => {
    if (sorted.length >= MAX_POINTS) return;
    const used = new Set(sorted.map((p) => p.temp));
    // Slot the new point halfway to the next one when there is room, else at the default.
    let t = point && index < sorted.length - 1 ? Math.round((point.temp + sorted[index + 1].temp) / 2) : DEFAULT_POINT.temp;
    while (used.has(t) && t < TEMP_MAX) t += 1;
    if (used.has(t)) return;
    const pwm = point ? point.pwm : DEFAULT_POINT.pwm;
    const next = [...sorted, { temp: t, pwm }].sort((a, b) => a.temp - b.temp);
    commit(next);
    setSelected(next.findIndex((p) => p.temp === t));
  };
  const removePoint = () => {
    if (sorted.length <= 1) return;
    commit(sorted.filter((_, i) => i !== index));
    setSelected(Math.max(0, index - 1));
  };
  const save = async () => {
    if (busy) return;
    setBusy(true);
    setError("");
    try {
      const next = await saveFanCurve(targetName, label, formatCurve(sorted));
      onSaved(next);
      closeModal?.();
    } catch (e) {
      setError(String(e));
      setBusy(false);
    }
  };
  const remove = async () => {
    if (busy) return;
    setBusy(true);
    try {
      const next = await deleteFanCurve(name);
      onSaved(next);
      closeModal?.();
    } catch (e) {
      setError(String(e));
      setBusy(false);
    }
  };
  const canSave = sorted.length > 0 && !!targetName && !nameTaken && !busy;

  return (
    <ModalRoot bAllowFullSize onCancel={() => closeModal?.()}>
      <style>{styles}</style>
      <DialogBody className="pocknix-control-tabs-modal">
        <h2 className="pk-fan-title">{factory ? `Customize "${curve.label}"` : `Edit "${curve.label}"`}</h2>
        <PanelSection>
          <PanelSectionRow>
            <Field label="Name" childrenLayout="below" childrenContainerWidth="max">
              <TextField value={label} disabled={busy} onChange={(event) => setLabel(event.target.value)} />
            </Field>
          </PanelSectionRow>
          {factory ? <div className="pocknix-note">Built-in curves stay as they are; this saves a new curve and switches to it.</div> : null}
          {nameTaken ? <div className="pk-fan-error">A curve with that name already exists.</div> : null}
        </PanelSection>
        <FanCurveGraph points={sorted} onChange={commit} currentTemp={temp} selectedIndex={index} onSelect={setSelected} />
        {point ? (
          <PanelSection title={`POINT ${index + 1} OF ${sorted.length}`}>
            <PanelSectionRow>
              <SliderField label="Temperature" value={point.temp} min={TEMP_MIN} max={TEMP_MAX} step={1} showValue valueSuffix="°C" onChange={(v) => setPoint("temp", v)} />
            </PanelSectionRow>
            <PanelSectionRow>
              <SliderField label="Fan speed" value={pwmToPercent(point.pwm)} min={0} max={100} step={5} showValue valueSuffix="%" onChange={(v) => setPoint("pwm", percentToPwm(v))} />
            </PanelSectionRow>
            <PanelSectionRow>
              <ButtonItem layout="below" onClick={() => setSelected((index + 1) % sorted.length)} disabled={sorted.length < 2}>Next point</ButtonItem>
            </PanelSectionRow>
            <PanelSectionRow>
              <ButtonItem layout="below" onClick={addPoint} disabled={sorted.length >= MAX_POINTS}>Add point</ButtonItem>
            </PanelSectionRow>
            <PanelSectionRow>
              <ButtonItem layout="below" onClick={removePoint} disabled={sorted.length <= 1}>Remove this point</ButtonItem>
            </PanelSectionRow>
          </PanelSection>
        ) : null}
        <div className="pocknix-note">Speed is 0 to 100% of the fan's full speed ({PWM_MAX} PWM). Below the first point the fan holds the first speed; above the last point it holds the last.</div>
        {error ? <div className="pk-fan-error">{error}</div> : null}
      </DialogBody>
      <DialogFooter>
        {!factory ? (
          confirmDelete ? (
            <DialogButton onClick={remove} disabled={busy}>Really delete</DialogButton>
          ) : (
            <DialogButton onClick={() => setConfirmDelete(true)} disabled={busy}>Delete curve</DialogButton>
          )
        ) : null}
        <DialogButton onClick={() => closeModal?.()} disabled={busy}>Cancel</DialogButton>
        <DialogButton onClick={save} disabled={!canSave}>{busy ? "Saving..." : factory ? "Save as new curve" : "Save"}</DialogButton>
      </DialogFooter>
    </ModalRoot>
  );
}

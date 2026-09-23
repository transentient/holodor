// SVG fan curve graph: draggable points (touch) and controller editing (focus the graph, A to
// edit, D-pad moves the highlighted point, LB/RB switch points, B stops). Ported from ArmadaOS
// armada-control FanCurveGraph.tsx (GPL-2.0-or-later) and trimmed to Holodor's model.
import { Focusable, GamepadButton } from "@decky/ui";
import type { GamepadEvent } from "@decky/ui";
import { useMemo, useRef, useState } from "react";
import type { PointerEvent as ReactPointerEvent } from "react";
import { PWM_MAX, PWM_MIN, TEMP_MAX, TEMP_MIN, clamp, interpolate, percentToPwm, pwmToPercent } from "../lib/fanCurve";
import type { CurvePoint } from "../lib/fanCurve";

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

const xForTemp = (temp: number) => PAD_LEFT + ((clamp(temp, TEMP_MIN, TEMP_MAX) - TEMP_MIN) / (TEMP_MAX - TEMP_MIN)) * PLOT_W;
const yForPwm = (pwm: number) => PAD_TOP + (1 - (clamp(pwm, PWM_MIN, PWM_MAX) - PWM_MIN) / (PWM_MAX - PWM_MIN)) * PLOT_H;

export function FanCurveGraph({ points, onChange, currentTemp, selectedIndex, onSelect }: {
  points: CurvePoint[];
  /** Omit for a read-only graph. */
  onChange?: (next: CurvePoint[]) => void;
  currentTemp?: number | null;
  selectedIndex?: number;
  onSelect?: (index: number) => void;
}) {
  const editable = !!onChange;
  const svgRef = useRef<SVGSVGElement | null>(null);
  const dragRef = useRef<{ points: CurvePoint[]; index: number } | null>(null);
  const [livePoints, setLivePoints] = useState<CurvePoint[] | null>(null);
  const [padActive, setPadActive] = useState(false);
  const shown = livePoints ?? points;
  const sorted = useMemo(() => [...shown].sort((a, b) => a.temp - b.temp), [shown]);
  if (!sorted.length) return null;
  const selected = clamp(selectedIndex ?? 0, 0, points.length - 1);

  const eventToPoint = (e: ReactPointerEvent): CurvePoint | null => {
    const svg = svgRef.current;
    if (!svg) return null;
    const rect = svg.getBoundingClientRect();
    const fracX = clamp((e.clientX - rect.left) / rect.width, 0, 1);
    const fracY = clamp((e.clientY - rect.top) / rect.height, 0, 1);
    const temp = Math.round(TEMP_MIN + clamp((fracX * WIDTH - PAD_LEFT) / PLOT_W, 0, 1) * (TEMP_MAX - TEMP_MIN));
    const pwm = Math.round(PWM_MAX - clamp((fracY * HEIGHT - PAD_TOP) / PLOT_H, 0, 1) * (PWM_MAX - PWM_MIN));
    return { temp, pwm };
  };
  const onPointerDown = (index: number) => (e: ReactPointerEvent<SVGCircleElement>) => {
    if (!editable) return;
    e.currentTarget.setPointerCapture(e.pointerId);
    dragRef.current = { points: points.map((p) => ({ ...p })), index };
    onSelect?.(index);
    setLivePoints(points.map((p) => ({ ...p })));
  };
  const onPointerMove = (e: ReactPointerEvent<SVGCircleElement>) => {
    const drag = dragRef.current;
    if (!drag) return;
    const next = eventToPoint(e);
    if (!next) return;
    drag.points[drag.index] = next;
    setLivePoints([...drag.points]);
  };
  const endDrag = (e: ReactPointerEvent<SVGCircleElement>) => {
    const drag = dragRef.current;
    if (!drag) return;
    dragRef.current = null;
    setLivePoints(null);
    onChange?.(drag.points);
    try {
      e.currentTarget.releasePointerCapture(e.pointerId);
    } catch {
      // already released
    }
  };
  const movePoint = (deltaTemp: number, deltaPwm: number) => {
    if (!editable || !points.length) return;
    const ordered = [...points].sort((a, b) => a.temp - b.temp);
    const current = ordered[selected];
    const lower = selected > 0 ? ordered[selected - 1].temp + 1 : TEMP_MIN;
    const upper = selected < ordered.length - 1 ? ordered[selected + 1].temp - 1 : TEMP_MAX;
    const nextTemp = clamp(current.temp + deltaTemp, Math.max(TEMP_MIN, lower), Math.min(TEMP_MAX, upper));
    const nextPwm = clamp(current.pwm + deltaPwm, PWM_MIN, PWM_MAX);
    if (nextTemp === current.temp && nextPwm === current.pwm) return;
    onChange?.(ordered.map((point, i) => (i === selected ? { temp: nextTemp, pwm: nextPwm } : point)));
  };
  const onButtonDown = (e: GamepadEvent) => {
    switch (e.detail.button) {
      case GamepadButton.BUMPER_LEFT: onSelect?.((selected - 1 + points.length) % points.length); break;
      case GamepadButton.BUMPER_RIGHT: onSelect?.((selected + 1) % points.length); break;
      default: return;
    }
    e.preventDefault();
    e.stopPropagation();
  };
  const onDirection = (e: GamepadEvent) => {
    switch (e.detail.button) {
      case GamepadButton.DIR_UP: movePoint(0, DPAD_PWM_STEP); break;
      case GamepadButton.DIR_DOWN: movePoint(0, -DPAD_PWM_STEP); break;
      case GamepadButton.DIR_RIGHT: movePoint(DPAD_TEMP_STEP, 0); break;
      case GamepadButton.DIR_LEFT: movePoint(-DPAD_TEMP_STEP, 0); break;
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
  const tempX = hasTemp ? xForTemp(currentTemp as number) : 0;
  const tempY = hasTemp ? yForPwm(interpolate(sorted, currentTemp as number)) : 0;

  const svg = (
    <svg ref={svgRef} viewBox={`0 0 ${WIDTH} ${HEIGHT}`} style={{ width: "100%", height: "auto", display: "block", touchAction: "none", userSelect: "none" }}>
      <rect x={PAD_LEFT} y={PAD_TOP} width={PLOT_W} height={PLOT_H} fill="rgba(255,255,255,0.04)" stroke="rgba(255,255,255,0.15)" />
      {PWM_TICK_PERCENTS.map((percent) => (
        <g key={`pwm-${percent}`}>
          <line x1={PAD_LEFT} x2={PAD_LEFT + PLOT_W} y1={yForPwm(percentToPwm(percent))} y2={yForPwm(percentToPwm(percent))} stroke="rgba(255,255,255,0.08)" />
          <text x={PAD_LEFT - 4} y={yForPwm(percentToPwm(percent)) + 3} fontSize="7" textAnchor="end" fill="rgba(255,255,255,0.55)">{`${percent}%`}</text>
        </g>
      ))}
      {TEMP_TICKS.map((temp) => (
        <g key={`temp-${temp}`}>
          <line x1={xForTemp(temp)} x2={xForTemp(temp)} y1={PAD_TOP} y2={PAD_TOP + PLOT_H} stroke="rgba(255,255,255,0.06)" />
          <text x={xForTemp(temp)} y={HEIGHT - 4} fontSize="7" textAnchor="middle" fill="rgba(255,255,255,0.55)">{temp}</text>
        </g>
      ))}
      <path d={pathD} fill="none" stroke="#5cc8ff" strokeWidth={2} />
      {hasTemp ? (
        <g pointerEvents="none">
          <circle cx={tempX} cy={tempY} r={7} fill="rgba(255,255,255,0.18)" />
          <circle cx={tempX} cy={tempY} r={3.5} fill="#ffffff" stroke="#0D141C" strokeWidth={1.5} />
          <text x={clamp(tempX, PAD_LEFT + 14, PAD_LEFT + PLOT_W - 14)} y={tempY - 10 < PAD_TOP ? tempY + 15 : tempY - 10} fontSize="7" textAnchor="middle" fill="#ffffff">{`${currentTemp}°C`}</text>
        </g>
      ) : null}
      {sorted.map((point, index) => {
        const isActive = editable && (livePoints ? dragRef.current?.index === index : padActive && index === selected);
        const cx = xForTemp(point.temp);
        const cy = yForPwm(point.pwm);
        return (
          <g key={`point-${index}`}>
            {editable ? (
              <circle cx={cx} cy={cy} r={14} fill="transparent" onPointerDown={onPointerDown(index)} onPointerMove={onPointerMove} onPointerUp={endDrag} onPointerCancel={endDrag} style={{ cursor: "grab", touchAction: "none" }} />
            ) : null}
            <circle cx={cx} cy={cy} r={isActive ? 6 : 4.5} fill={isActive ? "#ffd166" : "#5cc8ff"} stroke="#0D141C" strokeWidth={1.5} pointerEvents="none" />
            {isActive ? (
              <text x={cx} y={cy - 12 < PAD_TOP ? cy + 14 : cy - 12} fontSize="8" textAnchor="middle" fill="#ffd166">{`${point.temp}°C / ${pwmToPercent(point.pwm)}%`}</text>
            ) : null}
          </g>
        );
      })}
    </svg>
  );
  if (!editable) return <div className="pk-fan-graph">{svg}</div>;
  return (
    <Focusable
      className={padActive ? "pk-fan-graph pk-fan-graph-editing" : "pk-fan-graph"}
      focusClassName="pk-fan-graph-focused"
      onActivate={() => setPadActive(true)}
      onOKButton={() => setPadActive(true)}
      onCancelButton={padActive ? () => setPadActive(false) : undefined}
      onButtonDown={padActive ? onButtonDown : undefined}
      onGamepadDirection={padActive ? onDirection : undefined}
      onGamepadBlur={padActive ? () => setPadActive(false) : undefined}
      onOKActionDescription={padActive ? undefined : "Move Points"}
      onCancelActionDescription={padActive ? "Done" : undefined}
    >
      {svg}
      {padActive ? (
        <div className="pk-fan-hint">{`D-pad moves point ${selected + 1} of ${points.length} · LB/RB picks a point · B when done`}</div>
      ) : null}
    </Focusable>
  );
}

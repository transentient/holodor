// Fan curve model shared by the graph, the editor and the Power tab. Mirrors
// py_modules/pocknix_control/fan_curves.py (design after ArmadaOS armada-control, GPL-2.0-or-later).
export interface CurvePoint {
  temp: number;
  pwm: number;
}

export const TEMP_MIN = 0;
export const TEMP_MAX = 120;
export const PWM_MIN = 0;
export const PWM_MAX = 255;
export const MAX_POINTS = 16;
export const DEFAULT_POINT: CurvePoint = { temp: 60, pwm: 128 };

export const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));
export const pwmToPercent = (pwm: number) => Math.round((clamp(pwm, PWM_MIN, PWM_MAX) / PWM_MAX) * 100);
export const percentToPwm = (percent: number) => Math.round((clamp(percent, 0, 100) / 100) * PWM_MAX);

export function parseCurve(text: string | undefined): CurvePoint[] {
  if (!text) return [];
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

export function formatCurve(points: CurvePoint[]): string {
  return [...points]
    .sort((a, b) => a.temp - b.temp)
    .map((point) => `${Math.round(point.temp)}:${Math.round(point.pwm)}`)
    .join(",");
}

/** What the daemon will do at a given temperature (linear between points, flat outside). */
export function interpolate(points: CurvePoint[], temp: number): number {
  const sorted = [...points].sort((a, b) => a.temp - b.temp);
  if (!sorted.length) return 0;
  const first = sorted[0];
  const last = sorted[sorted.length - 1];
  if (temp <= first.temp) return first.pwm;
  if (temp >= last.temp) return last.pwm;
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
export function slugifyCurveName(value: string): string {
  const slug = value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .replace(/^[^a-z]+/, "")
    .slice(0, 32);
  return slug;
}

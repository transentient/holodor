export interface GameTweak {
  enabled?: boolean;
  name?: string;
  fexProfile?: string;
  /** Audio buffer in ms (PULSE_LATENCY_MSEC exported by pocknix-proton-wrapper); "" = game default. */
  audioLatency?: string;
  [key: string]: any;
}

export interface Tweaks {
  global: Record<string, any>;
  games: Record<string, GameTweak>;
}

export interface InstalledGame {
  appid: string;
  name: string;
}

export interface FexProfile {
  label: string;
  config?: Record<string, string>;
}

export interface GameRef {
  appid: string;
  name: string;
  nonSteam?: boolean;
}

export interface FanCurve {
  label: string;
  /** "tempC:pwm,tempC:pwm,..." sorted by temperature, pwm 0-255 */
  curve: string;
  factory: boolean;
}

export interface FanStatus {
  temp: number | null;
  pwm: number | null;
  percent: number | null;
}

export interface Config {
  fanMode: string;
  fanCurves: Record<string, FanCurve>;
  powerMode: string;
  chargeLimit: number;
  ledColor: string;
  ledMode: string;
  lavdMode: string;
  downloadInhibitMode: string;
  tweaks: Tweaks;
  fexProfiles: Record<string, FexProfile>;
  installedGames: InstalledGame[];
  game?: GameRef | null;
  selectedGame?: GameRef | null;
}

export interface DropdownChoice {
  data: string;
  label: string;
}

export interface UpdateInfo {
  name: string;
  current: string;
  latest: string;
}

export interface UpdateStatus {
  running: boolean;
  log: string;
  exitCode: number | null;
}

export interface SdcardInfo {
  present: boolean;
  device?: string;
  sizeBytes?: number;
  fstype?: string;
  label?: string;
  mountpoint?: string;
}

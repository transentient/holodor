import { DialogButton, Dropdown, DropdownItem, Focusable, PanelSectionRow } from "@decky/ui";
import { useState } from "react";
import type { ReactNode } from "react";
import type { DropdownChoice } from "../types";

// Like DropdownChoice but any data payload — the charge-limit selector uses numbers.
type Option = string | { data: any; label: string };

export function SelectEdit({ label, value, options, onChange }: {
  label?: ReactNode;
  value: any;
  options: Option[];
  onChange: (data: any) => void;
}) {
  const rgOptions = options.map((option) => (typeof option === "string" ? { data: option, label: option } : option));
  return (
    <PanelSectionRow>
      {label === undefined ? (
        <Dropdown selectedOption={value} rgOptions={rgOptions} onChange={(option) => onChange(option.data)} />
      ) : (
        <DropdownItem label={label} selectedOption={value} rgOptions={rgOptions} onChange={(option) => onChange(option.data)} />
      )}
    </PanelSectionRow>
  );
}

/** True when a check/glyph drawn over #RRGGBB needs to be dark to stay readable. */
function isBright(hex: string) {
  const n = parseInt(hex, 16);
  if (Number.isNaN(n)) return false;
  const r = (n >> 16) & 0xff, g = (n >> 8) & 0xff, b = n & 0xff;
  return 0.299 * r + 0.587 * g + 0.114 * b > 150;
}

/**
 * Row of preset color swatches. Steam's gamepad focus style repaints button
 * backgrounds, so each swatch keeps its color inline (inline beats the class)
 * and shows focus via its own border + selection via a check glyph.
 */
export function ColorPalette({ colors, value, onChange }: {
  colors: DropdownChoice[];
  value: string;
  onChange: (hex: string) => void;
}) {
  const [focused, setFocused] = useState<string | null>(null);
  return (
    <PanelSectionRow>
      <Focusable style={{ display: "flex", flexWrap: "wrap", gap: "8px", padding: "6px 0" }}>
        {colors.map(({ data, label }) => (
          <DialogButton
            key={data}
            onClick={() => onChange(data)}
            onGamepadFocus={() => setFocused(data)}
            onGamepadBlur={() => setFocused((current) => (current === data ? null : current))}
            style={{
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
            }}
          >
            {value === data ? "✓" : ""}
          </DialogButton>
        ))}
      </Focusable>
    </PanelSectionRow>
  );
}

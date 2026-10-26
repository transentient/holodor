// AtomS3U_BlePad — the M5Stack AtomS3U (ESP32-S3) as a Bluetooth LE gamepad, driven over its USB
// serial port from fusor. The dock matrix "finger": a real wireless controller for a docked device.
//
// Serial protocol (115200, one command per line, replies "ok <cmd>" / "err <why>"):
//   press <btn>        tap for 120 ms            btn: A B X Y LB RB L3 R3 START SELECT GUIDE
//   hold <btn> / release <btn>
//   dpad <dir>         tap for 120 ms            dir: up down left right center
//   stick <L|R> <x> <y>   -1.0..1.0 (0 0 = centred), stays until changed
//   trig <L|R> <0..1>
//   status             -> "ok connected=0|1"
//   name               -> "ok <advertised name>"
// Library: ESP32-BleGamepad (lemmingDev) + NimBLE-Arduino.
#include <Arduino.h>
#include <BleGamepad.h>

static BleGamepad pad("Holodor BLE Pad", "Holodor", 100);

static int buttonFor(const String& b) {
  if (b == "A") return BUTTON_1;   if (b == "B") return BUTTON_2;
  if (b == "X") return BUTTON_4;   if (b == "Y") return BUTTON_5;
  if (b == "LB") return BUTTON_7;  if (b == "RB") return BUTTON_8;
  if (b == "SELECT") return BUTTON_11; if (b == "START") return BUTTON_12;
  if (b == "GUIDE") return BUTTON_13; if (b == "L3") return BUTTON_14; if (b == "R3") return BUTTON_15;
  return -1;
}
static int hatFor(const String& d) {
  if (d == "up") return DPAD_UP; if (d == "down") return DPAD_DOWN;
  if (d == "left") return DPAD_LEFT; if (d == "right") return DPAD_RIGHT;
  if (d == "center") return DPAD_CENTERED;
  return -1;
}
static int16_t axis(float v) { if (v > 1) v = 1; if (v < -1) v = -1; return (int16_t)(v * 32767); }

void setup() {
  Serial.begin(115200);
  BleGamepadConfiguration cfg;
  cfg.setAutoReport(true);
  cfg.setControllerType(CONTROLLER_TYPE_GAMEPAD);
  cfg.setButtonCount(16);
  cfg.setHatSwitchCount(1);
  cfg.setWhichAxes(true, true, true, true, false, false, false, false);   // X Y Z RZ (two sticks)
  cfg.setWhichSimulationControls(false, false, false, false, false);
  cfg.setIncludeStart(true); cfg.setIncludeSelect(true); cfg.setIncludeHome(true);
  cfg.setVid(0x303a); cfg.setPid(0x8001);   // Espressif VID, our own PID: a generic gamepad, no OS quirks
  pad.begin(&cfg);
  Serial.println("ok boot Holodor BLE Pad");
}

void loop() {
  static String line;
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n' || c == '\r') {
      line.trim();
      if (line.length()) handle(line);
      line = "";
    } else line += c;
  }
}

void handle(const String& line) {
  int sp = line.indexOf(' ');
  String cmd = sp < 0 ? line : line.substring(0, sp);
  String rest = sp < 0 ? "" : line.substring(sp + 1);
  if (cmd == "status") { Serial.printf("ok connected=%d\n", pad.isConnected() ? 1 : 0); return; }
  if (cmd == "name")   { Serial.println("ok Holodor BLE Pad"); return; }
  if (!pad.isConnected()) { Serial.println("err not-connected"); return; }
  if (cmd == "press" || cmd == "hold" || cmd == "release") {
    int b = buttonFor(rest); if (b < 0) { Serial.println("err button"); return; }
    if (cmd == "release") pad.release(b);
    else { pad.press(b); if (cmd == "press") { delay(120); pad.release(b); } }
    Serial.printf("ok %s %s\n", cmd.c_str(), rest.c_str()); return;
  }
  if (cmd == "dpad") {
    int h = hatFor(rest); if (h < 0) { Serial.println("err dir"); return; }
    pad.setHat1(h); if (h != DPAD_CENTERED) { delay(120); pad.setHat1(DPAD_CENTERED); }
    Serial.printf("ok dpad %s\n", rest.c_str()); return;
  }
  if (cmd == "stick") {
    char side; float x, y;
    if (sscanf(rest.c_str(), "%c %f %f", &side, &x, &y) != 3) { Serial.println("err stick"); return; }
    if (side == 'L') pad.setLeftThumb(axis(x), axis(y)); else pad.setRightThumb(axis(x), axis(y));
    Serial.printf("ok stick %c\n", side); return;
  }
  if (cmd == "trig") {
    char side; float v;
    if (sscanf(rest.c_str(), "%c %f", &side, &v) != 2) { Serial.println("err trig"); return; }
    if (side == 'L') pad.setLeftTrigger(axis(v)); else pad.setRightTrigger(axis(v));
    Serial.printf("ok trig %c\n", side); return;
  }
  Serial.println("err unknown");
}

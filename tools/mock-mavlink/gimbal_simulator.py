#!/usr/bin/env python3
"""
Interactive MAVLink Gimbal Simulator for QGroundControl testing.

Simulates a minimal vehicle PLUS an interactive Gimbal v2 manager/device so you
can exercise QGC's gimbal control UI without any hardware. Unlike the built-in
MockLink (which reports a fixed 0-degree attitude and ignores commands), this
script *reacts* to your controls: when you pitch/yaw the gimbal in QGC, it slews
to the commanded angle (or integrates a commanded rate) and streams the new
attitude back, so the on-screen gimbal indicator actually moves.

It is wired to match src/Gimbal/GimbalController.cc in this repo:
  QGC discovers a gimbal manager from a component HEARTBEAT, then requests
  GIMBAL_MANAGER_INFORMATION (via MAV_CMD_REQUEST_MESSAGE). We answer with the
  manager info, and continuously stream GIMBAL_MANAGER_STATUS +
  GIMBAL_DEVICE_ATTITUDE_STATUS. Control comes in as:
    - MAV_CMD_DO_GIMBAL_MANAGER_CONFIGURE  -> acquire/release primary control
    - MAV_CMD_DO_GIMBAL_MANAGER_PITCHYAW   -> angle (param1/2) or rate (param3/4)
Note: GimbalController only starts the handshake AFTER parametersReady(), so this
script also emulates the autopilot heartbeat/params/mission handshake.

Usage:
    python gimbal_simulator.py                 # UDP -> 127.0.0.1:14550 (QGC auto-connect)
    python gimbal_simulator.py --port 14550
    python gimbal_simulator.py --verbose       # log every gimbal command received

In QGC this appears as a normal vehicle with a gimbal; open your gimbal control
UI and drag/point the gimbal - you should see the indicator follow.

Requirements: pip install pymavlink   (already present in this environment)
"""

import argparse
import math
import os
import sys
import threading
import time

# Gimbal v2 messages (GIMBAL_MANAGER_*, GIMBAL_DEVICE_*) have msgids > 255 and
# only exist in the MAVLink 2 "common" dialect, so force both BEFORE importing
# pymavlink (mavutil picks its dialect/version at import time).
os.environ.setdefault("MAVLINK20", "1")
os.environ.setdefault("MAVLINK_DIALECT", "common")

try:
    from pymavlink import mavutil
    from pymavlink.dialects.v20 import common as mavlink
except ImportError:
    print("Error: pymavlink not installed. Install with: pip install pymavlink")
    sys.exit(1)

# Component that hosts the gimbal manager + device. QGC addresses gimbal
# commands to this component id (managerCompid) and expects attitude from it.
GIMBAL_COMP = mavlink.MAV_COMP_ID_GIMBAL          # 154
GIMBAL_DEVICE_ID = 1                              # 1..6 (must match in INFO/STATUS/ATTITUDE)

# Default physical limits reported in GIMBAL_MANAGER_INFORMATION (overridable via CLI).
# Kept permissive so the UI is not clamped during UX testing; set them to your
# real gimbal's limits with --pitch-min/max --yaw-min/max to catch over-commands.
PITCH_MIN_DEG, PITCH_MAX_DEG = -90.0, 90.0
YAW_MIN_DEG, YAW_MAX_DEG = -180.0, 180.0
MAX_SLEW_DEG_S = 90.0                             # how fast we move toward a target angle

# GIMBAL_MANAGER_FLAGS bit -> short name, for decoding what QGC's UI sends.
_MGR_FLAG_NAMES = [
    (mavlink.GIMBAL_MANAGER_FLAGS_RETRACT, "RETRACT"),
    (mavlink.GIMBAL_MANAGER_FLAGS_NEUTRAL, "NEUTRAL"),
    (mavlink.GIMBAL_MANAGER_FLAGS_ROLL_LOCK, "ROLL_LOCK"),
    (mavlink.GIMBAL_MANAGER_FLAGS_PITCH_LOCK, "PITCH_LOCK"),
    (mavlink.GIMBAL_MANAGER_FLAGS_YAW_LOCK, "YAW_LOCK"),
    (mavlink.GIMBAL_MANAGER_FLAGS_YAW_IN_VEHICLE_FRAME, "YAW_IN_VEHICLE_FRAME"),
    (mavlink.GIMBAL_MANAGER_FLAGS_YAW_IN_EARTH_FRAME, "YAW_IN_EARTH_FRAME"),
]


def _decode_mgr_flags(flags: int):
    return [name for bit, name in _MGR_FLAG_NAMES if flags & bit] or ["<none>"]


def _wrap180(deg: float) -> float:
    """Wrap an angle to (-180, 180]."""
    while deg > 180.0:
        deg -= 360.0
    while deg <= -180.0:
        deg += 360.0
    return deg


def _to360(deg: float) -> float:
    """Normalize an angle to [0, 360) for display (so -90 shows as 270)."""
    return deg % 360.0


def _euler_to_quat(roll, pitch, yaw):
    """Euler (radians) -> quaternion [w, x, y, z]."""
    cy, sy = math.cos(yaw * 0.5), math.sin(yaw * 0.5)
    cp, sp = math.cos(pitch * 0.5), math.sin(pitch * 0.5)
    cr, sr = math.cos(roll * 0.5), math.sin(roll * 0.5)
    return [
        cr * cp * cy + sr * sp * sy,  # w
        sr * cp * cy - cr * sp * sy,  # x
        cr * sp * cy + sr * cp * sy,  # y
        cr * cp * sy - sr * sp * cy,  # z
    ]


class GimbalSimulator:
    def __init__(self, system_id=1, verbose=False,
                 pitch_min=PITCH_MIN_DEG, pitch_max=PITCH_MAX_DEG,
                 yaw_min=YAW_MIN_DEG, yaw_max=YAW_MAX_DEG,
                 expect_pitch=None, expect_yaw=None, tol=3.0):
        self.system_id = system_id
        self.autopilot_comp = mavlink.MAV_COMP_ID_AUTOPILOT1  # 1
        self.verbose = verbose
        self.conn = None
        self.start = time.time()

        # --- reported limits (advertised to QGC; also used for range checks) ---
        self.pitch_min, self.pitch_max = pitch_min, pitch_max
        self.yaw_min, self.yaw_max = yaw_min, yaw_max

        # --- optional expected target for a pass/fail verdict ---
        self.expect_pitch = expect_pitch       # deg or None
        self.expect_yaw = expect_yaw           # deg (any convention) or None
        self.tol = tol
        self._converged = False

        # --- gimbal state ---
        self.cur_pitch = 0.0       # degrees, current (reported) attitude
        self.cur_yaw = 0.0
        self.tgt_pitch = 0.0       # degrees, commanded angle target
        self.tgt_yaw = 0.0
        self.pitch_rate = 0.0      # deg/s, commanded rate (0 = angle mode)
        self.yaw_rate = 0.0
        self.yaw_lock = False      # earth-frame (locked) vs vehicle-frame (follow)
        self.manager_flags = 0
        # who holds primary control (set by DO_GIMBAL_MANAGER_CONFIGURE)
        self.ctrl_sysid = 0
        self.ctrl_compid = 0

        # --- validation bookkeeping ---
        self.cmd_count = 0
        self._last_log = None      # (mode, pitch, yaw, flags) of last logged command
        self._quit = False
        self.read_stdin = False    # force keyboard input even if stdin isn't a TTY

    # ---- connection ---------------------------------------------------------
    def connect_udp(self, host, port):
        self.conn = mavutil.mavlink_connection(
            f"udpout:{host}:{port}",
            source_system=self.system_id,
            source_component=self.autopilot_comp,
            dialect="common",
        )
        print(f"[gimbal-sim] UDP -> {host}:{port} (sysid {self.system_id})")

    def _boot_ms(self):
        return int((time.time() - self.start) * 1000) & 0xFFFFFFFF

    def _send_as(self, compid, send_fn, *args):
        """Send a message using a specific source component id on one socket."""
        prev = self.conn.mav.srcComponent
        self.conn.mav.srcComponent = compid
        try:
            send_fn(*args)
        finally:
            self.conn.mav.srcComponent = prev

    # ---- autopilot side (minimal handshake so QGC reaches parametersReady) --
    def send_autopilot_heartbeat(self):
        self.conn.mav.heartbeat_send(
            mavlink.MAV_TYPE_QUADROTOR,
            mavlink.MAV_AUTOPILOT_ARDUPILOTMEGA,
            mavlink.MAV_MODE_FLAG_CUSTOM_MODE_ENABLED,
            0,
            mavlink.MAV_STATE_ACTIVE,
        )

    def send_gimbal_heartbeat(self):
        # A heartbeat from the gimbal component is what makes QGC add it as a
        # "potential gimbal manager" and request GIMBAL_MANAGER_INFORMATION.
        self._send_as(
            GIMBAL_COMP,
            self.conn.mav.heartbeat_send,
            mavlink.MAV_TYPE_GIMBAL,
            mavlink.MAV_AUTOPILOT_INVALID,
            0,
            0,
            mavlink.MAV_STATE_ACTIVE,
        )

    def send_parameters(self):
        params = [
            ("SYSID_THISMAV", float(self.system_id)),
            ("BATT_CAPACITY", 5000.0),
            ("RTL_ALT", 30.0),
            ("MNT1_TYPE", 1.0),
        ]
        for i, (name, value) in enumerate(params):
            self.conn.mav.param_value_send(
                name.encode("utf-8"), value,
                mavlink.MAV_PARAM_TYPE_REAL32, len(params), i,
            )

    def send_autopilot_version(self):
        self.conn.mav.autopilot_version_send(
            mavlink.MAV_PROTOCOL_CAPABILITY_MISSION_FLOAT
            | mavlink.MAV_PROTOCOL_CAPABILITY_PARAM_FLOAT
            | mavlink.MAV_PROTOCOL_CAPABILITY_COMMAND_INT,
            0x04000000, 0, 0, 0,
            bytes(8), bytes(8), bytes(8), 0, 0, 0,
        )

    def send_command_ack(self, command, result, compid=None):
        fn = self.conn.mav.command_ack_send
        if compid is None:
            fn(command, result)
        else:
            self._send_as(compid, fn, command, result)

    # ---- gimbal telemetry ---------------------------------------------------
    def send_gimbal_manager_information(self):
        cap = (
            mavlink.GIMBAL_MANAGER_CAP_FLAGS_HAS_ROLL_AXIS
            | mavlink.GIMBAL_MANAGER_CAP_FLAGS_HAS_ROLL_LOCK
            | mavlink.GIMBAL_MANAGER_CAP_FLAGS_HAS_PITCH_AXIS
            | mavlink.GIMBAL_MANAGER_CAP_FLAGS_HAS_PITCH_FOLLOW
            | mavlink.GIMBAL_MANAGER_CAP_FLAGS_HAS_PITCH_LOCK
            | mavlink.GIMBAL_MANAGER_CAP_FLAGS_HAS_YAW_AXIS
            | mavlink.GIMBAL_MANAGER_CAP_FLAGS_HAS_YAW_FOLLOW
            | mavlink.GIMBAL_MANAGER_CAP_FLAGS_HAS_YAW_LOCK
            | mavlink.GIMBAL_MANAGER_CAP_FLAGS_SUPPORTS_YAW_IN_EARTH_FRAME
        )
        self._send_as(
            GIMBAL_COMP,
            self.conn.mav.gimbal_manager_information_send,
            self._boot_ms(), cap, GIMBAL_DEVICE_ID,
            math.radians(-30.0), math.radians(30.0),          # roll min/max
            math.radians(self.pitch_min), math.radians(self.pitch_max),
            math.radians(self.yaw_min), math.radians(self.yaw_max),
        )
        if self.verbose:
            print("[gimbal-sim] -> GIMBAL_MANAGER_INFORMATION")

    def send_gimbal_manager_status(self):
        self._send_as(
            GIMBAL_COMP,
            self.conn.mav.gimbal_manager_status_send,
            self._boot_ms(), self.manager_flags, GIMBAL_DEVICE_ID,
            self.ctrl_sysid, self.ctrl_compid,   # primary control
            0, 0,                                 # secondary control
        )

    def send_gimbal_device_attitude_status(self):
        q = _euler_to_quat(0.0, math.radians(self.cur_pitch), math.radians(self.cur_yaw))
        flags = (
            mavlink.GIMBAL_DEVICE_FLAGS_ROLL_LOCK
            | mavlink.GIMBAL_DEVICE_FLAGS_PITCH_LOCK
        )
        if self.yaw_lock:
            flags |= mavlink.GIMBAL_DEVICE_FLAGS_YAW_LOCK | mavlink.GIMBAL_DEVICE_FLAGS_YAW_IN_EARTH_FRAME
        else:
            flags |= mavlink.GIMBAL_DEVICE_FLAGS_YAW_IN_VEHICLE_FRAME

        args = [
            0, 0,                 # target system / component
            self._boot_ms(), flags, q,
            0.0, 0.0, 0.0,        # angular velocity x/y/z
            0,                    # failure flags
        ]
        # gimbal_device_id must be 1..6 to pair with the manager (see
        # GimbalController::_handleGimbalDeviceAttitudeStatus). Extension fields
        # (delta_yaw, delta_yaw_velocity, gimbal_device_id) exist in newer
        # dialects; fall back gracefully if this build predates them.
        try:
            self._send_as(
                GIMBAL_COMP,
                self.conn.mav.gimbal_device_attitude_status_send,
                *args, float("nan"), float("nan"), GIMBAL_DEVICE_ID,
            )
        except TypeError:
            self._send_as(
                GIMBAL_COMP,
                self.conn.mav.gimbal_device_attitude_status_send,
                *args,
            )

    # ---- incoming -----------------------------------------------------------
    def handle_incoming(self):
        while True:
            try:
                msg = self.conn.recv_match(blocking=False)
            except OSError:
                # On Windows a udpout socket raises WinError 10022 until it has
                # sent at least once; harmless, just try again next tick.
                return
            if msg is None:
                return
            t = msg.get_type()
            if t == "COMMAND_LONG":
                self.handle_command_long(msg)
            elif t == "PARAM_REQUEST_LIST":
                self.send_parameters()
            elif t == "MISSION_REQUEST_LIST":
                # Report empty mission/geofence/rally so downloads complete.
                mtype = getattr(msg, "mission_type", 0)
                self.conn.mav.mission_count_send(self.system_id, self.autopilot_comp, 0, mtype)

    def handle_command_long(self, msg):
        cmd = msg.command

        if cmd == mavlink.MAV_CMD_REQUEST_MESSAGE:
            if int(msg.param1) == mavlink.MAVLINK_MSG_ID_GIMBAL_MANAGER_INFORMATION:
                self.send_gimbal_manager_information()
                self.send_command_ack(cmd, mavlink.MAV_RESULT_ACCEPTED, compid=GIMBAL_COMP)
            elif int(msg.param1) == mavlink.MAVLINK_MSG_ID_AUTOPILOT_VERSION:
                self.send_autopilot_version()
                self.send_command_ack(cmd, mavlink.MAV_RESULT_ACCEPTED)
            else:
                self.send_command_ack(cmd, mavlink.MAV_RESULT_ACCEPTED)

        elif cmd == mavlink.MAV_CMD_REQUEST_AUTOPILOT_CAPABILITIES:
            self.send_autopilot_version()
            self.send_command_ack(cmd, mavlink.MAV_RESULT_ACCEPTED)

        elif cmd == mavlink.MAV_CMD_DO_GIMBAL_MANAGER_CONFIGURE:
            self.handle_configure(msg)
            self.send_command_ack(cmd, mavlink.MAV_RESULT_ACCEPTED, compid=GIMBAL_COMP)

        elif cmd == mavlink.MAV_CMD_DO_GIMBAL_MANAGER_PITCHYAW:
            self.handle_pitchyaw(msg)
            self.send_command_ack(cmd, mavlink.MAV_RESULT_ACCEPTED, compid=GIMBAL_COMP)

        else:
            self.send_command_ack(cmd, mavlink.MAV_RESULT_ACCEPTED)

    def handle_configure(self, msg):
        # param1/param2 = desired primary control sysid/compid.
        #   >0 -> that GCS takes control;  -3 -> release;  -1/-2 -> leave unchanged
        p1, p2 = int(msg.param1), int(msg.param2)
        if p1 == -3 or p2 == -3:
            self.ctrl_sysid, self.ctrl_compid = 0, 0
            action = "released"
        elif p1 >= 0 and p2 >= 0 and (p1 != 0 or p2 != 0):
            self.ctrl_sysid, self.ctrl_compid = p1, p2
            action = f"acquired by {p1}/{p2}"
        else:
            action = "unchanged"
        # Push a fresh status immediately so QGC's "in control" state updates fast.
        self.send_gimbal_manager_status()
        t = time.time() - self.start
        print(f"[{t:6.1f}s] CONFIGURE: control {action}")

    def handle_pitchyaw(self, msg):
        pitch, yaw = msg.param1, msg.param2       # degrees (NaN if rate mode)
        pitch_rate, yaw_rate = msg.param3, msg.param4  # deg/s (NaN if angle mode)
        flags = int(msg.param5)
        dev_id = int(msg.param7)
        self.cmd_count += 1
        self.manager_flags = flags
        self.yaw_lock = bool(flags & mavlink.GIMBAL_MANAGER_FLAGS_YAW_LOCK)

        issues = []
        if self.ctrl_sysid == 0 and self.ctrl_compid == 0:
            issues.append("no control acquired (should CONFIGURE first)")
        if dev_id not in (0, GIMBAL_DEVICE_ID):
            issues.append(f"device_id {dev_id} != {GIMBAL_DEVICE_ID}")

        angle_mode = not math.isnan(pitch) or not math.isnan(yaw)
        if angle_mode:
            self.pitch_rate = self.yaw_rate = 0.0
            if not math.isnan(pitch):
                if pitch < self.pitch_min - 0.5 or pitch > self.pitch_max + 0.5:
                    issues.append(f"pitch {pitch:+.1f} out of [{self.pitch_min:+.0f},{self.pitch_max:+.0f}]")
                self.tgt_pitch = max(self.pitch_min, min(self.pitch_max, pitch))
            if not math.isnan(yaw):
                self.tgt_yaw = _wrap180(yaw)
            self._log_command("ANGLE", pitch, yaw, flags, issues)
        else:
            self.pitch_rate = 0.0 if math.isnan(pitch_rate) else pitch_rate
            self.yaw_rate = 0.0 if math.isnan(yaw_rate) else yaw_rate
            self._log_command("RATE", pitch_rate, yaw_rate, flags, issues)

    def _log_command(self, mode, p, y, flags, issues):
        # Throttle: only print when the command meaningfully changes.
        key = (mode, round(p, 1) if not math.isnan(p) else None,
               round(y, 1) if not math.isnan(y) else None, flags)
        if key == self._last_log:
            return
        self._last_log = key

        frame = "EARTH/absolute" if self.yaw_lock else "VEHICLE/body"
        t = time.time() - self.start
        if mode == "ANGLE":
            ptxt = "  --  " if math.isnan(p) else f"{p:+6.1f}deg"
            ytxt = "  --  " if math.isnan(y) else f"{y:+6.1f}deg ({_to360(y):5.1f})"
            body = f"ANGLE P={ptxt} Y={ytxt}"
        else:
            body = f"RATE  Pdot={p:+5.1f}/s Ydot={y:+5.1f}/s"
        verdict = "OK" if not issues else "WARN: " + "; ".join(issues)
        mark = "  " if not issues else "!!"
        print(f"[{t:6.1f}s] #{self.cmd_count:<4} {mark} {body}  frame={frame}  "
              f"ctrl={self.ctrl_sysid}/{self.ctrl_compid}  flags=[{'|'.join(_decode_mgr_flags(flags))}]  {verdict}")

    def _check_converged(self):
        """If an expected target was given, announce PASS once the gimbal reaches it."""
        if self._converged or (self.expect_pitch is None and self.expect_yaw is None):
            return
        ok = True
        if self.expect_pitch is not None:
            ok = ok and abs(self.cur_pitch - self.expect_pitch) <= self.tol
        if self.expect_yaw is not None:
            ok = ok and abs(_wrap180(self.cur_yaw - _wrap180(self.expect_yaw))) <= self.tol
        if ok:
            self._converged = True
            t = time.time() - self.start
            exp = []
            if self.expect_pitch is not None:
                exp.append(f"pitch {self.expect_pitch:+.1f}")
            if self.expect_yaw is not None:
                exp.append(f"yaw {self.expect_yaw:+.1f} ({_to360(self.expect_yaw):.0f})")
            print(f"\n  ===> PASS [{t:5.1f}s]  gimbal reached {' , '.join(exp)}  "
                  f"(now P={self.cur_pitch:+.1f} Y={self.cur_yaw:+.1f}/{_to360(self.cur_yaw):.0f}, tol {self.tol:.0f}deg)\n")

    # ---- motion integration -------------------------------------------------
    def update(self, dt):
        if self.pitch_rate != 0.0 or self.yaw_rate != 0.0:
            self.cur_pitch += self.pitch_rate * dt
            self.cur_yaw += self.yaw_rate * dt
        else:
            self.cur_pitch = self._slew(self.cur_pitch, self.tgt_pitch, dt)
            self.cur_yaw = self._slew(self.cur_yaw, _wrap180(self.tgt_yaw), dt)

        self.cur_pitch = max(self.pitch_min, min(self.pitch_max, self.cur_pitch))
        self.cur_yaw = _wrap180(self.cur_yaw)

    @staticmethod
    def _slew(cur, tgt, dt):
        step = MAX_SLEW_DEG_S * dt
        diff = tgt - cur
        if abs(diff) <= step:
            return tgt
        return cur + math.copysign(step, diff)

    # ---- keyboard input: type an angle -> gimbal moves -> QGC reflects it ----
    def _print_input_help(self):
        print("\n[input] type a target and press Enter (QGC's P/Y readout will follow):")
        print("        <pitch> <yaw>   e.g.  -45 270      set both (deg)")
        print("        p <deg>         e.g.  p -30        set pitch only")
        print("        y <deg>         e.g.  y 90         set yaw only (0-360 or +/-180)")
        print("        c | center      go to 0, 0")
        print("        lock on|off     yaw earth-frame (lock) vs vehicle-frame (follow)")
        print("        h | q           help | quit\n")

    def _input_loop(self):
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                self._handle_input(line)
            except Exception:  # never let a bad line kill the input thread
                pass

    def _set_target(self, pitch=None, yaw=None):
        # Typed angle behaves like an external command: clear rates and slew there.
        self.pitch_rate = self.yaw_rate = 0.0
        if pitch is not None:
            clamped = max(self.pitch_min, min(self.pitch_max, pitch))
            self.tgt_pitch = clamped
            note = "" if abs(clamped - pitch) < 0.05 else f" (clamped from {pitch:+.1f})"
            print(f"[input] -> pitch target {clamped:+.1f}{note}")
        if yaw is not None:
            w = _wrap180(yaw)
            self.tgt_yaw = w
            extra = "" if abs(w - yaw) < 0.05 else f"  (QGC shows {w:+.1f}deg)"
            print(f"[input] -> yaw target {yaw:+.1f} ({_to360(yaw):.0f}deg){extra}")

    @staticmethod
    def _num(s):
        try:
            return float(s)
        except ValueError:
            return None

    def _handle_input(self, line):
        # Ignore the script's own console output / help text if it is ever fed
        # back into stdin (stdout coupled to stdin, or a log piped in).
        if line.startswith(("[", "=", "<")) or "e.g." in line or "->" in line:
            return

        low = line.lower()
        if low in ("h", "help", "?"):
            self._print_input_help(); return
        if low in ("q", "quit", "exit"):
            print("[input] quitting..."); self._quit = True; return
        if low in ("c", "center", "recenter", "re-center"):
            self._set_target(pitch=0.0, yaw=0.0); return
        if low in ("lock on", "lock off"):
            self.yaw_lock = low.endswith("on")
            print(f"[input] yaw_lock = {self.yaw_lock} "
                  f"({'EARTH/absolute' if self.yaw_lock else 'VEHICLE/body'})")
            return

        # Keyword form in any order: 'p -45 y 270', 'pitch -45 yaw 270', 'y 90 p -30'.
        toks = line.replace(",", " ").split()
        low_toks = [t.lower() for t in toks]
        pitch = yaw = None
        matched = False
        i = 0
        while i < len(toks):
            nxt = self._num(toks[i + 1]) if i + 1 < len(toks) else None
            if low_toks[i] in ("p", "pitch") and nxt is not None:
                pitch = nxt; i += 2; matched = True; continue
            if low_toks[i] in ("y", "yaw") and nxt is not None:
                yaw = nxt; i += 2; matched = True; continue
            i += 1
        if matched:
            self._set_target(pitch=pitch, yaw=yaw); return

        # Bare numbers: '<pitch>' or '<pitch> <yaw>'.
        n0 = self._num(toks[0])
        if n0 is not None:
            n1 = self._num(toks[1]) if len(toks) >= 2 else None
            self._set_target(pitch=n0, yaw=n1)
            return
        # Unrecognized: stay silent. Real typos are rare and 'h' shows help;
        # silence guarantees echoed output can never cause feedback spam.

    # ---- main loop ----------------------------------------------------------
    def run(self):
        print("[gimbal-sim] running. Connect QGC, open gimbal control, drag to move. Ctrl+C to stop.")
        # Prime the udpout socket with an initial send so subsequent recv works
        # (Windows rejects recvfrom on a udpout socket that hasn't sent yet).
        self.send_autopilot_heartbeat()
        self.send_gimbal_heartbeat()

        # Enable "type an angle" control when running in a real terminal
        # (or when forced with --stdin for IDE terminals / piped input).
        if self.read_stdin or (sys.stdin and sys.stdin.isatty()):
            threading.Thread(target=self._input_loop, daemon=True).start()
            self._print_input_help()

        last_hb = last_status = last_att = last_update = last_live = 0.0
        try:
            while not self._quit:
                now = time.time()
                self.handle_incoming()

                if now - last_hb >= 1.0:            # 1 Hz heartbeats
                    self.send_autopilot_heartbeat()
                    self.send_gimbal_heartbeat()
                    last_hb = now

                if now - last_update >= 0.02:       # 50 Hz motion integration
                    self.update(now - last_update if last_update else 0.02)
                    self._check_converged()
                    last_update = now

                if now - last_status >= 0.2:        # 5 Hz manager status
                    self.send_gimbal_manager_status()
                    last_status = now

                if now - last_att >= 0.05:          # 20 Hz attitude
                    self.send_gimbal_device_attitude_status()
                    last_att = now

                # Live attitude readout (only in --verbose, to avoid clutter).
                if self.verbose and now - last_live >= 0.5:
                    print(f"    live  P={self.cur_pitch:+6.1f}  "
                          f"Y={self.cur_yaw:+6.1f} ({_to360(self.cur_yaw):5.1f})", end="\r")
                    last_live = now

                time.sleep(0.005)
        except KeyboardInterrupt:
            print("\n[gimbal-sim] stopped.")


def main():
    # Line-buffer stdout so command logs appear immediately, even when piped to a file.
    try:
        sys.stdout.reconfigure(line_buffering=True)
    except AttributeError:
        pass

    p = argparse.ArgumentParser(description="Interactive MAVLink gimbal simulator for QGC")
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=14550, help="QGC UDP auto-connect port (default 14550)")
    p.add_argument("--system-id", type=int, default=1)
    p.add_argument("--verbose", action="store_true", help="also show a live attitude readout")
    p.add_argument("--pitch-min", type=float, default=PITCH_MIN_DEG, help="advertised/enforced pitch min (deg)")
    p.add_argument("--pitch-max", type=float, default=PITCH_MAX_DEG, help="advertised/enforced pitch max (deg)")
    p.add_argument("--yaw-min", type=float, default=YAW_MIN_DEG, help="advertised yaw min (deg)")
    p.add_argument("--yaw-max", type=float, default=YAW_MAX_DEG, help="advertised yaw max (deg)")
    p.add_argument("--expect-pitch", type=float, default=None,
                   help="print PASS when the gimbal reaches this pitch (deg)")
    p.add_argument("--expect-yaw", type=float, default=None,
                   help="print PASS when the gimbal reaches this yaw (deg; 270 == -90)")
    p.add_argument("--tol", type=float, default=3.0, help="convergence tolerance for --expect (deg)")
    p.add_argument("--stdin", action="store_true",
                   help="force keyboard input even if stdin isn't a detected TTY")
    p.add_argument("--selftest", action="store_true", help="pack all messages once and exit (no network)")
    args = p.parse_args()

    sim = GimbalSimulator(
        system_id=args.system_id, verbose=args.verbose,
        pitch_min=args.pitch_min, pitch_max=args.pitch_max,
        yaw_min=args.yaw_min, yaw_max=args.yaw_max,
        expect_pitch=args.expect_pitch, expect_yaw=args.expect_yaw, tol=args.tol,
    )
    sim.read_stdin = args.stdin

    if args.selftest:
        # Verify every message packs against the installed dialect without QGC.
        sim.conn = mavutil.mavlink_connection(
            "udpout:127.0.0.1:59999",
            source_system=args.system_id,
            source_component=sim.autopilot_comp,
            dialect="common",
        )
        sim.send_autopilot_heartbeat()
        sim.send_gimbal_heartbeat()
        sim.send_parameters()
        sim.send_autopilot_version()
        sim.send_gimbal_manager_information()
        sim.send_gimbal_manager_status()
        sim.send_gimbal_device_attitude_status()
        sim.update(0.02)
        print("[gimbal-sim] selftest OK - all messages packed and motion integrated.")
        return

    sim.connect_udp(args.host, args.port)
    sim.run()


if __name__ == "__main__":
    main()

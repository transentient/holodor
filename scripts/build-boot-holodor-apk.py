#!/usr/bin/env python3
"""
Deterministic pure-Python builder for BootHolodor.apk (org.holodor.boot).

Generates a self-contained, 1-tap Android launcher APK signed with both
APK Signature Scheme v1 (JAR) and APK Signature Scheme v2 (APK Sig Block 42)
using only Python 3 standard library + /usr/bin/openssl.

When tapped on Android, org.holodor.boot.MainActivity:
  1. Shows a Toast ("Rebooting into Holodor Linux...")
  2. Connects to AYN/Retroid's native root Binder service ("PServerBinder",
     backed by /system/bin/pservice on Odin 2/Mini/Portal/Odin 3 and Retroid
     Pocket 5/Mini/Flip 2) and writes 'ROCKNIX\\0\\0' (BootMode = 0x00 = Linux)
     at offset 2448 (0x990) of /dev/block/by-name/devinfo, then reboots.
  3. Falls back to standard 'su -c' for custom rooted Android ROMs.
"""

import base64
import hashlib
import math
import os
import struct
import subprocess
import sys
import tempfile
import zlib


def uleb128(val: int) -> bytes:
    out = bytearray()
    while True:
        b = val & 0x7F
        val >>= 7
        if val:
            out.append(b | 0x80)
        else:
            out.append(b)
            break
    return bytes(out)


def align4(buf: bytearray) -> None:
    while len(buf) % 4 != 0:
        buf.append(0)


# ---------------------------------------------------------------------------
# 1. Dalvik Bytecode (classes.dex)
# ---------------------------------------------------------------------------
def build_classes_dex() -> bytes:
    cmd1 = (
        "DEV=/dev/block/by-name/devinfo; "
        "OOFF=$(grep -abo OablSettings \"$DEV\" 2>/dev/null | head -n 1 | cut -d: -f1); "
        "if [ -n \"$OOFF\" ] && [ \"$OOFF\" -ge 2456 ]; then "
        "B=$(dd if=\"$DEV\" bs=1 skip=$((OOFF + 58)) count=1 2>/dev/null | od -An -tu1 | tr -d ' '); "
        "[ -n \"$B\" ] && printf \"\\\\$(printf '%03o' $(((B & 252) | 1)))\" | dd of=\"$DEV\" bs=1 seek=$((OOFF + 58)) count=1 conv=notrunc 2>/dev/null; "
        "fi; "
        "OFF=$(grep -abo BootMode \"$DEV\" 2>/dev/null | head -n 1 | cut -d: -f1); "
        "[ -n \"$OFF\" ] && [ \"$OFF\" -ge 2456 ] && printf '\\x00' | dd of=\"$DEV\" bs=1 seek=$((OFF + 56)) count=1 conv=notrunc 2>/dev/null"
    )
    cmd2 = "sync; setprop sys.powerctl reboot; reboot"
    su_cmd = f"{cmd1}; {cmd2}"

    raw_strings = [
        "-c",
        "0",
        "<init>",
        "I",
        "L",
        "LL",
        "LLLI",
        "Landroid/app/Activity;",
        "Landroid/content/Context;",
        "Landroid/os/Bundle;",
        "Landroid/os/IBinder;",
        "Landroid/os/Parcel;",
        "Landroid/os/ServiceManager;",
        "Landroid/widget/Toast;",
        "Ljava/lang/CharSequence;",
        "Ljava/lang/Object;",
        "Ljava/lang/Process;",
        "Ljava/lang/Runtime;",
        "Ljava/lang/String;",
        "Ljava/lang/Throwable;",
        "Lorg/holodor/boot/MainActivity;",
        "MainActivity.java",
        "PServerBinder",
        "Rebooting into Holodor Linux...",
        "V",
        "VL",
        "VLL",
        "Z",
        "ZILLI",
        "[Ljava/lang/String;",
        "bootHolodor",
        "exec",
        "execPServer",
        "finish",
        "getRuntime",
        "getService",
        "makeText",
        "obtain",
        "onCreate",
        cmd1,
        su_cmd,
        "recycle",
        "show",
        "su",
        cmd2,
        "transact",
        "writeStringArray",
    ]
    strings = sorted(set(raw_strings))
    sidx = {s: i for i, s in enumerate(strings)}

    raw_types = [
        "I",
        "V",
        "Z",
        "Landroid/app/Activity;",
        "Landroid/content/Context;",
        "Landroid/os/Bundle;",
        "Landroid/os/IBinder;",
        "Landroid/os/Parcel;",
        "Landroid/os/ServiceManager;",
        "Landroid/widget/Toast;",
        "Ljava/lang/CharSequence;",
        "Ljava/lang/Object;",
        "Ljava/lang/Process;",
        "Ljava/lang/Runtime;",
        "Ljava/lang/String;",
        "Ljava/lang/Throwable;",
        "Lorg/holodor/boot/MainActivity;",
        "[Ljava/lang/String;",
    ]
    types = sorted(set(raw_types), key=lambda t: sidx[t])
    tidx = {t: i for i, t in enumerate(types)}

    raw_protos = [
        ("V", "V", ()),
        ("VL", "V", ("Landroid/os/Bundle;",)),
        ("VLL", "V", ("Landroid/os/IBinder;", "Ljava/lang/String;")),
        ("VL", "V", ("[Ljava/lang/String;",)),
        ("LL", "Landroid/os/IBinder;", ("Ljava/lang/String;",)),
        ("L", "Landroid/os/Parcel;", ()),
        ("LLLI", "Landroid/widget/Toast;", ("Landroid/content/Context;", "Ljava/lang/CharSequence;", "I")),
        ("LL", "Ljava/lang/Process;", ("[Ljava/lang/String;",)),
        ("L", "Ljava/lang/Runtime;", ()),
        ("ZILLI", "Z", ("I", "Landroid/os/Parcel;", "Landroid/os/Parcel;", "I")),
    ]
    protos = sorted(
        raw_protos,
        key=lambda p: (tidx[p[1]], tuple(tidx[t] for t in p[2])),
    )
    pidx = {(p[1], p[2]): i for i, p in enumerate(protos)}

    raw_methods = [
        ("Landroid/app/Activity;", "<init>", ("V", ())),
        ("Landroid/app/Activity;", "finish", ("V", ())),
        ("Landroid/app/Activity;", "onCreate", ("V", ("Landroid/os/Bundle;",))),
        ("Landroid/os/IBinder;", "transact", ("Z", ("I", "Landroid/os/Parcel;", "Landroid/os/Parcel;", "I"))),
        ("Landroid/os/Parcel;", "obtain", ("Landroid/os/Parcel;", ())),
        ("Landroid/os/Parcel;", "recycle", ("V", ())),
        ("Landroid/os/Parcel;", "writeStringArray", ("V", ("[Ljava/lang/String;",))),
        ("Landroid/os/ServiceManager;", "getService", ("Landroid/os/IBinder;", ("Ljava/lang/String;",))),
        ("Landroid/widget/Toast;", "makeText", ("Landroid/widget/Toast;", ("Landroid/content/Context;", "Ljava/lang/CharSequence;", "I"))),
        ("Landroid/widget/Toast;", "show", ("V", ())),
        ("Ljava/lang/Runtime;", "exec", ("Ljava/lang/Process;", ("[Ljava/lang/String;",))),
        ("Ljava/lang/Runtime;", "getRuntime", ("Ljava/lang/Runtime;", ())),
        ("Lorg/holodor/boot/MainActivity;", "<init>", ("V", ())),
        ("Lorg/holodor/boot/MainActivity;", "bootHolodor", ("V", ())),
        ("Lorg/holodor/boot/MainActivity;", "execPServer", ("V", ("Landroid/os/IBinder;", "Ljava/lang/String;"))),
        ("Lorg/holodor/boot/MainActivity;", "onCreate", ("V", ("Landroid/os/Bundle;",))),
    ]
    methods = sorted(
        raw_methods,
        key=lambda m: (tidx[m[0]], sidx[m[1]], pidx[m[2]]),
    )
    midx = {(m[0], m[1], m[2]): i for i, m in enumerate(methods)}

    # 1. <init>()V
    m_act_init = midx[("Landroid/app/Activity;", "<init>", ("V", ()))]
    insns_init = [
        0x1070, m_act_init, 0x0000,
        0x000E,
    ]
    code_init = struct.pack("<HHHHII", 1, 1, 1, 0, 0, len(insns_init)) + struct.pack(f"<{len(insns_init)}H", *insns_init)

    # 2. bootHolodor()V
    m_get_svc = midx[("Landroid/os/ServiceManager;", "getService", ("Landroid/os/IBinder;", ("Ljava/lang/String;",)))]
    m_exec_ps = midx[("Lorg/holodor/boot/MainActivity;", "execPServer", ("V", ("Landroid/os/IBinder;", "Ljava/lang/String;")))]
    m_get_rt = midx[("Ljava/lang/Runtime;", "getRuntime", ("Ljava/lang/Runtime;", ()))]
    m_rt_exec = midx[("Ljava/lang/Runtime;", "exec", ("Ljava/lang/Process;", ("[Ljava/lang/String;",)))]
    t_str_arr = tidx["[Ljava/lang/String;"]

    insns_boot = [
        0x001A, sidx["PServerBinder"],
        0x1071, m_get_svc, 0x0000,
        0x000C,
        0x0038, 0x000E,
        0x011A, sidx[cmd1],
        0x2071, m_exec_ps, 0x0010,
        0x011A, sidx[cmd2],
        0x2071, m_exec_ps, 0x0010,
        0x000E,
        0x000D,
        0x0071, m_get_rt, 0x0000,
        0x000C,
        0x3112,
        0x1123, t_str_arr,
        0x0212,
        0x031A, sidx["su"],
        0x034D, 0x0201,
        0x1212,
        0x031A, sidx["-c"],
        0x034D, 0x0201,
        0x2212,
        0x031A, sidx[su_cmd],
        0x034D, 0x0201,
        0x206E, m_rt_exec, 0x0010,
        0x000E,
        0x000D,
        0x000E,
    ]
    assert len(insns_boot) == 48
    tries_boot = struct.pack("<IHH", 0, 18, 1) + struct.pack("<IHH", 20, 25, 3)
    handlers_boot = bytes([0x02, 0x00, 19, 0x00, 46])
    code_boot = (
        struct.pack("<HHHHII", 4, 0, 2, 2, 0, len(insns_boot))
        + struct.pack(f"<{len(insns_boot)}H", *insns_boot)
        + tries_boot
        + handlers_boot
    )

    # 3. execPServer(Landroid/os/IBinder;Ljava/lang/String;)V
    m_obtain = midx[("Landroid/os/Parcel;", "obtain", ("Landroid/os/Parcel;", ()))]
    m_write_sa = midx[("Landroid/os/Parcel;", "writeStringArray", ("V", ("[Ljava/lang/String;",)))]
    m_transact = midx[("Landroid/os/IBinder;", "transact", ("Z", ("I", "Landroid/os/Parcel;", "Landroid/os/Parcel;", "I")))]
    m_recycle = midx[("Landroid/os/Parcel;", "recycle", ("V", ()))]

    insns_exec_ps = [
        0x0071, m_obtain, 0x0000,
        0x000C,
        0x0071, m_obtain, 0x0000,
        0x010C,
        0x2212,
        0x2223, t_str_arr,
        0x0312,
        0x054D, 0x0302,
        0x1312,
        0x051A, sidx["0"],
        0x054D, 0x0302,
        0x206E, m_write_sa, 0x0020,
        0x0212,
        0x5272, m_transact, 0x1024,
        0x106E, m_recycle, 0x0001,
        0x106E, m_recycle, 0x0000,
        0x000E,
    ]
    code_exec_ps = (
        struct.pack("<HHHHII", 6, 2, 5, 0, 0, len(insns_exec_ps))
        + struct.pack(f"<{len(insns_exec_ps)}H", *insns_exec_ps)
    )

    # 4. onCreate(Landroid/os/Bundle;)V
    m_super_oncreate = midx[("Landroid/app/Activity;", "onCreate", ("V", ("Landroid/os/Bundle;",)))]
    m_make_text = midx[("Landroid/widget/Toast;", "makeText", ("Landroid/widget/Toast;", ("Landroid/content/Context;", "Ljava/lang/CharSequence;", "I")))]
    m_toast_show = midx[("Landroid/widget/Toast;", "show", ("V", ()))]
    m_boot_holodor = midx[("Lorg/holodor/boot/MainActivity;", "bootHolodor", ("V", ()))]
    m_finish = midx[("Landroid/app/Activity;", "finish", ("V", ()))]

    insns_oncreate = [
        0x206F, m_super_oncreate, 0x0032,
        0x001A, sidx["Rebooting into Holodor Linux..."],
        0x1112,
        0x3071, m_make_text, 0x0102,
        0x000C,
        0x106E, m_toast_show, 0x0000,
        0x0071, m_boot_holodor, 0x0000,
        0x106E, m_finish, 0x0002,
        0x000E,
    ]
    code_oncreate = (
        struct.pack("<HHHHII", 4, 2, 3, 0, 0, len(insns_oncreate))
        + struct.pack(f"<{len(insns_oncreate)}H", *insns_oncreate)
    )

    hdr_size = 112
    string_ids_off = hdr_size
    type_ids_off = string_ids_off + len(strings) * 4
    proto_ids_off = type_ids_off + len(types) * 4
    field_ids_off = 0
    method_ids_off = proto_ids_off + len(protos) * 12
    class_defs_off = method_ids_off + len(methods) * 8
    data_off = class_defs_off + 1 * 32

    data_buf = bytearray()

    def cur_off() -> int:
        return data_off + len(data_buf)

    code_offs = []
    for cbytes in (code_init, code_boot, code_exec_ps, code_oncreate):
        align4(data_buf)
        code_offs.append(cur_off())
        data_buf.extend(cbytes)

    align4(data_buf)
    type_list_off_start = cur_off()
    proto_type_list_offs = {}
    unique_param_tuples = []
    for _, _, params in protos:
        if params and params not in unique_param_tuples:
            unique_param_tuples.append(params)
    for params in unique_param_tuples:
        align4(data_buf)
        proto_type_list_offs[params] = cur_off()
        data_buf.extend(struct.pack("<I", len(params)))
        for p in params:
            data_buf.extend(struct.pack("<H", tidx[p]))

    string_data_off_start = cur_off()
    string_data_offs = []
    for s in strings:
        string_data_offs.append(cur_off())
        raw = s.encode("utf-8")
        data_buf.extend(uleb128(len(s)))
        data_buf.extend(raw)
        data_buf.append(0)

    class_data_off = cur_off()
    cd = bytearray()
    cd.extend(uleb128(0))
    cd.extend(uleb128(0))
    cd.extend(uleb128(3))
    cd.extend(uleb128(1))

    direct_defs = sorted(
        [
            (midx[("Lorg/holodor/boot/MainActivity;", "<init>", ("V", ()))], 0x10001, code_offs[0]),
            (midx[("Lorg/holodor/boot/MainActivity;", "bootHolodor", ("V", ()))], 0x0009, code_offs[1]),
            (midx[("Lorg/holodor/boot/MainActivity;", "execPServer", ("V", ("Landroid/os/IBinder;", "Ljava/lang/String;")))], 0x000A, code_offs[2]),
        ],
        key=lambda x: x[0],
    )
    prev_m = 0
    for m_id, acc, c_off in direct_defs:
        cd.extend(uleb128(m_id - prev_m))
        prev_m = m_id
        cd.extend(uleb128(acc))
        cd.extend(uleb128(c_off))

    m_oncreate_id = midx[("Lorg/holodor/boot/MainActivity;", "onCreate", ("V", ("Landroid/os/Bundle;",)))]
    cd.extend(uleb128(m_oncreate_id))
    cd.extend(uleb128(0x0004))
    cd.extend(uleb128(code_offs[3]))
    data_buf.extend(cd)

    align4(data_buf)
    map_off = cur_off()
    map_items = [
        (0x0000, 1, 0),
        (0x0001, len(strings), string_ids_off),
        (0x0002, len(types), type_ids_off),
        (0x0003, len(protos), proto_ids_off),
        (0x0005, len(methods), method_ids_off),
        (0x0006, 1, class_defs_off),
        (0x2001, 4, code_offs[0]),
        (0x1001, len(unique_param_tuples), type_list_off_start),
        (0x2002, len(strings), string_data_off_start),
        (0x2000, 1, class_data_off),
        (0x1000, 1, map_off),
    ]
    data_buf.extend(struct.pack("<I", len(map_items)))
    for mtype, mcnt, moff in map_items:
        data_buf.extend(struct.pack("<HHII", mtype, 0, mcnt, moff))
    align4(data_buf)

    tables = bytearray()
    for off in string_data_offs:
        tables.extend(struct.pack("<I", off))
    for t in types:
        tables.extend(struct.pack("<I", sidx[t]))
    for sh, ret, params in protos:
        tl_off = proto_type_list_offs[params] if params else 0
        tables.extend(struct.pack("<III", sidx[sh], tidx[ret], tl_off))
    for cls, name, pr in methods:
        tables.extend(struct.pack("<HHI", tidx[cls], pidx[pr], sidx[name]))
    tables.extend(
        struct.pack(
            "<IIIIIIII",
            tidx["Lorg/holodor/boot/MainActivity;"],
            0x0001,
            tidx["Landroid/app/Activity;"],
            0,
            sidx["MainActivity.java"],
            0,
            class_data_off,
            0,
        )
    )

    file_size = hdr_size + len(tables) + len(data_buf)
    hdr = struct.pack(
        "<8sI20sIIIIIIIIIIIIIIIIIIII",
        b"dex\n035\x00",
        0,
        b"\x00" * 20,
        file_size,
        hdr_size,
        0x12345678,
        0,
        0,
        map_off,
        len(strings),
        string_ids_off,
        len(types),
        type_ids_off,
        len(protos),
        proto_ids_off,
        0,
        field_ids_off,
        len(methods),
        method_ids_off,
        1,
        class_defs_off,
        len(data_buf),
        data_off,
    )
    dex = bytearray(hdr) + tables + data_buf
    sha1 = hashlib.sha1(dex[32:]).digest()
    dex[12:32] = sha1
    adler = zlib.adler32(dex[12:]) & 0xFFFFFFFF
    struct.pack_into("<I", dex, 8, adler)
    return bytes(dex)


# ---------------------------------------------------------------------------
# 2. Binary AndroidManifest.xml (AXML)
# ---------------------------------------------------------------------------
def build_axml() -> bytes:
    # Resource-mapped attribute names MUST come first in the string pool
    res_attrs = [
        ("theme", 0x01010000),
        ("label", 0x01010001),
        ("icon", 0x01010002),
        ("name", 0x01010003),
        ("exported", 0x01010010),
        ("minSdkVersion", 0x0101020C),
        ("versionCode", 0x0101021B),
        ("versionName", 0x0101021C),
        ("targetSdkVersion", 0x01010270),
        ("extractNativeLibs", 0x010104EA),
        ("usesNonSdkApi", 0x0101058E),
    ]
    other_strings = [
        "android",
        "http://schemas.android.com/apk/res/android",
        "",
        "manifest",
        "package",
        "org.holodor.boot",
        "1.0",
        "uses-sdk",
        "application",
        "activity",
        "org.holodor.boot.MainActivity",
        "Boot to Holodor",
        "intent-filter",
        "action",
        "android.intent.action.MAIN",
        "category",
        "android.intent.category.LAUNCHER",
        "android.intent.category.LEANBACK_LAUNCHER",
    ]
    pool_strings = [k for k, _ in res_attrs] + other_strings
    sidx = {s: i for i, s in enumerate(pool_strings)}

    # Build UTF-16LE String Pool chunk (type 0x0001)
    str_blobs = []
    str_offs = []
    cur = 0
    for s in pool_strings:
        str_offs.append(cur)
        u16 = s.encode("utf-16le")
        blob = struct.pack("<H", len(s)) + u16 + b"\x00\x00"
        str_blobs.append(blob)
        cur += len(blob)
    raw_str_data = bytearray(b"".join(str_blobs))
    align4(raw_str_data)
    strings_start = 28 + len(pool_strings) * 4
    sp_chunk_size = strings_start + len(raw_str_data)
    sp_chunk = (
        struct.pack("<HHIIIIII", 0x0001, 28, sp_chunk_size, len(pool_strings), 0, 0, strings_start, 0)
        + b"".join(struct.pack("<I", o) for o in str_offs)
        + bytes(raw_str_data)
    )

    # Resource Map chunk (type 0x0180)
    rm_chunk_size = 8 + len(res_attrs) * 4
    rm_chunk = struct.pack("<HHI", 0x0180, 8, rm_chunk_size) + b"".join(
        struct.pack("<I", rid) for _, rid in res_attrs
    )

    ns_prefix = sidx["android"]
    ns_uri = sidx["http://schemas.android.com/apk/res/android"]
    NO_NS = 0xFFFFFFFF

    def start_ns(line: int) -> bytes:
        return struct.pack("<HHIIIII", 0x0100, 16, 24, line, 0xFFFFFFFF, ns_prefix, ns_uri)

    def end_ns(line: int) -> bytes:
        return struct.pack("<HHIIIII", 0x0101, 16, 24, line, 0xFFFFFFFF, ns_prefix, ns_uri)

    def attr_str(ns: int, name: str, val: str) -> bytes:
        return struct.pack("<IIIHBBI", ns, sidx[name], sidx[val], 8, 0, 0x03, sidx[val])

    def attr_int(ns: int, name: str, val: int) -> bytes:
        return struct.pack("<IIIHBBI", ns, sidx[name], 0xFFFFFFFF, 8, 0, 0x10, val & 0xFFFFFFFF)

    def attr_bool(ns: int, name: str, val: bool) -> bytes:
        v = 0xFFFFFFFF if val else 0
        return struct.pack("<IIIHBBI", ns, sidx[name], 0xFFFFFFFF, 8, 0, 0x12, v)

    def attr_ref(ns: int, name: str, res_id: int) -> bytes:
        return struct.pack("<IIIHBBI", ns, sidx[name], 0xFFFFFFFF, 8, 0, 0x01, res_id)

    def start_elem(line: int, name: str, attrs: list[bytes]) -> bytes:
        total = 36 + len(attrs) * 20
        return (
            struct.pack(
                "<HHIIIIIHHHHHH",
                0x0102,
                16,
                total,
                line,
                0xFFFFFFFF,
                NO_NS,
                sidx[name],
                20,
                20,
                len(attrs),
                0,
                0,
                0,
            )
            + b"".join(attrs)
        )

    def end_elem(line: int, name: str) -> bytes:
        return struct.pack("<HHIIIII", 0x0103, 16, 24, line, 0xFFFFFFFF, NO_NS, sidx[name])

    xml_chunks = [
        start_ns(2),
        start_elem(
            2,
            "manifest",
            [
                attr_int(ns_uri, "versionCode", 1),
                attr_str(ns_uri, "versionName", "1.0"),
                attr_str(NO_NS, "package", "org.holodor.boot"),
            ],
        ),
        start_elem(
            3,
            "uses-sdk",
            [
                attr_int(ns_uri, "minSdkVersion", 24),
                attr_int(ns_uri, "targetSdkVersion", 29),
            ],
        ),
        end_elem(3, "uses-sdk"),
        start_elem(
            4,
            "application",
            [
                attr_ref(ns_uri, "theme", 0x01030055),  # @android:style/Theme.NoDisplay
                attr_ref(ns_uri, "label", 0x7F020000),  # @string/app_name
                attr_ref(ns_uri, "icon", 0x7F010000),   # @mipmap/ic_launcher
                attr_bool(ns_uri, "extractNativeLibs", True),
                attr_bool(ns_uri, "usesNonSdkApi", True),
            ],
        ),
        start_elem(
            5,
            "activity",
            [
                attr_ref(ns_uri, "label", 0x7F020000),
                attr_ref(ns_uri, "icon", 0x7F010000),
                attr_str(ns_uri, "name", "org.holodor.boot.MainActivity"),
                attr_bool(ns_uri, "exported", True),
            ],
        ),
        start_elem(6, "intent-filter", []),
        start_elem(7, "action", [attr_str(ns_uri, "name", "android.intent.action.MAIN")]),
        end_elem(7, "action"),
        start_elem(8, "category", [attr_str(ns_uri, "name", "android.intent.category.LAUNCHER")]),
        end_elem(8, "category"),
        start_elem(9, "category", [attr_str(ns_uri, "name", "android.intent.category.LEANBACK_LAUNCHER")]),
        end_elem(9, "category"),
        end_elem(6, "intent-filter"),
        end_elem(5, "activity"),
        end_elem(4, "application"),
        end_elem(2, "manifest"),
        end_ns(2),
    ]

    body = sp_chunk + rm_chunk + b"".join(xml_chunks)
    return struct.pack("<HHI", 0x0003, 8, 8 + len(body)) + body


# ---------------------------------------------------------------------------
# 3. Binary Resource Table (resources.arsc)
# ---------------------------------------------------------------------------
def build_utf8_string_pool(strings: list[str]) -> bytes:
    blobs = []
    offs = []
    cur = 0
    for s in strings:
        offs.append(cur)
        b = s.encode("utf-8")
        assert len(s) < 128 and len(b) < 128
        blob = bytes([len(s), len(b)]) + b + b"\x00"
        blobs.append(blob)
        cur += len(blob)
    raw = bytearray(b"".join(blobs))
    align4(raw)
    strings_start = 28 + len(strings) * 4
    total = strings_start + len(raw)
    return (
        struct.pack("<HHIIIIII", 0x0001, 28, total, len(strings), 0, 0x100, strings_start, 0)
        + b"".join(struct.pack("<I", o) for o in offs)
        + bytes(raw)
    )


def build_resources_arsc() -> bytes:
    # Global value string pool:
    #   0: "Boot to Holodor"
    #   1: "res/mipmap-mdpi-v4/ic_launcher.png"
    #   2: "res/mipmap-hdpi-v4/ic_launcher.png"
    #   3: "res/mipmap-xhdpi-v4/ic_launcher.png"
    global_pool = build_utf8_string_pool(
        [
            "Boot to Holodor",
            "res/mipmap-mdpi-v4/ic_launcher.png",
            "res/mipmap-hdpi-v4/ic_launcher.png",
            "res/mipmap-xhdpi-v4/ic_launcher.png",
        ]
    )
    type_pool = build_utf8_string_pool(["mipmap", "string"])
    key_pool = build_utf8_string_pool(["ic_launcher", "app_name"])

    def make_type_spec(type_id: int, flags: int) -> bytes:
        return struct.pack("<HHIBBHI", 0x0202, 16, 20, type_id, 0, 0, 1) + struct.pack("<I", flags)

    def make_type_chunk(type_id: int, density: int, key_idx: int, str_val_idx: int) -> bytes:
        # Standard ResTable_type (header_size=84, total_size=104):
        #   8-byte ResChunk_header (0x0201, 84, 104)
        #   id (1B), flags=0 (1B), reserved=0 (2B), entryCount=1 (4B), entriesStart=88 (4B)
        #   ResTable_config (64 bytes, size=64, density at offset 10 within config)
        #   offset[0] = 0 (4B at offset 84..88)
        #   ResTable_entry (size=8, flags=0, key=key_idx) + Res_value (size=8, res0=0, dataType=0x03, data=str_val_idx)
        cfg = bytearray(64)
        struct.pack_into("<I", cfg, 0, 64)
        if density:
            struct.pack_into("<H", cfg, 10, density)
            cfg[36] = 4  # sdkVersion = 4 (v4)
        hdr = struct.pack("<HHIBBHII", 0x0201, 84, 104, type_id, 0, 0, 1, 88) + bytes(cfg)
        entry_off = struct.pack("<I", 0)
        entry_and_val = struct.pack("<HHIBBHI", 8, 0, key_idx, 8, 0, 0x03, str_val_idx)
        return hdr + entry_off + entry_and_val

    type_chunks = b"".join(
        [
            make_type_spec(1, 0x00000100),  # mipmap (config density)
            make_type_chunk(1, 160, 0, 1),  # mdpi
            make_type_chunk(1, 240, 0, 2),  # hdpi
            make_type_chunk(1, 320, 0, 3),  # xhdpi
            make_type_spec(2, 0x00000000),  # string (default)
            make_type_chunk(2, 0, 1, 0),    # app_name = "Boot to Holodor"
        ]
    )

    pkg_name_u16 = "org.holodor.boot".encode("utf-16le").ljust(256, b"\x00")
    pkg_hdr_size = 288
    type_strings_off = pkg_hdr_size
    key_strings_off = type_strings_off + len(type_pool)
    pkg_total_size = pkg_hdr_size + len(type_pool) + len(key_pool) + len(type_chunks)

    pkg_hdr = (
        struct.pack("<HHI", 0x0200, pkg_hdr_size, pkg_total_size)
        + struct.pack("<I", 0x7F)
        + pkg_name_u16
        + struct.pack("<IIIII", type_strings_off, 2, key_strings_off, 2, 0)
    )
    pkg_chunk = pkg_hdr + type_pool + key_pool + type_chunks
    total_size = 12 + len(global_pool) + len(pkg_chunk)
    return struct.pack("<HHII", 0x0002, 12, total_size, 1) + global_pool + pkg_chunk


# ---------------------------------------------------------------------------
# 4. Launcher Icon PNG Generator (Holodor Portal + H Emblem)
# ---------------------------------------------------------------------------
def scale_rgba_nearest(src_rgba: bytes, src_w: int, src_h: int, dst_size: int) -> bytes:
    """Nearest-neighbor scale an RGBA image (src_w x src_h) to (dst_size x dst_size) PNG."""
    raw_rows = bytearray()
    for y in range(dst_size):
        raw_rows.append(0)  # Filter 0
        sy = min(src_h - 1, (y * src_h) // dst_size)
        for x in range(dst_size):
            sx = min(src_w - 1, (x * src_w) // dst_size)
            off = (sy * src_w + sx) * 4
            raw_rows.extend(src_rgba[off : off + 4])

    def png_chunk(ctype: bytes, cdata: bytes) -> bytes:
        crc = zlib.crc32(ctype + cdata) & 0xFFFFFFFF
        return struct.pack(">I", len(cdata)) + ctype + cdata + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", dst_size, dst_size, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw_rows), 9)
    return b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", ihdr) + png_chunk(b"IDAT", idat) + png_chunk(b"IEND", b"")


def decode_simple_png_rgba(png_bytes: bytes) -> tuple[int, int, bytes]:
    """Decode an 8-bit RGB/RGBA/Indexed PNG into raw RGBA bytes using stdlib."""
    assert png_bytes[:8] == b"\x89PNG\r\n\x1a\n", "Not a PNG file"
    pos = 8
    w = h = color_type = 0
    plte = b""
    trns = b""
    idat_chunks = []
    while pos < len(png_bytes):
        length, ctype = struct.unpack(">I4s", png_bytes[pos : pos + 8])
        cdata = png_bytes[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            w, h, bit_depth, color_type, comp, filt, interlace = struct.unpack(">IIBBBBB", cdata)
            assert bit_depth == 8 and interlace == 0, f"Unsupported PNG bit_depth={bit_depth} interlace={interlace}"
        elif ctype == b"PLTE":
            plte = cdata
        elif ctype == b"tRNS":
            trns = cdata
        elif ctype == b"IDAT":
            idat_chunks.append(cdata)
        elif ctype == b"IEND":
            break

    raw = zlib.decompress(b"".join(idat_chunks))
    bpp = {2: 3, 3: 1, 6: 4}[color_type]
    stride = w * bpp
    recon = bytearray(h * stride)
    for y in range(h):
        ftype = raw[y * (stride + 1)]
        row = raw[y * (stride + 1) + 1 : (y + 1) * (stride + 1)]
        out_off = y * stride
        prev_off = (y - 1) * stride
        for i in range(stride):
            x_val = row[i]
            a = recon[out_off + i - bpp] if i >= bpp else 0
            b = recon[prev_off + i] if y > 0 else 0
            c = recon[prev_off + i - bpp] if (y > 0 and i >= bpp) else 0
            if ftype == 0:
                val = x_val
            elif ftype == 1:
                val = (x_val + a) & 0xFF
            elif ftype == 2:
                val = (x_val + b) & 0xFF
            elif ftype == 3:
                val = (x_val + ((a + b) >> 1)) & 0xFF
            elif ftype == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                val = (x_val + pr) & 0xFF
            else:
                raise ValueError(f"Unsupported PNG filter {ftype}")
            recon[out_off + i] = val

    rgba = bytearray(w * h * 4)
    for i in range(w * h):
        if color_type == 6:
            rgba[i * 4 : i * 4 + 4] = recon[i * 4 : i * 4 + 4]
        elif color_type == 2:
            rgba[i * 4 : i * 4 + 3] = recon[i * 3 : i * 3 + 3]
            rgba[i * 4 + 3] = 255
        elif color_type == 3:
            idx = recon[i]
            rgba[i * 4 : i * 4 + 3] = plte[idx * 3 : idx * 3 + 3]
            rgba[i * 4 + 3] = trns[idx] if idx < len(trns) else 255
    return w, h, bytes(rgba)


def build_holodor_icon_png(size: int) -> bytes:
    custom_icon = os.environ.get(
        "HOLODOR_ICON_PNG",
        os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "ssalmon", "icon.png"),
    )
    if os.path.isfile(custom_icon):
        src_w, src_h, src_rgba = decode_simple_png_rgba(open(custom_icon, "rb").read())
        return scale_rgba_nearest(src_rgba, src_w, src_h, size)

    raw_rows = bytearray()
    cx = (size - 1) / 2.0
    cy = (size - 1) / 2.0
    r_max = size * 0.46
    corner_r = size * 0.22

    for y in range(size):
        raw_rows.append(0)  # PNG filter type 0 (None)
        ny = (y - cy) / (size / 2.0)
        for x in range(size):
            nx = (x - cx) / (size / 2.0)
            # Rounded rectangle SDF
            qx = abs(x - cx) - (r_max - corner_r)
            qy = abs(y - cy) - (r_max - corner_r)
            sdf_box = math.hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0) - corner_r

            if sdf_box > 1.0:
                raw_rows.extend((0, 0, 0, 0))
                continue

            alpha = max(0.0, min(1.0, 0.5 - sdf_box))

            # Dark slate-indigo background gradient
            bg_r = int(16 + 10 * (1.0 - ny))
            bg_g = int(22 + 14 * (1.0 - ny))
            bg_b = int(42 + 24 * (1.0 - ny))

            # Glowing cyan/teal portal ring around the H
            dist = math.hypot(nx, ny)
            ring_sdf = abs(dist - 0.66) - 0.055
            ring_glow = math.exp(-max(0.0, ring_sdf * 8.0) ** 2)

            r = int(bg_r * (1.0 - 0.75 * ring_glow) + 56 * ring_glow)
            g = int(bg_g * (1.0 - 0.75 * ring_glow) + 189 * ring_glow)
            b = int(bg_b * (1.0 - 0.75 * ring_glow) + 248 * ring_glow)

            # Crisp white 'H' in the center
            in_left_bar = -0.34 <= nx <= -0.17 and -0.38 <= ny <= 0.38
            in_right_bar = 0.17 <= nx <= 0.34 and -0.38 <= ny <= 0.38
            in_cross_bar = -0.20 <= nx <= 0.20 and -0.085 <= ny <= 0.085
            if in_left_bar or in_right_bar or in_cross_bar:
                r, g, b = 242, 248, 255

            raw_rows.extend((max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)), int(alpha * 255)))

    def png_chunk(ctype: bytes, cdata: bytes) -> bytes:
        crc = zlib.crc32(ctype + cdata) & 0xFFFFFFFF
        return struct.pack(">I", len(cdata)) + ctype + cdata + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw_rows), 9)
    return b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", ihdr) + png_chunk(b"IDAT", idat) + png_chunk(b"IEND", b"")


# ---------------------------------------------------------------------------
# 5. ZIP Builder (4-byte aligned stored entries) + APK Signature Scheme v1 & v2
# ---------------------------------------------------------------------------
def build_aligned_zip(entries: list[tuple[str, bytes, bool]]) -> tuple[bytes, int, int]:
    """
    Build a deterministic ZIP archive with 4-byte aligned uncompressed entries.
    Returns (zip_bytes, cd_offset, eocd_offset).
    """
    local_buf = bytearray()
    cd_buf = bytearray()

    for name, raw, compress in entries:
        name_b = name.encode("utf-8")
        crc = zlib.crc32(raw) & 0xFFFFFFFF
        if compress:
            cobj = zlib.compressobj(9, zlib.DEFLATED, -15)
            comp = cobj.flush() if False else (cobj.compress(raw) + cobj.flush())
            method = 8
        else:
            comp = raw
            method = 0

        local_hdr_off = len(local_buf)
        extra = b""
        if not compress:
            # Align data start (local_hdr_off + 30 + len(name_b) + len(extra)) to 4 bytes
            data_start = local_hdr_off + 30 + len(name_b)
            pad = (4 - (data_start % 4)) % 4
            if pad:
                extra = b"\x00" * pad

        local_hdr = struct.pack(
            "<4sHHHHHIIIHH",
            b"PK\x03\x04",
            20,
            0,
            method,
            0,
            0x21,  # 1980-01-01
            crc,
            len(comp),
            len(raw),
            len(name_b),
            len(extra),
        )
        local_buf.extend(local_hdr)
        local_buf.extend(name_b)
        local_buf.extend(extra)
        local_buf.extend(comp)

        cd_hdr = struct.pack(
            "<4sHHHHHHIIIHHHHHII",
            b"PK\x01\x02",
            20,
            20,
            0,
            method,
            0,
            0x21,
            crc,
            len(comp),
            len(raw),
            len(name_b),
            0,
            0,
            0,
            0,
            0,
            local_hdr_off,
        )
        cd_buf.extend(cd_hdr)
        cd_buf.extend(name_b)

    cd_off = len(local_buf)
    eocd_off = cd_off + len(cd_buf)
    eocd = struct.pack(
        "<4sHHHHIIH",
        b"PK\x05\x06",
        0,
        0,
        len(entries),
        len(entries),
        len(cd_buf),
        cd_off,
        0,
    )
    return bytes(local_buf + cd_buf + eocd), cd_off, eocd_off


def lp_bytes(b: bytes) -> bytes:
    return struct.pack("<I", len(b)) + b


def sign_apk_v1_and_v2(base_entries: list[tuple[str, bytes, bool]]) -> bytes:
    with tempfile.TemporaryDirectory() as tmp:
        key_pem = os.path.join(tmp, "key.pem")
        cert_pem = os.path.join(tmp, "cert.pem")
        cert_der = os.path.join(tmp, "cert.der")
        pub_der = os.path.join(tmp, "pub.der")

        # Generate deterministic-style RSA-2048 signing key & self-signed cert
        subprocess.run(
            [
                "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
                "-keyout", key_pem, "-out", cert_pem,
                "-days", "10000", "-subj", "/CN=Holodor/O=Holodor/C=US",
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        subprocess.run(["openssl", "x509", "-in", cert_pem, "-outform", "DER", "-out", cert_der], check=True)
        subprocess.run(["openssl", "pkey", "-in", key_pem, "-pubout", "-outform", "DER", "-out", pub_der], check=True)

        cert_der_bytes = open(cert_der, "rb").read()
        pub_der_bytes = open(pub_der, "rb").read()

        # --- Build v1 META-INF/MANIFEST.MF, CERT.SF, CERT.RSA ---
        mf_lines = ["Manifest-Version: 1.0", "Created-By: Holodor APK Builder", ""]
        sf_entry_blocks = []
        for name, raw, _ in base_entries:
            d = base64.b64encode(hashlib.sha256(raw).digest()).decode("ascii")
            entry_text = f"Name: {name}\r\nSHA-256-Digest: {d}\r\n\r\n"
            mf_lines.append(entry_text.rstrip("\r\n"))
            mf_lines.append("")
            sd = base64.b64encode(hashlib.sha256(entry_text.encode("utf-8")).digest()).decode("ascii")
            sf_entry_blocks.append(f"Name: {name}\r\nSHA-256-Digest: {sd}\r\n\r\n")

        manifest_mf = ("\r\n".join(mf_lines)).encode("utf-8")
        mf_digest = base64.b64encode(hashlib.sha256(manifest_mf).digest()).decode("ascii")
        cert_sf = (
            f"Signature-Version: 1.0\r\nCreated-By: Holodor APK Builder\r\nSHA-256-Digest-Manifest: {mf_digest}\r\nX-Android-APK-Signed: 2\r\n\r\n"
            + "".join(sf_entry_blocks)
        ).encode("utf-8")

        sf_path = os.path.join(tmp, "CERT.SF")
        rsa_path = os.path.join(tmp, "CERT.RSA")
        open(sf_path, "wb").write(cert_sf)
        subprocess.run(
            [
                "openssl", "cms", "-sign", "-binary", "-noattr", "-nosmimecap",
                "-md", "sha256", "-in", sf_path, "-signer", cert_pem, "-inkey", key_pem,
                "-outform", "DER", "-out", rsa_path,
            ],
            check=True,
        )
        cert_rsa = open(rsa_path, "rb").read()

        all_entries = list(base_entries) + [
            ("META-INF/MANIFEST.MF", manifest_mf, True),
            ("META-INF/CERT.SF", cert_sf, True),
            ("META-INF/CERT.RSA", cert_rsa, True),
        ]

        zip_bytes, cd_off, eocd_off = build_aligned_zip(all_entries)

        # --- Build APK Signature Scheme v2 Block (ID 0x7109871a) ---
        before_cd = zip_bytes[:cd_off]
        cd_section = zip_bytes[cd_off:eocd_off]
        eocd_for_digest = bytearray(zip_bytes[eocd_off:])
        struct.pack_into("<I", eocd_for_digest, 16, cd_off)

        chunk_digests = []
        for sec in (before_cd, cd_section, bytes(eocd_for_digest)):
            for off in range(0, len(sec), 1048576):
                chunk = sec[off : off + 1048576]
                h = hashlib.sha256()
                h.update(b"\xa5" + struct.pack("<I", len(chunk)))
                h.update(chunk)
                chunk_digests.append(h.digest())

        top_h = hashlib.sha256()
        top_h.update(b"\x5a" + struct.pack("<I", len(chunk_digests)))
        for d in chunk_digests:
            top_h.update(d)
        apk_sha256 = top_h.digest()

        # signature algorithm 0x0103 = RSASSA-PKCS1-v1_5 with SHA2-256
        sig_algo = 0x0103
        digest_entry = lp_bytes(struct.pack("<I", sig_algo) + lp_bytes(apk_sha256))
        digests_seq = lp_bytes(digest_entry)
        certs_seq = lp_bytes(lp_bytes(cert_der_bytes))
        attrs_seq = lp_bytes(b"")
        signed_data = digests_seq + certs_seq + attrs_seq + struct.pack("<I", 0)

        sd_path = os.path.join(tmp, "signed_data.bin")
        sig_path = os.path.join(tmp, "sig.bin")
        open(sd_path, "wb").write(signed_data)
        subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", key_pem, "-out", sig_path, sd_path],
            check=True,
        )
        sig_bytes = open(sig_path, "rb").read()

        sig_entry = lp_bytes(struct.pack("<I", sig_algo) + lp_bytes(sig_bytes))
        signatures_seq = lp_bytes(sig_entry)
        signer = lp_bytes(lp_bytes(signed_data) + signatures_seq + lp_bytes(pub_der_bytes))
        v2_block_val = lp_bytes(signer)

        pair = struct.pack("<QI", 4 + len(v2_block_val), 0x7109871A) + v2_block_val
        # Pad APK Signing Block to multiple of 4096 bytes using Android's verity padding block (0x42726577)
        # Total block size = 8 (size_head) + len(pairs) + 8 (size_tail) + 16 (magic)
        raw_total = 8 + len(pair) + 8 + 16
        rem = raw_total % 4096
        if rem != 0:
            pad_needed = 4096 - rem
            if pad_needed < 12:
                pad_needed += 4096
            pad_val_len = pad_needed - 12
            pad_pair = struct.pack("<QI", 4 + pad_val_len, 0x42726577) + (b"\x00" * pad_val_len)
            pairs = pair + pad_pair
        else:
            pairs = pair

        size_of_block = len(pairs) + 8 + 16
        apk_sig_block = (
            struct.pack("<Q", size_of_block)
            + pairs
            + struct.pack("<Q", size_of_block)
            + b"APK Sig Block 42"
        )

        new_cd_off = cd_off + len(apk_sig_block)
        final_eocd = bytearray(zip_bytes[eocd_off:])
        struct.pack_into("<I", final_eocd, 16, new_cd_off)

        return before_cd + apk_sig_block + cd_section + bytes(final_eocd)


def build_apk(out_path: str) -> None:
    dex = build_classes_dex()
    axml = build_axml()
    arsc = build_resources_arsc()
    icon_mdpi = build_holodor_icon_png(48)
    icon_hdpi = build_holodor_icon_png(72)
    icon_xhdpi = build_holodor_icon_png(96)

    entries = [
        ("AndroidManifest.xml", axml, True),
        ("classes.dex", dex, False),
        ("res/mipmap-mdpi-v4/ic_launcher.png", icon_mdpi, False),
        ("res/mipmap-hdpi-v4/ic_launcher.png", icon_hdpi, False),
        ("res/mipmap-xhdpi-v4/ic_launcher.png", icon_xhdpi, False),
        ("resources.arsc", arsc, False),
    ]
    apk_bytes = sign_apk_v1_and_v2(entries)
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(apk_bytes)
    print(f"Built {out_path} ({len(apk_bytes)} bytes)")


if __name__ == "__main__":
    targets = sys.argv[1:] or [
        "packages/pocknix-bootloader-sm8750/BootHolodor.apk",
        "packages/pocknix-bootloader-sm8250/BootHolodor.apk",
    ]
    for tgt in targets:
        build_apk(tgt)
    if len(targets) > 1:
        # Copy the first APK to all remaining targets so they share the exact same signing cert
        first_bytes = open(targets[0], "rb").read()
        for tgt in targets[1:]:
            open(tgt, "wb").write(first_bytes)
            print(f"Synced identical signed APK to {tgt}")

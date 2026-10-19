#!/usr/bin/env python3
"""
tools/apply_patches.py — BoltSDR source patches for pe5jw/rigflow
===================================================================

Strips RTL-SDR, HardRock-50 amplifier, and Linux serial-port code from
the rigflow-server source so it compiles cleanly on Windows (MSVC) without
libusb or libc serial dependencies.

What is REMOVED
---------------
- rtl-sdr-rs crate dependency
- libc crate dependency (used only by the termios serial code)
- rigflow-server/src/source/rtlsdr.rs            (deleted)
- RtlSdr variant in SourceConfig + factory arm    (source/factory.rs)
- SourceKind::RtlSdr + rtlsdr_* config fields    (config.rs)
- discover_rtl_radios() + RTL test               (radio/discovery.rs)
- amplifier/hr50.rs, serial.rs, transport.rs     (deleted)
- amplifier/mod.rs                               (replaced by empty stub)
- hr50_serial config field                       (config.rs)

What REMAINS
------------
HermesLite2 (HL2 / OpenHPSDR), WAV-file source, fake-tone source.

Usage
-----
    python3 tools/apply_patches.py .           # from the repo root
    python3 tools/apply_patches.py /path/to/rigflow
"""

import re
import os
import sys


def patch_file(path, description, fn):
    if not os.path.exists(path):
        print(f"  SKIP (not found): {path}")
        return
    with open(path, "r", encoding="utf-8") as f:
        original = f.read()
    patched = fn(original)
    if patched == original:
        print(f"  ALREADY OK:  {path}")
    else:
        with open(path, "w", encoding="utf-8") as f:
            f.write(patched)
        print(f"  PATCHED:     {path}  ({description})")


def remove_file(path, description):
    if os.path.exists(path):
        os.remove(path)
        print(f"  DELETED:     {path}  ({description})")
    else:
        print(f"  SKIP (gone): {path}")


def write_stub(path, content, description):
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"  STUBBED:     {path}  ({description})")


# ---------------------------------------------------------------------------
# Patch functions
# ---------------------------------------------------------------------------

def patch_server_cargo(src):
    src = re.sub(r'^rtl-sdr-rs\s*=.*\n', '', src, flags=re.MULTILINE)
    src = re.sub(r'^libc\s*=.*\n', '', src, flags=re.MULTILINE)
    return src


def patch_source_mod(src):
    return re.sub(r'^pub mod rtlsdr;\n', '', src, flags=re.MULTILINE)


def patch_factory(src):
    # Remove import
    src = re.sub(
        r'^use crate::source::rtlsdr::RtlSdrSource;\n',
        '', src, flags=re.MULTILINE,
    )
    # Remove RtlSdr { … } variant from enum (tolerant: handles trailing comma)
    src = re.sub(
        r'    RtlSdr \{[^}]*?\},?\n',
        '', src, flags=re.DOTALL,
    )
    # Remove match arm for RtlSdr
    src = re.sub(
        r'        SourceConfig::RtlSdr \{.*?\n        \}\n\n',
        '', src, flags=re.DOTALL,
    )
    return src


def patch_config(src):
    # SourceKind enum
    src = re.sub(r'\s*RtlSdr,', '', src)
    # Struct fields
    src = re.sub(r'\n    pub rtlsdr_\w+:[^\n]+', '', src)
    # hr50_serial field (with preceding doc-comments)
    src = re.sub(
        r'\n    /// Hardrock.*?pub hr50_serial:.*?\n',
        '\n',
        src, flags=re.DOTALL,
    )
    # Default values
    src = re.sub(r'\n            rtlsdr_\w+:[^\n]+,', '', src)
    src = re.sub(r'\n            hr50_serial:[^\n]+,', '', src)
    return src


def patch_discovery(src):
    # Remove import of rtlsdr functions
    src = re.sub(
        r'^use crate::source::rtlsdr[^\n]*;\n',
        '', src, flags=re.MULTILINE,
    )
    # Remove RTL-SDR bullet from the module doc-comment
    src = re.sub(r'^///.*RTL-SDR[^\n]*\n', '', src, flags=re.MULTILINE)
    # Remove discover_rtl_radios() call inside discover_radios()
    src = re.sub(r'[^\n]*discover_rtl_radios\(\)[^\n]*\n', '', src)
    # Remove the RTL Discovery section header + discover_rtl_radios fn
    src = re.sub(
        r'\n//\n// =+\n// RTL Discovery.*?(?=\n//\n// =|\Z)',
        '', src, flags=re.DOTALL,
    )
    src = re.sub(
        r'\nfn discover_rtl_radios\(\).*?^}\n',
        '\n', src, flags=re.DOTALL | re.MULTILINE,
    )
    # Remove helper fns only used by RTL discovery
    for fn_name in ('default_radio_capabilities', 'rtl_source_capabilities'):
        src = re.sub(
            rf'\nfn {fn_name}\(\).*?^}}\n',
            '\n', src, flags=re.DOTALL | re.MULTILINE,
        )
    # Remove #[cfg(test)] mod tests block (contains RTL-only test)
    src = re.sub(
        r'\n#\[cfg\(test\)\]\nmod tests \{.*?\n\}\n',
        '\n', src, flags=re.DOTALL,
    )
    return src


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def apply(root):
    server = os.path.join(root, "rigflow-server")

    patch_file(
        os.path.join(server, "Cargo.toml"),
        "remove rtl-sdr-rs + libc",
        patch_server_cargo,
    )
    patch_file(
        os.path.join(server, "src", "source", "mod.rs"),
        "remove pub mod rtlsdr",
        patch_source_mod,
    )
    remove_file(
        os.path.join(server, "src", "source", "rtlsdr.rs"),
        "RTL-SDR source",
    )
    patch_file(
        os.path.join(server, "src", "source", "factory.rs"),
        "remove RtlSdr variant + arm",
        patch_factory,
    )
    patch_file(
        os.path.join(server, "src", "config.rs"),
        "remove RTL-SDR fields + hr50_serial",
        patch_config,
    )
    patch_file(
        os.path.join(server, "src", "radio", "discovery.rs"),
        "remove RTL discovery + test",
        patch_discovery,
    )
    for fname in ("hr50.rs", "serial.rs", "transport.rs"):
        remove_file(
            os.path.join(server, "src", "amplifier", fname),
            "HardRock amplifier",
        )
    write_stub(
        os.path.join(server, "src", "amplifier", "mod.rs"),
        "// HardRock-50 amplifier support removed in BoltSDR build.\n"
        "// Kept as empty stub so existing mod-path references compile.\n",
        "amplifier mod emptied",
    )

    print("\nAll patches applied. Run `cargo check -p rigflow-server` to verify.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <path-to-rigflow-root>")
        sys.exit(1)
    root = sys.argv[1]
    if not os.path.isdir(root):
        print(f"Error: {root!r} is not a directory")
        sys.exit(1)
    print(f"Applying BoltSDR patches to: {os.path.abspath(root)}\n")
    apply(root)

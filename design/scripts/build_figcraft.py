#!/usr/bin/env python3
"""Generate Taproom's 5 core screens (Dark + Light, 1440x900) in FigCraft."""

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DESIGN_DIR = ROOT / "design"
SCRIPTS_DIR = DESIGN_DIR / "scripts"
RENDERS_DIR = DESIGN_DIR / "renders"

SCREENS = [
    ("01-installed-dark", "dark", "installed"),
    ("02-discover-dark", "dark", "discover"),
    ("03-outdated-log-dark", "dark", "outdated"),
    ("04-services-maintenance-dark", "dark", "services"),
    ("05-palette-menubar-dark", "dark", "palette"),
    ("01-installed-light", "light", "installed"),
    ("02-discover-light", "light", "discover"),
    ("03-outdated-log-light", "light", "outdated"),
    ("04-services-maintenance-light", "light", "services"),
    ("05-palette-menubar-light", "light", "palette"),
]

THEMES = {
    "dark": {
        "bg": "#141619",
        "elevated": "#1C1F24",
        "elevated2": "#23272E",
        "sidebar": "#181B20",
        "toolbar": "#181B20",
        "glass": "#22262E",
        "glassBorder": "#3B414D",
        "border": "#2A2E35",
        "text": "#F3F4F6",
        "muted": "#9CA3AF",
        "dim": "#6B7280",
        "accent": "#F59E0B",
        "onAccent": "#111214",
        "accentTint": "#2E2412",
        "current": "#10B981",
        "outdated": "#F59E0B",
        "error": "#F87171",
        "formulaBg": "#1E293B",
        "formulaFg": "#93C5FD",
        "caskBg": "#2A1F33",
        "caskFg": "#D8B4FE",
        "rowAlt": "#171A1E",
        "rowSel": "#26221A",
        "backdrop": "#0A0B0D",
    },
    "light": {
        "bg": "#F7F8FA",
        "elevated": "#FFFFFF",
        "elevated2": "#F0F2F5",
        "sidebar": "#ECEEF2",
        "toolbar": "#F2F4F7",
        "glass": "#FFFFFF",
        "glassBorder": "#D1D5DB",
        "border": "#E2E5EA",
        "text": "#111827",
        "muted": "#4B5563",
        "dim": "#6B7280",
        "accent": "#B45309",
        "onAccent": "#FFFFFF",
        "accentTint": "#FEF3C7",
        "current": "#059669",
        "outdated": "#D97706",
        "error": "#DC2626",
        "formulaBg": "#DBEAFE",
        "formulaFg": "#1D4ED8",
        "caskBg": "#F3E8FF",
        "caskFg": "#6D28D9",
        "rowAlt": "#F2F4F7",
        "rowSel": "#FEF7E6",
        "backdrop": "#111827",
    },
}


class Builder:
    def __init__(self, parent_id: str, theme_name: str):
        self.parent = parent_id
        self.t = THEMES[theme_name]
        self.theme_name = theme_name
        self.cmds = []

    def rect(self, name, x, y, w, h, fill=None, stroke=None, sw=1, r=0, opacity=1.0, clip=False):
        props = {}
        if fill:
            props["fill"] = fill
        if stroke:
            props["stroke"] = stroke
            props["strokeWeight"] = sw
            props["strokeAlign"] = "inside"
        if r:
            props["cornerRadius"] = r
        if opacity < 1.0:
            props["opacity"] = opacity
        if clip:
            props["clip"] = True
        self.cmds.append({
            "command": "node.create",
            "params": {
                "type": "rectangle",
                "parent": self.parent,
                "name": name,
                "x": x, "y": y, "width": w, "height": h,
                "props": props,
                "select": False,
            },
        })

    def circle(self, name, x, y, d, fill, stroke=None, sw=1, opacity=1.0):
        props = {"fill": fill}
        if stroke:
            props["stroke"] = stroke
            props["strokeWeight"] = sw
        if opacity < 1.0:
            props["opacity"] = opacity
        self.cmds.append({
            "command": "node.create",
            "params": {
                "type": "ellipse",
                "parent": self.parent,
                "name": name,
                "x": x, "y": y, "width": d, "height": d,
                "props": props,
                "select": False,
            },
        })

    def text(self, name, txt, x, y, w, h, size=13, color=None, font="SF Pro Text", weight="Regular", align="left", opacity=1.0):
        props = {
            "fill": color or self.t["text"],
            "fontFamily": font,
            "fontSize": size,
            "fontStyle": weight,
            "textAlign": align,
            "textAutoResize": "none",
        }
        if opacity < 1.0:
            props["opacity"] = opacity
        self.cmds.append({
            "command": "node.create",
            "params": {
                "type": "text",
                "parent": self.parent,
                "name": name,
                "x": x, "y": y, "width": w, "height": h,
                "text": txt,
                "props": props,
                "select": False,
            },
        })

    def image(self, name, path, x, y, w, h):
        self.cmds.append({
            "command": "image.place",
            "params": {
                "path": str(path),
                "x": x,
                "y": y,
                "width": w,
                "height": h,
                "parent": self.parent,
                "name": name,
                "mode": "fit",
            },
        })

    def badge(self, name, txt, x, y, w, bg, fg, r=4, size=10, mono=False):
        self.rect(f"{name}-bg", x, y, w, 20, fill=bg, r=r)
        self.text(
            f"{name}-txt", txt, x, y + 3, w, 14,
            size=size, color=fg,
            font="SF Mono" if mono else "SF Pro Text",
            weight="SemiBold", align="center",
        )

    def button(self, name, txt, x, y, w, h, primary=False, destructive=False):
        t = self.t
        if primary:
            bg, fg, st = t["accent"], t["onAccent"], None
        elif destructive:
            bg, fg, st = t["elevated2"], t["error"], t["border"]
        else:
            bg, fg, st = t["elevated2"], t["text"], t["border"]
        self.rect(f"{name}-bg", x, y, w, h, fill=bg, stroke=st, sw=1, r=6)
        self.text(f"{name}-txt", txt, x, y + (h - 16) // 2, w, 16, size=12, color=fg, weight="SemiBold", align="center")

    def chrome_shell(self, active_nav: str, title: str, subtitle: str):
        t = self.t
        # Window background
        self.rect("window-bg", 0, 0, 1440, 900, fill=t["bg"], stroke=t["border"], sw=1, r=16)

        # Liquid Glass Sidebar (220px)
        self.rect("sidebar-glass", 0, 0, 220, 900, fill=t["sidebar"], opacity=0.94, r=0)
        self.rect("sidebar-divider", 220, 0, 1, 900, fill=t["border"])

        # macOS traffic lights
        self.circle("tl-close", 20, 18, 12, "#FF5F57")
        self.circle("tl-min", 40, 18, 12, "#FEBC2E")
        self.circle("tl-max", 60, 18, 12, "#28C840")

        # App brand logo + label in sidebar
        self.image("brand-logo", RENDERS_DIR / "app-icon-1024.png", 18, 46, 26, 26)
        self.text("brand-title", "Taproom", 50, 50, 140, 22, size=15, font="SF Pro Display", weight="Bold")

        # Sidebar groups
        self.text("grp-pkg", "PACKAGES", 20, 92, 160, 16, size=10, color=t["dim"], weight="SemiBold")
        nav_pkg = [
            ("Installed", "142", 114),
            ("Outdated", "4", 150),
            ("Discover", "", 186),
        ]
        for label, count, y in nav_pkg:
            is_active = label == active_nav
            if is_active:
                self.rect(f"nav-{label}-sel", 12, y, 196, 30, fill=t["accentTint"], stroke=t["accent"], sw=1, r=7)
            self.text(
                f"nav-{label}-lbl", label, 24, y + 6, 120, 18,
                size=13, color=t["accent"] if is_active else t["text"],
                weight="SemiBold" if is_active else "Regular",
            )
            if count:
                pill_bg = t["accent"] if label == "Outdated" else t["elevated2"]
                pill_fg = t["onAccent"] if label == "Outdated" else t["muted"]
                self.rect(f"nav-{label}-cnt-bg", 168, y + 6, 30, 18, fill=pill_bg, r=9)
                self.text(f"nav-{label}-cnt", count, 168, y + 8, 30, 14, size=10, color=pill_fg, font="SF Mono", weight="SemiBold", align="center")

        self.text("grp-sys", "SYSTEM", 20, 238, 160, 16, size=10, color=t["dim"], weight="SemiBold")
        nav_sys = [
            ("Services", "4", 260),
            ("Taps", "5", 296),
            ("Maintenance", "", 332),
            ("Brewfile", "", 368),
        ]
        for label, count, y in nav_sys:
            is_active = label == active_nav
            if is_active:
                self.rect(f"nav-{label}-sel", 12, y, 196, 30, fill=t["accentTint"], stroke=t["accent"], sw=1, r=7)
            self.text(
                f"nav-{label}-lbl", label, 24, y + 6, 120, 18,
                size=13, color=t["accent"] if is_active else t["text"],
                weight="SemiBold" if is_active else "Regular",
            )
            if count:
                self.rect(f"nav-{label}-cnt-bg", 174, y + 6, 24, 18, fill=t["elevated2"], r=9)
                self.text(f"nav-{label}-cnt", count, 174, y + 8, 24, 14, size=10, color=t["muted"], font="SF Mono", weight="SemiBold", align="center")

        # Bottom Homebrew prefix glass pill
        self.rect("prefix-pill", 14, 838, 192, 44, fill=t["glass"], stroke=t["glassBorder"], sw=1, r=10, opacity=0.92)
        self.circle("prefix-dot", 26, 855, 8, t["current"])
        self.text("prefix-path", "/opt/homebrew", 42, 845, 150, 15, size=11, color=t["text"], font="SF Mono", weight="Medium")
        self.text("prefix-ver", "Homebrew 7.0.16 · arm64", 42, 862, 155, 14, size=10, color=t["muted"], font="SF Mono")

        # Liquid Glass Unified Toolbar (x=221..1440, h=52)
        self.rect("toolbar-bg", 221, 0, 1219, 52, fill=t["toolbar"], opacity=0.92)
        self.rect("toolbar-div", 221, 52, 1219, 1, fill=t["border"])
        self.text("tb-title", title, 244, 10, 320, 20, size=14, font="SF Pro Display", weight="SemiBold")
        self.text("tb-sub", subtitle, 244, 30, 360, 15, size=11, color=t["muted"], font="SF Mono")

        # Toolbar search pill + Cmd+K + Inspector toggle
        self.rect("tb-search", 940, 11, 260, 30, fill=t["elevated"], stroke=t["border"], sw=1, r=8)
        self.text("tb-search-ph", "Filter packages…", 954, 18, 170, 16, size=12, color=t["dim"])
        self.rect("tb-search-key", 1166, 16, 24, 20, fill=t["elevated2"], stroke=t["border"], sw=1, r=4)
        self.text("tb-search-key-t", "/", 1166, 18, 24, 16, size=11, color=t["muted"], font="SF Mono", align="center")

        self.rect("tb-cmdk", 1212, 11, 96, 30, fill=t["glass"], stroke=t["glassBorder"], sw=1, r=8)
        self.text("tb-cmdk-t", "⌘K Palette", 1212, 18, 96, 16, size=11, color=t["text"], font="SF Mono", weight="Medium", align="center")

        self.rect("tb-insp", 1318, 11, 102, 30, fill=t["glass"], stroke=t["glassBorder"], sw=1, r=8)
        self.text("tb-insp-t", "⌘I Inspect", 1318, 18, 102, 16, size=11, color=t["text"], font="SF Mono", weight="Medium", align="center")

    def floating_job_pill(self, x=560, y=830):
        t = self.t
        self.rect("job-pill", x, y, 360, 44, fill=t["glass"], stroke=t["glassBorder"], sw=1, r=22, opacity=0.96)
        self.circle("job-dot", x + 16, y + 17, 10, t["accent"])
        self.text("job-lbl", "Upgrading 1 of 3 · ffmpeg", x + 34, y + 8, 210, 16, size=12, weight="SemiBold")
        self.text("job-sub", "64% · 18.4 MB/s · Click for logs", x + 34, y + 24, 220, 14, size=10, color=t["muted"], font="SF Mono")
        self.rect("job-bar-bg", x + 266, y + 19, 76, 6, fill=t["elevated2"], r=3)
        self.rect("job-bar-fg", x + 266, y + 19, 48, 6, fill=t["accent"], r=3)

    # ------------------------------------------------------------------
    # SCREEN 1: INSTALLED + INSPECTOR
    # ------------------------------------------------------------------
    def build_installed(self):
        t = self.t
        self.chrome_shell("Installed", "Installed Packages", "142 total · 38 leaves · 104 dependencies")

        # Filter bar
        pills = [("All (142)", True, 244, 76), ("Leaves (38)", False, 328, 92), ("Formulae (118)", False, 428, 106), ("Casks (24)", False, 542, 86)]
        for lbl, active, px, pw in pills:
            self.rect(f"fp-{lbl}", px, 68, pw, 26, fill=t["accentTint"] if active else t["elevated"], stroke=t["accent"] if active else t["border"], sw=1, r=13)
            self.text(f"fp-{lbl}-t", lbl, px, 73, pw, 16, size=11, color=t["accent"] if active else t["muted"], weight="SemiBold" if active else "Medium", align="center")

        # Table container (x=221..1100, y=106..899) -> 879px wide
        self.rect("tbl-hdr", 221, 106, 879, 30, fill=t["elevated2"])
        self.rect("tbl-hdr-div", 221, 136, 879, 1, fill=t["border"])
        cols = [("PACKAGE", 244, 220), ("KIND", 510, 80), ("VERSION", 610, 140), ("SIZE", 770, 90), ("STATUS", 880, 120)]
        for cname, cx, cw in cols:
            self.text(f"col-{cname}", cname, cx, 114, cw, 14, size=10, color=t["dim"], weight="SemiBold")

        rows = [
            ("ripgrep", "FORMULA", "14.1.1", "11.4 MB", "Current", True),
            ("ffmpeg", "FORMULA", "7.1 -> 7.1.1", "148.2 MB", "Outdated", False),
            ("ghostty", "CASK", "1.1.3", "92.0 MB", "Current", False),
            ("neovim", "FORMULA", "0.10.4", "44.8 MB", "Current", False),
            ("git", "FORMULA", "2.48.1 -> 2.49.0", "51.2 MB", "Outdated", False),
            ("raycast", "CASK", "1.94.2", "184.5 MB", "Current", False),
            ("postgresql@17", "FORMULA", "17.4", "76.1 MB", "Service", False),
            ("bun", "FORMULA", "1.2.4 -> 1.2.5", "62.3 MB", "Outdated", False),
            ("orbstack", "CASK", "1.10.2", "312.0 MB", "Current", False),
            ("jq", "FORMULA", "1.7.1", "2.8 MB", "Current", False),
            ("fzf", "FORMULA", "0.60.3", "4.2 MB", "Current", False),
            ("uv", "FORMULA", "0.6.4 -> 0.6.6", "28.9 MB", "Outdated", False),
            ("zed", "CASK", "0.178.5", "241.0 MB", "Current", False),
            ("tmux", "FORMULA", "3.5a", "3.1 MB", "Current", False),
            ("eza", "FORMULA", "0.20.24", "3.6 MB", "Current", False),
            ("gh", "FORMULA", "2.68.1", "41.7 MB", "Current", False),
        ]

        for i, (name, kind, ver, sz, status, selected) in enumerate(rows):
            ry = 137 + i * 40
            row_bg = t["rowSel"] if selected else (t["rowAlt"] if i % 2 == 1 else t["bg"])
            self.rect(f"row-{i}", 221, ry, 879, 40, fill=row_bg)
            self.rect(f"row-{i}-div", 221, ry + 39, 879, 1, fill=t["border"])
            self.text(f"row-{i}-name", name, 244, ry + 11, 240, 18, size=13, weight="SemiBold" if selected else "Medium")
            if kind == "FORMULA":
                self.badge(f"row-{i}-kind", "FORMULA", 510, ry + 10, 68, t["formulaBg"], t["formulaFg"], r=4, size=9)
            else:
                self.badge(f"row-{i}-kind", "CASK", 510, ry + 10, 52, t["caskBg"], t["caskFg"], r=4, size=9)
            ver_col = t["outdated"] if status == "Outdated" else t["muted"]
            self.text(f"row-{i}-ver", ver, 610, ry + 11, 150, 18, size=12, color=ver_col, font="SF Mono", weight="Medium")
            self.text(f"row-{i}-sz", sz, 770, ry + 11, 80, 18, size=12, color=t["muted"], font="SF Mono")
            dot_col = t["outdated"] if status == "Outdated" else t["current"]
            self.circle(f"row-{i}-dot", 880, ry + 16, 8, dot_col)
            self.text(f"row-{i}-st", status, 896, ry + 11, 90, 18, size=12, color=dot_col if status == "Outdated" else t["muted"], weight="Medium")

        # Right Inspector (x=1100..1440, w=340)
        self.rect("insp-bg", 1100, 53, 340, 847, fill=t["elevated"])
        self.rect("insp-div", 1100, 53, 1, 847, fill=t["border"])
        self.text("insp-name", "ripgrep", 1124, 76, 220, 26, size=20, font="SF Pro Display", weight="Bold")
        self.badge("insp-kind", "FORMULA", 1336, 79, 76, t["formulaBg"], t["formulaFg"], r=4, size=10)
        self.text("insp-ver", "14.1.1 · homebrew/core · bottle", 1124, 108, 290, 16, size=11, color=t["muted"], font="SF Mono")
        self.text(
            "insp-desc",
            "Search tool like grep and The Silver Searcher. Respects gitignore and skips binary files by default.",
            1124, 138, 292, 54, size=12, color=t["text"],
        )

        # Action bar
        self.button("insp-pin", "Pin 14.1.1", 1124, 206, 140, 32, primary=False)
        self.button("insp-uninst", "Uninstall", 1276, 206, 140, 32, destructive=True)

        # Metadata card
        self.rect("insp-meta", 1124, 258, 292, 136, fill=t["bg"], stroke=t["border"], sw=1, r=10)
        meta_rows = [
            ("Installed", "Nov 18, 2026 (leaf)"),
            ("Disk Size", "11.4 MB (21 files)"),
            ("License", "MIT OR Unlicense"),
            ("Homepage", "github.com/BurntSushi/ripgrep"),
        ]
        for idx, (mk, mv) in enumerate(meta_rows):
            my = 272 + idx * 30
            self.text(f"mk-{idx}", mk, 1140, my, 85, 16, size=11, color=t["dim"])
            self.text(f"mv-{idx}", mv, 1228, my, 176, 16, size=11, color=t["text"], font="SF Mono")

        # Dependencies
        self.text("insp-deps-lbl", "DEPENDENCIES (2)", 1124, 418, 200, 16, size=10, color=t["dim"], weight="SemiBold")
        self.badge("dep-1", "pcre2 10.45", 1124, 442, 106, t["elevated2"], t["text"], r=6, size=11, mono=True)
        self.badge("dep-2", "xz 5.6.4", 1238, 442, 86, t["elevated2"], t["text"], r=6, size=11, mono=True)

        # Caveats box
        self.text("insp-cav-lbl", "CAVEATS & PATH", 1124, 492, 200, 16, size=10, color=t["dim"], weight="SemiBold")
        self.rect("insp-cav-box", 1124, 514, 292, 92, fill=t["bg"], stroke=t["border"], sw=1, r=10)
        self.text(
            "insp-cav-txt",
            "Binary linked at:\n/opt/homebrew/bin/rg\nShell completions installed in zsh/site-functions.",
            1138, 526, 264, 68, size=11, color=t["muted"], font="SF Mono",
        )

        # Floating Liquid Glass Job Pill
        self.floating_job_pill(x=480, y=832)

    # ------------------------------------------------------------------
    # SCREEN 2: DISCOVER / SEARCH
    # ------------------------------------------------------------------
    def build_discover(self):
        t = self.t
        self.chrome_shell("Discover", "Discover Catalog", "11,480 formulae & casks indexed in SQLite FTS5 (0.8 ms)")

        # Big FTS5 Search Input
        self.rect("disc-search", 244, 72, 1172, 46, fill=t["elevated"], stroke=t["accent"], sw=2, r=10)
        self.text("disc-q", "http", 264, 85, 400, 20, size=15, font="SF Mono", weight="Medium")
        self.text("disc-lat", "7 matches · 0.6 ms", 1230, 88, 170, 16, size=11, color=t["muted"], font="SF Mono", align="right")

        # Filter pills
        for lbl, active, px, pw in [("All (7)", True, 244, 76), ("Formulae (5)", False, 328, 96), ("Casks (2)", False, 432, 82), ("Installed (2)", False, 522, 98)]:
            self.rect(f"dfp-{lbl}", px, 132, pw, 26, fill=t["accentTint"] if active else t["elevated"], stroke=t["accent"] if active else t["border"], sw=1, r=13)
            self.text(f"dfp-{lbl}-t", lbl, px, 137, pw, 16, size=11, color=t["accent"] if active else t["muted"], weight="SemiBold" if active else "Medium", align="center")

        results = [
            ("httpie", "FORMULA", "3.2.4", "homebrew/core", "User-friendly cURL replacement (command-line HTTP client)", "1.4M installs/yr", False),
            ("xh", "FORMULA", "0.24.0", "homebrew/core", "Friendly and fast tool for sending HTTP requests (Rust)", "182K installs/yr", True),
            ("proxyman", "CASK", "5.15.0", "homebrew/cask", "Modern, native HTTP debugging proxy for macOS", "94K installs/yr", False),
            ("caddy", "FORMULA", "2.9.1", "homebrew/core", "Powerful, enterprise-ready, open source web server with automatic HTTPS", "310K installs/yr", False),
            ("http-server", "FORMULA", "14.1.1", "homebrew/core", "Simple zero-configuration command-line HTTP server", "88K installs/yr", False),
            ("bruno", "CASK", "1.39.1", "homebrew/cask", "Fast, Git-friendly open-source IDE for exploring and testing APIs", "126K installs/yr", True),
            ("mitmproxy", "FORMULA", "11.1.2", "homebrew/core", "Intercept, modify, replay, and save HTTP/HTTPS traffic", "205K installs/yr", False),
        ]

        for i, (name, kind, ver, tap, desc, pop, installed) in enumerate(results):
            cy = 174 + i * 94
            self.rect(f"res-{i}", 244, cy, 1172, 82, fill=t["elevated"], stroke=t["border"], sw=1, r=10)
            self.text(f"res-{i}-name", name, 264, cy + 14, 180, 22, size=15, font="SF Pro Display", weight="Bold")
            if kind == "FORMULA":
                self.badge(f"res-{i}-k", "FORMULA", 410, cy + 15, 70, t["formulaBg"], t["formulaFg"], r=4, size=9)
            else:
                self.badge(f"res-{i}-k", "CASK", 410, cy + 15, 52, t["caskBg"], t["caskFg"], r=4, size=9)
            self.text(f"res-{i}-ver", f"{ver} · {tap}", 496, cy + 16, 280, 16, size=12, color=t["muted"], font="SF Mono")
            self.text(f"res-{i}-pop", pop, 980, cy + 16, 180, 16, size=11, color=t["dim"], font="SF Mono", align="right")
            self.text(f"res-{i}-desc", desc, 264, cy + 44, 880, 20, size=12, color=t["muted"])

            if installed:
                self.rect(f"res-{i}-inst", 1290, cy + 24, 104, 32, fill=t["elevated2"], stroke=t["current"], sw=1, r=6)
                self.text(f"res-{i}-inst-t", "✓ Installed", 1290, cy + 32, 104, 16, size=12, color=t["current"], weight="SemiBold", align="center")
            else:
                self.button(f"res-{i}-btn", "Install", 1290, cy + 24, 104, 32, primary=True)

    # ------------------------------------------------------------------
    # SCREEN 3: OUTDATED & LIVE STREAMING LOG SHEET
    # ------------------------------------------------------------------
    def build_outdated(self):
        t = self.t
        self.chrome_shell("Outdated", "Outdated Packages", "4 updates available · last checked 12m ago")

        # Action header bar
        self.text("out-summary", "4 packages have newer bottles or cask releases.", 244, 76, 480, 20, size=13, color=t["muted"])
        self.button("out-check", "Check Now", 1110, 70, 110, 32, primary=False)
        self.button("out-upgall", "Upgrade All (4)", 1232, 70, 184, 32, primary=True)

        # Outdated table
        self.rect("out-hdr", 244, 118, 1172, 30, fill=t["elevated2"], r=6)
        for cname, cx, cw in [("PACKAGE", 264, 220), ("INSTALLED", 520, 160), ("AVAILABLE", 700, 160), ("KIND", 900, 90), ("ACTION", 1280, 110)]:
            self.text(f"oc-{cname}", cname, cx, 126, cw, 14, size=10, color=t["dim"], weight="SemiBold")

        out_rows = [
            ("ffmpeg", "7.1", "7.1.1", "FORMULA", "Upgrading…"),
            ("git", "2.48.1", "2.49.0", "FORMULA", "Queued"),
            ("bun", "1.2.4", "1.2.5", "FORMULA", "Queued"),
            ("uv", "0.6.4", "0.6.6", "FORMULA", "Upgrade"),
        ]
        for i, (name, old_v, new_v, kind, act) in enumerate(out_rows):
            ry = 152 + i * 44
            self.rect(f"or-{i}", 244, ry, 1172, 44, fill=t["elevated"] if i % 2 == 0 else t["bg"])
            self.rect(f"or-{i}-div", 244, ry + 43, 1172, 1, fill=t["border"])
            self.text(f"or-{i}-n", name, 264, ry + 13, 200, 18, size=13, weight="SemiBold")
            self.text(f"or-{i}-old", old_v, 520, ry + 13, 140, 18, size=12, color=t["muted"], font="SF Mono")
            self.text(f"or-{i}-new", f"→ {new_v}", 700, ry + 13, 150, 18, size=12, color=t["outdated"], font="SF Mono", weight="SemiBold")
            self.badge(f"or-{i}-k", kind, 900, ry + 12, 70, t["formulaBg"], t["formulaFg"], r=4, size=9)
            if act == "Upgrading…":
                self.badge(f"or-{i}-act", "Upgrading…", 1280, ry + 12, 108, t["accentTint"], t["accent"], r=6, size=11)
            elif act == "Queued":
                self.badge(f"or-{i}-act", "Queued", 1280, ry + 12, 108, t["elevated2"], t["muted"], r=6, size=11)
            else:
                self.button(f"or-{i}-btn", "Upgrade", 1280, ry + 6, 108, 30, primary=False)

        # Live Streaming Log Sheet (bottom half, elevated glass frame)
        self.rect("log-sheet", 244, 356, 1172, 520, fill=t["elevated"], stroke=t["glassBorder"], sw=1, r=14)
        self.rect("log-hdr", 244, 356, 1172, 48, fill=t["glass"], r=14)
        self.rect("log-hdr-div", 244, 404, 1172, 1, fill=t["border"])
        self.circle("log-live-dot", 264, 375, 10, t["accent"])
        self.text("log-title", "Live Output · brew upgrade ffmpeg", 282, 370, 360, 20, size=13, font="SF Mono", weight="SemiBold")
        self.text("log-timer", "Elapsed 00:14 · Queue: 2 remaining", 920, 372, 270, 16, size=11, color=t["muted"], font="SF Mono", align="right")
        self.button("log-cancel", "Cancel Job", 1296, 366, 102, 28, destructive=True)

        # Monospace terminal body
        self.rect("log-body", 260, 418, 1140, 442, fill=t["bg"], stroke=t["border"], sw=1, r=10)
        log_lines = [
            ("==> Downloading https://ghcr.io/v2/homebrew/core/ffmpeg/manifests/7.1.1", t["muted"]),
            ("Already downloaded: /Users/dev/Library/Caches/Homebrew/downloads/ffmpeg-7.1.1.bottle_manifest.json", t["dim"]),
            ("==> Fetching dependencies for ffmpeg: dav1d, harfbuzz, libass, x264, x265", t["text"]),
            ("==> Downloading https://ghcr.io/v2/homebrew/core/ffmpeg/blobs/sha256:9f3c...81e2", t["muted"]),
            ("######################################################################## 100.0%", t["current"]),
            ("==> Upgrading ffmpeg", t["accent"]),
            ("  7.1 -> 7.1.1", t["accent"]),
            ("==> Pouring ffmpeg--7.1.1.arm64_tahoe.bottle.tar.gz", t["text"]),
            ("==> Re-linking /opt/homebrew/Cellar/ffmpeg/7.1.1 -> /opt/homebrew/bin/ffmpeg", t["text"]),
            ("🍺  /opt/homebrew/Cellar/ffmpeg/7.1.1: 287 files, 148.2MB", t["current"]),
            ("==> Running `brew cleanup ffmpeg`...", t["muted"]),
            ("Removing: /opt/homebrew/Cellar/ffmpeg/7.1... (284 files, 146.9MB)", t["dim"]),
        ]
        for idx, (line, col) in enumerate(log_lines):
            self.text(f"ll-{idx}", line, 278, 434 + idx * 28, 1100, 20, size=12, color=col, font="SF Mono")

    # ------------------------------------------------------------------
    # SCREEN 4: SERVICES & MAINTENANCE
    # ------------------------------------------------------------------
    def build_services(self):
        t = self.t
        self.chrome_shell("Services", "Services & Maintenance", "4 launchd services · 1.84 GB reclaimable cache")

        # Services section header
        self.text("srv-hdr", "BACKGROUND SERVICES (brew services)", 244, 72, 400, 16, size=10, color=t["dim"], weight="SemiBold")
        services = [
            ("postgresql@17", "Running", "PID 4821 · LaunchAgent · ~/Library/LaunchAgents/homebrew.mxcl.postgresql@17.plist", True),
            ("redis", "Running", "PID 1904 · LaunchAgent · port 6379", True),
            ("ollama", "Running", "PID 6112 · LaunchAgent · 127.0.0.1:11434", True),
            ("nginx", "Stopped", "Exit 0 · Ready to start", False),
        ]
        for i, (sname, st, meta, running) in enumerate(services):
            sy = 98 + i * 64
            self.rect(f"srv-{i}", 244, sy, 1172, 54, fill=t["elevated"], stroke=t["border"], sw=1, r=10)
            self.circle(f"srv-{i}-dot", 264, sy + 22, 10, t["current"] if running else t["dim"])
            self.text(f"srv-{i}-n", sname, 286, sy + 10, 200, 18, size=13, font="SF Mono", weight="SemiBold")
            self.text(f"srv-{i}-m", meta, 286, sy + 30, 740, 15, size=11, color=t["muted"], font="SF Mono")
            if running:
                self.button(f"srv-{i}-rst", "Restart", 1200, sy + 11, 94, 32, primary=False)
                self.button(f"srv-{i}-stp", "Stop", 1304, sy + 11, 94, 32, destructive=True)
            else:
                self.button(f"srv-{i}-str", "Start", 1304, sy + 11, 94, 32, primary=True)

        # Maintenance Cards (2x2 grid below services)
        self.text("mnt-hdr", "MAINTENANCE & DIAGNOSTICS", 244, 376, 400, 16, size=10, color=t["dim"], weight="SemiBold")
        cards = [
            (244, 404, "Homebrew Doctor", "Ready to run", "Checks Cellar symlinks, PATH order, and broken dylibs.", "Run brew doctor", True, t["current"]),
            (842, 404, "Cache & Old Downloads", "1.84 GB reclaimable", "42 cached bottles & installers in ~/Library/Caches/Homebrew.", "Clean Cache", False, t["outdated"]),
            (244, 624, "Brewfile Snapshot", "Last exported 2d ago", "38 leaves, 24 casks, 5 taps ready for ~/.Brewfile sync.", "Export Brewfile", False, t["current"]),
            (842, 624, "Orphaned Dependencies", "6 unused formulas", "Dependencies no longer required by any installed leaf package.", "Autoremove (6)", False, t["outdated"]),
        ]
        for idx, (cx, cy, ctitle, cstat, cdesc, cbtn, is_pri, scol) in enumerate(cards):
            self.rect(f"mc-{idx}", cx, cy, 574, 196, fill=t["elevated"], stroke=t["border"], sw=1, r=12)
            self.text(f"mc-{idx}-t", ctitle, cx + 24, cy + 22, 340, 22, size=16, font="SF Pro Display", weight="Bold")
            self.badge(f"mc-{idx}-s", cstat, cx + 380, cy + 22, 170, t["elevated2"], scol, r=10, size=11, mono=True)
            self.text(f"mc-{idx}-d", cdesc, cx + 24, cy + 60, 520, 44, size=13, color=t["muted"])
            self.button(f"mc-{idx}-b", cbtn, cx + 24, cy + 136, 176, 36, primary=is_pri)

    # ------------------------------------------------------------------
    # SCREEN 5: CMD+K COMMAND PALETTE & MENU BAR POPOVER
    # ------------------------------------------------------------------
    def build_palette_menubar(self):
        t = self.t
        # Base workspace underneath
        self.build_installed()
        # Dimmed scrim
        self.rect("scrim", 0, 0, 1440, 900, fill=t["backdrop"], opacity=0.45, r=16)

        # Floating Liquid Glass Cmd+K Command Palette (left-center)
        px, py = 200, 160
        self.rect("pal-card", px, py, 640, 430, fill=t["glass"], stroke=t["glassBorder"], sw=1.5, r=16, opacity=0.98)
        self.rect("pal-input", px + 16, py + 16, 608, 46, fill=t["bg"], stroke=t["accent"], sw=1.5, r=10)
        self.text("pal-q", "upg", px + 34, py + 29, 300, 20, size=15, font="SF Mono", weight="Medium")
        self.text("pal-esc", "ESC", px + 566, py + 31, 40, 16, size=10, color=t["dim"], font="SF Mono", align="right")

        pal_items = [
            ("Upgrade All Outdated Packages (4)", "Action · ffmpeg, git, bun, uv", "⌘U", True),
            ("Upgrade ffmpeg (7.1 → 7.1.1)", "Formula · homebrew/core", "↵", False),
            ("Run brew cleanup --prune=all", "Maintenance · Reclaim 1.84 GB", "⌘⌫", False),
            ("Run brew doctor Diagnostics", "Maintenance · System health", "⌘D", False),
            ("Restart postgresql@17 Service", "Service · PID 4821", "⌘R", False),
            ("Export Brewfile to ~/Brewfile", "Sync · 38 leaves, 24 casks", "⌘E", False),
        ]
        for idx, (pt, ps, pk, sel) in enumerate(pal_items):
            iy = py + 76 + idx * 54
            if sel:
                self.rect(f"pi-{idx}-bg", px + 12, iy, 616, 48, fill=t["accentTint"], stroke=t["accent"], sw=1, r=9)
            self.text(f"pi-{idx}-t", pt, px + 26, iy + 8, 460, 18, size=13, color=t["accent"] if sel else t["text"], weight="SemiBold")
            self.text(f"pi-{idx}-s", ps, px + 26, iy + 27, 460, 15, size=11, color=t["muted"], font="SF Mono")
            self.rect(f"pi-{idx}-kbg", px + 572, iy + 13, 40, 22, fill=t["elevated2"], stroke=t["border"], sw=1, r=5)
            self.text(f"pi-{idx}-k", pk, px + 572, iy + 16, 40, 16, size=11, color=t["muted"], font="SF Mono", align="center")

        # macOS Menu Bar Status Item + Liquid Glass Popover (right side)
        self.rect("mb-bar", 960, 12, 340, 32, fill=t["glass"], stroke=t["glassBorder"], sw=1, r=8)
        self.image("mb-logo", RENDERS_DIR / "app-icon-1024.png", 974, 19, 18, 18)
        self.text("mb-cnt", "4", 998, 20, 16, 16, size=12, font="SF Mono", weight="Bold")
        self.text("mb-sys", "Thu 4:18 PM   Wi-Fi   100%", 1040, 20, 240, 16, size=12, color=t["muted"])

        mx, my = 960, 56
        self.rect("mb-pop", mx, my, 340, 420, fill=t["glass"], stroke=t["glassBorder"], sw=1.5, r=14, opacity=0.98)
        self.image("mb-pop-logo", RENDERS_DIR / "app-icon-1024.png", mx + 18, my + 16, 24, 24)
        self.text("mb-h1", "Taproom", mx + 48, my + 18, 160, 20, size=15, font="SF Pro Display", weight="Bold")
        self.badge("mb-b", "4 Outdated", mx + 226, my + 18, 96, t["accentTint"], t["accent"], r=10, size=11)
        self.button("mb-upg", "Upgrade All (4)", mx + 18, my + 54, 304, 34, primary=True)

        self.text("mb-s-lbl", "SERVICES", mx + 18, my + 108, 160, 14, size=10, color=t["dim"], weight="SemiBold")
        for idx, (sn, run) in enumerate([("postgresql@17", True), ("redis", True), ("ollama", True), ("nginx", False)]):
            sy = my + 130 + idx * 42
            self.rect(f"mbs-{idx}", mx + 18, sy, 304, 36, fill=t["elevated"], stroke=t["border"], sw=1, r=8)
            self.circle(f"mbs-{idx}-d", mx + 30, sy + 14, 8, t["current"] if run else t["dim"])
            self.text(f"mbs-{idx}-n", sn, mx + 46, sy + 10, 180, 16, size=12, font="SF Mono", weight="Medium")
            self.text(f"mbs-{idx}-t", "Running" if run else "Stopped", mx + 236, sy + 10, 74, 16, size=11, color=t["current"] if run else t["dim"], align="right")

        self.rect("mb-div", mx + 18, my + 312, 304, 1, fill=t["border"])
        self.button("mb-open", "Open Taproom Cockpit", mx + 18, my + 328, 304, 32, primary=False)
        self.text("mb-foot", "Last checked 12m ago · ⌘R to refresh", mx + 18, my + 378, 304, 16, size=11, color=t["dim"], font="SF Mono", align="center")


def run_figcraft(args):
    res = subprocess.run(["figcraft-cli"] + args, capture_output=True, text=True)
    if res.returncode != 0:
        print("STDOUT:", res.stdout)
        print("STDERR:", res.stderr)
        raise RuntimeError(f"figcraft-cli failed: {' '.join(args)}")
    return res.stdout


def main():
    # Phase A: Create 10 top-level frames
    frame_cmds = []
    for idx, (name, _, _) in enumerate(SCREENS):
        col = idx % 5
        row = idx // 5
        frame_cmds.append({
            "command": "node.create",
            "params": {
                "type": "frame",
                "name": name,
                "x": col * 1560,
                "y": row * 1020,
                "width": 1440,
                "height": 900,
                "props": {"clip": True, "cornerRadius": 16},
                "select": False,
            },
        })

    frames_json = SCRIPTS_DIR / "frames.json"
    frames_json.write_text(json.dumps(frame_cmds, indent=2))
    base_fig = DESIGN_DIR / "taproom.base.figcraft"

    out_a = run_figcraft([
        "run", str(frames_json),
        "--out", str(base_fig),
        "--automation-write-root", str(DESIGN_DIR),
    ])

    frame_ids = {}
    for idx, line in enumerate(out_a.strip().splitlines()):
        obj = json.loads(line)
        if not obj.get("ok"):
            raise RuntimeError(f"Frame step {idx} failed: {obj}")
        frame_ids[SCREENS[idx][0]] = obj["result"]["id"]

    # Phase B: Populate all 10 screens
    all_cmds = []
    for name, theme, kind in SCREENS:
        b = Builder(frame_ids[name], theme)
        if kind == "installed":
            b.build_installed()
        elif kind == "discover":
            b.build_discover()
        elif kind == "outdated":
            b.build_outdated()
        elif kind == "services":
            b.build_services()
        elif kind == "palette":
            b.build_palette_menubar()
        all_cmds.extend(b.cmds)

    screens_json = SCRIPTS_DIR / "taproom-screens.json"
    screens_json.write_text(json.dumps(all_cmds, indent=2))
    final_fig = DESIGN_DIR / "taproom.figcraft"

    out_b = run_figcraft([
        "run", str(screens_json),
        "--in", str(base_fig),
        "--out", str(final_fig),
        "--automation-read-root", str(DESIGN_DIR),
        "--automation-write-root", str(DESIGN_DIR),
    ])

    lines_b = out_b.strip().splitlines()
    failures = [json.loads(l) for l in lines_b if not json.loads(l).get("ok")]
    if failures:
        raise RuntimeError(f"{len(failures)} commands failed, first: {failures[0]}")
    print(f"Populated {len(lines_b)} layers across 10 screens with 0 failures.")

    # Export all top-level frames to PNGs
    run_figcraft([
        "export", str(final_fig),
        "--out", str(RENDERS_DIR),
        "--format", "png",
        "--scale", "1",
        "--automation-read-root", str(DESIGN_DIR),
        "--automation-write-root", str(DESIGN_DIR),
    ])
    print("Exported PNGs to", RENDERS_DIR)


if __name__ == "__main__":
    main()

---
version: alpha
name: Taproom
description: Native macOS Liquid Glass Homebrew cockpit modeled after a precision laboratory instrument and a Raycast/Ghostty developer console.
colors:
  primary: "#F59E0B"
  primaryLight: "#B45309"
  onPrimary: "#111214"
  onPrimaryLight: "#FFFFFF"
  surfaceDark: "#141619"
  surfaceElevatedDark: "#1C1F24"
  surfaceLight: "#F7F8FA"
  surfaceElevatedLight: "#FFFFFF"
  textPrimaryDark: "#F3F4F6"
  textSecondaryDark: "#9CA3AF"
  textPrimaryLight: "#111827"
  textSecondaryLight: "#4B5563"
  statusCurrent: "#10B981"
  statusOutdated: "#F59E0B"
  statusError: "#F87171"
typography:
  titleLg:
    fontFamily: SF Pro Display
    fontSize: 20px
    fontWeight: 600
    lineHeight: 1.25
    letterSpacing: -0.01em
  bodyMd:
    fontFamily: SF Pro Text
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.4
  labelSm:
    fontFamily: SF Pro Text
    fontSize: 11px
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: 0.02em
  monoMd:
    fontFamily: SF Mono
    fontSize: 12px
    fontWeight: 500
    lineHeight: 1.45
  monoSm:
    fontFamily: SF Mono
    fontSize: 11px
    fontWeight: 400
    lineHeight: 1.4
rounded:
  xs: 4px
  sm: 6px
  md: 10px
  lg: 14px
  pill: 999px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
components:
  sidebarDark:
    backgroundColor: "{colors.surfaceDark}"
    textColor: "{colors.textPrimaryDark}"
    padding: "{spacing.sm}"
    rounded: "{rounded.sm}"
    typography: "{typography.bodyMd}"
    width: 220px
  sidebarMutedDark:
    backgroundColor: "{colors.surfaceDark}"
    textColor: "{colors.textSecondaryDark}"
    typography: "{typography.labelSm}"
  packageTableDark:
    backgroundColor: "{colors.surfaceDark}"
    textColor: "{colors.textPrimaryDark}"
    padding: "{spacing.md}"
    typography: "{typography.bodyMd}"
  packageTableLight:
    backgroundColor: "{colors.surfaceLight}"
    textColor: "{colors.textPrimaryLight}"
    padding: "{spacing.md}"
    typography: "{typography.bodyMd}"
  packageVersionLight:
    backgroundColor: "{colors.surfaceElevatedLight}"
    textColor: "{colors.textSecondaryLight}"
    typography: "{typography.monoMd}"
  primaryButtonDark:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.onPrimary}"
    rounded: "{rounded.sm}"
    padding: "{spacing.lg}"
    typography: "{typography.labelSm}"
  primaryButtonLight:
    backgroundColor: "{colors.primaryLight}"
    textColor: "{colors.onPrimaryLight}"
    rounded: "{rounded.sm}"
    padding: "{spacing.lg}"
    typography: "{typography.labelSm}"
  inspectorPanelDark:
    backgroundColor: "{colors.surfaceElevatedDark}"
    textColor: "{colors.textPrimaryDark}"
    typography: "{typography.titleLg}"
    padding: "{spacing.xl}"
    rounded: "{rounded.md}"
    width: 340px
  badgeCurrent:
    backgroundColor: "{colors.surfaceElevatedDark}"
    textColor: "{colors.statusCurrent}"
    rounded: "{rounded.pill}"
    padding: "{spacing.xs}"
    typography: "{typography.labelSm}"
  badgeOutdated:
    backgroundColor: "{colors.surfaceElevatedDark}"
    textColor: "{colors.statusOutdated}"
    rounded: "{rounded.pill}"
    padding: "{spacing.xs}"
    typography: "{typography.labelSm}"
  badgeError:
    backgroundColor: "{colors.surfaceElevatedDark}"
    textColor: "{colors.statusError}"
    rounded: "{rounded.pill}"
    padding: "{spacing.xs}"
    typography: "{typography.labelSm}"
  terminalLog:
    backgroundColor: "{colors.surfaceElevatedDark}"
    textColor: "{colors.textPrimaryDark}"
    typography: "{typography.monoSm}"
    rounded: "{rounded.md}"
    padding: "{spacing.lg}"
  commandPalette:
    backgroundColor: "{colors.surfaceElevatedDark}"
    textColor: "{colors.textPrimaryDark}"
    rounded: "{rounded.lg}"
    padding: "{spacing.xs}"
  shortcutCap:
    backgroundColor: "{colors.surfaceDark}"
    textColor: "{colors.textSecondaryDark}"
    rounded: "{rounded.xs}"
    padding: "{spacing.xs}"
    typography: "{typography.monoSm}"
---

# Taproom Design System

## Overview

Taproom looks like an Apple-native developer instrument — combining the translucent navigation chrome of macOS Tahoe's **Liquid Glass** with the dense, monospace-grounded clarity of **Ghostty** and **Raycast**. It is built for macOS engineers and power users who live in Homebrew daily and want zero-latency package inspection, deterministic upgrade queues, and live daemon control without leaving native macOS. Liquid Glass is strictly a navigation and control-layer material; all package catalogs, version diffs, and streaming logs sit on crisp, opaque semantic surfaces.

## Colors

Warm Amber (`{colors.primary}` in dark mode, `{colors.primaryLight}` in light mode) is Taproom's sole brand accent, reserved exclusively for primary actions (`Upgrade All`, `Install`), active selection indicators, and focus rings. Dark mode pairs `{colors.surfaceDark}` content canvases with `{colors.surfaceElevatedDark}` inspector cards; light mode pairs `{colors.surfaceLight}` with `{colors.surfaceElevatedLight}`. Semantic status dots use `{colors.statusCurrent}` for up-to-date packages and running services, `{colors.statusOutdated}` for pending updates, and `{colors.statusError}` for `brew doctor` warnings or failed jobs.

## Typography

UI chrome, sidebar labels, and descriptions use **SF Pro** (`{typography.titleLg}` for detail headers, `{typography.bodyMd}` for table rows and inspector prose, `{typography.labelSm}` for section caps and pill badges). All technical identifiers — version strings, tap paths, bottle sizes, PIDs, and `brew` command output — use **SF Mono** (`{typography.monoMd}` in tables and `{typography.monoSm}` in terminal logs and caveats) with tabular numerals enabled. Display serifs and italicized body copy do not exist in Taproom.

## Layout

The main window is a 2-column `NavigationSplitView` (`220px` sidebar, fluid multi-column package table) paired with a toggleable `340px` right `.inspector` (`⌘I`) and a `48px` unified toolbar. Spacing follows a strict `4px` base grid (`{spacing.xs}` through `{spacing.xl}`), keeping table row heights compact (`34px`) so 18+ packages fit above the fold on a `1440×900` frame. A floating Liquid Glass Job Queue pill docks at bottom-center (`24px` inset) and expands into a sheet for live streaming logs.

## Elevation & Depth

Taproom uses three distinct depth planes: (1) the recessed opaque content plane (`{colors.surfaceDark}` / `{colors.surfaceLight}`) for package tables and logs, (2) the floating Liquid Glass navigation plane (sidebar, window toolbar, bottom job pill) with optical refraction, and (3) modal overlays (`⌘K` Command Palette, Menu Bar popover, Live Log sheet) rendered as elevated glass containers above a dimmed backdrop. Content rows never cast drop shadows.

## Shapes

Radii scale strictly with container hierarchy: `{rounded.xs}` (`4px`) for keyboard shortcut caps and inline code chips, `{rounded.sm}` (`6px`) for buttons and sidebar selection pills, `{rounded.md}` (`10px`) for inspector cards, caveats, and log viewports, `{rounded.lg}` (`14px`) for the `⌘K` Command Palette and floating Job Queue HUD, and `{rounded.pill}` (`999px`) for status and filter pills.

## Components

- **Sidebar (`{components.sidebarDark}`)**: Liquid Glass navigation rail with grouped sections (`Packages`: Installed, Outdated, Discover; `System`: Services, Taps, Maintenance, Brewfile) and a bottom prefix/version footer (`/opt/homebrew · 7.0.16`).
- **Package Table (`{components.packageTableDark}`, `{components.packageTableLight}`)**: Multi-column high-density table with fixed-width monospace version and size columns, kind badges (`FORMULA` / `CASK`), and single-pixel hairline dividers.
- **Inspector (`{components.inspectorPanelDark}`)**: Right-hand slide-over panel showing package title, version, tap, description, dependency chips, caveats callout, and action bar.
- **Terminal Log (`{components.terminalLog}`)**: High-contrast monospace viewport with ANSI-clean `brew` output, elapsed timer, and `Cancel` control.
- **Command Palette (`{components.commandPalette}`)**: Centered Liquid Glass `⌘K` launcher with fuzzy search across actions, packages, and services.

## Do's and Don'ts

1. **Do** keep Liquid Glass strictly on navigation chrome (sidebar, toolbar, floating job pill, `⌘K` palette, menu-bar popover).
2. **Don't** apply glass, blur, or translucency to package table rows, inspector body text, or streaming terminal logs.
3. **Do** render every version number, tap name, file size, PID, and CLI flag in SF Mono with tabular figures.
4. **Don't** invent custom blur rectangles or `NSVisualEffectView` hacks that fight macOS Tahoe's native `.glassEffect()`.
5. **Do** reserve Warm Amber (`{colors.primary}` / `{colors.primaryLight}`) for primary CTAs, active tabs, and focus states.
6. **Don't** use Amber for destructive actions (`Uninstall`, `Stop`) — use semantic red (`{colors.statusError}`) or neutral secondary buttons with confirmation.
7. **Do** keep table row density crisp (`34px`–`38px`) with 1px hairline separators rather than puffy card-per-row lists.
8. **Don't** truncate version diffs (`14.1.0 → 14.1.1`) in the Outdated view; allocate fixed monospace column width.
9. **Do** maintain >= 4.5:1 contrast on all text in both Dark and Light appearances.
10. **Don't** auto-upgrade packages silently; every mutation requires explicit user action and visible queue feedback.
11. **Do** pair every icon-only toolbar action with a tooltip and keyboard shortcut hint.
12. **Don't** use display serifs, gradients on table backgrounds, or drop shadows on list rows.

# StretchCat for Windows

A lightweight system-tray stretch reminder — the Windows counterpart to the macOS
app in the repo root. Built with [Tauri v2](https://tauri.app) (Rust + a tiny vanilla
HTML/CSS/JS card).

Same behavior as the macOS app: a tray icon, reminders every **1 / 2 / 3 hours**
(default 2h), a Windows toast plus a floating cat-video card with **Snooze 10m** /
**Done** and a **30-second** auto-close.

## Layout

| Path | What |
|------|------|
| `reminder-core/` | Pure logic — exercises + the reminder schedule. No Tauri deps. Unit-tested; mirrors `Sources/StretchCatCore/` in the macOS app. |
| `src-tauri/` | The platform shell: tray, card window, toasts, launch-at-login. |
| `src/` | The card UI (`card.html` / `card.css` / `card.js`) + `assets/cat_stretch.mp4`. |

## Develop on macOS or Windows

The logic and card UI run anywhere via Tauri's dev mode:

```bash
cd windows
cargo install tauri-cli --version "^2" --locked   # one-time
cargo tauri dev
```

Fast logic-only checks (no Tauri build needed — great on a Mac):

```bash
cargo test -p reminder-core
cargo clippy -p reminder-core --all-targets -- -D warnings
```

## What needs real Windows

These can't be exercised on macOS and are verified on Windows (a VM or the
`windows-latest` CI job): the **taskbar system tray**, **Windows toasts**,
**registry-based launch-at-login**, and the **MSI/NSIS installer**:

```bash
cargo tauri build
```

## Parity guard

`reminder-core`'s tests and the Swift `StretchCatCoreTests` assert the **same**
constants (5 exercises, 2h default, +10m snooze, 30s auto-close). Change one app's
behavior without the other and its test suite goes red.

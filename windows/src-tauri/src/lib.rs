//! StretchCat for Windows — a tray-only stretch reminder.
//!
//! The schedule + exercise logic lives in the platform-agnostic `reminder-core`
//! crate (mirrored from the macOS `StretchCatCore`). This file is the platform
//! shell: the system tray, the floating "stretch card" window, the dropdown
//! panel, notifications, and launch-at-login — the parts that have no macOS
//! equivalent and must be native.
//!
//! Like the macOS app, clicking the tray icon opens a rich popover (the `panel`
//! window) — there is no separate native menu. (A native menu would actually
//! swallow the left-click on macOS and never deliver it to us.)

use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Mutex;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use reminder_core::{
    pick_exercise, Exercise, Schedule, ALLOWED_INTERVAL_HOURS, AUTO_CLOSE_SECONDS,
    DEFAULT_INTERVAL_HOURS,
};
use serde::Serialize;
use tauri::{
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    AppHandle, Emitter, Manager, PhysicalPosition, PhysicalSize, Position, Rect, Runtime, Size,
    State, WebviewUrl, WebviewWindowBuilder, WindowEvent,
};
use tauri_plugin_autostart::ManagerExt;
use tauri_plugin_notification::NotificationExt;
use tauri_plugin_store::StoreExt;

const STORE_FILE: &str = "settings.json";
const KEY_INTERVAL: &str = "intervalHours";
const KEY_ENABLED: &str = "enabled";

/// Wall-clock millis the panel was last hidden — lets a tray click that closes
/// the panel (via focus-loss) avoid immediately reopening it.
static PANEL_HIDDEN_MS: AtomicU64 = AtomicU64::new(0);

/// Mutable runtime state behind a mutex.
struct AppState {
    schedule: Schedule,
    last_exercise: Option<Exercise>,
}

/// Snapshot sent to the card window's JS on every reminder.
#[derive(Clone, Serialize)]
struct StretchPayload {
    name: String,
    cue: String,
    #[serde(rename = "autoCloseSeconds")]
    auto_close_seconds: u64,
}

/// State the panel / card reads on demand.
#[derive(Serialize)]
struct StateDto {
    interval_hours: u32,
    enabled: bool,
    autostart: bool,
    seconds_remaining: Option<u64>,
    auto_close_seconds: u64,
}

fn now_secs() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

fn now_millis() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}

/// Cheap, dependency-free randomness in `[0, 1)` from the sub-second clock —
/// good enough to vary which exercise shows.
fn rng_unit() -> f64 {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.subsec_nanos())
        .unwrap_or(0);
    (nanos % 1_000_000) as f64 / 1_000_000.0
}

/// Fire a reminder now: pick an exercise, re-arm the next regular reminder,
/// post a toast, and pop the card window on top.
fn fire<R: Runtime>(app: &AppHandle<R>) {
    let exercise = {
        let state = app.state::<Mutex<AppState>>();
        let mut state = state.lock().unwrap();
        let prev = state.last_exercise;
        let ex = *pick_exercise(prev.as_ref(), rng_unit());
        state.last_exercise = Some(ex);
        state.schedule.arm(now_secs());
        ex
    };

    let _ = app
        .notification()
        .builder()
        .title("Time to stretch! 🐾")
        .body(format!("{} — {}", exercise.name, exercise.cue))
        .show();

    if let Some(win) = app.get_webview_window("card") {
        let _ = win.set_visible_on_all_workspaces(true);
        float_over_fullscreen(&win);
        let _ = win.set_always_on_top(true);
        let _ = win.center();
        let _ = win.show();
        let _ = win.set_focus();
    }
    let _ = app.emit(
        "stretch",
        StretchPayload {
            name: exercise.name.to_string(),
            cue: exercise.cue.to_string(),
            auto_close_seconds: AUTO_CLOSE_SECONDS,
        },
    );
}

/// Hide the card window (Done / Snooze / auto-close).
fn hide_card<R: Runtime>(app: &AppHandle<R>) {
    if let Some(win) = app.get_webview_window("card") {
        let _ = win.hide();
    }
}

/// Show / hide the dropdown panel, anchored to the clicked tray icon. Mirrors the
/// macOS menu-bar popover: a rich window (live cat + countdown + controls).
fn toggle_panel<R: Runtime>(app: &AppHandle<R>, icon_rect: Rect) {
    let Some(panel) = app.get_webview_window("panel") else {
        return;
    };
    if panel.is_visible().unwrap_or(false) {
        let _ = panel.hide();
        PANEL_HIDDEN_MS.store(now_millis(), Ordering::Relaxed);
        return;
    }
    // If the panel was just hidden (its focus-loss handler fired as this very
    // click landed), treat the click as a dismiss rather than reopening it.
    if now_millis().saturating_sub(PANEL_HIDDEN_MS.load(Ordering::Relaxed)) < 250 {
        return;
    }

    let scale = panel.scale_factor().unwrap_or(1.0);
    let (ix, iy) = match icon_rect.position {
        Position::Physical(p) => (p.x as f64, p.y as f64),
        Position::Logical(p) => (p.x * scale, p.y * scale),
    };
    let (iw, ih) = match icon_rect.size {
        Size::Physical(s) => (s.width as f64, s.height as f64),
        Size::Logical(s) => (s.width * scale, s.height * scale),
    };

    let psize = panel.outer_size().unwrap_or(PhysicalSize::new(300, 404));
    let (pw, ph) = (psize.width as f64, psize.height as f64);

    // Place below the icon when it sits in the top half of the screen (macOS menu
    // bar) and above it otherwise (e.g. a bottom Windows taskbar).
    let (mx, my, mw, mh) = match panel.current_monitor() {
        Ok(Some(mon)) => {
            let mp = mon.position();
            let ms = mon.size();
            (mp.x as f64, mp.y as f64, ms.width as f64, ms.height as f64)
        }
        _ => (0.0, 0.0, 1920.0, 1080.0),
    };
    let below = iy < my + mh / 2.0;
    let x = (ix + iw / 2.0 - pw / 2.0).clamp(mx, mx + mw - pw);
    let y = if below { iy + ih } else { iy - ph };

    let _ = panel.set_position(Position::Physical(PhysicalPosition::new(
        x as i32, y as i32,
    )));
    let _ = panel.set_always_on_top(true);
    let _ = panel.show();
    let _ = panel.set_focus();
}

/// Make a window float over full-screen Spaces on macOS by adding the
/// `CanJoinAllSpaces | FullScreenAuxiliary` collection behavior — the flag Tauri
/// doesn't expose. No-op (not compiled) anywhere but macOS.
#[cfg(target_os = "macos")]
#[allow(unexpected_cfgs)] // the `objc` macro emits a `cfg(cargo-clippy)` check
fn float_over_fullscreen<R: Runtime>(win: &tauri::WebviewWindow<R>) {
    use objc::runtime::Object;
    use objc::{msg_send, sel, sel_impl};
    if let Ok(ptr) = win.ns_window() {
        let ns = ptr as *mut Object;
        // NSWindowCollectionBehaviorCanJoinAllSpaces = 1 << 0, FullScreenAuxiliary = 1 << 8.
        const CAN_JOIN_ALL_SPACES: usize = 1 << 0;
        const FULL_SCREEN_AUXILIARY: usize = 1 << 8;
        unsafe {
            let current: usize = msg_send![ns, collectionBehavior];
            let _: () = msg_send![
                ns,
                setCollectionBehavior: current | CAN_JOIN_ALL_SPACES | FULL_SCREEN_AUXILIARY
            ];
        }
    }
}

#[cfg(not(target_os = "macos"))]
fn float_over_fullscreen<R: Runtime>(_win: &tauri::WebviewWindow<R>) {}

fn persist<R: Runtime>(app: &AppHandle<R>) {
    let state = app.state::<Mutex<AppState>>();
    let state = state.lock().unwrap();
    if let Ok(store) = app.store(STORE_FILE) {
        store.set(KEY_INTERVAL, state.schedule.interval_hours);
        store.set(KEY_ENABLED, state.schedule.enabled);
        let _ = store.save();
    }
}

// ---- Commands invoked from the panel / card windows ----

#[tauri::command]
fn get_state(app: AppHandle, state: State<Mutex<AppState>>) -> StateDto {
    let st = state.lock().unwrap();
    StateDto {
        interval_hours: st.schedule.interval_hours,
        enabled: st.schedule.enabled,
        autostart: app.autolaunch().is_enabled().unwrap_or(false),
        seconds_remaining: st.schedule.seconds_remaining(now_secs()),
        auto_close_seconds: AUTO_CLOSE_SECONDS,
    }
}

#[tauri::command]
fn done(app: AppHandle) {
    hide_card(&app);
}

#[tauri::command]
fn snooze(app: AppHandle, state: State<Mutex<AppState>>) {
    state.lock().unwrap().schedule.snooze(now_secs());
    hide_card(&app);
}

#[tauri::command]
fn set_interval(app: AppHandle, state: State<Mutex<AppState>>, hours: u32) {
    if !ALLOWED_INTERVAL_HOURS.contains(&hours) {
        return;
    }
    state
        .lock()
        .unwrap()
        .schedule
        .set_interval(hours, now_secs());
    persist(&app);
}

#[tauri::command]
fn set_enabled(app: AppHandle, state: State<Mutex<AppState>>, enabled: bool) {
    state
        .lock()
        .unwrap()
        .schedule
        .set_enabled(enabled, now_secs());
    persist(&app);
}

#[tauri::command]
fn set_autostart(app: AppHandle, enabled: bool) {
    let manager = app.autolaunch();
    let _ = if enabled {
        manager.enable()
    } else {
        manager.disable()
    };
}

#[tauri::command]
fn stretch_now(app: AppHandle) {
    fire(&app);
}

#[tauri::command]
fn quit_app(app: AppHandle) {
    app.exit(0);
}

/// Build the tray icon. Click (left or right) toggles the panel — no native menu,
/// so the click always reaches us (a menu would swallow it on macOS).
fn setup_tray<R: Runtime>(app: &AppHandle<R>) -> tauri::Result<()> {
    let icon = app
        .default_window_icon()
        .cloned()
        .expect("a default window icon is embedded from bundle.icon");

    TrayIconBuilder::with_id("main")
        .icon(icon)
        .tooltip("StretchCat")
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left | MouseButton::Right,
                button_state: MouseButtonState::Up,
                rect,
                ..
            } = event
            {
                toggle_panel(tray.app_handle(), rect);
            }
        })
        .build(app)?;

    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_store::Builder::new().build())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            None,
        ))
        .invoke_handler(tauri::generate_handler![
            get_state,
            done,
            snooze,
            set_interval,
            set_enabled,
            set_autostart,
            stretch_now,
            quit_app
        ])
        .setup(|app| {
            // Run as a menu-bar accessory (no Dock icon), like the macOS app. This
            // also lets the card/panel overlay another app's full-screen Space
            // instead of yanking the user to our own Space.
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);

            let handle = app.handle().clone();

            // Create the two hidden windows in Rust. wry enables media autoplay by
            // default, so the cat video plays without a click — the JS just retries
            // play() until the webview is actually on-screen.
            WebviewWindowBuilder::new(&handle, "card", WebviewUrl::App("card.html".into()))
                .title("Time to stretch")
                .inner_size(360.0, 470.0)
                .resizable(false)
                .decorations(false)
                .transparent(true)
                .shadow(false)
                .skip_taskbar(true)
                .always_on_top(true)
                .center()
                .visible(false)
                .build()?;

            WebviewWindowBuilder::new(&handle, "panel", WebviewUrl::App("panel.html".into()))
                .title("Stretch Cat")
                .inner_size(300.0, 404.0)
                .resizable(false)
                .decorations(false)
                .transparent(true)
                .shadow(false)
                .skip_taskbar(true)
                .always_on_top(true)
                .visible(false)
                .build()?;

            // Load persisted settings (default: 2h, enabled).
            let (interval_hours, enabled) = {
                let store = handle.store(STORE_FILE)?;
                let interval = store
                    .get(KEY_INTERVAL)
                    .and_then(|v| v.as_u64())
                    .map(|v| v as u32)
                    .filter(|h| ALLOWED_INTERVAL_HOURS.contains(h))
                    .unwrap_or(DEFAULT_INTERVAL_HOURS);
                let enabled = store
                    .get(KEY_ENABLED)
                    .and_then(|v| v.as_bool())
                    .unwrap_or(true);
                (interval, enabled)
            };

            let mut schedule = Schedule::new(interval_hours, enabled);
            schedule.arm(now_secs());
            app.manage(Mutex::new(AppState {
                schedule,
                last_exercise: None,
            }));

            // Ask for notification permission up front (unless already granted).
            use tauri::plugin::PermissionState;
            if handle.notification().permission_state()? != PermissionState::Granted {
                let _ = handle.notification().request_permission();
            }

            // Float the card + panel over every Space, including full-screen
            // apps (macOS), so a reminder is never hidden behind one.
            for label in ["card", "panel"] {
                if let Some(w) = handle.get_webview_window(label) {
                    let _ = w.set_visible_on_all_workspaces(true);
                    let _ = w.set_always_on_top(true);
                    float_over_fullscreen(&w);
                }
            }

            // Dismiss the dropdown panel when it loses focus (click-away),
            // matching the macOS popover's transient behavior.
            if let Some(panel) = handle.get_webview_window("panel") {
                let p = panel.clone();
                panel.on_window_event(move |event| {
                    if let WindowEvent::Focused(false) = event {
                        let _ = p.hide();
                        PANEL_HIDDEN_MS.store(now_millis(), Ordering::Relaxed);
                    }
                });
            }

            setup_tray(&handle)?;

            // Tick once a second: fire when due (survives sleep via wall-clock
            // comparison). The panel polls its own countdown independently.
            let ticker = handle.clone();
            std::thread::spawn(move || loop {
                std::thread::sleep(Duration::from_secs(1));
                let due = {
                    let state = ticker.state::<Mutex<AppState>>();
                    let state = state.lock().unwrap();
                    state.schedule.is_due(now_secs())
                };
                if due {
                    fire(&ticker);
                }
            });

            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("error while building StretchCat")
        .run(|_app, event| {
            // Tray app: keep running when a window closes (code == None), but let
            // an explicit quit (app.exit gives Some(code)) actually exit.
            if let tauri::RunEvent::ExitRequested { api, code, .. } = event {
                if code.is_none() {
                    api.prevent_exit();
                }
            }
        });
}

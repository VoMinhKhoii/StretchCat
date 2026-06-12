// The dropdown panel — mirrors the macOS menu-bar popover. Tauri's API is on
// `window.__TAURI__` (withGlobalTauri). The cat is an animated GIF, so it just
// plays.
const { invoke } = window.__TAURI__.core;

const statusEl = document.getElementById("status");
const enabledEl = document.getElementById("enabled");
const autostartEl = document.getElementById("autostart");
const segButtons = Array.from(document.querySelectorAll("#seg button"));

function statusLine(s) {
  if (!s.enabled) return "Reminders paused";
  if (s.seconds_remaining == null) return "Scheduling…";
  const secs = s.seconds_remaining;
  const h = Math.floor(secs / 3600);
  const m = Math.floor((secs % 3600) / 60);
  if (h > 0) return `Next stretch in ${h}h ${m}m`;
  if (m > 0) return `Next stretch in ${m}m`;
  return "Next stretch in under a minute";
}

async function refresh() {
  try {
    const s = await invoke("get_state");
    statusEl.textContent = statusLine(s);
    segButtons.forEach((b) =>
      b.classList.toggle("on", Number(b.dataset.h) === s.interval_hours),
    );
    enabledEl.checked = s.enabled;
    autostartEl.checked = s.autostart;
  } catch (_) {
    /* window may be mid-hide */
  }
}

document.getElementById("stretchNow").addEventListener("click", () => {
  invoke("stretch_now");
});

segButtons.forEach((b) =>
  b.addEventListener("click", async () => {
    await invoke("set_interval", { hours: Number(b.dataset.h) });
    refresh();
  }),
);

enabledEl.addEventListener("change", async (e) => {
  await invoke("set_enabled", { enabled: e.target.checked });
  refresh();
});

autostartEl.addEventListener("change", async (e) => {
  await invoke("set_autostart", { enabled: e.target.checked });
  refresh();
});

document.getElementById("quit").addEventListener("click", () => {
  invoke("quit_app");
});

refresh();
setInterval(refresh, 1000);

// The stretch card. Tauri exposes its API on `window.__TAURI__` because
// `withGlobalTauri` is enabled. The cat is an animated GIF, so it autoplays with
// no media-policy gymnastics.
const { invoke } = window.__TAURI__.core;
const { listen } = window.__TAURI__.event;

const titleEl = document.getElementById("title");
const cueEl = document.getElementById("cue");
const countdownEl = document.getElementById("countdown");

let timer = null;

function startCountdown(seconds) {
  if (timer) clearInterval(timer);
  let left = seconds;
  countdownEl.textContent = `Auto-closes in ${left}s`;
  timer = setInterval(() => {
    left -= 1;
    if (left <= 0) {
      clearInterval(timer);
      timer = null;
      invoke("done");
      return;
    }
    countdownEl.textContent = `Auto-closes in ${left}s`;
  }, 1000);
}

// Each reminder arrives as a "stretch" event with the exercise + countdown.
listen("stretch", (event) => {
  const { name, cue, autoCloseSeconds } = event.payload;
  titleEl.textContent = name;
  cueEl.textContent = cue;
  startCountdown(autoCloseSeconds);
});

document.getElementById("snooze").addEventListener("click", () => {
  if (timer) clearInterval(timer);
  invoke("snooze");
});

document.getElementById("done").addEventListener("click", () => {
  if (timer) clearInterval(timer);
  invoke("done");
});

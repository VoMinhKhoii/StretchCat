(function () {
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const hasGSAP = typeof window.gsap !== "undefined";

  /* ---- drifting paw prints (decorative, motion only) ---- */
  if (!reduce) {
    const paws = document.getElementById("paws");
    const N = 8;
    for (let i = 0; i < N; i++) {
      const p = document.createElement("i");
      p.className = "ph-fill ph-paw-print";
      const size = 16 + Math.round((i % 4) * 8);
      p.style.fontSize = size + "px";
      p.style.left = Math.round((i / N) * 100 + (i % 2 ? 6 : -3)) + "%";
      p.style.animationDuration = 16 + (i % 5) * 5 + "s";
      p.style.animationDelay = -(i * 2.4) + "s";
      paws.appendChild(p);
    }
  }

  /* ---- reveal-on-scroll (data-rise) ---- */
  const rises = document.querySelectorAll("[data-rise]");
  if (reduce || !("IntersectionObserver" in window)) {
    rises.forEach((el) => el.classList.add("in"));
  } else {
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.style.transitionDelay =
              Math.min((entry.target.dataset.delay || 0) * 1, 240) + "ms";
            entry.target.classList.add("in");
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.15, rootMargin: "0px 0px -7% 0px" }
    );
    // stagger siblings sharing a parent
    document.querySelectorAll(".loop-flow, .feature-list, .moves-grid").forEach((group) => {
      group.querySelectorAll("[data-rise]").forEach((el, i) => (el.dataset.delay = i * 70));
    });
    rises.forEach((el) => io.observe(el));
  }

  /* ---- hero squiggle + countdown ring trigger ---- */
  requestAnimationFrame(() => {
    document.querySelector(".hl")?.classList.add("drawn");
  });
  const ring = document.querySelector(".ring-wrap");
  if (ring) {
    if (reduce) ring.classList.add("go");
    else {
      const ro = new IntersectionObserver(
        (e) => e.forEach((x) => x.isIntersecting && (x.target.classList.add("go"), ro.disconnect())),
        { threshold: 0.5 }
      );
      ro.observe(ring);
    }
  }

  /* ---- parallax + hero tilt (GSAP, motion only) ---- */
  if (hasGSAP && !reduce) {
    gsap.registerPlugin(ScrollTrigger);

    gsap.utils.toArray("[data-par]").forEach((el) => {
      const depth = parseFloat(el.dataset.par) || 0.1;
      gsap.to(el, {
        yPercent: -depth * 100,
        ease: "none",
        scrollTrigger: { trigger: el, start: "top bottom", end: "bottom top", scrub: true },
      });
    });

    // hero card 3D tilt toward cursor (transform only, no React-style state)
    const stage = document.querySelector("[data-tilt]");
    const card = document.querySelector("[data-tilt-inner]");
    if (stage && card) {
      const qx = gsap.quickTo(card, "rotationY", { duration: 0.5, ease: "power3" });
      const qy = gsap.quickTo(card, "rotationX", { duration: 0.5, ease: "power3" });
      stage.addEventListener("pointermove", (e) => {
        const r = stage.getBoundingClientRect();
        const px = (e.clientX - r.left) / r.width - 0.5;
        const py = (e.clientY - r.top) / r.height - 0.5;
        qx(px * 16);
        qy(-py * 14);
      });
      stage.addEventListener("pointerleave", () => { qx(0); qy(0); });
    }
  }

  /* ---- interactive MacBook menu + popup ---- */
  (function () {
    const menu = document.getElementById("scMenu");
    const pop = document.getElementById("scPop");
    const trigger = document.getElementById("catTrigger");
    const hint = document.getElementById("catHint");
    if (!menu || !pop || !trigger) return;

    let autoCountId = null;

    // The "click me" callout points at the icon — show it only while nothing
    // is open, so it never fights the menu or popup for attention.
    function refreshHint() {
      if (!hint) return;
      hint.classList.toggle("is-hidden", !menu.hidden || !pop.hidden);
    }

    function openMenu() {
      menu.hidden = false;
      trigger.setAttribute("aria-expanded", "true");
      requestAnimationFrame(() => menu.classList.add("is-open"));
      refreshHint();
    }
    function closeMenu() {
      trigger.setAttribute("aria-expanded", "false");
      menu.classList.remove("is-open");
      if (reduce) { menu.hidden = true; refreshHint(); return; }
      menu.addEventListener("transitionend", function h() {
        if (!menu.classList.contains("is-open")) menu.hidden = true;
        menu.removeEventListener("transitionend", h);
        refreshHint();
      }, { once: true });
    }
    function toggleMenu() { menu.hidden ? openMenu() : closeMenu(); }

    // Swap menu -> popup as a single clean transition: the menu fully closes
    // before the popup appears, so the two are never on screen together (which
    // looked broken on the stacked mobile layout).
    function transitionToPopup() {
      if (menu.hidden || reduce) { closeMenu(); showPop(); return; }
      closeMenu();
      menu.addEventListener("transitionend", function h() {
        menu.removeEventListener("transitionend", h);
        showPop();
      }, { once: true });
    }

    function showPop() {
      pop.hidden = false;
      requestAnimationFrame(() => pop.classList.add("is-open"));
      startCountdown();
      refreshHint();
    }
    function hidePop() {
      clearInterval(autoCountId);
      pop.classList.remove("is-open");
      if (reduce) { pop.hidden = true; refreshHint(); return; }
      pop.addEventListener("transitionend", function h() {
        if (!pop.classList.contains("is-open")) pop.hidden = true;
        pop.removeEventListener("transitionend", h);
        refreshHint();
      }, { once: true });
    }
    function startCountdown() {
      clearInterval(autoCountId);
      if (reduce) return;
      let s = 30;
      const el = document.getElementById("scAuto");
      autoCountId = setInterval(() => {
        s--;
        el.textContent = "Auto-closes in " + s + "s";
        if (s <= 0) hidePop();
      }, 1000);
    }

    trigger.addEventListener("click", toggleMenu);
    document.addEventListener("keydown", (e) => {
      if (e.key !== "Escape") return;
      if (!menu.hidden) closeMenu();
      if (!pop.hidden) hidePop();
    });
    document.addEventListener("pointerdown", (e) => {
      if (menu.hidden) return;
      if (!menu.contains(e.target) && !trigger.contains(e.target)) closeMenu();
    });

    /* segmented interval picker */
    const segStatus = { 1: "Next stretch in 58m", 2: "Next stretch in 1h 23m", 3: "Next stretch in 2h 47m" };
    menu.querySelectorAll(".scm-seg-opt").forEach((opt) => {
      opt.addEventListener("click", () => {
        menu.querySelectorAll(".scm-seg-opt").forEach((o) => {
          o.classList.remove("is-on");
          o.setAttribute("aria-checked", "false");
        });
        opt.classList.add("is-on");
        opt.setAttribute("aria-checked", "true");
        document.getElementById("scStatus").textContent = segStatus[opt.dataset.h];
      });
    });

    /* toggles */
    menu.querySelectorAll(".scm-switch").forEach((sw) => {
      sw.addEventListener("click", () => {
        const on = sw.classList.toggle("is-on");
        sw.setAttribute("aria-checked", String(on));
      });
    });

    /* stretch now -> popup */
    document.getElementById("scStretchNow").addEventListener("click", transitionToPopup);
    document.getElementById("scSnooze").addEventListener("click", hidePop);
    document.getElementById("scDone").addEventListener("click", hidePop);
    menu.querySelector(".scm-quit").addEventListener("click", closeMenu);

    /* auto-open when scrolled into view, demo popup once */
    function runIntro() {
      if (reduce) {
        menu.hidden = false;
        menu.classList.add("is-open");
        trigger.setAttribute("aria-expanded", "true");
        refreshHint();
        return;
      }
      openMenu();
      // Show the controls, then the menu tucks away and the reminder slides in
      // — one clean swap, the same on every screen size.
      setTimeout(() => { if (pop.hidden) transitionToPopup(); }, 2600);
    }

    refreshHint();

    const mb = document.querySelector(".mb");
    if (reduce || !("IntersectionObserver" in window) || !mb) {
      runIntro();
    } else {
      const io = new IntersectionObserver((entries) => {
        entries.forEach((en) => {
          if (en.isIntersecting) { runIntro(); io.disconnect(); }
        });
      }, { threshold: 0.4 });
      io.observe(mb);
    }
  })();

  /* ---- support dialog ---- */
  (function () {
    const overlay = document.getElementById("supportModal");
    const card = overlay && overlay.querySelector(".support-card");
    const closeBtn = document.getElementById("supClose");
    if (!overlay || !card) return;

    let lastTrigger = null;

    function openSupport(trigger) {
      lastTrigger = trigger || null;
      overlay.hidden = false;
      requestAnimationFrame(() => overlay.classList.add("is-open"));
      closeBtn && closeBtn.focus();
    }
    function closeSupport() {
      overlay.classList.remove("is-open");
      const done = () => { overlay.hidden = true; if (lastTrigger) lastTrigger.focus(); };
      if (reduce) { done(); return; }
      overlay.addEventListener("transitionend", function h(e) {
        if (e.target !== overlay) return;
        overlay.removeEventListener("transitionend", h);
        done();
      }, { once: true });
    }

    document.querySelectorAll("[data-support]").forEach((el) =>
      el.addEventListener("click", () => openSupport(el))
    );

    // Bank/Momo toggle — only visible when the card is too narrow for both QRs.
    overlay.querySelectorAll(".sup-tab").forEach((tab) => {
      tab.addEventListener("click", () => {
        const which = tab.dataset.qr;
        overlay.querySelectorAll(".sup-tab").forEach((t) => {
          const on = t === tab;
          t.classList.toggle("is-on", on);
          t.setAttribute("aria-selected", String(on));
        });
        overlay.querySelectorAll(".sup-qr").forEach((qr) =>
          qr.classList.toggle("is-active", qr.dataset.qr === which)
        );
      });
    });
    closeBtn && closeBtn.addEventListener("click", closeSupport);
    overlay.addEventListener("pointerdown", (e) => {
      if (!card.contains(e.target)) closeSupport();
    });
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && !overlay.hidden) closeSupport();
    });
  })();

  /* ---- brew copy ---- */
  const btn = document.querySelector(".brew-copy");
  if (btn) {
    btn.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(btn.dataset.copy);
        btn.classList.add("copied");
        btn.innerHTML = '<i class="ph ph-check"></i>';
        setTimeout(() => { btn.classList.remove("copied"); btn.innerHTML = '<i class="ph ph-copy"></i>'; }, 1600);
      } catch (e) {}
    });
  }

  /* ---- download: little paw burst for delight ---- */
  const dl = document.getElementById("dl-btn");
  if (dl && !reduce) {
    dl.addEventListener("pointerenter", () => {
      const r = dl.getBoundingClientRect();
      for (let i = 0; i < 6; i++) {
        const p = document.createElement("i");
        p.className = "ph-fill ph-paw-print";
        Object.assign(p.style, {
          position: "fixed", left: r.left + r.width / 2 + "px", top: r.top + "px",
          color: "#E8A24B", zIndex: 70, pointerEvents: "none", fontSize: "16px",
        });
        document.body.appendChild(p);
        if (hasGSAP) {
          gsap.to(p, {
            x: (Math.random() - 0.5) * 160, y: -40 - Math.random() * 70,
            opacity: 0, rotation: (Math.random() - 0.5) * 180, duration: 0.9,
            ease: "power2.out", onComplete: () => p.remove(),
          });
        } else setTimeout(() => p.remove(), 50);
      }
    });
  }
})();

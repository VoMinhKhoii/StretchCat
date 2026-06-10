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

// Per-post flare: sweeps the time budget dial from 0:00 to 3:00 when it scrolls into view.
// Without JS (or with reduced motion) the dial simply shows the full 3:00.
(() => {
  const dial = document.querySelector(".budget");
  if (!dial || matchMedia("(prefers-reduced-motion: reduce)").matches || !("IntersectionObserver" in window)) return;
  const fill = dial.querySelector(".fill");
  const hand = dial.querySelector(".hand");
  const read = dial.querySelector(".read");
  const length = fill.getTotalLength();
  const draw = (t) => {
    const minutes = Math.round(180 * t);
    fill.style.strokeDasharray = `${length * t} ${length}`;
    hand.style.transform = `rotate(${360 * t}deg)`;
    read.textContent = `${Math.floor(minutes / 60)}:${String(minutes % 60).padStart(2, "0")}`;
  };
  draw(0);
  new IntersectionObserver((entries, obs) => {
    if (!entries[0].isIntersecting) return;
    obs.disconnect();
    const start = performance.now();
    const tick = (now) => {
      const t = Math.min((now - start) / 1600, 1);
      draw(1 - Math.pow(1 - t, 3));
      if (t < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  }, { threshold: 0.6 }).observe(dial);
})();

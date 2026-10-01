// grant-ps.com notebook.js: small progressive enhancements for post pages. Every page reads correctly without it.
// 1. A Copy button on each code block.
// 2. The margin ruler ("On this page") marks the section being read.
// 3. On very wide screens, footnotes are copied beside their paragraph as sidenotes (the CSS decides when to show them).
// Everything it adds is marked data-flare, so bin/guard ignores it, and aria-hidden where it duplicates content.
(function () {
  "use strict";
  var prose = document.querySelector("[data-post-body]");
  if (!prose) return;

  // 1. Copy buttons
  if (navigator.clipboard && window.isSecureContext) {
    prose.querySelectorAll("pre").forEach(function (pre) {
      var code = pre.querySelector("code") || pre;
      var btn = document.createElement("button");
      btn.type = "button";
      btn.className = "copy";
      btn.textContent = "Copy";
      btn.setAttribute("data-flare", "");
      btn.setAttribute("aria-label", "Copy code to clipboard");
      btn.addEventListener("click", function () {
        navigator.clipboard.writeText(code.textContent).then(function () {
          btn.textContent = "Copied";
          btn.setAttribute("aria-label", "Copied");
          setTimeout(function () { btn.textContent = "Copy"; btn.setAttribute("aria-label", "Copy code to clipboard"); }, 1500);
        });
      });
      pre.insertBefore(btn, pre.firstChild);
    });
  }

  // 2. Ruler: which section is being read
  var ruler = document.querySelector(".ruler");
  if (ruler) {
    var items = Array.prototype.slice.call(ruler.querySelectorAll("li[data-target]"));
    var targets = items.map(function (li) { return document.getElementById(li.getAttribute("data-target")); });
    var ticking = false;
    var update = function () {
      ticking = false;
      var line = window.scrollY + window.innerHeight * 0.3;
      var current = 0;
      targets.forEach(function (t, i) {
        if (t && t.getBoundingClientRect().top + window.scrollY <= line) current = i;
      });
      items.forEach(function (li, i) {
        li.classList.toggle("done", i < current);
        li.classList.toggle("now", i === current);
        var a = li.querySelector("a");
        if (a) { if (i === current) a.setAttribute("aria-current", "location"); else a.removeAttribute("aria-current"); }
      });
    };
    var onScroll = function () { if (!ticking) { ticking = true; window.requestAnimationFrame(update); } };
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll);
    update();
  }

  // 3. Sidenotes
  var refs = prose.querySelectorAll("sup a[data-footnote-ref]");
  var made = false;
  refs.forEach(function (ref) {
    var id = (ref.getAttribute("href") || "").replace(/^#/, "");
    var note = id && document.getElementById(id);
    var para = ref.closest("p, li");
    if (!note || !para || para.closest(".footnotes")) return;
    var box = para.querySelector(":scope > .sidenote");
    if (!box) {
      box = document.createElement("small");
      box.className = "sidenote";
      box.setAttribute("data-flare", "");
      box.setAttribute("aria-hidden", "true");
      para.appendChild(box);
    }
    var copy = document.createElement("span");
    var n = document.createElement("span");
    n.className = "n";
    n.textContent = ref.textContent;
    copy.appendChild(n);
    note.querySelectorAll(":scope > *").forEach(function (child) {
      var c = child.cloneNode(true);
      c.querySelectorAll("[data-footnote-backref]").forEach(function (b) { b.remove(); });
      copy.appendChild(c);
    });
    box.appendChild(copy);
    made = true;
  });
  if (made) prose.classList.add("has-sidenotes");
})();

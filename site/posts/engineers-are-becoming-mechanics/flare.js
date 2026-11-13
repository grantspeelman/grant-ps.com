// Flare for "Engineers Are Becoming Mechanics". Adds a workshop job card under the annual service
// paragraph: pick a stage to see what happens to a product on a visit. Every line restates the post.
// Without this file the post reads the same.
(function () {
  "use strict";
  var prose = document.querySelector("[data-post-body]");
  var anchor = prose && Array.prototype.find.call(prose.querySelectorAll("p"), function (p) {
    return p.textContent.indexOf("annual service. The engineers check") !== -1;
  });
  if (!anchor) return;

  var stages = [
    { id: "in", label: "Check in", when: "First visit",
      work: "The owner brings the product into the workshop. The engineers look at where the AI keeps getting stuck." },
    { id: "tune", label: "Tune up", when: "First visit",
      work: "Tune the agentic harness, fix the problems, and put the current best practices in place." },
    { id: "out", label: "Back on the road", when: "Then maybe nothing for a year",
      work: "Send it back out. The workshop might not see this product again for a year." },
    { id: "service", label: "Annual service", when: "A year later",
      work: "Check it still follows best practice, talk through the problems the owner has hit, and swap in the latest harness." },
    { id: "learn", label: "Back to the harness", when: "Every repair",
      work: "When the same fault keeps coming through the door, fix it in the harness itself, so the workshop's harness stays ahead." }
  ];

  var box = document.createElement("fieldset");
  box.className = "jobcard";
  box.setAttribute("data-flare", "");
  var legend = document.createElement("legend");
  legend.textContent = "Workshop job card: pick a stage";
  box.appendChild(legend);

  var list = document.createElement("div");
  list.className = "jobcard-stages";
  box.appendChild(list);

  var out = document.createElement("dl");
  out.className = "jobcard-out";
  out.setAttribute("aria-live", "polite");

  var row = function (key, value) {
    var dt = document.createElement("dt");
    dt.textContent = key;
    var dd = document.createElement("dd");
    dd.textContent = value;
    out.appendChild(dt);
    out.appendChild(dd);
  };

  var show = function (s, i) {
    out.textContent = "";
    row("Stage", (i + 1) + " of " + stages.length + ", " + s.label);
    row("When", s.when);
    row("Work done", s.work);
  };

  stages.forEach(function (s, i) {
    var label = document.createElement("label");
    var input = document.createElement("input");
    input.type = "radio";
    input.name = "jobcard-stage";
    input.value = s.id;
    input.checked = i === 0;
    input.addEventListener("change", function () { show(s, i); });
    var no = document.createElement("span");
    no.className = "jobcard-no";
    no.setAttribute("aria-hidden", "true");
    no.textContent = "0" + (i + 1);
    var text = document.createElement("span");
    text.textContent = s.label;
    label.appendChild(input);
    label.appendChild(no);
    label.appendChild(text);
    list.appendChild(label);
  });

  show(stages[0], 0);
  box.appendChild(out);
  anchor.parentNode.insertBefore(box, anchor.nextSibling);
})();

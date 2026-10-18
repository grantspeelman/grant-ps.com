// Flare for "Align on the what". Adds a two-option toggle under the Codex exchange so a reader can
// pick either answer to Q1 and see what the rule would cover. Without this file the post reads the same.
(function () {
  "use strict";
  var prose = document.querySelector("[data-post-body]");
  var exchange = prose && Array.prototype.find.call(prose.querySelectorAll("pre"), function (pre) {
    return pre.textContent.indexOf("Q1:") !== -1;
  });
  if (!exchange) return;

  var options = [
    {
      id: "all",
      label: "Yes, apply to all repository changes.",
      covers: "Everything, including docs and configuration, goes to sub-agents and gets a separate review.",
      readme: "A one-line README fix is delegated and reviewed too."
    },
    {
      id: "app",
      label: "Apply only to application code.",
      covers: "Only application code goes to sub-agents and gets a separate review.",
      readme: "Docs and configuration are outside the rule."
    }
  ];

  var box = document.createElement("fieldset");
  box.className = "q1";
  box.setAttribute("data-flare", "");
  var legend = document.createElement("legend");
  legend.textContent = "Q1: Does that match your intent?";
  box.appendChild(legend);

  var out = document.createElement("p");
  out.className = "q1-out";
  out.setAttribute("aria-live", "polite");

  var show = function (o) {
    out.textContent = "";
    var covers = document.createElement("span");
    covers.textContent = o.covers + " ";
    var readme = document.createElement("strong");
    readme.textContent = o.readme;
    out.appendChild(covers);
    out.appendChild(readme);
  };

  options.forEach(function (o, i) {
    var label = document.createElement("label");
    var input = document.createElement("input");
    input.type = "radio";
    input.name = "q1-scope";
    input.value = o.id;
    input.checked = i === 0;
    input.addEventListener("change", function () { show(o); });
    var text = document.createElement("span");
    text.textContent = (i + 1) + ". " + o.label;
    label.appendChild(input);
    label.appendChild(text);
    box.appendChild(label);
  });

  show(options[0]);
  box.appendChild(out);
  exchange.parentNode.insertBefore(box, exchange.nextSibling);
})();

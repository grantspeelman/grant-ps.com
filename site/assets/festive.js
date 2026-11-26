// grant-ps.com seasonal layer switch. Rules in design/BRIEF.md, "Seasonal layer".
// Loaded in <head> without defer so the festive colours apply before first paint.
// On from 1 December to 6 January by the visitor's clock. ?festive=1 forces it on, ?festive=0 forces it off.
// It only adds the "festive" class to <html> and, once the page has loaded, swaps the theme line of the home page's site.yml card.
// Without JavaScript the page is the normal notebook.
(function () {
  "use strict";
  var force = /[?&]festive=([01])\b/.exec(location.search);
  var now = new Date();
  var month = now.getMonth(), day = now.getDate();
  var season = month === 11 || (month === 0 && day <= 6);
  if (force ? force[1] !== "1" : !season) return;
  document.documentElement.classList.add("festive");
  document.addEventListener("DOMContentLoaded", function () {
    var theme = document.querySelector(".spec [data-festive-text]");
    if (theme) theme.textContent = theme.getAttribute("data-festive-text");
  });
})();

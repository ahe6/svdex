import { schedule } from "@ember/runloop";
import { modifier } from "ember-modifier";

// Native directory headers contribute intrinsic widths, so merely copying its
// fr formula does not align the boundary once the labels change. Measure core's
// standard table at the same width, and borrow only its identity + first stat.
export default modifier((element) => {
  let disposed = false;
  const update = () => {
    if (disposed) return;
    const reference = element.querySelector(".svdex-company-grid-reference .directory-table");
    const table = element.querySelector(".svdex-companies-table");
    if (!reference || !table) return;
    // This sizing-only, inert copy must not duplicate the visible sort IDs.
    reference.querySelectorAll("[id]").forEach((node) => node.removeAttribute("id"));
    const tracks = getComputedStyle(reference).gridTemplateColumns.split(/\s+/);
    if (!tracks.slice(0, 2).every((track) => /^\d+(\.\d+)?px$/.test(track))) return;
    const count = Number(element.dataset.financialColumns) || 6;
    const columns = `${tracks[0]} ${tracks[1]} repeat(${count}, minmax(min-content, 1fr))`;
    if (table.style.gridTemplateColumns !== columns) table.style.gridTemplateColumns = columns;
  };
  const observer = new ResizeObserver(update);
  observer.observe(element);
  schedule("afterRender", update);
  document.fonts?.ready.then(update);
  return () => { disposed = true; observer.disconnect(); };
});

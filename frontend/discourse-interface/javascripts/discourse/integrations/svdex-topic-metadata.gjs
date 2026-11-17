import { defaultRenderTag } from "discourse/lib/render-tag";
import { tagColor } from "../lib/svdex-tag-colors";

export default function registerTopicMetadata(api, { settings, router, site }) {
  // Keep native full names in selectors/directories, and expose a compact
  // variant only where topic metadata is rendered. CSS hides the unused
  // variant from both sighted readers and assistive technology.
  api.registerValueTransformer("category-display-name", ({ value, context }) => {
    const id = Number(context.category?.id);
    const short = id === Number(settings.svdex_public_offerings_category_id) ? "public"
      : id === Number(settings.svdex_private_offerings_category_id) ? "private"
      : id === Number(settings.svdex_introductions_category_id) ? "updates" : null;
    return short ? `<span class="svdex-category-full">${value}</span><span class="svdex-category-short svdex-category-short--${short}">${short}</span>` : value;
  });

  api.replaceTagRenderer((tag, params) => {
    const name = typeof tag === "string" ? tag : tag.name;
    const color = tagColor(name, settings.svdex_overview_tag_colors);
    // Core still owns the tag label, escaping, URL, classes and count.
    let rendered = defaultRenderTag(tag, params);
    // Preserve the canonical slug while spelling this acronym consistently.
    if (name === "ai") rendered = rendered.replace(">ai<", ">AI<");
    // Visibility names are compact in topic rows; URLs, selector labels and
    // data attributes retain the actual native tag name.
    if (params?.mode === "list" && ["public-offering", "private-offering"].includes(name)) {
      rendered = rendered.replace(`>${name}<`, `>${name.split("-")[0]}<`);
    }
    return rendered.replace(">", `><span class="svdex-tag-marker" style="background-color:#${color}" aria-hidden="true"></span>`);
  });
  const markHomeTopicLabels = ({ value, context }) => {
    const path = router.currentURL.split("?")[0];
    const home = path === "/" || path === "/all-forums" || /^\/(latest|top|new|unread|unseen|hot|posted)(\/|$)/.test(path);
    if (home && context.topic.category?.slug === "discussion") value.push("svdex-home-discussion");
    if (context.topic.svdex_listing || context.topic.svdex_presale) value.push("svdex-home-listing");
    return value;
  };
  api.registerValueTransformer("topic-list-item-class", markHomeTopicLabels);
  api.registerValueTransformer("latest-topic-list-item-class", markHomeTopicLabels);
}

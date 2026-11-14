import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import TagDrop, { ALL_TAGS_ID, NO_TAG_ID, NONE_TAG } from "discourse/select-kit/components/tag-drop";

// Keep core's tag search, menu, labels and keyboard interaction. Only the
// destination differs: filter the Home feed instead of opening a global tag page.
class HomeTagDrop extends TagDrop {
  @action onChange(value, tag) { this.onHomeSelect(value, tag); }
}

export default class HomeTags extends Component {
  @service router;
  @service site;
  @service siteSettings;
  get visible() {
    return this.siteSettings.tagging_enabled && !this.args.outletArgs.category && !this.args.outletArgs.tag &&
      /^discovery\.(latest|top|overview)(?:\.|$)/.test(this.router.currentRouteName);
  }
  get selected() {
    const query = this.router.currentRoute?.queryParams || {};
    if (query.no_tags === true || query.no_tags === "true") return {id: NO_TAG_ID, name: NONE_TAG};
    const name = (Array.isArray(query.tags) ? query.tags[0] : query.tags?.split(/\s+/)[0]);
    return name ? this.site.top_tags?.find(tag => tag.name === name) || {id:name, name, slug:name} : null;
  }
  @action change(value, tag) {
    const current = new URL(this.router.currentURL, window.location.origin);
    const mode = current.pathname === "/top" ? "top" : "latest";
    const params = current.searchParams;
    ["tags", "no_tags", "page", "match_all_tags", "svdex_home"].forEach(key => params.delete(key));
    if (value === NO_TAG_ID) { params.set("no_tags", "true"); params.set("svdex_home", "1"); }
    else if (value !== ALL_TAGS_ID) {
      const selected = tag?.targetTag || tag;
      if (!selected?.name) return;
      params.set("tags", selected.name);
      params.set("svdex_home", "1");
    }
    DiscourseURL.routeTo(`/${mode}${params.size ? `?${params}` : ""}`);
  }
  <template>
    {{#if this.visible}}
      <span class="svdex-home-tags"><HomeTagDrop @tag={{this.selected}} @onHomeSelect={{this.change}} /></span>
    {{/if}}
  </template>
}

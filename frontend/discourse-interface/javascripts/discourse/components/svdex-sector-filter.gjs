import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { hash } from "@ember/helper";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import ComboBox from "discourse/select-kit/components/combo-box";
import TagDropHeader from "discourse/select-kit/components/tag-drop/tag-drop-header";
import { sectorLabel } from "../lib/svdex-company-filters";
import { usesSectorFilter, sectorDestination } from "../lib/svdex-sector-navigation";

export default class SectorFilter extends Component {
  @service router;
  @service siteSettings;
  @tracked sectors = [];
  get category() { return this.args.outletArgs.category; }
  get home() { return !this.category && !this.args.outletArgs.tag; }
  get visible() { return this.siteSettings.tagging_enabled && usesSectorFilter(this.category, this.args.outletArgs.tag, this.router.currentRouteName, this.siteSettings); }
  @action async load() {
    try {
      const result = await ajax("/tag_groups/filter/search.json", { data: { names: ["Sectors"], limit: 1 } });
      if (!this.isDestroying && !this.isDestroyed) this.sectors = result.results.find(group => group.name === "Sectors")?.tags || [];
    } catch (error) { if (!this.isDestroying && !this.isDestroyed) popupAjaxError(error); }
  }
  get options() { return this.sectors.map(tag => ({ id: tag.name, name: sectorLabel(tag.name) })); }
  get selected() {
    const tags = this.router.currentRoute?.queryParams?.tags;
    const names = [...(Array.isArray(tags) ? tags : String(tags || "").split(/\s+/)), this.args.outletArgs.tag?.name];
    return names.find(name => this.sectors.some(tag => tag.name === name));
  }
  @action change(value) {
    DiscourseURL.routeTo(sectorDestination({ url: this.router.currentURL, category: this.category,
      mainTag: this.args.outletArgs.tag?.name, sectorNames: this.sectors.map(tag => tag.name), value, home: this.home }));
  }
  <template>
    {{#if this.visible}}
      <span class={{if this.home "svdex-mobile-filters svdex-home-filters svdex-sector-control" "svdex-mobile-filters svdex-sector-control"}} {{didInsert this.load}}>
        <ComboBox class="tag-drop svdex-sector-filter" @content={{this.options}} @value={{this.selected}} @onChange={{this.change}}
          @options={{hash translatedNone="Filter" headerAriaLabel="Filter" filterable=true clearable=true
            caretDownIcon="angle-right" caretUpIcon="angle-down" headerComponent=TagDropHeader}} />
      </span>
    {{/if}}
  </template>
}

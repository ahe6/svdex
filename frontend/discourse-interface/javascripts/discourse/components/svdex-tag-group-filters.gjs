import OfferingSearch from "./svdex-offering-search.gjs";
import { isOfferingCategory } from "../lib/svdex-offering-categories";
import { sectorLabel } from "../lib/svdex-company-filters";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { fn, hash } from "@ember/helper";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import ComboBox from "discourse/select-kit/components/combo-box";
import TagDropHeader from "discourse/select-kit/components/tag-drop/tag-drop-header";

const GROUPS = [
  { name: "Sectors", label: "Sector" },
];

export default class ListingTagGroupFilters extends Component {
  @service router;
  @service site;
  @service siteSettings;
  @tracked groups = [];
  @tracked failed = false;
  constructor() {
    super(...arguments);
    if (this.args.panel) this.load();
  }

  get visible() {
    return (this.args.panel || !this.site.mobileView) && isOfferingCategory(this.args.outletArgs.currentCategory?.id, this.siteSettings) && !this.args.outletArgs.editingCategory;
  }

  @action async load() {
    this.failed = false;
    try {
      const result = await ajax("/tag_groups/filter/search.json", { data: { names: GROUPS.map(group => group.name), limit: GROUPS.length } });
      if (!this.isDestroying && !this.isDestroyed) this.groups = result.results;
    } catch (error) {
      if (!this.isDestroying && !this.isDestroyed) {
        this.failed = true;
        popupAjaxError(error);
      }
    }
  }

  get selectedTags() {
    const query = this.router.currentRoute?.queryParams?.tags;
    // The native list query uses space-separated tag names.
    if (query) return Array.isArray(query) ? query : String(query).split(/\s+/).filter(Boolean);
    const main = this.args.outletArgs.tag?.name;
    return [main === "none" ? null : main, ...(this.args.outletArgs.additionalTags || [])].filter(Boolean);
  }

  get filters() {
    return GROUPS.flatMap(definition => {
      const group = this.groups.find(item => item.name === definition.name);
      if (!group) return [];
      return [{ ...definition, isSector: definition.name === "Sectors", tags: group.tags, value: [...this.selectedTags].reverse().find(name => group.tags.some(tag => tag.name === name)),
        options: group.tags.map(tag => ({ id: tag.name, name: sectorLabel(tag.name) })) }];
    });
  }

  get valuation() { return this.router.currentRoute?.queryParams?.svdex_valuation; }
  get valuationOptions() {
    return [
      { id: "under-10m", name: "Under $10m USD" },
      { id: "10m-50m", name: "$10m – under $50m USD" },
      { id: "50m-250m", name: "$50m – under $250m USD" },
      { id: "250m-plus", name: "$250m+ USD" },
      { id: "undisclosed", name: "Undisclosed" },
    ];
  }
  @action changeValuation(value) {
    const current = new URL(this.router.currentURL, window.location.origin);
    const params = new URLSearchParams(current.search);
    params.delete("page");
    if (value) params.set("svdex_valuation", value);
    else params.delete("svdex_valuation");
    DiscourseURL.routeTo(`${current.pathname}${params.size ? `?${params}` : ""}`);
  }

  @action change(group, value) {
    const groupTags = new Set(group.tags.map(tag => tag.name));
    const queryTags = this.router.currentRoute?.queryParams?.tags;
    const tags = (Array.isArray(queryTags) ? queryTags : String(queryTags || "").split(/\s+/)).filter(tag => tag && !groupTags.has(tag));
    if (value) tags.push(value);
    // Native tag routes expect their main tag in a combined tags query too;
    // otherwise core treats the returned tag metadata as a synonym redirect.
    const main = this.args.outletArgs.tag?.name;
    if (main && main !== "none" && !tags.includes(main)) tags.unshift(main);
    const uniqueTags = [...new Set(tags)];
    const category = this.args.outletArgs.currentCategory;
    const current = new URL(this.router.currentURL, window.location.origin);
    const params = new URLSearchParams(current.search);
    ["tags", "match_all_tags", "no_tags", "page"].forEach(key => params.delete(key));
    if (uniqueTags.length) {
      params.set("tags", uniqueTags.join(" "));
      params.set("match_all_tags", "true");
    }
    const listFilter = current.pathname.match(/\/l\/(latest|top|new|unread|unseen|hot)$/)?.[1];
    const path = this.args.outletArgs.tag ? current.pathname : `${category.url}${listFilter ? `/l/${listFilter}` : ""}`;
    DiscourseURL.routeTo(`${path}${params.size ? `?${params}` : ""}`);
  }

  <template>
    {{#if this.visible}}

      {{#if @panel}}
      <li class="svdex-offering-filter-group"><ul>
      {{#each this.filters as |filter|}}
        <li>
        <ComboBox
          class="tag-drop svdex-tag-group-filter"
          @content={{filter.options}}
          @value={{filter.value}}
          @onChange={{fn this.change filter}}
          @options={{hash
            translatedNone=filter.label
            headerAriaLabel=filter.label
            filterable=true
            clearable=true
            caretDownIcon="angle-right"
            caretUpIcon="angle-down"
            fullWidthOnMobile=(if @panel false true)
            headerComponent=TagDropHeader
          }}
        />
        </li>
        {{#if filter.isSector}}
          <li>
            <ComboBox class="tag-drop svdex-tag-group-filter" @content={{this.valuationOptions}}
              @value={{this.valuation}} @onChange={{this.changeValuation}}
              @options={{hash translatedNone="Valuation" headerAriaLabel="Valuation" clearable=true
                caretDownIcon="angle-right" caretUpIcon="angle-down" fullWidthOnMobile=(if @panel false true) headerComponent=TagDropHeader}} />
          </li>
        {{/if}}
      {{/each}}
      </ul></li>
      {{/if}}
      <OfferingSearch @panel={{@panel}} @outletArgs={{@outletArgs}} />
    {{/if}}
  </template>
}

import { isOfferingCategory } from "../lib/svdex-offering-categories";
import { sectorLabel } from "../lib/svdex-company-filters";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { destroy, registerDestructor } from "@ember/destroyable";
import { getOwner } from "@ember/owner";
import { modifier } from "ember-modifier";
import { TextareaAutocompleteHandler } from "discourse/lib/textarea-text-manipulation";
import DAutocomplete, { CANCELLED_STATUS } from "discourse/ui-kit/modifiers/d-autocomplete";
import CompanySuggestions from "./svdex-company-suggestions.gjs";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import DFilterInput from "discourse/ui-kit/d-filter-input";
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
  @tracked companyQuery = "";
  @tracked suggestionsOpen = false;

  companyAutocomplete = modifier(input => {
    let request = 0;
    const textHandler = new TextareaAutocompleteHandler(input);
    // A company suggestion replaces the whole search field, unlike a mention
    // inserted into a composer sentence. Keep native positioning and keys.
    textHandler.replaceTerm = (_start, _end, value) => {
      input.value = value;
      input.setSelectionRange(value.length, value.length);
    };
    const autocomplete = DAutocomplete.setupAutocomplete(getOwner(this), input, textHandler, {
      component: CompanySuggestions,
      debounced: true,
      fixedTextareaPosition: true,
      offset: 4,
      autoSelectFirstSuggestion: false,
      dataSource: async () => {
        const term = input.value.trim();
        const current = ++request;
        if (!term) return [];
        const result = await ajax("/listings/companies.json", { data: { q: term, category_id: this.args.outletArgs.currentCategory.id } });
        if (this.isDestroying || this.isDestroyed || current !== request || input.value.trim() !== term) return CANCELLED_STATUS;
        return result.companies;
      },
      transformComplete: result => result.name,
      afterComplete: value => {
        this.companyQuery = value.trim();
        this.applySearch(this.companyQuery);
      },
      onRender: () => { this.suggestionsOpen = true; },
      onClose: () => { this.suggestionsOpen = false; },
    });
    // This field completes its entire value, rather than an @mention trigger.
    // Start the native autocomplete context explicitly for typing and paste.
    const handleInput = () => {
      if (!input.value.trim()) { autocomplete.closeAutocomplete(); return; }
      autocomplete.completeStart = 0;
      autocomplete.completeEnd = (input.selectionStart ?? input.value.length) - 1;
      autocomplete.handleKeyUp({});
    };
    const handleSearchEnter = event => {
      if (event.key === "Enter" && !event.isComposing && autocomplete.selectedIndex < 0) {
        event.preventDefault();
        event.stopImmediatePropagation();
        autocomplete.closeAutocomplete();
        this.submitSearch(event);
      }
    };
    input.addEventListener("input", handleInput);
    input.addEventListener("keydown", handleSearchEnter, { capture: true });
    this.companyAutocompleteInstance = autocomplete;
    // Anchor to the entire filter box, including its leading search icon.
    autocomplete.createVirtualElementAtTextarea = () => ({
      getBoundingClientRect: () => input.closest("form").getBoundingClientRect(),
    });
    return () => {
      input.removeEventListener("input", handleInput);
      input.removeEventListener("keydown", handleSearchEnter, { capture: true });
      request++;
      if (this.companyAutocompleteInstance === autocomplete) this.companyAutocompleteInstance = null;
      destroy(autocomplete);
    };
  });

  constructor() {
    super(...arguments);
    this.syncCompanyQuery();
    this.router.on("routeDidChange", this.syncCompanyQuery);
    registerDestructor(this, () => this.router.off("routeDidChange", this.syncCompanyQuery));
    this.load();
  }

  @action syncCompanyQuery() {
    this.companyQuery = this.router.currentRoute?.queryParams?.svdex_company || "";
  }

  get visible() {
    return (this.args.panel || !this.site.mobileView) && isOfferingCategory(this.args.outletArgs.currentCategory?.id, this.siteSettings) && !this.args.outletArgs.editingCategory;
  }

  get showSearch() { return this.args.panel || !this.site.mobileView; }
  get showSort() { return !this.args.panel && !this.site.mobileView; }

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
  get sort() { return /\/l\/top$/.test(this.router.currentURL.split("?")[0]) ? "top" : "latest"; }
  get sortOptions() { return [{ id: "latest", name: "Latest" }, { id: "top", name: "Top" }]; }
  @action changeSort(value) {
    const current = new URL(this.router.currentURL, window.location.origin);
    const params = new URLSearchParams(current.search);
    params.delete("page");
    params.delete("period");
    const base = current.pathname.replace(/\/l\/(latest|top|new|unread|unseen|hot|posted)$/, "");
    DiscourseURL.routeTo(`${base}/l/${value}${params.size ? `?${params}` : ""}`);
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

  @action focusSearch(event) {
    // Match the visible filter frame's hit area without intercepting clearing
    // or the input's own native click/selection handling.
    if (!event.target.closest("button, input, a")) event.currentTarget.querySelector("input")?.focus();
  }

  @action updateSearch(event) { this.companyQuery = event.target.value; }

  @action submitSearch(event) {
    event?.preventDefault();
    this.applySearch(this.companyQuery.trim());
  }

  @action async clearSearch() {
    await this.companyAutocompleteInstance?.closeAutocomplete();
    this.companyQuery = "";
    this.applySearch("");
  }

  applySearch(value) {
    const category = this.args.outletArgs.currentCategory;
    const current = new URL(this.router.currentURL, window.location.origin);
    const params = new URLSearchParams(current.search);
    params.delete("page");
    if (value) params.set("svdex_company", value);
    else params.delete("svdex_company");
    const filter = current.pathname.match(/\/l\/(latest|top|new|unread|unseen|hot)$/)?.[1];
    const path = this.args.outletArgs.tag ? current.pathname : `${category.url}${filter ? `/l/${filter}` : ""}`;
    DiscourseURL.routeTo(`${path}${params.size ? `?${params}` : ""}`);
  }

  <template>
    {{#if this.visible}}
      {{#if this.showSearch}}
      <li class="svdex-company-search-item">
        <form class="svdex-company-search-form select-kit single-select combo-box tag-drop" role="search" aria-label="Search by company" {{on "submit" this.submitSearch}} {{on "click" this.focusSearch}}>
          <DFilterInput
            @value={{this.companyQuery}}
            @filterAction={{this.updateSearch}}
            @onClearInput={{this.clearSearch}}
            @icons={{hash left="magnifying-glass"}}
            @containerClass="select-kit-header tag-drop-header"
            placeholder="Search company"
            aria-label="Search company"
            maxlength="120"
            role="combobox"
            aria-autocomplete="list"
            aria-expanded={{this.suggestionsOpen}}
            aria-controls="svdex-company-suggestions"
            {{this.companyAutocomplete}}
          />
        </form>
      </li>
      {{/if}}

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
      {{#if this.showSort}}
        <li class="svdex-offering-sort-item">
          <ComboBox class="tag-drop svdex-tag-group-filter svdex-sort-filter" @content={{this.sortOptions}}
            @value={{this.sort}} @onChange={{this.changeSort}}
            @options={{hash headerAriaLabel="Sort" filterable=false clearable=false
              caretDownIcon="discourse-chevron-expand" caretUpIcon="discourse-chevron-expand" headerComponent=TagDropHeader}} />
        </li>
      {{/if}}
    {{/if}}
  </template>
}

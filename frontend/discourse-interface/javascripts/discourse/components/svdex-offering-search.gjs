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
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";

export default class OfferingSearch extends Component {
  @service router;
  @service site;
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
  }

  @action syncCompanyQuery() {
    this.companyQuery = this.router.currentRoute?.queryParams?.svdex_company || "";
  }

  get offeringCount() {
    const list = this.router.currentRoute?.attributes?.list;
    return list?.topic_list?.svdex_offering_count;
  }
  get offeringCountLabel() { return this.offeringCount === 1 ? "1 offering" : `${this.offeringCount} offerings`; }
  get hasOfferingCount() { return Number.isInteger(this.offeringCount) && !this.args.panel; }

  get showSearch() { return this.args.panel || !this.site.mobileView; }

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
      {{#if this.showSearch}}
      <li class="svdex-company-search-item">
        <form class="svdex-company-search-form select-kit single-select combo-box tag-drop" role="search" aria-label="Search offering" {{on "submit" this.submitSearch}} {{on "click" this.focusSearch}}>
          <DFilterInput
            @value={{this.companyQuery}}
            @filterAction={{this.updateSearch}}
            @onClearInput={{this.clearSearch}}
            @icons={{hash left="magnifying-glass"}}
            @containerClass="select-kit-header tag-drop-header"
            placeholder="Search offering"
            aria-label="Search offering"
            maxlength="120"
            role="combobox"
            aria-autocomplete="list"
            aria-expanded={{this.suggestionsOpen}}
            aria-controls="svdex-company-suggestions"
            {{this.companyAutocomplete}}
          />
        </form>
        {{#if this.hasOfferingCount}}<span class="total-rows">{{this.offeringCountLabel}}</span>{{/if}}
      </li>
      {{/if}}

  </template>
}

import Component from "@glimmer/component";
import { service } from "@ember/service";
import { action } from "@ember/object";
import { hash } from "@ember/helper";
import { tracked } from "@glimmer/tracking";
import { eq } from "truth-helpers";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import bodyClass from "discourse/helpers/body-class";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DResponsiveTable from "discourse/ui-kit/d-responsive-table";
import CompanyColumnMenu from "./svdex-company-column-menu.gjs";
import { sectorLabel } from "../lib/svdex-company-filters";
import { PRODUCT_STAGES } from "../lib/svdex-products";
import ProductUpvote from "./svdex-product-upvote.gjs";

export default class ProductDirectory extends Component {
  @service router;
  @service("svdex-product-directory") directory;
  @tracked rows = [];
  @tracked hasMore = false;
  @tracked loading = true;
  @tracked error = false;
  stages = PRODUCT_STAGES;
  page = 0;
  requestId = 0;
  tableStyle = "grid-template-columns: minmax(18rem, 3fr) minmax(8rem, 1.4fr) minmax(7rem, 1fr) minmax(5rem, .75fr) minmax(6rem, .65fr);";

  get query() { return this.router.currentRoute?.queryParams || {}; }
  get selection() { return JSON.stringify([this.args.presalesOnly, this.query.search, this.category, this.stage, this.ascending]); }
  get category() { return Number(this.query.svdex_product_category) || null; }
  get stage() { return this.args.presalesOnly ? "presale" : this.query.svdex_product_stage || null; }
  get label() { return this.args.presalesOnly ? "Pre-sale products" : "Products"; }
  get scope() { return this.args.presalesOnly ? "presales" : "products"; }
  get ascending() { return this.query.svdex_product_asc === "1"; }
  get sortDirection() { return this.ascending ? "ascending" : "descending"; }

  @action async load(page = 0) {
    const id = ++this.requestId;
    this.loading = true;
    this.error = false;
    try {
      const data = await ajax("/product-directory.json", { data: {
        page, search: this.query.search, category: this.category,
        stage: this.stage, asc: this.ascending ? "1" : "0",
      } });
      if (id !== this.requestId || this.isDestroying || this.isDestroyed) return;
      const rows = data.products.map(row => ({
        ...row, categoryText: row.categories.map(sectorLabel).join(", "),
        stageName: PRODUCT_STAGES.find(stage => stage.id === row.stage)?.name,
      }));
      this.rows = page ? [...this.rows, ...rows] : rows;
      this.directory.categories = data.categories.map(item => ({ ...item, name: sectorLabel(item.name) }));
      this.directory.total = data.total;
      this.hasMore = data.has_more;
      this.page = page;
    } catch {
      if (id === this.requestId && !this.isDestroying && !this.isDestroyed) this.error = true;
    } finally {
      if (id === this.requestId && !this.isDestroying && !this.isDestroyed) this.loading = false;
    }
  }

  @action refresh() {
    this.directory.scope = this.scope;
    this.directory.total = null;
    this.load();
  }

  @action loadMore() {
    if (!this.loading && this.hasMore && !this.error) return this.load(this.page + 1);
  }

  @action chooseCategory(value) {
    this.router.transitionTo({ queryParams: { svdex_product_category: value ? String(value) : null } });
  }

  @action chooseStage(value) {
    this.router.transitionTo({ queryParams: { svdex_product_stage: value } });
  }

  @action toggleUpvotes() {
    this.router.transitionTo({ queryParams: { svdex_product_asc: this.ascending ? null : "1" } });
  }

  <template>
    {{bodyClass "svdex-product-directory-page"}}
    <section class="users-directory directory svdex-product-directory"
      {{didInsert this.refresh}} {{didUpdate this.refresh this.selection}}>
      {{#if this.error}}
        <DEmptyState @body="Products could not be loaded." @ctaLabel="Try again" @ctaAction={{this.refresh}} />
      {{else}}
        <DResponsiveTable @ariaLabel={{this.label}} @className="svdex-product-directory-table" @style={{this.tableStyle}}>
          <:header>
            <div class="directory-table__column-header" role="columnheader"><span class="header-contents">Product</span></div>
            <div class="directory-table__column-header" role="columnheader"><span class="header-contents">Company</span></div>
            <CompanyColumnMenu @label="Category" @filter={{hash reset="All categories"
              options=this.directory.categories value=this.category onChoose=this.chooseCategory}} />
            {{#if @presalesOnly}}
              <div class="directory-table__column-header" role="columnheader"><span class="header-contents">Stage</span></div>
            {{else}}
              <CompanyColumnMenu @label="Stage" @filter={{hash reset="All stages"
                options=this.stages value=this.stage onChoose=this.chooseStage}} />
            {{/if}}
            <div class="directory-table__column-header" role="columnheader" aria-sort={{this.sortDirection}}>
              <DButton class="btn-flat header-contents" @icon={{if this.ascending "angle-up" "angle-down"}}
                @translatedLabel="Upvotes" @translatedTitle="Sort by upvotes" @action={{this.toggleUpvotes}} />
            </div>
          </:header>
          <:body>
            {{#each this.rows as |row|}}
              <div class="directory-table__row" role="row">
                <div class="directory-table__cell" role="rowheader">
                  <div class="user-info small">
                    {{#if row.logo}}<div class="user-image"><img class="avatar svdex-topic-logo" src={{row.logo}} width="48" height="48" alt="" loading="lazy" /></div>{{/if}}
                    <div class="user-detail">
                      <div class="name-line">
                        <span class="name-wrapper"><a href={{row.url}}><strong>{{row.name}}</strong></a></span>
                        {{#if row.description}}<span class="svdex-product-directory-description" title={{row.description}}>{{row.description}}</span>{{/if}}
                      </div>
                    </div>
                  </div>
                </div>
                <div class="directory-table__cell--user-field" role="cell">
                  <span class="directory-table__label"><span>Company</span></span>
                  <span class="directory-table__value--user-field">{{#if row.company}}<a href={{row.company.url}}>{{row.company.name}}</a>{{else}}—{{/if}}</span>
                </div>
                <div class="directory-table__cell--user-field" role="cell">
                  <span class="directory-table__label"><span>Category</span></span>
                  <span class="directory-table__value--user-field">{{if row.categoryText row.categoryText "—"}}</span>
                </div>
                <div class="directory-table__cell--user-field" role="cell">
                  <span class="directory-table__label"><span>Stage</span></span>
                  <span class="directory-table__value--user-field">{{#if (eq row.stage "presale")}}<a href={{if @presalesOnly row.campaign_url row.stage_url}}>{{row.stageName}}</a>{{else}}{{row.stageName}}{{/if}}</span>
                </div>
                <div class="directory-table__cell--user-field" role="cell">
                  <span class="directory-table__label"><span>Upvotes</span></span>
                  <span class="directory-table__value--user-field">
                    {{#if row.vote}}<ProductUpvote @vote={{row.vote}} />{{else}}—{{/if}}
                  </span>
                </div>
              </div>
            {{/each}}
          </:body>
        </DResponsiveTable>
        {{#if this.rows.length}}
          <DLoadMore @enabled={{this.hasMore}} @isLoading={{this.loading}} @action={{this.loadMore}} />
        {{else unless this.loading}}
          <DEmptyState @body="No products match these filters." />
        {{/if}}
      {{/if}}
      <DConditionalLoadingSpinner @condition={{this.loading}} />
    </section>
  </template>
}

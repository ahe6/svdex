import Component from "@glimmer/component";
import { action } from "@ember/object";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DResponsiveTable from "discourse/ui-kit/d-responsive-table";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { INSTRUMENTS, inferredInstrument } from "../lib/svdex-offering-instruments";
import { topicTermsPreview } from "../lib/svdex-offering-terms";

export default class SecuritiesDirectory extends Component {
  tableStyle = "grid-template-columns: minmax(17rem, 3fr) minmax(7rem, 1fr) minmax(10rem, 2fr) minmax(5rem, .7fr);";

  get rows() {
    return this.args.list?.topics.map(topic => ({
      topic,
      instrument: INSTRUMENTS.find(type => type.id === inferredInstrument(topic.svdex_listing, topic.title))?.name,
      terms: topicTermsPreview(topic, { includeExemption: true }),
    })) || [];
  }

  @action async loadMore() {
    const list = this.args.list;
    try {
      await list.loadMore();
    } catch (error) {
      list.set("loadingMore", false);
      popupAjaxError(error);
    }
  }

  <template>
    <section class="users-directory directory svdex-product-directory svdex-securities-directory">
      <DResponsiveTable @ariaLabel="Securities" @className="svdex-product-directory-table" @style={{this.tableStyle}}>
        <:header>
          <div class="directory-table__column-header" role="columnheader"><span class="header-contents">Security</span></div>
          <div class="directory-table__column-header" role="columnheader"><span class="header-contents">Instrument</span></div>
          <div class="directory-table__column-header" role="columnheader"><span class="header-contents">Terms</span></div>
          <div class="directory-table__column-header" role="columnheader"><span class="header-contents">Status</span></div>
        </:header>
        <:body>
          {{#each this.rows as |row|}}
            <div class="directory-table__row" role="row">
              <div class="directory-table__cell" role="rowheader">
                <div class="user-info small">
                  {{#if row.topic.svdex_organization_logo}}
                    <div class="user-image"><img class="avatar svdex-topic-logo" src={{row.topic.svdex_organization_logo}} width="48" height="48" alt="" loading="lazy" /></div>
                  {{/if}}
                  <div class="user-detail">
                    <div class="name-line">
                      <span class="name-wrapper"><a href={{row.topic.url}}><strong>{{row.topic.title}}</strong></a></span>
                      {{#if row.topic.svdex_listing.summary}}
                        <span class="svdex-product-directory-description" title={{row.topic.svdex_listing.summary}}>{{row.topic.svdex_listing.summary}}</span>
                      {{/if}}
                    </div>
                  </div>
                </div>
              </div>
              <div class="directory-table__cell--user-field" role="cell">
                <span class="directory-table__label"><span>Instrument</span></span>
                <span class="directory-table__value--user-field">{{if row.instrument row.instrument "—"}}</span>
              </div>
              <div class="directory-table__cell--user-field" role="cell">
                <span class="directory-table__label"><span>Terms</span></span>
                <span class="directory-table__value--user-field">{{if row.terms row.terms "—"}}</span>
              </div>
              <div class="directory-table__cell--user-field" role="cell">
                <span class="directory-table__label"><span>Status</span></span>
                <span class="directory-table__value--user-field">{{if row.topic.archived "Archived" (if row.topic.closed "Closed" "Open")}}</span>
              </div>
            </div>
          {{/each}}
        </:body>
      </DResponsiveTable>
      {{#if this.rows.length}}
        <DLoadMore @enabled={{@list.more_topics_url}} @isLoading={{@list.loadingMore}} @action={{this.loadMore}} />
      {{else}}
        <DEmptyState @body="No public securities match these filters." />
      {{/if}}
    </section>
  </template>
}

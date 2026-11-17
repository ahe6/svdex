import Component from "@glimmer/component";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { shortDate } from "discourse/lib/formatter";
import { eq } from "truth-helpers";

export default class DiscoveriesSummary extends Component {
  get user() { return this.args.user || this.args.outletArgs.user; }
  get credit() { return this.user?.svdex_discovery; }
  get history() { return this.user?.svdex_discoveries; }
  get viewAllLabel() { return `View all ${this.history.count} ${this.history.count === 1 ? "discovery" : "discoveries"}`; }
  get historyUrl() { return `/u/${encodeURIComponent(this.user.username)}/activity/discoveries`; }
  get credited() { return this.credit?.contributor; }
  get contributorUrl() { return this.credited && `/u/${encodeURIComponent(this.credited.username)}/summary`; }
  get importLabel() { return this.credit?.provenance === "imported" ? "Imported by SVDEX" : "Added by SVDEX"; }
  <template>
    {{#if this.credit}}
      <p class="svdex-discovery-attribution">
        {{#if this.credited}}
          {{#if (eq this.credit.provenance "self_listed")}}Self-listed by{{else}}Discovered by{{/if}}
          <a href={{this.contributorUrl}}>{{this.credited.username}}</a>
        {{else}}{{this.importLabel}}{{/if}}
        {{#if this.credit.listed_at}} · <time datetime={{this.credit.listed_at}}>{{shortDate this.credit.listed_at}}</time>{{/if}}
      </p>
    {{/if}}
    {{#if this.history.count}}
      <section class="top-section svdex-discoveries-summary" aria-label="Discoveries">
        <h3 class="stats-title">Discoveries <span class="svdex-discovery-count">{{this.history.count}}</span></h3>
        <ul class="svdex-discovery-preview">
          {{#each this.history.records as |row|}}
            <li>
              <div class="user-info small"><div class="user-image"><a href={{row.url}} aria-hidden="true">{{dAvatar row.entity imageSize="large"}}</a></div><div class="user-detail">
                <a href={{row.url}}>{{row.entity.name}}</a>
                <span>{{#if (eq row.kind "companies")}}Company{{else if (eq row.kind "funds")}}Fund{{else}}Person{{/if}} · {{shortDate row.listed_at}}{{#if (eq row.provenance "self_listed")}} · Self-listed{{/if}}</span>
              </div></div>
            </li>
          {{/each}}
        </ul>
        <a class="more" href={{this.historyUrl}}>{{this.viewAllLabel}}</a>
      </section>
    {{/if}}
  </template>
}

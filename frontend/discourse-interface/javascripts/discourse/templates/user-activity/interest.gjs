import { fn, hash } from "@ember/helper";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";

export default <template>
  {{#if @controller.model.permissionDenied}}
    <p class="alert alert-info">This activity is private.</p>
  {{else}}
    <div class="svdex-interest-activity">
      <h2 class="svdex-interest-mobile-heading">Interest &amp; bids</h2>
      <div class="inline-form svdex-interest-filters">
        <ComboBox @content={{@controller.kinds}} @value={{@controller.kind}} @onChange={{@controller.changeKind}} @options={{hash translatedName="Submission type"}} />
        <ComboBox @content={{@controller.statuses}} @value={{@controller.status}} @onChange={{@controller.changeStatus}} @options={{hash translatedName="Submission status"}} />
      </div>
      {{#if @controller.rows.length}}
        <DLoadMore @action={{@controller.loadMore}} @enabled={{@controller.hasMore}} @isLoading={{@controller.loading}}>
          <table class="topic-list svdex-interest-list">
            <thead class="topic-list-header"><tr><th class="topic-list-data">Submission</th><th class="topic-list-data">Amount</th><th class="topic-list-data">Status</th><th class="topic-list-data">Updated</th><th class="topic-list-data"><span class="sr-only">Actions</span></th></tr></thead>
            <tbody class="topic-list-body">
              {{#each @controller.rows as |row|}}
                <tr class="topic-list-item">
                  <td class="main-link topic-list-data">
                    <span class="link-top-line">{{#if row.url}}<a class="title" href={{row.url}}>{{row.title}}</a>{{else}}<span class="title">{{row.title}}</span>{{/if}}</span>
                    <div class="svdex-interest-meta">{{row.label}}{{#if row.topic}} · {{row.organization.name}}{{/if}}</div>
                    {{#if row.proposed_terms}}<div class="topic-excerpt svdex-interest-terms">{{row.proposed_terms}}</div>{{/if}}
                  </td>
                  <td class="topic-list-data svdex-interest-amount">{{row.amount}}</td>
                  <td class="topic-list-data svdex-interest-state">{{row.state}}</td>
                  <td class="topic-list-data svdex-interest-date"><time datetime={{row.updated_at}} title={{row.updated_at}}>{{row.date}}</time></td>
                  <td class="topic-list-data svdex-interest-actions">
                    {{#if row.can_edit}}<DButton @translatedLabel={{row.editLabel}} @action={{fn @controller.edit row}} />{{/if}}
                    {{#if row.canWithdraw}}<DButton @translatedLabel="Withdraw" @action={{fn @controller.withdraw row}} />{{/if}}
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
          <DConditionalLoadingSpinner @condition={{@controller.loading}} />
        </DLoadMore>
      {{else}}
        <DEmptyState @title={{if @controller.filtered "No matching submissions" "No interest or bids yet"}} @body={{if @controller.filtered "Try another type or status to find your submissions." "Your company and fund interest and offering bids will appear here. Only you can see this activity."}} />
        {{#if @controller.filtered}}<DButton @translatedLabel="Clear filters" @action={{@controller.clearFilters}} />{{/if}}
      {{/if}}
    </div>
  {{/if}}
</template>

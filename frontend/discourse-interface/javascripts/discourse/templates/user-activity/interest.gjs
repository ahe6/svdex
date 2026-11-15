import { eq } from "truth-helpers";
import InterestRowMenu from "../../components/svdex-interest-row-menu.gjs";
import { fn } from "@ember/helper";
import DButton from "discourse/ui-kit/d-button";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";

export default <template>
  {{#if @controller.model.permissionDenied}}
    <p class="alert alert-info">This activity is private.</p>
  {{else}}
    <div class="svdex-interest-activity">

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
                  <td class="topic-list-data svdex-interest-amount"><span class="svdex-interest-field-label">{{row.label}}:</span> <span class="svdex-interest-amount-value">{{row.amount}}</span></td>
                  <td class="topic-list-data svdex-interest-state"><span class="svdex-interest-field-label">Status:</span> {{row.state}}</td>
                  <td class="topic-list-data svdex-interest-date"><span class="svdex-interest-date-label">Updated </span><time datetime={{row.updated_at}} title={{row.updated_at}}>{{row.date}}</time></td>
                  <td class="topic-list-data svdex-interest-actions">
                    <div class="svdex-interest-action-buttons">
                      {{#if row.can_edit}}
                        <DButton class="btn-flat svdex-interest-edit" @icon="pencil" @translatedLabel="Edit" @action={{fn @controller.edit row}} />
                        {{#if (eq row.kind "interest")}}{{#if row.canWithdraw}}<InterestRowMenu @row={{row}} @withdraw={{@controller.withdraw}} />{{/if}}{{/if}}
                      {{else if row.canWithdraw}}
                        <DButton class="btn-flat svdex-interest-withdraw" @translatedLabel="Withdraw" @action={{fn @controller.withdraw row}} />
                      {{/if}}
                    </div>
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
          <DConditionalLoadingSpinner @condition={{@controller.loading}} />
        </DLoadMore>
      {{else}}
        <DEmptyState @title="No interest or bids yet" @body="Your company and fund interest and offering bids will appear here. Only you can see this activity." />
      {{/if}}
    </div>
  {{/if}}
</template>

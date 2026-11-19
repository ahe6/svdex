import DButton from "discourse/ui-kit/d-button";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { shortDate } from "discourse/lib/formatter";
import { eq } from "truth-helpers";
export default <template>
  <div class="svdex-discoveries-activity">
    <div class="svdex-discovery-controls">
      <span>{{@controller.countLabel}}</span>
    </div>
    {{#if @controller.model.records.length}}
      <table class="topic-list svdex-discovery-list">
        <thead class="topic-list-header"><tr><th class="topic-list-data">Discovery</th><th class="topic-list-data">Type</th><th class="topic-list-data">First listed</th></tr></thead>
        <tbody class="topic-list-body">
          {{#each @controller.model.records as |row|}}
            <tr class="topic-list-item">
              <td class="main-link topic-list-data"><div class="user-info small">
                {{#if row.entity.avatar_template}}<div class="user-image"><a href={{row.url}} aria-hidden="true">{{dAvatar row.entity imageSize="large"}}</a></div>{{/if}}
                <div class="user-detail"><div class="name-line"><a class="name" href={{row.url}}>{{row.entity.name}}</a></div>{{#if row.background}}<span class="svdex-discovery-background">{{row.background}}</span>{{/if}}{{#if (eq row.provenance "self_listed")}}<span class="svdex-discovery-self">Self-listed</span>{{/if}}</div>
              </div></td>
              <td class="topic-list-data svdex-discovery-kind">{{#if (eq row.kind "companies")}}Company{{else if (eq row.kind "funds")}}Fund{{else}}Person{{/if}}</td>
              <td class="topic-list-data svdex-discovery-date"><time datetime={{row.listed_at}}>{{shortDate row.listed_at}}</time></td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    {{else}}<p class="empty-state">No discoveries to show.</p>{{/if}}
    <div class="svdex-discovery-pagination">
      {{#if @controller.hasPrevious}}<DButton @translatedLabel="Previous" @action={{@controller.previous}} />{{/if}}
      {{#if @controller.model.has_more}}<DButton @translatedLabel="Next" @action={{@controller.next}} />{{/if}}
    </div>
  </div>
</template>;

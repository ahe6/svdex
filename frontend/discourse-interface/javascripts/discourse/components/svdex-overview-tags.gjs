import Component from "@glimmer/component";
import { tagColor } from "../lib/svdex-tag-colors";
import { tracked } from "@glimmer/tracking";
import EmberObject, { action, computed } from "@ember/object";
import { service } from "@ember/service";
import ParentCategoryRow from "discourse/components/parent-category-row";
import getURL from "discourse/lib/get-url";
import { escapeExpression } from "discourse/lib/utilities";
import Tag from "discourse/models/tag";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import { i18n } from "discourse-i18n";

class TagCategoryRow extends EmberObject {
  @computed("tracking.messageCount")
  get unreadTopicsCount() {
    return this.tracking.countUnread({ tagId: this.tagId });
  }
  @computed("tracking.messageCount")
  get newTopicsCount() {
    return this.tracking.countNew({ tagId: this.tagId });
  }
}

export default class SvdexOverviewTags extends Component {
  @service router;
  @service site;
  @service siteSettings;
  @service store;
  @service topicTrackingState;
  @tracked rows = [];
  @tracked loading = false;
  @tracked failed = false;

  constructor() {
    super(...arguments);
    if (this.overview) this.loadTags();
  }

  get overview() {
    return ["discovery.overview", "discovery.discussion-forums"].includes(this.router.currentRouteName);
  }

  @action
  async loadTags() {
    this.loading = true;
    this.failed = false;
    try {
      const [result, latest] = await Promise.all([
        this.store.findAll("tag"),
        this.store.findFiltered("topicList", { filter: "latest" }),
      ]);
      if (this.isDestroying || this.isDestroyed) return;
      const groups = result.extras?.tag_groups || [];
      const tags = groups.filter(group => ["companies", "sectors"].includes(group.name.toLowerCase()))
        .flatMap(group => group.tags);
      const uniqueTags = Array.from(new Map(tags.map(tag => [tag.id, Tag.create(tag)])).values());
      this.rows = uniqueTags
        .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name))
        .map(tag => {
          const count = Number(tag.count);
          const number = `<span class="value">${count}</span>`;
          const topics = latest.topics.filter(topic => (topic.tags || []).some(item =>
            typeof item === "string" ? item === tag.name : Number(item.id) === Number(tag.id)));
          // Only show a weekly count if the native Latest response contains all
          // visible topics for this tag. Otherwise use core's all-time variant.
          const complete = topics.length === count;
          const weekCount = complete ? topics.filter(topic => Date.parse(topic.created_at) >= Date.now() - 7 * 86400000).length : 0;
          const stat = weekCount ? i18n("categories.topic_stat", {
            count: weekCount, number: `<span class="value">${weekCount}</span>`,
            unit: `<span class="unit">${i18n("categories.topic_stat_unit.week")}</span>`,
          }) : number;
          // View-only adapters for the actual native row component. Never add
          // these objects to Discourse's category store or permission model.
          return TagCategoryRow.create({
            id: `svdex-tag-${tag.id}`, name: tag.name.split("-").map(word => ["ai", "svdex"].includes(word.toLowerCase()) ? word.toUpperCase() : word.charAt(0).toLocaleUpperCase() + word.slice(1)).join(" "), slug: tag.slug,
            tagId: Number(tag.id), tracking: this.topicTrackingState,
            url: tag.url, color: tagColor(tag.name, this.siteSettings.svdex_overview_tag_colors), textColor: "FFFFFF", style_type: "square",
            description_excerpt: escapeExpression(tag.description || ""),
            stat,
            statTitle: weekCount ? i18n("categories.topic_stat_sentence_week", { count: weekCount }) : i18n("categories.topic_sentence", { count }),
            statTotal: i18n("categories.topic_stat_all_time", { count, number }),
            pickAll: !weekCount, isHidden: false, isMuted: false, hasMuted: false,
            read_restricted: false, subcategories: [], subcategory_count: 0,
            featuredTopics: topics.slice(0, 3),
            unreadUrl: `${tag.url}/l/unread`, newUrl: `${tag.url}/l/new`,
            notificationLevelString: "regular",
          });
        });
    } catch {
      if (!this.isDestroying && !this.isDestroyed) this.failed = true;
    } finally {
      if (!this.isDestroying && !this.isDestroyed) this.loading = false;
    }
  }

  <template>
    {{#if this.overview}}
      <div class="svdex-overview-tags">
        <DConditionalLoadingSpinner @condition={{this.loading}} />
        <div class="svdex-overview-tag-list">
        {{#if this.failed}}
          <div class="alert alert-error">
            Could not load tags.
            <DButton @translatedLabel="Retry" @action={{this.loadTags}} />
          </div>
        {{else if this.site.mobileView}}
          <div class="category-list">
            {{#each this.rows as |row|}}<ParentCategoryRow @category={{row}} />{{/each}}
          </div>
        {{else}}
          <table class="category-list">
            <thead class="category-list-header">
              <tr>
                <th class="category topic-list-data default"><span aria-level="2" id="svdex-overview-tags-heading" role="heading">Tags</span></th>
                <th class="topics topic-list-data num">{{i18n "categories.topics"}}</th>
              </tr>
            </thead>
            <tbody aria-labelledby="svdex-overview-tags-heading">
              {{#each this.rows as |row|}}<ParentCategoryRow @category={{row}} />{{/each}}
            </tbody>
          </table>
        {{/if}}
        </div>
        {{#unless this.loading}}
          {{#unless this.failed}}
            <div class="more-topics">
              <a class="btn btn-default pull-right" href={{getURL "/tags"}}>{{i18n "more"}}</a>
            </div>
          {{/unless}}
        {{/unless}}
      </div>
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}

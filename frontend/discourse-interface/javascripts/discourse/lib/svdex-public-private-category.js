import EmberObject from "@ember/object";
import { i18n } from "discourse-i18n";

export const PRIVATE_ACCESS_ID = "svdex-private-access-info";

// View-only native-row adapter. Never register it in the category store or use
// it for authorization. Restricted counts are supplied only to viewers with native category access.
export function publicPrivateCategory(summary = {}) {
  const count = summary.topic_count ?? 0;
  const known = Number.isInteger(summary.topic_count);
  const week = summary.topics_week ?? 0;
  const number = `<span class="value">${known ? count : "—"}</span>`;
  return EmberObject.create({
    id: PRIVATE_ACCESS_ID, name: "Private offerings", displayName: "Private offerings",
    url: "/private-offerings", slug: "private-offerings", color: "0088CC", text_color: "FFFFFF",
    style_type: "square", read_restricted: true,
    descriptionText: "Access-restricted primary offerings and private secondary sale opportunities. Request access for individual review.",
    description_excerpt: "Access-restricted primary offerings and private secondary sale opportunities. Request access for individual review.",
    topic_count: known ? count : null, totalTopicCount: known ? count : null,
    stat: week ? i18n("categories.topic_stat", { count: week, number: `<span class="value">${week}</span>`, unit: `<span class="unit">${i18n("categories.topic_stat_unit.week")}</span>` }) : number,
    statTitle: !known ? "Request access to view private offerings." : week ? i18n("categories.topic_stat_sentence_week", { count: week }) : i18n("categories.topic_sentence", { count }),
    statTotal: known ? i18n("categories.topic_stat_all_time", { count, number }) : "", pickAll: !week,
    subcategories: [], subcategory_count: 0, featuredTopics: [],
    isHidden: false, isMuted: false, hasMuted: false, notificationLevelString: "regular",
    unreadTopicsCount: 0, newTopicsCount: 0,
  });
}

import { trustHTML } from "@ember/template";
import { categoryBadgeHTML } from "discourse/ui-kit/helpers/d-category-link";
import { publicPrivateCategory, PRIVATE_ACCESS_ID } from "../lib/svdex-public-private-category";
import { tracked } from "@glimmer/tracking";
import { privateAccessNoticePage } from "../lib/svdex-private-access-pages";
import PublicPrivateCategoryRow from "../components/svdex-public-private-category-row.gjs";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";

export default function registerPrivateAccess(api, { settings, router, site }) {
  // Render the public access link as a native subcategory, not a second
  // top-level offering directory. Never add it to Discourse's category store.
  api.modifyClass("component:parent-category-row", Base => class extends Base {
    @service site;
    @service siteSettings;
    get displayedSubcategories() {
      const children = super.displayedSubcategories;
      const privateId = Number(this.siteSettings.svdex_private_offerings_category_id);
      if (Number(this.category?.id) !== Number(this.siteSettings.svdex_listings_category_id) || !privateId || this.site.categories.some(c => Number(c.id) === privateId)) return children;
      return [...children, publicPrivateCategory()];
    }
  });

  // This public navigation choice contains no restricted category metadata.
  // It opens onboarding information, never a private topic-list response.
  const publicPrivateAccessChoice = Base => class extends Base {
    async search(filter) {
      let rows = await super.search(filter);
      const offeringIds = [settings.svdex_listings_category_id, settings.svdex_public_offerings_category_id, settings.svdex_private_offerings_category_id].map(Number).filter(id => id > 0);
      const discussionId = site.categories.find(c => c.slug === "discussion")?.id;
      const communityIds = [discussionId, settings.svdex_help_category_id, settings.svdex_introductions_category_id, settings.svdex_events_category_id].map(Number).filter(id => id > 0);
      const selectedId = Number(this.category?.id);
      const hasAccess = site.categories.some(c => Number(c.id) === Number(settings.svdex_private_offerings_category_id));
      if (!this.editingCategory) {
        if (offeringIds.includes(selectedId)) rows = rows.filter(c => offeringIds.includes(Number(c.id)) && (hasAccess || Number(c.id) !== Number(settings.svdex_listings_category_id)));
        else if (communityIds.includes(selectedId)) return rows.filter(c => communityIds.includes(Number(c.id)) && Number(c.id) !== Number(settings.svdex_events_category_id));
      }
      if (this.editingCategory || hasAccess || Number(settings.svdex_private_offerings_category_id) <= 0 || (filter && !"private offerings".includes(filter.toLowerCase()))) return rows;
      const result = [...rows];
      const publicIndex = result.findIndex(c => Number(c.id) === Number(settings.svdex_public_offerings_category_id));
      const index = publicIndex >= 0 ? publicIndex : result.findIndex(c => Number(c.id) === Number(settings.svdex_listings_category_id));
      result.splice(index >= 0 ? index + 1 : result.length, 0, { id: PRIVATE_ACCESS_ID, name: "Private offerings" });
      return result;
    }
    modifySelection(content) {
      const selected = super.modifySelection(content);
      if (!this.editingCategory && Number(this.category?.id) === Number(settings.svdex_listings_category_id)) {
        const hasAccess = site.categories.some(c => Number(c.id) === Number(settings.svdex_private_offerings_category_id));
        const source = hasAccess ? this.category : site.categories.find(c => Number(c.id) === Number(settings.svdex_public_offerings_category_id));
        if (source) {
          const name = hasAccess ? "All offerings" : "Public offerings";
          selected.name = name;
          selected.title = name;
          selected.label = trustHTML(categoryBadgeHTML({ ...source, name, displayName: name }, { link: false, hideParent: true, allowUncategorized: true }));
        }
      }
      return selected;
    }
    modifyComponentForRow() {
      return this.editingCategory ? super.modifyComponentForRow(...arguments) : PublicPrivateCategoryRow;
    }
    @action onChange(id) {
      if (id === PRIVATE_ACCESS_ID) return DiscourseURL.routeTo("/private-offerings");
      return super.onChange(...arguments);
    }
  };
  publicPrivateAccessChoice.pluginId = "svdex-public-private-access-choice";
  api.modifyClass("component:category-drop", publicPrivateAccessChoice);
  class PrivateAccessNoticeState { @tracked dismissed = false; }
  const privateAccessNotice = new PrivateAccessNoticeState();
  api.addGlobalNotice(
    '<span class="svdex-private-access-notice"><span class="svdex-notice-desktop">Private offerings are available to approved members. <a href="/private-offerings">Request access</a>.</span><span class="svdex-notice-mobile">Private offerings for approved members. <a href="/private-offerings">Request access</a>.</span></span>',
    "svdex-private-access",
    {
      dismissable: true,
      persistentDismiss: false,
      onDismiss: () => { privateAccessNotice.dismissed = true; },
      visibility: () => !privateAccessNotice.dismissed &&
        Number(settings.svdex_private_offerings_category_id) > 0 &&
        !site.categories.some(c => Number(c.id) === Number(settings.svdex_private_offerings_category_id)) &&
        privateAccessNoticePage(router.currentURL, settings),
    }
  );
}

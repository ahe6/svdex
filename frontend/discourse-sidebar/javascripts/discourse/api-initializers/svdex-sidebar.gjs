import { service } from "@ember/service";
import { scheduleOnce } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";
import FAQSectionLink from "discourse/lib/sidebar/common/community-section/faq-section-link";
import AboutSectionLink from "discourse/lib/sidebar/common/community-section/about-section-link";
import BadgesSectionLink from "discourse/lib/sidebar/common/community-section/badges-section-link";
import GroupsSectionLink from "discourse/lib/sidebar/common/community-section/groups-section-link";
import UsersSectionLink from "discourse/lib/sidebar/common/community-section/users-section-link";
import ReviewSectionLink from "discourse/lib/sidebar/user/community-section/review-section-link";
import AdminSectionLink from "discourse/lib/sidebar/user/community-section/admin-section-link";
import InviteSectionLink from "discourse/lib/sidebar/user/community-section/invite-section-link";

export default apiInitializer((api) => {
  // Native themes may be imported before a managed host accepts our plugin.
  // Register plugin routes only when its client settings are present.
  const hasSvdexPlugin = api.container.lookup("service:site-settings")?.svdex_listings_category_id !== undefined;
  // Core leaves anonymous visitors without a colorMode until they choose one.
  // Initialize its native automatic mode so the selector has a valid label.
  const initializeNativeColorMode = () => {
    const color = api.container.lookup("service:interface-color");
    if (color.selectorAvailable && color.colorMode === undefined) {
      color.useAutoMode({ adjustStylesheets: false });
    }
  };
  api.onPageChange(() => scheduleOnce("afterRender", null, initializeNativeColorMode));

  api.addCommunitySectionLink(BaseLink => class extends BaseLink {
    get name() { return "svdex-home"; }
    get text() { return "Home"; }
    get title() { return "Offerings and company or fund updates"; }
    get href() { return "/latest"; }
    get prefixValue() { return "layer-group"; }
    get currentWhen() { return /^discovery\.(latest|top|overview|new|unread|unseen)$/.test(this.router.currentRouteName); }
  });

  api.addCommunitySectionLink(BaseLink => class extends BaseLink {
    @service site;
    get category() { return this.site.categories.find(category => Number(category.id) === Number(this.siteSettings.svdex_listings_category_id)); }
    get name() { return "svdex-offerings"; }
    get currentWhen() {
      const path = (this.router.currentURL || "").split("?")[0];
      const ids = [this.siteSettings.svdex_listings_category_id, this.siteSettings.svdex_public_offerings_category_id, this.siteSettings.svdex_private_offerings_category_id].map(Number);
      return this.site.categories.some(c => ids.includes(Number(c.id)) &&
        (path === c.url || path.startsWith(`${c.url}/`) || path.startsWith(`/tags${c.url}/`)));
    }
    get text() { return "Offerings"; }
    get title() { return "Offerings"; }
    get href() {
      const hasAccess = this.site.categories.some(c => Number(c.id) === Number(this.siteSettings.svdex_private_offerings_category_id));
      return (hasAccess ? this.category : this.site.categories.find(c => Number(c.id) === Number(this.siteSettings.svdex_public_offerings_category_id)))?.url || this.category?.url;
    }
    get prefixValue() { return "list"; }
    get shouldDisplay() { return Boolean(this.category); }
  });

  // Separate directory links share one route without sharing active state.
  const organizationDirectoryLink = (kind, text, icon) => BaseLink => class extends BaseLink {
    @service router;
    get name() { return `svdex-${kind}`; }
    get text() { return text; }
    get title() { return text; }
    get independent() { return window.location.hostname === "localhost" && window.location.port === "4080"; }
    get route() { return this.independent ? `independent-${kind}` : "companies"; }
    get query() { return { kind, order: kind === "funds" ? "svdex_aum" : "svdex_total_funding", asc: null, name: null, svdex_sector: null, svdex_funding: null, svdex_valuation: null, svdex_stage: null, svdex_location: null, svdex_open: null, svdex_type: null, svdex_aum: null, svdex_buy_interest: null, svdex_sell_interest: null }; }
    get prefixType() { return "icon"; }
    get prefixValue() { return icon; }
    get currentWhen() { if (this.independent) return this.router.currentRouteName === `independent-${kind}` || this.router.currentRouteName === (kind === "funds" ? "independent-fund" : "independent-company"); return this.router.currentRouteName === "companies" && (this.router.currentRoute.queryParams.kind || "companies") === kind; }
  };

  const catalogCategoryLink = (name, label, setting, icon, suffix = "") => BaseLink => class extends BaseLink {
    @service site;
    @service siteSettings;
    @service router;
    get category() { return this.site.categories.find(category => Number(category.id) === Number(this.siteSettings[setting])); }
    get name() { return `svdex-${name}`; }
    get text() { return label; }
    get title() { return label; }
    get href() { return this.category && `${this.category.url}${suffix}`; }
    get prefixType() { return "icon"; }
    get prefixValue() { return icon; }
    get shouldDisplay() { return Boolean(this.category); }
    get currentWhen() {
      const url = this.category?.url;
      const path = (this.router.currentURL || "").split("?")[0];
      return Boolean(url && (path === url || path.startsWith(`${url}/`) || path.startsWith(`/tags${url}/`)));
    }
  };

  if (hasSvdexPlugin) {
    api.addCommunitySectionLink(catalogCategoryLink("presales", "Pre-sales", "svdex_presales_category_id", "cart-shopping"));
  }

  // Events starts with native event topics; Calendar is an alternate view.
  api.addCommunitySectionLink(BaseLink => class extends BaseLink {
    @service site;
    get category() { return this.site.categories.find(c => Number(c.id) === Number(this.siteSettings.svdex_events_category_id)); }
    get name() { return "svdex-events"; }
    get text() { return "Events"; }
    get title() { return "Events and community conversations"; }
    get href() { return this.category?.url || "/upcoming-events"; }
    get currentWhen() { return this.router.currentRouteName?.startsWith("discourse-post-event-upcoming-events") || (this.category && this.router.currentURL?.split("?")[0].startsWith(this.category.url)); }
    get prefixValue() { return "calendar-day"; }
    get shouldDisplay() { return this.siteSettings.discourse_events_enabled && this.siteSettings.discourse_post_event_enabled; }
  });

  // Discussions includes the category feed, Overview, and Lounge.
  api.addCommunitySectionLink(BaseLink => class extends BaseLink {
    @service site;
    get category() { return this.site.categories.find(category => category.slug === "discussion"); }
    get name() { return "svdex-discussions"; }
    get currentWhen() {
      if (this.router.currentRouteName === "discovery.discussion-forums") return true;
      const path = (this.router.currentURL || "").split("?")[0];
      if (path === this.siteSettings.svdex_lounge_channel_url) return true;
      return this.category && (path === this.category.url || path.startsWith(`${this.category.url}/`) || path.startsWith(`/tags${this.category.url}/`));
    }
    get text() { return "Discussions"; }
    get title() { return "Research and community discussions"; }
    get href() { return this.category?.url; }
    get prefixValue() { return "comments"; }
    get shouldDisplay() { return Boolean(this.category); }
  });

  if (hasSvdexPlugin) {
    api.addCommunitySectionLink(organizationDirectoryLink("companies", "Companies", "building"));
    api.addCommunitySectionLink(organizationDirectoryLink("funds", "Funds", "chart-pie"));
    api.addCommunitySectionLink(catalogCategoryLink("products", "Products", "svdex_products_category_id", "box-open", "/none"));
    api.addCommunitySectionLink(BaseLink => class extends BaseLink {
      get name() { return "svdex-people"; }
      get text() { return "People"; }
      get title() { return "People"; }
      get route() { return window.location.hostname === "localhost" && window.location.port === "4080" ? "independent-people" : "people"; }
      get query() { return { period: "all", order: "username", asc: true, name: null }; }
      get prefixValue() { return "address-book"; }
    });
  }

  api.addCommunitySectionLink(() => class extends FAQSectionLink {
    get shouldDisplay() { return false; }
  }, true);
  for (const [name, text, property, icon] of [
    ["svdex-terms", "Terms", "tos_url", "file-lines"],
    ["svdex-privacy", "Privacy", "privacy_policy_url", "shield-halved"],
  ]) {
    api.addCommunitySectionLink(BaseLink => class extends BaseLink {
      @service site;
      get name() { return name; }
      get text() { return text; }
      get title() { return text; }
      get href() { return this.site[property]; }
      get prefixValue() { return icon; }
      get shouldDisplay() { return Boolean(this.href); }
    }, true);
  }
  api.addCommunitySectionLink(() => class extends AboutSectionLink {
    get text() { return "About"; }
    get shouldDisplay() { return false; }
  }, true);
  api.addCommunitySectionLink(BaseLink => class extends BaseLink {
    @service site;
    get category() { return this.site.categories.find(category => Number(category.id) === Number(this.siteSettings.svdex_help_category_id)); }
    get name() { return "svdex-help"; }
    get text() { return this.category?.name || "Feedback"; }
    get title() { return this.category?.name || "Feedback"; }
    get href() { return this.category?.url; }
    get prefixValue() { return "circle-question"; }
    get shouldDisplay() { return Boolean(this.category); }
  }, true);
  // Personal conversations use native Chat. Staff applications retain private topics.
  api.addCommunitySectionLink(BaseLink => class extends BaseLink {
    get name() { return "my-messages"; }
    get text() { return "Messages"; }
    get title() { return "Direct messages"; }
    get route() { return "chat.direct-messages"; }
    get prefixValue() { return "envelope"; }
    get currentWhen() { return "chat.direct-messages"; }
    get shouldDisplay() { return Boolean(this.currentUser?.has_chat_enabled) && this.siteSettings.chat_enabled; }
  });

  api.addCommunitySectionLink({
    name: "svdex-index", text: "All tags", title: "All tags", href: "/tags", icon: "tags",
  }, true);
  api.addCommunitySectionLink(BaseLink => class extends BaseLink {
    get name() { return "my-posts"; }
    get text() { return "My posts"; }
    get title() { return "View your posts"; }
    get route() { return "userActivity.index"; }
    get model() { return this.currentUser; }
    get prefixValue() { return "file-lines"; }
    get shouldDisplay() { return Boolean(this.currentUser); }
  });
  api.addCommunitySectionLink(BaseLink => class extends BaseLink {
    get name() { return "svdex-my-interest"; }
    get text() { return "My Interests"; }
    get title() { return "My Interests"; }
    get route() { return "userActivity.interest"; }
    get model() { return this.currentUser?.username; }
    get prefixValue() { return "file-invoice-dollar"; }
    get shouldDisplay() { return Boolean(this.currentUser) && Boolean(this.siteSettings.svdex_companies_group_name); }
  });
  // Keep Bookmarks in core's main navigation instead of a separate custom section.
  api.addCommunitySectionLink(BaseLink => class extends BaseLink {
    get name() { return "svdex-bookmarks"; }
    get text() { return "Bookmarks"; }
    get title() { return "Bookmarks"; }
    get route() { return "userActivity.bookmarks"; }
    get model() { return this.currentUser?.username; }
    get prefixValue() { return "bookmark"; }
    get shouldDisplay() { return Boolean(this.currentUser); }
  });
  api.addCommunitySectionLink(() => class extends BadgesSectionLink {
    get text() { return "Achievements"; }
  }, true);

  api.addCommunitySectionLink(() => class extends UsersSectionLink {
    get text() { return "Users"; }
    get title() { return "Users"; }
  }, true);
  api.addCommunitySectionLink(() => class extends GroupsSectionLink {
    get text() { return "Groups"; }
  }, true);
  api.addCommunitySectionLink(() => class extends ReviewSectionLink {
    constructor(owner, options) { super(owner, { ...options, overriddenName: "Review" }); }
  });
  api.addCommunitySectionLink(() => class extends AdminSectionLink {
    constructor(owner, options) { super(owner, { ...options, overriddenName: "Admin" }); }
  });
  api.addCommunitySectionLink(() => class extends InviteSectionLink {
    constructor(owner, options) { super(owner, { ...options, overriddenName: "Invite" }); }
  });
});

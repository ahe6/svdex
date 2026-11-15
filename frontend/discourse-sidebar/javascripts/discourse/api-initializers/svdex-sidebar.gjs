import { service } from "@ember/service";
import { scheduleOnce } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";
import FAQSectionLink from "discourse/lib/sidebar/common/community-section/faq-section-link";
import AboutSectionLink from "discourse/lib/sidebar/common/community-section/about-section-link";
import BadgesSectionLink from "discourse/lib/sidebar/common/community-section/badges-section-link";
import GroupsSectionLink from "discourse/lib/sidebar/common/community-section/groups-section-link";
import UsersSectionLink from "discourse/lib/sidebar/common/community-section/users-section-link";
import MyPostsSectionLink from "discourse/lib/sidebar/user/community-section/my-posts-section-link";
import MyMessagesSectionLink from "discourse/lib/sidebar/user/community-section/my-messages-section-link";
import ReviewSectionLink from "discourse/lib/sidebar/user/community-section/review-section-link";
import AdminSectionLink from "discourse/lib/sidebar/user/community-section/admin-section-link";
import InviteSectionLink from "discourse/lib/sidebar/user/community-section/invite-section-link";

export default apiInitializer((api) => {
  // Native themes may be imported before a managed host accepts our plugin.
  // Register plugin routes only when its client settings are present.
  const hasSvdexPlugin = api.container.lookup("service:site-settings")?.svdex_listings_category_id !== undefined;
  // Set core's preference before its native navigation handlers run. Scope this
  // to Chat entry points so explicit minimizing still opens the drawer.
  document.addEventListener("click", (event) => {
    const loungeUrl = api.container.lookup("service:site-settings")?.svdex_lounge_channel_url;
    const link = event.target.closest?.("a");
    if (event.target.closest?.('.chat-header-icon a, .nav-pills a[href="/chat/browse/open"]') || (loungeUrl && link?.getAttribute("href") === loungeUrl)) {
      api.container.lookup("service:chat-state-manager")?.prefersFullPage();
    }
  }, true);
  // Core leaves anonymous visitors without a colorMode until they choose one.
  // Initialize its native automatic mode so the selector has a valid label.
  const initializeNativeColorMode = () => {
    const color = api.container.lookup("service:interface-color");
    if (color.selectorAvailable && color.colorMode === undefined) {
      color.useAutoMode({ adjustStylesheets: false });
    }
  };
  api.onPageChange(() => scheduleOnce("afterRender", null, initializeNativeColorMode));

  if (hasSvdexPlugin) {
    // The native All categories sidebar link leads to the combined directory.
    api.modifyClass("route:discovery.categories", {
      pluginId: "svdex-overview-directory",
      beforeModel() {
        if (this.routeName === "discovery.categories") {
          return this.router.replaceWith("discovery.overview");
        }
        return this._super(...arguments);
      },
    });
    api.addNavigationBarItem({
      name: "svdex-overview", displayName: "Overview", href: "/all-forums", before: "categories",
      customFilter: category => !category && api.container.lookup("service:router").currentRouteName !== "discovery.discussion-forums",
      forceActive: (_category, _args, router) => router.currentRouteName === "discovery.overview",
    });
    api.addNavigationBarItem({
      name: "svdex-discussion-forums", displayName: "Overview", title: "Browse discussion forums and tags", href: "/discussion-forums", before: "categories",
      customFilter: category => category?.slug === "discussion" || api.container.lookup("service:router").currentRouteName === "discovery.discussion-forums",
      forceActive: (_category, _args, router) => router.currentRouteName === "discovery.discussion-forums",
    });
    api.addNavigationBarItem({
      name: "svdex-events-calendar", displayName: "Calendar", title: "View events by date", href: "/upcoming-events",
      customFilter: category => Number(category?.id) > 0 && Number(category.id) === Number(api.container.lookup("service:site-settings").svdex_events_category_id),
      forceActive: (_category, _args, router) => router.currentRouteName?.startsWith("discourse-post-event-upcoming-events"),
    });
    api.addNavigationBarItem({
      name: "svdex-discussion-chat",
      before: "svdex-discussion-forums",
      displayName: "Chat",
      title: "Open Lounge chat",
      forceActive: (_category, _args, router) => router.currentURL?.split("?")[0] === api.container.lookup("service:site-settings").svdex_lounge_channel_url,
      href: "/chat/browse/open",
      customHref: () => api.container.lookup("service:site-settings").svdex_lounge_channel_url || "/chat/browse/open",
      customFilter: category => {
        const settings = api.container.lookup("service:site-settings");
        const user = api.container.lookup("service:current-user");
        const channels = api.container.lookup("service:chat-channels-manager");
        return category?.slug === "discussion" && settings.chat_enabled &&
          (user?.has_chat_enabled || channels?.anonymousUserCanViewPublicChat);
      },
    });
  }

  api.modifyClass("component:tag-drop", {
    pluginId: "svdex-sidebar",
    modifyNoSelection() {
      const content = this._super(...arguments);
      return this.tag?.name === "none" ? content : { ...content, name: "tags" };
    },
  });

  // Only the directory heading is renamed; other tag labels stay native.
  const renameTagsHeading = () => {
    const heading = document.querySelector(".tags-index .tags-controls > h2");
    if (heading) heading.textContent = "All tags";
    if (["discovery.overview", "discovery.discussion-forums"].includes(api.container.lookup("service:router").currentRouteName)) {
      const directoryHeading = document.querySelector("#topic-list-heading");
      if (directoryHeading) directoryHeading.textContent = "Overview";
    }
  };
  api.onPageChange(() => scheduleOnce("afterRender", null, renameTagsHeading));


  api.addCommunitySectionLink(BaseLink => class extends BaseLink {
    get name() { return "svdex-home"; }
    get text() { return "Home"; }
    get title() { return "Offerings and company or fund updates"; }
    get href() { return "/latest"; }
    get prefixValue() { return "layer-group"; }
    get currentWhen() { return /^discovery\.(latest|top|overview|new|unread|unseen)$/.test(this.router.currentRouteName); }
  });

  // Separate directory links share one route without sharing active state.
  for (const [kind, text, icon] of (hasSvdexPlugin ? [["companies", "Companies", "building"], ["funds", "Funds", "layer-group"]] : [])) {
    api.addCommunitySectionLink(BaseLink => class extends BaseLink {
      get name() { return `svdex-${kind}`; }
      get text() { return text; }
      get title() { return text; }
      get route() { return "companies"; }
      get query() { return { kind, order: kind === "funds" ? "svdex_aum" : "svdex_total_funding", asc: null, name: null, svdex_sector: null, svdex_funding: null, svdex_valuation: null, svdex_stage: null, svdex_location: null, svdex_open: null, svdex_type: null, svdex_aum: null, svdex_buy_interest: null, svdex_sell_interest: null }; }
      get prefixValue() { return icon; }
      get currentWhen() { return this.router.currentRouteName === "companies" && (this.router.currentRoute.queryParams.kind || "companies") === kind; }
    });
  }

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
  // Independent discussions keep their native category and topic controls,
  // but are no longer mixed into Home's listing/introductions feed.
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

  api.addCommunitySectionLink(() => class extends MyMessagesSectionLink {
    constructor(owner, options) { super(owner, { ...options, overriddenName: "Messages" }); }
  });
  api.addCommunitySectionLink(() => class extends MyPostsSectionLink {
    constructor(owner, options) { super(owner, { ...options, overriddenName: "My posts" }); }
  });
  api.addCommunitySectionLink(BaseLink => class extends BaseLink {
    get name() { return "svdex-my-interest"; }
    get text() { return "My Bids"; }
    get title() { return "My Bids"; }
    get route() { return "userActivity.interest"; }
    get model() { return this.currentUser?.username; }
    get prefixValue() { return "list-check"; }
    get shouldDisplay() { return Boolean(this.currentUser) && Boolean(this.siteSettings.svdex_companies_group_name); }
  });


  api.addCommunitySectionLink({
    name: "svdex-index", text: "All tags", title: "All tags", href: "/tags", icon: "tags",
  }, true);
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
  });
  api.addCommunitySectionLink(() => class extends UsersSectionLink {
    get text() { return "Users"; }
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

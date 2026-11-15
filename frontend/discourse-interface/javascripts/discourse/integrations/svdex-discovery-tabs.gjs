export default function registerDiscoveryTabs(api) {
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

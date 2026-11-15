import { apiInitializer } from "discourse/lib/api";
import { scheduleOnce } from "@ember/runloop";

// Generic native navigation stays usable even when the SVDEX backend is absent.
export default apiInitializer(api => {
  // Set core's preference before its native navigation handlers run. Scope this
  // to Chat entry points so explicit minimizing still opens the drawer.
  document.addEventListener("click", (event) => {
    const loungeUrl = api.container.lookup("service:site-settings")?.svdex_lounge_channel_url;
    const link = event.target.closest?.("a");
    if (event.target.closest?.('.chat-header-icon a, .nav-pills a[href="/chat/browse/open"]') || (loungeUrl && link?.getAttribute("href") === loungeUrl)) {
      api.container.lookup("service:chat-state-manager")?.prefersFullPage();
    }
  }, true);
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


});

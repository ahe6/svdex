import { withPluginApi } from "discourse/lib/plugin-api";
import registerDiscovery from "../integrations/svdex-discovery-navigation.gjs";
import registerPrivateAccess from "../integrations/svdex-private-access.gjs";
import registerProfiles from "../integrations/svdex-organization-profiles.gjs";
import registerMetadata from "../integrations/svdex-topic-metadata.gjs";
import registerOfferings from "../integrations/svdex-offering-topics.gjs";

export default {
  name: "svdex-topic-listings",
  initialize() {
    withPluginApi((api) => {
      const settings = api.container.lookup("service:site-settings");
      if (settings.svdex_listings_category_id === undefined) return;
      const context = {
        settings,
        router: api.container.lookup("service:router"),
        site: api.container.lookup("service:site"),
      };
      registerDiscovery(api, context);
      registerPrivateAccess(api, context);
      registerProfiles(api, context);
      registerMetadata(api, context);
      registerOfferings(api, context);
    });
  },
};

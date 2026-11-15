import InterestActivityNav from "../components/svdex-interest-activity-nav.gjs";
import CompanyApplication from "../components/svdex-company-application.gjs";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import CompanyAdminFields from "../components/svdex-company-admin-fields.gjs";
import CompanySummary from "../components/svdex-company-summary.gjs";

export default function registerOrganizationProfiles(api, { settings, router, site }) {
  const companyApplicationModal = Base => class extends Base {
    @action showRequestMembershipForm() {
      if (this.args.model.name !== settings.svdex_companies_group_name || !this.currentUser) return super.showRequestMembershipForm(...arguments);
      this.modal.show(CompanyApplication, { model: { group: this.args.model } });
    }
  };
  companyApplicationModal.pluginId = "svdex-native-company-application";
  api.modifyClass("component:group-membership-button", companyApplicationModal);

  const peopleGroupChoices = Base => class extends Base {
    async loadGroups() {
      await super.loadGroups(...arguments);
      const organizationGroups = new Set([settings.svdex_companies_group_name, settings.svdex_funds_group_name]);
      const choices = this.groupOptions?.filter(group => !organizationGroups.has(group.id));
      this.set("groupOptions", choices?.length ? choices : null);
    }
  };
  peopleGroupChoices.pluginId = "svdex-people-directory-groups";
  api.modifyClass("controller:users", peopleGroupChoices);

  const memberOrganizations = Base => class extends Base {
    setupController(controller, model) {
      const columns = [...model.columns.filter(column => column.name !== "svdex_organizations"),
        { name: "svdex_organizations", type: "automatic", icon: null }];
      return super.setupController(controller, { ...model, columns });
    }
  };
  memberOrganizations.pluginId = "svdex-member-organizations";
  api.modifyClass("route:users", memberOrganizations);

  // Reuse native collapse/expand behavior for mobile organization profiles.
  // Hidden profiles and ordinary people keep core's visibility rules.
  const compactOrganizationHeader = Base => class extends Base {
    @service site;
    @computed("model.svdex_company_account", "site.mobileView", "model.profile_hidden", "viewingSelf")
    get canExpandProfile() {
      if (this.site.mobileView && this.model?.svdex_company_account && !this.model.profile_hidden) return true;
      return super.canExpandProfile;
    }
    @computed("model.svdex_company_account", "site.mobileView", "model.profile_hidden", "isSummaryRoute", "viewingSelf", "forceExpand")
    get collapsedInfo() {
      if (this.site.mobileView && this.model?.svdex_company_account) return this.model.profile_hidden || !this.forceExpand;
      return super.collapsedInfo;
    }
  };
  compactOrganizationHeader.pluginId = "svdex-compact-organization-header";
  api.modifyClass("controller:user", compactOrganizationHeader);

  const companySummaryRoute = Base => class extends Base {
    setupController(controller, model) {
      this.templateName = this.modelFor("user")?.svdex_company_account ? "svdex-company-profile-summary" : "user/summary";
      super.setupController(controller, model);
    }
  };
  companySummaryRoute.pluginId = "svdex-company-profile-summary";
  api.modifyClass("route:user.summary", companySummaryRoute);
  api.renderInOutlet("after-user-name", CompanySummary);
  api.renderInOutlet("admin-user-details", CompanyAdminFields);
  api.renderInOutlet("user-activity-bottom", InterestActivityNav);
}

import InterestActivityNav from "../components/svdex-interest-activity-nav.gjs";
import CompanyApplication from "../components/svdex-company-application.gjs";
import { action } from "@ember/object";
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

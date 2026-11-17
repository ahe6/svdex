import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DiscourseURL from "discourse/lib/url";

export default class AddPerson extends Component {
  @service currentUser;
  @service site;
  @service siteSettings;
  @action open() {
    if (!this.currentUser) return DiscourseURL.routeTo("/login");
    // Suggestions stay in the native private-message workflow. Staff curate
    // profiles; sending a suggestion never creates an account or membership.
    const params = new URLSearchParams({
      username: this.siteSettings.svdex_private_access_contact,
      title: "Person suggestion",
      body: "Please review this person for the People directory.\n\n**Name:** \n\n**Background and current role:** \n\n**Public profile or source:** ",
    });
    return DiscourseURL.routeTo(`/new-message?${params}`);
  }
  <template>
    <DButton @icon="plus" @translatedLabel={{if this.site.mobileView null "Add person"}}
      @translatedAriaLabel="Add person" @translatedTitle="Add person" @action={{this.open}}
      class="btn-primary svdex-company-application" />
  </template>
}

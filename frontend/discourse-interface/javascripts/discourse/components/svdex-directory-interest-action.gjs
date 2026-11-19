import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import { InterestModal } from "./svdex-interest.gjs";

export default class DirectoryInterestAction extends Component {
  @service modal;
  @service currentUser;
  @service siteSettings;
  @action open() {
    if (!this.currentUser) return DiscourseURL.routeTo("/login");
    const controller = this.args.controller;
    this.modal.show(InterestModal, { model: { chooseOrganization: true, allowDirection: true, kind: controller.kind, independent: controller.independentProfiles, onChange: controller.refreshInterest } });
  }
  <template>
    {{#if this.siteSettings.svdex_interest_enabled}}<DButton @translatedLabel="Add interest" @translatedTitle="Indicate buy or sell interest" @action={{this.open}} class="btn-primary svdex-directory-interest-action" />{{/if}}
  </template>
}

import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { array, hash } from "@ember/helper";
import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import ComboBox from "discourse/select-kit/components/combo-box";
import { InterestModal } from "./svdex-interest.gjs";

// Native SelectKit owns async search, loading, filtering and keyboard selection.
class InterestOrganizationSelect extends ComboBox {
  async search(filter) {
    if (this.independent) {
      const data = await ajax("/company-profiles.json", { data: { name: filter, order: "username", asc: true } });
      return data.profiles.map(({profile}) => ({ id: profile.id, name: profile.name, endpoint: `/company-profile-interests/${profile.id}` }));
    }
    const data = await ajax("/listings/company-directory.json", { data: { name: filter, kind: this.kind, order: "username", asc: true } });
    return data.directory_items.map(({user}) => ({ id: user.id, name: user.name || user.username }));
  }
}
class DirectoryInterestChooser extends Component {
  @service modal;
  @tracked organization;
  @tracked side = "buy";
  get noun() { return this.args.model.controller.isFund ? "Fund" : "Company"; }
  get searchLabel() { return this.args.model.controller.isFund ? "Search funds" : "Search companies"; }
  sides = [{id: "buy", name: "Buy interest"}, {id: "sell", name: "Sell interest"}];
  @action chooseOrganization(_id, item) { this.organization = item; }
  @action chooseSide(side) { this.side = side; }
  @action continue() {
    if (!this.organization) return;
    const organization = this.organization;
    this.modal.show(InterestModal, { model: { organizationId: organization.id, organizationName: organization.name,
      interestEndpoint: organization.endpoint, side: this.side, onChange: this.args.model.controller.refreshInterest } });
  }
  <template>
    <DModal @title="Indicate interest" @closeModal={{@closeModal}}>
      <:body>
        <div class="control-group"><label for="svdex-interest-organization">{{this.noun}}</label>
          <InterestOrganizationSelect @id="svdex-interest-organization" @kind={{@model.controller.kind}} @independent={{@model.controller.independentProfiles}} @value={{this.organization.id}} @content={{if this.organization (array this.organization)}} @onChange={{this.chooseOrganization}} @options={{hash filterable=true translatedNone=this.searchLabel clearable=true}} />
        </div>
        <div class="control-group"><label for="svdex-interest-direction">Direction</label>
          <ComboBox @id="svdex-interest-direction" @value={{this.side}} @content={{this.sides}} @onChange={{this.chooseSide}} />
        </div>
      </:body>
      <:footer><DButton @translatedLabel="Continue" @action={{this.continue}} @disabled={{unless this.organization true}} class="btn-primary" /><DButton @translatedLabel="Cancel" @action={{@closeModal}} /></:footer>
    </DModal>
  </template>
}
export default class DirectoryInterestAction extends Component {
  @service modal;
  @service currentUser;
  @service siteSettings;
  @action open() {
    if (!this.currentUser) return DiscourseURL.routeTo("/login");
    this.modal.show(DirectoryInterestChooser, { model: { controller: this.args.controller } });
  }
  <template>
    {{#if this.siteSettings.svdex_interest_enabled}}<DButton @translatedLabel="Buy / Sell" @translatedTitle="Indicate buy or sell interest" @action={{this.open}} class="btn-default svdex-directory-interest-action" />{{/if}}
  </template>
}

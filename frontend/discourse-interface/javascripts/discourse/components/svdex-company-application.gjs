import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import DModal from "discourse/ui-kit/d-modal";
import DButton from "discourse/ui-kit/d-button";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import DiscourseURL from "discourse/lib/url";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { companyApplication } from "../lib/svdex-company-application";
export default class CompanyApplication extends Component {
  @service currentUser;
  @tracked name = "";
  @tracked representative = this.currentUser?.name || "";
  @tracked description = "";
  @tracked website = "";
  @tracked authorized = false;
  @tracked saving = false;
  @tracked error = "";
  get kind() { return this.args.model.kind; }
  get isFund() { return this.kind === "funds"; }
  @action update(event) {
    const key = event.target.name;
    if (["name", "representative", "description", "website", "authorized"].includes(key)) this[key] = key === "authorized" ? event.target.checked : event.target.value;
    this.error = "";
  }
  @action async submit() {
    const result = companyApplication(this);
    if (result.error) { this.error = result.error; return; }
    this.saving = true;
    try {
      const group = this.args.model.group;
      let url;
      if (group.is_group_user) {
        // Approved members and staff need another profile reviewed, not a
        // second membership. Use the same owners' native private-message inbox.
        const members = await ajax(`/groups/${encodeURIComponent(group.name)}/members.json`, { data: { limit: 1 } });
        const owners = members.owners.map(owner => owner.username);
        if (!owners.length) throw new Error("No application reviewers are available.");
        const post = await ajax("/posts.json", { type: "POST", data: {
          archetype: "private_message", target_recipients: owners.join(","),
          title: `${this.isFund ? "Fund" : "Company"} application: ${this.name.trim()}`,
          raw: result.reason,
        } });
        url = `/t/${post.topic_slug}/${post.topic_id}`;
      } else {
        const response = await group.requestMembership(result.reason);
        url = response.relative_url;
      }
      this.args.closeModal();
      DiscourseURL.routeTo(url);
    } catch (error) { popupAjaxError(error); }
    finally { this.saving = false; }
  }
  <template>
    <DModal @title={{if this.isFund "Add fund" "Add company"}} @closeModal={{@closeModal}} @inline={{@inline}} class="svdex-company-application-modal">
      <:body>
        <p>{{if this.isFund "Tell us about your fund and its strategy. Staff review every application before adding a fund profile." "Tell us about your company or project. Early-stage and pre-incorporation projects are welcome. Staff review every application."}}</p>
        {{#if this.error}}<p class="alert alert-error" role="alert">{{this.error}}</p>{{/if}}
        <div class="control-group"><label for="svdex-company-name">{{if this.isFund "Fund name *" "Company or project name *"}}</label><input id="svdex-company-name" type="text" class="input-xxlarge" name="name" value={{this.name}} maxlength="120" required {{on "input" this.update}} /></div>
        <div class="control-group"><label for="svdex-company-representative">{{if this.isFund "Manager or authorized representative *" "Founder or authorized representative *"}}</label><input id="svdex-company-representative" type="text" class="input-xxlarge" name="representative" value={{this.representative}} maxlength="120" required {{on "input" this.update}} /></div>
        <div class="control-group"><label for="svdex-company-description">{{if this.isFund "What is the fund’s strategy? *" "What does the company or project do? *"}}</label><textarea id="svdex-company-description" name="description" value={{this.description}} maxlength="1200" required {{on "input" this.update}} /></div>
        <div class="control-group"><label for="svdex-company-website">Website (optional)</label><input id="svdex-company-website" class="input-xxlarge" name="website" value={{this.website}} maxlength="500" type="url" {{on "input" this.update}} /></div>
        <label class="checkbox-label"><input type="checkbox" name="authorized" checked={{this.authorized}} {{on "change" this.update}} /> {{if this.isFund "I am authorized to represent this fund. *" "I am authorized to represent this company or project. *"}}</label>
      </:body>
      <:footer><DButton @translatedLabel="Submit application" @action={{this.submit}} @disabled={{this.saving}} class="btn-primary" /><DModalCancel @close={{@closeModal}} /></:footer>
    </DModal>
  </template>
}

import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { hash } from "@ember/helper";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import { on } from "@ember/modifier";
import DModal from "discourse/ui-kit/d-modal";
import DButton from "discourse/ui-kit/d-button";

export default class CompanySearchModal extends Component {
  @tracked query = this.args.model.name || "";
  @action update(event) { this.query = event.target.value; }
  @action search(event) {
    event?.preventDefault();
    this.args.model._setUsernameFilter(this.query.trim());
    this.args.closeModal();
  }
  <template>
    <DModal @title={{@model.searchTitle}} @closeModal={{@closeModal}} class="svdex-company-search-modal">
      <:body>
        <form id="svdex-company-search" {{on "submit" this.search}}>
          <label for="svdex-company-search-input">{{@model.searchLabel}}</label>
          <DFilterInput id="svdex-company-search-input" @icons={{hash left="magnifying-glass"}} @value={{this.query}} @filterAction={{this.update}} />
        </form>
      </:body>
      <:footer><DButton @translatedLabel="Search" @action={{this.search}} class="btn-primary" /></:footer>
    </DModal>
  </template>
}

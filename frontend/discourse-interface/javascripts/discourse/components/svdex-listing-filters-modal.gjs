import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import DModal from "discourse/ui-kit/d-modal";
import DButton from "discourse/ui-kit/d-button";
import ListingTagGroupFilters from "./svdex-tag-group-filters.gjs";

export default class ListingFiltersModal extends Component {
  <template>
    <DModal @title="Filters" @closeModal={{@closeModal}} class="svdex-listing-filters-modal">
      <:body>
        <ul class="svdex-mobile-filter-fields">
          <ListingTagGroupFilters @panel={{true}} @outletArgs={{hash currentCategory=@model.category tag=@model.tag additionalTags=@model.additionalTags}} />
        </ul>
      </:body>
      <:footer>
        <DButton @translatedLabel="Done" @action={{@closeModal}} class="btn-primary" />
      </:footer>
    </DModal>
  </template>
}

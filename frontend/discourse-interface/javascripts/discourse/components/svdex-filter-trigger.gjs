import Component from "@glimmer/component";
import DButton from "discourse/ui-kit/d-button";

export default class FilterTrigger extends Component {
  get title() {
    if (!this.args.active) return "Filters";
    return this.args.count ? `Filters (${this.args.count} active)` : "Filters (active)";
  }
  <template>
    <DButton
      @icon={{if @compact "filter" "angle-right"}}
      @translatedLabel={{unless @compact "Filter"}}
      @translatedTitle={{this.title}}
      @translatedAriaLabel={{this.title}}
      @action={{@action}}
      class="btn-default svdex-filter-trigger {{if @active 'has-active-filters'}}"
    />
  </template>
}

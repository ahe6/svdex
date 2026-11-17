import Component from "@glimmer/component";
import DNavigationItem from "discourse/ui-kit/d-navigation-item";
import icon from "discourse/helpers/d-icon";
export default class DiscoveriesNav extends Component {
  <template>
    {{#if @outletArgs.model.svdex_discoveries.count}}
      <DNavigationItem @route="userActivity.discoveries" @ariaCurrentContext="subNav">{{icon "compass"}}<span>Discoveries</span></DNavigationItem>
    {{/if}}
  </template>
}

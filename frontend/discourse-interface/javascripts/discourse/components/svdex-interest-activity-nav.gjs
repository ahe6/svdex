import Component from "@glimmer/component";
import { service } from "@ember/service";
import DNavigationItem from "discourse/ui-kit/d-navigation-item";
import icon from "discourse/helpers/d-icon";

export default class InterestActivityNav extends Component {
  @service currentUser;
  get visible() { return this.currentUser && this.args.outletArgs.model.id === this.currentUser.id; }
  <template>
    {{#if this.visible}}<DNavigationItem @route="userActivity.interest" @ariaCurrentContext="subNav" class="user-nav__activity-interest">{{icon "list-check"}}<span>Interest &amp; bids</span></DNavigationItem>{{/if}}
  </template>
}

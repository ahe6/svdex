import Component from "@glimmer/component";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class InterestRowMenu extends Component {
  get label() { return `Withdraw ${this.args.row.side} interest`; }
  get title() { return `Actions for ${this.args.row.label.toLowerCase()} in ${this.args.row.organization.name}`; }
  @action registerMenu(api) { this.menu = api; }
  @action async withdraw() {
    await this.menu?.close();
    this.args.withdraw(this.args.row);
  }
  <template>
    <DMenu class="btn-flat svdex-interest-row-menu" @title={{this.title}} @onRegisterApi={{this.registerMenu}}>
      <:trigger>{{dIcon "ellipsis-vertical"}}</:trigger>
      <:content>
        <DDropdownMenu as |dropdown|>
          <dropdown.item><DButton @translatedLabel={{this.label}} @icon="xmark" @action={{this.withdraw}} /></dropdown.item>
        </DDropdownMenu>
      </:content>
    </DMenu>
  </template>
}

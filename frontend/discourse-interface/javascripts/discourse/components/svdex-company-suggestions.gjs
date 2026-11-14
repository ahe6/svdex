import Component from "@glimmer/component";
import { action } from "@ember/object";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";

export default class CompanySuggestions extends Component {
  @action selected(index) { return index === this.args.selectedIndex; }
  @action choose(result, index, event) {
    event.preventDefault();
    event.stopPropagation();
    this.args.onSelect(result, index, event);
  }
  <template>
    <div class="select-kit single-select combo-box tag-drop is-expanded svdex-company-suggestion-menu">
      <div class="select-kit-body">
      <ul class="select-kit-collection" id="svdex-company-suggestions" role="listbox" aria-label="Company suggestions">
        {{#each @results as |result index|}}
          <li class={{if (this.selected index) "select-kit-row is-highlighted" "select-kit-row"}}
            {{on "click" (fn this.choose result index)}}>
            <a href role="option" aria-selected={{this.selected index}}
              class={{if (this.selected index) "name selected" "name"}}
              >{{result.name}}</a>
          </li>
        {{/each}}
      </ul>
      </div>
    </div>
  </template>
}

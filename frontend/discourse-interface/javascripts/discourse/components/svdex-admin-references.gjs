import Component from "@glimmer/component";
import { action } from "@ember/object";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DButton from "discourse/ui-kit/d-button";
export default class AdminReferences extends Component {
  get entries() { return this.args.entries || []; }
  @action change(index, field, event) { this.args.onChange(this.entries.map((entry, i) => i === index ? {...entry, [field]:event.target.value} : entry)); }
  @action add() { this.args.onChange([...this.entries, {name:"",role:"",url:""}]); }
  @action remove(index) { this.args.onChange(this.entries.filter((_entry, i) => i !== index)); }
  <template>
    {{#each this.entries as |entry index|}}
      <fieldset class="svdex-admin-reference">
        <label>Name<input type="text" maxlength="120" value={{entry.name}} {{on "input" (fn this.change index "name")}} /></label>
        <label>Role<input type="text" maxlength="120" value={{entry.role}} {{on "input" (fn this.change index "role")}} /></label>
        <label>Public professional or entity URL<input type="url" value={{entry.url}} {{on "input" (fn this.change index "url")}} /></label>
        <label>Confirmed SVDEX account ID (optional)<input type="number" min="1" step="1" value={{entry.user_id}} {{on "input" (fn this.change index "user_id")}} /></label>
        <DButton @translatedLabel="Remove" @action={{fn this.remove index}} />
      </fieldset>
    {{/each}}
    <DButton @translatedLabel={{@addLabel}} @action={{this.add}} />
  </template>
}

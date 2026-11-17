import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { PRESALE_FIELDS, isPresaleCategory } from "../lib/svdex-presales";
export default class PresaleFields extends Component {
  @service siteSettings;
  get model() { return this.args.outletArgs.model; }
  get visible() { return this.model.topicFirstPost && !this.model.privateMessage && isPresaleCategory(this.model.categoryId, this.siteSettings); }
  get fields() { return PRESALE_FIELDS.map(field => ({ ...field, value: this.model[`svdex_presale_${field.key}`] ?? this.model.topic?.svdex_presale?.[field.key] ?? "" })); }
  @action update(key, event) { this.model.set(`svdex_presale_${key}`, event.target.value); this.model.notifyPropertyChange("reply"); }
  <template>
    {{#if this.visible}}
      <details class="svdex-composer-details" open>
        <summary>Pre-sale details</summary>
        <fieldset class="svdex-composer-fields"><legend class="sr-only">Pre-sale details</legend>
          {{#each this.fields as |field|}}
            <label class="svdex-field"><span>{{field.name}}</span><input value={{field.value}} maxlength={{field.max}} placeholder={{field.hint}} {{on "input" (fn this.update field.key)}} /></label>
          {{/each}}
        </fieldset>
      </details>
    {{/if}}
  </template>
}

import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { fn, hash } from "@ember/helper";
import TopicChooser from "discourse/select-kit/components/topic-chooser";
import { escapeExpression } from "discourse/lib/utilities";
import { PRESALE_FIELDS, isPresaleCategory } from "../lib/svdex-presales";
export default class PresaleFields extends Component {
  @service siteSettings;
  get model() { return this.args.outletArgs.model; }
  get visible() { return this.model.topicFirstPost && !this.model.privateMessage && isPresaleCategory(this.model.categoryId, this.siteSettings); }
  get needsProduct() { return !this.model.topic?.svdex_presale?.product_id; }
  get productId() { return Number(this.model.svdex_presale_product_id ?? this.model.topic?.svdex_presale?.product_id) || null; }
  get productChoices() {
    if (!this.productId) return [];
    const title = this.model.svdex_presale_product_title ?? this.model.topic?.svdex_presale?.product_title;
    return [{ id: this.productId, title, fancy_title: escapeExpression(title) }];
  }
  get productSearch() { return `category:=${this.siteSettings.svdex_products_category_id} status:public`; }

  @action chooseProduct(id, product) {
    this.model.set("svdex_presale_product_id", id == null ? "" : String(id));
    this.model.set("svdex_presale_product_title", product?.title ?? "");
    this.model.notifyPropertyChange("reply");
  }

  get fields() { return PRESALE_FIELDS.map(field => ({ ...field, value: this.model[`svdex_presale_${field.key}`] ?? this.model.topic?.svdex_presale?.[field.key] ?? "" })); }
  @action update(key, event) { this.model.set(`svdex_presale_${key}`, event.target.value); this.model.notifyPropertyChange("reply"); }
  <template>
    {{#if this.visible}}
      <details class="svdex-composer-details" open={{this.needsProduct}}>
        <summary>Pre-sale details</summary>
        <fieldset class="svdex-composer-fields svdex-presale-fields"><legend class="sr-only">Pre-sale details</legend>
          <div class="svdex-field">
            <span>Product</span>
            <TopicChooser
              @content={{this.productChoices}}
              @onChange={{this.chooseProduct}}
              @options={{hash additionalFilters=this.productSearch none="svdex.presale.choose_product" clearable=false}}
              @value={{this.productId}}
            />
          </div>
          {{#each this.fields as |field|}}
            <label class="svdex-field"><span>{{field.name}}</span><input type="text" value={{field.value}} maxlength={{field.max}} placeholder={{field.hint}} {{on "input" (fn this.update field.key)}} /></label>
          {{/each}}
        </fieldset>
      </details>
    {{/if}}
  </template>
}

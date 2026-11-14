import Component from "@glimmer/component";
import { action } from "@ember/object";
import { hash } from "@ember/helper";
import ComboBox from "discourse/select-kit/components/combo-box";

const OPTIONS = [
  { id: "svdex_total_funding:desc", name: "Total funding: highest first", field: "svdex_total_funding", asc: null },
  { id: "svdex_total_funding:asc", name: "Total funding: lowest first", field: "svdex_total_funding", asc: true },
  { id: "svdex_last_valuation:desc", name: "Last valuation: highest first", field: "svdex_last_valuation", asc: null },
  { id: "svdex_last_valuation:asc", name: "Last valuation: lowest first", field: "svdex_last_valuation", asc: true },
  { id: "username:asc", name: "Name: A–Z", field: "username", asc: true },
  { id: "username:desc", name: "Name: Z–A", field: "username", asc: null },
];

export default class CompanySort extends Component {
  get options() { return this.args.kind === "funds" ? [
    { id:"svdex_aum:desc", name:"AUM: highest first", field:"svdex_aum", asc:null },
    { id:"svdex_aum:asc", name:"AUM: lowest first", field:"svdex_aum", asc:true },
    ...OPTIONS.filter(option => option.field === "username"),
  ] : OPTIONS; }
  get value() { return `${this.args.order || "svdex_total_funding"}:${this.args.asc ? "asc" : "desc"}`; }
  @action changeSort(value) {
    const option = this.options.find(item => item.id === value);
    if (option) this.args.onChange(option.field, option.asc);
  }
  <template>
    <div class="svdex-company-sort-control">
      <span class="svdex-company-sort-label">Sort by</span>
      <ComboBox @content={{this.options}} @value={{this.value}} @onChange={{this.changeSort}}
        @options={{hash filterable=false headerAriaLabel="Sort listings"}} />
    </div>
  </template>
}

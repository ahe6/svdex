import Component from "@glimmer/component";
export default class OrganizationReferences extends Component {
  get entries() { return this.args.limit ? (this.args.entries || []).slice(0, this.args.limit) : this.args.entries; }
  get extra() { return Math.max(0, (this.args.entries?.length || 0) - (this.args.limit || Infinity)); }
  <template>
    {{#each this.entries as |entry|}}
      <span class="svdex-organization-reference">{{#if entry.url}}<a href={{entry.url}}>{{entry.name}}</a>{{else}}{{entry.name}}{{/if}} <span class="svdex-organization-reference__role">({{entry.role}})</span></span>
    {{else}}—{{/each}}
    {{#if this.extra}}<a href={{@profileUrl}}>+{{this.extra}}</a>{{/if}}
  </template>
}

import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { avatarImg } from "discourse/lib/avatar-utils";
export function profileLogo(profile) { return trustHTML(avatarImg({ size: "large", avatarTemplate: profile.logo_template, alt: "", title: profile.name })); }
export default class ProfileIdentity extends Component {
  <template>
    <div class="user-info small svdex-person-named">
      <div class="user-image"><div class="user-image-inner"><a aria-hidden="true" href={{@profile.url}}>{{profileLogo @profile}}</a></div></div>
      <div class="user-detail"><div class="name-line"><span class="name-wrapper"><a href={{@profile.url}} aria-level="3" role="heading"><span class="name">{{@profile.name}}</span></a></span><span class="svdex-company-summary" title={{@profile.summary}}>{{@profile.summary}}</span></div><div class="title"></div></div>
    </div>
  </template>
}

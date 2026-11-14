import NativeUserSummary from "discourse/templates/user/summary";
import bodyClass from "discourse/helpers/body-class";
import CompanyProfileSummary from "../components/svdex-company-profile-summary.gjs";
export default <template>
  {{#if @controller.user.svdex_company_account}}
    {{bodyClass "user-summary-page"}}
    <div class="user-content" id="user-content"><CompanyProfileSummary @user={{@controller.user}} /></div>
  {{else}}
    <NativeUserSummary @controller={{@controller}} />
  {{/if}}
</template>;

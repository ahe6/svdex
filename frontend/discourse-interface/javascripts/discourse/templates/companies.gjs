import { action } from "@ember/object";
import CompanyApplication from "../components/svdex-company-application.gjs";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import { service } from "@ember/service";
import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import DirectoryTable from "../components/svdex-companies-table.gjs";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import lazyHash from "discourse/helpers/lazy-hash";
import withEventValue from "discourse/helpers/with-event-value";
import ComboBox from "discourse/select-kit/components/combo-box";
import CompanyMobileControls from "../components/svdex-company-mobile-controls.gjs";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import DLoadMore from "discourse/ui-kit/d-load-more";
import { i18n } from "discourse-i18n";

class CompanyApplicationLink extends Component {
  @service siteSettings;
  @service currentUser;
  @service store;
  @service modal;
  get isFund() { return this.args.kind === "funds"; }
  @action async open() {
    const name = this.siteSettings.svdex_companies_group_name;
    if (this.currentUser?.staff) return DiscourseURL.routeTo(`/g/${encodeURIComponent(name)}/requests`);
    if (!this.currentUser) return DiscourseURL.routeTo("/login");
    try {
      const group = await this.store.find("group", name);
      if (group.is_group_user) return DiscourseURL.routeTo(`/u/${this.currentUser.username}/summary`);
      this.modal.show(CompanyApplication, { model: { group, kind: this.args.kind } });
    } catch (error) { popupAjaxError(error); }
  }
  <template><DButton @action={{this.open}} @icon="far-pen-to-square" @translatedLabel={{if this.isFund "New fund" "New company"}} class="btn-primary svdex-company-application" /></template>
}

export default <template>
  {{#if @controller.model.canLoadMore}}
    {{hideApplicationFooter}}
  {{/if}}

  {{bodyClass "users-page svdex-companies-page"}}
  <section>
    <DLoadMore
      @action={{@controller.loadMore}}
      @enabled={{@controller.model.canLoadMore}}
      @isLoading={{@controller.isLoading}}
    >
      <div class="container">
        <div class="users-directory directory">
          <span>
            <PluginOutlet
              @connectorTagName="div"
              @name="users-top"
              @outletArgs={{lazyHash model=@controller.model}}
            />
          </span>
          <div class="directory-controls">
            <div class="period-controls">
              <h2>{{if @controller.isFund "Funds" "Companies"}}</h2>
              {{#if @controller.lastUpdatedAt}}
                <div class="directory-last-updated">
                  {{i18n "directory.last_updated"}}
                  {{@controller.lastUpdatedAt}}
                </div>
              {{/if}}
            </div>
            <div class="svdex-company-directory-tools">
            <div class="inline-form">
              <label class="total-rows">
                {{#if @controller.model.totalRows}}
                  {{i18n
                    @controller.countKey
                    count=@controller.model.totalRows
                  }}
                {{/if}}
              </label>
              <Input
                class="filter-name no-blur"
                placeholder={{@controller.searchLabel}}
                @value={{readonly @controller.nameInput}}
                {{on
                  "input"
                  (withEventValue @controller.onUsernameFilterChanged)
                }}
              />
              {{#if @controller.showGroupFilter}}
                <ComboBox
                  class="directory-group-selector"
                  @content={{@controller.groupOptions}}
                  @onChange={{@controller.groupChanged}}
                  @options={{hash none="directory.group.all"}}
                  @value={{@controller.group}}
                />
              {{/if}}
              <CompanyMobileControls @controller={{@controller}} />
              <PluginOutlet
                @name="users-directory-controls"
                @outletArgs={{lazyHash model=@controller.model}}
              />
            </div>
            <CompanyApplicationLink @kind={{if @controller.isFund "funds" "companies"}} />
            </div>
          </div>

          <DConditionalLoadingSpinner @condition={{@controller.isLoading}}>
            {{#if @controller.model.content}}
              <DirectoryTable
                @controller={{@controller}}
                @identityKey={{@controller.identityKey}}
                @referenceColumns={{@controller.columns}}
                @asc={{@controller.asc}}
                @items={{@controller.model.content}}
                @order={{@controller.order}}
                @updateOrderAndAsc={{@controller.updateOrderAndAsc}}
              />
              <DConditionalLoadingSpinner
                @condition={{@controller.model.loadingMore}}
              />
            {{else}}
              <DEmptyState @body={{@controller.emptyMessage}} />
              {{#if @controller.hasCompanyFilters}}
                <DButton @translatedLabel="Clear filters" @action={{@controller.clearCompanyFilters}} />
              {{/if}}
            {{/if}}
          </DConditionalLoadingSpinner>
        </div>
      </div>
    </DLoadMore>
  </section>
</template>

import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import PeopleFilters from "../components/svdex-people-filters.gjs";
import PeopleTable from "../components/svdex-people-table.gjs";
import bodyClass from "discourse/helpers/body-class";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import withEventValue from "discourse/helpers/with-event-value";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import DLoadMore from "discourse/ui-kit/d-load-more";

export default <template>
  {{bodyClass "users-page svdex-people-page"}}
  {{#if @controller.model.canLoadMore}}{{hideApplicationFooter}}{{/if}}
  <section>
    <DLoadMore @action={{@controller.loadMore}} @enabled={{@controller.model.canLoadMore}} @isLoading={{@controller.isLoading}}>
      <div class="container">
        <div class="users-directory directory">
          <div class="directory-controls">
            <div class="period-controls"><h2>People</h2></div>
            <div class="inline-form">
              <label class="total-rows">{{@controller.peopleCount}}</label>
              <Input class="filter-name no-blur" placeholder="Search by name" @value={{readonly @controller.nameInput}}
                {{on "input" (withEventValue @controller.onUsernameFilterChanged)}} />
              <PeopleFilters @controller={{@controller}} />
            </div>
          </div>
          <DConditionalLoadingSpinner @condition={{@controller.isLoading}}>
            {{#if @controller.model.content}}
              <PeopleTable @asc={{@controller.asc}} @items={{@controller.model.content}}
                @order={{@controller.order}} @updateOrderAndAsc={{@controller.updateOrderAndAsc}} />
              <DConditionalLoadingSpinner @condition={{@controller.model.loadingMore}} />
            {{else}}
              <DEmptyState @body="No people found." />
            {{/if}}
          </DConditionalLoadingSpinner>
        </div>
      </div>
    </DLoadMore>
  </section>
</template>

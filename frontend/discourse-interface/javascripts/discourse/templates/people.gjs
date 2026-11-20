import { hash } from "@ember/helper";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import PeopleFilters from "../components/svdex-people-filters.gjs";
import PeopleTable from "../components/svdex-people-table.gjs";
import CatalogProposalAction from "../components/svdex-catalog-proposal.gjs";
import AddPerson from "../components/svdex-add-person.gjs";
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
            <div class="period-controls">
              <h2>People</h2>
              <span class="svdex-directory-heading-count">
                <span aria-hidden="true">{{or @controller.model.totalRows 0}}</span>
                <span class="sr-only">{{@controller.peopleCount}}</span>
              </span>
            </div>
            <div class="inline-form">
              <DFilterInput
                @containerClass="filter-name svdex-directory-search"
                @icons={{hash left="magnifying-glass"}}
                @value={{@controller.nameInput}}
                @filterAction={{withEventValue @controller.onUsernameFilterChanged}}
                class="no-blur"
                placeholder="Search by name"
                aria-label="Search by name"
              />
              <PeopleFilters @controller={{@controller}} />
              <CatalogProposalAction @kind="people"><AddPerson /></CatalogProposalAction>
            </div>
          </div>
          <DConditionalLoadingSpinner @condition={{@controller.isLoading}}>
            {{#if @controller.model.content}}
              <PeopleTable @controller={{@controller}} @items={{@controller.model.content}} />
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

import Layout from "discourse/components/discovery/layout";
import Navigation from "discourse/components/discovery/navigation";
import OverviewDirectory from "../../components/svdex-overview-directory.gjs";
import bodyClass from "discourse/helpers/body-class";

export default <template>
  <Layout @listClass="--categories" @model={{@controller.model}}>
    <:navigation>
      <Navigation @canCreateTopic={{@controller.model.can_create_topic}}
        @category={{@controller.discussionCategory}} @createTopic={{@controller.createTopic}}
        @filterType="categories" />
    </:navigation>
    <:list>
      {{bodyClass "svdex-directory-page categories-list svdex-discussion-forums"}}
      <OverviewDirectory @categories={{@controller.directoryCategories}} />
    </:list>
  </Layout>
</template>;

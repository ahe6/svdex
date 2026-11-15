import Layout from "discourse/components/discovery/layout";
import Navigation from "discourse/components/discovery/navigation";
import bodyClass from "discourse/helpers/body-class";
import OverviewDirectory from "../../components/svdex-overview-directory.gjs";

export default <template>
  <Layout @listClass="--categories" @model={{@controller.model}}>
    <:navigation>
      <Navigation @canCreateTopic={{@controller.model.can_create_topic}}
        @category={{@controller.model.parentCategory}} @createTopic={{@controller.createTopic}}
        @filterType="categories" />
    </:navigation>
    <:list>
      {{bodyClass "svdex-directory-page categories-list"}}
      <OverviewDirectory @categories={{@controller.directoryCategories}} />
    </:list>
  </Layout>
</template>;

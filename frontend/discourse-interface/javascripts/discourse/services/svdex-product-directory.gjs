import Service from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class ProductDirectoryMetadata extends Service {
  @tracked categories = [];
  @tracked total = null;
  @tracked scope;
}

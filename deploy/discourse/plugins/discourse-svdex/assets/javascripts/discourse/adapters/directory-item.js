import RestAdapter from "discourse/adapters/rest";

export default class DirectoryItemAdapter extends RestAdapter {
  pathFor(store, type, findArgs) {
    if (findArgs?.svdex_company_directory) {
      const { svdex_company_directory, ...params } = findArgs;
      return this.appendQueryParams("/listings/company-directory.json", params);
    }
    return super.pathFor(...arguments);
  }
}

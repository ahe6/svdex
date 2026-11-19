import ComboBox from "discourse/select-kit/components/combo-box";
import { ajax } from "discourse/lib/ajax";

// Native SelectKit owns async search, loading, filtering and keyboard selection.
export default class InterestOrganizationSelect extends ComboBox {
  async search(filter) {
    if (this.independent) {
      const data = await ajax("/company-profiles.json", { data: { name: filter, kind: this.kind, order: "username", asc: true } });
      return data.profiles.map(({profile}) => ({ id: profile.id, name: profile.name, endpoint: `/company-profile-interests/${profile.id}` }));
    }
    const data = await ajax("/listings/company-directory.json", { data: { name: filter, kind: this.kind, order: "username", asc: true } });
    return data.directory_items.map(({user}) => ({ id: user.id, name: user.name || user.username }));
  }
}

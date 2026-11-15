import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { InterestModal } from "../../components/svdex-interest.gjs";
import OfferingBidModal from "../../components/svdex-offering-bid.gjs";

export default class InterestController extends Controller {
  @service modal;
  @service dialog;
  queryParams = [];
  @tracked kind = "all";
  @tracked status = "all";
  @tracked records = [];
  @tracked hasMore = false;
  @tracked page = 0;
  @tracked loading = false;
  kinds = [{ id: "all", name: "All submissions" }, { id: "interest", name: "Interest" }, { id: "bid", name: "Bids" }];
  statuses = [{ id: "all", name: "All statuses" }, { id: "current", name: "Current" }, { id: "expired", name: "Expired" }, { id: "withdrawn", name: "Withdrawn" }];
  get filtered() { return this.kind !== "all" || this.status !== "all"; }
  get rows() {
    return this.records.map(row => ({ ...row,
      title: row.topic?.title || row.organization?.name || (row.kind === "bid" ? "Unavailable offering" : "Unavailable company or fund"),
      url: row.topic?.url || row.organization?.url,
      label: row.kind === "bid" ? "Bid" : row.side === "sell" ? "Sell interest" : "Buy interest",
      amount: new Intl.NumberFormat(undefined, { style: "currency", currency: row.currency, minimumFractionDigits: 0, maximumFractionDigits: 2 }).format(row.amount_cents / 100),
      state: row.status.charAt(0).toUpperCase() + row.status.slice(1),
      editLabel: row.status === "current" ? "Edit" : "Resubmit",
      canWithdraw: row.status !== "withdrawn",
      date: new Date(row.updated_at).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" }),
    }));
  }
  @action changeKind(value) { this.kind = value; }
  @action changeStatus(value) { this.status = value; }
  @action clearFilters() { this.kind = "all"; this.status = "all"; }
  @action async loadMore() {
    if (this.loading || !this.hasMore) return;
    this.loading = true;
    const kind = this.kind, status = this.status, page = this.page;
    try {
      const data = await ajax("/listings/my-interest.json", { data: { kind, status, page: page + 1 } });
      if (kind !== this.kind || status !== this.status || page !== this.page) return;
      this.records = [...this.records, ...data.records]; this.page++; this.hasMore = data.has_more;
    } catch (error) { popupAjaxError(error); }
    finally { this.loading = false; }
  }
  @action async reload() {
    const data = await ajax("/listings/my-interest.json", { data: { kind: this.kind, status: this.status } });
    this.records = data.records; this.page = 0; this.hasMore = data.has_more;
  }
  @action edit(row) {
    if (!row.can_edit) return;
    const model = { organizationId: row.organization.id, organizationName: row.organization.name, side: row.side,
      topicId: row.topic?.id, topicTitle: row.topic?.title, onChange: this.reload };
    this.modal.show(row.kind === "bid" ? OfferingBidModal : InterestModal, { model });
  }
  @action withdraw(row) {
    this.dialog.confirm({ message: `Withdraw your ${row.label.toLowerCase()} ${row.kind === "bid" ? "for" : "in"} ${row.kind === "bid" ? row.title : row.organization.name}?`, didConfirm: async () => {
      try { await ajax(`/listings/my-interest/${row.kind}/${row.id}.json`, { type: "DELETE" }); await this.reload(); }
      catch (error) { popupAjaxError(error); }
    } });
  }
}

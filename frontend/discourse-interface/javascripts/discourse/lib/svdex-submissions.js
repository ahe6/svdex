export function submissionLabel(row) {
  return row.kind === "bid" ? "Bid" : row.side === "sell" ? "Sell interest" : "Buy interest";
}

export function withdrawalMessage(row) {
  const label = submissionLabel(row).toLowerCase();
  // Inaccessible sources are deliberately absent from the owner-history API.
  // Withdrawal must still work, without reconstructing a redacted identity.
  const target = row.kind === "bid" ? row.topic?.title : row.organization?.name;
  return target ? `Withdraw your ${label} ${row.kind === "bid" ? "for" : "in"} ${target}?` : `Withdraw this ${label}?`;
}

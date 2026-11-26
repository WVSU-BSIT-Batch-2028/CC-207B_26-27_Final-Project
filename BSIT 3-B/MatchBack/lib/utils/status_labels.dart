/// Wording shown to people for each claim status.
String claimStatusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Pending Review';
    case 'approved':
      return 'Approved';
    case 'ready':
      return 'Ready for Collection';
    case 'returned':
      return 'Returned to Owner';
    case 'rejected':
      return 'Rejected';
    default:
      return status;
  }
}

/// Wording shown to people for each item status. "claimed" is the old status
/// from before this workflow existed, so old records still display sensibly.
String itemStatusLabel(String status) {
  switch (status) {
    case 'lost':
      return 'Lost';
    case 'found':
      return 'Found';
    case 'claim_pending':
      return 'Claim Pending';
    case 'claimed':
      return 'Claim Approved';
    case 'ready':
      return 'Ready for Collection';
    case 'returned':
      return 'Returned to Owner';
    default:
      return status;
  }
}

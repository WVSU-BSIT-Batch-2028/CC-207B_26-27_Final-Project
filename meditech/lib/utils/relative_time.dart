String relativeTimeAgo(DateTime? when, {DateTime? now}) {
  if (when == null) return 'Not updated yet';
  final anchor = now ?? DateTime.now();
  final diff = anchor.difference(when);
  if (diff.inDays >= 365) {
    final years = (diff.inDays / 365).floor();
    return years == 1 ? 'Last updated 1 year ago' : 'Last updated $years years ago';
  }
  if (diff.inDays >= 30) {
    final months = (diff.inDays / 30).floor();
    return months == 1 ? 'Last updated 1 month ago' : 'Last updated $months months ago';
  }
  if (diff.inDays >= 1) {
    return diff.inDays == 1
        ? 'Last updated 1 day ago'
        : 'Last updated ${diff.inDays} days ago';
  }
  if (diff.inHours >= 1) {
    return diff.inHours == 1
        ? 'Last updated 1 hour ago'
        : 'Last updated ${diff.inHours} hours ago';
  }
  return 'Updated recently';
}
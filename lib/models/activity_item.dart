class ActivityItem {
  final String id;
  final String itemId;
  final String itemName;
  final String category;
  final int quantity;
  final String icon;
  final String? photoUrl;
  final String? qrCode;
  final bool addedDuringActivity;
  final DateTime? createdAt;

  const ActivityItem({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.icon,
    this.photoUrl,
    this.qrCode,
    required this.addedDuringActivity,
    this.createdAt,
  });

  bool get hasQr {
    return qrCode != null && qrCode!.isNotEmpty;
  }
}

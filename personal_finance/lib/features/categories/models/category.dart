class Category {
  final String id;
  final String name;
  final String transactionType; // 'expense' or 'income'
  final String iconKey;
  final String colorKey;
  final bool isDefault;
  final bool isArchived;

  Category({
    required this.id,
    required this.name,
    required this.transactionType,
    required this.iconKey,
    required this.colorKey,
    this.isDefault = false,
    this.isArchived = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'transaction_type': transactionType,
      'icon_key': iconKey,
      'color_key': colorKey,
      'is_default': isDefault ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      transactionType: map['transaction_type'] as String,
      iconKey: map['icon_key'] as String,
      colorKey: map['color_key'] as String,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
    );
  }
}

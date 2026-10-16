class Account {
  final String id;
  final String name;
  final String accountType; // cash, bank, mobile_money, savings, custom
  final String currencyCode;
  final int openingBalance; // in cents
  final int? lastConfirmedBalance; // bank-reported snapshot in cents
  final DateTime? lastConfirmedAt; // timestamp of confirmed snapshot
  final bool hasConfirmedStartingBalance; // baseline established
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  Account({
    required this.id,
    required this.name,
    required this.accountType,
    this.currencyCode = 'ETB',
    this.openingBalance = 0,
    this.lastConfirmedBalance,
    this.lastConfirmedAt,
    this.hasConfirmedStartingBalance = true,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'account_type': accountType,
      'currency_code': currencyCode,
      'opening_balance': openingBalance,
      'last_confirmed_balance': lastConfirmedBalance,
      'last_confirmed_at': lastConfirmedAt?.toIso8601String(),
      'has_confirmed_starting_balance': hasConfirmedStartingBalance ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as String,
      name: map['name'] as String,
      accountType: map['account_type'] as String,
      currencyCode: map['currency_code'] as String? ?? 'ETB',
      openingBalance: map['opening_balance'] as int? ?? 0,
      lastConfirmedBalance: map['last_confirmed_balance'] as int?,
      lastConfirmedAt: map['last_confirmed_at'] != null
          ? DateTime.parse(map['last_confirmed_at'] as String)
          : null,
      hasConfirmedStartingBalance:
          (map['has_confirmed_starting_balance'] as int? ?? 1) == 1,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Account copyWith({
    String? id,
    String? name,
    String? accountType,
    String? currencyCode,
    int? openingBalance,
    int? lastConfirmedBalance,
    DateTime? lastConfirmedAt,
    bool? hasConfirmedStartingBalance,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,
      currencyCode: currencyCode ?? this.currencyCode,
      openingBalance: openingBalance ?? this.openingBalance,
      lastConfirmedBalance: lastConfirmedBalance ?? this.lastConfirmedBalance,
      lastConfirmedAt: lastConfirmedAt ?? this.lastConfirmedAt,
      hasConfirmedStartingBalance:
          hasConfirmedStartingBalance ?? this.hasConfirmedStartingBalance,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum DebtType {
  iOwe,    // User owes money to someone (e.g. payable)
  owesMe,  // Someone owes money to user (e.g. receivable)
}

enum DebtStatus {
  unpaid,
  partial,
  settled,
}

class Debt {
  final String id;
  final String personName;
  final DebtType type;
  final int totalAmount; // cents
  final int settledAmount; // cents
  final DateTime? dueDate;
  final DateTime startDate;
  final String? linkedWalletId;
  final DebtStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Debt({
    required this.id,
    required this.personName,
    required this.type,
    required this.totalAmount,
    this.settledAmount = 0,
    this.dueDate,
    required this.startDate,
    this.linkedWalletId,
    this.status = DebtStatus.unpaid,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  int get remainingAmount => (totalAmount - settledAmount).clamp(0, totalAmount);

  double get progressPercentage {
    if (totalAmount <= 0) return 1.0;
    return (settledAmount / totalAmount).clamp(0.0, 1.0);
  }

  bool get isSettled => status == DebtStatus.settled || remainingAmount == 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'person_name': personName,
      'name': personName,
      'type': type == DebtType.iOwe ? 'I_OWE' : 'OWES_ME',
      'debt_type': type == DebtType.iOwe ? 'I_OWE' : 'OWES_ME',
      'total_amount': totalAmount,
      'settled_amount': settledAmount,
      'original_amount': totalAmount,
      'due_date': dueDate?.toIso8601String(),
      'start_date': startDate.toIso8601String(),
      'linked_wallet_id': linkedWalletId,
      'status': status.name.toUpperCase(),
      'notes': notes,
      'description': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Debt.fromMap(Map<String, dynamic> map) {
    final rawType = (map['type'] ?? map['debt_type'] ?? 'I_OWE').toString().toUpperCase();
    final debtType = (rawType == 'OWES_ME' || rawType == 'LENT' || rawType == 'RECEIVABLE')
        ? DebtType.owesMe
        : DebtType.iOwe;

    final rawStatus = (map['status'] ?? 'UNPAID').toString().toUpperCase();
    DebtStatus debtStatus;
    if (rawStatus == 'SETTLED' || rawStatus == 'PAID') {
      debtStatus = DebtStatus.settled;
    } else if (rawStatus == 'PARTIAL') {
      debtStatus = DebtStatus.partial;
    } else {
      debtStatus = DebtStatus.unpaid;
    }

    final total = (map['total_amount'] as int?) ?? (map['original_amount'] as int?) ?? 0;
    final settled = (map['settled_amount'] as int?) ?? 0;

    return Debt(
      id: map['id'] as String,
      personName: (map['person_name'] as String?) ?? (map['name'] as String?) ?? 'Unknown Person',
      type: debtType,
      totalAmount: total,
      settledAmount: settled,
      dueDate: map['due_date'] != null ? DateTime.tryParse(map['due_date'] as String) : null,
      startDate: map['start_date'] != null
          ? DateTime.tryParse(map['start_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      linkedWalletId: map['linked_wallet_id'] as String?,
      status: debtStatus,
      notes: (map['notes'] as String?) ?? (map['description'] as String?),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Debt copyWith({
    String? id,
    String? personName,
    DebtType? type,
    int? totalAmount,
    int? settledAmount,
    DateTime? dueDate,
    DateTime? startDate,
    String? linkedWalletId,
    DebtStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Debt(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      type: type ?? this.type,
      totalAmount: totalAmount ?? this.totalAmount,
      settledAmount: settledAmount ?? this.settledAmount,
      dueDate: dueDate ?? this.dueDate,
      startDate: startDate ?? this.startDate,
      linkedWalletId: linkedWalletId ?? this.linkedWalletId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

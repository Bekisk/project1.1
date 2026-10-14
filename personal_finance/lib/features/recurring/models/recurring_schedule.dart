enum RecurringFrequency {
  weekly,
  monthly,
  yearly,
}

class RecurringSchedule {
  final String id;
  final String name;
  final String type; // 'expense' or 'income'
  final int amount; // cents
  final String accountId;
  final String? categoryId;
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextOccurrence;
  final DateTime? lastProcessedDate;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringSchedule({
    required this.id,
    required this.name,
    this.type = 'expense',
    required this.amount,
    required this.accountId,
    this.categoryId,
    this.frequency = RecurringFrequency.monthly,
    required this.startDate,
    this.endDate,
    required this.nextOccurrence,
    this.lastProcessedDate,
    this.isActive = true,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Monthly normalized amount in cents for fixed commitments summary calculation
  int get monthlyCostCents {
    if (!isActive || type != 'expense') return 0;
    switch (frequency) {
      case RecurringFrequency.weekly:
        return (amount * 52 / 12).round();
      case RecurringFrequency.monthly:
        return amount;
      case RecurringFrequency.yearly:
        return (amount / 12).round();
    }
  }

  String get frequencyLabel {
    switch (frequency) {
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.monthly:
        return 'Monthly';
      case RecurringFrequency.yearly:
        return 'Yearly';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'amount': amount,
      'account_id': accountId,
      'category_id': categoryId,
      'frequency': frequency.name,
      'interval_type': frequency == RecurringFrequency.weekly
          ? 'week'
          : frequency == RecurringFrequency.yearly
              ? 'year'
              : 'month',
      'interval_value': 1,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'next_occurrence': nextOccurrence.toIso8601String(),
      'last_processed_date': lastProcessedDate?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'is_enabled': isActive ? 1 : 0,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory RecurringSchedule.fromMap(Map<String, dynamic> map) {
    final rawFreq = (map['frequency'] ?? map['interval_type'] ?? 'monthly').toString().toLowerCase();
    RecurringFrequency freq;
    if (rawFreq.contains('week')) {
      freq = RecurringFrequency.weekly;
    } else if (rawFreq.contains('year')) {
      freq = RecurringFrequency.yearly;
    } else {
      freq = RecurringFrequency.monthly;
    }

    final activeVal = map['is_active'] ?? map['is_enabled'] ?? 1;
    final isActive = (activeVal is int && activeVal == 1) || (activeVal is bool && activeVal);

    return RecurringSchedule(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? 'Subscription',
      type: (map['type'] as String?) ?? 'expense',
      amount: (map['amount'] as int?) ?? 0,
      accountId: (map['account_id'] as String?) ?? '',
      categoryId: map['category_id'] as String?,
      frequency: freq,
      startDate: map['start_date'] != null
          ? DateTime.tryParse(map['start_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      endDate: map['end_date'] != null ? DateTime.tryParse(map['end_date'] as String) : null,
      nextOccurrence: map['next_occurrence'] != null
          ? DateTime.tryParse(map['next_occurrence'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastProcessedDate: map['last_processed_date'] != null
          ? DateTime.tryParse(map['last_processed_date'] as String)
          : null,
      isActive: isActive,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  RecurringSchedule copyWith({
    String? id,
    String? name,
    String? type,
    int? amount,
    String? accountId,
    String? categoryId,
    RecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nextOccurrence,
    DateTime? lastProcessedDate,
    bool? isActive,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringSchedule(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      nextOccurrence: nextOccurrence ?? this.nextOccurrence,
      lastProcessedDate: lastProcessedDate ?? this.lastProcessedDate,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

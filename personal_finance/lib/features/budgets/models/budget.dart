enum BudgetType { category, overall, customPeriod }

enum BudgetFrequency { weekly, monthly, yearly, custom }

class Budget {
  final String id;
  final String name;
  final BudgetType budgetType;
  final String? categoryId;
  final int amount; // in cents
  final DateTime periodStart;
  final DateTime periodEnd;
  final BudgetFrequency frequency;
  final String? accountId;
  final double warningThreshold; // e.g. 0.8 = 80%
  final bool isArchived;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Budget({
    required this.id,
    required this.name,
    this.budgetType = BudgetType.category,
    this.categoryId,
    required this.amount,
    required this.periodStart,
    required this.periodEnd,
    this.frequency = BudgetFrequency.monthly,
    this.accountId,
    this.warningThreshold = 0.8,
    this.isArchived = false,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'budget_type': budgetType.name,
      'category_id': categoryId,
      'amount': amount,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
      'frequency': frequency.name,
      'account_id': accountId,
      'warning_threshold': warningThreshold,
      'is_archived': isArchived ? 1 : 0,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Budget',
      budgetType: BudgetType.values.firstWhere(
        (e) => e.name == map['budget_type'],
        orElse: () => map['category_id'] != null
            ? BudgetType.category
            : BudgetType.overall,
      ),
      categoryId: map['category_id'] as String?,
      amount: map['amount'] as int,
      periodStart: DateTime.parse(map['period_start'] as String),
      periodEnd: DateTime.parse(map['period_end'] as String),
      frequency: BudgetFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => BudgetFrequency.monthly,
      ),
      accountId: map['account_id'] as String?,
      warningThreshold: (map['warning_threshold'] as num?)?.toDouble() ?? 0.8,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Budget copyWith({
    String? id,
    String? name,
    BudgetType? budgetType,
    String? categoryId,
    bool clearCategoryId = false,
    int? amount,
    DateTime? periodStart,
    DateTime? periodEnd,
    BudgetFrequency? frequency,
    String? accountId,
    bool clearAccountId = false,
    double? warningThreshold,
    bool? isArchived,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      name: name ?? this.name,
      budgetType: budgetType ?? this.budgetType,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      amount: amount ?? this.amount,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      frequency: frequency ?? this.frequency,
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      warningThreshold: warningThreshold ?? this.warningThreshold,
      isArchived: isArchived ?? this.isArchived,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

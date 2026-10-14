enum TransactionType { income, expense, transfer }

class FinancialTransaction {
  final String id;
  final String accountId;
  final String? destinationAccountId;
  final TransactionType type;
  final int amount; // in cents
  final String? categoryId;
  final String description;
  final String? notes;
  final DateTime transactionDate;
  final String? recurringScheduleId;
  final DateTime createdAt;
  final DateTime updatedAt;

  FinancialTransaction({
    required this.id,
    required this.accountId,
    this.destinationAccountId,
    required this.type,
    required this.amount,
    this.categoryId,
    required this.description,
    this.notes,
    required this.transactionDate,
    this.recurringScheduleId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'destination_account_id': destinationAccountId,
      'type': type.name,
      'amount': amount,
      'category_id': categoryId,
      'description': description,
      'notes': notes,
      'transaction_date': transactionDate.toIso8601String(),
      'recurring_schedule_id': recurringScheduleId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory FinancialTransaction.fromMap(Map<String, dynamic> map) {
    return FinancialTransaction(
      id: map['id'] as String,
      accountId: map['account_id'] as String,
      destinationAccountId: map['destination_account_id'] as String?,
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      amount: map['amount'] as int,
      categoryId: map['category_id'] as String?,
      description: map['description'] as String,
      notes: map['notes'] as String?,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      recurringScheduleId: map['recurring_schedule_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

enum ContributionMode {
  manual,
  accountTransfer,
}

class GoalContribution {
  final String id;
  final String goalId;
  final int amount; // in cents
  final DateTime contributionDate;
  final ContributionMode mode; // manual (earmark only) or accountTransfer (real transfer)
  final String? sourceAccountId;
  final String? destinationAccountId;
  final String? transferTransactionId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  GoalContribution({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.contributionDate,
    required this.mode,
    this.sourceAccountId,
    this.destinationAccountId,
    this.transferTransactionId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goal_id': goalId,
      'amount': amount,
      'contribution_date': contributionDate.toIso8601String(),
      'mode': mode == ContributionMode.accountTransfer ? 'account_transfer' : 'manual',
      'source_account_id': sourceAccountId,
      'destination_account_id': destinationAccountId,
      'transfer_transaction_id': transferTransactionId,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory GoalContribution.fromMap(Map<String, dynamic> map) {
    final modeStr = map['mode'] as String? ?? 'manual';
    return GoalContribution(
      id: map['id'] as String,
      goalId: map['goal_id'] as String,
      amount: map['amount'] as int,
      contributionDate: DateTime.parse(map['contribution_date'] as String),
      mode: modeStr == 'account_transfer'
          ? ContributionMode.accountTransfer
          : ContributionMode.manual,
      sourceAccountId: map['source_account_id'] as String?,
      destinationAccountId: map['destination_account_id'] as String?,
      transferTransactionId: map['transfer_transaction_id'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  GoalContribution copyWith({
    String? id,
    String? goalId,
    int? amount,
    DateTime? contributionDate,
    ContributionMode? mode,
    String? sourceAccountId,
    String? destinationAccountId,
    String? transferTransactionId,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GoalContribution(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      amount: amount ?? this.amount,
      contributionDate: contributionDate ?? this.contributionDate,
      mode: mode ?? this.mode,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      transferTransactionId: transferTransactionId ?? this.transferTransactionId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

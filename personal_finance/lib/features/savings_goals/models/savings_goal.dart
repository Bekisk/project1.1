enum GoalStatus {
  active,
  completed,
  paused,
  archived,
}

enum GoalPriority {
  low,
  medium,
  high,
}

enum ContributionPlanFrequency {
  weekly,
  monthly,
  custom,
}

class SavingsGoal {
  final String id;
  final String name;
  final int targetAmount; // in cents (e.g. 40,000 ETB = 4,000,000 cents)
  final DateTime? targetDate;
  final String? description;
  final String category; // 'Emergency Fund', 'Education', 'Technology', 'Business', 'Travel', 'Housing', 'Personal', 'General Savings', 'Other'
  final String iconKey; // 'emergency', 'school', 'laptop', 'business', 'flight', 'home', 'person', 'savings'
  final GoalStatus status; // active, completed, paused, archived
  final GoalPriority priority; // low, medium, high
  final String? linkedAccountId;
  final ContributionPlanFrequency? planFrequency;
  final int? plannedPeriodicAmount; // in cents, optional
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.targetDate,
    this.description,
    this.category = 'General Savings',
    this.iconKey = 'savings',
    this.status = GoalStatus.active,
    this.priority = GoalPriority.medium,
    this.linkedAccountId,
    this.planFrequency,
    this.plannedPeriodicAmount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'target_amount': targetAmount,
      'target_date': targetDate?.toIso8601String(),
      'description': description,
      'category': category,
      'icon_key': iconKey,
      'status': status.name,
      'priority': priority.name,
      'linked_account_id': linkedAccountId,
      'plan_frequency': planFrequency?.name,
      'planned_periodic_amount': plannedPeriodicAmount,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  factory SavingsGoal.fromMap(Map<String, dynamic> map) {
    return SavingsGoal(
      id: map['id'] as String,
      name: map['name'] as String,
      targetAmount: map['target_amount'] as int,
      targetDate: map['target_date'] != null
          ? DateTime.parse(map['target_date'] as String)
          : null,
      description: map['description'] as String?,
      category: (map['category'] as String?) ?? 'General Savings',
      iconKey: (map['icon_key'] as String?) ?? 'savings',
      status: GoalStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String?),
        orElse: () => GoalStatus.active,
      ),
      priority: GoalPriority.values.firstWhere(
        (e) => e.name == (map['priority'] as String?),
        orElse: () => GoalPriority.medium,
      ),
      linkedAccountId: map['linked_account_id'] as String?,
      planFrequency: map['plan_frequency'] != null
          ? ContributionPlanFrequency.values.firstWhere(
              (e) => e.name == (map['plan_frequency'] as String?),
              orElse: () => ContributionPlanFrequency.monthly,
            )
          : null,
      plannedPeriodicAmount: map['planned_periodic_amount'] as int?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
    );
  }

  SavingsGoal copyWith({
    String? id,
    String? name,
    int? targetAmount,
    DateTime? targetDate,
    String? description,
    String? category,
    String? iconKey,
    GoalStatus? status,
    GoalPriority? priority,
    String? linkedAccountId,
    ContributionPlanFrequency? planFrequency,
    int? plannedPeriodicAmount,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearTargetDate = false,
    bool clearLinkedAccount = false,
    bool clearPlan = false,
    bool clearCompletedAt = false,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
      description: description ?? this.description,
      category: category ?? this.category,
      iconKey: iconKey ?? this.iconKey,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      linkedAccountId:
          clearLinkedAccount ? null : (linkedAccountId ?? this.linkedAccountId),
      planFrequency:
          clearPlan ? null : (planFrequency ?? this.planFrequency),
      plannedPeriodicAmount: clearPlan
          ? null
          : (plannedPeriodicAmount ?? this.plannedPeriodicAmount),
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }
}

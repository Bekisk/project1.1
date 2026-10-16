import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/features/savings_goals/models/goal_contribution.dart';
import 'package:personal_finance/features/savings_goals/models/savings_goal.dart';
import 'package:personal_finance/features/savings_goals/providers/savings_goals_provider.dart';
import 'package:provider/provider.dart';

class AddEditGoalSheet extends StatefulWidget {
  final SavingsGoal? goalToEdit;
  final String? initialName;
  final String? initialCategory;
  final String? initialIconKey;
  final int? initialTargetAmount;

  const AddEditGoalSheet({
    super.key,
    this.goalToEdit,
    this.initialName,
    this.initialCategory,
    this.initialIconKey,
    this.initialTargetAmount,
  });

  static Future<void> show(
    BuildContext context, {
    SavingsGoal? goalToEdit,
    String? initialName,
    String? initialCategory,
    String? initialIconKey,
    int? initialTargetAmount,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditGoalSheet(
        goalToEdit: goalToEdit,
        initialName: initialName,
        initialCategory: initialCategory,
        initialIconKey: initialIconKey,
        initialTargetAmount: initialTargetAmount,
      ),
    );
  }

  @override
  State<AddEditGoalSheet> createState() => _AddEditGoalSheetState();
}

class _AddEditGoalSheetState extends State<AddEditGoalSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _targetAmountController;
  late TextEditingController _descriptionController;
  late TextEditingController _notesController;
  late TextEditingController _initialContribController;
  late TextEditingController _plannedAmountController;

  late String _selectedCategory;
  late String _selectedIconKey;
  late GoalPriority _selectedPriority;
  DateTime? _selectedTargetDate;
  String? _selectedLinkedAccountId;
  ContributionPlanFrequency? _selectedPlanFrequency;
  bool _enablePlan = false;
  bool _addInitialContribution = false;
  ContributionMode _initialContribMode = ContributionMode.manual;
  String? _initialSourceAccountId;

  bool _isSaving = false;

  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'Emergency Fund',
      'icon': 'emergency',
      'iconData': Icons.health_and_safety_rounded,
      'color': AppTheme.primaryGreen,
    },
    {
      'name': 'Education',
      'icon': 'school',
      'iconData': Icons.school_rounded,
      'color': AppTheme.accentTeal,
    },
    {
      'name': 'Technology',
      'icon': 'laptop',
      'iconData': Icons.laptop_mac_rounded,
      'color': AppTheme.accentBlue,
    },
    {
      'name': 'Business',
      'icon': 'business',
      'iconData': Icons.business_center_rounded,
      'color': AppTheme.accentPurple,
    },
    {
      'name': 'Travel',
      'icon': 'flight',
      'iconData': Icons.flight_takeoff_rounded,
      'color': AppTheme.accentAmber,
    },
    {
      'name': 'Housing',
      'icon': 'home',
      'iconData': Icons.home_rounded,
      'color': AppTheme.accentCoral,
    },
    {
      'name': 'Personal',
      'icon': 'person',
      'iconData': Icons.person_rounded,
      'color': AppTheme.accentIndigo,
    },
    {
      'name': 'General Savings',
      'icon': 'savings',
      'iconData': Icons.savings_rounded,
      'color': AppTheme.primaryNavy,
    },
  ];

  @override
  void initState() {
    super.initState();
    final g = widget.goalToEdit;
    _nameController = TextEditingController(
      text: g?.name ?? widget.initialName ?? '',
    );
    _targetAmountController = TextEditingController(
      text: g != null
          ? (g.targetAmount / 100.0).toStringAsFixed(2)
          : (widget.initialTargetAmount != null
                ? (widget.initialTargetAmount! / 100.0).toStringAsFixed(0)
                : ''),
    );
    _descriptionController = TextEditingController(text: g?.description ?? '');
    _notesController = TextEditingController(text: g?.notes ?? '');
    _initialContribController = TextEditingController();
    _plannedAmountController = TextEditingController(
      text: g?.plannedPeriodicAmount != null
          ? (g!.plannedPeriodicAmount! / 100.0).toStringAsFixed(2)
          : '',
    );

    _selectedCategory =
        g?.category ?? widget.initialCategory ?? 'General Savings';
    _selectedIconKey = g?.iconKey ?? widget.initialIconKey ?? 'savings';
    _selectedPriority = g?.priority ?? GoalPriority.medium;
    _selectedTargetDate = g?.targetDate;
    _selectedLinkedAccountId = g?.linkedAccountId;
    _selectedPlanFrequency = g?.planFrequency;
    _enablePlan = g?.planFrequency != null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _initialContribController.dispose();
    _plannedAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final initialDate =
        _selectedTargetDate ?? now.add(const Duration(days: 90));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(now) ? now : initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 30)),
    );
    if (picked != null) {
      setState(() {
        _selectedTargetDate = picked;
      });
    }
  }

  Future<void> _saveGoal() async {
    if (_isSaving) return; // Prevent double-tap
    if (!_formKey.currentState!.validate()) return;

    final targetParsed =
        double.tryParse(_targetAmountController.text.trim()) ?? 0;
    final targetCents = (targetParsed * 100).round();
    if (targetCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Target amount must be greater than zero'),
        ),
      );
      return;
    }

    int? plannedAmountCents;
    if (_enablePlan && _plannedAmountController.text.trim().isNotEmpty) {
      final pParsed =
          double.tryParse(_plannedAmountController.text.trim()) ?? 0;
      if (pParsed > 0) {
        plannedAmountCents = (pParsed * 100).round();
      }
    }

    int initialCents = 0;
    if (widget.goalToEdit == null && _addInitialContribution) {
      final initParsed =
          double.tryParse(_initialContribController.text.trim()) ?? 0;
      initialCents = (initParsed * 100).round();
      if (_initialContribMode == ContributionMode.accountTransfer &&
          _initialSourceAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a source account for transfer'),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    final provider = context.read<SavingsGoalsProvider>();

    try {
      if (widget.goalToEdit != null) {
        final g = widget.goalToEdit!;
        final updated = g.copyWith(
          name: _nameController.text.trim(),
          targetAmount: targetCents,
          targetDate: _selectedTargetDate,
          clearTargetDate: _selectedTargetDate == null,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          category: _selectedCategory,
          iconKey: _selectedIconKey,
          priority: _selectedPriority,
          linkedAccountId: _selectedLinkedAccountId,
          clearLinkedAccount: _selectedLinkedAccountId == null,
          planFrequency: _enablePlan
              ? (_selectedPlanFrequency ?? ContributionPlanFrequency.monthly)
              : null,
          plannedPeriodicAmount: _enablePlan ? plannedAmountCents : null,
          clearPlan: !_enablePlan,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

        final success = await provider.updateGoal(updated);
        if (mounted) {
          if (success) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Goal updated successfully!'),
                backgroundColor: AppTheme.primaryGreen,
              ),
            );
          } else {
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update goal')),
            );
          }
        }
      } else {
        // Create new goal
        final created = await provider.createGoal(
          name: _nameController.text.trim(),
          targetAmount: targetCents,
          targetDate: _selectedTargetDate,
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          iconKey: _selectedIconKey,
          priority: _selectedPriority,
          linkedAccountId: _selectedLinkedAccountId,
          planFrequency: _enablePlan
              ? (_selectedPlanFrequency ?? ContributionPlanFrequency.monthly)
              : null,
          plannedPeriodicAmount: _enablePlan ? plannedAmountCents : null,
          notes: _notesController.text.trim(),
          initialContributionAmount: initialCents,
          initialMode: _initialContribMode,
          sourceAccountId: _initialSourceAccountId,
        );

        if (mounted) {
          if (created != null) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Savings goal created successfully!'),
                backgroundColor: AppTheme.primaryGreen,
              ),
            );
          } else {
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to create savings goal')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<SavingsGoalsProvider>();
    final accounts = provider.accounts;

    final isEdit = widget.goalToEdit != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 12,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit Savings Goal' : 'Create Savings Goal',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Goal Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Goal Name *',
                  hintText: 'e.g. Laptop Purchase, Emergency Fund',
                  prefixIcon: const Icon(Icons.flag_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a goal name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Target Amount
              TextFormField(
                controller: _targetAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Target Amount (ETB) *',
                  hintText: '40000.00',
                  prefixIcon: const Icon(Icons.payments_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a target amount';
                  }
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a positive amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Category Selector
              Text('Goal Category', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final cat = _categories[i];
                    final isSelected = _selectedCategory == cat['name'];
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat['iconData'] as IconData, size: 16),
                          const SizedBox(width: 6),
                          Text(cat['name'] as String),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: (cat['color'] as Color).withValues(
                        alpha: 0.25,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = cat['name'] as String;
                            _selectedIconKey = cat['icon'] as String;
                          });
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Priority Selector
              Text('Priority', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<GoalPriority>(
                segments: const [
                  ButtonSegment(value: GoalPriority.low, label: Text('Low')),
                  ButtonSegment(
                    value: GoalPriority.medium,
                    label: Text('Medium'),
                  ),
                  ButtonSegment(value: GoalPriority.high, label: Text('High')),
                ],
                selected: {_selectedPriority},
                onSelectionChanged: (set) {
                  setState(() {
                    _selectedPriority = set.first;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Target Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: Text(
                  _selectedTargetDate != null
                      ? 'Target Date: ${DateFormat('MMM dd, yyyy').format(_selectedTargetDate!)}'
                      : 'Set Target Date (Optional)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: _selectedTargetDate != null
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  _selectedTargetDate != null
                      ? '${_selectedTargetDate!.difference(DateTime.now()).inDays} days remaining'
                      : 'Helps calculate savings timeline and monthly plans',
                  style: theme.textTheme.bodySmall,
                ),
                trailing: _selectedTargetDate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () =>
                            setState(() => _selectedTargetDate = null),
                      )
                    : OutlinedButton(
                        onPressed: _pickTargetDate,
                        child: const Text('Pick Date'),
                      ),
                onTap: _pickTargetDate,
              ),
              const Divider(),

              // Optional Linked Savings Account
              if (accounts.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  initialValue: _selectedLinkedAccountId,
                  decoration: InputDecoration(
                    labelText: 'Linked Savings Account (Optional)',
                    helperText:
                        'Earmark savings into a dedicated bank or wallet',
                    prefixIcon: const Icon(
                      Icons.account_balance_wallet_rounded,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None (General Goal)'),
                    ),
                    ...accounts.map(
                      (acc) => DropdownMenuItem<String?>(
                        value: acc.id,
                        child: Text('${acc.name} (${acc.currencyCode})'),
                      ),
                    ),
                  ],
                  onChanged: (val) =>
                      setState(() => _selectedLinkedAccountId = val),
                ),
                const SizedBox(height: 14),
              ],

              // Savings Plan Toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Configure Contribution Plan'),
                subtitle: const Text('Plan weekly or monthly target savings'),
                value: _enablePlan,
                onChanged: (val) {
                  setState(() {
                    _enablePlan = val;
                    if (val && _selectedPlanFrequency == null) {
                      _selectedPlanFrequency =
                          ContributionPlanFrequency.monthly;
                    }
                  });
                },
              ),
              if (_enablePlan) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<ContributionPlanFrequency>(
                        initialValue:
                            _selectedPlanFrequency ??
                            ContributionPlanFrequency.monthly,
                        decoration: InputDecoration(
                          labelText: 'Frequency',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: ContributionPlanFrequency.weekly,
                            child: Text('Weekly'),
                          ),
                          DropdownMenuItem(
                            value: ContributionPlanFrequency.monthly,
                            child: Text('Monthly'),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedPlanFrequency = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _plannedAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Planned (ETB)',
                          hintText: '1000.00',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Initial contribution (Only for create)
              if (!isEdit) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Add Initial Contribution'),
                  subtitle: const Text(
                    'Deposit or earmark money immediately upon creation',
                  ),
                  value: _addInitialContribution,
                  onChanged: (val) =>
                      setState(() => _addInitialContribution = val),
                ),
                if (_addInitialContribution) ...[
                  TextFormField(
                    controller: _initialContribController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Initial Amount (ETB)',
                      prefixIcon: const Icon(Icons.add_circle_outline_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<ContributionMode>(
                    segments: const [
                      ButtonSegment(
                        value: ContributionMode.manual,
                        label: Text('Manual Earmark'),
                      ),
                      ButtonSegment(
                        value: ContributionMode.accountTransfer,
                        label: Text('Account Transfer'),
                      ),
                    ],
                    selected: {_initialContribMode},
                    onSelectionChanged: (set) =>
                        setState(() => _initialContribMode = set.first),
                  ),
                  if (_initialContribMode ==
                      ContributionMode.accountTransfer) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _initialSourceAccountId,
                      decoration: InputDecoration(
                        labelText: 'Source Account',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: accounts.map((acc) {
                        return DropdownMenuItem(
                          value: acc.id,
                          child: Text(acc.name),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _initialSourceAccountId = val),
                    ),
                  ],
                  const SizedBox(height: 14),
                ],
              ],

              // Description & Notes
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveGoal,
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark
                        ? AppTheme.primaryGreen
                        : AppTheme.primaryNavy,
                    foregroundColor: isDark ? AppTheme.deepNavy : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEdit ? 'Update Savings Goal' : 'Save Goal',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

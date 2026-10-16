import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/categories/models/category.dart';
import 'package:personal_finance/features/recurring/models/recurring_schedule.dart';
import 'package:personal_finance/features/recurring/providers/recurring_provider.dart';
import 'package:personal_finance/features/transactions/providers/transactions_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  static void navigate(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SubscriptionsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final txProvider = context.watch<TransactionsProvider>();
    final accounts = txProvider.accounts;
    final categories = txProvider.categories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring & Subscriptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Schedule',
            onPressed: () => _showAddEditDialog(
              context,
              accounts: accounts,
              categories: categories,
            ),
          ),
        ],
      ),
      body: Consumer<RecurringProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final schedules = provider.schedules;
          final monthlyCost = provider.totalMonthlyCommitmentCents;

          return RefreshIndicator(
            onRefresh: () => provider.loadSchedules(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // Highlight Commitment Card
                FintechCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TOTAL FIXED COMMITMENT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentPurple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${provider.activeExpenses.length} Active',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentPurple,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${CurrencyFormatter.formatCents(monthlyCost)} / Month',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Normalized monthly expenditure for all active fixed expenses and scheduled bills.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Schedules List Header
                Text(
                  'Scheduled Subscriptions & Bills',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                if (schedules.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.autorenew_rounded,
                            size: 48,
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No recurring schedules created',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add rent, internet, gym, or software subscriptions to track fixed commitments.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add First Subscription'),
                            onPressed: () => _showAddEditDialog(
                              context,
                              accounts: accounts,
                              categories: categories,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...schedules.map((schedule) {
                    final acc = txProvider.accountMap[schedule.accountId];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FintechCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: schedule.isActive
                                  ? AppTheme.accentPurple.withOpacity(0.15)
                                  : Colors.grey.withOpacity(0.15),
                              child: Icon(
                                Icons.repeat_rounded,
                                size: 18,
                                color: schedule.isActive
                                    ? AppTheme.accentPurple
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          schedule.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            decoration: schedule.isActive
                                                ? null
                                                : TextDecoration.lineThrough,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white10
                                              : Colors.black.withOpacity(0.06),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          schedule.frequencyLabel,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${acc?.name ?? "Account"} • Next: ${DateFormat("MMM dd").format(schedule.nextOccurrence)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppTheme.textSecondaryDark
                                          : AppTheme.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.formatCents(
                                    schedule.amount,
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: schedule.isActive
                                        ? (isDark
                                              ? Colors.white
                                              : Colors.black87)
                                        : Colors.grey,
                                  ),
                                ),
                                Switch.adaptive(
                                  value: schedule.isActive,
                                  activeColor: AppTheme.primaryGreen,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  onChanged: (_) =>
                                      provider.toggleActive(schedule),
                                ),
                              ],
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                size: 18,
                              ),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showAddEditDialog(
                                    context,
                                    scheduleToEdit: schedule,
                                    accounts: accounts,
                                    categories: categories,
                                  );
                                } else if (val == 'delete') {
                                  provider.deleteSchedule(schedule.id);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddEditDialog(
    BuildContext context, {
    RecurringSchedule? scheduleToEdit,
    required List<Account> accounts,
    required List<Category> categories,
  }) {
    final nameCtrl = TextEditingController(text: scheduleToEdit?.name ?? '');
    final amountCtrl = TextEditingController(
      text: scheduleToEdit != null
          ? (scheduleToEdit.amount / 100.0).toStringAsFixed(2)
          : '',
    );
    RecurringFrequency selectedFreq =
        scheduleToEdit?.frequency ?? RecurringFrequency.monthly;
    String? selectedAccId =
        scheduleToEdit?.accountId ??
        (accounts.isNotEmpty ? accounts.first.id : null);
    String? selectedCatId =
        scheduleToEdit?.categoryId ??
        (categories.isNotEmpty ? categories.first.id : null);
    DateTime nextOccur =
        scheduleToEdit?.nextOccurrence ??
        DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        scheduleToEdit == null
                            ? 'New Subscription'
                            : 'Edit Subscription',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Name
                  const Text(
                    'Name / Service',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Netflix, Gym, Rent, Internet',
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Amount
                  const Text(
                    'Amount (ETB)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Frequency
                  const Text(
                    'Frequency',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: RecurringFrequency.values.map((f) {
                      final isSelected = selectedFreq == f;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ChoiceChip(
                            label: Text(
                              f == RecurringFrequency.weekly
                                  ? 'Weekly'
                                  : f == RecurringFrequency.monthly
                                  ? 'Monthly'
                                  : 'Yearly',
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: isSelected,
                            selectedColor: AppTheme.accentPurple.withOpacity(
                              0.2,
                            ),
                            onSelected: (val) {
                              if (val) setState(() => selectedFreq = f);
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Account Selector
                  const Text(
                    'Debit Account',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedAccId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    dropdownColor: isDark
                        ? const Color(0xFF1E293B)
                        : Colors.white,
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedAccId = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Next Execution Date
                  const Text(
                    'Next Execution Date',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: nextOccur,
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 365 * 3)),
                      );
                      if (picked != null) {
                        setState(() => nextOccur = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMM dd, yyyy').format(nextOccur),
                            style: const TextStyle(fontSize: 13),
                          ),
                          const Icon(Icons.calendar_today_rounded, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final amount =
                            (double.tryParse(amountCtrl.text.trim()) ?? 0 * 100)
                                .round();
                        if (name.isEmpty ||
                            amount <= 0 ||
                            selectedAccId == null) {
                          return;
                        }

                        final now = DateTime.now();
                        if (scheduleToEdit == null) {
                          final newSchedule = RecurringSchedule(
                            id: const Uuid().v4(),
                            name: name,
                            type: 'expense',
                            amount: (double.parse(amountCtrl.text.trim()) * 100)
                                .round(),
                            accountId: selectedAccId!,
                            categoryId: selectedCatId,
                            frequency: selectedFreq,
                            startDate: now,
                            nextOccurrence: nextOccur,
                            isActive: true,
                            createdAt: now,
                            updatedAt: now,
                          );
                          await context.read<RecurringProvider>().addSchedule(
                            newSchedule,
                          );
                        } else {
                          final updated = scheduleToEdit.copyWith(
                            name: name,
                            amount: (double.parse(amountCtrl.text.trim()) * 100)
                                .round(),
                            accountId: selectedAccId,
                            categoryId: selectedCatId,
                            frequency: selectedFreq,
                            nextOccurrence: nextOccur,
                            updatedAt: now,
                          );
                          await context
                              .read<RecurringProvider>()
                              .updateSchedule(updated);
                        }

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                      },
                      child: Text(
                        scheduleToEdit == null
                            ? 'Schedule Subscription'
                            : 'Save Changes',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/core/widgets/liquid_atmosphere_background.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/categories/models/category.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';
import 'package:personal_finance/features/transactions/services/transaction_review_service.dart';

class TransactionReviewAssistantScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const TransactionReviewAssistantScreen({super.key, required this.onComplete});

  @override
  State<TransactionReviewAssistantScreen> createState() =>
      _TransactionReviewAssistantScreenState();
}

class _TransactionReviewAssistantScreenState
    extends State<TransactionReviewAssistantScreen> {
  final TransactionReviewService _reviewService =
      TransactionReviewService.instance;

  List<FinancialTransaction> _pendingQueue = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  Account? _currentAccount;
  List<Category> _availableCategories = [];
  String? _selectedCategoryId;
  final TextEditingController _explanationController = TextEditingController();
  final FocusNode _explanationFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadPendingTransactions();
  }

  @override
  void dispose() {
    _explanationController.dispose();
    _explanationFocus.dispose();
    super.dispose();
  }

  Future<void> _loadPendingTransactions() async {
    setState(() => _isLoading = true);
    final list = await _reviewService.getPendingTransactions();
    if (!mounted) return;

    if (list.isEmpty) {
      widget.onComplete();
      return;
    }

    setState(() {
      _pendingQueue = list;
      _currentIndex = 0;
      _isLoading = false;
    });

    await _loadTransactionDetails();
  }

  Future<void> _loadTransactionDetails() async {
    if (_currentIndex >= _pendingQueue.length) {
      widget.onComplete();
      return;
    }

    final tx = _pendingQueue[_currentIndex];
    final account = await _reviewService.getAccount(tx.accountId);
    final categories = await _reviewService.getCategoriesForType(tx.type);

    if (!mounted) return;

    setState(() {
      _currentAccount = account;
      _availableCategories = categories;
      _selectedCategoryId = tx.categoryId;
      _explanationController.text = tx.notes ?? '';
    });
  }

  Future<void> _saveAndContinue() async {
    if (_currentIndex >= _pendingQueue.length) return;
    final tx = _pendingQueue[_currentIndex];

    setState(() => _isSaving = true);

    final success = await _reviewService.saveTransactionReview(
      transactionId: tx.id,
      categoryId: _selectedCategoryId,
      purposeNote: _explanationController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      _moveToNext();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save review. Please retry.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _skipForNow() {
    // Keep transaction pending for next launch and continue to next pending
    _moveToNext();
  }

  void _reviewLater() {
    // Exit assistant to home page leaving unreviewed transactions in queue
    widget.onComplete();
  }

  void _moveToNext() {
    if (_currentIndex + 1 < _pendingQueue.length) {
      setState(() {
        _currentIndex++;
      });
      _loadTransactionDetails();
    } else {
      widget.onComplete();
    }
  }

  String _buildQuestionText(FinancialTransaction tx) {
    final lowerDesc = tx.description.toLowerCase();
    if (lowerDesc.contains('atm') || lowerDesc.contains('withdrawal')) {
      return 'What is this cash withdrawal for?';
    }
    if (tx.type == TransactionType.income) {
      return 'What was this money for?';
    }
    if (tx.type == TransactionType.transfer) {
      return 'What was this transfer for?';
    }
    return 'What did you spend this money on?';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        body: LiquidAtmosphereBackground(
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_pendingQueue.isEmpty || _currentIndex >= _pendingQueue.length) {
      return const SizedBox.shrink();
    }

    final tx = _pendingQueue[_currentIndex];
    final totalCount = _pendingQueue.length;
    final progressNumber = _currentIndex + 1;
    final isIncome = tx.type == TransactionType.income;
    final formattedDate = DateFormat('MMM dd, yyyy • h:mm a')
        .format(tx.transactionDate);

    return Scaffold(
      body: LiquidAtmosphereBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Header with Progress and Review Later button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryAccent.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.primaryAccent.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 13,
                                    color: AppTheme.primaryAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Review Assistant',
                                    style: TextStyle(
                                      color: isDark
                                          ? AppTheme.pureWhite
                                          : AppTheme.primaryAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Transaction $progressNumber of $totalCount',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.secondaryGray
                                : const Color(0xFF475569),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: _reviewLater,
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? AppTheme.secondaryGray
                            : const Color(0xFF64748B),
                      ),
                      child: const Text(
                        'Review Later',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Linear Progress Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressNumber / totalCount,
                    minHeight: 4,
                    backgroundColor: isDark
                        ? AppTheme.cardCharcoal
                        : const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Main Transaction Card + Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Transaction Details Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.cardCharcoal : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.borderPrimary
                                : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.35 : 0.08,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Direction Badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (isIncome
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFEF4444))
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isIncome
                                            ? Icons.arrow_downward_rounded
                                            : Icons.arrow_upward_rounded,
                                        size: 14,
                                        color: isIncome
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isIncome ? 'Received' : 'Debited',
                                        style: TextStyle(
                                          color: isIncome
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFEF4444),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Amount Display
                            Text(
                              CurrencyFormatter.formatCents(tx.amount),
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.pureWhite
                                    : const Color(0xFF0F172A),
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Bank & Account Details
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.account_balance_rounded,
                                  size: 14,
                                  color: isDark
                                      ? AppTheme.secondaryGray
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _currentAccount?.name ?? 'Main Account',
                                  style: TextStyle(
                                    color: isDark
                                        ? AppTheme.secondaryGray
                                        : const Color(0xFF64748B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.disabledGray
                                    : const Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                            if (tx.description.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF181818)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  tx.description,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDark
                                        ? AppTheme.pureWhite
                                        : const Color(0xFF334155),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Adaptive Question
                      Text(
                        _buildQuestionText(tx),
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.pureWhite
                              : const Color(0xFF0F172A),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // User Explanation Text Field
                      TextField(
                        controller: _explanationController,
                        focusNode: _explanationFocus,
                        style: TextStyle(
                          color: isDark ? AppTheme.pureWhite : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: isIncome
                              ? 'e.g. Monthly salary, Freelance project, Gift...'
                              : 'e.g. Groceries at supermarket, Taxi fare, Lunch...',
                          hintStyle: TextStyle(
                            color: isDark
                                ? AppTheme.disabledGray
                                : const Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? AppTheme.cardCharcoal
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppTheme.borderPrimary
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppTheme.borderPrimary
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryAccent,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Suggested Categories
                      if (_availableCategories.isNotEmpty) ...[
                        Text(
                          'Suggested Category',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.secondaryGray
                                : const Color(0xFF475569),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableCategories.take(8).map((cat) {
                            final isSelected = _selectedCategoryId == cat.id;
                            return ChoiceChip(
                              label: Text(cat.name),
                              selected: isSelected,
                              onSelected: (val) {
                                setState(() {
                                  _selectedCategoryId = val ? cat.id : null;
                                });
                              },
                              selectedColor: AppTheme.primaryAccent,
                              backgroundColor: isDark
                                  ? AppTheme.cardCharcoal
                                  : const Color(0xFFF1F5F9),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.black
                                    : (isDark
                                          ? AppTheme.pureWhite
                                          : const Color(0xFF334155)),
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppTheme.primaryAccent
                                      : (isDark
                                            ? AppTheme.borderPrimary
                                            : const Color(0xFFE2E8F0)),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Actions: Save & Continue + Skip for Now
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveAndContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryAccent,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Save and Continue',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _skipForNow,
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? AppTheme.secondaryGray
                            : const Color(0xFF64748B),
                      ),
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

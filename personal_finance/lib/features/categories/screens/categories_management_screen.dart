import 'package:flutter/material.dart';
import 'package:personal_finance/core/widgets/category_icon_badge.dart';
import 'package:personal_finance/features/categories/models/category.dart';
import 'package:personal_finance/features/dashboard/providers/dashboard_provider.dart';
import 'package:personal_finance/features/transactions/providers/transactions_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:personal_finance/core/database/database_helper.dart';

class CategoriesManagementScreen extends StatefulWidget {
  final bool isSelectionMode;
  final String? initialSelectedCategoryId;
  final String initialTab;

  const CategoriesManagementScreen({
    super.key,
    this.isSelectionMode = false,
    this.initialSelectedCategoryId,
    this.initialTab = 'expense',
  });

  static Future<Category?> selectCategory(
    BuildContext context, {
    String initialTab = 'expense',
    String? currentCategoryId,
  }) async {
    return Navigator.of(context).push<Category>(
      MaterialPageRoute(
        builder: (_) => CategoriesManagementScreen(
          isSelectionMode: true,
          initialSelectedCategoryId: currentCategoryId,
          initialTab: initialTab,
        ),
      ),
    );
  }

  static void navigate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CategoriesManagementScreen()),
    );
  }

  @override
  State<CategoriesManagementScreen> createState() =>
      _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState
    extends State<CategoriesManagementScreen> {
  bool _isLoading = true;
  List<Category> _categories = [];
  late String _selectedTab;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _selectedCategoryId = widget.initialSelectedCategoryId;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final catMaps = await db.query('categories', where: 'is_archived = 0');
      if (mounted) {
        setState(() {
          _categories = catMaps.map((e) => Category.fromMap(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEditCategoryDialog({Category? categoryToEdit}) {
    final nameCtrl = TextEditingController(text: categoryToEdit?.name ?? '');
    String iconKey = categoryToEdit?.iconKey ?? 'category';
    String colorKey = categoryToEdit?.colorKey ?? '0xFF10B981';
    final formKey = GlobalKey<FormState>();

    final iconsList = [
      'work',
      'laptop',
      'card_giftcard',
      'trending_up',
      'store',
      'restaurant',
      'directions_car',
      'shopping_bag',
      'receipt_long',
      'fitness_center',
      'home',
      'school',
      'medical_services',
      'movie',
      'category',
    ];
    final colorsList = [
      '0xFF3B82F6',
      '0xFF06B6D4',
      '0xFFFB7185',
      '0xFFF59E0B',
      '0xFF10B981',
      '0xFFEF4444',
      '0xFF8B5CF6',
      '0xFF64748B',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              categoryToEdit == null
                  ? 'New ${_selectedTab == 'income' ? 'Income' : 'Expense'} Category'
                  : 'Edit Category',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Category Name',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF00A86B),
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Enter category name'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Select Icon',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: iconsList.map((ic) {
                        final isSelected = ic == iconKey;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setDialogState(() => iconKey = ic),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF00A86B)
                                        .withValues(alpha: 0.15)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(
                                      color: const Color(0xFF00A86B),
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Icon(
                              CategoryIconBadge.getIcon(ic),
                              size: 22,
                              color: isSelected
                                  ? const Color(0xFF00A86B)
                                  : const Color(0xFF475569),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Select Color',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: colorsList.map((colHex) {
                        final color = Color(int.parse(colHex));
                        final isSelected = colHex == colorKey;
                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => setDialogState(() => colorKey = colHex),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      const BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final nav = Navigator.of(ctx);
                  final dash = context.read<DashboardProvider>();
                  final txs = context.read<TransactionsProvider>();

                  final db = await DatabaseHelper.instance.database;

                  if (categoryToEdit == null) {
                    final newCat = Category(
                      id: const Uuid().v4(),
                      name: nameCtrl.text.trim(),
                      transactionType: _selectedTab,
                      iconKey: iconKey,
                      colorKey: colorKey,
                      isDefault: false,
                    );
                    await db.insert('categories', newCat.toMap());
                  } else {
                    final updated = Category(
                      id: categoryToEdit.id,
                      name: nameCtrl.text.trim(),
                      transactionType: categoryToEdit.transactionType,
                      iconKey: iconKey,
                      colorKey: colorKey,
                      isDefault: categoryToEdit.isDefault,
                      isArchived: categoryToEdit.isArchived,
                    );
                    await db.update(
                      'categories',
                      updated.toMap(),
                      where: 'id = ?',
                      whereArgs: [categoryToEdit.id],
                    );
                  }

                  nav.pop();
                  dash.loadDashboardData();
                  txs.loadTransactions();
                  if (mounted) {
                    _loadCategories();
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00A86B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmArchive(Category cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Archive Category?'),
        content: Text(
          'Archive "${cat.name}"? Existing transactions will retain their historical link.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final db = await DatabaseHelper.instance.database;
              await db.update(
                'categories',
                {'is_archived': 1},
                where: 'id = ?',
                whereArgs: [cat.id],
              );
              if (mounted) {
                context.read<DashboardProvider>().loadDashboardData();
                context.read<TransactionsProvider>().loadTransactions();
                _loadCategories();
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _categories
        .where((c) => c.transactionType == _selectedTab)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Categories',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_rounded,
              size: 24,
              color: Color(0xFF0F172A),
            ),
            tooltip: 'Add Category',
            onPressed: () => _showAddEditCategoryDialog(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          // Segmented Pill Toggle: Income | Expense
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 'income'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 'income'
                              ? const Color(0xFF00A86B)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            'Income',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _selectedTab == 'income'
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 'expense'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 'expense'
                              ? const Color(0xFF00A86B)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            'Expense',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _selectedTab == 'expense'
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Category Items List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00A86B)),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No $_selectedTab categories found',
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final cat = filtered[i];
                      final isSelected =
                          widget.isSelectionMode &&
                          (_selectedCategoryId == cat.id);

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (widget.isSelectionMode) {
                            setState(() => _selectedCategoryId = cat.id);
                            Navigator.of(context).pop(cat);
                          } else {
                            _showAddEditCategoryDialog(categoryToEdit: cat);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF00A86B)
                                  : const Color(0xFFF1F5F9),
                              width: isSelected ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CategoryIconBadge(
                                iconKey: cat.iconKey,
                                colorKey: cat.colorKey,
                                size: 42,
                                iconSize: 20,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  cat.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_rounded,
                                  color: Color(0xFF00A86B),
                                  size: 22,
                                )
                              else if (!widget.isSelectionMode) ...[
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  onPressed: () => _showAddEditCategoryDialog(
                                    categoryToEdit: cat,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.archive_outlined,
                                    size: 18,
                                    color: Color(0xFFFDA4AF),
                                  ),
                                  onPressed: () => _confirmArchive(cat),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

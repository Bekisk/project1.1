import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/categories/models/category.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';

class TransactionReviewService {
  TransactionReviewService._();
  static final TransactionReviewService instance = TransactionReviewService._();

  /// Fetches pending transactions needing review ordered chronologically
  Future<List<FinancialTransaction>> getPendingTransactions() async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.query(
      'transactions',
      where: "review_status = 'needsReview'",
      orderBy: 'transaction_date ASC, created_at ASC',
    );
    return results.map((m) => FinancialTransaction.fromMap(m)).toList();
  }

  /// Count of unreviewed transactions
  Future<int> getPendingReviewCount() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM transactions WHERE review_status = 'needsReview'",
    );
    return (res.first['cnt'] as int?) ?? 0;
  }

  /// Saves the user's purpose explanation and selected category,
  /// marking the transaction as reviewed atomically.
  /// Does NOT alter amount, account, date, or duplicate balances.
  Future<bool> saveTransactionReview({
    required String transactionId,
    required String? categoryId,
    required String purposeNote,
    String? updatedDescription,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

    // Fetch existing transaction to preserve all other fields
    final existingRows = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );
    if (existingRows.isEmpty) return false;

    final existing = FinancialTransaction.fromMap(existingRows.first);

    // Merge notes cleanly without erasing technical ref
    String finalNotes;
    final cleanPurpose = purposeNote.trim();
    if (cleanPurpose.isNotEmpty) {
      if (existing.notes != null && existing.notes!.isNotEmpty) {
        finalNotes = '$cleanPurpose • ${existing.notes!}';
      } else {
        finalNotes = cleanPurpose;
      }
    } else {
      finalNotes = existing.notes ?? '';
    }

    final updatedTx = existing.copyWith(
      categoryId: categoryId ?? existing.categoryId,
      description:
          (updatedDescription != null && updatedDescription.trim().isNotEmpty)
          ? updatedDescription.trim()
          : (cleanPurpose.isNotEmpty ? cleanPurpose : existing.description),
      notes: finalNotes.isNotEmpty ? finalNotes : null,
      reviewStatus: ReviewStatus.reviewed,
      updatedAt: now,
    );

    final count = await db.update(
      'transactions',
      updatedTx.toMap(),
      where: 'id = ?',
      whereArgs: [transactionId],
    );

    return count > 0;
  }

  /// Marks a transaction as skipped (or leaves in review queue according to user request)
  Future<bool> skipTransaction(
    String transactionId, {
    bool deferForLater = true,
  }) async {
    final db = await DatabaseHelper.instance.database;
    if (deferForLater) {
      // Kept as needsReview so reopening the app resumes pending reviews
      return true;
    }
    final count = await db.update(
      'transactions',
      {
        'review_status': ReviewStatus.skipped.name,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [transactionId],
    );
    return count > 0;
  }

  /// Loads available categories for suggested chips
  Future<List<Category>> getCategoriesForType(TransactionType type) async {
    final db = await DatabaseHelper.instance.database;
    final typeStr = type == TransactionType.income ? 'income' : 'expense';
    final rows = await db.query(
      'categories',
      where: 'is_archived = 0 AND transaction_type = ?',
      whereArgs: [typeStr],
      orderBy: 'is_default DESC, name ASC',
    );
    return rows.map((m) => Category.fromMap(m)).toList();
  }

  /// Loads account details by ID
  Future<Account?> getAccount(String accountId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Account.fromMap(rows.first);
  }
}

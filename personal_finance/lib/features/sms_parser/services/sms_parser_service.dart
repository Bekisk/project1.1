import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/accounts/services/account_balance_service.dart';
import 'package:personal_finance/features/sms_parser/models/parsed_sms_transaction.dart';
import 'package:personal_finance/features/sms_parser/models/sms_import_log.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';
import 'package:uuid/uuid.dart';

class SyncResult {
  final SmsImportStatus status;
  final FinancialTransaction? transaction;
  final SmsImportLog log;
  final String message;

  const SyncResult({
    required this.status,
    this.transaction,
    required this.log,
    required this.message,
  });
}

class SmsParserService {
  static final SmsParserService instance = SmsParserService._();
  SmsParserService._();

  /// Comprehensive Parser for SMS alerts from Ethiopian banks and financial institutions
  ParsedSmsTransaction? parseSms(String text) {
    if (text.trim().isEmpty) return null;

    final lower = text.toLowerCase();

    // 0. Security, OTP, and Non-financial Guard
    // Crucial rule: Never book OTPs, passwords, authentication, marketing or security alerts
    if (_isNonFinancialOrSecurity(lower)) {
      return ParsedSmsTransaction(
        provider: _detectProvider(lower),
        transactionType: SmsTransactionType.nonFinancialOrOtp,
        isMoneyIn: false,
        amountCents: 0,
        rawMessage: text,
        confidence: ParsingConfidence.high,
        reviewReason: 'Security alert or non-financial message',
      );
    }

    // 1. Balance Inquiry / Promotional Guard
    if (_isBalanceInquiry(lower)) {
      final balanceCents = _extractReportedBalance(text);
      return ParsedSmsTransaction(
        provider: _detectProvider(lower),
        transactionType: SmsTransactionType.balanceInquiry,
        isMoneyIn: false,
        amountCents: 0,
        reportedBalanceCents: balanceCents,
        rawMessage: text,
        confidence: ParsingConfidence.high,
        reviewReason: 'Balance inquiry only — no funds transferred',
      );
    }

    // 2. Failed / Declined Transaction Guard
    if (_isFailedTransaction(lower)) {
      final amount = _extractPrimaryAmount(text) ?? 0;
      return ParsedSmsTransaction(
        provider: _detectProvider(lower),
        transactionType: SmsTransactionType.failedTransaction,
        isMoneyIn: false,
        amountCents: amount,
        rawMessage: text,
        confidence: ParsingConfidence.high,
        reviewReason: 'Transaction was declined, reversed or failed',
      );
    }

    // 3. Commercial Bank of Ethiopia (CBE)
    if (lower.contains('cbe') ||
        lower.contains('commercial bank') ||
        lower.contains('cbebirr') ||
        lower.contains('cbe birr') ||
        lower.contains('1000') &&
            (lower.contains('debited') || lower.contains('credited'))) {
      final cbe = _parseCbe(text);
      if (cbe != null) return cbe;
    }

    // 4. Telebirr
    if (lower.contains('telebirr') ||
        lower.contains('ethio telecom') ||
        lower.contains('you have paid etb') ||
        lower.contains('you have received etb')) {
      final tb = _parseTelebirr(text);
      if (tb != null) return tb;
    }

    // 5. Awash Bank
    if (lower.contains('awash') || lower.contains('awashbank')) {
      final awash = _parseAwash(text);
      if (awash != null) return awash;
    }

    // 6. Bank of Abyssinia (BoA)
    if (lower.contains('abyssinia') ||
        lower.contains('boa') ||
        lower.contains('apollo')) {
      final boa = _parseAbyssinia(text);
      if (boa != null) return boa;
    }

    // 7. Dashen Bank
    if (lower.contains('dashen') || lower.contains('amole')) {
      final dashen = _parseDashen(text);
      if (dashen != null) return dashen;
    }

    // 8. Generic Ethiopian Bank SMS Parser (Wegagen, Nib, Hibret, Cooperative, Zemen, etc.)
    return _parseGenericEthiopian(text);
  }

  // -------------------------------------------------------------
  // BANK-SPECIFIC PARSER IMPLEMENTATIONS
  // -------------------------------------------------------------

  ParsedSmsTransaction? _parseCbe(String text) {
    final lower = text.toLowerCase();

    // Direction indicators:
    // Outgoing transfers / withdrawals / debits:
    final hasSuccessfullyTransferred =
        lower.contains('successfully transferred') ||
        lower.contains('transferred to') ||
        lower.contains('you have transferred');
    final isDebit =
        lower.contains('debited') ||
        lower.contains('withdrawn') ||
        lower.contains('paid') ||
        hasSuccessfullyTransferred ||
        lower.contains('service charge');

    // Incoming transfers / deposits / credits:
    final hasReceived =
        lower.contains('you have received') ||
        lower.contains('received etb') ||
        lower.contains('credited with') ||
        lower.contains('credited to');
    final isCredit =
        lower.contains('credited') ||
        lower.contains('deposited') ||
        hasReceived ||
        lower.contains('refunded');

    if (!isDebit && !isCredit) return null;

    // Prioritize specific direction when both could match loosely:
    // E.g. "You have successfully transferred ETB200 from ... to ... Service charge of ETB 0.50"
    final bool moneyIn;
    if (hasSuccessfullyTransferred) {
      moneyIn = false;
    } else if (hasReceived) {
      moneyIn = true;
    } else if (lower.contains('debited')) {
      moneyIn = false;
    } else if (lower.contains('credited')) {
      moneyIn = true;
    } else {
      moneyIn = isCredit && !isDebit;
    }

    // Extract primary amount
    final amountCents =
        _extractAmountAfterKeywords(text, [
          'successfully transferred',
          'transferred',
          'received',
          'debited with',
          'debited by',
          'credited with',
          'withdrawn',
          'paid',
        ]) ??
        _extractPrimaryAmount(text);

    if (amountCents == null || amountCents <= 0) return null;

    final reportedBalance = _extractReportedBalance(text);
    final ref = _extractReference(text);
    final date = _extractDate(text) ?? DateTime.now();

    // Account extraction:
    // For incoming: "to your account 1**2313" vs "from account 1**6658"
    // For outgoing: "from account 1**2313 to account 1**9525"
    String? account;
    if (moneyIn) {
      final toYourAccMatch = RegExp(
        r'(?:to your account|to account)\s*([0-9*X\-]{4,20})',
        caseSensitive: false,
      ).firstMatch(text);
      if (toYourAccMatch != null) {
        final raw = toYourAccMatch.group(1)!;
        final digits = RegExp(r'([0-9]{3,4})$').firstMatch(raw);
        account = digits != null ? '...${digits.group(1)}' : raw;
      }
    } else {
      final fromAccMatch = RegExp(
        r'(?:from account|from your account)\s*([0-9*X\-]{4,20})',
        caseSensitive: false,
      ).firstMatch(text);
      if (fromAccMatch != null) {
        final raw = fromAccMatch.group(1)!;
        final digits = RegExp(r'([0-9]{3,4})$').firstMatch(raw);
        account = digits != null ? '...${digits.group(1)}' : raw;
      }
    }
    account ??= _extractAccount(text);

    // Fee extraction:
    // Check if total fee is indicated e.g. "with total of ETB200.61"
    int feeCents = 0;
    final totalFeeMatch = RegExp(
      r'with total of\s*(?:etb|birr|br\.?)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (totalFeeMatch != null) {
      final totalCents = _parseAmountToCents(totalFeeMatch.group(1));
      if (totalCents != null && totalCents > amountCents) {
        feeCents = totalCents - amountCents;
      }
    }
    // Only look for separate fee if NOT stated as "including Service charge" (which means already included in total debit)
    if (feeCents == 0 && !lower.contains('including service charge')) {
      feeCents = _extractSeparateFee(text);
    }

    // Determine granular transaction type
    SmsTransactionType txType;
    if (lower.contains('atm') || lower.contains('withdrawn from atm')) {
      txType = SmsTransactionType.atmWithdrawal;
    } else if (lower.contains('service charge') &&
        !hasSuccessfullyTransferred &&
        !lower.contains('debited with etb') &&
        !lower.contains('debited with') &&
        !lower.contains('including service charge')) {
      txType = SmsTransactionType.bankServiceFee;
    } else if (lower.contains('refund') || lower.contains('reversal')) {
      txType = SmsTransactionType.reversalOrRefund;
    } else if (lower.contains('interest')) {
      txType = SmsTransactionType.interestReceived;
    } else if (moneyIn) {
      txType = lower.contains('deposited')
          ? SmsTransactionType.cashDeposit
          : SmsTransactionType.incomingTransfer;
    } else if (hasSuccessfullyTransferred ||
        lower.contains('transferred to') ||
        lower.contains('transfer to')) {
      txType = SmsTransactionType.outgoingTransfer;
    } else if (lower.contains('paid etb') ||
        lower.contains('pos purchase') ||
        lower.contains('card payment')) {
      txType = SmsTransactionType.cardPayment;
    } else if (RegExp(
          r'\bfor\s+[a-zA-Z0-9]',
          caseSensitive: false,
        ).hasMatch(text) &&
        !lower.contains('for feedback') &&
        !lower.contains('for banking with')) {
      // e.g. "debited with ETB 653.00 on 12/10/2026 for Groceries."
      txType = SmsTransactionType.cardPayment;
    } else {
      // Generic account debit (e.g. Example C: "has been debited with ETB 200.85 including Service charge...")
      txType = SmsTransactionType.other;
    }

    // Extract party / merchant / counterpart
    String? party;
    if (moneyIn) {
      // E.g. "from account 1**6658 (Alemtshay Mekurya W/aregay)"
      final fromParenMatch = RegExp(
        r'from account\s*[0-9*X\-]+\s*\(([^)]+)\)',
        caseSensitive: false,
      ).firstMatch(text);
      if (fromParenMatch != null) {
        party = fromParenMatch.group(1)?.trim();
      } else {
        final byMatch = RegExp(
          r'(?:by|from)\s+([^.\n]+?)(?:\.|\s+on|\s+balance|\s+ref|\s+txn|$)',
          caseSensitive: false,
        ).firstMatch(text);
        final candidate = byMatch?.group(1)?.trim();
        if (candidate != null &&
            !candidate.toLowerCase().startsWith('banking with') &&
            !candidate.toLowerCase().startsWith('cbe')) {
          party = candidate;
        }
      }
    } else if (txType == SmsTransactionType.outgoingTransfer) {
      // E.g. "to account 1**9525 (Ethi.full Gos.ch. Haya Hulet M)"
      final toParenMatch = RegExp(
        r'to account\s*[0-9*X\-]+\s*\(([^)]+)\)',
        caseSensitive: false,
      ).firstMatch(text);
      if (toParenMatch != null) {
        party = toParenMatch.group(1)?.trim();
      } else {
        final toMatch = RegExp(
          r'(?:to)\s+([^.\n]+?)(?:\.|\s+on|\s+balance|\s+ref|\s+txn|$)',
          caseSensitive: false,
        ).firstMatch(text);
        final candidate = toMatch?.group(1)?.trim();
        if (candidate != null &&
            !candidate.toLowerCase().startsWith('account') &&
            !candidate.toLowerCase().startsWith('cbe')) {
          party = candidate;
        }
      }
    } else if (txType == SmsTransactionType.cardPayment ||
        txType == SmsTransactionType.merchantPayment) {
      final forMatch = RegExp(
        r'(?:for|to|at)\s+([^.\n]+?)(?:\.|\s+on|\s+balance|\s+ref|\s+txn|$)',
        caseSensitive: false,
      ).firstMatch(text);
      final candidate = forMatch?.group(1)?.trim();
      if (candidate != null &&
          !candidate.toLowerCase().startsWith('banking with') &&
          !candidate.toLowerCase().startsWith('feedback') &&
          !candidate.toLowerCase().startsWith('cbe')) {
        party = candidate;
      }
    }
    // Generic debits (SmsTransactionType.other) have no inferred recipient/merchant

    final confidence =
        (account != null && (ref != null || reportedBalance != null))
        ? ParsingConfidence.high
        : ParsingConfidence.medium;

    return ParsedSmsTransaction(
      provider: EthiopianBankProvider.cbe,
      transactionType: txType,
      isMoneyIn: moneyIn,
      amountCents: amountCents,
      feeCents: feeCents,
      reportedBalanceCents: reportedBalance,
      currencyCode: 'ETB',
      accountSuffix: account,
      partyOrMerchant: party,
      transactionDate: date,
      referenceNumber: ref,
      rawMessage: text,
      confidence: confidence,
    );
  }

  ParsedSmsTransaction? _parseTelebirr(String text) {
    final lower = text.toLowerCase();
    final isDebit =
        lower.contains('paid') ||
        lower.contains('transferred to') ||
        lower.contains('debited') ||
        lower.contains('cash out') ||
        lower.contains('bought');
    final isCredit =
        lower.contains('received') ||
        lower.contains('credited') ||
        lower.contains('deposited') ||
        lower.contains('cash in');

    if (!isDebit && !isCredit) return null;

    final amountCents =
        _extractAmountAfterKeywords(text, [
          'paid',
          'received',
          'transferred',
          'cash out',
          'cash in',
          'debited',
        ]) ??
        _extractPrimaryAmount(text);

    if (amountCents == null || amountCents <= 0) return null;

    final feeCents = _extractSeparateFee(text);
    final reportedBalance = _extractReportedBalance(text);
    final ref = _extractReference(text);
    final date = _extractDate(text) ?? DateTime.now();

    SmsTransactionType txType;
    if (lower.contains('cash out') || lower.contains('atm')) {
      txType = SmsTransactionType.atmWithdrawal;
    } else if (lower.contains('cash in')) {
      txType = SmsTransactionType.cashDeposit;
    } else if (lower.contains('fee') || lower.contains('service charge')) {
      txType = SmsTransactionType.bankServiceFee;
    } else if (isCredit) {
      txType = SmsTransactionType.incomingTransfer;
    } else {
      txType = SmsTransactionType.mobileMoneyPayment;
    }

    String? party;
    if (isDebit) {
      final toMatch = RegExp(
        r'to\s+([^.\n]+?)(?:\s+on|\s+your|\.|\s+txn|\s+ref|\s+current balance|$)',
        caseSensitive: false,
      ).firstMatch(text);
      party = toMatch?.group(1)?.trim();
    } else {
      final fromMatch = RegExp(
        r'from\s+([^.\n]+?)(?:\s+on|\.|\s+txn|\s+ref|\s+current balance|$)',
        caseSensitive: false,
      ).firstMatch(text);
      party = fromMatch?.group(1)?.trim();
    }

    return ParsedSmsTransaction(
      provider: EthiopianBankProvider.telebirr,
      transactionType: txType,
      isMoneyIn: isCredit,
      amountCents: amountCents,
      feeCents: feeCents,
      reportedBalanceCents: reportedBalance,
      currencyCode: 'ETB',
      accountSuffix: 'Telebirr',
      partyOrMerchant: party,
      transactionDate: date,
      referenceNumber: ref,
      rawMessage: text,
      confidence: ref != null
          ? ParsingConfidence.high
          : ParsingConfidence.medium,
    );
  }

  ParsedSmsTransaction? _parseAwash(String text) {
    final lower = text.toLowerCase();
    final isDebit =
        lower.contains('debited') ||
        lower.contains('withdrawn') ||
        lower.contains('paid');
    final isCredit =
        lower.contains('credited') ||
        lower.contains('deposited') ||
        lower.contains('received');

    if (!isDebit && !isCredit) return null;

    final amountCents =
        _extractAmountAfterKeywords(text, [
          'debited by',
          'debited with',
          'credited with',
          'transferred',
        ]) ??
        _extractPrimaryAmount(text);
    if (amountCents == null || amountCents <= 0) return null;

    final feeCents = _extractSeparateFee(text);
    final reportedBalance = _extractReportedBalance(text);
    final account = _extractAccount(text);
    final ref = _extractReference(text);
    final date = _extractDate(text) ?? DateTime.now();

    final reasonMatch = RegExp(
      r'(?:reason|for|to|from):?\s*([^.\n]+?)(?:\.|\s+balance|\s+ref|$)',
      caseSensitive: false,
    ).firstMatch(text);
    final party = reasonMatch?.group(1)?.trim();

    final txType = isCredit
        ? SmsTransactionType.incomingTransfer
        : SmsTransactionType.cardPayment;

    return ParsedSmsTransaction(
      provider: EthiopianBankProvider.awash,
      transactionType: txType,
      isMoneyIn: isCredit,
      amountCents: amountCents,
      feeCents: feeCents,
      reportedBalanceCents: reportedBalance,
      currencyCode: 'ETB',
      accountSuffix: account,
      partyOrMerchant: party,
      transactionDate: date,
      referenceNumber: ref,
      rawMessage: text,
      confidence: (account != null || ref != null)
          ? ParsingConfidence.high
          : ParsingConfidence.medium,
    );
  }

  ParsedSmsTransaction? _parseAbyssinia(String text) {
    final lower = text.toLowerCase();
    final isDebit =
        lower.contains('debited') ||
        lower.contains('withdrawn') ||
        lower.contains('paid') ||
        lower.contains('transferred');
    final isCredit =
        lower.contains('credited') ||
        lower.contains('deposited') ||
        lower.contains('received');

    if (!isDebit && !isCredit) return null;

    final amountCents = _extractPrimaryAmount(text);
    if (amountCents == null || amountCents <= 0) return null;

    final feeCents = _extractSeparateFee(text);
    final reportedBalance = _extractReportedBalance(text);
    final account = _extractAccount(text);
    final ref = _extractReference(text);
    final date = _extractDate(text) ?? DateTime.now();

    return ParsedSmsTransaction(
      provider: EthiopianBankProvider.abyssinia,
      transactionType: isCredit
          ? SmsTransactionType.incomingTransfer
          : SmsTransactionType.outgoingTransfer,
      isMoneyIn: isCredit,
      amountCents: amountCents,
      feeCents: feeCents,
      reportedBalanceCents: reportedBalance,
      currencyCode: 'ETB',
      accountSuffix: account,
      partyOrMerchant: isDebit ? 'Merchant / Recipient' : 'Sender',
      transactionDate: date,
      referenceNumber: ref,
      rawMessage: text,
      confidence: ParsingConfidence.high,
    );
  }

  ParsedSmsTransaction? _parseDashen(String text) {
    final lower = text.toLowerCase();
    final isDebit =
        lower.contains('debited') ||
        lower.contains('withdrawn') ||
        lower.contains('paid');
    final isCredit =
        lower.contains('credited') ||
        lower.contains('deposited') ||
        lower.contains('received');

    if (!isDebit && !isCredit) return null;

    final amountCents = _extractPrimaryAmount(text);
    if (amountCents == null || amountCents <= 0) return null;

    final feeCents = _extractSeparateFee(text);
    final reportedBalance = _extractReportedBalance(text);
    final account = _extractAccount(text);
    final ref = _extractReference(text);
    final date = _extractDate(text) ?? DateTime.now();

    return ParsedSmsTransaction(
      provider: EthiopianBankProvider.dashen,
      transactionType: isCredit
          ? SmsTransactionType.incomingTransfer
          : SmsTransactionType.cardPayment,
      isMoneyIn: isCredit,
      amountCents: amountCents,
      feeCents: feeCents,
      reportedBalanceCents: reportedBalance,
      currencyCode: 'ETB',
      accountSuffix: account,
      partyOrMerchant: isDebit ? 'Merchant' : 'Sender',
      transactionDate: date,
      referenceNumber: ref,
      rawMessage: text,
      confidence: ParsingConfidence.high,
    );
  }

  ParsedSmsTransaction? _parseGenericEthiopian(String text) {
    final lower = text.toLowerCase();
    final hasMoneyKeyword =
        lower.contains('etb') ||
        lower.contains('birr') ||
        lower.contains('br.');
    if (!hasMoneyKeyword) return null;

    final isDebit =
        lower.contains('debited') ||
        lower.contains('paid') ||
        lower.contains('withdrawn') ||
        lower.contains('transfer');
    final isCredit =
        lower.contains('credited') ||
        lower.contains('received') ||
        lower.contains('deposited');
    if (!isDebit && !isCredit) return null;

    final amountCents = _extractPrimaryAmount(text);
    if (amountCents == null || amountCents <= 0) return null;

    final feeCents = _extractSeparateFee(text);
    final reportedBalance = _extractReportedBalance(text);
    final account = _extractAccount(text);
    final ref = _extractReference(text);
    final date = _extractDate(text) ?? DateTime.now();

    return ParsedSmsTransaction(
      provider: EthiopianBankProvider.unknown,
      transactionType: isCredit
          ? SmsTransactionType.incomingTransfer
          : SmsTransactionType.other,
      isMoneyIn: isCredit,
      amountCents: amountCents,
      feeCents: feeCents,
      reportedBalanceCents: reportedBalance,
      currencyCode: 'ETB',
      accountSuffix: account,
      partyOrMerchant: null,
      transactionDate: date,
      referenceNumber: ref,
      rawMessage: text,
      confidence: ParsingConfidence.medium,
      reviewReason: 'Unregistered bank format — review details before saving',
    );
  }

  // -------------------------------------------------------------
  // RECONCILIATION & SAFE DATABASE RECORDING
  // -------------------------------------------------------------

  /// Evaluates an SMS message and either auto-records it or puts it into the review queue.
  /// Strictly prevents duplicate insertions and duplicate notifications.
  Future<SyncResult> processAndReconcileSms(
    String text, {
    String? senderShortCode,
  }) async {
    final parsed = parseSms(text);
    final now = DateTime.now();
    final fingerprint =
        parsed?.generateDeduplicationFingerprint() ??
        'raw_${text.hashCode}_${now.millisecondsSinceEpoch}';

    final db = await DatabaseHelper.instance.database;

    // 1. Deduplication check: Check sms_import_logs table first
    final existingLogs = await db.query(
      'sms_import_logs',
      where: 'fingerprint = ?',
      whereArgs: [fingerprint],
      limit: 1,
    );

    if (existingLogs.isNotEmpty) {
      final prevLog = SmsImportLog.fromMap(existingLogs.first);
      return SyncResult(
        status: SmsImportStatus.duplicate,
        log: prevLog,
        message: 'Transaction has already been processed previously (Duplicate prevented).',
      );
    }

    // Check if the message is non-financial or failed
    if (parsed == null || !parsed.isCompletedFinancialTransaction) {
      final log = SmsImportLog(
        id: const Uuid().v4(),
        sender: senderShortCode ?? parsed?.provider.name ?? 'Unknown',
        amountCents: parsed?.amountCents ?? 0,
        fingerprint: fingerprint,
        transactionType: parsed?.transactionType.name ?? 'unsupported',
        status:
            parsed?.transactionType == SmsTransactionType.nonFinancialOrOtp ||
                parsed?.transactionType == SmsTransactionType.balanceInquiry
            ? SmsImportStatus.ignored
            : SmsImportStatus.unsupported,
        confidence: parsed?.confidence.name ?? 'low',
        reviewReason:
            parsed?.reviewReason ?? 'Non-financial or unrecognized format',
        rawPreview: text.length > 80 ? '${text.substring(0, 80)}...' : text,
        createdAt: now,
      );
      await db.insert('sms_import_logs', log.toMap());
      return SyncResult(
        status: log.status,
        log: log,
        message: log.reviewReason ?? 'Message ignored.',
      );
    }

    // 2. Account Matching
    final matchedAccount = await _matchAccount(parsed);

    // 3. User setting check: Is auto-recording enabled for high confidence?
    final settingsRows = await db.query(
      'sms_tracker_settings',
      where: "key = 'auto_record_high_confidence'",
      limit: 1,
    );
    final autoRecordEnabled =
        settingsRows.isNotEmpty && settingsRows.first['value'] == '1';

    // Check duplicate against existing transactions table by reference or (amount + date window)
    final isTxDuplicate = await _checkTransactionDuplicate(parsed);
    if (isTxDuplicate) {
      final log = SmsImportLog(
        id: const Uuid().v4(),
        sender: senderShortCode ?? parsed.provider.name,
        accountSuffix: parsed.accountSuffix,
        amountCents: parsed.amountCents,
        feeCents: parsed.feeCents,
        reportedBalanceCents: parsed.reportedBalanceCents,
        referenceNumber: parsed.referenceNumber,
        fingerprint: fingerprint,
        transactionType: parsed.transactionType.name,
        status: SmsImportStatus.duplicate,
        matchedAccountId: matchedAccount?.id,
        reviewReason: 'Matching transaction with identical amount & reference already exists in accounts',
        confidence: parsed.confidence.name,
        rawPreview: text.length > 80 ? '${text.substring(0, 80)}...' : text,
        createdAt: now,
      );
      await db.insert('sms_import_logs', log.toMap());
      return SyncResult(
        status: SmsImportStatus.duplicate,
        log: log,
        message: 'A transaction with this reference/amount already exists in your records.',
      );
    }

    // Decide whether to auto-record or queue for review
    final canAutoRecord =
        autoRecordEnabled &&
        parsed.confidence == ParsingConfidence.high &&
        matchedAccount != null &&
        parsed.amountCents > 0;

    if (canAutoRecord) {
      // 4. Look up learned category for merchant
      final categoryId = await _lookupLearnedCategory(parsed.partyOrMerchant);

      final txId = const Uuid().v4();
      final financialTx = FinancialTransaction(
        id: txId,
        accountId: matchedAccount.id,
        destinationAccountId: null,
        type: parsed.isMoneyIn
            ? TransactionType.income
            : TransactionType.expense,
        amount: parsed.amountCents,
        categoryId: categoryId,
        description: parsed.buildFactualDescription(),
        notes:
            'Auto-imported from ${parsed.providerDisplayName}. Ref: ${parsed.referenceNumber ?? "N/A"}'
            '${parsed.reportedBalanceCents != null ? " • Reported Balance: ETB ${(parsed.reportedBalanceCents! / 100).toStringAsFixed(2)}" : ""}',
        transactionDate: parsed.transactionDate ?? now,
        reviewStatus: ReviewStatus.needsReview,
        createdAt: now,
        updatedAt: now,
      );

      await db.insert('transactions', financialTx.toMap());

      // If there's a separate fee, insert fee transaction
      if (parsed.feeCents > 0) {
        final feeTx = FinancialTransaction(
          id: const Uuid().v4(),
          accountId: matchedAccount.id,
          destinationAccountId: null,
          type: TransactionType.expense,
          amount: parsed.feeCents,
          categoryId: null,
          description: 'Bank service fee (${parsed.providerDisplayName})',
          notes: 'Fee for transaction ref ${parsed.referenceNumber ?? "N/A"}',
          transactionDate: parsed.transactionDate ?? now,
          reviewStatus:
              ReviewStatus.reviewed, // Service fees are pre-categorized
          createdAt: now,
          updatedAt: now,
        );
        await db.insert('transactions', feeTx.toMap());
      }

      // Reconcile bank-reported balance snapshot safely if present
      if (parsed.reportedBalanceCents != null) {
        await AccountBalanceService.instance.reconcileBankReportedBalance(
          accountId: matchedAccount.id,
          reportedBalanceCents: parsed.reportedBalanceCents!,
          snapshotTime: parsed.transactionDate ?? now,
          executor: db,
        );
      }

      final log = SmsImportLog(
        id: const Uuid().v4(),
        sender: senderShortCode ?? parsed.provider.name,
        accountSuffix: parsed.accountSuffix,
        amountCents: parsed.amountCents,
        feeCents: parsed.feeCents,
        reportedBalanceCents: parsed.reportedBalanceCents,
        referenceNumber: parsed.referenceNumber,
        fingerprint: fingerprint,
        transactionType: parsed.transactionType.name,
        status: SmsImportStatus.autoRecorded,
        matchedAccountId: matchedAccount.id,
        linkedTransactionId: txId,
        confidence: parsed.confidence.name,
        rawPreview: text.length > 80 ? '${text.substring(0, 80)}...' : text,
        createdAt: now,
      );
      await db.insert('sms_import_logs', log.toMap());

      return SyncResult(
        status: SmsImportStatus.autoRecorded,
        transaction: financialTx,
        log: log,
        message: 'Transaction successfully recorded to ${matchedAccount.name}.',
      );
    } else {
      // Send to review queue
      final reviewReason = matchedAccount == null
          ? 'No matching app account found. Please assign an account.'
          : (parsed.confidence != ParsingConfidence.high
                ? 'Parsing confidence requires confirmation.'
                : 'Auto-recording is disabled in settings. Confirm to add.');

      final log = SmsImportLog(
        id: const Uuid().v4(),
        sender: senderShortCode ?? parsed.provider.name,
        accountSuffix: parsed.accountSuffix,
        amountCents: parsed.amountCents,
        feeCents: parsed.feeCents,
        reportedBalanceCents: parsed.reportedBalanceCents,
        referenceNumber: parsed.referenceNumber,
        fingerprint: fingerprint,
        transactionType: parsed.transactionType.name,
        status: SmsImportStatus.pendingReview,
        matchedAccountId: matchedAccount?.id,
        reviewReason: reviewReason,
        confidence: parsed.confidence.name,
        rawPreview: text.length > 80 ? '${text.substring(0, 80)}...' : text,
        createdAt: now,
      );
      await db.insert('sms_import_logs', log.toMap());

      return SyncResult(
        status: SmsImportStatus.pendingReview,
        log: log,
        message: reviewReason,
      );
    }
  }

  /// Confirms a pending review log and saves it into transactions
  Future<FinancialTransaction?> confirmPendingImport({
    required SmsImportLog log,
    required String accountId,
    String? categoryId,
    String? customDescription,
    String? merchantToLearn,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();

      final isCredit =
          log.transactionType == SmsTransactionType.incomingTransfer.name ||
          log.transactionType == SmsTransactionType.cashDeposit.name ||
          log.transactionType == SmsTransactionType.interestReceived.name;

      final txId = const Uuid().v4();
      final financialTx = FinancialTransaction(
        id: txId,
        accountId: accountId,
        destinationAccountId: null,
        type: isCredit ? TransactionType.income : TransactionType.expense,
        amount: log.amountCents,
        categoryId: categoryId,
        description: customDescription ?? 'Bank SMS Import (${log.sender})',
        notes:
            'Confirmed from Bank SMS. Ref: ${log.referenceNumber ?? "N/A"}'
            '${log.reportedBalanceCents != null ? " • Reported Balance: ETB ${(log.reportedBalanceCents! / 100).toStringAsFixed(2)}" : ""}',
        transactionDate: log.createdAt,
        reviewStatus: (categoryId != null || customDescription != null)
            ? ReviewStatus.reviewed
            : ReviewStatus.needsReview,
        createdAt: now,
        updatedAt: now,
      );

      await db.insert('transactions', financialTx.toMap());

      // If there's a separate fee, insert fee transaction
      if (log.feeCents > 0) {
        final feeTx = FinancialTransaction(
          id: const Uuid().v4(),
          accountId: accountId,
          destinationAccountId: null,
          type: TransactionType.expense,
          amount: log.feeCents,
          categoryId: null,
          description: 'Bank service fee (${log.sender})',
          notes: 'Fee for transaction ref ${log.referenceNumber ?? "N/A"}',
          transactionDate: log.createdAt,
          reviewStatus: ReviewStatus.reviewed,
          createdAt: now,
          updatedAt: now,
        );
        await db.insert('transactions', feeTx.toMap());
      }

      // Reconcile bank-reported balance snapshot safely if present
      if (log.reportedBalanceCents != null) {
        await AccountBalanceService.instance.reconcileBankReportedBalance(
          accountId: accountId,
          reportedBalanceCents: log.reportedBalanceCents!,
          snapshotTime: log.createdAt,
          executor: db,
        );
      }

      // If user selected a category and gave merchant name, learn the rule
      if (categoryId != null &&
          merchantToLearn != null &&
          merchantToLearn.trim().isNotEmpty) {
        await learnCategoryRule(merchantToLearn.trim(), categoryId);
      }

      // Update import log
      await db.update(
        'sms_import_logs',
        {
          'status': SmsImportStatus.confirmed.name,
          'matched_account_id': accountId,
          'linked_transaction_id': txId,
        },
        where: 'id = ?',
        whereArgs: [log.id],
      );

      return financialTx;
    } catch (_) {
      return null;
    }
  }

  /// Matches parsed bank/account suffix to existing user accounts
  Future<Account?> _matchAccount(ParsedSmsTransaction parsed) async {
    final db = await DatabaseHelper.instance.database;

    // 1. Check explicit mappings in sms_account_mappings
    if (parsed.accountSuffix != null && parsed.accountSuffix!.isNotEmpty) {
      final mappings = await db.query(
        'sms_account_mappings',
        where: 'bank_code = ? AND account_suffix = ?',
        whereArgs: [parsed.provider.name, parsed.accountSuffix],
        limit: 1,
      );
      if (mappings.isNotEmpty) {
        final targetAccId = mappings.first['account_id'] as String;
        final accMap = await db.query(
          'accounts',
          where: 'id = ? AND is_archived = 0',
          whereArgs: [targetAccId],
        );
        if (accMap.isNotEmpty) {
          return Account.fromMap(accMap.first);
        }
      }
    }

    // 2. Fallback matching by provider name in account name or type
    final accMaps = await db.query('accounts', where: 'is_archived = 0');
    final accounts = accMaps.map((e) => Account.fromMap(e)).toList();
    if (accounts.isEmpty) return null;

    final providerQuery = parsed.provider == EthiopianBankProvider.cbe
        ? 'cbe'
        : parsed.provider == EthiopianBankProvider.telebirr
        ? 'telebirr'
        : parsed.provider == EthiopianBankProvider.awash
        ? 'awash'
        : parsed.provider == EthiopianBankProvider.abyssinia
        ? 'abyssinia'
        : parsed.provider == EthiopianBankProvider.dashen
        ? 'dashen'
        : '';

    if (providerQuery.isNotEmpty) {
      for (final a in accounts) {
        if (a.name.toLowerCase().contains(providerQuery) ||
            a.accountType.toLowerCase().contains(providerQuery)) {
          return a;
        }
      }
    }

    // Default to main profile account or first account
    final profileRows = await db.query('user_profiles', limit: 1);
    if (profileRows.isNotEmpty) {
      final mainId = profileRows.first['main_account_id'] as String?;
      if (mainId != null) {
        final mainAcc = accounts.where((a) => a.id == mainId);
        if (mainAcc.isNotEmpty) return mainAcc.first;
      }
    }

    return accounts.first;
  }

  /// Checks if a transaction with identical reference or amount+window exists
  Future<bool> _checkTransactionDuplicate(ParsedSmsTransaction parsed) async {
    final db = await DatabaseHelper.instance.database;

    if (parsed.referenceNumber != null &&
        parsed.referenceNumber!.isNotEmpty &&
        parsed.referenceNumber != 'N/A') {
      final existingByRef = await db.query(
        'transactions',
        where: "notes LIKE ?",
        whereArgs: ['%${parsed.referenceNumber}%'],
        limit: 1,
      );
      if (existingByRef.isNotEmpty) return true;
    }

    final txDate = parsed.transactionDate ?? DateTime.now();
    final dayStart = DateTime(
      txDate.year,
      txDate.month,
      txDate.day,
    ).toIso8601String();
    final dayEnd = DateTime(
      txDate.year,
      txDate.month,
      txDate.day,
      23,
      59,
      59,
    ).toIso8601String();
    final existingDuplicate = await db.query(
      'transactions',
      where: "amount = ? AND transaction_date >= ? AND transaction_date <= ?",
      whereArgs: [parsed.amountCents, dayStart, dayEnd],
      limit: 1,
    );
    return existingDuplicate.isNotEmpty;
  }

  /// Learns a local category rule for future matching
  Future<void> learnCategoryRule(String keyword, String categoryId) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('sms_category_rules', {
      'id': const Uuid().v4(),
      'keyword': keyword.toLowerCase().trim(),
      'category_id': categoryId,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Looks up learned category rules
  Future<String?> _lookupLearnedCategory(String? merchant) async {
    if (merchant == null || merchant.trim().isEmpty) return null;
    final db = await DatabaseHelper.instance.database;
    final lower = merchant.toLowerCase().trim();

    final rules = await db.query('sms_category_rules');
    for (final rule in rules) {
      final kw = (rule['keyword'] as String).toLowerCase();
      if (lower.contains(kw)) {
        return rule['category_id'] as String;
      }
    }
    return null;
  }

  // -------------------------------------------------------------
  // REGEX & DATA EXTRACTION UTILITIES
  // -------------------------------------------------------------

  bool _isNonFinancialOrSecurity(String text) {
    return text.contains('otp') ||
        text.contains('one time password') ||
        text.contains('verification code') ||
        text.contains('security code') ||
        text.contains('do not share') ||
        text.contains('login alert') ||
        text.contains('password changed') ||
        text.contains('pin changed') ||
        text.contains('welcome to') &&
            !text.contains('credited') &&
            !text.contains('debited');
  }

  bool _isBalanceInquiry(String text) {
    final hasBalance =
        text.contains('balance is') ||
        text.contains('current balance') ||
        text.contains('available balance');
    final hasTx =
        text.contains('debited') ||
        text.contains('credited') ||
        text.contains('paid') ||
        text.contains('received') ||
        text.contains('withdrawn') ||
        text.contains('transferred');
    return hasBalance && !hasTx;
  }

  bool _isFailedTransaction(String text) {
    return text.contains('failed') ||
        text.contains('declined') ||
        text.contains('unsuccessful') ||
        text.contains('could not be processed') ||
        text.contains('insufficient balance') ||
        text.contains('transaction cancelled');
  }

  EthiopianBankProvider _detectProvider(String text) {
    if (text.contains('cbe') || text.contains('commercial bank')) {
      return EthiopianBankProvider.cbe;
    }
    if (text.contains('telebirr')) {
      return EthiopianBankProvider.telebirr;
    }
    if (text.contains('awash')) {
      return EthiopianBankProvider.awash;
    }
    if (text.contains('abyssinia') || text.contains('boa')) {
      return EthiopianBankProvider.abyssinia;
    }
    if (text.contains('dashen') || text.contains('amole')) {
      return EthiopianBankProvider.dashen;
    }
    return EthiopianBankProvider.unknown;
  }

  int? _extractPrimaryAmount(String text) {
    // Looks for ETB / Birr / Br followed or preceded by decimal amount, with or without space
    final regex = RegExp(
      r'(?:etb|birr|br\.?)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      return _parseAmountToCents(match.group(1));
    }

    final reverseRegex = RegExp(
      r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:etb|birr|br\.?)',
      caseSensitive: false,
    );
    final matchRev = reverseRegex.firstMatch(text);
    if (matchRev != null) {
      return _parseAmountToCents(matchRev.group(1));
    }
    return null;
  }

  int? _extractAmountAfterKeywords(String text, List<String> keywords) {
    for (final kw in keywords) {
      final pattern = RegExp(
        '$kw\\s+(?:with|by|of)?\\s*(?:etb|birr|br\\.?)?\\s*([0-9,]+(?:\\.[0-9]{1,2})?)',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(text);
      if (match != null) {
        return _parseAmountToCents(match.group(1));
      }
    }
    return null;
  }

  int _extractSeparateFee(String text) {
    // Check if total fee is indicated e.g. "with total of ETB200.61" or "including Service charge..."
    // Matches explicit fee / service charge clauses
    final feeRegex = RegExp(
      r'(?:fee|service charge|charge)\s*(?:is|of|:)?\s*(?:etb|birr|br\.?)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );
    final match = feeRegex.firstMatch(text);
    if (match != null) {
      return _parseAmountToCents(match.group(1)) ?? 0;
    }
    return 0;
  }

  int? _extractReportedBalance(String text) {
    final balRegex = RegExp(
      r'(?:balance is|current balance|available balance|new balance)\s*(?:is|:)?\s*(?:etb|birr|br\.?)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );
    final match = balRegex.firstMatch(text);
    if (match != null) {
      return _parseAmountToCents(match.group(1));
    }
    return null;
  }

  String? _extractAccount(String text) {
    // Matches account formats like 1000123456, 1**2313, 1****2313, 01320098765400
    final accRegex = RegExp(
      r'(?:account|acc\.?|a/c)\s*(?:no\.?)?\s*([0-9*X\-]{4,20})',
      caseSensitive: false,
    );
    final match = accRegex.firstMatch(text);
    if (match != null) {
      final raw = match.group(1)!;
      // If masked e.g. 1**2313 or 1****2313, extract the trailing digits
      if (raw.contains('*')) {
        final lastDigits = RegExp(r'([0-9]{3,4})$').firstMatch(raw);
        if (lastDigits != null) {
          return '...${lastDigits.group(1)}';
        }
        return raw;
      }
      // Mask if longer than 4 digits
      if (raw.length > 4) {
        return '...${raw.substring(raw.length - 4)}';
      }
      return raw;
    }
    return null;
  }

  String? _extractReference(String text) {
    // 1. Check for CBE digital receipt URL format: https://mbreciept.cbe.com.et/v2-hfHCxHzZw3nl5PujC2Gx
    final cbeUrlMatch = RegExp(
      r'mbreciept\.cbe\.com\.et/([A-Za-z0-9\-_]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (cbeUrlMatch != null) {
      return cbeUrlMatch.group(1);
    }

    // 2. Short URL receipts: https://shorturl.at/auUX0
    final shortUrlMatch = RegExp(
      r'shorturl\.at/([A-Za-z0-9\-_]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (shortUrlMatch != null) {
      return 'short_${shortUrlMatch.group(1)}';
    }

    // 3. Standard text references
    final refRegex = RegExp(
      r'(?:transaction (?:number|id|ref) is|txn:?|ref:?|reference:?|trans\.? no\.?)\s*([A-Za-z0-9]+)',
      caseSensitive: false,
    );
    final match = refRegex.firstMatch(text);
    return match?.group(1);
  }

  DateTime? _extractDate(String text) {
    final dateRegex = RegExp(r'([0-9]{1,4}[-/.][0-9]{1,2}[-/.][0-9]{1,4})');
    final match = dateRegex.firstMatch(text);
    if (match == null) return null;

    final dateStr = match.group(1)!;
    final formats = [
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'yyyy-MM-dd',
      'dd-MM-yyyy',
      'd/M/yyyy',
    ];
    for (final f in formats) {
      try {
        return DateFormat(f).parse(dateStr);
      } catch (_) {}
    }
    return null;
  }

  int? _parseAmountToCents(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(',', '').trim();
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return null;
    return (parsed * 100).round();
  }
}

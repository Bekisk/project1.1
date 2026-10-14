enum SmsTransactionType {
  incomingTransfer,
  cashDeposit,
  outgoingTransfer,
  atmWithdrawal,
  cardPayment,
  merchantPayment,
  mobileMoneyPayment,
  bankServiceFee,
  interestReceived,
  reversalOrRefund,
  failedTransaction,
  pendingTransaction,
  balanceInquiry,
  nonFinancialOrOtp,
  other,
}

enum EthiopianBankProvider {
  cbe,
  telebirr,
  awash,
  abyssinia,
  dashen,
  unknown,
}

enum ParsingConfidence {
  high,
  medium,
  low,
}

class ParsedSmsTransaction {
  final EthiopianBankProvider provider;
  final SmsTransactionType transactionType;
  final bool isMoneyIn; // true = incoming (credit), false = outgoing (debit)
  final int amountCents; // Primary transaction amount in cents (e.g. 500.00 ETB = 50000)
  final int feeCents; // Separately stated fee in cents (e.g. 15.00 ETB = 1500)
  final int? reportedBalanceCents; // Bank-reported balance after transaction
  final String currencyCode; // e.g. 'ETB'
  final String? accountSuffix; // Masked or short account number (e.g. '...1234')
  final String? partyOrMerchant; // Recipient, sender, merchant or service
  final DateTime? transactionDate;
  final String? referenceNumber; // Bank reference or transaction ID
  final String rawMessage;
  final ParsingConfidence confidence;
  final String? reviewReason;
  final List<String> unidentifiedFields;

  const ParsedSmsTransaction({
    required this.provider,
    required this.transactionType,
    required this.isMoneyIn,
    required this.amountCents,
    this.feeCents = 0,
    this.reportedBalanceCents,
    this.currencyCode = 'ETB',
    this.accountSuffix,
    this.partyOrMerchant,
    this.transactionDate,
    this.referenceNumber,
    required this.rawMessage,
    this.confidence = ParsingConfidence.medium,
    this.reviewReason,
    this.unidentifiedFields = const [],
  });

  /// True if this represents a confirmed, completed financial cashflow transaction
  bool get isCompletedFinancialTransaction {
    if (amountCents <= 0) return false;
    switch (transactionType) {
      case SmsTransactionType.incomingTransfer:
      case SmsTransactionType.cashDeposit:
      case SmsTransactionType.outgoingTransfer:
      case SmsTransactionType.atmWithdrawal:
      case SmsTransactionType.cardPayment:
      case SmsTransactionType.merchantPayment:
      case SmsTransactionType.mobileMoneyPayment:
      case SmsTransactionType.bankServiceFee:
      case SmsTransactionType.interestReceived:
      case SmsTransactionType.reversalOrRefund:
      case SmsTransactionType.other:
        return true;
      case SmsTransactionType.failedTransaction:
      case SmsTransactionType.pendingTransaction:
      case SmsTransactionType.balanceInquiry:
      case SmsTransactionType.nonFinancialOrOtp:
        return false;
    }
  }

  String get providerDisplayName {
    switch (provider) {
      case EthiopianBankProvider.cbe:
        return 'Commercial Bank of Ethiopia (CBE)';
      case EthiopianBankProvider.telebirr:
        return 'Telebirr';
      case EthiopianBankProvider.awash:
        return 'Awash Bank';
      case EthiopianBankProvider.abyssinia:
        return 'Bank of Abyssinia';
      case EthiopianBankProvider.dashen:
        return 'Dashen Bank';
      case EthiopianBankProvider.unknown:
        return 'Bank SMS';
    }
  }

  String get typeDisplayName {
    switch (transactionType) {
      case SmsTransactionType.incomingTransfer:
        return 'Incoming Transfer';
      case SmsTransactionType.cashDeposit:
        return 'Cash Deposit';
      case SmsTransactionType.outgoingTransfer:
        return 'Outgoing Transfer';
      case SmsTransactionType.atmWithdrawal:
        return 'ATM Withdrawal';
      case SmsTransactionType.cardPayment:
        return 'Card Payment';
      case SmsTransactionType.merchantPayment:
        return 'Merchant Payment';
      case SmsTransactionType.mobileMoneyPayment:
        return 'Mobile Money Payment';
      case SmsTransactionType.bankServiceFee:
        return 'Bank Service Fee';
      case SmsTransactionType.interestReceived:
        return 'Interest Received';
      case SmsTransactionType.reversalOrRefund:
        return 'Reversal / Refund';
      case SmsTransactionType.failedTransaction:
        return 'Failed Transaction';
      case SmsTransactionType.pendingTransaction:
        return 'Pending Transaction';
      case SmsTransactionType.balanceInquiry:
        return 'Balance Inquiry';
      case SmsTransactionType.nonFinancialOrOtp:
        return 'Non-Financial / OTP';
      case SmsTransactionType.other:
        return isMoneyIn ? 'Income' : 'Expense';
    }
  }

  double get amountInEtb => amountCents / 100.0;
  double get feeInEtb => feeCents / 100.0;
  double? get reportedBalanceInEtb =>
      reportedBalanceCents != null ? (reportedBalanceCents! / 100.0) : null;

  /// Synthesizes a factual, clear transaction description without guessing unknown reasons
  String buildFactualDescription() {
    if (partyOrMerchant != null && partyOrMerchant!.trim().isNotEmpty) {
      if (transactionType == SmsTransactionType.incomingTransfer) {
        return 'Received from ${partyOrMerchant!.trim()}';
      } else if (transactionType == SmsTransactionType.outgoingTransfer) {
        return 'Transfer to ${partyOrMerchant!.trim()}';
      } else if (transactionType == SmsTransactionType.merchantPayment ||
          transactionType == SmsTransactionType.cardPayment) {
        return 'Paid to ${partyOrMerchant!.trim()}';
      } else if (transactionType == SmsTransactionType.atmWithdrawal) {
        return 'ATM withdrawal at ${partyOrMerchant!.trim()}';
      }
      return partyOrMerchant!.trim();
    }

    switch (transactionType) {
      case SmsTransactionType.incomingTransfer:
        return 'Received transfer';
      case SmsTransactionType.cashDeposit:
        return 'Cash deposit';
      case SmsTransactionType.outgoingTransfer:
        return 'Transferred money to another account';
      case SmsTransactionType.atmWithdrawal:
        return 'ATM withdrawal';
      case SmsTransactionType.bankServiceFee:
        return 'Bank service fee';
      case SmsTransactionType.reversalOrRefund:
        return 'Received refund / reversal';
      case SmsTransactionType.interestReceived:
        return 'Bank interest earned';
      case SmsTransactionType.merchantPayment:
      case SmsTransactionType.cardPayment:
      case SmsTransactionType.mobileMoneyPayment:
        return 'Payment to merchant';
      default:
        return isMoneyIn ? 'Money received' : 'Money deducted';
    }
  }

  /// Generates a deterministic deduplication fingerprint
  String generateDeduplicationFingerprint() {
    final ref = (referenceNumber ?? '').trim().toLowerCase();
    if (ref.isNotEmpty && ref != 'n/a') {
      return '${provider.name}_ref_$ref';
    }

    final dateKey = transactionDate != null
        ? '${transactionDate!.year}${transactionDate!.month.toString().padLeft(2, '0')}${transactionDate!.day.toString().padLeft(2, '0')}'
        : 'nodate';
    final acc = (accountSuffix ?? 'noacc').trim().toLowerCase();
    return '${provider.name}_${acc}_${amountCents}_${isMoneyIn ? 1 : 0}_$dateKey';
  }
}

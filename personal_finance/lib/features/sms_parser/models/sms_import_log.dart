enum SmsImportStatus {
  autoRecorded,
  pendingReview,
  confirmed,
  duplicate,
  unsupported,
  ignored,
}

class SmsImportLog {
  final String id;
  final String sender;
  final String? accountSuffix;
  final int amountCents;
  final int feeCents;
  final int? reportedBalanceCents;
  final String? referenceNumber;
  final String fingerprint;
  final String transactionType;
  final SmsImportStatus status;
  final String? matchedAccountId;
  final String? linkedTransactionId;
  final String? reviewReason;
  final String confidence;
  final String rawPreview;
  final DateTime createdAt;

  const SmsImportLog({
    required this.id,
    required this.sender,
    this.accountSuffix,
    required this.amountCents,
    this.feeCents = 0,
    this.reportedBalanceCents,
    this.referenceNumber,
    required this.fingerprint,
    required this.transactionType,
    required this.status,
    this.matchedAccountId,
    this.linkedTransactionId,
    this.reviewReason,
    required this.confidence,
    required this.rawPreview,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'account_suffix': accountSuffix,
      'amount_cents': amountCents,
      'fee_cents': feeCents,
      'reported_balance_cents': reportedBalanceCents,
      'reference_number': referenceNumber,
      'fingerprint': fingerprint,
      'transaction_type': transactionType,
      'status': status.name,
      'matched_account_id': matchedAccountId,
      'linked_transaction_id': linkedTransactionId,
      'review_reason': reviewReason,
      'confidence': confidence,
      'raw_preview': rawPreview,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SmsImportLog.fromMap(Map<String, dynamic> map) {
    return SmsImportLog(
      id: map['id'] as String,
      sender: map['sender'] as String,
      accountSuffix: map['account_suffix'] as String?,
      amountCents: map['amount_cents'] as int? ?? 0,
      feeCents: map['fee_cents'] as int? ?? 0,
      reportedBalanceCents: map['reported_balance_cents'] as int?,
      referenceNumber: map['reference_number'] as String?,
      fingerprint: map['fingerprint'] as String,
      transactionType: map['transaction_type'] as String? ?? 'other',
      status: SmsImportStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SmsImportStatus.pendingReview,
      ),
      matchedAccountId: map['matched_account_id'] as String?,
      linkedTransactionId: map['linked_transaction_id'] as String?,
      reviewReason: map['review_reason'] as String?,
      confidence: map['confidence'] as String? ?? 'medium',
      rawPreview: map['raw_preview'] as String? ?? '',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

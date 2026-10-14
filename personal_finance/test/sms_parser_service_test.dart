import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/sms_parser/models/parsed_sms_transaction.dart';
import 'package:personal_finance/features/sms_parser/services/sms_parser_service.dart';

void main() {
  group('Comprehensive Bank SMS Transaction Tracker Tests', () {
    final parser = SmsParserService.instance;

    // 1. Completed Incoming Transfer
    test('Scenario 1: Completed incoming transfer parses amount, currency, and sender', () {
      const sms = 'Dear Abebe, your account 1000123456 has been credited with ETB 25,000.00 on 10/10/2026 by Tech Salary. Balance is ETB 45,000.00.';
      final parsed = parser.parseSms(sms);

      expect(parsed, isNotNull);
      expect(parsed!.provider, EthiopianBankProvider.cbe);
      expect(parsed.isMoneyIn, isTrue);
      expect(parsed.amountCents, 2500000);
      expect(parsed.amountInEtb, 25000.0);
      expect(parsed.accountSuffix, '...3456');
      expect(parsed.reportedBalanceCents, 4500000);
      expect(parsed.reportedBalanceInEtb, 45000.0);
      expect(parsed.isCompletedFinancialTransaction, isTrue);
    });

    // 2. Completed Outgoing Transfer
    test('Scenario 2: Completed outgoing transfer parses amount, direction, and merchant', () {
      const sms = 'Dear Abebe, your account 1000123456 has been debited with ETB 653.00 on 12/10/2026 for Groceries. Balance is ETB 4,500.00.';
      final parsed = parser.parseSms(sms);

      expect(parsed, isNotNull);
      expect(parsed!.provider, EthiopianBankProvider.cbe);
      expect(parsed.isMoneyIn, isFalse);
      expect(parsed.amountCents, 65300);
      expect(parsed.amountInEtb, 653.0);
      expect(parsed.partyOrMerchant?.toLowerCase(), contains('groceries'));
      expect(parsed.reportedBalanceCents, 450000);
      expect(parsed.isCompletedFinancialTransaction, isTrue);
    });

    // 3. ATM Withdrawal
    test('Scenario 3: ATM withdrawal identifies withdrawal type without double charging', () {
      const sms = 'Dear Customer, your account 1000987654 was debited ETB 4,000.00 withdrawn from ATM on 11/10/2026. Ref: ATM7812.';
      final parsed = parser.parseSms(sms);

      expect(parsed, isNotNull);
      expect(parsed!.transactionType, SmsTransactionType.atmWithdrawal);
      expect(parsed.isMoneyIn, isFalse);
      expect(parsed.amountCents, 400000);
      expect(parsed.referenceNumber, 'ATM7812');
      expect(parsed.isCompletedFinancialTransaction, isTrue);
    });

    // 4. Merchant Payment
    test('Scenario 4: Merchant payment parses vendor and ref', () {
      const sms = 'You have paid ETB 450.50 to Cafe on 12/10/2026 14:32:00. Your transaction number is CI892345. Current balance is ETB 1,200.00.';
      final parsed = parser.parseSms(sms);

      expect(parsed, isNotNull);
      expect(parsed!.provider, EthiopianBankProvider.telebirr);
      expect(parsed.transactionType, SmsTransactionType.mobileMoneyPayment);
      expect(parsed.isMoneyIn, isFalse);
      expect(parsed.amountCents, 45050);
      expect(parsed.partyOrMerchant?.toLowerCase(), contains('cafe'));
      expect(parsed.referenceNumber, 'CI892345');
      expect(parsed.reportedBalanceCents, 120000);
      expect(parsed.isCompletedFinancialTransaction, isTrue);
    });

    // 5. Bank Service Fee
    test('Scenario 5: Bank service fee modeled as fee expense', () {
      const sms = 'Dear customer, service charge of ETB 25.00 has been debited from your account 1000123456 on 10/10/2026.';
      final parsed = parser.parseSms(sms);

      expect(parsed, isNotNull);
      expect(parsed!.transactionType, SmsTransactionType.bankServiceFee);
      expect(parsed.isMoneyIn, isFalse);
      expect(parsed.amountCents, 2500);
      expect(parsed.isCompletedFinancialTransaction, isTrue);
    });

    // 6. Transfer with Separate Fee
    test('Scenario 6: Transfer with separate fee models both without subtracting fee twice', () {
      const sms = 'You have transferred ETB 1,000.00 to Abebe on 12/10/2026. Fee is ETB 15.00. Txn: TB99281. Current balance is ETB 5,000.00.';
      final parsed = parser.parseSms(sms);

      expect(parsed, isNotNull);
      expect(parsed!.amountCents, 100000); // 1,000.00 ETB
      expect(parsed.feeCents, 1500); // 15.00 ETB
      expect(parsed.reportedBalanceCents, 500000);
      expect(parsed.feeInEtb, 15.0);
    });

    // 7. Refund / Reversal
    test('Scenario 7 & 8: Refund or reversal recognized as reversalOrRefund', () {
      const sms = 'Dear Customer, your reversal of ETB 500.00 has been credited to account 1000123456 on 12/10/2026.';
      final parsed = parser.parseSms(sms);

      expect(parsed, isNotNull);
      expect(parsed!.transactionType, SmsTransactionType.reversalOrRefund);
      expect(parsed.isMoneyIn, isTrue);
      expect(parsed.amountCents, 50000);
    });

    // 9. Failed Transaction Guard
    test('Scenario 9: Failed or declined transaction rejected from booking', () {
      const sms = 'Transaction failed. Your payment of ETB 2,500.00 to Supermarket was declined due to insufficient balance.';
      final parsed = parser.parseSms(sms);

      expect(parsed, isNotNull);
      expect(parsed!.transactionType, SmsTransactionType.failedTransaction);
      expect(parsed.isCompletedFinancialTransaction, isFalse);
    });

    // 10. Balance Inquiry Guard
    test('Scenario 14: Balance inquiry alone does NOT create cash flow', () {
      const sms = 'Dear Customer, your current balance is ETB 12,450.00 for account 1000123456.';
      final parsed = parser.parseSms(sms);

      expect(parsed, isNotNull);
      expect(parsed!.transactionType, SmsTransactionType.balanceInquiry);
      expect(parsed.isCompletedFinancialTransaction, isFalse);
      expect(parsed.reportedBalanceCents, 1245000);
    });

    // 11. OTP / Security Message Guard
    test('Scenario 16: OTP and login codes strictly rejected from financial recording', () {
      const sms = 'Your one time password (OTP) is 849201 for CBE Mobile Banking. Do not share with anyone.';
      final parsed = parser.parseSms(sms);

      expect(parsed, isNotNull);
      expect(parsed!.transactionType, SmsTransactionType.nonFinancialOrOtp);
      expect(parsed.isCompletedFinancialTransaction, isFalse);
    });

    // 12. Promotional / Marketing SMS
    test('Scenario 15: Promotional text returns non-transactional or null', () {
      const sms = 'Welcome to Ethiopian Airlines! Book your domestic flights today and save up to 20%.';
      final parsed = parser.parseSms(sms);
      expect(parsed == null || !parsed.isCompletedFinancialTransaction, isTrue);
    });

    // 13. Bank of Abyssinia (BoA) Support
    test('BoA Parser extracts debited amount and account suffix', () {
      const sms = 'Bank of Abyssinia: Your account 20001234 has been debited by ETB 3,500.00 on 12/10/2026. Ref: BOA9912.';
      final parsed = parser.parseSms(sms);

      expect(parsed, isNotNull);
      expect(parsed!.provider, EthiopianBankProvider.abyssinia);
      expect(parsed.isMoneyIn, isFalse);
      expect(parsed.amountCents, 350000);
      expect(parsed.referenceNumber, 'BOA9912');
    });

    // 14. Awash Bank Support
    test('Awash Bank Parser extracts reason and account', () {
      const sms = 'Awash Bank: Your account 01320098765400 has been debited by ETB 1,500.00 on 12/10/2026. Reason: Supermarket.';
      final parsed = parser.parseSms(sms);

      expect(parsed, isNotNull);
      expect(parsed!.provider, EthiopianBankProvider.awash);
      expect(parsed.amountCents, 150000);
      expect(parsed.accountSuffix, '...5400');
    });

    // 15. Deduplication Fingerprint Stability
    test('Scenario 18 & 19: Deduplication fingerprint is identical for duplicate SMS', () {
      const sms1 = 'You have paid ETB 450.50 to Cafe on 12/10/2026 14:32:00. Your transaction number is CI892345.';
      const sms2 = 'You have paid ETB 450.50 to Cafe on 12/10/2026 14:32:00. Your transaction number is CI892345.';

      final parsed1 = parser.parseSms(sms1)!;
      final parsed2 = parser.parseSms(sms2)!;

      expect(parsed1.generateDeduplicationFingerprint(), parsed2.generateDeduplicationFingerprint());
      expect(parsed1.generateDeduplicationFingerprint(), 'telebirr_ref_ci892345');
    });

    // 16. Two legitimate transactions with same amount have different fingerprints if different dates/refs
    test('Scenario 18: Different transactions with same amount have distinct fingerprints', () {
      const tx1 = 'You have paid ETB 500.00 to Cafe. Txn: REF001.';
      const tx2 = 'You have paid ETB 500.00 to Taxi. Txn: REF002.';

      final p1 = parser.parseSms(tx1)!;
      final p2 = parser.parseSms(tx2)!;

      expect(p1.generateDeduplicationFingerprint(), isNot(equals(p2.generateDeduplicationFingerprint())));
    });

    // 17. Factual description synthesis
    test('Scenario 22: Synthesizes clean factual descriptions without fabricating user reasons', () {
      const smsNoParty = 'Dear Customer, your account has been debited with ETB 300.00 on 12/10/2026.';
      final parsed = parser.parseSms(smsNoParty)!;
      expect(parsed.buildFactualDescription(), 'Money deducted');
    });
  });
}

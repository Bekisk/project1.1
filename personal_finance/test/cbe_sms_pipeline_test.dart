import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/sms_parser/models/parsed_sms_transaction.dart';
import 'package:personal_finance/features/sms_parser/services/sms_parser_service.dart';

void main() {
  group('Mandatory CBE Detection & Processing Pipeline Tests (Tests A - G)', () {
    final parser = SmsParserService.instance;

    const exampleA =
        'Dear Bereket Anteneh Kassa You have received ETB 20,000.00 from account 1**6658 (Alemtshay Mekurya W/aregay) to your account 1**2313. Your current balance is ETB20,822.40. Thanks for Banking with CBE. https://mbreciept.cbe.com.et/v2-hfHCxHzZw3nl5PujC2Gx  for feedback: https://forms.gle/kGNGQpG3mQCCk3iD6';

    const exampleB =
        'Dear Bereket Anteneh Kassa You have successfully transferred ETB200.00 from account 1**2313 to account 1**9525 (Ethi.full Gos.ch. Haya Hulet M). Service charge of ETB 0.50 and VAT(15%) of ETB0.08 and Disaster Recovery(5%) of 0.03 with total of ETB200.61. Your current balance is ETB20,621.79. Thanks for Banking with CBE. https://mbreciept.cbe.com.et/v2-hfHCxHAlpPQoNHnmKA7C  for feedback: https://forms.gle/kGNGQpG3mQCCk3iD6';

    const exampleC =
        'Dear Mr Bereket your Account 1****2313 has been debited with ETB 200.85 including Service charge ETB0.70ETB0.04 and VAT(15%) ETB0.11. Your Current Balance is ETB 10434.47. Thank you for banking with CBE!. For feedback https://forms.gle/kGNGQpG3mQCCk3iD6';

    const exampleAtm =
        'Dear Customer, your account 1000987654 was debited ETB 4,000.00 withdrawn from ATM on 11/10/2026. Ref: ATM7812.';

    // Test A — Incoming transfer
    test('Test A: Incoming transfer parses as income of ETB 20,000 without confusing with balance', () {
      final parsed = parser.parseSms(exampleA);

      expect(parsed, isNotNull);
      expect(parsed!.provider, EthiopianBankProvider.cbe);
      expect(parsed.isMoneyIn, isTrue);
      expect(parsed.transactionType, SmsTransactionType.incomingTransfer);
      expect(parsed.amountCents, 2000000); // ETB 20,000.00
      expect(parsed.amountInEtb, 20000.0);
      expect(parsed.reportedBalanceCents, 2082240); // ETB 20,822.40
      expect(parsed.reportedBalanceInEtb, 20822.40);
      expect(parsed.accountSuffix, '...2313');
      expect(parsed.partyOrMerchant, 'Alemtshay Mekurya W/aregay');
      expect(parsed.referenceNumber, 'v2-hfHCxHzZw3nl5PujC2Gx');
      expect(parsed.isCompletedFinancialTransaction, isTrue);
      expect(
        parsed.buildFactualDescription(),
        'Received from Alemtshay Mekurya W/aregay',
      );
    });

    // Test B — Outgoing transfer
    test('Test B: Outgoing transfer preserves principal, stated fees, and total debit without double counting', () {
      final parsed = parser.parseSms(exampleB);

      expect(parsed, isNotNull);
      expect(parsed!.provider, EthiopianBankProvider.cbe);
      expect(parsed.isMoneyIn, isFalse);
      expect(parsed.transactionType, SmsTransactionType.outgoingTransfer);
      expect(parsed.amountCents, 20000); // ETB 200.00 principal
      expect(parsed.amountInEtb, 200.0);
      expect(parsed.feeCents, 61); // ETB 0.61 fee (total ETB 200.61)
      expect(parsed.feeInEtb, 0.61);
      // Ensure principal + fee = 200.61 (no double debiting to 400.61)
      expect((parsed.amountCents + parsed.feeCents) / 100.0, 200.61);
      expect(parsed.reportedBalanceCents, 2062179); // ETB 20,621.79
      expect(parsed.accountSuffix, '...2313');
      expect(parsed.partyOrMerchant, 'Ethi.full Gos.ch. Haya Hulet M');
      expect(parsed.referenceNumber, 'v2-hfHCxHAlpPQoNHnmKA7C');
      expect(parsed.isCompletedFinancialTransaction, isTrue);
      expect(
        parsed.buildFactualDescription(),
        'Transfer to Ethi.full Gos.ch. Haya Hulet M',
      );
    });

    // Test C — Generic debit
    test('Test C: Generic debit with fees parses total debit and balance, avoids fabricating recipient or transfer type', () {
      final parsed = parser.parseSms(exampleC);

      expect(parsed, isNotNull);
      expect(parsed!.provider, EthiopianBankProvider.cbe);
      expect(parsed.isMoneyIn, isFalse);
      expect(parsed.transactionType, SmsTransactionType.other); // generic debit
      expect(parsed.amountCents, 20085); // ETB 200.85 total debit
      expect(parsed.amountInEtb, 200.85);
      expect(parsed.feeCents, 0); // Not added a second time
      expect(parsed.reportedBalanceCents, 1043447); // ETB 10,434.47
      expect(parsed.accountSuffix, '...2313');
      expect(parsed.partyOrMerchant, isNull); // No invented recipient
      expect(parsed.buildFactualDescription(), 'Money deducted');
      expect(parsed.isCompletedFinancialTransaction, isTrue);
    });

    // Test D — Duplicate SMS fingerprint idempotency
    test('Test D: Processing identical SMS has identical deduplication fingerprint', () {
      final p1 = parser.parseSms(exampleA)!;
      final p2 = parser.parseSms(exampleA)!;

      expect(
        p1.generateDeduplicationFingerprint(),
        p2.generateDeduplicationFingerprint(),
      );
      expect(
        p1.generateDeduplicationFingerprint(),
        contains('v2-hfhcxhzzw3nl5pujc2gx'),
      );

      final pB1 = parser.parseSms(exampleB)!;
      final pB2 = parser.parseSms(exampleB)!;
      expect(
        pB1.generateDeduplicationFingerprint(),
        pB2.generateDeduplicationFingerprint(),
      );
    });

    // Test E — Existing ATM regression
    test('Test E: Existing working ATM message formats parse and maintain ATM withdrawal classification', () {
      final parsed = parser.parseSms(exampleAtm);

      expect(parsed, isNotNull);
      expect(parsed!.provider, EthiopianBankProvider.cbe);
      expect(parsed.transactionType, SmsTransactionType.atmWithdrawal);
      expect(parsed.isMoneyIn, isFalse);
      expect(parsed.amountCents, 400000);
      expect(parsed.referenceNumber, 'ATM7812');
      expect(parsed.isCompletedFinancialTransaction, isTrue);
    });

    // Test F — Negative and malformed cases
    test('Test F1: Unrelated SMS containing "CBE" does not become a financial transaction', () {
      const unrelated =
          'Dear customer, CBE wishes you a happy Ethiopian New Year! Enjoy peace and prosperity.';
      final parsed = parser.parseSms(unrelated);
      expect(parsed == null || !parsed.isCompletedFinancialTransaction, isTrue);
    });

    test('Test F2: Balance inquiry with no transaction amount is rejected from financial recording', () {
      const balanceOnly =
          'Dear Customer, your current balance is ETB 15,200.00 for account 1000123456. Thanks for Banking with CBE.';
      final parsed = parser.parseSms(balanceOnly);
      expect(parsed, isNotNull);
      expect(parsed!.transactionType, SmsTransactionType.balanceInquiry);
      expect(parsed.isCompletedFinancialTransaction, isFalse);
    });

    test('Test F3: URLs and feedback links do not corrupt parsing or reference extraction', () {
      const withUrls =
          'Dear Customer You have received ETB 500.00 to your account 1**2313. Your current balance is ETB 500.00. Thanks for Banking with CBE. https://mbreciept.cbe.com.et/v2-xyz123 for feedback: https://forms.gle/test';
      final parsed = parser.parseSms(withUrls);
      expect(parsed, isNotNull);
      expect(parsed!.amountCents, 50000);
      expect(parsed.referenceNumber, 'v2-xyz123');
      expect(parsed.isCompletedFinancialTransaction, isTrue);
    });
  });
}

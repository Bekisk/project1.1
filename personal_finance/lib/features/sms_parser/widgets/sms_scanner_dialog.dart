import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';

import '../models/parsed_sms_transaction.dart';
import '../services/sms_parser_service.dart';
import 'sms_quick_confirm_sheet.dart';

class SmsScannerDialog extends StatefulWidget {
  const SmsScannerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const SmsScannerDialog(),
    );
  }

  @override
  State<SmsScannerDialog> createState() => _SmsScannerDialogState();
}

class _SmsScannerDialogState extends State<SmsScannerDialog> {
  final TextEditingController _textController = TextEditingController();
  ParsedSmsTransaction? _parsedResult;
  bool _hasAttemptedParse = false;

  final List<Map<String, String>> _templates = [
    {
      'label': 'CBE Received',
      'text':
          'Dear Bereket Anteneh Kassa You have received ETB 20,000.00 from account 16658 (Alemtshay Mekurya W/aregay) to your account 12313. Your current balance is ETB20,822.40. Thanks for Banking with CBE.',
    },
    {
      'label': 'CBE Transferred',
      'text':
          'Dear Bereket Anteneh Kassa You have successfully transferred ETB200.00 from account 12313 to account 19525 (Ethi.full Gos.ch. Haya Hulet M). Service charge of ETB 0.50 and VAT(15%) of ETB0.08 and Disaster Recovery(5%) of 0.03 with total of ETB200.61. Your current balance is ETB20,621.79. Thanks for Banking with CBE.',
    },
    {
      'label': 'CBE Debit',
      'text':
          'Dear Mr Bereket your Account 1****2313 has been debited with ETB 200.85 including Service charge ETB0.70ETB0.04 and VAT(15%) ETB0.11. Your Current Balance is ETB 10434.47. Thank you for Banking with CBE!. For feedback https://shorturl.at/auUX0',
    },
    {
      'label': 'Telebirr Paid',
      'text':
          'You have paid ETB 450.00 to Cafe on 12/10/2026 14:32:00. Your transaction number is CI892345. Current balance is ETB 1200.00.',
    },
    {
      'label': 'Telebirr Received',
      'text':
          'You have received ETB 2,500.00 from 0911223344 on 11/10/2026. Txn: TB782193. Current balance is ETB 3700.00.',
    },
    {
      'label': 'Awash Bank',
      'text':
          'Awash Bank: Your account 01320098765400 has been debited by ETB 1,500.00 on 12/10/2026. Reason: Supermarket shopping.',
    },
  ];

  void _parseCurrentText() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _parsedResult = null;
        _hasAttemptedParse = true;
      });
      return;
    }

    final result = SmsParserService.instance.parseSms(text);
    setState(() {
      _parsedResult = result;
      _hasAttemptedParse = true;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.mark_email_read_rounded,
                    color: AppTheme.primaryGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SMS & Notification Parser',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'CBE, Awash & Telebirr Auto-Detector',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'Sample Bank Templates (Tap to test):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppTheme.textSecondaryDark
                    : AppTheme.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _templates.map((tpl) {
                return ActionChip(
                  label: Text(
                    tpl['label']!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.pureWhite : AppTheme.textDark,
                    ),
                  ),
                  backgroundColor: isDark
                      ? AppTheme.elevatedCharcoal
                      : const Color(0xFFF1F5F9),
                  side: BorderSide(
                    color: isDark ? AppTheme.borderPrimary : Colors.transparent,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onPressed: () {
                    _textController.text = tpl['text']!;
                    _parseCurrentText();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _textController,
              maxLines: 4,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Paste any SMS alert or notification string here...',
                hintStyle: TextStyle(
                  color: isDark ? AppTheme.tertiaryGray : Colors.black26,
                  fontSize: 12,
                ),
                filled: true,
                fillColor: isDark
                    ? AppTheme.inputCharcoal
                    : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppTheme.borderPrimary
                        : Colors.black.withOpacity(0.06),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppTheme.borderPrimary
                        : Colors.black.withOpacity(0.06),
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              onChanged: (_) => _parseCurrentText(),
            ),
            const SizedBox(height: 14),

            // Parse result preview
            if (_parsedResult != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.primaryGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_parsedResult!.providerDisplayName} Detected',
                          style: const TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Type: ${_parsedResult!.typeDisplayName}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Amount: ${CurrencyFormatter.formatCents(_parsedResult!.amountCents)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_parsedResult!.feeCents > 0)
                      Text(
                        'Separate Fee: ${CurrencyFormatter.formatCents(_parsedResult!.feeCents)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.accentAmber,
                        ),
                      ),
                    if (_parsedResult!.partyOrMerchant != null)
                      Text(
                        'Merchant/Party: ${_parsedResult!.partyOrMerchant}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    if (_parsedResult!.reportedBalanceCents != null)
                      Text(
                        'Bank Reported Balance: ${CurrencyFormatter.formatCents(_parsedResult!.reportedBalanceCents!)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.flash_on_rounded, size: 18),
                  label: const Text(
                    'Confirm & Auto-Log',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    SmsQuickConfirmSheet.show(
                      context,
                      parsedSms: _parsedResult!,
                    );
                  },
                ),
              ),
            ] else if (_hasAttemptedParse &&
                _textController.text.trim().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No matching transaction found. Ensure the message contains amounts in ETB/Birr.',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

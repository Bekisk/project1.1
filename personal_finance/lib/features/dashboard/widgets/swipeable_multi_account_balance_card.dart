import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/widgets/animated_balance_text.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/accounts/screens/accounts_management_screen.dart';

/// Representation of an account item for the Swipeable Multi-Account Balance Carousel
class AccountCardItem {
  final Account account;
  final int balance;
  final bool isMain;
  final bool isSavings;
  final String roleBadge;

  const AccountCardItem({
    required this.account,
    required this.balance,
    required this.isMain,
    required this.isSavings,
    required this.roleBadge,
  });

  String get bankDisplayName {
    // If the account name contains a well-known institution or name, display it cleanly
    final trimmed = account.name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    switch (account.accountType.toLowerCase()) {
      case 'bank':
        return 'Bank Account';
      case 'savings':
        return 'Savings Account';
      case 'mobile_money':
        return 'Mobile Money';
      case 'cash':
        return 'Cash Wallet';
      default:
        return 'Financial Account';
    }
  }

  String get subtitleLabel {
    if (isMain) return 'Main Account';
    if (isSavings) return 'Savings Account';
    switch (account.accountType.toLowerCase()) {
      case 'bank':
        return 'Bank Account';
      case 'savings':
        return 'Dedicated Savings';
      case 'mobile_money':
        return 'Mobile Wallet';
      case 'cash':
        return 'Physical Cash';
      default:
        return 'Active Account';
    }
  }
}

/// Premium Apple-inspired Liquid Glass Swipeable Multi-Account Balance Card
class SwipeableMultiAccountBalanceCard extends StatefulWidget {
  final List<Account> accounts;
  final Map<String, int> accountBalances;
  final String? mainAccountId;
  final String? designatedSavingsAccountId;
  final bool isDark;
  final VoidCallback? onAddAccount;

  const SwipeableMultiAccountBalanceCard({
    super.key,
    required this.accounts,
    required this.accountBalances,
    this.mainAccountId,
    this.designatedSavingsAccountId,
    required this.isDark,
    this.onAddAccount,
  });

  @override
  State<SwipeableMultiAccountBalanceCard> createState() =>
      _SwipeableMultiAccountBalanceCardState();
}

class _SwipeableMultiAccountBalanceCardState
    extends State<SwipeableMultiAccountBalanceCard> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isBalanceHidden = false;
  List<AccountCardItem> _items = [];

  @override
  void initState() {
    super.initState();
    _rebuildItems();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void didUpdateWidget(covariant SwipeableMultiAccountBalanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accounts != widget.accounts ||
        oldWidget.accountBalances != widget.accountBalances ||
        oldWidget.mainAccountId != widget.mainAccountId ||
        oldWidget.designatedSavingsAccountId !=
            widget.designatedSavingsAccountId) {
      _rebuildItems();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _rebuildItems() {
    final rawAccounts = widget.accounts.where((a) => !a.isArchived).toList();
    if (rawAccounts.isEmpty) {
      _items = [];
      _currentIndex = 0;
      return;
    }

    // Sort predictable order:
    // 1. Designated Main Account first
    // 2. Designated Savings Account second
    // 3. Other accounts in existing order
    Account? mainAccount;
    Account? savingsAccount;
    final List<Account> others = [];

    final mainId = widget.mainAccountId;
    final savingsId = widget.designatedSavingsAccountId;

    for (final acc in rawAccounts) {
      if (mainId != null && acc.id == mainId) {
        mainAccount = acc;
      } else if (savingsId != null && acc.id == savingsId) {
        savingsAccount = acc;
      } else {
        others.add(acc);
      }
    }

    // Fallback if main was not explicitly designated: first account becomes main
    if (mainAccount == null && rawAccounts.isNotEmpty) {
      mainAccount = rawAccounts.first;
      others.removeWhere((a) => a.id == mainAccount!.id);
      if (savingsAccount?.id == mainAccount.id) {
        savingsAccount = null;
      }
    }

    final List<Account> ordered = [];
    if (mainAccount != null) ordered.add(mainAccount);
    if (savingsAccount != null && savingsAccount.id != mainAccount?.id) {
      ordered.add(savingsAccount);
    }
    ordered.addAll(others);

    _items = ordered.map((acc) {
      final isMain = (acc.id == (mainAccount?.id ?? rawAccounts.first.id));
      final isSavings = (acc.id == savingsId) ||
          (!isMain && acc.accountType.toLowerCase() == 'savings');
      final role = isMain
          ? 'MAIN'
          : (isSavings ? 'SAVINGS' : acc.accountType.toUpperCase());
      final balance = widget.accountBalances[acc.id] ?? acc.openingBalance;
      return AccountCardItem(
        account: acc,
        balance: balance,
        isMain: isMain,
        isSavings: isSavings,
        roleBadge: role,
      );
    }).toList();

    if (_currentIndex >= _items.length) {
      _currentIndex = (_items.length - 1).clamp(0, 9999);
    }
  }

  void _toggleBalanceVisibility() {
    setState(() {
      _isBalanceHidden = !_isBalanceHidden;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return _buildEmptyAccountCard();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: widget.isDark ? AppTheme.cardCharcoal : null,
        gradient: widget.isDark
            ? null
            : const LinearGradient(
                colors: [Color(0xFF0F5747), Color(0xFF093E33)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: widget.isDark
              ? AppTheme.borderPrimary
              : const Color(0x3310B981),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.50 : 0.15),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Layered Realistic Payment Cards behind the glass pocket
          Positioned(
            top: 12,
            left: 20,
            right: 20,
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF202020) : null,
                gradient: widget.isDark
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.isDark
                      ? AppTheme.borderSecondary
                      : Colors.transparent,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),

          // Second layer: Top Real Bank Card that shows real account details
          Positioned(
            top: 18,
            left: 16,
            right: 16,
            child: _buildTopBankCardPreview(_items[_currentIndex]),
          ),

          // 2. Front Glass Pocket with Swipeable Content & Scoop
          Padding(
            padding: const EdgeInsets.only(top: 68),
            child: ClipPath(
              clipper: _PocketScoopClipper(),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: widget.isDark
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF141414),
                            Color(0xFF0D0D0D),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : const LinearGradient(
                          colors: [
                            Color(0xFA083D33),
                            Color(0xFA04261F),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                  border: Border.all(
                    color: widget.isDark
                        ? AppTheme.borderPrimary
                        : const Color(0x3865F5D4),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Swipeable PageView inside pocket
                    SizedBox(
                      height: 124,
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _items.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _buildCardFace(item);
                        },
                      ),
                    ),

                    // Subtle Carousel Indicator & Swipe Cue
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Indicators
                          if (_items.length > 1)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(_items.length, (idx) {
                                final isActive = idx == _currentIndex;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  margin: const EdgeInsets.only(right: 6),
                                  width: isActive ? 18 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? (widget.isDark
                                            ? AppTheme.pureWhite
                                            : AppTheme.primaryAccent)
                                        : (widget.isDark
                                            ? AppTheme.disabledGray
                                            : const Color(0xFF325E54)),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            )
                          else
                            const SizedBox.shrink(),

                          // Swipe Prompt / Account Switch Cue
                          if (_items.length > 1)
                            GestureDetector(
                              onTap: () {
                                final next =
                                    (_currentIndex + 1) % _items.length;
                                _pageController.animateToPage(
                                  next,
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _currentIndex == 0
                                        ? 'Swipe for ${_items[1].roleBadge}'
                                        : 'Swipe to switch',
                                    style: TextStyle(
                                      color: widget.isDark
                                          ? AppTheme.secondaryGray
                                          : const Color(0xFF8DAFA5),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 10,
                                    color: widget.isDark
                                        ? AppTheme.secondaryGray
                                        : const Color(0xFF8DAFA5),
                                  ),
                                ],
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Second layer card showing the real bank name, icon, and role
  Widget _buildTopBankCardPreview(AccountCardItem item) {
    final isSavings = item.isSavings;
    final isMain = item.isMain;

    final gradient = widget.isDark
        ? const LinearGradient(
            colors: [Color(0xFF202020), Color(0xFF181818)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : (isSavings
            ? const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF14B8A6), Color(0xFF06B6D4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : (isMain
                ? const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF06B6D4), Color(0xFF14B8A6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF38BDF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.elevatedCharcoal : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark ? AppTheme.borderPrimary : Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.35 : 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _iconForAccount(item.account),
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    item.bankDisplayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitleLabel,
                style: TextStyle(
                  color: widget.isDark ? AppTheme.secondaryGray : Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? const Color(0xFF292929)
                  : Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSavings
                      ? Icons.savings_rounded
                      : Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 11,
                ),
                const SizedBox(width: 3),
                Text(
                  item.roleBadge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Individual face inside the pocket with balance, eye toggle, and encryption badge
  Widget _buildCardFace(AccountCardItem item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Account identity + Encrypted Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    item.bankDisplayName,
                    style: TextStyle(
                      color: widget.isDark
                          ? AppTheme.secondaryGray
                          : const Color(0xFFBBE5DA),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF202020)
                          : (item.isMain
                              ? AppTheme.primaryAccent.withValues(alpha: 0.2)
                              : (item.isSavings
                                  ? const Color(0xFF14B8A6).withValues(alpha: 0.25)
                                  : Colors.white12)),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      item.roleBadge,
                      style: TextStyle(
                        color: widget.isDark
                            ? AppTheme.pureWhite
                            : (item.isMain
                                ? AppTheme.primaryAccent
                                : (item.isSavings
                                    ? const Color(0xFF5EEAD4)
                                    : Colors.white70)),
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? const Color(0xFF181818)
                      : AppTheme.primaryAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.isDark
                        ? AppTheme.borderPrimary
                        : AppTheme.primaryAccent.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: widget.isDark ? AppTheme.secondaryGray : AppTheme.primaryAccent,
                      size: 10,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Encrypted',
                      style: TextStyle(
                        color: widget.isDark ? AppTheme.secondaryGray : AppTheme.primaryAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Balance Row with Eye Toggle
          Row(
            children: [
              Expanded(
                child: _isBalanceHidden
                    ? Text(
                        '••••••••',
                        style: TextStyle(
                          color: widget.isDark
                              ? AppTheme.pureWhite
                              : const Color(0xFFE9FFF9),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          height: 1.1,
                        ),
                      )
                    : AnimatedBalanceText(
                        cents: item.balance,
                        style: TextStyle(
                          color: widget.isDark
                              ? AppTheme.pureWhite
                              : const Color(0xFFE9FFF9),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          height: 1.1,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _toggleBalanceVisibility,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    _isBalanceHidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: widget.isDark
                        ? AppTheme.tertiaryGray
                        : const Color(0xFF8DAFA5),
                    size: 19,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),

          // Secondary Currency / Subtitle Indicator
          _isBalanceHidden
              ? Text(
                  'Balance Hidden',
                  style: TextStyle(
                    color: widget.isDark
                        ? AppTheme.tertiaryGray
                        : const Color(0xFF5F8177),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : AnimatedBalanceText(
                  cents: item.balance,
                  showAmharicSuffix: true,
                  style: TextStyle(
                    color: widget.isDark
                        ? AppTheme.secondaryGray
                        : const Color(0xFF5F8177),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyAccountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: widget.isDark ? AppTheme.cardCharcoal : null,
        gradient: widget.isDark
            ? null
            : const LinearGradient(
                colors: [Color(0xFF0F5747), Color(0xFF093E33)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: widget.isDark
              ? AppTheme.borderPrimary
              : const Color(0x3310B981),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 42,
            color: widget.isDark ? AppTheme.pureWhite : AppTheme.primaryAccent,
          ),
          const SizedBox(height: 12),
          const Text(
            'No Accounts Configured',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add your main bank account or savings wallet to view your balances.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.isDark ? AppTheme.secondaryGray : const Color(0xFF8DAFA5),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
              if (widget.onAddAccount != null) {
                widget.onAddAccount!();
              } else {
                AccountsManagementScreen.navigate(context);
              }
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Account'),
            style: FilledButton.styleFrom(
              backgroundColor: widget.isDark ? AppTheme.pureWhite : AppTheme.primaryAccent,
              foregroundColor: widget.isDark ? AppTheme.pureBlack : const Color(0xFF04261F),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForAccount(Account acc) {
    switch (acc.accountType.toLowerCase()) {
      case 'bank':
        return Icons.account_balance_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'mobile_money':
        return Icons.phone_android_rounded;
      case 'cash':
        return Icons.payments_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }
}

/// Custom clipper that creates an elegant curved scoop notch along the top edge
/// of the wallet pocket overhang, revealing the cards behind it.
class _PocketScoopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, 0);

    // Left shoulder to center dip
    final scoopWidth = size.width * 0.40;
    const scoopDepth = 18.0;
    final leftX = (size.width - scoopWidth) / 2;
    final rightX = leftX + scoopWidth;

    path.lineTo(leftX, 0);

    // Smooth curve down and back up
    path.cubicTo(
      leftX + 16,
      0,
      leftX + 24,
      scoopDepth,
      size.width / 2,
      scoopDepth,
    );
    path.cubicTo(
      rightX - 24,
      scoopDepth,
      rightX - 16,
      0,
      rightX,
      0,
    );

    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

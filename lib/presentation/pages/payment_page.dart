import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../blocs/wallet_cubit.dart';
import '../../core/theme/app_theme.dart';
import 'package:bingo_mk/presentation/widgets/loading_widgets.dart';
import 'package:bingo_mk/core/l10n/app_strings.dart';
import 'package:bingo_mk/presentation/blocs/settings_cubit.dart';
import 'package:bingo_mk/core/theme/app_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});
  @override State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _shownRejections = <String>{};
  String? _lastShownStatusMessage; // BUG-FIX: track to avoid showing same msg twice

  final _depositAmountCtrl  = TextEditingController();
  final _referenceCtrl      = TextEditingController();
  final _withdrawAmountCtrl = TextEditingController();
  final _accountCtrl        = TextEditingController();

  String? _depositAmountError;
  String? _referenceError;
  String? _withdrawAmountError;
  String? _accountError;
  String? _selectedDepositBank;
  String? _selectedWithdrawBank;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<WalletCubit>().loadWallet();
    _registerFcmToken();
  }

  @override
  void dispose() {
    _depositAmountCtrl.dispose();
    _referenceCtrl.dispose();
    _withdrawAmountCtrl.dispose();
    _accountCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _registerFcmToken() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && mounted) {
          context.read<WalletCubit>().saveFcmToken(token);
        }
      }
    } catch (_) {}
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: AppTokens.success, size: 18),
          const SizedBox(width: 8),
          Text('${label}${S.copied}', style: AppText.body(size: 13, weight: FontWeight.w600)),
        ]),
        backgroundColor: AppTokens.cardHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
    );
  }

  void _validateDepositAmt(String v, WalletLimits l) {
    final n = double.tryParse(v);
    String? e;
    if (v.isNotEmpty) {
      if (n == null || n <= 0) e = S.enterValidNumber;
      else if (n < l.minDeposit) e = 'Min ${l.minDeposit.toStringAsFixed(0)} ETB';
      else if (n > l.maxDeposit) e = 'Max ${l.maxDeposit.toStringAsFixed(0)} ETB';
    }
    setState(() => _depositAmountError = e);
  }

  void _validateWithdrawAmt(String v, WalletLimits l, double bal) {
    final n = double.tryParse(v);
    String? e;
    if (v.isNotEmpty) {
      if (n == null || n <= 0) e = S.enterValidNumber;
      else if (n < l.minWithdraw) e = 'Min ${l.minWithdraw.toStringAsFixed(0)} ETB';
      else if (n > l.maxWithdraw) e = 'Max ${l.maxWithdraw.toStringAsFixed(0)} ETB';
      else if (n > bal) e = S.insufficientBalance;
    }
    setState(() => _withdrawAmountError = e);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, _) => Scaffold(
      backgroundColor: AppTokens.bg,
      body: BlocConsumer<WalletCubit, WalletState>(
        listener: (context, state) {
          if (state is WalletLoaded) {
            _checkRejections(context, state);
            // BUG-FIX (Bug 2): Show wallet errors (e.g. "Withdrawal failed:
            // Insufficient balance") as a visible snackbar. Previously the
            // inline _StatusBanner was easy to miss. We also deduplicate so the
            // same message doesn't flash repeatedly on balance stream ticks.
            final msg = state.statusMessage;
            if (msg != null && msg.isNotEmpty && msg != _lastShownStatusMessage) {
              _lastShownStatusMessage = msg;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final isError = msg.toLowerCase().contains('failed') ||
                    msg.toLowerCase().contains('error') ||
                    msg.toLowerCase().contains('insufficient') ||
                    msg.toLowerCase().contains('denied');
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(children: [
                      Icon(
                        isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                        color: isError ? Colors.red[300] : AppTokens.success,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(msg, style: AppText.body(size: 13, weight: FontWeight.w600))),
                    ]),
                    backgroundColor: AppTokens.cardHigh,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: Duration(seconds: isError ? 4 : 2),
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  ),
                );
              });
            } else if (msg == null) {
              _lastShownStatusMessage = null;
            }
          }
        },
        builder: (context, state) {
          if (state is WalletLoading) {
            return const Center(child: AppSpinner());
          }
          if (state is WalletLoaded) {
            return Column(
              children: [
                _WalletHeader(balance: state.balance),
                Expanded(
                  child: RefreshIndicator(
                    color: AppTokens.goldAlt,
                    backgroundColor: AppTokens.card,
                    onRefresh: () => context.read<WalletCubit>().loadWallet(),
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics()),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              if (state.statusMessage != null) ...[
                                const SizedBox(height: 12),
                                _StatusBanner(message: state.statusMessage!),
                              ],
                              const SizedBox(height: 20),
                              _TabRow(controller: _tabController),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 1800, // tall enough to avoid nested scroll
                                child: TabBarView(
                                  controller: _tabController,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: [
                                    _DepositTab(
                                      state: state,
                                      amountCtrl: _depositAmountCtrl,
                                      referenceCtrl: _referenceCtrl,
                                      amountError: _depositAmountError,
                                      referenceError: _referenceError,
                                      selectedBank: _selectedDepositBank,
                                      onBankChanged: (v) => setState(() => _selectedDepositBank = v),
                                      onAmountChanged: (v) => _validateDepositAmt(v, state.limits),
                                      onReferenceChanged: (v) => setState(() =>
                                          _referenceError = v.trim().isEmpty ? S.referenceRequired : null),
                                      onCopy: _copy,
                                      onSubmit: () => _submitDeposit(state),
                                    ),
                                    _WithdrawTab(
                                      state: state,
                                      amountCtrl: _withdrawAmountCtrl,
                                      accountCtrl: _accountCtrl,
                                      amountError: _withdrawAmountError,
                                      accountError: _accountError,
                                      selectedBank: _selectedWithdrawBank,
                                      onBankChanged: (v) => setState(() => _selectedWithdrawBank = v),
                                      onAmountChanged: (v) => _validateWithdrawAmt(v, state.limits, state.balance),
                                      onAccountChanged: (v) => setState(() =>
                                          _accountError = v.trim().isEmpty ? S.accountRequired : null),
                                      onSubmit: () => _submitWithdraw(state),
                                    ),
                                  ],
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          if (state is WalletError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.wifi_off_rounded, color: AppTokens.textLow, size: 52),
                const SizedBox(height: 16),
                Text(state.message, style: AppText.body(color: AppTokens.textMid), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                _GoldButton(
                  label: S.retry,
                  onTap: () => context.read<WalletCubit>().loadWallet(),
                ),
              ]),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    ),
    );
  }

  void _checkRejections(BuildContext context, WalletLoaded state) {
    for (final dep in state.deposits) {
      final id = dep['id'] as String? ?? '';
      if (dep['status'] == 'rejected' && id.isNotEmpty && !_shownRejections.contains(id)) {
        _shownRejections.add(id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showRejectionDialog(context, 'Deposit', dep['amount'],
              dep['rejectionReason'] ?? S.unknown,
              () => context.read<WalletCubit>().deleteTransaction('deposits', id));
        });
        break;
      }
    }
    for (final wth in state.withdrawals) {
      final id = wth['id'] as String? ?? '';
      if (wth['status'] == 'rejected' && id.isNotEmpty && !_shownRejections.contains(id)) {
        _shownRejections.add(id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showRejectionDialog(context, 'Withdrawal', wth['amount'],
              wth['rejectionReason'] ?? S.unknown,
              () => context.read<WalletCubit>().deleteTransaction('withdrawals', id));
        });
        break;
      }
    }
  }

  Future<void> _submitDeposit(WalletLoaded state) async {
    final banks = state.bankAccounts
        .map((a) => a['bank'] as String? ?? '')
        .where((b) => b.isNotEmpty)
        .toList();
    final activeBank = _selectedDepositBank ?? (banks.isNotEmpty ? banks.first : 'Telebirr');

    final amt = double.tryParse(_depositAmountCtrl.text) ?? 0;
    final ref = _referenceCtrl.text.trim();
    final amtErr = amt <= 0 ? 'Enter a valid amount'
        : (amt < state.limits.minDeposit ? 'Min ${state.limits.minDeposit.toStringAsFixed(0)} ETB'
        : (amt > state.limits.maxDeposit ? 'Max ${state.limits.maxDeposit.toStringAsFixed(0)} ETB' : null));
    final refErr = ref.isEmpty ? S.referenceRequired : null;
    setState(() { _depositAmountError = amtErr; _referenceError = refErr; });
    if (amtErr != null || refErr != null) return;

    await context.read<WalletCubit>().deposit(amt, activeBank, ref);
    if (!mounted) return;
    final s = context.read<WalletCubit>().state;
    if (s is WalletLoaded && s.statusMessage == null) {
      _depositAmountCtrl.clear(); _referenceCtrl.clear();
      setState(() { _depositAmountError = null; _referenceError = null; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(S.depositSubmitted, style: AppText.body(size: 13)),
        backgroundColor: AppTokens.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ));
    }
  }

  Future<void> _submitWithdraw(WalletLoaded state) async {
    final banks = state.bankAccounts
        .map((a) => a['bank'] as String? ?? '')
        .where((b) => b.isNotEmpty)
        .toList();
    final activeBank = _selectedWithdrawBank ?? (banks.isNotEmpty ? banks.first : 'Telebirr');

    final amt = double.tryParse(_withdrawAmountCtrl.text) ?? 0;
    final acc = _accountCtrl.text.trim();
    final amtErr = amt <= 0 ? 'Enter a valid amount'
        : (amt < state.limits.minWithdraw ? 'Min ${state.limits.minWithdraw.toStringAsFixed(0)} ETB'
        : (amt > state.limits.maxWithdraw ? 'Max ${state.limits.maxWithdraw.toStringAsFixed(0)} ETB'
        : (amt > state.balance ? S.insufficientBalance : null)));
    final accErr = acc.isEmpty ? S.accountRequired : null;
    setState(() { _withdrawAmountError = amtErr; _accountError = accErr; });
    if (amtErr != null || accErr != null) return;

    await context.read<WalletCubit>().withdraw(amt, activeBank, acc);
    if (!mounted) return;
    final s = context.read<WalletCubit>().state;
    if (s is WalletLoaded && s.statusMessage == null) {
      _withdrawAmountCtrl.clear(); _accountCtrl.clear();
      setState(() { _withdrawAmountError = null; _accountError = null; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(S.withdrawalSubmitted, style: AppText.body(size: 13)),
        backgroundColor: AppTokens.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ));
    }
  }

  void _showRejectionDialog(BuildContext ctx, String type, dynamic amount,
      String reason, VoidCallback onDelete) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTokens.cardHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTokens.danger.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.close_rounded, color: AppTokens.danger, size: 20),
          ),
          const SizedBox(width: 12),
          Text('$type Rejected',
              style: AppText.body(size: 16, weight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your $type of $amount ETB was rejected.',
              style: AppText.body(color: AppTokens.textMid)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTokens.danger.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTokens.danger.withOpacity(0.2)),
            ),
            child: Text('Reason: $reason',
                style: AppText.body(size: 12, color: AppTokens.danger, weight: FontWeight.w600)),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(dialogCtx); onDelete(); },
            child: Text(S.dismiss,
                style: AppText.label(size: 12, color: AppTokens.goldAlt, spacing: 1.0)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIVER HEADER — Balance hero
// ─────────────────────────────────────────────────────────────────────────────
class _WalletHeader extends StatelessWidget {
  final double balance;
  const _WalletHeader({required this.balance});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.availableBalance, style: AppText.label(size: 10, color: AppTokens.textLow, spacing: 0.5)),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          balance.toStringAsFixed(2),
                          style: AppText.display.copyWith(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppTokens.goldAlt,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('ETB', style: AppText.label(size: 11, color: AppTokens.goldAltDim, spacing: 0.5)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTokens.goldAltFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTokens.goldAltBorder, width: 0.75),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: AppTokens.goldAlt, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 0.5, color: AppTokens.divider),
          ],
        ),
      ),
    );
  }
}

// ─── Status banner ────────────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final String message;
  const _StatusBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: AppTokens.danger.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTokens.danger.withOpacity(0.25)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: AppTokens.danger, size: 17),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: AppText.body(size: 12, color: AppTokens.danger))),
    ]),
  );
}

// ─── Tab row ──────────────────────────────────────────────────────────────────
class _TabRow extends StatelessWidget {
  final TabController controller;
  const _TabRow({required this.controller});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: glassDeco(),
    child: TabBar(
      controller: controller,
      indicator: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFF5CC50)],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: Colors.black,
      unselectedLabelColor: AppTokens.textMid,
      labelStyle: AppText.label(size: 12, color: Colors.black, spacing: 1.5),
      unselectedLabelStyle: AppText.label(size: 12, color: AppTokens.textMid, spacing: 1.5),
      tabs: [Tab(text: S.deposit), Tab(text: S.withdraw)],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DEPOSIT TAB
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// DEPOSIT TAB
// ─────────────────────────────────────────────────────────────────────────────
class _DepositTab extends StatelessWidget {
  final WalletLoaded state;
  final TextEditingController amountCtrl, referenceCtrl;
  final String? amountError, referenceError, selectedBank;
  final ValueChanged<String?> onBankChanged;
  final ValueChanged<String> onAmountChanged, onReferenceChanged;
  final void Function(String, String) onCopy;
  final VoidCallback onSubmit;

  const _DepositTab({
    required this.state, required this.amountCtrl, required this.referenceCtrl,
    required this.amountError, required this.referenceError, required this.selectedBank,
    required this.onBankChanged, required this.onAmountChanged,
    required this.onReferenceChanged, required this.onCopy, required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final banks = state.bankAccounts
        .map((a) => a['bank'] as String? ?? '').where((b) => b.isNotEmpty).toList();
    final activeBank = selectedBank ?? (banks.isNotEmpty ? banks.first : 'Telebirr');

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Minimalist Full-Width Accounts List
      if (state.bankAccounts.isNotEmpty) ...[
        Text(S.copyAccountDetails, style: AppText.label(size: 11, color: AppTokens.textLow)),
        const SizedBox(height: 8),
        Column(
          children: state.bankAccounts.map((a) {
            final bank   = a['bank'] as String? ?? '';
            final number = a['accountNumber'] as String? ?? a['number'] as String? ?? '';
            final name   = a['accountName'] as String? ?? a['name'] as String? ?? '';
            final isMobile = bank.toLowerCase().contains('tele') || bank.toLowerCase().contains('m-pesa');
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTokens.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTokens.divider, width: 0.75),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bank.toUpperCase(), style: AppText.label(size: 9, color: isMobile ? AppTokens.blueAccent : const Color(0xFF9FA8DA), spacing: 0.5)),
                        const SizedBox(height: 2),
                        Text(number, style: AppText.display.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: AppTokens.textHigh)),
                        if (name.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(name, style: AppText.label(size: 9, color: AppTokens.textLow), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: AppTokens.goldAlt, size: 16),
                    onPressed: () => onCopy(number, '$bank number'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
      ],

      // Minimalist Inputs Form
      Container(
        padding: const EdgeInsets.all(16),
        decoration: glassDeco(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (banks.isNotEmpty) ...[
              _WalletDropdown(
                label: S.bankPaidTo,
                value: banks.contains(activeBank) ? activeBank : banks.first,
                items: banks,
                onChanged: onBankChanged,
                icon: Icons.account_balance_wallet_rounded,
              ),
              const SizedBox(height: 10),
            ],
            _WalletField(
              controller: amountCtrl,
              hint: '${S.amountSent} (Min ${state.limits.minDeposit.toStringAsFixed(0)} - Max ${state.limits.maxDeposit.toStringAsFixed(0)} ETB)',
              icon: Icons.monetization_on_rounded,
              inputType: TextInputType.number,
              errorText: amountError,
              onChanged: onAmountChanged,
            ),
            const SizedBox(height: 10),
            _WalletField(
              controller: referenceCtrl,
              hint: S.transactionRef,
              icon: Icons.receipt_long_rounded,
              errorText: referenceError,
              onChanged: onReferenceChanged,
            ),
            const SizedBox(height: 16),
            _GoldButton(label: S.submitDeposit, onTap: onSubmit, isLoading: state.isActionLoading),
          ],
        ),
      ),
      const SizedBox(height: 24),
      _HistorySection(
          title: S.depositHistory,
          items: state.deposits,
          isDeposit: true),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WITHDRAW TAB
// ─────────────────────────────────────────────────────────────────────────────
class _WithdrawTab extends StatelessWidget {
  final WalletLoaded state;
  final TextEditingController amountCtrl, accountCtrl;
  final String? amountError, accountError, selectedBank;
  final ValueChanged<String?> onBankChanged;
  final ValueChanged<String> onAmountChanged, onAccountChanged;
  final VoidCallback onSubmit;

  const _WithdrawTab({
    required this.state, required this.amountCtrl, required this.accountCtrl,
    required this.amountError, required this.accountError, required this.selectedBank,
    required this.onBankChanged, required this.onAmountChanged,
    required this.onAccountChanged, required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final banks = state.bankAccounts
        .map((a) => a['bank'] as String? ?? '').where((b) => b.isNotEmpty).toList();
    final activeBank = selectedBank ?? (banks.isNotEmpty ? banks.first : 'Telebirr');

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: glassDeco(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (banks.isNotEmpty) ...[
              _WalletDropdown(
                label: S.withdrawalBank,
                value: banks.contains(activeBank) ? activeBank : banks.first,
                items: banks,
                onChanged: onBankChanged,
                icon: Icons.account_balance_rounded,
              ),
              const SizedBox(height: 10),
            ],
            _WalletField(
              controller: amountCtrl,
              hint: '${S.amount} (Min ${state.limits.minWithdraw.toStringAsFixed(0)} - Max ${state.limits.maxWithdraw.toStringAsFixed(0)} ETB)',
              icon: Icons.monetization_on_rounded,
              inputType: TextInputType.number,
              errorText: amountError,
              onChanged: onAmountChanged,
            ),
            const SizedBox(height: 10),
            _WalletField(
              controller: accountCtrl,
              hint: S.accountPhone,
              icon: Icons.account_box_rounded,
              errorText: accountError,
              onChanged: onAccountChanged,
            ),
            const SizedBox(height: 16),
            _GoldButton(label: S.requestWithdrawal, onTap: onSubmit, isLoading: state.isActionLoading),
          ],
        ),
      ),
      const SizedBox(height: 24),
      _HistorySection(
          title: S.withdrawalHistory,
          items: state.withdrawals,
          isDeposit: false),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _LimitsPill extends StatelessWidget {
  final String label;
  const _LimitsPill({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: AppTokens.goldAltFill,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTokens.goldAltBorder),
    ),
    child: Row(children: [
      const Icon(Icons.info_outline_rounded, color: AppTokens.goldAlt, size: 15),
      const SizedBox(width: 8),
      Text(label, style: AppText.label(size: 11, color: AppTokens.goldAlt, spacing: 0.3)),
    ]),
  );
}

class _StepCard extends StatelessWidget {
  final int? step;
  final String title;
  final Widget child;
  const _StepCard({required this.title, required this.child, this.step});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: glassDeco(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (step != null) ...[
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: AppTokens.goldAltFill,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTokens.goldAltBorder),
            ),
            alignment: Alignment.center,
            child: Text('$step',
                style: AppText.label(size: 11, color: AppTokens.goldAlt, spacing: 0)),
          ),
          const SizedBox(width: 10),
        ],
        Text(title, style: AppText.body(size: 13, weight: FontWeight.w600)),
      ]),
      const SizedBox(height: 14),
      child,
    ]),
  );
}

class _AccountTile extends StatelessWidget {
  final String bank, number, name;
  final void Function(String, String) onCopy;
  const _AccountTile(
      {required this.bank, required this.number, required this.name, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final isMobile = bank.toLowerCase().contains('tele') ||
        bank.toLowerCase().contains('m-pesa');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTokens.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTokens.divider),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: isMobile
                ? AppTokens.blueAccent.withOpacity(0.08)
                : AppTokens.blueDeep.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isMobile ? Icons.phone_android_rounded : Icons.account_balance_rounded,
            color: isMobile ? AppTokens.blueAccent : const Color(0xFF7986CB),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(bank.toUpperCase(), style: AppText.label(
              size: 10,
              color: isMobile ? AppTokens.blueAccent : const Color(0xFF9FA8DA),
              spacing: 0.8)),
          const SizedBox(height: 2),
          Text(number, style: AppText.display.copyWith(
              fontSize: 14, fontWeight: FontWeight.bold, color: AppTokens.textHigh)),
          if (name.isNotEmpty)
            Text(name, style: AppText.label(size: 10, color: AppTokens.textLow, spacing: 0.3)),
        ])),
        IconButton(
          icon: const Icon(Icons.copy_rounded, color: AppTokens.goldAlt, size: 18),
          onPressed: () => onCopy(number, '$bank number'),
          tooltip: 'Copy',
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(8),
        ),
      ]),
    );
  }
}

class _WalletField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType inputType;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _WalletField({
    required this.controller, required this.hint, required this.icon,
    this.inputType = TextInputType.text, this.errorText, this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return TextField(
      controller: controller,
      keyboardType: inputType,
      style: AppText.body(size: 14),
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: hasError ? AppTokens.danger : AppTokens.goldAlt, size: 19),
        hintText: hint,
        hintStyle: AppText.body(size: 13, color: AppTokens.textLow),
        errorText: errorText,
        errorStyle: AppText.label(size: 11, color: AppTokens.danger, spacing: 0.2),
        filled: true,
        fillColor: AppTokens.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: hasError ? AppTokens.danger.withOpacity(0.5) : AppTokens.divider,
            width: 0.75,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: hasError ? AppTokens.danger : AppTokens.goldAlt, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTokens.danger, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTokens.danger, width: 1.5),
        ),
      ),
    );
  }
}

class _WalletDropdown extends StatelessWidget {
  final String label, value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final IconData icon;
  const _WalletDropdown({
    required this.label, required this.value, required this.items,
    required this.onChanged, required this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppTokens.bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTokens.divider, width: 0.75),
    ),
    child: DropdownButtonFormField<String>(
      value: value,
      dropdownColor: AppTokens.card,
      style: AppText.body(size: 14),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTokens.goldAlt, size: 20),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppTokens.goldAlt, size: 19),
        labelText: label,
        labelStyle: AppText.label(size: 11, color: AppTokens.textLow, spacing: 0.3),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
      ),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item, style: AppText.body(size: 14)),
      )).toList(),
      onChanged: onChanged,
    ),
  );
}

class _GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  const _GoldButton({required this.label, required this.onTap, this.isLoading = false});
  @override
  Widget build(BuildContext context) {
    final disabled = isLoading;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            gradient: disabled
                ? null
                : const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFF5CC50)],
                  ),
            color: disabled ? const Color(0xFF444444) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  )
                : Text(label,
                    style: AppText.label(size: 13, color: Colors.black, spacing: 1.5)),
          ),
        ),
      ),
    );
  }
}

// ─── History section ──────────────────────────────────────────────────────────
class _HistorySection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final bool isDeposit;
  const _HistorySection({required this.title, required this.items, required this.isDeposit});

  @override
  Widget build(BuildContext context) {
    final visible = items.where((i) => i['status'] != 'rejected').toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title, style: AppText.body(size: 13, weight: FontWeight.w600)),
      ),
      if (visible.isEmpty)
        _EmptyInfo(isDeposit ? 'No deposits yet' : 'No withdrawals yet')
      else
        ...visible.map((item) => _HistoryTile(item: item, isDeposit: isDeposit,
            onTap: () => _showReceipt(context, item, isDeposit))),
    ]);
  }

  static void _showReceipt(BuildContext context, Map<String, dynamic> item, bool isDeposit) {
    final status = item['status'] as String? ?? 'pending';
    final statusColor = status == 'approved' ? AppTokens.success
        : (status == 'pending' ? AppTokens.warning : AppTokens.danger);
    final statusIcon  = status == 'approved' ? Icons.check_circle_rounded
        : (status == 'pending' ? Icons.schedule_rounded : Icons.cancel_rounded);

    String _fmt(dynamic ts) {
      if (ts == null) return '—';
      try {
        final dt = ts is DateTime ? ts : (ts as dynamic).toDate() as DateTime;
        return '${dt.day}/${dt.month}/${dt.year}  '
            '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      } catch (_) { return ts.toString(); }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTokens.cardHigh,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: AppTokens.divider, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Icon(isDeposit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: AppTokens.goldAlt),
            const SizedBox(width: 10),
            Text(isDeposit ? 'Deposit Receipt' : 'Withdrawal Receipt',
                style: AppText.body(size: 16, weight: FontWeight.bold)),
            const Spacer(),
            Icon(statusIcon, color: statusColor, size: 22),
          ]),
          const SizedBox(height: 16),
          Container(height: 0.5, color: AppTokens.divider),
          const SizedBox(height: 14),
          _ReceiptRow('Amount', '${item['amount']} ETB', large: true),
          _ReceiptRow('Bank', item['bank'] ?? '—'),
          if (isDeposit) _ReceiptRow('Reference', item['reference'] ?? '—'),
          if (!isDeposit) _ReceiptRow('Account', item['accountNumber'] ?? '—'),
          _ReceiptRow('Status', status.toUpperCase(), valueColor: statusColor),
          if (item['createdAt'] != null) _ReceiptRow('Submitted', _fmt(item['createdAt'])),
          if (item['verifiedAt'] != null) _ReceiptRow('Verified', _fmt(item['verifiedAt'])),
          if (!isDeposit && item['reservedAt'] != null) _ReceiptRow('Reserved', _fmt(item['reservedAt'])),
          if (!isDeposit && item['refundedAt'] != null) _ReceiptRow('Refunded', _fmt(item['refundedAt'])),
          if (item['matchedVia'] != null) _ReceiptRow('Matched via', item['matchedVia']),
          if (item['rejectionReason'] != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTokens.danger.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTokens.danger.withOpacity(0.2)),
              ),
              child: Text('Reason: ${item['rejectionReason']}',
                  style: AppText.body(size: 12, color: AppTokens.danger)),
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTokens.warning.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTokens.warning.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.notifications_active_outlined,
                    color: AppTokens.warning, size: 15),
                const SizedBox(width: 8),
                Expanded(child: Text(
                    "You'll receive a push notification when approved.",
                    style: AppText.body(size: 11, color: AppTokens.warning))),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDeposit;
  final VoidCallback onTap;
  const _HistoryTile({required this.item, required this.isDeposit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = item['status'] as String? ?? 'pending';
    final statusColor = status == 'approved' ? AppTokens.success
        : (status == 'pending' ? AppTokens.warning : AppTokens.danger);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: glassDeco(),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDeposit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: statusColor, size: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['bank'] as String? ?? '—',
                style: AppText.body(size: 13, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(item['reference'] ?? item['accountNumber'] ?? '—',
                style: AppText.label(size: 10, color: AppTokens.textLow, spacing: 0.2),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${item['amount']} ETB',
                style: AppText.display.copyWith(
                    fontSize: 13, fontWeight: FontWeight.bold, color: AppTokens.goldAlt)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(status.toUpperCase(),
                  style: AppText.label(size: 9, color: statusColor, spacing: 0.5)),
            ),
          ]),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: AppTokens.textLow, size: 16),
        ]),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label, value;
  final bool large;
  final Color? valueColor;
  const _ReceiptRow(this.label, this.value, {this.large = false, this.valueColor});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: AppText.label(size: 12, color: AppTokens.textLow, spacing: 0.2)),
      Flexible(child: Text(value, textAlign: TextAlign.right,
          style: large
              ? AppText.display.copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor ?? AppTokens.goldAlt)
              : AppText.body(size: 13, color: valueColor ?? AppTokens.textHigh, weight: FontWeight.w500))),
    ]),
  );
}

class _EmptyInfo extends StatelessWidget {
  final String message;
  const _EmptyInfo(this.message);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(children: [
      Icon(Icons.inbox_outlined, color: AppTokens.textLow, size: 36),
      const SizedBox(height: 10),
      Text(message, style: AppText.label(size: 12, color: AppTokens.textLow, spacing: 0.2)),
    ]),
  );
}
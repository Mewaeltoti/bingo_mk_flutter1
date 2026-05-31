import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../blocs/wallet_cubit.dart';
import '../../core/theme/app_theme.dart';
import 'package:bingo_mk/presentation/widgets/loading_widgets.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
class _C {
  // Base surfaces
  static const bg        = Color(0xFF050D1A);
  static const card      = Color(0xFF0D1B2A);
  static const cardHigh  = Color(0xFF112236);
  static const divider   = Color(0xFF1C2E40);

  // Brand
  static const gold      = Color(0xFFD4AF37);
  static const goldDim   = Color(0xFFA07C1E);
  static const goldFill  = Color(0x1AD4AF37);  // 10%
  static const goldBorder= Color(0x40D4AF37);  // 25%
  static const blue      = Color(0xFF1A237E);
  static const blueMid   = Color(0xFF283593);
  static const accent    = Color(0xFF42A5F5);

  // Semantic
  static const success   = Color(0xFF2A9D8F);
  static const danger    = Color(0xFFE63946);
  static const warning   = Color(0xFFF59E0B);

  // Text
  static const textHigh  = Colors.white;
  static const textMid   = Color(0xFFB0BEC5);
  static const textLow   = Color(0xFF607D8B);
}

// ─── Shared text styles ───────────────────────────────────────────────────────
class _T {
  static const mono = TextStyle(fontFamily: 'Orbitron');
  static TextStyle label({double size = 11, Color? color, double spacing = 0.8}) =>
      TextStyle(
        fontFamily: 'Outfit',
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: spacing,
        color: color ?? _C.textMid,
      );
  static TextStyle body({double size = 13, Color? color, FontWeight weight = FontWeight.w400}) =>
      TextStyle(fontFamily: 'Outfit', fontSize: size, fontWeight: weight, color: color ?? _C.textHigh);
}

// ─── Decoration helpers ───────────────────────────────────────────────────────
BoxDecoration _cardDeco({Color? border, Color? bg}) => BoxDecoration(
  color: bg ?? _C.card,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: border ?? _C.divider, width: 0.5),
);

// ─────────────────────────────────────────────────────────────────────────────
class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});
  @override State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _shownRejections = <String>{};

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
          const Icon(Icons.check_circle_rounded, color: _C.success, size: 18),
          const SizedBox(width: 8),
          Text('$label copied', style: _T.body(size: 13, weight: FontWeight.w600)),
        ]),
        backgroundColor: _C.cardHigh,
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
      if (n == null || n <= 0) e = 'Enter a valid number';
      else if (n < l.minDeposit) e = 'Min ${l.minDeposit.toStringAsFixed(0)} ETB';
      else if (n > l.maxDeposit) e = 'Max ${l.maxDeposit.toStringAsFixed(0)} ETB';
    }
    setState(() => _depositAmountError = e);
  }

  void _validateWithdrawAmt(String v, WalletLimits l, double bal) {
    final n = double.tryParse(v);
    String? e;
    if (v.isNotEmpty) {
      if (n == null || n <= 0) e = 'Enter a valid number';
      else if (n < l.minWithdraw) e = 'Min ${l.minWithdraw.toStringAsFixed(0)} ETB';
      else if (n > l.maxWithdraw) e = 'Max ${l.maxWithdraw.toStringAsFixed(0)} ETB';
      else if (n > bal) e = 'Insufficient balance';
    }
    setState(() => _withdrawAmountError = e);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: BlocConsumer<WalletCubit, WalletState>(
        listener: (context, state) {
          if (state is WalletLoaded) {
            _checkRejections(context, state);
          }
        },
        builder: (context, state) {
          if (state is WalletLoading) {
            return const Center(child: AppSpinner());
          }
          if (state is WalletLoaded) {
            return RefreshIndicator(
              color: _C.gold,
              backgroundColor: _C.card,
              onRefresh: () => context.read<WalletCubit>().loadWallet(),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  _SliverWalletHeader(balance: state.balance),
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
                                    _referenceError = v.trim().isEmpty ? 'Reference required' : null),
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
                                    _accountError = v.trim().isEmpty ? 'Account required' : null),
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
            );
          }
          if (state is WalletError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.wifi_off_rounded, color: _C.textLow, size: 52),
                const SizedBox(height: 16),
                Text(state.message, style: _T.body(color: _C.textMid), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                _GoldButton(
                  label: 'RETRY',
                  onTap: () => context.read<WalletCubit>().loadWallet(),
                ),
              ]),
            );
          }
          return const SizedBox.shrink();
        },
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
              dep['rejectionReason'] ?? 'Unknown',
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
              wth['rejectionReason'] ?? 'Unknown',
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
    final refErr = ref.isEmpty ? 'Reference required' : null;
    setState(() { _depositAmountError = amtErr; _referenceError = refErr; });
    if (amtErr != null || refErr != null) return;

    await context.read<WalletCubit>().deposit(amt, activeBank, ref);
    if (!mounted) return;
    final s = context.read<WalletCubit>().state;
    if (s is WalletLoaded && s.statusMessage == null) {
      _depositAmountCtrl.clear(); _referenceCtrl.clear();
      setState(() { _depositAmountError = null; _referenceError = null; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Deposit submitted — auto-matching in progress…', style: _T.body(size: 13)),
        backgroundColor: _C.success,
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
        : (amt > state.balance ? 'Insufficient balance' : null)));
    final accErr = acc.isEmpty ? 'Account required' : null;
    setState(() { _withdrawAmountError = amtErr; _accountError = accErr; });
    if (amtErr != null || accErr != null) return;

    await context.read<WalletCubit>().withdraw(amt, activeBank, acc);
    if (!mounted) return;
    final s = context.read<WalletCubit>().state;
    if (s is WalletLoaded && s.statusMessage == null) {
      _withdrawAmountCtrl.clear(); _accountCtrl.clear();
      setState(() { _withdrawAmountError = null; _accountError = null; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Withdrawal request submitted!', style: _T.body(size: 13)),
        backgroundColor: _C.success,
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
        backgroundColor: _C.cardHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _C.danger.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.close_rounded, color: _C.danger, size: 20),
          ),
          const SizedBox(width: 12),
          Text('$type Rejected',
              style: _T.body(size: 16, weight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your $type of $amount ETB was rejected.',
              style: _T.body(color: _C.textMid)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.danger.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.danger.withOpacity(0.2)),
            ),
            child: Text('Reason: $reason',
                style: _T.body(size: 12, color: _C.danger, weight: FontWeight.w600)),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(dialogCtx); onDelete(); },
            child: Text('DISMISS',
                style: _T.label(size: 12, color: _C.gold, spacing: 1.0)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIVER HEADER — Balance hero
// ─────────────────────────────────────────────────────────────────────────────
class _SliverWalletHeader extends StatelessWidget {
  final double balance;
  const _SliverWalletHeader({required this.balance});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 56, 16, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1628), Color(0xFF0D1B2A), Color(0xFF050D1A)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title row
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _C.goldFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.goldBorder),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: _C.gold, size: 22),
            ),
            const SizedBox(width: 12),
            Text('WALLET', style: _T.label(size: 13, color: _C.gold, spacing: 2.5)),
          ]),
          const SizedBox(height: 20),
          // Balance
          Text('Available Balance', style: _T.label(size: 11, color: _C.textLow, spacing: 0.5)),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              balance.toStringAsFixed(2),
              style: _T.mono.copyWith(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: _C.gold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('ETB', style: _T.label(size: 14, color: _C.goldDim, spacing: 1.0)),
            ),
          ]),
          const SizedBox(height: 20),
          // Divider line
          Container(height: 0.5, color: _C.divider),
        ]),
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
      color: _C.danger.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _C.danger.withOpacity(0.25)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: _C.danger, size: 17),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: _T.body(size: 12, color: _C.danger))),
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
    decoration: _cardDeco(),
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
      unselectedLabelColor: _C.textMid,
      labelStyle: _T.label(size: 12, color: Colors.black, spacing: 1.5),
      unselectedLabelStyle: _T.label(size: 12, color: _C.textMid, spacing: 1.5),
      dividerColor: Colors.transparent,
      tabs: const [Tab(text: 'DEPOSIT'), Tab(text: 'WITHDRAW')],
    ),
  );
}

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
      _LimitsPill(
        label: 'Deposit range: ${state.limits.minDeposit.toStringAsFixed(0)} – '
            '${state.limits.maxDeposit.toStringAsFixed(0)} ETB',
      ),
      const SizedBox(height: 20),
      // Step 1
      _StepCard(
        step: 1,
        title: 'Copy Account Details',
        child: state.bankAccounts.isEmpty
            ? _EmptyInfo('No payment accounts configured')
            : Column(
                children: state.bankAccounts.map((a) {
                  final bank   = a['bank'] as String? ?? '';
                  final number = a['accountNumber'] as String? ?? a['number'] as String? ?? '';
                  final name   = a['accountName'] as String? ?? a['name'] as String? ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AccountTile(bank: bank, number: number, name: name, onCopy: onCopy),
                  );
                }).toList(),
              ),
      ),
      const SizedBox(height: 12),
      // Step 2
      _StepCard(
        step: 2,
        title: 'Submit Reference',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (banks.isNotEmpty) ...[
            _WalletDropdown(
              label: 'Bank Paid To',
              value: banks.contains(activeBank) ? activeBank : banks.first,
              items: banks,
              onChanged: onBankChanged,
              icon: Icons.account_balance_wallet_rounded,
            ),
            const SizedBox(height: 10),
          ],
          _WalletField(
            controller: amountCtrl,
            hint: 'Amount sent (ETB)',
            icon: Icons.monetization_on_rounded,
            inputType: TextInputType.number,
            errorText: amountError,
            onChanged: onAmountChanged,
          ),
          const SizedBox(height: 10),
          _WalletField(
            controller: referenceCtrl,
            hint: 'Transaction reference / FT number',
            icon: Icons.receipt_long_rounded,
            errorText: referenceError,
            onChanged: onReferenceChanged,
          ),
          const SizedBox(height: 16),
          _GoldButton(label: 'SUBMIT DEPOSIT', onTap: onSubmit),
        ]),
      ),
      const SizedBox(height: 20),
      _HistorySection(
          title: 'Deposit History',
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
      _LimitsPill(
        label: 'Withdrawal range: ${state.limits.minWithdraw.toStringAsFixed(0)} – '
            '${state.limits.maxWithdraw.toStringAsFixed(0)} ETB',
      ),
      const SizedBox(height: 20),
      _StepCard(
        step: null,
        title: 'Withdrawal Details',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (banks.isNotEmpty) ...[
            _WalletDropdown(
              label: 'Withdrawal Bank',
              value: banks.contains(activeBank) ? activeBank : banks.first,
              items: banks,
              onChanged: onBankChanged,
              icon: Icons.account_balance_rounded,
            ),
            const SizedBox(height: 10),
          ],
          _WalletField(
            controller: amountCtrl,
            hint: 'Amount (ETB)',
            icon: Icons.monetization_on_rounded,
            inputType: TextInputType.number,
            errorText: amountError,
            onChanged: onAmountChanged,
          ),
          const SizedBox(height: 10),
          _WalletField(
            controller: accountCtrl,
            hint: 'Your account / phone number',
            icon: Icons.account_box_rounded,
            errorText: accountError,
            onChanged: onAccountChanged,
          ),
          const SizedBox(height: 16),
          _GoldButton(label: 'REQUEST WITHDRAWAL', onTap: onSubmit),
        ]),
      ),
      const SizedBox(height: 20),
      _HistorySection(
          title: 'Withdrawal History',
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
      color: _C.goldFill,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _C.goldBorder),
    ),
    child: Row(children: [
      const Icon(Icons.info_outline_rounded, color: _C.gold, size: 15),
      const SizedBox(width: 8),
      Text(label, style: _T.label(size: 11, color: _C.gold, spacing: 0.3)),
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
    decoration: _cardDeco(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (step != null) ...[
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: _C.goldFill,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _C.goldBorder),
            ),
            alignment: Alignment.center,
            child: Text('$step',
                style: _T.label(size: 11, color: _C.gold, spacing: 0)),
          ),
          const SizedBox(width: 10),
        ],
        Text(title, style: _T.body(size: 13, weight: FontWeight.w600)),
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
        color: _C.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.divider),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: isMobile
                ? _C.accent.withOpacity(0.08)
                : _C.blue.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isMobile ? Icons.phone_android_rounded : Icons.account_balance_rounded,
            color: isMobile ? _C.accent : const Color(0xFF7986CB),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(bank.toUpperCase(), style: _T.label(
              size: 10,
              color: isMobile ? _C.accent : const Color(0xFF9FA8DA),
              spacing: 0.8)),
          const SizedBox(height: 2),
          Text(number, style: _T.mono.copyWith(
              fontSize: 14, fontWeight: FontWeight.bold, color: _C.textHigh)),
          if (name.isNotEmpty)
            Text(name, style: _T.label(size: 10, color: _C.textLow, spacing: 0.3)),
        ])),
        IconButton(
          icon: const Icon(Icons.copy_rounded, color: _C.gold, size: 18),
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
      style: _T.body(size: 14),
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: hasError ? _C.danger : _C.gold, size: 19),
        hintText: hint,
        hintStyle: _T.body(size: 13, color: _C.textLow),
        errorText: errorText,
        errorStyle: _T.label(size: 11, color: _C.danger, spacing: 0.2),
        filled: true,
        fillColor: _C.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: hasError ? _C.danger.withOpacity(0.5) : _C.divider,
            width: 0.75,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: hasError ? _C.danger : _C.gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.danger, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.danger, width: 1.5),
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
      color: _C.bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _C.divider, width: 0.75),
    ),
    child: DropdownButtonFormField<String>(
      value: value,
      dropdownColor: _C.card,
      style: _T.body(size: 14),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _C.gold, size: 20),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: _C.gold, size: 19),
        labelText: label,
        labelStyle: _T.label(size: 11, color: _C.textLow, spacing: 0.3),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
      ),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item, style: _T.body(size: 14)),
      )).toList(),
      onChanged: onChanged,
    ),
  );
}

class _GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GoldButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD4AF37), Color(0xFFF5CC50)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(label,
              style: _T.label(size: 13, color: Colors.black, spacing: 1.5)),
        ),
      ),
    ),
  );
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
        child: Text(title, style: _T.body(size: 13, weight: FontWeight.w600)),
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
    final statusColor = status == 'approved' ? _C.success
        : (status == 'pending' ? _C.warning : _C.danger);
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
      backgroundColor: _C.cardHigh,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: _C.divider, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Icon(isDeposit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: _C.gold),
            const SizedBox(width: 10),
            Text(isDeposit ? 'Deposit Receipt' : 'Withdrawal Receipt',
                style: _T.body(size: 16, weight: FontWeight.bold)),
            const Spacer(),
            Icon(statusIcon, color: statusColor, size: 22),
          ]),
          const SizedBox(height: 16),
          Container(height: 0.5, color: _C.divider),
          const SizedBox(height: 14),
          _ReceiptRow('Amount', '${item['amount']} ETB', large: true),
          _ReceiptRow('Bank', item['bank'] ?? '—'),
          if (isDeposit) _ReceiptRow('Reference', item['reference'] ?? '—'),
          if (!isDeposit) _ReceiptRow('Account', item['accountNumber'] ?? '—'),
          _ReceiptRow('Status', status.toUpperCase(), valueColor: statusColor),
          if (item['createdAt'] != null) _ReceiptRow('Submitted', _fmt(item['createdAt'])),
          if (item['verifiedAt'] != null) _ReceiptRow('Verified', _fmt(item['verifiedAt'])),
          if (item['matchedVia'] != null) _ReceiptRow('Matched via', item['matchedVia']),
          if (item['rejectionReason'] != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _C.danger.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.danger.withOpacity(0.2)),
              ),
              child: Text('Reason: ${item['rejectionReason']}',
                  style: _T.body(size: 12, color: _C.danger)),
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _C.warning.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.warning.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.notifications_active_outlined,
                    color: _C.warning, size: 15),
                const SizedBox(width: 8),
                Expanded(child: Text(
                    "You'll receive a push notification when approved.",
                    style: _T.body(size: 11, color: _C.warning))),
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
    final statusColor = status == 'approved' ? _C.success
        : (status == 'pending' ? _C.warning : _C.danger);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: _cardDeco(),
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
                style: _T.body(size: 13, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(item['reference'] ?? item['accountNumber'] ?? '—',
                style: _T.label(size: 10, color: _C.textLow, spacing: 0.2),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${item['amount']} ETB',
                style: _T.mono.copyWith(
                    fontSize: 13, fontWeight: FontWeight.bold, color: _C.gold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(status.toUpperCase(),
                  style: _T.label(size: 9, color: statusColor, spacing: 0.5)),
            ),
          ]),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: _C.textLow, size: 16),
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
      Text(label, style: _T.label(size: 12, color: _C.textLow, spacing: 0.2)),
      Flexible(child: Text(value, textAlign: TextAlign.right,
          style: large
              ? _T.mono.copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor ?? _C.gold)
              : _T.body(size: 13, color: valueColor ?? _C.textHigh, weight: FontWeight.w500))),
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
      Icon(Icons.inbox_outlined, color: _C.textLow, size: 36),
      const SizedBox(height: 10),
      Text(message, style: _T.label(size: 12, color: _C.textLow, spacing: 0.2)),
    ]),
  );
}
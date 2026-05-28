import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../blocs/wallet_cubit.dart';
import '../../core/theme/app_theme.dart';
import 'package:bingo_mk/presentation/widgets/loading_widgets.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Deposit form
  final _depositAmountController = TextEditingController();
  final _referenceController = TextEditingController();
  String? _depositAmountError;
  String? _referenceError;

  // Withdraw form
  final _withdrawAmountController = TextEditingController();
  final _accountController = TextEditingController();
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
    _depositAmountController.dispose();
    _referenceController.dispose();
    _withdrawAmountController.dispose();
    _accountController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ─── FCM token registration ───────────────────────────────────────────────
  Future<void> _registerFcmToken() async {
    try {
      final settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && mounted) {
          context.read<WalletCubit>().saveFcmToken(token);
        }
      }
    } catch (_) {
      // Non-critical — continue without push
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.greenAccent, size: 20),
            const SizedBox(width: 8),
            Text('$label copied!',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        backgroundColor: AppColors.darkCard,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── Inline field validation (called on each keystroke) ──────────────────
  void _validateDepositAmount(String value, WalletLimits limits) {
    final amt = double.tryParse(value);
    String? error;
    if (value.isNotEmpty) {
      if (amt == null || amt <= 0) {
        error = 'Enter a valid number';
      } else {
        // Validate inline using the limits already in scope
        error = null;
        // Simpler: use limits directly
        if (amt < limits.minDeposit) {
          error =
              'Minimum deposit is ${limits.minDeposit.toStringAsFixed(0)} ETB';
        } else if (amt > limits.maxDeposit) {
          error =
              'Maximum deposit is ${limits.maxDeposit.toStringAsFixed(0)} ETB';
        } else {
          error = null;
        }
      }
    }
    setState(() => _depositAmountError = error);
  }

  void _validateWithdrawAmount(String value, WalletLimits limits, double balance) {
    final amt = double.tryParse(value);
    String? error;
    if (value.isNotEmpty) {
      if (amt == null || amt <= 0) {
        error = 'Enter a valid number';
      } else if (amt < limits.minWithdraw) {
        error =
            'Minimum withdrawal is ${limits.minWithdraw.toStringAsFixed(0)} ETB';
      } else if (amt > limits.maxWithdraw) {
        error =
            'Maximum withdrawal is ${limits.maxWithdraw.toStringAsFixed(0)} ETB';
      } else if (amt > balance) {
        error =
            'Insufficient balance (${balance.toStringAsFixed(2)} ETB available)';
      }
    }
    setState(() => _withdrawAmountError = error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: BlocConsumer<WalletCubit, WalletState>(
        listener: (context, state) {
          if (state is WalletLoaded) {
            for (var dep in state.deposits) {
              if (dep['status'] == 'rejected') {
                final reason = dep['rejectionReason'] ?? 'Unknown error';
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showRejectionDialog(
                    context,
                    'Deposit',
                    dep['amount'],
                    reason,
                    () => context
                        .read<WalletCubit>()
                        .deleteTransaction('deposits', dep['id']),
                  );
                });
                break;
              }
            }
            for (var wth in state.withdrawals) {
              if (wth['status'] == 'rejected') {
                final reason = wth['rejectionReason'] ?? 'Unknown error';
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showRejectionDialog(
                    context,
                    'Withdrawal',
                    wth['amount'],
                    reason,
                    () => context
                        .read<WalletCubit>()
                        .deleteTransaction('withdrawals', wth['id']),
                  );
                });
                break;
              }
            }
          }
        },
        builder: (context, state) {
          if (state is WalletLoading) {
            return const Center(child: AppSpinner());
          }
          if (state is WalletLoaded) {
            return RefreshIndicator(
              color: AppColors.secondary,
              backgroundColor: AppColors.darkCard,
              onRefresh: () => context.read<WalletCubit>().loadWallet(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBalanceCard(state.balance),
                    const SizedBox(height: 14),
                    _buildTabs(),
                    const SizedBox(height: 14),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildDepositTab(state),
                          _buildWithdrawTab(state),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state is WalletError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.danger, size: 48),
                  const SizedBox(height: 12),
                  Text(state.message,
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<WalletCubit>().loadWallet(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // ─── Balance card ─────────────────────────────────────────────────────────
  Widget _buildBalanceCard(double balance) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A3D62), Color(0xFF1E3A5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_rounded,
              color: AppColors.secondary, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('WALLET BALANCE',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white60,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${balance.toStringAsFixed(2)} ETB',
                  style: const TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Tabs ─────────────────────────────────────────────────────────────────
  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.secondary,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            fontFamily: 'Orbitron'),
        tabs: const [Tab(text: 'DEPOSIT'), Tab(text: 'WITHDRAW')],
      ),
    );
  }

  // ─── Deposit tab ──────────────────────────────────────────────────────────
  Widget _buildDepositTab(WalletLoaded state) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Limits info banner
        _buildLimitsBanner(
          depositMin: state.limits.minDeposit,
          depositMax: state.limits.maxDeposit,
          isDeposit: true,
        ),
        const SizedBox(height: 14),
        _buildSectionHeader('1. Copy Account Details'),
        const SizedBox(height: 8),
        _buildDepositAccounts(state),
        const SizedBox(height: 20),
        _buildSectionHeader('2. Submit Reference'),
        const SizedBox(height: 8),
        _buildDepositForm(state),
        const SizedBox(height: 24),
        _buildHistorySection('Deposit History', state.deposits, isDeposit: true),
        const SizedBox(height: 40),
      ],
    );
  }

  // ─── Withdraw tab ─────────────────────────────────────────────────────────
  Widget _buildWithdrawTab(WalletLoaded state) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildLimitsBanner(
          depositMin: state.limits.minWithdraw,
          depositMax: state.limits.maxWithdraw,
          isDeposit: false,
        ),
        const SizedBox(height: 14),
        _buildSectionHeader('Request Withdrawal'),
        const SizedBox(height: 8),
        _buildWithdrawForm(state),
        const SizedBox(height: 24),
        _buildHistorySection('Withdrawal History', state.withdrawals,
            isDeposit: false),
        const SizedBox(height: 40),
      ],
    );
  }

  // ─── Limits banner ────────────────────────────────────────────────────────
  Widget _buildLimitsBanner({
    required double depositMin,
    required double depositMax,
    required bool isDeposit,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppColors.secondary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.secondary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isDeposit
                  ? 'Min deposit: ${depositMin.toStringAsFixed(0)} ETB  ·  Max: ${depositMax.toStringAsFixed(0)} ETB'
                  : 'Min withdrawal: ${depositMin.toStringAsFixed(0)} ETB  ·  Max: ${depositMax.toStringAsFixed(0)} ETB',
              style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Account cards ────────────────────────────────────────────────────────
  Widget _buildDepositAccounts(WalletLoaded state) {
    if (state.bankAccounts.isEmpty) {
      return _buildEmptyState(
          Icons.account_balance_outlined, 'No payment accounts configured');
    }
    return Column(
      children: state.bankAccounts.map((account) {
        final bank = account['bank'] as String? ?? '';
        final number = account['accountNumber'] as String? ??
            account['number'] as String? ?? '';
        final name = account['accountName'] as String? ??
            account['name'] as String? ?? '';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildAccountCard(bank, number, name),
        );
      }).toList(),
    );
  }

  Widget _buildAccountCard(String bank, String number, String name) {
    final isMobile = bank.toLowerCase().contains('tele') ||
        bank.toLowerCase().contains('m-pesa');
    final accentColor =
        isMobile ? Colors.lightBlueAccent : Colors.purpleAccent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isMobile
                  ? Icons.phone_android_rounded
                  : Icons.account_balance_rounded,
              color: accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bank.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                        letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(name,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white54)),
                const SizedBox(height: 4),
                Text(number,
                    style: const TextStyle(
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 15)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded,
                color: AppColors.secondary, size: 20),
            onPressed: () => _copyToClipboard(number, '$bank number'),
            tooltip: 'Copy',
          ),
        ],
      ),
    );
  }

  // ─── Deposit form ─────────────────────────────────────────────────────────
  Widget _buildDepositForm(WalletLoaded state) {
    final banks = state.bankAccounts
        .map((a) => a['bank'] as String? ?? '')
        .where((b) => b.isNotEmpty)
        .toList();
    final activeBank = _selectedDepositBank ??
        (banks.isNotEmpty ? banks.first : 'Telebirr');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (banks.isNotEmpty) ...[
          _buildDropdown(
            label: 'Bank Paid To',
            value: banks.contains(activeBank) ? activeBank : banks.first,
            items: banks,
            onChanged: (v) => setState(() => _selectedDepositBank = v),
            icon: Icons.account_balance_wallet_rounded,
          ),
          const SizedBox(height: 12),
        ],
        _buildValidatedTextField(
          controller: _depositAmountController,
          hint: 'Amount Sent (ETB)',
          type: TextInputType.number,
          icon: Icons.monetization_on_rounded,
          errorText: _depositAmountError,
          onChanged: (v) =>
              _validateDepositAmount(v, state.limits),
        ),
        const SizedBox(height: 12),
        _buildValidatedTextField(
          controller: _referenceController,
          hint: 'Transaction Reference / FT Number',
          type: TextInputType.text,
          icon: Icons.receipt_long_rounded,
          errorText: _referenceError,
          onChanged: (v) {
            if (v.trim().isEmpty) {
              setState(() => _referenceError = 'Reference is required');
            } else {
              setState(() => _referenceError = null);
            }
          },
        ),
        const SizedBox(height: 16),
        _buildSubmitButton(
          label: 'SUBMIT DEPOSIT',
          isLoading: state.isActionLoading,
          onPressed: () {
            final amt =
                double.tryParse(_depositAmountController.text) ?? 0;
            final ref = _referenceController.text.trim();

            // Final validation sweep
            final amtErr = amt <= 0
                ? 'Enter a valid amount'
                : (amt < state.limits.minDeposit
                    ? 'Minimum is ${state.limits.minDeposit.toStringAsFixed(0)} ETB'
                    : (amt > state.limits.maxDeposit
                        ? 'Maximum is ${state.limits.maxDeposit.toStringAsFixed(0)} ETB'
                        : null));
            final refErr = ref.isEmpty ? 'Reference is required' : null;

            setState(() {
              _depositAmountError = amtErr;
              _referenceError = refErr;
            });

            if (amtErr != null || refErr != null) return;

            context
                .read<WalletCubit>()
                .deposit(amt, activeBank, ref);
            _depositAmountController.clear();
            _referenceController.clear();
            setState(() {
              _depositAmountError = null;
              _referenceError = null;
            });

            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Deposit submitted — auto-matching in progress…'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ));
          },
        ),
      ],
    );
  }

  // ─── Withdraw form ────────────────────────────────────────────────────────
  Widget _buildWithdrawForm(WalletLoaded state) {
    final banks = state.bankAccounts
        .map((a) => a['bank'] as String? ?? '')
        .where((b) => b.isNotEmpty)
        .toList();
    final activeBank = _selectedWithdrawBank ??
        (banks.isNotEmpty ? banks.first : 'Telebirr');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (banks.isNotEmpty) ...[
          _buildDropdown(
            label: 'Withdrawal Bank',
            value: banks.contains(activeBank) ? activeBank : banks.first,
            items: banks,
            onChanged: (v) => setState(() => _selectedWithdrawBank = v),
            icon: Icons.account_balance_rounded,
          ),
          const SizedBox(height: 12),
        ],
        _buildValidatedTextField(
          controller: _withdrawAmountController,
          hint: 'Amount (ETB)',
          type: TextInputType.number,
          icon: Icons.monetization_on_rounded,
          errorText: _withdrawAmountError,
          onChanged: (v) =>
              _validateWithdrawAmount(v, state.limits, state.balance),
        ),
        const SizedBox(height: 12),
        _buildValidatedTextField(
          controller: _accountController,
          hint: 'Your Bank Account / Phone Number',
          type: TextInputType.text,
          icon: Icons.account_box_rounded,
          errorText: _accountError,
          onChanged: (v) {
            setState(() =>
                _accountError = v.trim().isEmpty ? 'Account is required' : null);
          },
        ),
        const SizedBox(height: 16),
        _buildSubmitButton(
          label: 'REQUEST WITHDRAWAL',
          isLoading: state.isActionLoading,
          onPressed: () {
            final amt =
                double.tryParse(_withdrawAmountController.text) ?? 0;
            final acc = _accountController.text.trim();

            final amtErr = amt <= 0
                ? 'Enter a valid amount'
                : (amt < state.limits.minWithdraw
                    ? 'Minimum is ${state.limits.minWithdraw.toStringAsFixed(0)} ETB'
                    : (amt > state.limits.maxWithdraw
                        ? 'Maximum is ${state.limits.maxWithdraw.toStringAsFixed(0)} ETB'
                        : (amt > state.balance
                            ? 'Insufficient balance'
                            : null)));
            final accErr = acc.isEmpty ? 'Account is required' : null;

            setState(() {
              _withdrawAmountError = amtErr;
              _accountError = accErr;
            });

            if (amtErr != null || accErr != null) return;

            context
                .read<WalletCubit>()
                .withdraw(amt, activeBank, acc);
            _withdrawAmountController.clear();
            _accountController.clear();
            setState(() {
              _withdrawAmountError = null;
              _accountError = null;
            });

            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Withdrawal request submitted!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ));
          },
        ),
      ],
    );
  }

  // ─── Shared form widgets ──────────────────────────────────────────────────
  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: AppColors.darkCard,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon:
              Icon(icon, color: AppColors.secondary, size: 20),
          labelText: label,
          labelStyle:
              const TextStyle(color: Colors.white70, fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
        items: items
            .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item,
                    style: const TextStyle(color: Colors.white))))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildValidatedTextField({
    required TextEditingController controller,
    required String hint,
    required TextInputType type,
    required IconData icon,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.secondary, size: 20),
        hintText: hint,
        hintStyle:
            const TextStyle(color: Colors.white54, fontSize: 13),
        errorText: errorText,
        errorStyle:
            const TextStyle(color: AppColors.danger, fontSize: 11),
        filled: true,
        fillColor: AppColors.darkCard,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: errorText != null
                  ? AppColors.danger.withOpacity(0.5)
                  : Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: errorText != null
                  ? AppColors.danger
                  : AppColors.secondary,
              width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildSubmitButton({
    required String label,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [AppColors.secondary, Color(0xFFFFC107)],
          ),
          boxShadow: [
            BoxShadow(
                color: AppColors.secondary.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.black, strokeWidth: 2.5))
              : Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 13,
                      fontFamily: 'Orbitron',
                      letterSpacing: 1.2)),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5));
  }

  // ─── Transaction history ──────────────────────────────────────────────────
  Widget _buildHistorySection(
      String title, List<Map<String, dynamic>> items,
      {required bool isDeposit}) {
    final visible =
        items.where((i) => i['status'] != 'rejected').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          _buildEmptyState(
              isDeposit
                  ? Icons.inbox_outlined
                  : Icons.outbox_outlined,
              isDeposit
                  ? 'No deposits yet'
                  : 'No withdrawals yet')
        else
          ...visible.map((item) => _buildHistoryTile(item, isDeposit)),
      ],
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> item, bool isDeposit) {
    final status = item['status'] as String? ?? 'pending';
    final statusColor = status == 'approved'
        ? Colors.greenAccent
        : (status == 'pending' ? Colors.amberAccent : AppColors.danger);

    return GestureDetector(
      onTap: () => _showReceiptSheet(context, item, isDeposit),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDeposit
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: statusColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['bank'] as String? ?? '—',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['reference'] ??
                        item['accountNumber'] ??
                        '—',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item['amount']} ETB',
                  style: const TextStyle(
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                      fontSize: 13),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  // ─── Receipt bottom sheet ─────────────────────────────────────────────────
  void _showReceiptSheet(
      BuildContext context, Map<String, dynamic> item, bool isDeposit) {
    final status = item['status'] as String? ?? 'pending';
    final statusColor = status == 'approved'
        ? Colors.greenAccent
        : (status == 'pending' ? Colors.amberAccent : AppColors.danger);
    final statusIcon = status == 'approved'
        ? Icons.check_circle_rounded
        : (status == 'pending'
            ? Icons.hourglass_top_rounded
            : Icons.cancel_rounded);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),

              // Title + status icon
              Row(
                children: [
                  Icon(
                    isDeposit
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isDeposit ? 'Deposit Receipt' : 'Withdrawal Receipt',
                    style: const TextStyle(
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16),
                  ),
                  const Spacer(),
                  Icon(statusIcon, color: statusColor, size: 22),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white12),
              const SizedBox(height: 12),

              // Amount
              _receiptRow('Amount',
                  '${item['amount']} ETB', isLarge: true),
              _receiptRow('Bank', item['bank'] ?? '—'),
              if (isDeposit)
                _receiptRow(
                    'Reference', item['reference'] ?? '—'),
              if (!isDeposit)
                _receiptRow(
                    'Account', item['accountNumber'] ?? '—'),
              _receiptRow('Status', status.toUpperCase(),
                  valueColor: statusColor),
              if (item['createdAt'] != null)
                _receiptRow('Submitted',
                    _formatTimestamp(item['createdAt'])),
              if (item['verifiedAt'] != null)
                _receiptRow('Verified',
                    _formatTimestamp(item['verifiedAt'])),
              if (item['matchedVia'] != null)
                _receiptRow(
                    'Matched via', item['matchedVia'] ?? '—'),
              if (item['rejectionReason'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.danger.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Reason: ${item['rejectionReason']}',
                          style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (status == 'pending')
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.amber.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.notifications_active_outlined,
                          color: Colors.amberAccent, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "You'll receive a push notification when this is approved.",
                          style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _receiptRow(String label, String value,
      {bool isLarge = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: isLarge ? 18 : 13,
                fontWeight: isLarge
                    ? FontWeight.bold
                    : FontWeight.w500,
                fontFamily: isLarge ? 'Orbitron' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '—';
    try {
      // Firestore Timestamp
      final dt = (ts as dynamic).toDate() as DateTime;
      return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts.toString();
    }
  }

  // ─── Rejection dialog ─────────────────────────────────────────────────────
  void _showRejectionDialog(BuildContext context, String type,
      dynamic amount, String reason, VoidCallback onDelete) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.redAccent),
          const SizedBox(width: 8),
          Text('$type Rejected',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your $type of $amount ETB was rejected.',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.redAccent.withOpacity(0.15)),
              ),
              child: Text('Reason: $reason',
                  style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('DISMISS',
                style: TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────
  Widget _buildEmptyState(IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, color: Colors.white24, size: 40),
          const SizedBox(height: 10),
          Text(message,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _accountController = TextEditingController();
  String? _selectedBank;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<WalletCubit>().loadWallet();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _accountController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              '$label copied!',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Wallet Ledger',
          style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold),
        ),
      ),
      body: BlocBuilder<WalletCubit, WalletState>(
        builder: (context, state) {
          if (state is WalletLoading) {
            return const Center(child: AppSpinner());
          }
          if (state is WalletLoaded) {
            return RefreshIndicator(
              onRefresh: () => context.read<WalletCubit>().loadWallet(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBalanceCard(state.balance),
                    const SizedBox(height: 16),
                    _buildTabs(),
                    const SizedBox(height: 16),
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
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildBalanceCard(double balance) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Column(
        children: [
          const Text(
            'CURRENT WALLET BALANCE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${balance.toStringAsFixed(2)} ETB',
            style: const TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.primary,
        ),
        labelColor: Colors.black,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Orbitron'),
        tabs: const [
          Tab(text: 'DEPOSIT'),
          Tab(text: 'WITHDRAW'),
        ],
      ),
    );
  }

  Widget _buildDepositTab(WalletLoaded state) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildInfoBox(
          'Automated Verification',
          'Send real money to one of the accounts below, then input your transaction Reference number. The system will verify and credit your balance automatically!',
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('1. Select & Copy Account Details'),
        const SizedBox(height: 8),
        _buildDepositAccounts(state),
        const SizedBox(height: 20),
        _buildSectionHeader('2. Submit Reference'),
        const SizedBox(height: 8),
        _buildDepositForm(state),
        const SizedBox(height: 24),
        _buildHistorySection('Recent Deposit History', state.deposits),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildWithdrawTab(WalletLoaded state) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildInfoBox(
          'Withdraw Funds',
          'Withdrawals are processed securely back to your banking account of choice within 24 hours.',
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('Request Withdrawal'),
        const SizedBox(height: 8),
        _buildWithdrawForm(state),
        const SizedBox(height: 24),
        _buildHistorySection('Recent Withdrawal History', state.withdrawals),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildInfoBox(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositAccounts(WalletLoaded state) {
    if (state.bankAccounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const Text('No payment accounts configured.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return Column(
      children: state.bankAccounts.map((account) {
        final bank = account['bank'] as String? ?? 'Telebirr';
        final number = account['number'] as String? ?? '';
        final name = account['name'] as String? ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildAccountCard(bank, number, name),
        );
      }).toList(),
    );
  }

  Widget _buildAccountCard(String bank, String number, String name) {
    final isTelebirr = bank.toLowerCase().contains('tele');
    final accentColor = isTelebirr ? Colors.lightBlueAccent : Colors.purpleAccent;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isTelebirr ? Icons.phone_android_rounded : Icons.account_balance_rounded,
              color: accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      bank.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '($name)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  number,
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 20),
            onPressed: () => _copyToClipboard(number, '$bank Number'),
            tooltip: 'Copy Number',
          ),
        ],
      ),
    );
  }

  Widget _buildDepositForm(WalletLoaded state) {
    final activeBank = _selectedBank ?? (state.bankAccounts.isNotEmpty ? state.bankAccounts.first['bank'] as String : 'Telebirr');

    return Column(
      children: [
        if (state.bankAccounts.isNotEmpty) ...[
          _buildDropdownField(
            label: 'Select Bank You Paid To',
            value: state.bankAccounts.any((a) => a['bank'] == activeBank) ? activeBank : state.bankAccounts.first['bank'] as String,
            items: state.bankAccounts.map((a) => a['bank'] as String? ?? '').toList(),
            onChanged: (val) {
              setState(() {
                _selectedBank = val;
              });
            },
            icon: Icons.account_balance_wallet_rounded,
          ),
          const SizedBox(height: 12),
        ],
        _buildTextField(
          _amountController,
          'Amount Sent (ETB)',
          TextInputType.number,
          Icons.monetization_on_rounded,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _referenceController,
          'Transaction Reference / FT Number',
          TextInputType.text,
          Icons.receipt_long_rounded,
        ),
        const SizedBox(height: 16),
        _buildSubmitButton('SUBMIT DEPOSIT', () {
          final amt = double.tryParse(_amountController.text) ?? 0;
          final ref = _referenceController.text.trim();

          if (amt <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enter a valid deposit amount')),
            );
            return;
          }
          if (ref.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enter transaction reference number')),
            );
            return;
          }

          context.read<WalletCubit>().deposit(amt, activeBank, ref);
          
          // Clear inputs on success submit to improve user feel
          _amountController.clear();
          _referenceController.clear();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Deposit requested! Auto-matching processing...'),
              backgroundColor: Colors.green,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWithdrawForm(WalletLoaded state) {
    final activeBank = _selectedBank ?? (state.bankAccounts.isNotEmpty ? state.bankAccounts.first['bank'] as String : 'Telebirr');

    return Column(
      children: [
        if (state.bankAccounts.isNotEmpty) ...[
          _buildDropdownField(
            label: 'Select Withdrawal Bank',
            value: state.bankAccounts.any((a) => a['bank'] == activeBank) ? activeBank : state.bankAccounts.first['bank'] as String,
            items: state.bankAccounts.map((a) => a['bank'] as String? ?? '').toList(),
            onChanged: (val) {
              setState(() {
                _selectedBank = val;
              });
            },
            icon: Icons.account_balance_rounded,
          ),
          const SizedBox(height: 12),
        ],
        _buildTextField(
          _amountController,
          'Withdraw Amount (ETB)',
          TextInputType.number,
          Icons.monetization_on_rounded,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _accountController,
          'Your Bank Account Number / Phone',
          TextInputType.text,
          Icons.account_box_rounded,
        ),
        const SizedBox(height: 16),
        _buildSubmitButton('REQUEST WITHDRAWAL', () {
          final amt = double.tryParse(_amountController.text) ?? 0;
          final acc = _accountController.text.trim();

          if (amt <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enter a valid withdrawal amount')),
            );
            return;
          }
          if (acc.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enter target bank account number')),
            );
            return;
          }

          context.read<WalletCubit>().withdraw(amt, activeBank, acc);
          
          _amountController.clear();
          _accountController.clear();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Withdrawal request submitted!'),
              backgroundColor: Colors.green,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: AppColors.card,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item, style: const TextStyle(color: Colors.white)),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    TextInputType type,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: AppColors.card,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildSubmitButton(String label, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primary],
        ),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 13,
            fontFamily: 'Orbitron',
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection(String title, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            child: const Text(
              'No recent transactions found',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          )
        else
          ...items.map((item) => _buildHistoryItem(item)),
      ],
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final status = item['status'] as String;
    final color = status == 'approved'
        ? Colors.greenAccent
        : (status == 'pending' ? Colors.amberAccent : Colors.redAccent);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${item['bank']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item['amount']} ETB',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.primary,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item['reference'] ?? item['accountNumber'] ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

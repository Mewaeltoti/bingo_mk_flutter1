import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/wallet_cubit.dart';
import '../../core/theme/app_theme.dart';

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
  final String _selectedBank = 'Telebirr';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<WalletCubit>().loadWallet();
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
          'Wallet',
          style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold),
        ),
      ),
      body: BlocBuilder<WalletCubit, WalletState>(
        builder: (context, state) {
          if (state is WalletLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is WalletLoaded) {
            return RefreshIndicator(
              onRefresh: () => context.read<WalletCubit>().loadWallet(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBalanceCard(state.balance),
                  const SizedBox(height: 20),
                  _buildTabs(),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 600, // Fixed height for tab content
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
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildBalanceCard(double balance) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Text(
            'CURRENT BALANCE',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${balance.toStringAsFixed(2)} ETB',
            style: const TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 32,
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
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primary],
          ),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: 'DEPOSIT'),
          Tab(text: 'WITHDRAW'),
        ],
      ),
    );
  }

  Widget _buildDepositTab(WalletLoaded state) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBox(
            'Deposit Instructions',
            'Send money to one of the accounts below and enter the transaction reference.',
          ),
          const SizedBox(height: 16),
          _buildDepositAccounts(),
          const SizedBox(height: 24),
          _buildDepositForm(),
          const SizedBox(height: 32),
          _buildHistorySection('Recent Deposits', state.deposits),
        ],
      ),
    );
  }

  Widget _buildWithdrawTab(WalletLoaded state) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBox(
            'Withdrawal',
            'Requests are processed within 24 hours.',
          ),
          const SizedBox(height: 16),
          _buildWithdrawForm(),
          const SizedBox(height: 32),
          _buildHistorySection('Recent Withdrawals', state.withdrawals),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
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
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositAccounts() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildAccountRow('Telebirr', '0978187178', 'Ephrem'),
          const Divider(height: 24, color: AppColors.border),
          _buildAccountRow('CBE', '1000217643426', 'Ephrem'),
        ],
      ),
    );
  }

  Widget _buildAccountRow(String bank, String number, String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bank,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              number,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 14,
              ),
            ),
          ],
        ),
        Text(
          name,
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildDepositForm() {
    return Column(
      children: [
        _buildTextField(
          _amountController,
          'Amount (ETB)',
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _referenceController,
          'Transaction Reference',
          TextInputType.text,
        ),
        const SizedBox(height: 20),
        _buildSubmitButton('SUBMIT DEPOSIT', () {
          final amt = double.tryParse(_amountController.text) ?? 0;
          context.read<WalletCubit>().deposit(
            amt,
            _selectedBank,
            _referenceController.text,
          );
        }),
      ],
    );
  }

  Widget _buildWithdrawForm() {
    return Column(
      children: [
        _buildTextField(
          _amountController,
          'Amount (ETB)',
          TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _accountController,
          'Account Number',
          TextInputType.text,
        ),
        const SizedBox(height: 20),
        _buildSubmitButton('REQUEST WITHDRAWAL', () {
          final amt = double.tryParse(_amountController.text) ?? 0;
          context.read<WalletCubit>().withdraw(
            amt,
            _selectedBank,
            _accountController.text,
          );
        }),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    TextInputType type,
  ) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildSubmitButton(String label, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primary],
        ),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection(String title, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Center(
            child: Text(
              'No recent transactions',
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
        ? Colors.green
        : (status == 'pending' ? Colors.amber : Colors.red);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item['bank']} — ${item['amount']} ETB',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                item['reference'] ?? item['accountNumber'] ?? '',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
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
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/lms_api_client.dart';

class LmsPaymentsScreen extends StatefulWidget {
  const LmsPaymentsScreen({super.key});

  @override
  State<LmsPaymentsScreen> createState() => _LmsPaymentsScreenState();
}

class _LmsPaymentsScreenState extends State<LmsPaymentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _summary;
  List<dynamic> _invoices = [];
  List<dynamic> _feeConfigs = [];
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _generatedInvoice;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        LmsApiClient.get('/payments/student-summary'),
        LmsApiClient.get('/payments/invoices'),
        LmsApiClient.get('/payments/fee-configs'),
      ]);
      setState(() {
        _summary = Map<String, dynamic>.from(results[0].data);
        _invoices = (results[1].data as List<dynamic>?) ?? [];
        _feeConfigs = (results[2].data as List<dynamic>?) ?? [];
      });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _generateInvoice(String feeType) async {
    setState(() { _loading = true; _error = null; _generatedInvoice = null; });
    try {
      final res = await LmsApiClient.post('/payments/invoices', data: {'feeType': feeType});
      setState(() { _generatedInvoice = Map<String, dynamic>.from(res.data); });
      await _fetchData();
      _tabController.animateTo(1);
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _downloadReceipt(String invoiceId) async {
    try {
      final receiptRes = await LmsApiClient.get('/payments/invoices/$invoiceId/receipt');
      final receipt = Map<String, dynamic>.from(receiptRes.data);

      final dio = await LmsApiClient.getDio();
      await dio.get(
        '/payments/receipts/${receipt['id']}/download',
        options: Options(responseType: ResponseType.bytes),
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt #${receipt['receiptNumber']} ready. Save from browser or use Share.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to download receipt')),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'COMPLETE': case 'REMITTED': return Colors.green;
      case 'COLLECTED': case 'REMITTING': return Colors.blue;
      case 'FAILED': case 'EXPIRED': return Colors.red;
      default: return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'COMPLETE': case 'REMITTED': return Icons.check_circle;
      case 'COLLECTED': case 'REMITTING': return Icons.hourglass_top;
      case 'FAILED': case 'EXPIRED': return Icons.error;
      default: return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Invoices'),
            Tab(text: 'Pay Fee'),
          ],
        ),
      ),
      body: _loading && _summary == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.red.shade50,
                    child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverview(),
                      _buildInvoices(),
                      _buildPayFee(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOverview() {
    if (_summary == null) return const Center(child: Text('No data'));
    final outstanding = Map<String, dynamic>.from(_summary!['outstandingBalances'] ?? {});
    final recent = (_summary!['recentPayments'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          _StatCard(label: 'Invoices', value: '${_summary!['totalInvoices']}', icon: Icons.receipt, color: Colors.blue),
          const SizedBox(width: 12),
          _StatCard(label: 'Completed', value: '${_summary!['completedPayments']}', icon: Icons.check_circle, color: Colors.green),
        ]),
        if (outstanding.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Outstanding Balances', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...outstanding.entries.map((e) => Card(
            child: ListTile(
              title: Text(e.key.toString().replaceAll('_', ' ')),
              subtitle: null,
              trailing: Text('₦${(e.value as num).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ),
          )),
        ],
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Recent Payments', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ...recent.map((p) {
            final pm = p as Map<String, dynamic>;
            return ListTile(
              leading: const Icon(Icons.receipt, color: Colors.green),
              title: Text(pm['feeType'].toString().replaceAll('_', ' ')),
              subtitle: Text(pm['receiptNumber'] as String? ?? ''),
              trailing: Text('₦${(pm['totalAmount'] as num).toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            );
          }),
        ],
      ]),
    );
  }

  Widget _buildInvoices() {
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: _invoices.isEmpty
          ? ListView(children: const [Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No invoices yet')))])
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _invoices.length,
              itemBuilder: (ctx, i) {
                final inv = _invoices[i] as Map<String, dynamic>;
                final status = inv['status'] as String? ?? 'AWAITING_PAYMENT';
                final isComplete = status == 'COMPLETE' || status == 'REMITTED';
                return Card(
                  child: ListTile(
                    leading: Icon(_statusIcon(status), color: _statusColor(status)),
                    title: Text(inv['feeType'].toString().replaceAll('_', ' ')),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('₦${(inv['totalAmount'] as num).toStringAsFixed(0)} (Fee: ${inv['amount']} + Processing: ${inv['serviceFee']})',
                          style: const TextStyle(fontSize: 12)),
                        if (inv['virtualAccountNumber'] != null)
                          Text('Account: ${inv['virtualAccountNumber']} (${inv['virtualAccountBank']})',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                    trailing: isComplete
                        ? IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () => _downloadReceipt(inv['id']),
                            tooltip: 'Download Receipt',
                          )
                        : status == 'AWAITING_PAYMENT'
                            ? TextButton(
                                onPressed: null,
                                child: const Text('View'))
                            : null,
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildPayFee() {
    if (_generatedInvoice != null) {
      return _buildInvoiceDetail(_generatedInvoice!);
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Select what you want to pay for', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (_feeConfigs.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No fee configurations available. Contact administrator.'))),
      ..._feeConfigs.map((cfg) {
        final cm = cfg as Map<String, dynamic>;
        final amount = (cm['amount'] as num?) ?? 0;
        final serviceFee = (cm['serviceFee'] as num?) ?? 0;
        return Card(
          child: ListTile(
            leading: const Icon(Icons.payment, color: Colors.blue),
            title: Text(cm['label'] as String? ?? cm['feeType']),
            subtitle: Text('₦$amount + ₦$serviceFee processing fee'),
            trailing: FilledButton(
              onPressed: _loading ? null : () => _generateInvoice(cm['feeType'] as String),
              child: const Text('Pay'),
            ),
            onTap: _loading ? null : () => _generateInvoice(cm['feeType'] as String),
          ),
        );
      }),
    ]);
  }

  Widget _buildInvoiceDetail(Map<String, dynamic> inv) {
    final total = (inv['totalAmount'] as num?) ?? 0;
    final amount = (inv['amount'] as num?) ?? 0;
    final serviceFee = (inv['serviceFee'] as num?) ?? 0;

    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text('Invoice Ready', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),
            Text('Bank: ${inv['virtualAccountBank'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
              child: Column(children: [
                const Text('Virtual Account Number', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(inv['virtualAccountNumber'] ?? 'N/A',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'monospace')),
              ]),
            ),
            const SizedBox(height: 16),
            const Divider(),
            _FeeRow(label: 'Fee Amount', amount: amount),
            _FeeRow(label: 'Processing Fee', amount: serviceFee),
            const Divider(),
            _FeeRow(label: 'Total', amount: total, bold: true),
            const SizedBox(height: 12),
            const Text('Pay the total amount to the account above via your bank app, USSD, OPay or POS. Payment will be confirmed automatically.',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        icon: const Icon(Icons.refresh),
        label: const Text('Check Payment Status'),
        onPressed: _fetchData,
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () { setState(() { _generatedInvoice = null; }); },
        child: const Text('Create Another Invoice'),
      ),
    ]);
  }
}

class _FeeRow extends StatelessWidget {
  final String label;
  final num amount;
  final bool bold;
  const _FeeRow({required this.label, required this.amount, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text('₦${amount.toStringAsFixed(0)}', style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ]),
        ),
      ),
    );
  }
}

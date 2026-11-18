import 'package:cake_wallet/store/simulator_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';

/// Full-page settings UI for the balance simulator.
/// Add a route entry in your router and a tile in the main Settings screen
/// pointing to this page.
class SimulatorSettingsPage extends StatefulWidget {
  const SimulatorSettingsPage({super.key, required this.simulatorStore});

  final SimulatorStore simulatorStore;

  @override
  State<SimulatorSettingsPage> createState() => _SimulatorSettingsPageState();
}

class _SimulatorSettingsPageState extends State<SimulatorSettingsPage> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _txAmountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _amountController.text =
        widget.simulatorStore.simulatedXmrAmount.toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _txAmountController.dispose();
    super.dispose();
  }

  void _applyAmount() {
    final val = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (val == null || val < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount (≥ 0)')),
      );
      return;
    }
    widget.simulatorStore.setAmount(val);
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Simulated balance set to $val XMR')),
    );
  }

  Future<void> _addTransaction(String type) async {
    if (!_formKey.currentState!.validate()) return;
    final amount =
        double.parse(_txAmountController.text.replaceAll(',', '.'));
    await widget.simulatorStore.addTransaction(
      amount: type == 'receive' ? amount : -amount,
      type: type,
      note: _noteController.text,
    );
    _txAmountController.clear();
    _noteController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.simulatorStore;
    final dateFormat = DateFormat('MMM d, y · HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Balance Simulator'),
        centerTitle: true,
      ),
      body: Observer(
        builder: (_) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Enable toggle ──────────────────────────────────────────────
            Card(
              child: SwitchListTile(
                title: const Text('Enable simulator'),
                subtitle: const Text(
                    'Displays a simulated XMR balance and simulated entries in history. It does not change real wallet funds or real transaction history.'),
                value: store.isEnabled,
                onChanged: (v) => store.setEnabled(v),
              ),
            ),

            const SizedBox(height: 16),

            // ── Set balance directly ───────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Simulated XMR amount',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]')),
                            ],
                            decoration: const InputDecoration(
                              suffixText: 'XMR',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _applyAmount,
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current: ${store.simulatedXmrAmount.toStringAsFixed(6)} XMR',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Add fake transaction ───────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add simulated transaction',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _txAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Amount (XMR)',
                          suffixText: 'XMR',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v.replaceAll(',', '.')) == null) {
                            return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          labelText: 'Note (optional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.arrow_downward, size: 16),
                              label: const Text('Receive'),
                              onPressed: () => _addTransaction('receive'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.arrow_upward, size: 16),
                              label: const Text('Send'),
                              onPressed: () => _addTransaction('send'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Transaction history ────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Simulated history',
                    style: Theme.of(context).textTheme.titleSmall),
                if (store.transactions.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Clear all?'),
                          content: const Text(
                              'This resets the simulated balance to 0 and deletes all fake transactions.'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text('Clear')),
                          ],
                        ),
                      );
                      if (confirm == true) await store.clearAll();
                    },
                    child: const Text('Clear all'),
                  ),
              ],
            ),

            if (store.transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No simulated transactions yet.',
                      style: TextStyle(color: Colors.grey)),
                ),
              ),

            ...store.transactions.map((tx) {
              final isReceive = tx.type == 'receive';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isReceive ? Colors.green.shade100 : Colors.red.shade100,
                    child: Icon(
                      isReceive
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      color: isReceive ? Colors.green : Colors.red,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    '${isReceive ? '+' : ''}${tx.amount.toStringAsFixed(6)} XMR',
                    style: TextStyle(
                      color: isReceive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateFormat.format(tx.date),
                          style: const TextStyle(fontSize: 11)),
                      if (tx.note.isNotEmpty)
                        Text(tx.note,
                            style: const TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic)),
                    ],
                  ),
                  isThreeLine: tx.note.isNotEmpty,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => store.removeTransaction(tx.id),
                    tooltip: 'Remove',
                  ),
                ),
              );
            }),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

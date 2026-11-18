import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A fake transaction for display in the history list
class SimulatedTransaction {
  SimulatedTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.date,
    this.note = '',
  });

  final String id;
  final double amount; // positive = receive, negative = send
  final String type;  // 'receive' | 'send'
  final DateTime date;
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'type': type,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory SimulatedTransaction.fromJson(Map<String, dynamic> j) =>
      SimulatedTransaction(
        id: j['id'] as String,
        amount: (j['amount'] as num).toDouble(),
        type: j['type'] as String,
        date: DateTime.parse(j['date'] as String),
        note: j['note'] as String? ?? '',
      );
}

class SimulatorStore {
  static const _keyEnabled = 'simulator_enabled';
  static const _keyAmount = 'simulator_xmr_amount';
  static const _keyTxs = 'simulator_transactions';

  // ── State ────────────────────────────────────────────────────────────────

  final Observable<bool> _isEnabled = Observable(false);

  bool get isEnabled => _isEnabled.value;
  set isEnabled(bool value) => _isEnabled.value = value;

  final Observable<double> _simulatedXmrAmount = Observable(0.0);

  double get simulatedXmrAmount => _simulatedXmrAmount.value;
  set simulatedXmrAmount(double value) => _simulatedXmrAmount.value = value;

  final Observable<double?> _simulatedXmrPrice = Observable(null);
  String? _priceCurrency;
  DateTime? _lastPriceFetch;
  Timer? _priceRefreshTimer;

  double? get simulatedXmrPrice => _simulatedXmrPrice.value;

  String? get simulatedPriceCurrency => _priceCurrency;

  void startXmrPriceRefresh(String fiatCurrency) {
    _priceRefreshTimer?.cancel();
    refreshXmrPrice(fiatCurrency);
    _priceRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => refreshXmrPrice(fiatCurrency),
    );
  }

  void stopXmrPriceRefresh() {
    _priceRefreshTimer?.cancel();
    _priceRefreshTimer = null;
  }

  Future<void> refreshXmrPrice(String fiatCurrency) async {
    final currency = fiatCurrency.toUpperCase();
    if (currency.isEmpty) return;

    if (_priceCurrency != currency) {
      _priceCurrency = currency;
      _simulatedXmrPrice.value = null;
      _lastPriceFetch = null;
    }

    final lastFetch = _lastPriceFetch;
    if (lastFetch != null && DateTime.now().difference(lastFetch).inSeconds < 60) {
      return;
    }

    _lastPriceFetch = DateTime.now();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final uri = Uri.https('api.coinpaprika.com', '/v1/tickers/xmr-monero', {
        'quotes': currency,
      });
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != HttpStatus.ok) return;

      final body = await response.transform(utf8.decoder).join();
      final ticker = jsonDecode(body) as Map<String, dynamic>;
      final quotes = ticker['quotes'] as Map<String, dynamic>?;
      final quote = quotes?[currency] as Map<String, dynamic>?;
      final price = (quote?['price'] as num?)?.toDouble();
      if (price != null && price.isFinite && price > 0 && _priceCurrency == currency) {
        _simulatedXmrPrice.value = price;
      }
    } catch (_) {
      // A failed demo-price lookup leaves the last known price in place.
    } finally {
      client.close(force: true);
    }
  }

  final ObservableList<SimulatedTransaction> transactions =
      ObservableList<SimulatedTransaction>();

  // ── Load / Save ──────────────────────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isEnabled = prefs.getBool(_keyEnabled) ?? false;
    simulatedXmrAmount = prefs.getDouble(_keyAmount) ?? 0.0;
    final raw = prefs.getString(_keyTxs);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      transactions.addAll(
        list.map((e) => SimulatedTransaction.fromJson(e as Map<String, dynamic>)),
      );
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, isEnabled);
    await prefs.setDouble(_keyAmount, simulatedXmrAmount);
    await prefs.setString(
      _keyTxs,
      jsonEncode(transactions.map((t) => t.toJson()).toList()),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> setEnabled(bool value) async {
    isEnabled = value;
    await _save();
  }

  Future<void> setAmount(double amount) async {
    simulatedXmrAmount = amount;
    await _save();
  }

  Future<void> addTransaction({
    required double amount,
    required String type,
    String note = '',
  }) async {
    final tx = SimulatedTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      type: type,
      date: DateTime.now(),
      note: note,
    );
    transactions.insert(0, tx);
    simulatedXmrAmount += amount;
    if (simulatedXmrAmount < 0) simulatedXmrAmount = 0;
    await _save();
  }

  Future<void> removeTransaction(String id) async {
    final tx = transactions.firstWhere((t) => t.id == id);
    transactions.removeWhere((t) => t.id == id);
    simulatedXmrAmount -= tx.amount;
    if (simulatedXmrAmount < 0) simulatedXmrAmount = 0;
    await _save();
  }

  Future<void> clearAll() async {
    transactions.clear();
    simulatedXmrAmount = 0.0;
    await _save();
  }
}

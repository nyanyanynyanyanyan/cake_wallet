import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/store/simulator_store.dart';
import 'package:cake_wallet/view_model/dashboard/balance_view_model.dart';
import 'package:cake_wallet/view_model/dashboard/transaction_list_item.dart';
import 'package:cw_core/amount/money.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:flutter/foundation.dart';

class SimulatedTransactionInfo extends TransactionInfo {
  SimulatedTransactionInfo(SimulatedTransaction transaction) {
    id = 'demo_${transaction.id}';
    txHash = id;
    amount = Money.parse(
      transaction.amount.abs().toStringAsFixed(CryptoCurrency.xmr.decimals),
      CryptoCurrency.xmr,
    );
    direction =
        transaction.amount >= 0 ? TransactionDirection.incoming : TransactionDirection.outgoing;
    isPending = false;
    date = transaction.date;
    confirmations = 10;
    additionalInfo = {
      'isSimulatorDemo': true,
      'demoNote': transaction.note,
    };
  }
}

class SimulatedTransactionListItem extends TransactionListItem {
  SimulatedTransactionListItem({
    required SimulatedTransaction transaction,
    required BalanceViewModel balanceViewModel,
    required AppStore appStore,
  }) : super(
          transaction: SimulatedTransactionInfo(transaction),
          balanceViewModel: balanceViewModel,
          appStore: appStore,
          key: ValueKey('simulated_transaction_${transaction.id}'),
        );

  @override
  double get price =>
      balanceViewModel.fiatConversionStore.prices[CryptoCurrency.xmr] ??
      balanceViewModel.simulatorStore.simulatedXmrPrice ??
      0;

  @override
  String get formattedTitle => super.formattedTitle;
}

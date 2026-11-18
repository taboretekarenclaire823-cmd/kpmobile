import 'package:flutter/material.dart';

Future<void> showFeePaymentPrompt({
  required BuildContext context,
  required Map<String, dynamic>? fee,
  required String recordLabel,
  required String recordNumber,
  required Future<void> Function() onPayOnline,
  String? linkedBlotterNumber,
  bool sharedFeeAlreadySatisfied = false,
}) {
  final satisfied = fee?['satisfied'] == true;
  final canPayOnline = fee?['can_pay_online'] == true;
  final balance = fee?['balance'];
  final amount = '₱${((balance ?? 0) as num).toStringAsFixed(2)}';
  final sharedFeeStatus = fee?['status']?.toString().toLowerCase();

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(satisfied ? Icons.verified_outlined : Icons.payments_outlined),
      title: Text(
        sharedFeeAlreadySatisfied
            ? 'No additional fee due'
            : satisfied
            ? 'Filing fee is settled'
            : 'Filing fee',
      ),
      content: Text(
        sharedFeeAlreadySatisfied
            ? 'The fee for linked blotter '
                  '${linkedBlotterNumber ?? recordNumber} has already been '
                  '$sharedFeeStatus. This complaint uses that same fee, so no '
                  'second payment is due.'
            : fee == null
            ? 'Your $recordLabel $recordNumber was filed. The barangay has not '
                  'set a fee for it yet. Check this screen again later for updates.'
            : satisfied
            ? 'Your $recordLabel fee is already ${fee['status'].toString().toLowerCase()}. '
                  'No additional payment is due.'
            : 'Your $recordLabel $recordNumber has a balance of $amount.',
      ),
      actions: [
        if (fee != null && !satisfied && canPayOnline)
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onPayOnline();
            },
            icon: const Icon(Icons.account_balance_wallet),
            label: Text('Pay $amount with GCash'),
          ),
        if (fee != null && !satisfied)
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  icon: const Icon(Icons.local_atm_outlined),
                  title: const Text('Pay in cash'),
                  content: Text(
                    'Pay $amount at the barangay hall. Show $recordLabel '
                    '$recordNumber so staff can record your payment. It will '
                    'appear here after it has been recorded. If this fee was '
                    'already paid through a linked blotter or complaint, do '
                    'not pay again.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.local_atm_outlined),
            label: const Text('Pay cash at barangay hall'),
          ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(
            fee == null || satisfied || sharedFeeAlreadySatisfied
                ? 'Close'
                : 'Pay later',
          ),
        ),
      ],
    ),
  );
}

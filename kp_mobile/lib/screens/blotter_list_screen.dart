import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../widgets/app_ui.dart';
import '../widgets/fee_payment_prompt.dart';
import 'blotter_form_screen.dart';

String _errorText(Object? e) =>
    (e ?? 'Something went wrong.').toString().replaceFirst('Exception: ', '');

AppBar _appBar(BuildContext context, String title) {
  final colors = Theme.of(context).colorScheme;

  return AppBar(
    backgroundColor: colors.primary,
    foregroundColor: colors.onPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
    title: Text(title),
  );
}

class BlotterListScreen extends StatefulWidget {
  final bool canFile;

  const BlotterListScreen({super.key, this.canFile = true});

  @override
  State<BlotterListScreen> createState() => _BlotterListScreenState();
}

class _BlotterListScreenState extends State<BlotterListScreen> {
  late Future<List<Map<String, dynamic>>> _future = ApiService.getBlotters();

  Future<void> _reload() async {
    setState(() => _future = ApiService.getBlotters());
    try {
      await _future;
    } catch (_) {
      // The error is shown by the FutureBuilder below.
    }
  }

  Future<void> _newReport() async {
    final blotterId = await Navigator.of(
      context,
    ).push<int>(MaterialPageRoute(builder: (_) => const BlotterFormScreen()));
    if (!mounted || blotterId == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            BlotterDetailScreen(id: blotterId, showPaymentPrompt: true),
      ),
    );
    if (!mounted) return;
    await _reload();
  }

  String _summary(List<Map<String, dynamic>> reports) {
    if (reports.isEmpty) return 'Nothing filed yet';

    final inProgress = reports
        .where((r) => r['status'] == 'Open' || r['status'] == 'Pending')
        .length;
    final total =
        '${reports.length} ${reports.length == 1 ? 'report' : 'reports'}';

    return inProgress == 0 ? total : '$total  •  $inProgress in progress';
  }

  Widget _reportCard(Map<String, dynamic> r) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlotterDetailScreen(id: r['id'] as int),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r['blotter_number'].toString(),
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    StatusBadge(status: r['status'].toString()),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  r['title'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                MetaLine(
                  icon: Icons.category_outlined,
                  text: r['incident_type'].toString(),
                ),
                const SizedBox(height: 4),
                MetaLine(
                  icon: Icons.schedule,
                  text: 'Reported ${r['date_reported']}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(context, 'My reports'),
      floatingActionButton: widget.canFile
          ? FloatingActionButton.extended(
              onPressed: _newReport,
              icon: const Icon(Icons.add),
              label: const Text('New report'),
            )
          : null,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ErrorState(
              message: _errorText(snapshot.error),
              onRetry: _reload,
            );
          }

          final reports = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                ScreenHeader(
                  icon: Icons.list_alt,
                  title: 'Your incident reports',
                  subtitle: _summary(reports),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                  child: reports.isEmpty
                      ? const EmptyState(
                          icon: Icons.description_outlined,
                          title: 'No reports yet',
                          message: 'Tap "New report" to send an incident report to the barangay.',
                        )
                      : Column(children: reports.map(_reportCard).toList()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class BlotterDetailScreen extends StatefulWidget {
  final int id;
  final bool showPaymentPrompt;

  const BlotterDetailScreen({
    super.key,
    required this.id,
    this.showPaymentPrompt = false,
  });

  @override
  State<BlotterDetailScreen> createState() => _BlotterDetailScreenState();
}

class _BlotterDetailScreenState extends State<BlotterDetailScreen>
    with WidgetsBindingObserver {
  late Future<Map<String, dynamic>> _future = ApiService.getBlotter(widget.id);
  bool _paying = false;
  bool _awaitingPayment = false;
  bool _paymentPromptShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingPayment) {
      _checkAfterPayment();
    }
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _reload() async {
    setState(() => _future = ApiService.getBlotter(widget.id));
    try {
      await _future;
    } catch (_) {
      // The error is shown by the FutureBuilder below.
    }
  }

  Future<void> _payOnline() async {
    setState(() => _paying = true);
    try {
      final url = await ApiService.startBlotterPayment(widget.id);
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (opened) {
        _awaitingPayment = true;
      } else {
        _msg('Could not open the payment page.');
      }
    } catch (e) {
      _msg(_errorText(e));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _checkAfterPayment() async {
    _awaitingPayment = false;

    for (var i = 0; i < 5; i++) {
      if (!mounted) return;
      try {
        final blotter = await ApiService.getBlotter(widget.id);
        if (!mounted) return;
        setState(() => _future = Future.value(blotter));

        final fee = blotter['fee'];
        if (fee is Map && fee['satisfied'] == true) {
          _msg('Payment received. Thank you!');
          return;
        }
      } catch (_) {
        // Retry below while the webhook records the confirmed payment.
      }
      await Future.delayed(const Duration(seconds: 3));
    }

    _msg(
      'We have not received your payment yet. '
      'Pull down to refresh in a moment.',
    );
  }

  String _names(dynamic list) {
    final names = (list as List?)?.map((e) => e.toString()).toList() ?? [];
    return names.isEmpty ? '—' : names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: _appBar(context, 'Report details'),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: _errorText(snapshot.error),
              onRetry: _reload,
            );
          }

          final b = snapshot.data!;
          final fee = b['fee'] == null
              ? null
              : Map<String, dynamic>.from(b['fee'] as Map);
          if (widget.showPaymentPrompt && !_paymentPromptShown) {
            _paymentPromptShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              showFeePaymentPrompt(
                context: context,
                fee: fee,
                recordLabel: 'blotter',
                recordNumber: b['blotter_number'].toString(),
                onPayOnline: _payOnline,
              );
            });
          }
          final payments = (b['payments'] as List? ?? [])
              .map((payment) => Map<String, dynamic>.from(payment as Map))
              .toList();

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                HeaderBand(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b['blotter_number'].toString(),
                        style: TextStyle(
                          color: colors.onPrimary.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        b['title'].toString(),
                        style: TextStyle(
                          color: colors.onPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 16),
                      StatusBadge(status: b['status'].toString(), onDark: true),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionCard(
                        title: 'Incident details',
                        icon: Icons.info_outline,
                        children: [
                          DetailRow(
                            label: 'Type of incident',
                            value: b['incident_type'].toString(),
                          ),
                          DetailRow(
                            label: 'When it happened',
                            value: b['incident_at']?.toString() ?? '—',
                          ),
                          DetailRow(
                            label: 'Incident location',
                            value: b['incident_location']?.toString() ?? '—',
                          ),
                          if (b['incident_location'] == 'Outside Paraiso') ...[
                            DetailRow(
                              label: 'Incident barangay',
                              value: b['incident_barangay']?.toString() ?? '—',
                            ),
                            DetailRow(
                              label: 'Incident city / municipality',
                              value: b['incident_city']?.toString() ?? '—',
                            ),
                          ],
                          DetailRow(
                            label: 'Reported on',
                            value: b['date_reported']?.toString() ?? '—',
                          ),
                          if (b['complaint_number'] != null)
                            DetailRow(
                              label: 'Linked complaint',
                              value: b['complaint_number'].toString(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SectionCard(
                        title: 'Description',
                        icon: Icons.notes,
                        children: [
                          Text(
                            b['details']?.toString() ?? '—',
                            style: const TextStyle(
                              fontSize: 15.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SectionCard(
                        title: 'People',
                        icon: Icons.groups_outlined,
                        children: [
                          DetailRow(
                            label: 'Person involved',
                            value: _names(b['respondents']),
                          ),
                          DetailRow(
                            label: 'Witnesses',
                            value: _names(b['witnesses']),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (fee != null) ...[
                        SectionCard(
                          title: 'Filing fee',
                          icon: Icons.payments_outlined,
                          children: [
                            DetailRow(
                              label: 'Status',
                              value: fee['status'].toString(),
                            ),
                            DetailRow(
                              label: 'Amount due',
                              value:
                                  '₱${(fee['amount_due'] as num).toStringAsFixed(2)}',
                            ),
                            DetailRow(
                              label: 'Paid',
                              value:
                                  '₱${(fee['paid'] as num).toStringAsFixed(2)}',
                            ),
                            DetailRow(
                              label: 'Balance',
                              value:
                                  '₱${(fee['balance'] as num).toStringAsFixed(2)}',
                            ),
                            if (fee['satisfied'] != true)
                              OutlinedButton.icon(
                                onPressed: _paying
                                    ? null
                                    : () => showFeePaymentPrompt(
                                        context: context,
                                        fee: fee,
                                        recordLabel: 'blotter',
                                        recordNumber: b['blotter_number']
                                            .toString(),
                                        onPayOnline: _payOnline,
                                      ),
                                icon: _paying
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.payments_outlined),
                                label: const Text('Payment options'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SectionCard(
                          title: 'Payments',
                          icon: Icons.receipt_long_outlined,
                          children: payments.isEmpty
                              ? const [
                                  Text('No payment has been recorded yet.'),
                                ]
                              : payments.map((payment) {
                                  final reference =
                                      (payment['reference_number'] ?? '')
                                          .toString();
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.receipt_long),
                                    title: Text(
                                      '₱${(payment['amount'] as num).toStringAsFixed(2)}'
                                      ' • ${payment['payment_method'] ?? '—'}',
                                    ),
                                    subtitle: Text(
                                      '${payment['or_number'] ?? '—'}'
                                      ' • ${payment['paid_at'] ?? '—'}'
                                      '${reference.isEmpty ? '' : '\nRef: $reference'}',
                                    ),
                                  );
                                }).toList(),
                        ),
                      ] else
                        const SectionCard(
                          title: 'Filing fee',
                          icon: Icons.payments_outlined,
                          children: [
                            Text(
                              'The barangay has not set a fee for this report yet.',
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

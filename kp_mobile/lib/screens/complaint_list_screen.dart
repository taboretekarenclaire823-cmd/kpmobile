import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../widgets/app_ui.dart';
import '../widgets/fee_payment_prompt.dart';
import '../widgets/hearing_tile.dart';
import 'complaint_form_screen.dart';

String _errorText(Object? e) =>
    (e ?? 'Something went wrong.').toString().replaceFirst('Exception: ', '');

String _money(dynamic v) => '₱${((v ?? 0) as num).toStringAsFixed(2)}';

class ComplaintListScreen extends StatefulWidget {
  final bool canFile;

  const ComplaintListScreen({super.key, this.canFile = true});

  @override
  State<ComplaintListScreen> createState() => _ComplaintListScreenState();
}

class _ComplaintListScreenState extends State<ComplaintListScreen> {
  late Future<List<Map<String, dynamic>>> _future = ApiService.getComplaints();

  Future<void> _reload() async {
    setState(() => _future = ApiService.getComplaints());
    try {
      await _future;
    } catch (_) {
      // The error is shown by the FutureBuilder below.
    }
  }

  Future<void> _newComplaint() async {
    final complaintId = await Navigator.of(
      context,
    ).push<int>(MaterialPageRoute(builder: (_) => const ComplaintFormScreen()));
    if (!mounted || complaintId == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ComplaintDetailScreen(id: complaintId, showPaymentPrompt: true),
      ),
    );
    if (!mounted) return;
    await _reload();
  }

  String _summary(List<Map<String, dynamic>> complaints) {
    if (complaints.isEmpty) return 'Nothing filed yet';

    const finished = ['Settled', 'Certified', 'Closed', 'Dismissed'];
    final active = complaints
        .where((c) => !finished.contains(c['status']))
        .length;
    final total =
        '${complaints.length} ${complaints.length == 1 ? 'complaint' : 'complaints'}';

    return active == 0 ? total : '$total  •  $active active';
  }

  Widget _complaintCard(Map<String, dynamic> c) {
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
              builder: (_) => ComplaintDetailScreen(id: c['id'] as int),
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
                        c['complaint_number'].toString(),
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    StatusBadge(status: c['status'].toString()),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  c['title'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                MetaLine(
                  icon: Icons.category_outlined,
                  text: c['complaint_type'].toString(),
                ),
                const SizedBox(height: 4),
                MetaLine(
                  icon: Icons.schedule,
                  text: 'Filed ${c['date_filed']}',
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
      appBar: styledAppBar(context, 'My complaints'),
      floatingActionButton: widget.canFile
          ? FloatingActionButton.extended(
              onPressed: _newComplaint,
              icon: const Icon(Icons.add),
              label: const Text('New complaint'),
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

          final complaints = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                ScreenHeader(
                  icon: Icons.gavel,
                  title: 'Your complaints',
                  subtitle: _summary(complaints),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                  child: complaints.isEmpty
                      ? const EmptyState(
                          icon: Icons.gavel_outlined,
                          title: 'No complaints yet',
                          message: 'Tap "New complaint" to file a formal complaint with the barangay.',
                        )
                      : Column(
                          children: complaints.map(_complaintCard).toList(),
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

class ComplaintDetailScreen extends StatefulWidget {
  final int id;
  final bool showPaymentPrompt;

  const ComplaintDetailScreen({
    super.key,
    required this.id,
    this.showPaymentPrompt = false,
  });

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen>
    with WidgetsBindingObserver {
  late Future<Map<String, dynamic>> _future = ApiService.getComplaint(
    widget.id,
  );

  bool _paying = false; // starting the checkout
  bool _awaitingPayment = false; // the browser/GCash page is open
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

  /// Coming back from the browser/GCash: check the real payment status.
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
    setState(() => _future = ApiService.getComplaint(widget.id));
    try {
      await _future;
    } catch (_) {
      // The error is shown by the FutureBuilder below.
    }
  }

  /// The server records the payment when PayMongo confirms it, which can
  /// take a few seconds, so ask a few times before giving up.
  Future<void> _checkAfterPayment() async {
    _awaitingPayment = false;

    for (var i = 0; i < 5; i++) {
      if (!mounted) return;
      try {
        final c = await ApiService.getComplaint(widget.id);
        if (!mounted) return;
        setState(() => _future = Future.value(c));

        final fee = c['fee'];
        if (fee is Map && fee['satisfied'] == true) {
          _msg('Payment received. Thank you!');
          return;
        }
      } catch (_) {
        // Try again below.
      }
      await Future.delayed(const Duration(seconds: 3));
    }

    _msg(
      'We have not received your payment yet. '
      'Pull down to refresh in a moment.',
    );
  }

  Future<void> _payOnline() async {
    setState(() => _paying = true);
    try {
      final url = await ApiService.startComplaintPayment(widget.id);
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

  String _names(dynamic list) {
    final names = (list as List?)?.map((e) => e.toString()).toList() ?? [];
    return names.isEmpty ? '—' : names.join(', ');
  }

  // ------------------------------------------------------------ fee card

  Widget _stat(String label, String value, {bool highlight = false}) {
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: highlight
              ? colors.primaryContainer
              : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight ? colors.primaryContainer : colors.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: highlight
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: highlight ? colors.onPrimaryContainer : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBox(String text) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: colors.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCashPaymentInstructions({
    required String complaintNumber,
    required dynamic balance,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.payments_outlined),
        title: const Text('Pay in cash'),
        content: Text(
          'Pay ${_money(balance)} at the barangay hall. Show complaint '
          '$complaintNumber so staff can record the payment. It will appear '
          'here after it has been recorded. Do not pay again if this fee was '
          'already paid through a linked blotter.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _feeCard(Map<String, dynamic> fee, {required String complaintNumber}) {
    final colors = Theme.of(context).colorScheme;
    final satisfied = fee['satisfied'] == true;
    final canPayOnline = fee['can_pay_online'] == true;

    return SectionCard(
      title: 'Filing fee',
      icon: Icons.payments_outlined,
      children: [
        Row(
          children: [
            Text(
              'Status',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            StatusBadge(status: fee['status'].toString()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _stat('Amount due', _money(fee['amount_due'])),
            const SizedBox(width: 10),
            _stat('Paid', _money(fee['paid'])),
            const SizedBox(width: 10),
            _stat('Balance', _money(fee['balance']), highlight: !satisfied),
          ],
        ),
        if (!satisfied) ...[
          const SizedBox(height: 18),
          Text(
            'Choose how to pay',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (canPayOnline) ...[
            SizedBox(
              height: 54,
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _paying ? null : _payOnline,
                icon: _paying
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : const Icon(Icons.account_balance_wallet),
                label: Text(
                  'Pay ${_money(fee['balance'])} with GCash',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
          if (canPayOnline) const SizedBox(height: 10),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showCashPaymentInstructions(
                complaintNumber: complaintNumber,
                balance: fee['balance'],
              ),
              icon: const Icon(Icons.local_atm_outlined),
              label: const Text('Pay cash at barangay hall'),
            ),
          ),
          const SizedBox(height: 12),
          _infoBox(
            'The fee must be paid or waived before summons and mediation '
            'can proceed. If a linked blotter fee was already paid, no '
            'additional payment is due.',
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------- payments card

  Widget _paymentRow(Map<String, dynamic> p) {
    final colors = Theme.of(context).colorScheme;
    final ref = (p['reference_number'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.receipt_long,
              size: 20,
              color: colors.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['or_number'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '${p['paid_at'] ?? '—'}  •  ${p['payment_method'] ?? '—'}'
                  '${ref.isEmpty ? '' : '\nRef: $ref'}',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _money(p['amount']),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _paymentsCard(Map<String, dynamic> c) {
    final colors = Theme.of(context).colorScheme;
    final payments = (c['payments'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final rows = <Widget>[];
    for (var i = 0; i < payments.length; i++) {
      rows.add(_paymentRow(payments[i]));
      if (i != payments.length - 1) rows.add(const Divider(height: 1));
    }

    return SectionCard(
      title: 'Payments',
      icon: Icons.receipt_long_outlined,
      children: payments.isEmpty
          ? [
              Text(
                'No payment has been recorded yet.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ]
          : rows,
    );
  }

  Widget _workflowCard(List<Map<String, dynamic>> stages) {
    final colors = Theme.of(context).colorScheme;

    return SectionCard(
      title: 'KP process progress',
      icon: Icons.route_outlined,
      children: [
        for (var i = 0; i < stages.length; i++) ...[
          _workflowStage(stages[i], colors),
          if (i != stages.length - 1) const Divider(height: 24),
        ],
      ],
    );
  }

  Widget _workflowStage(
    Map<String, dynamic> stage,
    ColorScheme colors,
  ) {
    final status = stage['status']?.toString() ?? 'upcoming';
    final (color, icon) = switch (status) {
      'complete' => (Colors.green, Icons.check),
      'current' => (colors.primary, Icons.play_arrow),
      'blocked' => (colors.error, Icons.block),
      'skipped' => (colors.outline, Icons.remove),
      _ => (colors.outline, Icons.more_horiz),
    };
    final date = stage['date']?.toString();
    final deadline = stage['deadline']?.toString();
    final schedule = stage['schedule']?.toString();
    final hasSchedule = schedule != null && schedule.isNotEmpty;
    final showRecordedDate = date != null &&
        date.isNotEmpty &&
        (!hasSchedule || stage['key'] == 'arbitration');
    final dateLabel =
        stage['key'] == 'arbitration' ? 'Recorded' : 'Date';
    final label = status.isEmpty
        ? status
        : '${status[0].toUpperCase()}${status.substring(1)}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      stage['title']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                stage['description']?.toString() ?? '',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              if (hasSchedule) ...[
                const SizedBox(height: 5),
                Text(
                  'Scheduled: $schedule',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
              if (showRecordedDate || (deadline != null && deadline.isNotEmpty)) ...[
                const SizedBox(height: 5),
                Text(
                  [
                    if (showRecordedDate)
                      '$dateLabel: $date',
                    if (deadline != null && deadline.isNotEmpty)
                      'Due: $deadline',
                  ].join('  ·  '),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: styledAppBar(context, 'Complaint details'),
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

          final c = snapshot.data!;
          final fee = c['fee'] == null
              ? null
              : Map<String, dynamic>.from(c['fee'] as Map);
          final sharedBlotterFeeSatisfied =
              c['blotter_number'] != null && fee?['satisfied'] == true;
          if (widget.showPaymentPrompt && !_paymentPromptShown) {
            _paymentPromptShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              showFeePaymentPrompt(
                context: context,
                fee: fee,
                recordLabel: 'complaint',
                recordNumber: c['complaint_number'].toString(),
                onPayOnline: _payOnline,
                linkedBlotterNumber: c['blotter_number']?.toString(),
                sharedFeeAlreadySatisfied: sharedBlotterFeeSatisfied,
              );
            });
          }
          final hearings = (c['hearings'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final workflow = (c['workflow'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
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
                        c['complaint_number'].toString(),
                        style: TextStyle(
                          color: colors.onPrimary.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c['title'].toString(),
                        style: TextStyle(
                          color: colors.onPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 16),
                      StatusBadge(status: c['status'].toString(), onDark: true),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionCard(
                        title: 'Complaint details',
                        icon: Icons.info_outline,
                        children: [
                          DetailRow(
                            label: 'Type of complaint',
                            value: c['complaint_type'].toString(),
                          ),
                          DetailRow(
                            label: 'Filed on',
                            value: c['date_filed']?.toString() ?? '—',
                          ),
                          DetailRow(
                            label: 'Screening',
                            value: c['screening_outcome']?.toString() ??
                                'Pending',
                          ),
                          DetailRow(
                            label: 'Venue assessment',
                            value: c['venue_result']?.toString() ?? '—',
                          ),
                          DetailRow(
                            label: 'When it happened',
                            value: c['incident_at']?.toString() ?? '—',
                          ),
                          DetailRow(
                            label: 'Incident location',
                            value: c['incident_location']?.toString() ?? '—',
                          ),
                          if (c['incident_location'] == 'Outside Paraiso') ...[
                            DetailRow(
                              label: 'Incident barangay',
                              value: c['incident_barangay']?.toString() ?? '—',
                            ),
                            DetailRow(
                              label: 'Incident city / municipality',
                              value: c['incident_city']?.toString() ?? '—',
                            ),
                          ],
                          DetailRow(
                            label: 'Linked report',
                            value: c['blotter_number']?.toString() ?? '—',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SectionCard(
                        title: 'Description',
                        icon: Icons.notes,
                        children: [
                          Text(
                            c['details']?.toString() ?? '—',
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
                            label: 'Complainant',
                            value: _names(c['complainants']),
                          ),
                          DetailRow(
                            label: 'Person complained about',
                            value: _names(c['respondents']),
                          ),
                          DetailRow(
                            label: 'Witnesses',
                            value: _names(c['witnesses']),
                          ),
                        ],
                      ),
                      if (workflow.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _workflowCard(workflow),
                      ],
                      if (fee != null) ...[
                        const SizedBox(height: 20),
                        _feeCard(
                          fee,
                          complaintNumber: c['complaint_number'].toString(),
                        ),
                        const SizedBox(height: 20),
                        _paymentsCard(c),
                      ],
                      const SizedBox(height: 20),
                      SectionCard(
                        title: 'Hearings',
                        icon: Icons.event,
                        children: hearings.isEmpty
                            ? [
                                Text(
                                  'No hearing has been scheduled yet.',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ]
                            : [
                                for (final h in hearings)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: HearingTile(hearing: h),
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

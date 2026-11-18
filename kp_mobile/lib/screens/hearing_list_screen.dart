import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/hearing_tile.dart';

String _errorText(Object? e) =>
    (e ?? 'Something went wrong.').toString().replaceFirst('Exception: ', '');

class HearingListScreen extends StatefulWidget {
  const HearingListScreen({super.key});

  @override
  State<HearingListScreen> createState() => _HearingListScreenState();
}

class _HearingListScreenState extends State<HearingListScreen> {
  late Future<List<Map<String, dynamic>>> _future = ApiService.getHearings();

  Future<void> _reload() async {
    setState(() => _future = ApiService.getHearings());
    try {
      await _future;
    } catch (_) {
      // The error is shown by the FutureBuilder below.
    }
  }

  // --------------------------------------------------------------- pieces

  Widget _summaryHeader({
    required int upcoming,
    required int past,
    required String? next,
  }) {
    final colors = Theme.of(context).colorScheme;

    Widget stat(String value, String label, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colors.onPrimary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: colors.onPrimary, size: 22),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.onPrimary.withValues(alpha: 0.85),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              stat('$upcoming', 'Upcoming', Icons.event),
              const SizedBox(width: 12),
              stat('$past', 'Past', Icons.event_available),
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: colors.onPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Next hearing: $next',
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int count, IconData icon) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: colors.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _centered({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 46, color: colors.onPrimaryContainer),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, height: 1.4),
        ),
        if (action != null) ...[
          const SizedBox(height: 24),
          Center(child: action),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Hearing schedule'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: _centered(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load hearings',
                message: _errorText(snapshot.error),
                action: FilledButton.tonalIcon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ),
            );
          }

          final hearings = snapshot.data ?? [];
          final upcoming =
              hearings.where((h) => h['is_upcoming'] == true).toList();
          final past =
              hearings.where((h) => h['is_upcoming'] != true).toList();

          if (hearings.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: _centered(
                icon: Icons.event_busy_outlined,
                title: 'No hearings yet',
                message: 'You will see your hearings here once the '
                    'barangay sets a date.',
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                _summaryHeader(
                  upcoming: upcoming.length,
                  past: past.length,
                  next: upcoming.isEmpty
                      ? null
                      : upcoming.first['scheduled_at']?.toString(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (upcoming.isNotEmpty) ...[
                        _sectionHeader('Upcoming', upcoming.length, Icons.event),
                        ...upcoming.map(
                          (h) => HearingTile(hearing: h, showComplaint: true),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (past.isNotEmpty) ...[
                        _sectionHeader(
                            'Past', past.length, Icons.event_available),
                        ...past.map(
                          (h) => HearingTile(hearing: h, showComplaint: true),
                        ),
                      ],
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
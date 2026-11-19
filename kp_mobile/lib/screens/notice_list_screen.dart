import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../services/api_service.dart';
import '../widgets/app_ui.dart';

String _errorText(Object? e) =>
    (e ?? 'Something went wrong.').toString().replaceFirst('Exception: ', '');

/// "My summons" - notices where the resident is the respondent.
class SummonsListScreen extends StatelessWidget {
  const SummonsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NoticeListScreen(
      title: 'My summons',
      emptyText: 'You have no summons.',
      icon: Icons.description_outlined,
      loader: ApiService.getSummons,
      downloader: ApiService.downloadSummons,
    );
  }
}

/// "My subpoenas" - notices where the resident is a witness.
class SubpoenaListScreen extends StatelessWidget {
  const SubpoenaListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NoticeListScreen(
      title: 'My subpoenas',
      emptyText: 'You have no subpoenas.',
      icon: Icons.assignment_outlined,
      loader: ApiService.getSubpoenas,
      downloader: ApiService.downloadSubpoena,
    );
  }
}

class NoticeListScreen extends StatefulWidget {
  final String title;
  final String emptyText;
  final IconData icon;
  final Future<List<Map<String, dynamic>>> Function() loader;

  /// Downloads the notice's letter (PDF) and returns the saved file path.
  final Future<String> Function(int id, String fileName) downloader;

  const NoticeListScreen({
    super.key,
    required this.title,
    required this.emptyText,
    required this.icon,
    required this.loader,
    required this.downloader,
  });

  @override
  State<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends State<NoticeListScreen> {
  late Future<List<Map<String, dynamic>>> _future = widget.loader();
  int? _openingId;

  Future<void> _reload() async {
    setState(() => _future = widget.loader());
    try {
      await _future;
    } catch (_) {
      // The error is shown by the FutureBuilder below.
    }
  }

  Future<void> _openPdf(Map<String, dynamic> n) async {
    final id = n['id'] as int;
    setState(() => _openingId = id);

    try {
      final fileName = 'KP-Form-${n['form_number']}-${n['kp_form_no']}.pdf';
      final path = await widget.downloader(id, fileName);
      final result = await OpenFilex.open(path);

      if (!mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No PDF viewer was found on this phone.'),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_errorText(e))));
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  String _val(dynamic v) =>
      (v == null || v.toString().isEmpty) ? '—' : v.toString();

  Color _noticeColor(String status) {
    switch (status) {
      case 'Cancelled':
        return Colors.red;
      case 'Served':
      case 'Acknowledged':
      case 'Delivered':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  Widget _badge(String status) {
    final color = _noticeColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _summary(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return 'Nothing received';

    final upcoming = items.where((n) => n['is_upcoming'] == true).length;
    final total = '${items.length} ${items.length == 1 ? 'notice' : 'notices'}';

    return upcoming == 0 ? total : '$total  •  $upcoming upcoming';
  }

  Widget _letterButton(Map<String, dynamic> n) {
    final opening = _openingId == n['id'];
    final hasFile = n['has_file'] == true;

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          onPressed: hasFile && !opening ? () => _openPdf(n) : null,
          icon: opening
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined),
          label: Text(hasFile ? 'Open letter (PDF)' : 'Letter not available'),
        ),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> n) {
    final colors = Theme.of(context).colorScheme;
    final upcoming = n['is_upcoming'] == true;
    final status = n['status'].toString();

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
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: upcoming
                    ? colors.primaryContainer
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.icon,
                color: upcoming
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${n['number']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _badge(status),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MetaLine(
                    icon: Icons.event,
                    text: 'Appear: ${n['appearance_at'] ?? '—'}',
                  ),
                  if (upcoming) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Upcoming',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            children: [
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(height: 14),
              DetailRow(
                  label: 'Complaint', value: _val(n['complaint_number'])),
              DetailRow(
                  label: 'Case title', value: _val(n['complaint_title'])),
              DetailRow(
                  label: 'Appearance date & time',
                  value: _val(n['appearance_at'])),
              DetailRow(
                  label: 'Place of appearance',
                  value: _val(n['place_of_appearance'])),
              DetailRow(label: 'Date issued', value: _val(n['date_issued'])),
              DetailRow(label: 'Issued by', value: _val(n['issued_by'])),
              if (_val(n['service_mode']) != '—')
                DetailRow(label: 'How served', value: _val(n['service_mode'])),
              if (_val(n['date_served']) != '—')
                DetailRow(label: 'Date served', value: _val(n['date_served'])),
              if (_val(n['served_by']) != '—')
                DetailRow(label: 'Served by', value: _val(n['served_by'])),
              _letterButton(n),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: styledAppBar(context, widget.title),
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

          final items = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                ScreenHeader(
                  icon: widget.icon,
                  title: widget.title,
                  subtitle: _summary(items),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: items.isEmpty
                      ? EmptyState(
                          icon: widget.icon,
                          title: widget.emptyText,
                          message:
                              'Notices from the barangay will appear here.',
                        )
                      : Column(children: items.map(_tile).toList()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
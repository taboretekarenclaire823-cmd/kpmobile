import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../services/api_service.dart';
import '../widgets/app_ui.dart';

String _errorText(Object? e) =>
    (e ?? 'Something went wrong.').toString().replaceFirst('Exception: ', '');

/// How a document is labelled and colored in the list.
class _Kind {
  final String label;
  final IconData icon;
  final Color color;

  const _Kind(this.label, this.icon, this.color);
}

_Kind _kindOf(String formNumber) {
  switch (formNumber) {
    case '15':
      return const _Kind('Arbitration award', Icons.gavel, Colors.green);
    case '21':
    case '22':
      return const _Kind('Bar order', Icons.block, Colors.red);
    default:
      // Forms 20, 20-A and 20-B: certificate to file action.
      return const _Kind(
          'Certificate', Icons.workspace_premium_outlined, Colors.blue);
  }
}

class CertificateListScreen extends StatefulWidget {
  const CertificateListScreen({super.key});

  @override
  State<CertificateListScreen> createState() => _CertificateListScreenState();
}

class _CertificateListScreenState extends State<CertificateListScreen> {
  late Future<List<Map<String, dynamic>>> _future =
      ApiService.getCertificates();
  int? _openingId;

  Future<void> _reload() async {
    final next = ApiService.getCertificates();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {
      // The error is shown by the FutureBuilder below.
    }
  }

  Future<void> _openPdf(Map<String, dynamic> cert) async {
    final id = cert['id'] as int;
    setState(() => _openingId = id);

    try {
      final fileName =
          'KP-Form-${cert['form_number']}-${cert['kp_form_no']}.pdf';
      final path = await ApiService.downloadCertificate(id, fileName);
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

  String _summary(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return 'Nothing issued yet';
    return '${items.length} ${items.length == 1 ? 'document' : 'documents'}';
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> c) {
    final colors = Theme.of(context).colorScheme;
    final kind = _kindOf('${c['form_number']}');
    final opening = _openingId == c['id'];
    final hasFile = c['has_file'] == true;
    final title = (c['title'] ?? kind.label).toString();

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
          onTap: hasFile && !opening ? () => _openPdf(c) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: kind.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(kind.icon, color: kind.color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'KP Form No. ${c['form_number']}',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _badge(kind.label, kind.color),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: colors.outlineVariant),
                const SizedBox(height: 14),
                MetaLine(
                  icon: Icons.folder_open_outlined,
                  text: 'Complaint ${c['complaint_number'] ?? '—'}',
                ),
                const SizedBox(height: 6),
                MetaLine(
                  icon: Icons.event,
                  text: 'Issued ${c['date_issued'] ?? '—'}',
                ),
                const SizedBox(height: 6),
                MetaLine(
                  icon: Icons.person_outline,
                  text: 'You: ${c['my_role'] ?? '—'}',
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: hasFile && !opening ? () => _openPdf(c) : null,
                    icon: opening
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                        hasFile ? 'Open PDF' : 'File not available'),
                  ),
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
      appBar: styledAppBar(context, 'Certificates & awards'),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return ErrorState(
              message: _errorText(snap.error),
              onRetry: _reload,
            );
          }

          final items = snap.data ?? [];

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                ScreenHeader(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Certificates & awards',
                  subtitle: _summary(items),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: items.isEmpty
                      ? const EmptyState(
                          icon: Icons.workspace_premium_outlined,
                          title: 'No certificates or awards yet.',
                          message: 'They appear here once the barangay '
                              'issues one for your complaint.',
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
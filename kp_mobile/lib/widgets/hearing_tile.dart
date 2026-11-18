import 'package:flutter/material.dart';

/// One hearing as a card. Used by the hearing schedule and the
/// complaint detail screen.
class HearingTile extends StatelessWidget {
  final Map<String, dynamic> hearing;
  final bool showComplaint;

  const HearingTile({
    super.key,
    required this.hearing,
    this.showComplaint = false,
  });

  String? _text(String key) {
    final value = hearing[key];
    if (value == null || value.toString().trim().isEmpty) return null;
    return value.toString();
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'Mediation':
        return Colors.blue.shade700;
      case 'Conciliation':
        return Colors.teal.shade700;
      case 'Arbitration':
        return Colors.deepPurple.shade600;
      case 'Compliance Hearing':
        return Colors.orange.shade800;
      default:
        return Colors.blueGrey;
    }
  }

  Color _attendanceColor(String? s) {
    switch (s) {
      case 'Both Present':
        return Colors.green.shade700;
      case 'Complainant No-Show':
      case 'Respondent No-Show':
      case 'Both No-Show':
        return Colors.red.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  Color _outcomeColor(String? s) {
    switch (s) {
      case 'Settlement':
      case 'Award Issued':
        return Colors.green.shade700;
      case 'No Settlement':
        return Colors.red.shade700;
      case 'Postponed':
        return Colors.orange.shade800;
      default:
        return Colors.blueGrey;
    }
  }

  /// Splits "Oct 06, 2026 1:46 PM" into month, day, year and time.
  ({String month, String day, String year, String time})? _dateParts() {
    final raw = _text('scheduled_at');
    if (raw == null) return null;

    final m = RegExp(r'^([A-Za-z]{3})\s+(\d{1,2}),\s+(\d{4})\s+(.+)$')
        .firstMatch(raw.trim());
    if (m == null) return null;

    return (
      month: m.group(1)!.toUpperCase(),
      day: m.group(2)!,
      year: m.group(3)!,
      time: m.group(4)!,
    );
  }

  // -------------------------------------------------------------- widgets

  Widget _dateBadge(Color color, bool upcoming) {
    final parts = _dateParts();
    final tint = upcoming ? color : Colors.blueGrey;

    return Container(
      width: 58,
      height: 64,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: parts == null
          ? Icon(Icons.event, color: tint)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  parts.month,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: tint,
                  ),
                ),
                Text(
                  parts.day,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                    color: tint,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {bool muted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.3,
                color: muted ? Colors.grey : Colors.black87,
                fontStyle: muted ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _personRow(String label, String? name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.person_outline, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  name ?? 'Not assigned yet',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: name == null ? Colors.grey : Colors.black87,
                    fontStyle:
                        name == null ? FontStyle.italic : FontStyle.normal,
                    fontWeight:
                        name == null ? FontWeight.normal : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pangkatBlock(BuildContext context, Color color) {
    final raw = hearing['pangkat'];
    final type = hearing['hearing_type']?.toString();

    if (raw is! Map) {
      if (type != 'Conciliation') return const SizedBox.shrink();
      return _infoRow(Icons.groups_outlined, 'Pangkat not formed yet',
          muted: true);
    }

    final pangkat = Map<String, dynamic>.from(raw);
    final number = pangkat['number']?.toString().trim() ?? '';
    final members = (pangkat['members'] is List)
        ? (pangkat['members'] as List).whereType<Map>().toList()
        : <Map>[];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups_outlined, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                number.isEmpty ? 'Pangkat' : 'Pangkat $number',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
          if (members.isNotEmpty) const SizedBox(height: 8),
          for (final m in members)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      m['name']?.toString() ?? '',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  if ((m['role']?.toString() ?? '').isNotEmpty)
                    _chip(m['role'].toString(), color),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final type = hearing['hearing_type']?.toString();
    final color = _typeColor(type);
    final upcoming = hearing['is_upcoming'] == true;
    final rehearing = hearing['is_rehearing'] == true;

    final parts = _dateParts();
    final venue = _text('venue');
    final reference = _text('case_reference');
    final presider = _text('presider');
    final secretary = _text('secretary');
    final myRole = _text('my_role');

    // Mediation and Compliance hearings are presided by a Lupon member.
    final hasPresider = type == 'Mediation' || type == 'Compliance Hearing';

    final timeText = parts == null
        ? (_text('scheduled_at') ?? 'Date not set')
        : '${parts.time}  •  ${parts.year}';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: upcoming ? color : Colors.grey.shade400,
              width: 5,
            ),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Header: date badge, type, number, status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dateBadge(color, upcoming),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type ?? 'Hearing',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: upcoming ? color : Colors.blueGrey,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${hearing['hearing_no'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              timeText,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (upcoming) _chip('Upcoming', color),
              ],
            ),

            if (rehearing) ...[
              const SizedBox(height: 10),
              _chip('Rehearing', Colors.indigo),
            ],

            const SizedBox(height: 14),
            Divider(height: 1, color: colors.outlineVariant),
            const SizedBox(height: 14),

            // ---- Details
            if (showComplaint)
              _infoRow(
                Icons.gavel,
                '${hearing['complaint_number'] ?? ''}  •  '
                '${hearing['complaint_title'] ?? ''}',
              ),
            if (venue != null) _infoRow(Icons.place_outlined, venue),
            ?(reference == null
                ? null
                : _infoRow(Icons.tag, reference)),

            if (hasPresider) ...[
              _personRow('Presider', presider),
              _personRow('Recording secretary', secretary),
            ] else ...[
              if (presider != null) _personRow('Presider', presider),
              if (secretary != null) _personRow('Recording secretary', secretary),
            ],

            _pangkatBlock(context, color),

            if (myRole != null) ...[
              const SizedBox(height: 4),
              _chip('You are the $myRole', colors.primary),
            ],

            // ---- Result (only once the hearing has happened)
            if (!upcoming) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(
                    'Attendance: ${_text('attendance_status') ?? '—'}',
                    _attendanceColor(_text('attendance_status')),
                  ),
                  _chip(
                    'Outcome: ${_text('outcome') ?? '—'}',
                    _outcomeColor(_text('outcome')),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
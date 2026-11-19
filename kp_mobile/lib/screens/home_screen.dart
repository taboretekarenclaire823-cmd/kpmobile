import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_ui.dart';
import 'blotter_form_screen.dart';
import 'blotter_list_screen.dart';
import 'certificate_list_screen.dart';
import 'complaint_form_screen.dart';
import 'complaint_list_screen.dart';
import 'hearing_list_screen.dart';
import 'login_screen.dart';
// Contains SummonsListScreen and SubpoenaListScreen.
// Change these two names if your files are called something else.
import 'notice_list_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic>? resident;

  const HomeScreen({
    super.key,
    required this.user,
    required this.resident,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _NavItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _NavItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class _HomeScreenState extends State<HomeScreen> {
  late Map<String, dynamic> _user = widget.user;
  late Map<String, dynamic>? _resident = widget.resident;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  // ------------------------------------------------------------- actions

  /// The profile photo is optional; any failure just keeps the initials.
  Future<void> _loadPhoto() async {
    try {
      final p = await ApiService.getProfile();
      if (!mounted) return;
      setState(() => _photoUrl = (p['photo_url'] ?? '').toString());
    } catch (_) {
      // Keep showing the initials.
    }
  }

  Future<void> _refresh() async {
    try {
      final data = await ApiService.getMe();
      if (!mounted) return;
      setState(() {
        _user = data['user'] as Map<String, dynamic>;
        _resident = _user['resident'];
      });
      _loadPhoto();
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      if (message.contains('session has expired')) _goToLogin();
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await ApiService.logout();
    if (!mounted) return;
    _goToLogin();
  }

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _openProfile() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    if (!mounted) return;
    _loadPhoto(); // the photo may have changed
  }

  // ------------------------------------------------------------- helpers

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  // ------------------------------------------------------------- widgets

  Widget _avatar(String name) {
    final colors = Theme.of(context).colorScheme;
    final hasPhoto = (_photoUrl ?? '').isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.onPrimary,
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        radius: 40,
        backgroundColor: colors.primaryContainer,
        backgroundImage: hasPhoto ? NetworkImage(_photoUrl!) : null,
        onBackgroundImageError: hasPhoto ? (_, __) {} : null,
        child: hasPhoto
            ? null
            : Text(
                _initials(name),
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  /// Small translucent label shown on the header band.
  Widget _pill(IconData icon, String text) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.onPrimary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: colors.onPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, {bool first = false}) => Padding(
        padding: EdgeInsets.only(top: first ? 0 : 24, bottom: 10, left: 4),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _quickTile({
    required String label,
    required String caption,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: colors.onPrimary, size: 22),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: TextStyle(
                  color: colors.onPrimaryContainer.withValues(alpha: 0.8),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A titled card holding a list of tappable rows.
  Widget _group(String title, List<_NavItem> items) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(title),
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                ListTile(
                  onTap: items[i].onTap,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(items[i].icon,
                        color: colors.onPrimaryContainer, size: 22),
                  ),
                  title: Text(
                    items[i].title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    items[i].subtitle,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right,
                      color: colors.onSurfaceVariant),
                ),
                if (i < items.length - 1)
                  Divider(height: 1, indent: 74, color: colors.outlineVariant),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusCard(IconData icon, Color color, String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final name = (_user['name'] ?? 'Resident').toString();
    final residentNo = (_resident?['resident_no'] ?? 'N/A').toString();
    final status = (_resident?['verification_status'] ?? 'Unknown').toString();
    final canFile = _resident?['can_file'] == true;
    final filingBlockedMessage =
        (_resident?['filing_blocked_message'] ?? '').toString().trim();

    late final IconData statusIcon;
    late final Color statusColor;
    late final String statusMessage;
    switch (status) {
      case 'Approved':
        statusIcon = canFile ? Icons.verified : Icons.info_outline;
        statusColor = canFile ? Colors.green : Colors.orange;
        statusMessage = filingBlockedMessage.isNotEmpty
            ? filingBlockedMessage
            : 'Your account is approved, but filing is currently unavailable. '
                'Please contact the barangay.';
        break;
      case 'Rejected':
        statusIcon = Icons.cancel;
        statusColor = Colors.red;
        statusMessage = 'Your registration was rejected.\n\nReason: '
            '${_resident?['rejection_reason'] ?? 'No reason given.'}';
        break;
      default:
        statusIcon = Icons.hourglass_top;
        statusColor = Colors.orange;
        statusMessage = filingBlockedMessage.isNotEmpty
            ? filingBlockedMessage
            : 'Waiting for the barangay to approve your account. '
                'You will be able to file reports and complaints once approved.';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('KP Mobile'),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: _openProfile,
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'My profile',
          ),
          IconButton(
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            HeaderBand(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _openProfile,
                    child: _avatar(name),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${_greeting()},',
                    style: TextStyle(
                      color: colors.onPrimary.withValues(alpha: 0.85),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill(Icons.badge_outlined, 'Resident No. $residentNo'),
                      _pill(statusIcon, status),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!canFile)
                    _statusCard(statusIcon, statusColor, statusMessage),
                  if (canFile) ...[
                    _sectionLabel('File something', first: true),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _quickTile(
                              label: 'Report an incident',
                              caption: 'Record what happened',
                              icon: Icons.edit_note,
                              onTap: () => _open(const BlotterFormScreen()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _quickTile(
                              label: 'File a complaint',
                              caption: 'Start a barangay case',
                              icon: Icons.gavel,
                              onTap: () => _open(const ComplaintFormScreen()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  _group('My cases', [
                    _NavItem(
                      title: 'My reports',
                      subtitle: 'Incident reports you filed',
                      icon: Icons.list_alt,
                      onTap: () => _open(BlotterListScreen(canFile: canFile)),
                    ),
                    _NavItem(
                      title: 'My complaints',
                      subtitle: 'Track the status of your cases',
                      icon: Icons.description_outlined,
                      onTap: () => _open(ComplaintListScreen(canFile: canFile)),
                    ),
                    _NavItem(
                      title: 'Hearing schedule',
                      subtitle: 'Upcoming and past hearings',
                      icon: Icons.event,
                      onTap: () => _open(const HearingListScreen()),
                    ),
                  ]),
                  _group('Notices & documents', [
                    _NavItem(
                      title: 'My summons',
                      subtitle: 'Notices to appear as respondent',
                      icon: Icons.mail_outline,
                      onTap: () => _open(const SummonsListScreen()),
                    ),
                    _NavItem(
                      title: 'My subpoenas',
                      subtitle: 'Notices to appear as witness',
                      icon: Icons.assignment_outlined,
                      onTap: () => _open(const SubpoenaListScreen()),
                    ),
                    _NavItem(
                      title: 'Certificates & awards',
                      subtitle: 'Official documents for your case',
                      icon: Icons.workspace_premium_outlined,
                      onTap: () => _open(const CertificateListScreen()),
                    ),
                  ]),
                  _group('Account', [
                    _NavItem(
                      title: 'My profile',
                      subtitle: 'Contact details, photo and password',
                      icon: Icons.person_outline,
                      onTap: _openProfile,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  Text(
                    'Pull down to refresh.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
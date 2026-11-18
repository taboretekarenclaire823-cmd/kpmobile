import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The barangay seal, in a white circle so it stands out on the header.
class AuthLogo extends StatelessWidget {
  final double size;

  const AuthLogo({super.key, this.size = 110});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.cover,
          // If the file is missing, show an icon instead of crashing.
          errorBuilder: (_, __, ___) => Icon(
            Icons.account_balance,
            size: size * 0.5,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}

/// Gradient header in the theme's primary color, with the logo and title.
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? badge;
  final double logoSize;
  final double bottomPadding;
  final VoidCallback? onBack;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.badge,
    this.logoSize = 104,
    this.bottomPadding = 32,
    this.onBack,
  });

  Widget _circle(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;
    final darkHeader =
        ThemeData.estimateBrightnessForColor(colors.primary) == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkHeader ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.primary,
              Color.lerp(colors.primary, Colors.black, 0.28)!,
            ],
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(32),
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -50, right: -40, child: _circle(180, 0.07)),
            Positioned(bottom: -70, left: -50, child: _circle(210, 0.06)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                topPadding + (onBack != null ? 4 : 32),
                24,
                bottomPadding,
              ),
              child: Column(
                children: [
                  if (onBack != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back),
                        color: colors.onPrimary,
                        tooltip: 'Back',
                      ),
                    ),
                  AuthLogo(size: logoSize),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onPrimary.withValues(alpha: 0.82),
                      fontSize: 13.5,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: colors.onPrimary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_outlined,
                              size: 15, color: colors.onPrimary),
                          const SizedBox(width: 6),
                          Text(
                            badge!,
                            style: TextStyle(
                              color: colors.onPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White rounded card with a soft shadow.
class AuthCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AuthCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Small title with an icon, used at the top of each register card.
class AuthSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const AuthSectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colors.onPrimaryContainer, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One consistent look for every text field and dropdown.
InputDecoration authDecoration(
  BuildContext context, {
  required String label,
  IconData? icon,
  Widget? suffix,
}) {
  final colors = Theme.of(context).colorScheme;

  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    labelText: label,
    prefixIcon: icon == null ? null : Icon(icon),
    suffixIcon: suffix,
    filled: true,
    fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.45),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(colors.outlineVariant),
    enabledBorder: border(colors.outlineVariant),
    focusedBorder: border(colors.primary, 2),
    errorBorder: border(colors.error),
    focusedErrorBorder: border(colors.error, 2),
  );
}
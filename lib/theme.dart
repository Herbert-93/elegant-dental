import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppColors {
  static const navy = Color(0xFF0B2A3C);
  static const navy2 = Color(0xFF14455C);
  static const teal = Color(0xFF0E9F9A);
  static const tealDark = Color(0xFF0A7F7B);
  static const bg = Color(0xFFF2F6F9);
  static const ink = Color(0xFF12232E);
  static const muted = Color(0xFF6B7C88);
  static const border = Color(0xFFE1E9EE);
  static const red = Color(0xFFD62839);
  static const redDark = Color(0xFF9B111E);
  static const redBg = Color(0xFFFFECEE);
  static const green = Color(0xFF1B9E5A);
  static const greenBg = Color(0xFFE3F6EB);
  static const amber = Color(0xFFD97E00);
  static const amberBg = Color(0xFFFFF3DC);
}

ThemeData appTheme() {
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.teal)
        .copyWith(primary: AppColors.tealDark, error: AppColors.red),
    scaffoldBackgroundColor: AppColors.bg,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.tealDark,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme:
        SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: shape),
  );
}

InputDecoration deco(String label, {IconData? icon}) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    labelText: label,
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    filled: true,
    fillColor: Colors.white,
    border: b(AppColors.border),
    enabledBorder: b(AppColors.border),
    focusedBorder: b(AppColors.tealDark, 1.8),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
  );
}

String initials(String n) {
  final p = n.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  if (p.length == 1) return p[0][0].toUpperCase();
  return (p[0][0] + p[1][0]).toUpperCase();
}

String fmtTime(String hhmm) {
  final p = hhmm.split(':');
  if (p.length != 2) return hhmm;
  return DateFormat('h:mm a').format(
      DateTime(2000, 1, 1, int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 0));
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color, borderColor;
  const Panel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(18),
      this.color,
      this.borderColor});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor ?? AppColors.border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0F0B2A3C), blurRadius: 18, offset: Offset(0, 6))
          ],
        ),
        child: child,
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color fg, bg;
  final IconData? icon;
  const Pill(this.text, this.fg, this.bg, {super.key, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4)
          ],
          Text(text,
              style: TextStyle(
                  color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}

class Avatar extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  const Avatar(this.name,
      {super.key, this.size = 40, this.color = AppColors.tealDark});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: color.withOpacity(0.14), shape: BoxShape.circle),
        child: Text(initials(name),
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.36)),
      );
}

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const PageHeader(
      {super.key, required this.title, this.subtitle, this.actions = const []});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                  if (subtitle != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!,
                            style: const TextStyle(color: AppColors.muted))),
                ]),
            Wrap(spacing: 10, runSpacing: 8, children: actions),
          ],
        ),
      );
}

/// Scrolling page body with a max width, so the layout looks good on big screens.
class PageScroll extends StatelessWidget {
  final List<Widget> children;
  const PageScroll({super.key, required this.children});
  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: ListView(
            padding: EdgeInsets.all(narrow ? 14 : 26), children: children),
      ),
    );
  }
}

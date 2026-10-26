import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'config.dart';
import 'models.dart';
import 'services.dart';
import 'theme.dart';

void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
String niceDate(String ymd) =>
    DateFormat('EEEE, d MMMM y').format(DateTime.parse(ymd));
Future<void> signOut() => FirebaseAuth.instance.signOut();

Widget field(TextEditingController c, String label,
    {TextInputType? type,
    List<TextInputFormatter>? fmt,
    int maxLines = 1,
    bool required = true,
    IconData? icon}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: c,
      keyboardType: type,
      inputFormatters: fmt,
      maxLines: maxLines,
      decoration: deco(label, icon: icon),
      validator: (v) =>
          required && (v == null || v.trim().isEmpty) ? 'Required' : null,
    ),
  );
}

AlertDialog appDialog(BuildContext context,
    {required String title,
    String? subtitle,
    required Widget content,
    required List<Widget> actions,
    double width = 500}) {
  final w = math.min(width, MediaQuery.of(context).size.width - 110);
  return AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    titlePadding: const EdgeInsets.fromLTRB(26, 24, 26, 8),
    contentPadding: const EdgeInsets.fromLTRB(26, 10, 26, 6),
    actionsPadding: const EdgeInsets.fromLTRB(26, 8, 26, 22),
    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 21, color: AppColors.ink)),
      if (subtitle != null)
        Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(subtitle,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w400))),
    ]),
    content: SizedBox(width: w, child: content),
    actions: actions,
  );
}

Future<bool> confirm(BuildContext context, String title, String message,
    {String yes = 'Confirm'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => appDialog(ctx,
        title: title,
        width: 420,
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(yes)),
        ]),
  );
  return r == true;
}

// ---------------------------------------------------------------- Register patient
Future<void> showRegisterDialog(
        BuildContext context, AppUser user, int suggested,
        {Appointment? appt}) =>
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _RegisterDialog(user: user, suggested: suggested, appt: appt));

class _RegisterDialog extends StatefulWidget {
  final AppUser user;
  final int suggested;
  final Appointment? appt;
  const _RegisterDialog(
      {required this.user, required this.suggested, this.appt});
  @override
  State<_RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<_RegisterDialog> {
  final form = GlobalKey<FormState>();
  late final numC = TextEditingController(text: '${widget.suggested}');
  late final name = TextEditingController(text: widget.appt?.name ?? '');
  late final phone = TextEditingController(text: widget.appt?.phone ?? '');
  late final treatment = TextEditingController(text: widget.appt?.reason ?? '');
  final age = TextEditingController(),
      address = TextEditingController(),
      email = TextEditingController();
  bool busy = false;

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await Svc.addVisit(
        number: int.parse(numC.text.trim()),
        name: name.text.trim(),
        age: int.parse(age.text.trim()),
        address: address.text.trim(),
        phone: phone.text.trim(),
        email: email.text.trim(),
        treatment: treatment.text.trim(),
        by: widget.user,
      );
      if (widget.appt != null)
        await Svc.setAppointmentStatus(widget.appt!.id, 'completed');
      nav.pop();
      messenger.showSnackBar(SnackBar(
          content: Text(
              '${name.text.trim()} registered as patient ${numC.text.trim()}.')));
    } catch (e) {
      if (mounted) setState(() => busy = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return appDialog(
      context,
      title: widget.appt == null ? 'Register Patient' : 'Check in appointment',
      subtitle: 'Enter the patient details for today',
      content: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: field(numC, 'Patient No. (today)',
                      type: TextInputType.number,
                      fmt: digits,
                      icon: Icons.tag)),
              const SizedBox(width: 12),
              Expanded(
                  child: field(age, 'Age',
                      type: TextInputType.number,
                      fmt: digits,
                      icon: Icons.cake_outlined)),
            ]),
            field(name, 'Full name', icon: Icons.person_outline),
            field(phone, 'Phone number',
                type: TextInputType.phone, icon: Icons.phone_outlined),
            field(email, 'Email address (optional)',
                type: TextInputType.emailAddress,
                required: false,
                icon: Icons.email_outlined),
            field(address, 'Address', icon: Icons.location_on_outlined),
            field(treatment, 'Treatment the patient came for',
                maxLines: 2, icon: Icons.medical_services_outlined),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton.icon(
            onPressed: busy ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(busy ? 'Saving...' : 'Save Patient')),
      ],
    );
  }
}

// ---------------------------------------------------------------- Record treatment cost
Future<void> showTreatmentDialog(BuildContext context, Visit v, AppUser user) =>
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _TreatmentDialog(v: v, user: user));

class _TreatmentDialog extends StatefulWidget {
  final Visit v;
  final AppUser user;
  const _TreatmentDialog({required this.v, required this.user});
  @override
  State<_TreatmentDialog> createState() => _TreatmentDialogState();
}

class _TreatmentDialogState extends State<_TreatmentDialog> {
  final form = GlobalKey<FormState>();
  late final cost = TextEditingController(
      text: widget.v.cost == null
          ? ''
          : widget.v.cost!.toStringAsFixed(widget.v.cost! % 1 == 0 ? 0 : 2));
  late final notes = TextEditingController(text: widget.v.notes);
  late String method = widget.v.paymentMethod.isEmpty
      ? Cfg.paymentMethods.first
      : widget.v.paymentMethod;
  bool busy = false;

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await Svc.recordTreatment(widget.v.id, double.parse(cost.text.trim()),
          method, notes.text.trim(), widget.user);
      nav.pop();
      messenger
          .showSnackBar(const SnackBar(content: Text('Treatment cost saved.')));
    } catch (e) {
      if (mounted) setState(() => busy = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.v;
    return appDialog(
      context,
      title: 'Record treatment',
      subtitle: 'Patient #${v.number} - ${v.name}',
      content: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('Came for: ${v.treatment}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextFormField(
                    controller: cost,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'))
                    ],
                    decoration: deco('Cost of treatment (${Cfg.currency})',
                        icon: Icons.payments_outlined),
                    validator: (t) =>
                        (t == null || double.tryParse(t.trim()) == null)
                            ? 'Enter a valid amount'
                            : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<String>(
                    value: method,
                    decoration: deco('Payment method',
                        icon: Icons.account_balance_wallet_outlined),
                    items: Cfg.paymentMethods
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (x) => setState(() => method = x ?? method),
                  ),
                ),
                field(notes, 'Treatment notes (optional)',
                    maxLines: 2, required: false, icon: Icons.notes),
              ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton.icon(
            onPressed: busy ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(busy ? 'Saving...' : 'Save')),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const StatCard(this.label, this.value, this.icon,
      {super.key, this.color = AppColors.tealDark});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 250,
        child: Panel(
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 13)),
                  const SizedBox(height: 2),
                  FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink))),
                ])),
          ]),
        ),
      );
}

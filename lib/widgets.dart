import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'config.dart';
import 'models.dart';
import 'receipt.dart';
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
  final age = TextEditingController(), address = TextEditingController();
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

// ---------------------------------------------------------------- Receipt
Future<void> showReceiptDialog(BuildContext context, Visit v) => showDialog(
      context: context,
      builder: (ctx) {
        Widget row(String a, String b) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                    width: 110,
                    child: Text(a,
                        style: const TextStyle(color: AppColors.muted))),
                Expanded(
                    child: Text(b,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
              ]),
            );
        return appDialog(
          ctx,
          title: 'Receipt',
          subtitle: v.receiptNo,
          width: 440,
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              row('Patient', v.name),
              row('Treatment', v.treatment),
              row('Payment', v.paymentMethod),
              const Divider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('TOTAL PAID',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                Text(money(v.cost ?? 0),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: AppColors.tealDark)),
              ]),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close')),
            OutlinedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Download PDF'),
              onPressed: () async => Printing.sharePdf(
                  bytes: await buildReceipt(v),
                  filename: 'Receipt-${v.receiptNo}.pdf'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.print),
              label: const Text('Print'),
              onPressed: () async => Printing.layoutPdf(
                  name: 'Receipt-${v.receiptNo}',
                  onLayout: (_) => buildReceipt(v)),
            ),
          ],
        );
      },
    );

// ---------------------------------------------------------------- Visit list / table
class VisitTable extends StatelessWidget {
  final List<Visit> visits;
  final AppUser user;
  final bool showDate;
  const VisitTable(
      {super.key,
      required this.visits,
      required this.user,
      this.showDate = false});

  Widget _status(Visit v) => v.treated
      ? const Pill('Treated', AppColors.green, AppColors.greenBg,
          icon: Icons.check_circle)
      : const Pill('Waiting', AppColors.amber, AppColors.amberBg,
          icon: Icons.schedule);

  Widget _actions(BuildContext c, Visit v) {
    final small = FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12));
    return Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          v.treated
              ? OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12)),
                  onPressed: () => showTreatmentDialog(c, v, user),
                  child: const Text('Edit cost'))
              : FilledButton(
                  style: small,
                  onPressed: () => showTreatmentDialog(c, v, user),
                  child: const Text('Record treatment')),
          if (v.treated)
            IconButton.outlined(
                tooltip: 'Receipt',
                icon: const Icon(Icons.receipt_long, size: 20),
                onPressed: () => showReceiptDialog(c, v)),
          if (user.isAdmin)
            IconButton(
              tooltip: 'Delete',
              color: AppColors.red,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(c, 'Delete record?',
                    'Permanently delete ${v.name} (#${v.number}, ${v.date})?',
                    yes: 'Delete')) {
                  await Svc.deleteVisit(v.id);
                }
              },
            ),
        ]);
  }

  String _time(Visit v) =>
      v.createdAt == null ? '-' : DateFormat('h:mm a').format(v.createdAt!);

  @override
  Widget build(BuildContext context) {
    if (visits.isEmpty) {
      return const Panel(
        padding: EdgeInsets.all(40),
        child: Center(
            child: Column(children: [
          Icon(Icons.people_outline, size: 46, color: AppColors.muted),
          SizedBox(height: 8),
          Text('No patients found',
              style: TextStyle(
                  color: AppColors.muted, fontWeight: FontWeight.w600)),
        ])),
      );
    }
    return LayoutBuilder(builder: (context, bc) {
      if (bc.maxWidth < 980) {
        return Column(
            children: visits
                .map((v) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Panel(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Avatar(v.name),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(v.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15)),
                                      Text(
                                          '#${v.number} - ${v.age} yrs - ${v.phone}',
                                          style: const TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 12.5)),
                                    ])),
                                _status(v),
                              ]),
                              const SizedBox(height: 10),
                              Text(v.treatment),
                              const SizedBox(height: 2),
                              Text(
                                  '${showDate ? '${v.date}  ' : ''}${_time(v)} - ${v.address}',
                                  style: const TextStyle(
                                      color: AppColors.muted, fontSize: 12.5)),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                    child: Text(
                                        v.cost == null
                                            ? 'No cost yet'
                                            : money(v.cost!),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800))),
                                Flexible(child: _actions(context, v)),
                              ]),
                            ]),
                      ),
                    ))
                .toList());
      }
      const hs = TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
          fontSize: 12.5,
          letterSpacing: .4);
      return Panel(
        padding: EdgeInsets.zero,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
                color: Color(0xFFF6F9FB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(children: [
              const SizedBox(width: 48, child: Text('NO.', style: hs)),
              const Expanded(flex: 4, child: Text('PATIENT', style: hs)),
              const Expanded(flex: 3, child: Text('TREATMENT', style: hs)),
              Expanded(
                  flex: 2,
                  child: Text(showDate ? 'DATE / TIME' : 'ARRIVED', style: hs)),
              const Expanded(flex: 2, child: Text('STATUS', style: hs)),
              const Expanded(flex: 2, child: Text('COST', style: hs)),
              const SizedBox(
                  width: 250,
                  child: Align(
                      alignment: Alignment.centerRight,
                      child: Text('ACTIONS', style: hs))),
            ]),
          ),
          ...visits.map((v) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border))),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 48,
                          child: Text('#${v.number}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.tealDark))),
                      Expanded(
                          flex: 4,
                          child: Row(children: [
                            Avatar(v.name),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(v.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  Text(
                                      '${v.age} yrs - ${v.phone} - ${v.address}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 12.5)),
                                ])),
                          ])),
                      Expanded(
                          flex: 3,
                          child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Text(v.treatment,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis))),
                      Expanded(
                          flex: 2,
                          child: Text(
                              showDate ? '${v.date}\n${_time(v)}' : _time(v),
                              style: const TextStyle(color: AppColors.muted))),
                      Expanded(
                          flex: 2,
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: _status(v))),
                      Expanded(
                          flex: 2,
                          child: Text(v.cost == null ? '-' : money(v.cost!),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700))),
                      SizedBox(width: 250, child: _actions(context, v)),
                    ]),
              )),
        ]),
      );
    });
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

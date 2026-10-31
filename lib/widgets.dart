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
      email = TextEditingController(),
      nextOfKin = TextEditingController();
  bool busy = false;
  bool _minor = false;

  @override
  void initState() {
    super.initState();
    age.addListener(() {
      final a = int.tryParse(age.text.trim());
      final m = a != null && a < 18;
      if (m != _minor && mounted) setState(() => _minor = m);
    });
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await Svc.addVisit(
        nextOfKin: _minor ? nextOfKin.text.trim() : '',
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
            if (_minor)
              field(nextOfKin, 'Next of kin (patient is under 18)',
                  required: false, icon: Icons.family_restroom_outlined),
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
  // [cost] holds the TREATMENT cost only; medicines are added on top of it.
  late final cost = TextEditingController(
      text: widget.v.cost == null
          ? ''
          : widget.v.treatmentCost
              .toStringAsFixed(widget.v.treatmentCost % 1 == 0 ? 0 : 2));
  late List<_MedRow> meds = widget.v.medicines
      .map((m) => _MedRow(text: m.name, cost: _num(m.cost)))
      .toList();
  late final notes = TextEditingController(text: widget.v.notes);
  late final doctor = TextEditingController(text: widget.v.doctor);
  late final balance = TextEditingController(
      text: widget.v.balance > 0
          ? widget.v.balance.toStringAsFixed(widget.v.balance % 1 == 0 ? 0 : 2)
          : '');
  late final nextAppt = TextEditingController(text: widget.v.nextAppointment);
  late String method = widget.v.payments.length > 1
      ? widget.v.payments.keys.first
      : (widget.v.paymentMethod.isEmpty
          ? Cfg.paymentMethods.first
          : widget.v.paymentMethod);
  bool busy = false;

  // ---- split payment (e.g. part Cash, part MTN Mobile Money)
  late bool split = widget.v.payments.length > 1;
  late List<_PayRow> rows = widget.v.payments.length > 1
      ? widget.v.payments.entries
          .map((e) => _PayRow(e.key, text: _num(e.value)))
          .toList()
      : <_PayRow>[];
  String? splitError;

  static String _num(double n) => n.toStringAsFixed(n % 1 == 0 ? 0 : 2);

  @override
  void dispose() {
    for (final r in rows) {
      r.amount.dispose();
    }
    for (final m in meds) {
      m.name.dispose();
      m.cost.dispose();
    }
    super.dispose();
  }

  // ---- medicines + grand total
  double get _medSum => meds.fold<double>(
      0, (a, m) => a + (double.tryParse(m.cost.text.trim()) ?? 0));

  /// Treatment + medicines (null until a valid treatment cost is typed).
  double? get _total {
    final t = double.tryParse(cost.text.trim());
    return t == null ? null : t + _medSum;
  }

  /// Called whenever treatment cost or a medicine price changes: keeps a 2-way split in step.
  void _changed() => setState(() {
        if (!split) return;
        splitError = null;
        final t = _total;
        if (rows.length == 2 && t != null) {
          final a = double.tryParse(rows[0].amount.text.trim()) ?? 0;
          final rest = t - a;
          rows[1].amount.text = rest > 0 ? _num(rest) : '';
        }
      });

  void _addMed() => setState(() => meds.add(_MedRow()));

  void _removeMed(int i) {
    setState(() {
      meds[i].name.dispose();
      meds[i].cost.dispose();
      meds.removeAt(i);
    });
    _changed();
  }

  Widget _medRow(int i) {
    final m = meds[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 5,
          child: TextFormField(
            controller: m.name,
            textCapitalization: TextCapitalization.sentences,
            decoration: deco('Medicine name'),
            validator: (t) =>
                ((t ?? '').trim().isEmpty && m.cost.text.trim().isNotEmpty)
                    ? 'Enter the medicine name'
                    : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: TextFormField(
            controller: m.cost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
            ],
            decoration: deco('Cost (${Cfg.currency})'),
            validator: (t) => (m.name.text.trim().isNotEmpty &&
                    double.tryParse((t ?? '').trim()) == null)
                ? 'Enter the cost'
                : null,
            onChanged: (_) => _changed(),
          ),
        ),
        IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => _removeMed(i)),
      ]),
    );
  }

  Widget _medicineSection() {
    final t = double.tryParse(cost.text.trim());
    final total = _total;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Medicine given (optional)',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (var i = 0; i < meds.length; i++) _medRow(i),
        TextButton.icon(
            onPressed: _addMed,
            icon: const Icon(Icons.add, size: 18),
            label:
                Text(meds.isEmpty ? 'Add medicine' : 'Add another medicine')),
        const Divider(height: 20),
        _sumLine('Treatment', t == null ? '-' : money(t)),
        _sumLine('Medicine', money(_medSum)),
        const SizedBox(height: 4),
        _sumLine('Total to pay', total == null ? '-' : money(total),
            bold: true),
      ]),
    );
  }

  Widget _sumLine(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                  color: bold ? AppColors.ink : AppColors.muted)),
          Text(v,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  fontSize: bold ? 16 : 14,
                  color: bold ? AppColors.tealDark : AppColors.ink)),
        ]),
      );

  void _toggleSplit(bool on) => setState(() {
        split = on;
        splitError = null;
        if (on) {
          final second = Cfg.paymentMethods
              .firstWhere((m) => m != method, orElse: () => method);
          rows = [_PayRow(method), _PayRow(second)];
          // Start with the whole total on the first method; the cashier adjusts it.
          final c = _total;
          if (c != null) rows[0].amount.text = _num(c);
        } else {
          if (rows.isNotEmpty) method = rows.first.method;
          for (final r in rows) {
            r.amount.dispose();
          }
          rows = [];
        }
      });

  /// With two methods, typing one amount fills the other with what is left of the cost.
  void _onAmount(int i) => setState(() {
        splitError = null;
        if (rows.length == 2) {
          final c = _total;
          final a = double.tryParse(rows[i].amount.text.trim()) ?? 0;
          if (c != null) {
            final rest = c - a;
            rows[1 - i].amount.text = rest > 0 ? _num(rest) : '';
          }
        }
      });

  void _addRow() => setState(() {
        final used = rows.map((r) => r.method).toSet();
        final next = Cfg.paymentMethods
            .firstWhere((m) => !used.contains(m), orElse: () => method);
        rows.add(_PayRow(next));
      });

  void _removeRow(int i) => setState(() {
        rows[i].amount.dispose();
        rows.removeAt(i);
        splitError = null;
      });

  double get _entered => rows.fold<double>(
      0, (a, r) => a + (double.tryParse(r.amount.text.trim()) ?? 0));

  Widget _payRow(int i) {
    final r = rows[i];
    final used = rows.where((x) => x != r).map((x) => x.method).toSet();
    final options = <String>[
      ...Cfg.paymentMethods.where((m) => m == r.method || !used.contains(m)),
      if (!Cfg.paymentMethods.contains(r.method)) r.method,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(
          flex: 5,
          child: DropdownButtonFormField<String>(
            value: r.method,
            isExpanded: true,
            decoration: deco('Method'),
            items: options
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (x) => setState(() {
              r.method = x ?? r.method;
              splitError = null;
            }),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: TextFormField(
            controller: r.amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
            ],
            decoration: deco('Amount (${Cfg.currency})'),
            onChanged: (_) => _onAmount(i),
          ),
        ),
        if (rows.length > 2)
          IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => _removeRow(i)),
      ]),
    );
  }

  Widget _splitSection() {
    final c = _total;
    final entered = _entered;
    final left = (c ?? 0) - entered;
    final ok = c != null && left.abs() < 0.01;
    final String msg;
    if (c == null) {
      msg = 'Enter the cost of treatment first.';
    } else if (ok) {
      msg = 'Fully allocated: ${money(entered)} of ${money(c)}';
    } else if (left > 0) {
      msg = 'Still to allocate: ${money(left)}';
    } else {
      msg = 'Over by ${money(-left)}';
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < rows.length; i++) _payRow(i),
        Row(children: [
          if (rows.length < Cfg.paymentMethods.length)
            TextButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add another method')),
          const Spacer(),
        ]),
        Text(msg,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: ok ? AppColors.green : AppColors.red)),
        if (splitError != null)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(splitError!,
                  style: const TextStyle(color: AppColors.red))),
      ]),
    );
  }

  Future<void> _pickNextAppt() async {
    final existing = DateTime.tryParse(nextAppt.text.trim());
    final picked = await showDatePicker(
      context: context,
      initialDate: existing ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => nextAppt.text = Svc.fmtDate(picked));
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    final total = _total!; // treatment + medicines
    final medicines = [
      for (final m in meds)
        if (m.name.text.trim().isNotEmpty)
          Medicine(m.name.text.trim(), double.parse(m.cost.text.trim()))
    ];
    Map<String, double> payments = {method: total};
    String payMethod = method;
    if (split) {
      final m = <String, double>{};
      for (final r in rows) {
        final a = double.tryParse(r.amount.text.trim()) ?? 0;
        if (a <= 0) continue;
        if (m.containsKey(r.method)) {
          setState(() => splitError =
              'Each payment method can only be used once - combine the amounts.');
          return;
        }
        m[r.method] = a;
      }
      final sum = m.values.fold<double>(0, (a, b) => a + b);
      if (m.isEmpty || (sum - total).abs() >= 0.01) {
        setState(() => splitError =
            'The amounts must add up to ${money(total)} (now ${money(sum)}).');
        return;
      }
      payments = m;
      payMethod = m.keys.join(' + ');
    }
    setState(() => busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await Svc.recordTreatment(
          widget.v.id, total, payMethod, notes.text.trim(), widget.user,
          payments: payments,
          medicines: medicines,
          doctor: doctor.text.trim(),
          balance: double.tryParse(balance.text.trim()) ?? 0,
          nextAppointment: nextAppt.text.trim());
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
                field(doctor, 'Doctor who treated the patient',
                    icon: Icons.medical_information_outlined),
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
                    onChanged: (_) => _changed(),
                    decoration: deco('Cost of treatment (${Cfg.currency})',
                        icon: Icons.payments_outlined),
                    validator: (t) =>
                        (t == null || double.tryParse(t.trim()) == null)
                            ? 'Enter a valid amount'
                            : null,
                  ),
                ),
                _medicineSection(),
                if (!split)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: DropdownButtonFormField<String>(
                      value: method,
                      decoration: deco('Payment method',
                          icon: Icons.account_balance_wallet_outlined),
                      items: [
                        ...Cfg.paymentMethods,
                        if (!Cfg.paymentMethods.contains(method)) method,
                      ]
                          .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (x) => setState(() => method = x ?? method),
                    ),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Customer paid with more than one method',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('e.g. part Cash, part Mobile Money'),
                  value: split,
                  onChanged: _toggleSplit,
                ),
                if (split) _splitSection() else const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextFormField(
                    controller: balance,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'))
                    ],
                    decoration: deco(
                            'Balance (${Cfg.currency}) - leave empty if none',
                            icon: Icons.account_balance_outlined)
                        .copyWith(hintText: 'Nil'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextFormField(
                    controller: nextAppt,
                    readOnly: true,
                    onTap: _pickNextAppt,
                    decoration: deco('Next appointment - leave empty if none',
                            icon: Icons.event_outlined)
                        .copyWith(
                      hintText: 'Null',
                      suffixIcon: nextAppt.text.isEmpty
                          ? const Icon(Icons.arrow_drop_down)
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () =>
                                  setState(() => nextAppt.clear())),
                    ),
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

class _MedRow {
  final TextEditingController name, cost;
  _MedRow({String text = '', String cost = ''})
      : name = TextEditingController(text: text),
        cost = TextEditingController(text: cost);
}

class _PayRow {
  String method;
  final TextEditingController amount;
  _PayRow(this.method, {String text = ''})
      : amount = TextEditingController(text: text);
}

class StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap; // when set, the card is clickable
  const StatCard(this.label, this.value, this.icon,
      {super.key, this.color = AppColors.tealDark, this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 250,
        child: onTap == null
            ? _card()
            : MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(onTap: onTap, child: _card())),
      );

  Widget _card() => Panel(
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
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 13)),
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
          if (onTap != null)
            const Icon(Icons.chevron_right, color: AppColors.muted),
        ]),
      );
}

/// Opens the list of medicines sold (name + cost of each one), for today or the last 7 days.
void showMedicineDialog(BuildContext context, List<Visit> today,
    {List<Visit>? week}) {
  showDialog(
    context: context,
    builder: (ctx) {
      var showWeek = false;
      return StatefulBuilder(builder: (ctx, setS) {
        final src = (showWeek && week != null ? week : today)
            .where((v) => v.treated && v.medicines.isNotEmpty)
            .toList()
          ..sort((a, b) => (b.treatedAt ?? DateTime(2000))
              .compareTo(a.treatedAt ?? DateTime(2000)));
        final items = <({Visit v, Medicine m})>[
          for (final v in src)
            for (final m in v.medicines) (v: v, m: m)
        ];
        final total = items.fold<double>(0, (a, e) => a + e.m.cost);
        return appDialog(
          ctx,
          title: 'Medicine sold',
          subtitle: showWeek && week != null ? 'Last 7 days' : 'Today',
          width: 560,
          content: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (week != null) ...[
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Today')),
                        ButtonSegment(value: true, label: Text('Last 7 days')),
                      ],
                      selected: {showWeek},
                      onSelectionChanged: (s) => setS(() => showWeek = s.first),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (items.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('No medicine recorded in this period.',
                            style: TextStyle(color: AppColors.muted))),
                  for (final e in items)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: AppColors.border))),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(e.m.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text(
                                  '${e.v.name} (#${e.v.number}) - ${niceDate(e.v.date)}',
                                  style: const TextStyle(
                                      color: AppColors.muted, fontSize: 12)),
                            ])),
                        Text(money(e.m.cost),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  const SizedBox(height: 12),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total medicine',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        Text(money(total),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: AppColors.tealDark)),
                      ]),
                ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close')),
          ],
        );
      });
    },
  );
}

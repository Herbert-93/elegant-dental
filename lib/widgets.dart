import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'config.dart';
import 'models.dart';
import 'receipt.dart';
import 'services.dart';

void snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Widget field(TextEditingController c, String label,
    {TextInputType? type, List<TextInputFormatter>? fmt, int maxLines = 1, bool required = true}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c, keyboardType: type, inputFormatters: fmt, maxLines: maxLines,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: (v) => required && (v == null || v.trim().isEmpty) ? 'Required' : null,
    ),
  );
}

// ---------------------------------------------------------------- Register patient
Future<void> showRegisterDialog(BuildContext context, AppUser user, int suggested) =>
    showDialog(context: context, barrierDismissible: false, builder: (_) => _RegisterDialog(user: user, suggested: suggested));

class _RegisterDialog extends StatefulWidget {
  final AppUser user;
  final int suggested;
  const _RegisterDialog({required this.user, required this.suggested});
  @override
  State<_RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<_RegisterDialog> {
  final form = GlobalKey<FormState>();
  late final numC = TextEditingController(text: '${widget.suggested}');
  final name = TextEditingController(), age = TextEditingController(), address = TextEditingController(),
      phone = TextEditingController(), treatment = TextEditingController();
  bool busy = false;

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await Svc.addVisit(
        number: int.parse(numC.text.trim()), name: name.text.trim(), age: int.parse(age.text.trim()),
        address: address.text.trim(), phone: phone.text.trim(), treatment: treatment.text.trim(), by: widget.user,
      );
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text('${name.text.trim()} registered as patient ${numC.text.trim()}.')));
    } catch (e) {
      if (mounted) setState(() => busy = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return AlertDialog(
      title: const Text('Register Patient'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              field(numC, 'Patient number for today (1, 2, 3...)', type: TextInputType.number, fmt: digits),
              field(name, 'Full name'),
              field(age, 'Age', type: TextInputType.number, fmt: digits),
              field(address, 'Address'),
              field(phone, 'Phone number', type: TextInputType.phone),
              field(treatment, 'Treatment the patient came for', maxLines: 2),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: busy ? null : _save, child: Text(busy ? 'Saving...' : 'Save Patient')),
      ],
    );
  }
}

// ---------------------------------------------------------------- Record treatment cost
Future<void> showTreatmentDialog(BuildContext context, Visit v, AppUser user) =>
    showDialog(context: context, barrierDismissible: false, builder: (_) => _TreatmentDialog(v: v, user: user));

class _TreatmentDialog extends StatefulWidget {
  final Visit v;
  final AppUser user;
  const _TreatmentDialog({required this.v, required this.user});
  @override
  State<_TreatmentDialog> createState() => _TreatmentDialogState();
}

class _TreatmentDialogState extends State<_TreatmentDialog> {
  final form = GlobalKey<FormState>();
  late final cost = TextEditingController(text: widget.v.cost == null ? '' : widget.v.cost!.toStringAsFixed(widget.v.cost! % 1 == 0 ? 0 : 2));
  late final notes = TextEditingController(text: widget.v.notes);
  late String method = widget.v.paymentMethod.isEmpty ? Cfg.paymentMethods.first : widget.v.paymentMethod;
  bool busy = false;

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await Svc.recordTreatment(widget.v.id, double.parse(cost.text.trim()), method, notes.text.trim(), widget.user);
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Treatment cost saved.')));
    } catch (e) {
      if (mounted) setState(() => busy = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.v;
    return AlertDialog(
      title: Text('Record Treatment - #${v.number} ${v.name}'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Came for: ${v.treatment}'),
              const SizedBox(height: 14),
              TextFormField(
                controller: cost, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                decoration: InputDecoration(labelText: 'Cost of treatment (${Cfg.currency})', border: const OutlineInputBorder()),
                validator: (t) => (t == null || double.tryParse(t.trim()) == null) ? 'Enter a valid amount' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: method,
                decoration: const InputDecoration(labelText: 'Payment method', border: OutlineInputBorder()),
                items: Cfg.paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (x) => setState(() => method = x ?? method),
              ),
              const SizedBox(height: 12),
              field(notes, 'Treatment notes (optional)', maxLines: 2, required: false),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: busy ? null : _save, child: Text(busy ? 'Saving...' : 'Save')),
      ],
    );
  }
}

// ---------------------------------------------------------------- Receipt
Future<void> showReceiptDialog(BuildContext context, Visit v) => showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Receipt ${v.receiptNo}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Patient: ${v.name}'),
          Text('Treatment: ${v.treatment}'),
          Text('Paid: ${money(v.cost ?? 0)} (${v.paymentMethod})'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          OutlinedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Download PDF'),
            onPressed: () async => Printing.sharePdf(bytes: await buildReceipt(v), filename: 'Receipt-${v.receiptNo}.pdf'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Print'),
            onPressed: () async => Printing.layoutPdf(name: 'Receipt-${v.receiptNo}', onLayout: (_) => buildReceipt(v)),
          ),
        ],
      ),
    );

// ---------------------------------------------------------------- Visit table
class VisitTable extends StatelessWidget {
  final List<Visit> visits;
  final AppUser user;
  final bool showDate;
  const VisitTable({super.key, required this.visits, required this.user, this.showDate = false});

  Future<void> _delete(BuildContext context, Visit v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text('Permanently delete ${v.name} (#${v.number}, ${v.date})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await Svc.deleteVisit(v.id);
  }

  @override
  Widget build(BuildContext context) {
    if (visits.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No patients found.'))));
    }
    final tf = DateFormat('HH:mm');
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            if (showDate) const DataColumn(label: Text('Date')),
            const DataColumn(label: Text('No.')),
            const DataColumn(label: Text('Time')),
            const DataColumn(label: Text('Name')),
            const DataColumn(label: Text('Age')),
            const DataColumn(label: Text('Phone')),
            const DataColumn(label: Text('Address')),
            const DataColumn(label: Text('Treatment')),
            const DataColumn(label: Text('Status')),
            const DataColumn(label: Text('Cost')),
            const DataColumn(label: Text('Actions')),
          ],
          rows: visits.map((v) {
            return DataRow(cells: [
              if (showDate) DataCell(Text(v.date)),
              DataCell(Text('${v.number}')),
              DataCell(Text(v.createdAt == null ? '-' : tf.format(v.createdAt!))),
              DataCell(Text(v.name)),
              DataCell(Text('${v.age}')),
              DataCell(Text(v.phone)),
              DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: Text(v.address, overflow: TextOverflow.ellipsis))),
              DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: Text(v.treatment, overflow: TextOverflow.ellipsis))),
              DataCell(Chip(
                label: Text(v.treated ? 'Treated' : 'Waiting'),
                backgroundColor: v.treated ? Colors.green.shade100 : Colors.orange.shade100,
                visualDensity: VisualDensity.compact,
              )),
              DataCell(Text(v.cost == null ? '-' : money(v.cost!))),
              DataCell(Row(children: [
                v.treated
                    ? TextButton(onPressed: () => showTreatmentDialog(context, v, user), child: const Text('Edit cost'))
                    : FilledButton.tonal(onPressed: () => showTreatmentDialog(context, v, user), child: const Text('Record treatment')),
                if (v.treated)
                  IconButton(tooltip: 'Receipt', icon: const Icon(Icons.receipt_long), onPressed: () => showReceiptDialog(context, v)),
                if (user.isAdmin)
                  IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context, v)),
              ])),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const StatCard(this.label, this.value, this.icon, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label), Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ])),
            ]),
          ),
        ),
      );
}

String niceDate(String ymd) => DateFormat('EEEE, d MMMM y').format(DateTime.parse(ymd));
Future<void> signOut() => FirebaseAuth.instance.signOut();

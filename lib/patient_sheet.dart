import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'config.dart';
import 'medical_form.dart';
import 'models.dart';
import 'receipt_ui.dart';
import 'services.dart';
import 'theme.dart';
import 'widgets.dart';

/// Opens the full history sheet for one patient (only that patient's visits and medical forms).
Future<void> showPatientSheet(BuildContext context, Visit v, AppUser user) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 980),
      builder: (_) => PatientSheet(visit: v, user: user),
    );

class PatientSheet extends StatefulWidget {
  final Visit visit;
  final AppUser user;
  const PatientSheet({super.key, required this.visit, required this.user});
  @override
  State<PatientSheet> createState() => _PatientSheetState();
}

class _PatientSheetState extends State<PatientSheet> {
  late final Stream<List<Visit>> visitStream =
      Svc.visitsForPatient(widget.visit.phone, widget.visit.name);
  late final Stream<List<MedicalForm>> formStream =
      Svc.medicalFormsForPatient(widget.visit.phone, widget.visit.name);

  String _d(String ymd) => DateFormat('d MMM y').format(DateTime.parse(ymd));

  Widget _info(IconData i, String t) => t.trim().isEmpty
      ? const SizedBox.shrink()
      : Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 15, color: AppColors.muted),
          const SizedBox(width: 5),
          Flexible(
              child: Text(t, style: const TextStyle(color: AppColors.muted))),
        ]);

  Widget _kv(String k, String v) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 2),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]);

  Widget _visitCard(Visit x) => Panel(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(DateFormat('EEE, d MMM y').format(DateTime.parse(x.date)),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                Pill('Patient #${x.number}', AppColors.navy2,
                    const Color(0xFFE3EEF4)),
                x.treated
                    ? const Pill('Treated', AppColors.green, AppColors.greenBg,
                        icon: Icons.check_circle)
                    : const Pill('Waiting', AppColors.amber, AppColors.amberBg,
                        icon: Icons.schedule),
              ]),
          const SizedBox(height: 12),
          _kv('Treatment', x.treatment),
          if (x.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            _kv('Notes', x.notes)
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 28, runSpacing: 10, children: [
            _kv('Cost', x.cost == null ? 'Not recorded' : money(x.cost!)),
            if (x.paymentMethod.isNotEmpty) _kv('Payment', x.paymentMethod),
            _kv('Registered by', x.createdBy.isEmpty ? '-' : x.createdBy),
            if (x.treatedBy.isNotEmpty) _kv('Treated by', x.treatedBy),
            if (x.age > 0) _kv('Age at visit', '${x.age}'),
          ]),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: x.treated
                ? FilledButton.icon(
                    onPressed: () => showReceiptDialog(context, x),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('Receipt'))
                : FilledButton(
                    onPressed: () =>
                        showTreatmentDialog(context, x, widget.user),
                    child: const Text('Record treatment')),
          ),
        ]),
      );

  Widget _formRow(MedicalForm f) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.description_outlined, color: AppColors.tealDark),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    DateFormat('EEE, d MMM y, h:mm a')
                        .format(f.createdAt ?? DateTime.now()),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('${f.formNo} - by ${f.formBy}',
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12.5)),
                if (f.diagnosis.trim().isNotEmpty)
                  Text('Diagnosis: ${f.diagnosis}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted)),
              ])),
          const SizedBox(width: 8),
          OutlinedButton(
              onPressed: () => showMedicalFormDialog(context, f),
              child: const Text('View / Print')),
          if (widget.user.isAdmin)
            IconButton(
              tooltip: 'Delete',
              color: AppColors.red,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(context, 'Delete medical form?',
                    'Permanently delete this medical form for ${f.patientName}?',
                    yes: 'Delete')) {
                  await Svc.deleteMedicalForm(f.id);
                }
              },
            ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (ctx, sc) => Container(
        decoration: const BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        child: StreamBuilder<List<Visit>>(
          stream: visitStream,
          builder: (c, s) {
            if (s.hasError)
              return ListView(
                  controller: sc,
                  padding: const EdgeInsets.all(24),
                  children: [Text('Error: ${s.error}')]);
            if (!s.hasData)
              return ListView(controller: sc, children: const [
                Padding(
                    padding: EdgeInsets.all(60),
                    child: Center(child: CircularProgressIndicator()))
              ]);
            final list = s.data!;
            final latest = list.isEmpty ? widget.visit : list.first;
            final treated = list.where((v) => v.treated).toList();
            final paid = treated.fold<double>(0, (a, v) => a + (v.cost ?? 0));
            final dates = list.map((v) => v.date).toList()..sort();
            return ListView(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 34),
                children: [
                  Center(
                      child: Container(
                          width: 44,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(4)))),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Avatar(latest.name, size: 64),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Wrap(
                              spacing: 14,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(latest.name,
                                    style: const TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.ink)),
                                FilledButton.icon(
                                  onPressed: () => showCreateMedicalFormDialog(
                                      context, latest, widget.user),
                                  icon: const Icon(Icons.note_add_outlined,
                                      size: 18),
                                  label: const Text('Create medical form'),
                                ),
                              ]),
                          const SizedBox(height: 6),
                          Wrap(spacing: 18, runSpacing: 6, children: [
                            _info(Icons.cake_outlined,
                                latest.age > 0 ? '${latest.age} yrs' : ''),
                            _info(Icons.phone_outlined, latest.phone),
                            _info(Icons.email_outlined, latest.email),
                            _info(Icons.location_on_outlined, latest.address),
                          ]),
                        ])),
                    IconButton.outlined(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ]),
                  const SizedBox(height: 18),
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    StatCard('Total visits', '${list.length}', Icons.history,
                        color: AppColors.navy2),
                    StatCard('Treatments done', '${treated.length}',
                        Icons.check_circle,
                        color: AppColors.green),
                    StatCard('Total paid', money(paid), Icons.payments,
                        color: AppColors.tealDark),
                    if (dates.isNotEmpty)
                      StatCard(
                          'First visit', _d(dates.first), Icons.flag_outlined,
                          color: AppColors.amber),
                    if (dates.isNotEmpty)
                      StatCard('Last visit', _d(dates.last), Icons.update,
                          color: AppColors.amber),
                  ]),
                  const SizedBox(height: 22),
                  const Text('Visit history',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text(
                      'Every time this patient has been recorded, newest first',
                      style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 12),
                  if (list.isEmpty)
                    const Panel(child: Text('No records found.')),
                  ...list.map((x) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _visitCard(x))),
                  StreamBuilder<List<MedicalForm>>(
                    stream: formStream,
                    builder: (c, m) {
                      final l = m.data ?? <MedicalForm>[];
                      if (l.isEmpty) return const SizedBox.shrink();
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 14),
                            const Text('Medical forms',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            ...l.map(_formRow),
                          ]);
                    },
                  ),
                ]);
          },
        ),
      ),
    );
  }
}

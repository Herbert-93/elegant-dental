import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'config.dart';
import 'edit_patient.dart';
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

  /// Returning patient: record a NEW visit on this same patient sheet - their details are
  /// copied from the saved record, so nothing has to be typed again.
  Future<void> _newVisit(Visit latest, List<Visit> history) async {
    final today = Svc.todayStr();
    if (history.any((v) => v.date == today && !v.treated)) {
      await showDialog(
        context: context,
        builder: (ctx) => appDialog(ctx,
            title: 'Already registered today',
            width: 420,
            content: Text(
                '${latest.name} is already registered today and is waiting for treatment. Record the treatment on that visit below.'),
            actions: [
              FilledButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
            ]),
      );
      return;
    }
    final next = await Svc.nextNumber();
    if (!mounted) return;
    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ReturningVisitDialog(
            patient: latest, suggested: next, user: widget.user));
  }

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
            if (x.medicines.isNotEmpty)
              _kv('Treatment cost', money(x.treatmentCost)),
            if (x.medicines.isNotEmpty) _kv('Medicine', x.medicineSummary),
            if (x.paymentMethod.isNotEmpty) _kv('Payment', x.paymentDetail),
            _kv('Registered by', x.createdBy.isEmpty ? '-' : x.createdBy),
            if (x.doctor.isNotEmpty || x.treatedBy.isNotEmpty)
              _kv('Treated by', x.doctor.isNotEmpty ? x.doctor : x.treatedBy),
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
                                  onPressed: () => _newVisit(latest, list),
                                  icon: const Icon(Icons.add_circle_outline,
                                      size: 18),
                                  label: const Text('New visit'),
                                ),
                                FilledButton.icon(
                                  onPressed: () => showCreateMedicalFormDialog(
                                      context, latest, widget.user),
                                  icon: const Icon(Icons.note_add_outlined,
                                      size: 18),
                                  label: const Text('Create medical form'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final nav = Navigator.of(context);
                                    final saved = await showEditPatientDialog(
                                        context, latest,
                                        withTreatment: false);
                                    // the sheet was opened for the old details, so close it; reopen to see the changes
                                    if (saved) nav.pop();
                                  },
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 18),
                                  label: const Text('Edit patient'),
                                ),
                              ]),
                          const SizedBox(height: 6),
                          Wrap(spacing: 18, runSpacing: 6, children: [
                            _info(Icons.cake_outlined,
                                latest.age > 0 ? '${latest.age} yrs' : ''),
                            _info(Icons.phone_outlined, latest.phone),
                            _info(Icons.email_outlined, latest.email),
                            _info(Icons.location_on_outlined, latest.address),
                            _info(
                                Icons.family_restroom_outlined,
                                latest.nextOfKin.isEmpty
                                    ? ''
                                    : 'Next of kin: ${latest.nextOfKin}'),
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

/// Small dialog for a returning patient: only the visit number and what they came for.
class _ReturningVisitDialog extends StatefulWidget {
  final Visit patient;
  final int suggested;
  final AppUser user;
  const _ReturningVisitDialog(
      {required this.patient, required this.suggested, required this.user});
  @override
  State<_ReturningVisitDialog> createState() => _ReturningVisitDialogState();
}

class _ReturningVisitDialogState extends State<_ReturningVisitDialog> {
  final form = GlobalKey<FormState>();
  late final numC = TextEditingController(text: '${widget.suggested}');
  final treatment = TextEditingController();
  bool busy = false;

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final p = widget.patient;
    try {
      await Svc.addVisit(
        number: int.parse(numC.text.trim()),
        name: p.name,
        age: p.age,
        address: p.address,
        phone: p.phone,
        email: p.email,
        nextOfKin: p.nextOfKin,
        treatment: treatment.text.trim(),
        by: widget.user,
      );
      nav.pop();
      messenger.showSnackBar(SnackBar(
          content: Text(
              'New visit recorded for ${p.name} as patient ${numC.text.trim()}.')));
    } catch (e) {
      if (mounted) setState(() => busy = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    final details = [
      if (p.age > 0) '${p.age} yrs',
      p.phone,
      p.address,
    ].where((t) => t.trim().isNotEmpty).join('  -  ');
    return appDialog(
      context,
      title: 'New visit',
      subtitle: 'Returning patient - details are already saved',
      width: 460,
      content: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Avatar(p.name, size: 42),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(p.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      if (details.isNotEmpty)
                        Text(details,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12.5)),
                    ])),
              ]),
            ),
            field(numC, 'Patient No. (today)',
                type: TextInputType.number,
                fmt: [FilteringTextInputFormatter.digitsOnly],
                icon: Icons.tag),
            field(treatment, 'What has the patient come for?',
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
            label: Text(busy ? 'Saving...' : 'Save Visit')),
      ],
    );
  }
}

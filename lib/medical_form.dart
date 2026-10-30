import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'config.dart';
import 'logo.dart';
import 'models.dart';
import 'services.dart';
import 'theme.dart';
import 'widgets.dart';

/// The five table fields of a medical form, in order, plus the "Medical form by" row at the end.
List<MapEntry<String, String>> _formRows(MedicalForm f) => [
      MapEntry('Complaints', f.complaints),
      MapEntry('Notes', f.notes),
      MapEntry('Diagnosis', f.diagnosis),
      MapEntry('Management', f.management),
      MapEntry('Treatment', f.treatment),
      MapEntry('Medical form by', f.formBy),
    ];

String _orDash(String s) => s.trim().isEmpty ? '-' : s.trim();

// ====================================================================== PDF
Future<Uint8List> buildMedicalForm(MedicalForm f) async {
  final navy = PdfColor.fromHex('#0B2A3C');
  final teal = PdfColor.fromHex('#0A7F7B');
  final mint = PdfColor.fromHex('#7FD6D1');
  final soft = PdfColor.fromHex('#F2F6F9');
  final grey = PdfColor.fromHex('#6B7C88');
  final line = PdfColor.fromHex('#C9D5DC');
  final when = f.createdAt ?? DateTime.now();
  final df = DateFormat('d MMM yyyy');
  final tf = DateFormat('h:mm a');

  pw.Widget pad(pw.Widget w) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 26), child: w);

  pw.Widget label(String t) => pw.Text(t,
      style: pw.TextStyle(
          fontSize: 7.5,
          color: grey,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1));

  pw.Widget kv(String k, String val) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child:
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(
              width: 58,
              child:
                  pw.Text(k, style: pw.TextStyle(fontSize: 8.5, color: grey))),
          pw.Expanded(
              child: pw.Text(val,
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold))),
        ]),
      );

  pw.Widget contact(String k, String val, int flex) => pw.Expanded(
        flex: flex,
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(k,
                  style: pw.TextStyle(
                      fontSize: 6.5,
                      color: grey,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.8)),
              pw.SizedBox(height: 1.5),
              pw.Text(val, style: const pw.TextStyle(fontSize: 8)),
            ]),
      );

  final widths = {
    0: const pw.FixedColumnWidth(120),
    1: const pw.FlexColumnWidth(),
  };

  pw.Widget headerRow() => pw.Table(
        border: pw.TableBorder.all(color: navy, width: 0.5),
        columnWidths: widths,
        children: [
          pw.TableRow(decoration: pw.BoxDecoration(color: navy), children: [
            pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: pw.Text('FIELD',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1))),
            pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: pw.Text('DETAILS',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1))),
          ]),
        ],
      );

  // One table per row so a long form can flow onto a second page between rows.
  pw.Widget dataRow(String k, String v) => pw.Table(
        border: pw.TableBorder.all(color: line, width: 0.5),
        columnWidths: widths,
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
        children: [
          pw.TableRow(children: [
            pw.Container(
                color: soft,
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: pw.Text(k,
                    style: pw.TextStyle(
                        fontSize: 9.5, fontWeight: pw.FontWeight.bold))),
            pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: pw.Text(_orDash(v),
                    style: const pw.TextStyle(fontSize: 10, lineSpacing: 2))),
          ]),
        ],
      );

  pw.Widget band() =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Container(
          color: navy,
          padding: const pw.EdgeInsets.fromLTRB(26, 24, 26, 20),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(Cfg.clinicName,
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 21,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text(Cfg.tagline,
                          style: pw.TextStyle(color: mint, fontSize: 9)),
                    ]),
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('MEDICAL FORM',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 2)),
                      pw.SizedBox(height: 3),
                      pw.Text(f.formNo,
                          style: pw.TextStyle(
                              color: PdfColor.fromHex('#CFE6EA'), fontSize: 9)),
                    ]),
              ]),
        ),
        pw.Container(height: 4, color: teal),
        pw.Container(
          color: soft,
          padding: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 9),
          child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                contact('ADDRESS', Cfg.address, 4),
                pw.SizedBox(width: 10),
                contact('TELEPHONE', Cfg.phone, 3),
                pw.SizedBox(width: 10),
                contact('EMAIL', Cfg.email, 4),
              ]),
        ),
      ]);

  final doc =
      pw.Document(title: 'Medical form ${f.formNo}', author: Cfg.clinicName);
  doc.addPage(pw.MultiPage(
    pageTheme: pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      buildBackground: (_) => pdfWatermark(PdfPageFormat.a4),
    ),
    header: (ctx) => ctx.pageNumber == 1 ? band() : pw.SizedBox(height: 26),
    footer: (ctx) => pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(26, 0, 26, 18),
      child: pw.Column(children: [
        pw.Divider(color: line),
        pw.SizedBox(height: 4),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('${Cfg.clinicName} - confidential medical record',
              style: pw.TextStyle(fontSize: 7.5, color: grey)),
          pw.Text(
              '${f.formNo}   |   Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 7.5, color: grey)),
        ]),
      ]),
    ),
    build: (ctx) => [
      pw.SizedBox(height: 18),
      pad(pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                label('PATIENT'),
                pw.SizedBox(height: 5),
                pw.Text(f.patientName,
                    style: pw.TextStyle(
                        fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                if (f.age > 0)
                  pw.Text('Age: ${f.age}',
                      style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Tel: ${f.phone}',
                    style: const pw.TextStyle(fontSize: 9)),
                if (f.email.isNotEmpty)
                  pw.Text('Email: ${f.email}',
                      style: const pw.TextStyle(fontSize: 9)),
                pw.Text(f.address, style: const pw.TextStyle(fontSize: 9)),
                if (f.nextOfKin.isNotEmpty)
                  pw.Text('Next of kin: ${f.nextOfKin}',
                      style: const pw.TextStyle(fontSize: 9)),
              ]),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                label('FORM DETAILS'),
                pw.SizedBox(height: 5),
                kv('Date', df.format(when)),
                kv('Time', tf.format(when)),
                kv('Form No.', f.formNo),
                kv('Entered by', f.createdBy.isEmpty ? '-' : f.createdBy),
              ]),
        ),
      ])),
      pw.SizedBox(height: 18),
      pad(headerRow()),
      for (final r in _formRows(f)) pad(dataRow(r.key, r.value)),
    ],
  ));
  return doc.save();
}

// ====================================================================== CREATE (prompt)
/// Opens the "Create medical form" prompt for one patient. Only patients who need a form get one.
Future<void> showCreateMedicalFormDialog(
        BuildContext context, Visit patient, AppUser user) =>
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CreateMedicalFormDialog(
            host: context, patient: patient, user: user));

class _CreateMedicalFormDialog extends StatefulWidget {
  final BuildContext host;
  final Visit patient;
  final AppUser user;
  const _CreateMedicalFormDialog(
      {required this.host, required this.patient, required this.user});
  @override
  State<_CreateMedicalFormDialog> createState() =>
      _CreateMedicalFormDialogState();
}

class _CreateMedicalFormDialogState extends State<_CreateMedicalFormDialog> {
  final form = GlobalKey<FormState>();
  final complaints = TextEditingController(),
      notes = TextEditingController(),
      diagnosis = TextEditingController(),
      management = TextEditingController(),
      treatment = TextEditingController(),
      formBy = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    for (final c in [
      complaints,
      notes,
      diagnosis,
      management,
      treatment,
      formBy
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final allEmpty = [complaints, notes, diagnosis, management, treatment]
        .every((c) => c.text.trim().isEmpty);
    if (allEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Fill in at least one field of the table.')));
      return;
    }
    setState(() => busy = true);
    final nav = Navigator.of(context);
    final p = widget.patient;
    try {
      final id = await Svc.addMedicalForm(
        name: p.name,
        age: p.age,
        phone: p.phone,
        email: p.email,
        address: p.address,
        nextOfKin: p.nextOfKin,
        complaints: complaints.text.trim(),
        notes: notes.text.trim(),
        diagnosis: diagnosis.text.trim(),
        management: management.text.trim(),
        treatment: treatment.text.trim(),
        formBy: formBy.text.trim(),
        by: widget.user,
      );
      final saved = MedicalForm(
        id: id,
        patientName: p.name,
        age: p.age,
        phone: p.phone,
        email: p.email,
        address: p.address,
        nextOfKin: p.nextOfKin,
        complaints: complaints.text.trim(),
        notes: notes.text.trim(),
        diagnosis: diagnosis.text.trim(),
        management: management.text.trim(),
        treatment: treatment.text.trim(),
        formBy: formBy.text.trim(),
        createdBy: widget.user.name,
        createdAt: DateTime.now(),
      );
      nav.pop();
      messenger
          .showSnackBar(const SnackBar(content: Text('Medical form saved.')));
      if (widget.host.mounted) showMedicalFormDialog(widget.host, saved);
    } catch (e) {
      if (mounted) setState(() => busy = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _row(String label, TextEditingController c,
      {bool required = false, int minLines = 2, String hint = ''}) {
    return Container(
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border))),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 104,
            padding: const EdgeInsets.all(10),
            color: const Color(0xFFF6F9FB),
            child: Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          Container(width: 1, color: AppColors.border),
          Expanded(
            child: TextFormField(
              controller: c,
              minLines: minLines,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                filled: false,
                hintText: hint,
                contentPadding: const EdgeInsets.all(10),
              ),
              validator: (t) => required && (t == null || t.trim().isEmpty)
                  ? 'Required'
                  : null,
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    return appDialog(
      context,
      title: 'Create medical form',
      subtitle: '${p.name}${p.age > 0 ? ' - ${p.age} yrs' : ''} - ${p.phone}',
      width: 640,
      content: Form(
        key: form,
        child: SingleChildScrollView(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                color: AppColors.navy,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: const Row(children: [
                  SizedBox(
                      width: 104,
                      child: Text('FIELD',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .8))),
                  Expanded(
                      child: Padding(
                          padding: EdgeInsets.only(left: 1),
                          child: Text('DETAILS',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: .8)))),
                ]),
              ),
              _row('Complaints', complaints),
              _row('Notes', notes),
              _row('Diagnosis', diagnosis),
              _row('Management', management),
              _row('Treatment', treatment),
              _row('Medical form by', formBy,
                  required: true, minLines: 1, hint: 'Enter name'),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton.icon(
            onPressed: busy ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(busy ? 'Saving...' : 'Save form')),
      ],
    );
  }
}

// ====================================================================== VIEW / PRINT
Future<void> showMedicalFormDialog(BuildContext context, MedicalForm f) {
  final when = f.createdAt ?? DateTime.now();
  Widget row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 100,
              child: Text(a, style: const TextStyle(color: AppColors.muted))),
          Expanded(
              child:
                  Text(b, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
  Widget tableRow(String k, String v, {bool first = false}) => Container(
        decoration: BoxDecoration(
            border: first
                ? null
                : const Border(top: BorderSide(color: AppColors.border))),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 104,
              padding: const EdgeInsets.all(10),
              color: const Color(0xFFF6F9FB),
              child: Text(k,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            Container(width: 1, color: AppColors.border),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(_orDash(v)))),
          ]),
        ),
      );
  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(18),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [AppColors.navy, AppColors.navy2])),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const Text(Cfg.clinicName,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              const Text(Cfg.tagline,
                                  style: TextStyle(
                                      color: Color(0xFF7FD6D1), fontSize: 12)),
                              const SizedBox(height: 8),
                              Text('${Cfg.phone}  |  ${Cfg.email}',
                                  style: const TextStyle(
                                      color: Color(0xFFCFE6EA), fontSize: 12)),
                            ])),
                        const Pill('MEDICAL FORM', Colors.white, AppColors.teal,
                            icon: Icons.description_outlined),
                      ]),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(children: [
                    row('Form No.', f.formNo),
                    row('Date', DateFormat('d MMM yyyy, h:mm a').format(when)),
                    row('Patient', f.patientName),
                    if (f.age > 0) row('Age', '${f.age}'),
                    row('Phone', f.phone),
                    if (f.email.isNotEmpty) row('Email', f.email),
                    row('Address', f.address),
                    if (f.nextOfKin.isNotEmpty) row('Next of kin', f.nextOfKin),
                    const SizedBox(height: 14),
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border)),
                      child: Column(children: [
                        for (var i = 0; i < _formRows(f).length; i++)
                          tableRow(_formRows(f)[i].key, _formRows(f)[i].value,
                              first: i == 0),
                      ]),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                  child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close')),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download),
                          label: const Text('Download'),
                          onPressed: () async => Printing.sharePdf(
                              bytes: await buildMedicalForm(f),
                              filename: 'MedicalForm-${f.formNo}.pdf'),
                        ),
                        FilledButton.icon(
                          icon: const Icon(Icons.print),
                          label: const Text('Print'),
                          onPressed: () async => Printing.layoutPdf(
                              name: 'MedicalForm-${f.formNo}',
                              onLayout: (_) => buildMedicalForm(f)),
                        ),
                      ]),
                ),
              ]),
        ),
      ),
    ),
  );
}
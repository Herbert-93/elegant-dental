import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'config.dart';
import 'models.dart';

/// Balance shown on the receipt: the amount if one was entered, otherwise "Nil".
String balanceLabel(Visit v) => v.balance > 0 ? money(v.balance) : 'Nil';

/// Next appointment shown on the receipt: the date if one was entered, otherwise "Null".
String nextApptLabel(Visit v) {
  final s = v.nextAppointment.trim();
  if (s.isEmpty) return 'Null';
  final d = DateTime.tryParse(s);
  return d == null ? s : DateFormat('EEE, d MMM yyyy').format(d);
}

/// Plain-text version of the receipt (used for WhatsApp / Email / Copy).
String receiptText(Visit v) {
  final when = v.treatedAt ?? v.createdAt ?? DateTime.now();
  final b = StringBuffer()
    ..writeln('*${Cfg.clinicName}*')
    ..writeln('PAYMENT RECEIPT - ${v.receiptNo}')
    ..writeln('Date: ${DateFormat('d MMM yyyy, h:mm a').format(when)}')
    ..writeln('--------------------------')
    ..writeln('Patient: ${v.name}')
    ..write(v.nextOfKin.isEmpty ? '' : 'Next of kin: ${v.nextOfKin}\n')
    ..writeln('Treatment: ${v.treatment}')
    ..writeln('Payment method: ${v.paymentMethod}')
    ..writeln('*TOTAL PAID: ${money(v.cost ?? 0)}*')
    ..writeln('Balance: ${balanceLabel(v)}')
    ..writeln('Next appointment: ${nextApptLabel(v)}')
    ..writeln('--------------------------')
    ..writeln('Thank you for choosing ${Cfg.clinicName}.')
    ..writeln('Tel: ${Cfg.phone}')
    ..writeln('Email: ${Cfg.email}');
  return b.toString();
}

Future<Uint8List> buildReceipt(Visit v) async {
  final navy = PdfColor.fromHex('#0B2A3C');
  final teal = PdfColor.fromHex('#0A7F7B');
  final mint = PdfColor.fromHex('#7FD6D1');
  final soft = PdfColor.fromHex('#F2F6F9');
  final grey = PdfColor.fromHex('#6B7C88');
  final green = PdfColor.fromHex('#1B9E5A');
  final line = PdfColor.fromHex('#E1E9EE');
  final when = v.treatedAt ?? v.createdAt ?? DateTime.now();
  final df = DateFormat('d MMM yyyy');
  final tf = DateFormat('h:mm a');
  final amount = money(v.cost ?? 0);
  final servedBy = v.treatedBy.isNotEmpty ? v.treatedBy : v.createdBy;

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

  pw.Widget totalRow(String k, String val) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(k, style: pw.TextStyle(fontSize: 9, color: grey)),
              pw.Text(val,
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ]),
      );

  final doc =
      pw.Document(title: 'Receipt ${v.receiptNo}', author: Cfg.clinicName);
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a5,
    margin: pw.EdgeInsets.zero,
    build: (_) =>
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      // ---- header band
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
                    pw.Text('RECEIPT',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 2)),
                    pw.SizedBox(height: 3),
                    pw.Text(v.receiptNo,
                        style: pw.TextStyle(
                            color: PdfColor.fromHex('#CFE6EA'), fontSize: 9)),
                  ]),
            ]),
      ),
      pw.Container(height: 4, color: teal),
      // ---- clinic contact bar
      pw.Container(
        color: soft,
        padding: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 9),
        child:
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          contact('ADDRESS', Cfg.address, 4),
          pw.SizedBox(width: 10),
          contact('TELEPHONE', Cfg.phone, 3),
          pw.SizedBox(width: 10),
          contact('EMAIL', Cfg.email, 4),
        ]),
      ),
      // ---- body
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(26, 18, 26, 0),
        child: pw
            .Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    label('BILLED TO'),
                    pw.SizedBox(height: 5),
                    pw.Text(v.name,
                        style: pw.TextStyle(
                            fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 3),
                    pw.Text('Age: ${v.age}',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Tel: ${v.phone}',
                        style: const pw.TextStyle(fontSize: 9)),
                    if (v.email.isNotEmpty)
                      pw.Text('Email: ${v.email}',
                          style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(v.address, style: const pw.TextStyle(fontSize: 9)),
                    if (v.nextOfKin.isNotEmpty)
                      pw.Text('Next of kin: ${v.nextOfKin}',
                          style: const pw.TextStyle(fontSize: 9)),
                  ]),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    label('RECEIPT DETAILS'),
                    pw.SizedBox(height: 5),
                    kv('Date', df.format(when)),
                    kv('Time', tf.format(when)),
                    kv('Patient No.', '#${v.number}'),
                    kv('Served by', servedBy.isEmpty ? '-' : servedBy),
                  ]),
            ),
          ]),
          pw.SizedBox(height: 18),
          pw.Container(
            color: navy,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('DESCRIPTION',
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1)),
                  pw.Text('AMOUNT',
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1)),
                ]),
          ),
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: line))),
            child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(v.treatment,
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold)),
                          if (v.notes.isNotEmpty)
                            pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 2),
                                child: pw.Text(v.notes,
                                    style: pw.TextStyle(
                                        fontSize: 8.5, color: grey))),
                        ]),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Text(amount,
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ]),
          ),
          pw.SizedBox(height: 14),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Expanded(
              child: pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Transform.rotate(
                  angle: -0.18,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: green, width: 2.2),
                        borderRadius: pw.BorderRadius.circular(6)),
                    child: pw.Text('PAID',
                        style: pw.TextStyle(
                            color: green,
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 3)),
                  ),
                ),
              ),
            ),
            pw.SizedBox(
              width: 190,
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    totalRow('Subtotal', amount),
                    totalRow('Payment method',
                        v.paymentMethod.isEmpty ? '-' : v.paymentMethod),
                    totalRow('Balance', balanceLabel(v)),
                    totalRow('Next appointment', nextApptLabel(v)),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      color: teal,
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAL PAID',
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text(amount,
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 13,
                                    fontWeight: pw.FontWeight.bold)),
                          ]),
                    ),
                  ]),
            ),
          ]),
        ]),
      ),
      pw.Spacer(),
      // ---- footer
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(26, 0, 26, 18),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Divider(color: line),
              pw.SizedBox(height: 6),
              pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data:
                          'Receipt ${v.receiptNo} | ${v.name} | $amount | ${v.date}',
                      width: 52,
                      height: 52,
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Thank you for choosing ${Cfg.clinicName}.',
                                style: pw.TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 2),
                            pw.Text('We wish you a healthy, confident smile!',
                                style:
                                    pw.TextStyle(fontSize: 8.5, color: grey)),
                            pw.SizedBox(height: 2),
                            pw.Text(
                                'Computer-generated receipt - valid without a signature.',
                                style:
                                    pw.TextStyle(fontSize: 7.5, color: grey)),
                          ]),
                    ),
                  ]),
            ]),
      ),
    ]),
  ));
  return doc.save();
}

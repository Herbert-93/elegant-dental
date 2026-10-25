import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'config.dart';
import 'models.dart';

Future<Uint8List> buildReceipt(Visit v) async {
  final doc = pw.Document();
  final df = DateFormat('d MMM yyyy, HH:mm');

  pw.Widget row(String a, String b) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: 110, child: pw.Text(a, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(child: pw.Text(b)),
        ]),
      );

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a5,
    margin: const pw.EdgeInsets.all(28),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Center(child: pw.Text(Cfg.clinicName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
      pw.Center(child: pw.Text(Cfg.address)),
      pw.Center(child: pw.Text('Tel: ${Cfg.phone}')),
      pw.SizedBox(height: 8),
      pw.Divider(),
      pw.Center(child: pw.Text('PAYMENT RECEIPT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: 8),
      row('Receipt No:', v.receiptNo),
      row('Date:', df.format(v.treatedAt ?? DateTime.now())),
      row('Patient No (day):', '${v.number}'),
      row('Patient Name:', v.name),
      row('Age:', '${v.age}'),
      row('Phone:', v.phone),
      row('Address:', v.address),
      pw.Divider(),
      row('Treatment:', v.treatment),
      if (v.notes.isNotEmpty) row('Notes:', v.notes),
      row('Payment Method:', v.paymentMethod),
      pw.SizedBox(height: 6),
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(border: pw.Border.all()),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('TOTAL PAID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
          pw.Text(money(v.cost ?? 0), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
        ]),
      ),
      pw.Spacer(),
      pw.Center(child: pw.Text('Served by: ${v.createdBy}')),
      pw.SizedBox(height: 4),
      pw.Center(child: pw.Text('Thank you for choosing ${Cfg.clinicName}. Wishing you a healthy smile!')),
    ]),
  ));
  return doc.save();
}

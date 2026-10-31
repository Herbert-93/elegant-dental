import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'models.dart';
import 'receipt.dart';
import 'theme.dart';

String _waNumber(String raw) {
  final d = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (d.startsWith('+')) return d.substring(1);
  if (d.startsWith('00')) return d.substring(2);
  if (d.startsWith('0')) return Cfg.countryCode + d.substring(1);
  return d;
}

Future<void> _nativeShare(BuildContext context, Visit v) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = await buildReceipt(v);
    await Share.shareXFiles(
      [
        XFile.fromData(bytes,
            mimeType: 'application/pdf', name: 'Receipt-${v.receiptNo}.pdf')
      ],
      subject: 'Receipt ${v.receiptNo} - ${Cfg.clinicName}',
      text: receiptText(v),
    );
  } catch (_) {
    messenger.showSnackBar(const SnackBar(
        content: Text(
            'This browser cannot share files directly. Use WhatsApp, Email or Download PDF instead.')));
  }
}

Future<void> _whatsapp(Visit v) {
  final n = _waNumber(v.phone);
  final url =
      'https://wa.me/${n.isEmpty ? '' : n}?text=${Uri.encodeComponent(receiptText(v))}';
  return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

Future<void> _email(Visit v) {
  final subject =
      Uri.encodeComponent('Receipt ${v.receiptNo} - ${Cfg.clinicName}');
  final body = Uri.encodeComponent(receiptText(v));
  return launchUrl(Uri.parse('mailto:${v.email}?subject=$subject&body=$body'));
}

Future<void> showShareSheet(BuildContext context, Visit v) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 520),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) {
      Widget tile(IconData icon, Color color, String title, String sub,
              VoidCallback onTap) =>
          ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(sub),
            onTap: () {
              Navigator.pop(ctx);
              onTap();
            },
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Share receipt',
                        style: TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800)))),
            tile(
                Icons.ios_share,
                AppColors.tealDark,
                'Share PDF file',
                'Opens your device share menu with the PDF attached',
                () => _nativeShare(context, v)),
            tile(
                Icons.chat,
                const Color(0xFF1FA855),
                'WhatsApp',
                v.phone.isEmpty
                    ? 'Send receipt details on WhatsApp'
                    : 'Send to ${v.phone}',
                () => _whatsapp(v)),
            tile(
                Icons.email_outlined,
                AppColors.navy2,
                'Email',
                v.email.isEmpty
                    ? 'Compose an email with the receipt details'
                    : 'Send to ${v.email}',
                () => _email(v)),
            tile(Icons.copy, AppColors.muted, 'Copy receipt text',
                'Copy the details to paste anywhere', () async {
              await Clipboard.setData(ClipboardData(text: receiptText(v)));
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Receipt text copied.')));
            }),
          ]),
        ),
      );
    },
  );
}

Future<void> showReceiptDialog(BuildContext context, Visit v) {
  final when = v.treatedAt ?? v.createdAt ?? DateTime.now();
  Widget row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 110,
              child: Text(a, style: const TextStyle(color: AppColors.muted))),
          Expanded(
              child:
                  Text(b, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
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
        constraints: const BoxConstraints(maxWidth: 480),
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
                        const Pill('PAID', Colors.white, AppColors.green,
                            icon: Icons.check_circle),
                      ]),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(children: [
                    row('Receipt No.', v.receiptNo),
                    row('Date', DateFormat('d MMM yyyy, h:mm a').format(when)),
                    row('Patient', '${v.name} (#${v.number})'),
                    row('Phone', v.phone),
                    if (v.email.isNotEmpty) row('Email', v.email),
                    if (v.nextOfKin.isNotEmpty) row('Next of kin', v.nextOfKin),
                    row('Treatment', v.treatment),
                    if (v.medicines.isNotEmpty) ...[
                      row('Treatment cost', money(v.treatmentCost)),
                      for (final m in v.medicines)
                        row('Medicine', '${m.name} - ${money(m.cost)}'),
                    ],
                    row('Payment', v.paymentDetail),
                    row('Balance', balanceLabel(v)),
                    row('Next appointment', nextApptLabel(v)),
                    const Divider(height: 26),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL PAID',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          Text(money(v.cost ?? 0),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 24,
                                  color: AppColors.tealDark)),
                        ]),
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
                              bytes: await buildReceipt(v),
                              filename: 'Receipt-${v.receiptNo}.pdf'),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.print),
                          label: const Text('Print'),
                          onPressed: () async => Printing.layoutPdf(
                              name: 'Receipt-${v.receiptNo}',
                              onLayout: (_) => buildReceipt(v)),
                        ),
                        FilledButton.icon(
                            icon: const Icon(Icons.share),
                            label: const Text('Share'),
                            onPressed: () => showShareSheet(ctx, v)),
                      ]),
                ),
              ]),
        ),
      ),
    ),
  );
}

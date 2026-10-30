import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Elegant Dental Care logo (transparent PNG, embedded so no asset setup is needed).
final Uint8List logoBytes = base64Decode(
    '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'
    );

/// The logo as a Flutter widget. Dark navy artwork, so give it a light background.
class ClinicLogo extends StatelessWidget {
  final double height;
  const ClinicLogo({super.key, this.height = 40});
  @override
  Widget build(BuildContext context) => Image.memory(logoBytes,
      height: height, fit: BoxFit.contain, gaplessPlayback: true);
}

/// A white rounded badge holding the logo - used on the dark sidebar / login panel.
class LogoBadge extends StatelessWidget {
  final double size;
  const LogoBadge({super.key, this.size = 44});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.3)),
        child: Image.memory(logoBytes, fit: BoxFit.contain, gaplessPlayback: true),
      );
}

/// Faint centred logo drawn BEHIND the page content of printed / shared PDFs.
/// Use as `buildBackground` of a pw.PageTheme.
pw.Widget pdfWatermark(PdfPageFormat fmt, {double opacity = 0.10}) => pw.Center(
      child: pw.Opacity(
        opacity: opacity,
        child: pw.Image(pw.MemoryImage(logoBytes),
            width: fmt.width * 0.55, fit: pw.BoxFit.contain),
      ),
    );
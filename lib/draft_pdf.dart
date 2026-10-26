import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'document_calculation.dart';

Future<Uint8List> createDraftPdf(String number, String customer,
    List<DraftLine> items, int discountPercent) async {
  final pdf = pw.Document();
  final total = DraftTotals.afterDiscountCents(items, discountPercent * 100);
  pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (_) => [
    pw.Text('BIZPILOT AI - DOKUMENTENTWURF'),
    pw.Text('Nummer: $number'),
    pw.Text('Kunde: $customer'),
    pw.TableHelper.fromTextArray(
      headers: ['Leistung', 'Menge', 'Preis', 'Gesamt'],
      data: items.map((line) => [
        line.description,
        line.quantity.toString(),
        DraftTotals.euro(line.unitPriceCents),
        DraftTotals.euro(line.totalCents),
      ]).toList(),
    ),
    pw.Text('Rabatt: $discountPercent %'),
    pw.Text('Summe: ${DraftTotals.euro(total)}'),
    pw.Text('Nur Vorschau. Keine Steuerberechnung.'),
  ]));
  return pdf.save();
}

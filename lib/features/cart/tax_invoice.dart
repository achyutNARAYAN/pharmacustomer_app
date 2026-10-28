import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/providers/profile_notifier.dart';
import '../../core/theme.dart';

Future<File> generateAndSaveInvoicePdf([String customerName = 'Verified Customer']) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context ctx) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'pharmaCustomer',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF087F8C),
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'pharmaCustomer Retail & Specialty Pharmacy Pvt Ltd',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Building 4B, Bio-Tech District, MIDC Phase II, Mumbai, MH - 400070',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
              pw.Divider(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Invoice No: AC-INV-2024-88402', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('GSTIN: 27AABCA9182L1Z9', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Billed To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(customerName, style: const pw.TextStyle(fontSize: 11)),
                      pw.Text('Verified Delivery Location', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.Divider(height: 20),
              pw.Text('Prescription Items', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Janumet 50mg/500mg (JN8103F)'),
                  pw.Text('INR 485.00'),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Rosuvas 10mg (RV1008)'),
                  pw.Text('INR 1,022.00'),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Clinical dispatch & GST'),
                  pw.Text('INR 161.46'),
                ],
              ),
              pw.Divider(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Taxable Subtotal'),
                  pw.Text('INR 1,345.54'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('CGST (6%) + SGST (6%)'),
                  pw.Text('INR 161.46'),
                ],
              ),
              pw.Divider(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Amount', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('INR 1,507.00', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF087F8C))),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );

  final bytes = await pdf.save();
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/Invoice_AC-INV-2024-88402.pdf');
  await file.writeAsBytes(bytes);

  // Share / save to device downloads or print
  await Printing.sharePdf(bytes: bytes, filename: 'Invoice_AC-INV-2024-88402.pdf');

  return file;
}

class TaxInvoice extends StatelessWidget {
  const TaxInvoice({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileNotifier>();
    final customerName = profile.name.isNotEmpty ? profile.name : 'Customer';
    final customerLocation = profile.address.isNotEmpty ? profile.address : 'Verified Account';
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tax Invoice'),
            Text(
              'Order Tax Receipt',
              style: TextStyle(fontSize: 11, color: AppTheme.mutedText),
            ),
          ],
        ),
      actions: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.picture_as_pdf_outlined),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.outlineBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'pharmaCustomer',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'pharmaCustomer Retail & Specialty Pharmacy Pvt Ltd',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Text(
                'Building 4B, Bio-Tech District, MIDC Phase II, Mumbai, MH – 400070',
                style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
              ),
              const Divider(height: 26),
              const Row(
                children: [
                  Expanded(child: _Detail('GSTIN Number', '27AABCA9182L1Z9')),
                  SizedBox(width: 8),
                  Expanded(child: _Detail('FSSAI License', '11521018000492')),
                ],
              ),
              const Divider(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Invoice Number', style: TextStyle(fontSize: 11)),
                        Text(
                          'AC-INV-2024-88402',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Date: 28 Oct 2024, 09:42 AM',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Billed To\n$customerName\n$customerLocation',
                    textAlign: TextAlign.right,
                    style: const TextStyle(height: 1.4),
                  ),
                ],
              ),
              const Divider(height: 26),
              const Text(
                'Prescription Items & Taxes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              const _InvoiceItem(
                'Janumet 50mg/500mg',
                'Batch JN8103F · Exp 04/2027',
                '₹485.00',
              ),
              const _InvoiceItem(
                'Rosuvas 10mg',
                'Batch RV1008 · Exp 08/2027',
                '₹1,022.00',
              ),
              const _InvoiceItem(
                'Clinical dispatch & GST',
                'GST included',
                '₹161.46',
              ),
              const Divider(height: 24),
              const _Total('Taxable subtotal', '₹1,345.54'),
              const _Total('Central GST (6%)', '₹80.73'),
              const _Total('State GST (6%)', '₹80.73'),
              const Divider(height: 24),
              const _Total('Gross amount', '₹1,507.00', bold: true),
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              try {
                final file = await generateAndSaveInvoicePdf(customerName);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invoice saved to ${file.path}')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save invoice: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download Invoice'),
          ),
        ),
      ),
    ),
  );
}
}

class _Detail extends StatelessWidget {
  const _Detail(this.title, this.value);
  final String title, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppTheme.surfaceLow,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 10)),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

class _InvoiceItem extends StatelessWidget {
  const _InvoiceItem(this.name, this.batch, this.price);
  final String name, batch, price;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                batch,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Text(price, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _Total extends StatelessWidget {
  const _Total(this.label, this.value, {this.bold = false});
  final String label, value;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: bold ? AppTheme.primaryDark : AppTheme.text,
            fontSize: bold ? 20 : 14,
          ),
        ),
      ],
    ),
  );
}

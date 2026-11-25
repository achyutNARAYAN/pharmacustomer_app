import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/models/cart_item.dart';
import '../../core/providers/cart_notifier.dart';
import '../../core/providers/profile_notifier.dart';
import '../../core/theme.dart';
import '../orders/providers/orders_provider.dart';
import '../profile/providers/customer_address_provider.dart';

String _formatInvoiceDate(DateTime dt) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final day = dt.day.toString().padLeft(2, '0');
  final month = months[dt.month - 1];
  final year = dt.year;
  final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '$day $month $year, $hour:$minute $period';
}

Future<File> generateAndSaveInvoicePdf({
  required String invoiceNumber,
  required String customerName,
  required String customerLocation,
  required DateTime orderDate,
  required List<CartItem> items,
  required double grossAmount,
  required double deliveryFee,
  required double taxableSubtotal,
  required double cgst,
  required double sgst,
  double? itemsTotal,
  double? discount,
  String? couponCode,
  String? allocatedStore,
}) async {
  final pdf = pw.Document();
  final formattedDate = _formatInvoiceDate(orderDate);

  final double calcItemsTotal = itemsTotal ??
      items.fold<double>(0.0, (sum, i) => sum + (i.price * i.quantity));
  final double calcDiscount = discount ?? 0.0;

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
                      pw.Text('Invoice No: $invoiceNumber', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('GSTIN: 27AABCA9182L1Z9', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Date: $formattedDate', style: const pw.TextStyle(fontSize: 10)),
                      if (allocatedStore != null && allocatedStore.isNotEmpty)
                        pw.Text('Dispensary Hub: $allocatedStore', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Billed To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(customerName, style: const pw.TextStyle(fontSize: 11)),
                      pw.Text(customerLocation, style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.Divider(height: 20),
              pw.Text('Prescription Items & Taxes', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              ...items.map((item) {
                final qtySuffix = item.quantity > 1 ? ' x ${item.quantity}' : '';
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${item.name}$qtySuffix'),
                      pw.Text('INR ${(item.price * item.quantity).toStringAsFixed(2)}'),
                    ],
                  ),
                );
              }),
              pw.Divider(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Items Total'),
                  pw.Text('INR ${calcItemsTotal.toStringAsFixed(2)}'),
                ],
              ),
              if (calcDiscount > 0)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(couponCode != null && couponCode.isNotEmpty
                          ? 'Coupon Discount ($couponCode)'
                          : 'Prescription Subsidy & Discount'),
                      pw.Text('-INR ${calcDiscount.toStringAsFixed(2)}', style: pw.TextStyle(color: PdfColors.green800)),
                    ],
                  ),
                ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Express Delivery Fee'),
                    pw.Text(deliveryFee == 0 ? 'FREE' : 'INR ${deliveryFee.toStringAsFixed(2)}'),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Handling & Packaging'),
                    pw.Text('FREE', style: pw.TextStyle(color: PdfColors.green800)),
                  ],
                ),
              ),
              pw.Divider(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Taxable Supply Value'),
                  pw.Text('INR ${taxableSubtotal.toStringAsFixed(2)}'),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Central GST (6%) + State GST (6%)'),
                  pw.Text('INR ${(cgst + sgst).toStringAsFixed(2)}'),
                ],
              ),
              pw.Divider(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Gross Amount Paid', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    'INR ${grossAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF087F8C),
                    ),
                  ),
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
  final cleanInv = invoiceNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final file = File('${dir.path}/Invoice_$cleanInv.pdf');
  await file.writeAsBytes(bytes);

  // Share / save to device downloads or print
  await Printing.sharePdf(bytes: bytes, filename: 'Invoice_$cleanInv.pdf');

  return file;
}

class TaxInvoice extends StatelessWidget {
  final String? orderId;
  final List<CartItem>? items;
  final double? totalPaid;
  final DateTime? orderDate;
  final double? itemsTotal;
  final double? discount;
  final double? deliveryFee;
  final String? couponCode;
  final String? allocatedStore;

  const TaxInvoice({
    super.key,
    this.orderId,
    this.items,
    this.totalPaid,
    this.orderDate,
    this.itemsTotal,
    this.discount,
    this.deliveryFee,
    this.couponCode,
    this.allocatedStore,
  });

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileNotifier>();
    final ordersProvider = context.watch<OrdersProvider?>();
    final cart = context.watch<CartNotifier>();

    CustomerAddressProvider? addressProvider;
    try {
      addressProvider = Provider.of<CustomerAddressProvider>(context, listen: false);
    } catch (_) {}

    final activeAddress = addressProvider?.selectedAddress ?? addressProvider?.defaultAddress;

    final latestOrder = (ordersProvider != null && ordersProvider.orders.isNotEmpty)
        ? ordersProvider.orders.first
        : null;

    final rawOrderId = orderId ?? latestOrder?.orderId ?? '';

    final invoiceNumber = rawOrderId.isNotEmpty
        ? (rawOrderId.startsWith('AC-') ? rawOrderId : 'AC-$rawOrderId')
        : 'N/A';

    final effectiveDate = orderDate ?? latestOrder?.createdAt ?? DateTime.now();

    List<CartItem> effectiveItems = (items != null && items!.isNotEmpty)
        ? items!
        : (latestOrder?.items != null && latestOrder!.items!.isNotEmpty
            ? latestOrder!.items!
            : cart.items);

    final double calcItemsTotal = itemsTotal ??
        (cart.itemsTotalPaise > 0
            ? (cart.itemsTotalPaise / 100.0)
            : effectiveItems.fold<double>(
                0.0,
                (sum, i) => sum + (i.price * i.quantity),
              ));

    final double grossAmount = totalPaid ??
        (latestOrder != null ? latestOrder.totalPaise / 100.0 : null) ??
        (cart.totalPrice > 0 ? cart.totalPrice : calcItemsTotal);

    final double effectiveDiscount = discount ??
        (cart.discountPaise > 0
            ? (cart.discountPaise / 100.0)
            : ((calcItemsTotal + (deliveryFee ?? 40.0) > grossAmount)
                ? (calcItemsTotal + (deliveryFee ?? 40.0) - grossAmount)
                : 0.0));

    final double effectiveDeliveryFee = deliveryFee ??
        (cart.deliveryFeePaise > 0
            ? (cart.deliveryFeePaise / 100.0)
            : ((grossAmount == calcItemsTotal - effectiveDiscount) ? 0.0 : 40.0));

    final String? effectiveCoupon = couponCode ?? cart.couponCode;
    final String? effectiveStore = allocatedStore ?? cart.allocatedStore;

    // GST calculations (retail medicine pricing in India includes GST)
    final double taxableSubtotal = grossAmount > 0 ? (grossAmount / 1.12) : 0.0;
    final double totalGst = grossAmount - taxableSubtotal;
    final double cgst = totalGst / 2;
    final double sgst = totalGst / 2;

    final customerName = activeAddress?.contactName ??
        (profile.name.isNotEmpty ? profile.name : 'Customer');
    final customerLocation = activeAddress != null
        ? '${activeAddress.typeKey} · ${activeAddress.displayDetails}'
        : (profile.address.isNotEmpty ? profile.address : 'Verified Account');
    final formattedDate = _formatInvoiceDate(effectiveDate);

    Future<void> handleDownloadPdf() async {
      try {
        final file = await generateAndSaveInvoicePdf(
          invoiceNumber: invoiceNumber,
          customerName: customerName,
          customerLocation: customerLocation,
          orderDate: effectiveDate,
          items: effectiveItems,
          grossAmount: grossAmount,
          deliveryFee: effectiveDeliveryFee,
          taxableSubtotal: taxableSubtotal,
          cgst: cgst,
          sgst: sgst,
          itemsTotal: calcItemsTotal,
          discount: effectiveDiscount,
          couponCode: effectiveCoupon,
          allocatedStore: effectiveStore,
        );
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
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
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
          IconButton(
            onPressed: handleDownloadPdf,
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Invoice',
          ),
          IconButton(
            onPressed: handleDownloadPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Download PDF',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.outlineBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'pharmaCustomer',
                    style: TextStyle(
                      fontSize: 20,
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
                const SizedBox(height: 4),
                const Text(
                  'Building 4B, Bio-Tech District, MIDC Phase II, Mumbai, MH – 400070',
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
                ),
                const Divider(height: 26),
                Row(
                  children: [
                    const Expanded(child: _Detail('GSTIN Number', '27AABCA9182L1Z9')),
                    const SizedBox(width: 8),
                    const Expanded(child: _Detail('FSSAI License', '11521018000492')),
                    if (effectiveStore != null && effectiveStore.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(child: _Detail('Fulfillment Hub', effectiveStore)),
                    ],
                  ],
                ),
                const Divider(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Invoice Number', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            invoiceNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Date: $formattedDate',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Billed To',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customerName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.right,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customerLocation,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 26),
                const Text(
                  'Prescription Items & Taxes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                if (effectiveItems.isNotEmpty)
                  ...effectiveItems.map(
                    (item) => _InvoiceItem(
                      item.name,
                      '${item.pack.isNotEmpty ? item.pack : "Standard Pack"}${item.quantity > 1 ? " · Qty: ${item.quantity}" : ""}',
                      '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No items listed in order',
                      style: TextStyle(color: AppTheme.mutedText),
                    ),
                  ),
                const Divider(height: 24),
                _Total('Items total', '₹${calcItemsTotal.toStringAsFixed(2)}'),
                if (effectiveDiscount > 0)
                  _Total(
                    effectiveCoupon != null && effectiveCoupon.isNotEmpty
                        ? 'Coupon discount ($effectiveCoupon)'
                        : 'Prescription subsidy & discount',
                    '−₹${effectiveDiscount.toStringAsFixed(2)}',
                    green: true,
                  ),
                _Total(
                  'Express delivery',
                  effectiveDeliveryFee == 0 ? 'FREE' : '₹${effectiveDeliveryFee.toStringAsFixed(2)}',
                  green: effectiveDeliveryFee == 0,
                ),
                const _Total('Handling & packaging', 'FREE', green: true),
                const Divider(height: 20),
                _Total('Taxable supply value', '₹${taxableSubtotal.toStringAsFixed(2)}'),
                _Total('Central GST (6%)', '₹${cgst.toStringAsFixed(2)}'),
                _Total('State GST (6%)', '₹${sgst.toStringAsFixed(2)}'),
                const Divider(height: 24),
                _Total('Gross amount', '₹${grossAmount.toStringAsFixed(2)}', bold: true),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: handleDownloadPdf,
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
        Text(title, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Text(
                batch,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Text(price, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      ],
    ),
  );
}

class _Total extends StatelessWidget {
  const _Total(this.label, this.value, {this.bold = false, this.green = false});
  final String label, value;
  final bool bold;
  final bool green;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: green
                ? AppTheme.successText
                : (bold ? AppTheme.primaryDark : AppTheme.text),
            fontSize: bold ? 20 : 14,
          ),
        ),
      ],
    ),
  );
}

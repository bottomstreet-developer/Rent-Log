import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'database_helper.dart';

class PdfService {
  static String _fmtDate(DateFormat df, String raw) {
    final d = DateTime.tryParse(raw);
    return d != null ? df.format(d) : raw;
  }

  static Future<void> exportPaymentHistory(int leaseId) async {
    final db = DatabaseHelper.instance;
    Lease? lease;
    for (final l in await db.getLeases()) {
      if (l.id == leaseId) {
        lease = l;
        break;
      }
    }
    if (lease == null) return;
    final Lease le = lease;

    final payments = await db.getPayments(leaseId);

    payments.sort((a, b) {
      final da = DateTime.tryParse(a.paymentDate);
      final dateB = DateTime.tryParse(b.paymentDate);
      if (da != null && dateB != null) return da.compareTo(dateB);
      return a.paymentDate.compareTo(b.paymentDate);
    });

    final totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);
    final firstDate = payments.isNotEmpty
        ? payments.first.paymentDate
        : le.leaseStartDate;
    final lastDate = payments.isNotEmpty
        ? payments.last.paymentDate
        : le.leaseEndDate;
    final dateFormat = DateFormat('MMM d, yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Payment History',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                dateFormat.format(DateTime.now()),
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SUMMARY',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _summaryItem('Total Paid', currencyFormat.format(totalPaid)),
                    _summaryItem('Payments', '${payments.length}'),
                    _summaryItem(
                      'Period',
                      '${_fmtDate(dateFormat, firstDate)} - ${_fmtDate(dateFormat, lastDate)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'LEASE DETAILS',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _detailItem('Property', le.propertyName),
              _detailItem('Address', le.address),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              _detailItem('Landlord', le.landlordName),
              _detailItem(
                'Monthly Rent',
                currencyFormat.format(le.monthlyRent),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              _detailItem(
                'Lease Start',
                _fmtDate(dateFormat, le.leaseStartDate),
              ),
              _detailItem(
                'Lease End',
                _fmtDate(dateFormat, le.leaseEndDate),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'PAYMENT RECORDS',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder(
              bottom: const pw.BorderSide(color: PdfColors.grey300),
              horizontalInside: const pw.BorderSide(color: PdfColors.grey200),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: ['Date', 'Method', 'Amount', 'Notes']
                    .map(
                      (h) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: pw.Text(
                          h,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              ...payments.map(
                (p) => pw.TableRow(
                  children: [
                    _cell(_fmtDate(dateFormat, p.paymentDate)),
                    _cell(p.paymentMethod),
                    _cell(currencyFormat.format(p.amount)),
                    _cell(p.notes),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                'Generated by RentLog',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey400,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'rentlog_payments_${le.propertyName.replaceAll(' ', '_')}.pdf',
    );
  }

  static pw.Widget _summaryItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static pw.Widget _detailItem(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 4),
        ],
      ),
    );
  }

  static pw.Widget _cell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }
}

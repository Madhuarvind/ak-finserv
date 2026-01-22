import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../utils/localizations.dart';

class LineReportScreen extends StatefulWidget {
  final int lineId;
  final String period; // 'daily' or 'weekly'
  final String? lineName;

  const LineReportScreen({super.key, required this.lineId, required this.period, this.lineName});

  @override
  State<LineReportScreen> createState() => _LineReportScreenState();
}

class _LineReportScreenState extends State<LineReportScreen> {
  final ApiService _apiService = ApiService();
  final _storage = FlutterSecureStorage();
  Map<String, dynamic>? _reportData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final data = await _apiService.getLineSummaryReport(
          widget.lineId,
          widget.period,
          DateFormat('yyyy-MM-dd').format(DateTime.now()),
          token,
        );
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _printReport() async {
    if (_reportData == null) return;
    
    try {
      final doc = pw.Document();
      final summary = _reportData?['summary'] as Map<String, dynamic>? ?? {};
      final details = (_reportData?['details'] as List<dynamic>?) ?? [];
      final lineName = _reportData!['line_name'] ?? 'Unknown Line';
      final periodText = widget.period.toUpperCase();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pdfContext) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('AK FINSERV - ${context.translate('reports').toUpperCase()}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${context.translate('line_name')}: $lineName', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${context.translate('language')}: $periodText', style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: pw.TextStyle(fontSize: 12)),
              pw.Divider(thickness: 2, color: PdfColors.grey300),
              pw.SizedBox(height: 16),
            ],
          ),
          build: (pdfContext) => [
            pw.TableHelper.fromTextArray(
              headers: [
                context.translate('name'),
                'ID',
                context.translate('language'), // 'Mode' - reusing 'language' or need another key? Actually I added mode keys.
                context.translate('recently'),
                context.translate('amount'),
                context.translate('status')
              ],
              data: details.map((d) => [
                d['name'],
                d['customer_id'],
                (d['modes'] as List? ?? []).join(', '),
                d['time'] != null ? DateFormat('HH:mm').format(DateTime.parse(d['time'])) : '-',
                'Rs. ${d['amount']}',
                d['status']
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.center,
              },
            ),
            pw.SizedBox(height: 40),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                   _buildSummaryRow(context.translate('users'), (summary['total_customers'] ?? 0).toString()),
                   _buildSummaryRow(context.translate('active'), (summary['paid_customers'] ?? 0).toString()),
                   _buildSummaryRow(context.translate('cash'), 'Rs. ${summary['total_cash'] ?? 0}'),
                   _buildSummaryRow(context.translate('upi'), 'Rs. ${summary['total_upi'] ?? 0}'),
                   pw.SizedBox(width: 150, child: pw.Divider()),
                   pw.Text('${context.translate('paid_total')}: Rs. ${summary['total_collected'] ?? 0}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                ],
              ),
            ),
          ],
          footer: (pdfContext) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 32),
            child: pw.Text('Page ${pdfContext.pageNumber} of ${pdfContext.pagesCount}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
          ),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Line_Report_${lineName}_${widget.period}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print Error: $e')));
      }
    }
  }

  pw.Widget _buildSummaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('$label: ', style: const pw.TextStyle(fontSize: 12)),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('${widget.period == 'daily' ? context.translate('daily_report') : context.translate('weekly_report')}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          if (!_isLoading && _reportData != null)
            IconButton(
              icon: const Icon(Icons.print_rounded, color: Colors.white),
              onPressed: _printReport,
              tooltip: 'Print Report',
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : _reportData == null
                ? Center(child: Text(context.translate('user_not_found'), style: GoogleFonts.outfit(color: Colors.white70)))
                : _buildReportUI(),
      ),
    );
  }

  Widget _buildReportUI() {
    final summary = _reportData?['summary'] as Map<String, dynamic>? ?? {};
    final details = (_reportData?['details'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 100, left: 20, right: 20, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          _reportData!['line_name'] ?? widget.lineName ?? 'Unknown Line', 
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), 
                        overflow: TextOverflow.ellipsis
                      ),
                      const SizedBox(height: 4),
                      Text(DateFormat('dd MMMM yyyy').format(DateTime.now()), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text(widget.period.toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tally Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.6,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildTallyCard(context.translate('paid_total'), '₹${summary['total_collected'] ?? 0}', Icons.payments_rounded, Colors.greenAccent),
              _buildTallyCard('${context.translate('active')} / ${context.translate('total')}', '${summary['paid_customers'] ?? 0} / ${summary['total_customers'] ?? 0}', Icons.people_rounded, Colors.blueAccent),
              _buildTallyCard(context.translate('cash'), '₹${summary['total_cash'] ?? 0}', Icons.money_rounded, Colors.orangeAccent),
              _buildTallyCard(context.translate('upi'), '₹${summary['total_upi'] ?? 0}', Icons.account_balance_rounded, Colors.indigoAccent),
            ],
          ),
          const SizedBox(height: 32),

          // Collection Progress
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: (summary['total_customers'] ?? 0) > 0 
                            ? (summary['paid_customers'] ?? 0) / summary['total_customers'] 
                            : 0,
                        backgroundColor: Colors.white12,
                        color: AppTheme.primaryColor,
                        strokeWidth: 8,
                      ),
                    ),
                    Text(
                      '${(summary['total_customers'] ?? 0) > 0 ? (((summary['paid_customers'] ?? 0) / summary['total_customers']) * 100).toStringAsFixed(0) : 0}%',
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.translate('target_achieved'), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                        "${summary['paid_customers'] ?? 0} ${context.translate('active')} out of ${summary['total_customers'] ?? 0} ${context.translate('total')}",
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Customer List
          Text(context.translate('customer_breakdown'), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: details.length,
            itemBuilder: (context, index) {
              final d = details[index];
              final isPaid = d['status'] == 'Paid';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (isPaid ? Colors.green : Colors.grey).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(isPaid ? Icons.check_circle_rounded : Icons.pending_rounded, color: isPaid ? Colors.greenAccent : Colors.white54, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(d['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                            Text(d['customer_id'] ?? '-', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                          Text('₹${d['amount'] ?? 0}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: isPaid ? Colors.white : Colors.white54)),
                        if (isPaid)
                          Text((d['modes'] as List? ?? []).join(', ').toUpperCase(), style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 80), // Space for print button if we put it floating
        ],
      ),
    );
  }

  Widget _buildTallyCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}

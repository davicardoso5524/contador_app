// lib/services/pdf_report_service.dart
// Placeholder: IDs de sabores devem ser alinhados com categorias desejadas no PDF

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class PdfReportService {
  /// Gera PDF com relatório de vendas e abre share sheet
  ///
  /// [start] e [end]: intervalo de datas do relatório
  /// [reportByDay]: Map DateTime, Map String,int com vendas por dia e sabor
  /// [summaryByFlavor]: Map String,int com totais por sabor para todo intervalo
  /// [flavorName]: função que converte ID de sabor para nome
  static Future<void> generateAndSharePdf({
    required DateTime start,
    required DateTime end,
    required Map<DateTime, Map<String, int>> reportByDay,
    required Map<String, int> summaryByFlavor,
    required String Function(String flavorId) flavorName,
  }) async {
    try {
      final pdf = pw.Document();

      // Cabeçalho
      final sortedEntries = reportByDay.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      final dayWidgets = <pw.Widget>[];

      // Seções por dia
      for (final entry in sortedEntries) {
        dayWidgets.add(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Cabeçalho do dia
              pw.Text(
                'Dia ${_formatDate(entry.key)}',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),

              // Lista de sabores do dia
              ...(entry.value.entries.toList().where((e) => e.value > 0).map((
                flavorEntry,
              ) {
                return pw.Text(
                  '• ${flavorName(flavorEntry.key)}: ${flavorEntry.value} vendidas',
                  style: const pw.TextStyle(fontSize: 10),
                );
              })),

              // Se nenhuma venda no dia
              if (!entry.value.values.any((v) => v != 0))
                pw.Text(
                  'Nenhuma venda neste dia',
                  style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
                ),

              pw.SizedBox(height: 12),
            ],
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) {
            return [
              // Título
              pw.Center(
                child: pw.Text(
                  'Relatório de Vendas',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),

              // Período
              pw.Center(
                child: pw.Text(
                  'Período: ${_formatDate(start)} até ${_formatDate(end)}',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 16),

              // Seções por dia
              ...dayWidgets,

              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 16),

              // Resumo por categorias (conforme imagem de referência)
              _buildResumoCoxinhas(summaryByFlavor, flavorName),
              pw.SizedBox(height: 12),
              _buildResumoOutros(summaryByFlavor, flavorName),
              pw.SizedBox(height: 16),

              // Total Geral
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL GERAL',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    summaryByFlavor.values
                        .fold<int>(0, (sum, v) => sum + v)
                        .toString(),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ];
          },
        ),
      );

      // Salva em arquivo temporário
      final output = await getTemporaryDirectory();
      final fileName =
          'relatorio_${_formatDateForFile(start)}_${_formatDateForFile(end)}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      // Abre share sheet
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject:
              'Relatório de Vendas ${_formatDate(start)} a ${_formatDate(end)}',
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Formata data para padrão DD/MM/YYYY
  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Formata data para nome de arquivo
  static String _formatDateForFile(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}_${date.month.toString().padLeft(2, '0')}_${date.year}';
  }

  /// Constrói seção de resumo de coxinhas
  ///
  /// Agrupa sabores originais (coxinhas tradicionais)
  /// IDs: frango, frango_bacon, carne_do_sol, queijo, calabresa, pizza
  static pw.Widget _buildResumoCoxinhas(
    Map<String, int> summary,
    String Function(String) flavorName,
  ) {
    // IDs das coxinhas originais - AJUSTE CONFORME NECESSÁRIO EM flavors.dart
    const coxinhaIds = [
      'frango',
      'frango_bacon',
      'carne_do_sol',
      'queijo',
      'calabresa',
      'pizza',
    ];

    final totalCoxinhas = coxinhaIds.fold<int>(
      0,
      (sum, id) => sum + (summary[id] ?? 0),
    );

    final coxinhaRows = <pw.Widget>[];
    for (final id in coxinhaIds) {
      final count = summary[id] ?? 0;
      coxinhaRows.add(
        pw.Text(
          '${flavorName(id)}: $count',
          style: const pw.TextStyle(fontSize: 10),
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blue300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'COXINHAS',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          ...coxinhaRows,
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Subtotal Coxinhas:',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              pw.Text(
                '$totalCoxinhas',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Constrói seção de resumo de outros sabores (churros, kibes, etc.)
  ///
  /// IDs: churritos, doce-de-leite, chocolate, kibes
  static pw.Widget _buildResumoOutros(
    Map<String, int> summary,
    String Function(String) flavorName,
  ) {
    // IDs de outros sabores - AJUSTE CONFORME NECESSÁRIO EM flavors.dart
    const outrosIds = ['churritos', 'doce-de-leite', 'chocolate', 'kibes'];

    final totalOutros = outrosIds.fold<int>(
      0,
      (sum, id) => sum + (summary[id] ?? 0),
    );

    final labels = outrosIds.map((id) => flavorName(id)).toList().join(' | ');

    final outrosRows = <pw.Widget>[];
    for (final id in outrosIds) {
      final count = summary[id] ?? 0;
      outrosRows.add(
        pw.Text(
          '${flavorName(id)}: $count',
          style: const pw.TextStyle(fontSize: 10),
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.orange300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            labels,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          ...outrosRows,
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Subtotal Outros:',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              pw.Text(
                '$totalOutros',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// lib/pages/report_page.dart
// - Mostra uma seção por dia (10 cards)
// - Cada seção lista todos os 10 sabores com contagens por dia
// - Resumo final soma todas as quantidades por sabor do intervalo
// - Nenhuma referência a "Semana" ou "Final de Semana"
import 'package:flutter/material.dart';
import '../services/counter_service.dart';
import '../services/pdf_report_service.dart';
import '../shared/flavors.dart';

class ReportPage extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, int>? moreFlavorsData;

  const ReportPage({
    super.key,
    required this.startDate,
    required this.endDate,
    this.moreFlavorsData,
  });

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final CounterService _service = CounterService();
  late Map<DateTime, Map<String, int>> _dailyTotals;
  late Map<String, int> _summaryTotals;
  bool _loading = true;
  bool _generatingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  /// Carrega dados do intervalo de datas
  Future<void> _loadReportData() async {
    await _service.init();
    if (!mounted) return;

    setState(() {
      _dailyTotals = _service.totalsPerDayForRange(
        widget.startDate,
        widget.endDate,
      );
      _summaryTotals = _service.totalsSummaryForRange(
        widget.startDate,
        widget.endDate,
      );
      _loading = false;
    });
  }

  /// Formata data para exibição (DD/MM/YYYY)
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Retorna o nome do sabor por ID
  String _getFlavorName(String id) {
    try {
      final counter = _service.counters.firstWhere((c) => c.id == id);
      return counter.name;
    } catch (e) {
      return Flavors.getFlavorName(id);
    }
  }

  /// Gera e compartilha PDF do relatório
  Future<void> _generateAndSharePdf() async {
    if (_loading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carregando dados do relatório...')),
      );
      return;
    }

    setState(() {
      _generatingPdf = true;
    });

    try {
      await PdfReportService.generateAndSharePdf(
        start: widget.startDate,
        end: widget.endDate,
        reportByDay: _dailyTotals,
        summaryByFlavor: _summaryTotals,
        flavorName: _getFlavorName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _generatingPdf = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Relatório'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabeçalho com intervalo
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Período do Relatório',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_formatDate(widget.startDate)} até ${_formatDate(widget.endDate)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Relatório por dia
                      ..._buildDailyReportSections(),

                      const SizedBox(height: 24),

                      // Resumo Total
                      _buildSummarySection(),

                      const SizedBox(height: 24),

                      // Botão Gerar PDF e Compartilhar
                      ElevatedButton.icon(
                        onPressed: _generatingPdf ? null : _generateAndSharePdf,
                        icon: _generatingPdf
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.picture_as_pdf),
                        label: Text(
                          _generatingPdf
                              ? 'Gerando PDF...'
                              : 'Gerar PDF e Compartilhar',
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// Constrói as seções de relatório por dia
  List<Widget> _buildDailyReportSections() {
    final sections = <Widget>[];
    final sortedDates = _dailyTotals.keys.toList()..sort();

    for (final date in sortedDates) {
      final totals = _dailyTotals[date]!;
      final hasData = totals.values.any((v) => v != 0);

      sections.add(
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(date),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                if (!hasData)
                  const Text(
                    'Nenhuma coxinha vendida nesse dia.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  )
                else
                  ...Flavors.allFlavorIds.map((flavorId) {
                    final count = totals[flavorId] ?? 0;
                    final name = _getFlavorName(flavorId);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(name),
                          Text(
                            count.toString(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      );
    }

    return sections;
  }

  /// Constrói a seção de resumo (total por sabor)
  Widget _buildSummarySection() {
    final totalQty = _summaryTotals.values.fold<int>(0, (sum, v) => sum + v);

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RESUMO TOTAL DO PERÍODO',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ...Flavors.allFlavorIds.map((flavorId) {
              final total = _summaryTotals[flavorId] ?? 0;
              final name = _getFlavorName(flavorId);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 13)),
                    Text(
                      total.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL GERAL',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  totalQty.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

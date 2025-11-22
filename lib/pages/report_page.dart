// lib/pages/report_page.dart (VERSÃO OTIMIZADA)
// Otimizações para performance:
// 1) ListView.builder para virtualização de elementos (renderiza apenas visíveis)
// 2) Widgets separados (_DayTile, _SummaryTile) para evitar rebuilds globais
// 3) Todos os cálculos em _loadReportData() ANTES de build()
// 4) Dados imutáveis no estado
// 5) Botão no bottomNavigationBar (não sofre rerender do conteúdo)
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

  // Dados imutáveis, carregados uma única vez
  late List<DateTime> _sortedDates;
  late Map<DateTime, Map<String, int>> _dailyTotals;
  late Map<String, int> _summaryTotals;

  bool _loading = true;
  bool _generatingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  /// Carrega dados do intervalo de datas UMA ÚNICA VEZ
  /// Todos os cálculos feitos aqui, ANTES de build()
  Future<void> _loadReportData() async {
    await _service.init();
    if (!mounted) return;

    try {
      // Carregamento assíncrono
      final dailyTotals = await _service.totalsPerDayForRangeAsync(
        widget.startDate,
        widget.endDate,
      );
      final summaryTotals = await _service.totalsSummaryForRangeAsync(
        widget.startDate,
        widget.endDate,
      );

      if (!mounted) return;

      // Ordena as datas uma única vez (não em build)
      final sortedDates = dailyTotals.keys.toList()..sort();

      setState(() {
        _dailyTotals = dailyTotals;
        _summaryTotals = summaryTotals;
        _sortedDates = sortedDates;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar relatório: $e')),
        );
      }
    }
  }

  /// Formata data para exibição (função pura)
  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  /// Retorna o nome do sabor por ID
  String _getFlavorName(String id) {
    try {
      final counter = _service.counters.firstWhere((c) => c.id == id);
      return counter.name;
    } catch (e) {
      // Tenta obter do Flavors (inclui novos sabores)
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
      // Os dados já incluem os sabores adicionais via totalsPerDayForRangeAsync
      // Não é necessário merge com moreFlavorsData
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
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context);
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
            : _buildReportList(),
        // Botão fixo no bottomNavigationBar (não sofre rerender do conteúdo)
        bottomNavigationBar: SafeArea(
          bottom: true,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomPadding),
            child: ElevatedButton.icon(
              onPressed: _generatingPdf ? null : _generateAndSharePdf,
              icon: _generatingPdf
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: Text(
                _generatingPdf ? 'Gerando PDF...' : 'Gerar PDF e Compartilhar',
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Constrói a lista virtualizada com header, dias, resumo
  /// ListView.builder renderiza apenas os items visíveis na tela
  Widget _buildReportList() {
    // itemCount = 1 (header) + N (dias) + 1 (resumo) + 1 (spacing)
    final itemCount = 1 + _sortedDates.length + 1 + 1;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Item 0: Header com período
        if (index == 0) {
          return _HeaderTile(
            startDate: widget.startDate,
            endDate: widget.endDate,
          );
        }

        // Items 1 até N: Dias do relatório (virtualizados)
        if (index > 0 && index <= _sortedDates.length) {
          final dateIndex = index - 1;
          final date = _sortedDates[dateIndex];
          final dayTotals = _dailyTotals[date]!;

          return _DayTile(
            date: date,
            totals: dayTotals,
            getFlavorName: _getFlavorName,
          );
        }

        // Item N+1: Resumo Total
        if (index == _sortedDates.length + 1) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _SummaryTile(
              summaryTotals: _summaryTotals,
              getFlavorName: _getFlavorName,
            ),
          );
        }

        // Item final: Spacing para não sobrepor o botão
        return const SizedBox(height: 90);
      },
    );
  }
}

/// Header com período do relatório (widget immutable, sem rebuild desnecessário)
class _HeaderTile extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;

  const _HeaderTile({required this.startDate, required this.endDate});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Período do Relatório',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '${_ReportPageState._formatDate(startDate)} até ${_ReportPageState._formatDate(endDate)}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de um dia do relatório (widget immutable)
class _DayTile extends StatelessWidget {
  final DateTime date;
  final Map<String, int> totals;
  final String Function(String) getFlavorName;

  const _DayTile({
    required this.date,
    required this.totals,
    required this.getFlavorName,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = totals.values.any((v) => v != 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _ReportPageState._formatDate(date),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
              // Lista de sabores para este dia
              ...Flavors.allFlavorIds.map((flavorId) {
                final count = totals[flavorId] ?? 0;
                final name = getFlavorName(flavorId);
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
    );
  }
}

/// Card de resumo total (widget immutable)
class _SummaryTile extends StatelessWidget {
  final Map<String, int> summaryTotals;
  final String Function(String) getFlavorName;

  const _SummaryTile({
    required this.summaryTotals,
    required this.getFlavorName,
  });

  @override
  Widget build(BuildContext context) {
    final totalQty = summaryTotals.values.fold<int>(0, (sum, v) => sum + v);

    return Card(
      color: Colors.blue.shade50,
      margin: const EdgeInsets.only(bottom: 12),
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
            // Lista de sabores (pré-calculados, sem recálculo)
            ...Flavors.allFlavorIds.map((flavorId) {
              final total = summaryTotals[flavorId] ?? 0;
              final name = getFlavorName(flavorId);
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

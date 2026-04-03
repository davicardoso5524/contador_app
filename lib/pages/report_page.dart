// lib/pages/report_page.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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

  late List<DateTime> _sortedDates;
  late Map<DateTime, Map<String, int>> _dailyTotals;
  late Map<String, int> _summaryTotals;

  bool _loading = true;
  bool _generatingPdf = false;
  bool _showChart = false;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    await _service.init();
    if (!mounted) return;

    try {
      final dailyTotals = await _service.totalsPerDayForRangeAsync(
        widget.startDate,
        widget.endDate,
      );
      final summaryTotals = await _service.totalsSummaryForRangeAsync(
        widget.startDate,
        widget.endDate,
      );

      if (!mounted) return;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar relatório: $e')),
      );
    }
  }

  String _getFlavorName(String id) {
    try {
      final counter = _service.counters.firstWhere((c) => c.id == id);
      return counter.name;
    } catch (e) {
      return Flavors.getFlavorName(id);
    }
  }

  Future<void> _generateAndSharePdf() async {
    if (_loading) return;
    setState(() => _generatingPdf = true);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório'),
        actions: [
          IconButton(
            icon: Icon(_showChart ? Icons.list : Icons.pie_chart),
            onPressed: () => setState(() => _showChart = !_showChart),
            tooltip: _showChart ? 'Ver Lista' : 'Ver Gráfico',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _showChart 
              ? _buildChart()
              : _buildReportList(),
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomPadding),
          child: ElevatedButton.icon(
            onPressed: _generatingPdf ? null : _generateAndSharePdf,
            icon: _generatingPdf
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                : const Icon(Icons.picture_as_pdf),
            label: Text(_generatingPdf ? 'Gerando PDF...' : 'Gerar PDF e Compartilhar'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChart() {
    final total = _summaryTotals.values.fold<int>(0, (sum, v) => sum + v);
    if (total == 0) {
      return const Center(child: Text('Nenhum dado para exibir no gráfico.'));
    }

    final List<Color> colors = [
      Colors.blue, Colors.red, Colors.green, Colors.orange, 
      Colors.purple, Colors.amber, Colors.cyan, Colors.brown,
      Colors.pink, Colors.teal,
    ];

    int colorIndex = 0;
    final List<PieChartSectionData> sections = [];
    final List<Widget> indicators = [];

    _summaryTotals.forEach((id, value) {
      if (value > 0) {
        final color = colors[colorIndex % colors.length];
        final name = _getFlavorName(id);
        final percentage = (value / total * 100).toStringAsFixed(1);

        sections.add(PieChartSectionData(
          color: color,
          value: value.toDouble(),
          title: '$percentage%',
          radius: 100,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ));

        indicators.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(width: 12, height: 12, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text('$name ($value)', style: const TextStyle(fontSize: 12))),
              ],
            ),
          ),
        );
        colorIndex++;
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _HeaderTile(startDate: widget.startDate, endDate: widget.endDate),
          const SizedBox(height: 20),
          const Text('Distribuição de Vendas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: PieChart(PieChartData(sections: sections, sectionsSpace: 2, centerSpaceRadius: 40)),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: indicators.map((i) => SizedBox(width: 140, child: i)).toList(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildReportList() {
    final itemCount = 1 + _sortedDates.length + 1 + 1;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) return _HeaderTile(startDate: widget.startDate, endDate: widget.endDate);
        if (index > 0 && index <= _sortedDates.length) {
          final date = _sortedDates[index - 1];
          return _DayTile(date: date, totals: _dailyTotals[date]!, getFlavorName: _getFlavorName);
        }
        if (index == _sortedDates.length + 1) {
          return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: _SummaryTile(summaryTotals: _summaryTotals, getFlavorName: _getFlavorName));
        }
        return const SizedBox(height: 90);
      },
    );
  }
}

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
            const Text('Período do Relatório', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('${_formatDate(startDate)} até ${_formatDate(endDate)}', style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _DayTile extends StatelessWidget {
  final DateTime date;
  final Map<String, int> totals;
  final String Function(String) getFlavorName;
  const _DayTile({required this.date, required this.totals, required this.getFlavorName});
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
            Text(_formatDate(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            if (!hasData) const Text('Nenhuma coxinha vendida nesse dia.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
            else ...Flavors.allFlavorIds.map((flavorId) {
                final count = totals[flavorId] ?? 0;
                if (count == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(getFlavorName(flavorId)), Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.w600))]),
                );
              }),
          ],
        ),
      ),
    );
  }
  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _SummaryTile extends StatelessWidget {
  final Map<String, int> summaryTotals;
  final String Function(String) getFlavorName;
  const _SummaryTile({required this.summaryTotals, required this.getFlavorName});
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
            const Text('RESUMO TOTAL DO PERÍODO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            ...Flavors.allFlavorIds.map((flavorId) {
              final total = summaryTotals[flavorId] ?? 0;
              if (total == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(getFlavorName(flavorId), style: const TextStyle(fontSize: 13)), Text(total.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
              );
            }),
            const Divider(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL GERAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(totalQty.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]),
          ],
        ),
      ),
    );
  }
}

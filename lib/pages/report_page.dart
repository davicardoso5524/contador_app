// lib/pages/report_page.dart
import 'package:flutter/material.dart';
import '../services/counter_service.dart';
import '../models/counter.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final CounterService _service = CounterService();
  DateTime _selected = DateTime.now();
  Map<String, int> _totals = {};
  List<CounterModel> _counters = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    await _service.init();
    if (!mounted) return;
    _counters = _service.counters;
    _loadTotalsForSelected();
    setState(() {
      _loading = false;
    });
  }

  void _loadTotalsForSelected() {
    // Antes: usávamos totalsUpToDate -> acumulado até a data (isso causava o "copiar" dos valores)
    // Agora: usamos totalsForSingleDate -> somente os eventos DO DIA selecionado
    final totals = _service.totalsForSingleDate(_selected);
    if (!mounted) return;
    setState(() {
      _totals = totals;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _selected = picked);
      _loadTotalsForSelected();
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year.toString().substring(2)}';
  }

  // gera ranges: monday..thursday and friday..sunday for the week containing the selected date
  Map<String, DateTime> _computeWeekRanges(DateTime anyDate) {
    // get monday of the week containing anyDate
    final int weekday = anyDate.weekday; // Mon=1 ... Sun=7
    final monday = anyDate.subtract(Duration(days: weekday - 1));
    final second = DateTime(monday.year, monday.month, monday.day); // monday start
    final weekStart = second;
    final weekEnd = weekStart.add(const Duration(days: 3)); // mon..thu
    final weekendStart = weekStart.add(const Duration(days: 4)); // fri
    final weekendEnd = weekStart.add(const Duration(days: 6)); // sun
    return {
      'weekStart': weekStart,
      'weekEnd': weekEnd,
      'weekendStart': weekendStart,
      'weekendEnd': weekendEnd,
    };
  }

  void _showWeeklyPopup() {
    // compute ranges based on _selected (the date chosen in UI)
    final ranges = _computeWeekRanges(_selected);
    final DateTime wS = ranges['weekStart']!;
    final DateTime wE = ranges['weekEnd']!;
    final DateTime wsS = ranges['weekendStart']!;
    final DateTime wsE = ranges['weekendEnd']!;

    // totals aggregated for the ranges (unchanged)
    final Map<String,int> weekTotals = _service.totalsForRange(wS, wE);
    final Map<String,int> weekendTotals = _service.totalsForRange(wsS, wsE);
    final Map<String,int> combined = _service.totalsForRange(wS, wsE); // monday..sunday

    int sumWeek = weekTotals.values.fold(0, (p, n) => p + n);
    int sumWeekend = weekendTotals.values.fold(0, (p, n) => p + n);
    int sumCombined = combined.values.fold(0, (p, n) => p + n);

    // Build dialog content: for each day from monday..sunday show per-day totals or "nenhum registro"
    final List<Widget> content = [];

    // Helper: append per-day block
    void appendDayBlock(DateTime day) {
      final dayTotals = _service.totalsForSingleDate(day);
      final dayAny = dayTotals.values.any((v) => v != 0);
      content.add(Text(
        'Dia ${_formatDate(day)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));
      content.add(const SizedBox(height: 6));
      if (!dayAny) {
        content.add(const Text('Nenhuma coxinha adicionada nesse dia.'));
        content.add(const SizedBox(height: 8));
      } else {
        for (final c in _counters) {
          final v = dayTotals[c.id] ?? 0;
          content.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('${c.name} - $v'),
          ));
        }
        final daySum = dayTotals.values.fold(0, (p, n) => p + n);
        content.add(const SizedBox(height: 6));
        content.add(Text('TOTAL DO DIA - $daySum', style: const TextStyle(fontWeight: FontWeight.bold)));
        content.add(const SizedBox(height: 8));
      }
      content.add(const Divider());
    }

    // Append Semana (segunda..quinta) header + per-day breakdown
    content.add(Text('Semana - De ${_formatDate(wS)} até ${_formatDate(wE)}', style: const TextStyle(fontWeight: FontWeight.bold)));
    content.add(const SizedBox(height: 8));
    for (int i = 0; i <= 3; i++) {
      final day = wS.add(Duration(days: i));
      appendDayBlock(day);
    }
    content.add(Text('TOTAL VENDIDO NA SEMANA - $sumWeek', style: const TextStyle(fontWeight: FontWeight.bold)));
    content.add(const Divider(height: 18));

    // Append Fim de semana (sexta..domingo) header + per-day breakdown
    content.add(Text('FIM DE SEMANA - De ${_formatDate(wsS)} até ${_formatDate(wsE)}', style: const TextStyle(fontWeight: FontWeight.bold)));
    content.add(const SizedBox(height: 8));
    for (int i = 0; i <= 2; i++) {
      final day = wsS.add(Duration(days: i));
      appendDayBlock(day);
    }
    content.add(Text('TOTAL VENDIDO NO FINAL DE SEMANA - $sumWeekend', style: const TextStyle(fontWeight: FontWeight.bold)));
    content.add(const Divider(height: 18));

    // Combined total
    content.add(Text('TOTAL DE COXINHAS VENDIDAS DO DIA ${_formatDate(wS)} ATÉ ${_formatDate(wsE)}', style: const TextStyle(fontWeight: FontWeight.bold)));
    content.add(const SizedBox(height: 8));
    content.add(Text('TOTAL - $sumCombined', style: const TextStyle(fontWeight: FontWeight.bold)));

    // Show dialog
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Relatório Semanal (Detalhado por dia)'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatted = '${_selected.day.toString().padLeft(2, '0')}/${_selected.month.toString().padLeft(2, '0')}/${_selected.year}';
    final any = _totals.values.any((v) => v != 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Relatório')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text('Data selecionada: $formatted', style: const TextStyle(fontSize: 16))),
                ElevatedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.date_range),
                  label: const Text('Alterar Data'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Atualizar',
                  onPressed: _loadTotalsForSelected,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // BOTÃO GERAR RELATÓRIO SEMANAL
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _showWeeklyPopup,
                child: const Text('Gerar Relatório Semanal'),
              ),
            ),

            const SizedBox(height: 12),

            if (!any)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.info_outline, size: 42, color: Colors.black54),
                      SizedBox(height: 8),
                      Text(
                        'Nenhuma coxinha contabilizada nessa data.',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

            if (any)
              Expanded(
                child: ListView.separated(
                  itemCount: _counters.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final c = _counters[index];
                    final v = _totals[c.id] ?? 0;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(28),
                        child: Text(
                          v.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(c.name),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
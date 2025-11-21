// lib/pages/report_range_page.dart
// TODO: test manual - selecionar datas e clicar "Gerar Relatório" deve navegar para ReportPage com intervalo

import 'package:flutter/material.dart';

/// Tela de seleção de intervalo de datas para geração do relatório
/// Retorna um mapa com 'startDate' e 'endDate' ao navegar de volta
class ReportRangePage extends StatefulWidget {
  const ReportRangePage({super.key});

  @override
  State<ReportRangePage> createState() => _ReportRangePageState();
}

class _ReportRangePageState extends State<ReportRangePage> {
  late DateTime _startDate;
  late DateTime _endDate;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day);
  }

  /// Formata data para exibição (DD/MM/YYYY)
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Abre date picker para data de início
  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _errorMessage = null;
      });
    }
  }

  /// Abre date picker para data de fim
  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _errorMessage = null;
      });
    }
  }

  /// Valida intervalo e navega para relatório
  void _generateReport() {
    if (_startDate.isAfter(_endDate)) {
      setState(() {
        _errorMessage = 'Data de início deve ser antes ou igual à data de fim';
      });
      return;
    }

    Navigator.pop(context, {'startDate': _startDate, 'endDate': _endDate});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filtro de Relatório'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Título
            const Text(
              'Selecione o intervalo de datas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Data de início
            const Text(
              'Data de Início',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.date_range, color: Colors.blue),
                title: Text(_formatDate(_startDate)),
                onTap: _pickStartDate,
              ),
            ),
            const SizedBox(height: 24),

            // Data de fim
            const Text(
              'Data de Fim',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.date_range, color: Colors.blue),
                title: Text(_formatDate(_endDate)),
                onTap: _pickEndDate,
              ),
            ),
            const SizedBox(height: 24),

            // Mensagem de erro
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade400),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

            // Resumo do intervalo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Intervalo Selecionado:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_formatDate(_startDate)} até ${_formatDate(_endDate)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_endDate.difference(_startDate).inDays + 1} dia(s)',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Botão Gerar Relatório
            ElevatedButton(
              onPressed: _generateReport,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
              ),
              child: const Text(
                'Gerar Relatório',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

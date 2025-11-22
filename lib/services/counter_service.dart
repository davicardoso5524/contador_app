// lib/services/counter_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/counter.dart';
import '../models/event.dart';

class CounterService {
  static const _kCountersKey = 'counters_v1';
  static const _kEventsKey = 'events_v1';
  // Padrão de chave para sabores adicionais por data: 'more_flavors:YYYY-MM-DD:flavorId'
  static const _kMoreFlavorPrefix = 'more_flavors';

  final Uuid _uuid = const Uuid();

  List<CounterModel> _counters = [];
  List<CounterEvent> _events = [];

  // Cache para totais diários (evita recalcular frequentemente)
  final Map<String, Map<String, int>> _dateCache = {};

  static final CounterService _instance = CounterService._internal();
  factory CounterService() => _instance;
  CounterService._internal();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final countersJson = prefs.getString(_kCountersKey);
    final eventsJson = prefs.getString(_kEventsKey);

    if (countersJson != null) {
      final list = jsonDecode(countersJson) as List<dynamic>;
      _counters = list
          .map((e) => CounterModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _counters = [
        CounterModel(id: 'frango', name: 'Frango', value: 0),
        CounterModel(id: 'frango_bacon', name: 'Frango c/ Bacon', value: 0),
        CounterModel(id: 'carne_do_sol', name: 'Carne do Sol', value: 0),
        CounterModel(id: 'queijo', name: 'Queijo', value: 0),
        CounterModel(id: 'calabresa', name: 'Calabresa', value: 0),
        CounterModel(id: 'pizza', name: 'Pizza', value: 0),
      ];
      // salva sem passar o prefs para evitar warning de variável não usada
      await _saveCounters();
    }

    if (eventsJson != null) {
      final list = jsonDecode(eventsJson) as List<dynamic>;
      _events = list
          .map((e) => CounterEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _events = [];
      await _saveEvents();
    }
  }

  List<CounterModel> get counters => List.unmodifiable(_counters);
  List<CounterEvent> get events => List.unmodifiable(_events);

  Future<void> _saveCounters([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final encoded = jsonEncode(_counters.map((c) => c.toJson()).toList());
    await p.setString(_kCountersKey, encoded);
  }

  Future<void> _saveEvents([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final encoded = jsonEncode(_events.map((e) => e.toJson()).toList());
    await p.setString(_kEventsKey, encoded);
  }

  CounterModel? getById(String id) {
    return _counters.firstWhere(
      (c) => c.id == id,
      orElse: () => throw Exception('Counter not found: $id'),
    );
  }

  Future<void> addCounter(String name) async {
    final id = _uuid.v4();
    _counters.add(CounterModel(id: id, name: name, value: 0));
    await _saveCounters();
  }

  Future<void> removeCounter(String id) async {
    _counters.removeWhere((c) => c.id == id);
    await _saveCounters();
  }

  Future<void> editName(String id, String newName) async {
    final idx = _counters.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    _counters[idx] = _counters[idx].copyWith(name: newName);
    await _saveCounters();
  }

  /// Obtém a contagem de um sabor adicional (more_flavor) para uma data específica
  /// Padrão de chave: 'more_flavors:YYYY-MM-DD:flavorId'
  Future<int> getMoreFlavorCountForDate(String flavorId, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final dateStr = '$year-$month-$day';
    final key = '$_kMoreFlavorPrefix:$dateStr:$flavorId';
    return prefs.getInt(key) ?? 0;
  }

  /// Define a contagem de um sabor adicional (more_flavor) para uma data específica
  /// Padrão de chave: 'more_flavors:YYYY-MM-DD:flavorId'
  /// Limpa o cache ao modificar
  Future<void> setMoreFlavorCountForDate(
    String flavorId,
    DateTime date,
    int value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final dateStr = '$year-$month-$day';
    final key = '$_kMoreFlavorPrefix:$dateStr:$flavorId';

    // Garante que o valor não seja negativo
    final finalValue = value < 0 ? 0 : value;

    if (finalValue == 0) {
      // Se valor for 0, remove a chave para economizar espaço
      await prefs.remove(key);
    } else {
      await prefs.setInt(key, finalValue);
    }

    // Limpa cache pois houve mudanças
    _clearDateCache();
  }

  /// Aplica um delta a um sabor adicional para uma data específica
  /// Similar ao applyDelta para sabores originais
  Future<void> applyMoreFlavorDelta(
    String flavorId,
    int delta,
    DateTime date,
  ) async {
    if (delta == 0) return;

    final current = await getMoreFlavorCountForDate(flavorId, date);
    int newValue = current + delta;

    // Não permitir valor negativo: limita para 0
    if (newValue < 0) newValue = 0;

    await setMoreFlavorCountForDate(flavorId, date, newValue);
  }

  /// Aplica um delta ao contador identificado por [id].
  /// Se o delta for negativo e exceder o valor atual, ele será ajustado
  /// para apenas reduzir até 0 (não permite resultado negativo).
  /// O evento registrado terá o delta efetivamente aplicado.
  ///
  /// Se [date] for fornecido, o evento será registrado para aquela data
  /// (com timestamp no meio do dia). Se não for fornecido, usa DateTime.now().
  Future<void> applyDelta(String id, int delta, [DateTime? date]) async {
    if (delta == 0) return;
    final idx = _counters.indexWhere((c) => c.id == id);
    if (idx == -1) throw Exception('Counter not found');

    final current = _counters[idx].value;
    int newValue = current + delta;

    // Não permitir valor negativo: limita para 0
    if (newValue < 0) newValue = 0;

    final actualApplied = newValue - current;

    // Se nada foi aplicado (por exemplo tentativa de remover quando já está 0), não grava nem gera evento
    if (actualApplied == 0) return;

    _counters[idx] = _counters[idx].copyWith(value: newValue);

    // Usa a data fornecida ou DateTime.now()
    final eventDate = date ?? DateTime.now();
    // Define o timestamp para o meio do dia da data selecionada
    final eventTimestamp = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      12,
      0,
      0,
    ).millisecondsSinceEpoch;

    final event = CounterEvent(
      id: _uuid.v4(),
      counterId: id,
      delta: actualApplied,
      timestamp: eventTimestamp,
    );
    _events.add(event);

    // Limpa cache pois houve mudanças
    _clearDateCache();

    await Future.wait([_saveCounters(), _saveEvents()]);
  }

  Future<void> resetCounter(String id) async {
    final idx = _counters.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final delta = -_counters[idx].value;
    if (delta == 0) return;
    await applyDelta(id, delta);
  }

  Future<void> resetAll() async {
    for (var i = 0; i < _counters.length; i++) {
      _counters[i] = _counters[i].copyWith(value: 0);
    }
    await _saveCounters();
  }

  Map<String, int> totalsForDate(DateTime date) {
    final start = DateTime(
      date.year,
      date.month,
      date.day,
    ).millisecondsSinceEpoch;
    final end = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;

    final Map<String, int> totals = {};
    for (var c in _counters) {
      totals[c.id] = 0;
    }

    for (var e in _events) {
      if (e.timestamp >= start && e.timestamp <= end) {
        totals[e.counterId] = (totals[e.counterId] ?? 0) + e.delta;
      }
    }
    return totals;
  }

  Map<String, int> currentTotals() {
    final Map<String, int> totals = {};
    for (var c in _counters) {
      totals[c.id] = c.value;
    }
    return totals;
  }

  Map<String, int> totalsUpToDate(DateTime date) {
    final end = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;

    final Map<String, int> totals = {};
    for (var c in _counters) {
      totals[c.id] = 0;
    }

    for (var e in _events) {
      if (e.timestamp <= end) {
        totals[e.counterId] = (totals[e.counterId] ?? 0) + e.delta;
      }
    }
    return totals;
  }

  /// Totals for an inclusive date range: start..end (both inclusive)
  Map<String, int> totalsForRange(DateTime start, DateTime end) {
    // normalize to epoch ms (start beginning of day, end end of day)
    final s = DateTime(
      start.year,
      start.month,
      start.day,
    ).millisecondsSinceEpoch;
    final e = DateTime(
      end.year,
      end.month,
      end.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;

    final Map<String, int> totals = {};
    for (var c in _counters) {
      totals[c.id] = 0;
    }

    for (var ev in _events) {
      if (ev.timestamp >= s && ev.timestamp <= e) {
        totals[ev.counterId] = (totals[ev.counterId] ?? 0) + ev.delta;
      }
    }
    return totals;
  }

  /// Totals for a single date (start..end of that day), returns map counterId -> total
  /// Usa cache para evitar recálculos repetidos da mesma data
  /// Nota: Este método retorna apenas os sabores originais (não inclui more_flavors)
  /// Para incluir more_flavors, use totalsForSingleDateAsync
  Map<String, int> totalsForSingleDate(DateTime date) {
    final dateKey = '${date.year}-${date.month}-${date.day}';

    // Retorna do cache se disponível
    if (_dateCache.containsKey(dateKey)) {
      return Map.from(_dateCache[dateKey]!);
    }

    final start = DateTime(
      date.year,
      date.month,
      date.day,
    ).millisecondsSinceEpoch;
    final end = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;

    final Map<String, int> totals = {};
    for (var c in _counters) {
      totals[c.id] = 0;
    }

    for (var ev in _events) {
      if (ev.timestamp >= start && ev.timestamp <= end) {
        totals[ev.counterId] = (totals[ev.counterId] ?? 0) + ev.delta;
      }
    }

    // Armazena em cache para futuras consultas
    _dateCache[dateKey] = Map.from(totals);
    return totals;
  }

  /// Versão assíncrona que inclui sabores adicionais (more_flavors)
  /// Retorna todos os 10 sabores (6 originais + 4 adicionais)

  Future<Map<String, int>> totalsForSingleDateAsync(DateTime date) async {
    // Começa com os sabores originais
    final totals = totalsForSingleDate(date);

    // Adiciona os sabores adicionais
    const moreFlavorIds = ['churritos', 'doce-de-leite', 'chocolate', 'kibes'];

    for (final flavorId in moreFlavorIds) {
      final count = await getMoreFlavorCountForDate(flavorId, date);
      totals[flavorId] = count;
    }

    return totals;
  }

  /// Limpa o cache de datas (chamado após modificações)
  void _clearDateCache() => _dateCache.clear();

  /// Retorna totais por sabor para cada dia em um intervalo.
  /// Retorna `Map<DateTime, Map<String, int>>` onde:
  /// - DateTime é o dia (sem hora)
  /// - `Map<String, int>` é ID sabor -> quantidade naquele dia
  /// Nota: Este método retorna apenas os sabores originais
  /// Para incluir more_flavors, use totalsPerDayForRangeAsync
  Map<DateTime, Map<String, int>> totalsPerDayForRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    final result = <DateTime, Map<String, int>>{};

    // Itera cada dia no intervalo (inclusive start e end)
    DateTime current = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    while (!current.isAfter(end)) {
      result[current] = totalsForSingleDate(current);
      current = current.add(const Duration(days: 1));
    }

    return result;
  }

  /// Versão assíncrona que inclui sabores adicionais (more_flavors)
  /// Retorna todos os 10 sabores (6 originais + 4 adicionais) para cada dia
  Future<Map<DateTime, Map<String, int>>> totalsPerDayForRangeAsync(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final result = <DateTime, Map<String, int>>{};

    // Itera cada dia no intervalo (inclusive start e end)
    DateTime current = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    while (!current.isAfter(end)) {
      result[current] = await totalsForSingleDateAsync(current);
      current = current.add(const Duration(days: 1));
    }

    return result;
  }

  /// Retorna totais agregados (soma) por sabor para um intervalo de datas.
  /// Retorna `Map<String, int>` onde chave é ID sabor e valor é quantidade total
  /// Nota: Este método retorna apenas os sabores originais
  /// Para incluir more_flavors, use totalsSummaryForRangeAsync
  Map<String, int> totalsSummaryForRange(DateTime startDate, DateTime endDate) {
    final dailyTotals = totalsPerDayForRange(startDate, endDate);
    final summary = <String, int>{};

    // Inicializa todos os sabores com 0
    for (var c in _counters) {
      summary[c.id] = 0;
    }

    // Soma os totais de cada dia
    for (var dayTotals in dailyTotals.values) {
      dayTotals.forEach((id, count) {
        summary[id] = (summary[id] ?? 0) + count;
      });
    }

    return summary;
  }

  /// Versão assíncrona que inclui sabores adicionais (more_flavors)
  /// Retorna totais agregados para todos os 10 sabores
  Future<Map<String, int>> totalsSummaryForRangeAsync(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final dailyTotals = await totalsPerDayForRangeAsync(startDate, endDate);
    final summary = <String, int>{};

    // Inicializa todos os sabores (originais + adicionais) com 0
    for (var c in _counters) {
      summary[c.id] = 0;
    }
    const moreFlavorIds = ['churritos', 'doce-de-leite', 'chocolate', 'kibes'];
    for (final id in moreFlavorIds) {
      summary[id] = 0;
    }

    // Soma os totais de cada dia
    for (var dayTotals in dailyTotals.values) {
      dayTotals.forEach((id, count) {
        summary[id] = (summary[id] ?? 0) + count;
      });
    }

    return summary;
  }
}

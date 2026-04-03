// lib/services/counter_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/counter.dart';
import '../models/event.dart';

class CounterService {
  static const _kCountersKey = 'counters_v1';
  static const _kEventsKey = 'events_v1';
  static const _kMoreFlavorPrefix = 'more_flavors';

  final Uuid _uuid = const Uuid();

  List<CounterModel> _counters = [];
  List<CounterEvent> _events = [];

  // Cache para totais diários
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

  /// Obtém a contagem de um sabor adicional para uma data específica
  Future<int> getMoreFlavorCountForDate(String flavorId, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final key = '$_kMoreFlavorPrefix:$dateStr:$flavorId';
    return prefs.getInt(key) ?? 0;
  }

  /// Define a contagem de um sabor adicional para uma data específica
  Future<void> setMoreFlavorCountForDate(
    String flavorId,
    DateTime date,
    int value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final key = '$_kMoreFlavorPrefix:$dateStr:$flavorId';

    final finalValue = value < 0 ? 0 : value;

    if (finalValue == 0) {
      await prefs.remove(key);
    } else {
      await prefs.setInt(key, finalValue);
    }

    _clearDateCache();
  }

  /// Aplica um delta a um sabor adicional para uma data específica
  Future<void> applyMoreFlavorDelta(
    String flavorId,
    int delta,
    DateTime date,
  ) async {
    if (delta == 0) return;
    final current = await getMoreFlavorCountForDate(flavorId, date);
    int newValue = current + delta;
    if (newValue < 0) newValue = 0;
    await setMoreFlavorCountForDate(flavorId, date, newValue);
  }

  /// Aplica um delta ao contador identificado por [id].
  Future<void> applyDelta(String id, int delta, [DateTime? date]) async {
    if (delta == 0) return;
    final idx = _counters.indexWhere((c) => c.id == id);
    if (idx == -1) throw Exception('Counter not found');

    final current = _counters[idx].value;
    int newValue = current + delta;
    if (newValue < 0) newValue = 0;
    final actualApplied = newValue - current;
    if (actualApplied == 0) return;

    _counters[idx] = _counters[idx].copyWith(value: newValue);

    final eventDate = date ?? DateTime.now();
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

    _clearDateCache();
    await Future.wait([_saveCounters(), _saveEvents()]);
  }

  Future<void> resetAll() async {
    for (var i = 0; i < _counters.length; i++) {
      _counters[i] = _counters[i].copyWith(value: 0);
    }
    await _saveCounters();
  }

  /// Totals for a single date
  Map<String, int> totalsForSingleDate(DateTime date) {
    final dateKey = '${date.year}-${date.month}-${date.day}';
    if (_dateCache.containsKey(dateKey)) {
      return Map.from(_dateCache[dateKey]!);
    }

    final start = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999).millisecondsSinceEpoch;

    final Map<String, int> totals = {};
    for (var c in _counters) {
      totals[c.id] = 0;
    }

    for (var ev in _events) {
      if (ev.timestamp >= start && ev.timestamp <= end) {
        totals[ev.counterId] = (totals[ev.counterId] ?? 0) + ev.delta;
      }
    }

    _dateCache[dateKey] = Map.from(totals);
    return totals;
  }

  /// Versão assíncrona que inclui sabores adicionais
  Future<Map<String, int>> totalsForSingleDateAsync(DateTime date) async {
    final totals = totalsForSingleDate(date);
    const moreFlavorIds = ['churritos', 'doce-de-leite', 'chocolate', 'kibes', 'charque'];
    for (final flavorId in moreFlavorIds) {
      final count = await getMoreFlavorCountForDate(flavorId, date);
      totals[flavorId] = count;
    }
    return totals;
  }

  void _clearDateCache() => _dateCache.clear();

  /// Versão assíncrona que inclui sabores adicionais para cada dia no intervalo
  Future<Map<DateTime, Map<String, int>>> totalsPerDayForRangeAsync(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final result = <DateTime, Map<String, int>>{};
    DateTime current = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    while (!current.isAfter(end)) {
      result[current] = await totalsForSingleDateAsync(current);
      current = current.add(const Duration(days: 1));
    }
    return result;
  }

  /// Versão assíncrona que inclui sabores adicionais nos totais agregados
  Future<Map<String, int>> totalsSummaryForRangeAsync(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final dailyTotals = await totalsPerDayForRangeAsync(startDate, endDate);
    final summary = <String, int>{};

    for (var c in _counters) {
      summary[c.id] = 0;
    }
    const moreFlavorIds = ['churritos', 'doce-de-leite', 'chocolate', 'kibes', 'charque'];
    for (final id in moreFlavorIds) {
      summary[id] = 0;
    }

    for (var dayTotals in dailyTotals.values) {
      dayTotals.forEach((id, count) {
        summary[id] = (summary[id] ?? 0) + count;
      });
    }
    return summary;
  }
}

// lib/services/counter_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/counter.dart';
import '../models/event.dart';

class CounterService {
  static const _kCountersKey = 'counters_v1';
  static const _kEventsKey = 'events_v1';

  final Uuid _uuid = const Uuid();

  List<CounterModel> _counters = [];
  List<CounterEvent> _events = [];

  static final CounterService _instance = CounterService._internal();
  factory CounterService() => _instance;
  CounterService._internal();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final countersJson = prefs.getString(_kCountersKey);
    final eventsJson = prefs.getString(_kEventsKey);

    if (countersJson != null) {
      final list = jsonDecode(countersJson) as List<dynamic>;
      _counters = list.map((e) => CounterModel.fromJson(e as Map<String, dynamic>)).toList();
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
      _events = list.map((e) => CounterEvent.fromJson(e as Map<String, dynamic>)).toList();
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
    return _counters.firstWhere((c) => c.id == id, orElse: () => throw Exception('Counter not found: $id'));
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

  Future<void> applyDelta(String id, int delta) async {
    if (delta == 0) return;
    final idx = _counters.indexWhere((c) => c.id == id);
    if (idx == -1) throw Exception('Counter not found');

    final newValue = _counters[idx].value + delta;
    if (newValue < 0) {
      throw Exception('Result would be negative');
    }

    _counters[idx] = _counters[idx].copyWith(value: newValue);

    final event = CounterEvent(
      id: _uuid.v4(),
      counterId: id,
      delta: delta,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _events.add(event);

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
    final start = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999).millisecondsSinceEpoch;

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
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999).millisecondsSinceEpoch;

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
  Map<String,int> totalsForRange(DateTime start, DateTime end) {
    // normalize to epoch ms (start beginning of day, end end of day)
    final s = DateTime(start.year, start.month, start.day).millisecondsSinceEpoch;
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59, 999).millisecondsSinceEpoch;

    final Map<String,int> totals = {};
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
  Map<String,int> totalsForSingleDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999).millisecondsSinceEpoch;

    final Map<String,int> totals = {};
    for (var c in _counters) {
      totals[c.id] = 0;
    }

    for (var ev in _events) {
      if (ev.timestamp >= start && ev.timestamp <= end) {
        totals[ev.counterId] = (totals[ev.counterId] ?? 0) + ev.delta;
      }
    }
    return totals;
  }
}

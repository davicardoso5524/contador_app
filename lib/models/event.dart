// lib/models/event.dart
class CounterEvent {
  final String id; // event id
  final String counterId; // flavor id
  final int delta; // +N or -N
  final int timestamp; // epoch ms

  CounterEvent({
    required this.id,
    required this.counterId,
    required this.delta,
    required this.timestamp,
  });

  factory CounterEvent.fromJson(Map<String, dynamic> json) {
    return CounterEvent(
      id: json['id'] as String,
      counterId: json['counterId'] as String,
      delta: json['delta'] as int,
      timestamp: json['timestamp'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'counterId': counterId,
    'delta': delta,
    'timestamp': timestamp,
  };
}

// lib/models/counter.dart
class CounterModel {
  final String id;
  final String name;
  final int value;

  CounterModel({
    required this.id,
    required this.name,
    required this.value,
  });

  CounterModel copyWith({String? name, int? value}) {
    return CounterModel(
      id: id,
      name: name ?? this.name,
      value: value ?? this.value,
    );
  }

  factory CounterModel.fromJson(Map<String, dynamic> json) {
    return CounterModel(
      id: json['id'] as String,
      name: json['name'] as String,
      value: json['value'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'value': value,
  };
}

// lib/models/expiry_product.dart

class ExpiryProduct {
  final String id;
  final String name;
  final DateTime expiryDate;
  final int notifyDaysBefore; // 1, 7, 15, or 30
  final int quantity;

  ExpiryProduct({
    required this.id,
    required this.name,
    required this.expiryDate,
    required this.notifyDaysBefore,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'expiryDate': expiryDate.toIso8601String(),
      'notifyDaysBefore': notifyDaysBefore,
      'quantity': quantity,
    };
  }

  factory ExpiryProduct.fromJson(Map<String, dynamic> json) {
    return ExpiryProduct(
      id: json['id'],
      name: json['name'],
      expiryDate: DateTime.parse(json['expiryDate']),
      notifyDaysBefore: json['notifyDaysBefore'] ?? 1,
      quantity: json['quantity'] ?? 1,
    );
  }

  ExpiryProduct copyWith({
    String? id,
    String? name,
    DateTime? expiryDate,
    int? notifyDaysBefore,
    int? quantity,
  }) {
    return ExpiryProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      expiryDate: expiryDate ?? this.expiryDate,
      notifyDaysBefore: notifyDaysBefore ?? this.notifyDaysBefore,
      quantity: quantity ?? this.quantity,
    );
  }
}

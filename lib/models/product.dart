// lib/models/product.dart
// Modelo de dados para produtos do estoque
class Product {
  final String id;
  final String name;
  final String categoryId;
  final double price;
  final int quantity;
  final String? description;
  final String? imagePath;

  Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.price,
    required this.quantity,
    this.description,
    this.imagePath,
  });

  /// Cria um Product a partir de um mapa JSON
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      categoryId: json['categoryId'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int,
      description: json['description'] as String?,
      imagePath: json['imagePath'] as String?,
    );
  }

  /// Converte o Product para um mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'categoryId': categoryId,
      'price': price,
      'quantity': quantity,
      'description': description,
      'imagePath': imagePath,
    };
  }

  /// Retorna uma cópia do Product com alguns campos alterados
  Product copyWith({
    String? id,
    String? name,
    String? categoryId,
    double? price,
    int? quantity,
    String? description,
    String? imagePath,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, categoryId: $categoryId, '
        'price: $price, quantity: $quantity)';
  }
}

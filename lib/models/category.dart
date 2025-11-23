// lib/models/category.dart
// Modelo de dados para categorias do estoque
import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final int? colorValue; // Armazenar como int para persistência

  Category({required this.id, required this.name, this.colorValue});

  /// Retorna a cor da categoria como objeto Color
  Color? getColor() {
    if (colorValue == null) return null;
    return Color(colorValue!);
  }

  /// Cria uma Category a partir de um mapa JSON
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      colorValue: json['colorValue'] as int?,
    );
  }

  /// Converte a Category para um mapa JSON
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'colorValue': colorValue};
  }

  /// Retorna uma cópia da Category com alguns campos alterados
  Category copyWith({String? id, String? name, int? colorValue}) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  @override
  String toString() => 'Category(id: $id, name: $name)';
}

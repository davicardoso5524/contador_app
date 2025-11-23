// lib/services/inventory_service.dart
// Serviço para gerenciar CRUD de produtos e categorias com persistência em SharedPreferences
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../models/category.dart';

class InventoryService {
  late SharedPreferences _prefs;
  static const String _productsKey = 'inventory:products';
  static const String _categoriesKey = 'inventory:categories';

  List<Product> _cachedProducts = [];
  List<Category> _cachedCategories = [];

  /// Inicializa o serviço e carrega dados do SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadProducts();
    await _loadCategories();
  }

  /// Carrega produtos do SharedPreferences para cache
  Future<void> _loadProducts() async {
    try {
      final json = _prefs.getString(_productsKey);
      if (json != null && json.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(json);
        _cachedProducts = decoded
            .map((item) => Product.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        _cachedProducts = [];
      }
    } catch (e) {
      _cachedProducts = [];
    }
  }

  /// Carrega categorias do SharedPreferences para cache
  Future<void> _loadCategories() async {
    try {
      final json = _prefs.getString(_categoriesKey);
      if (json != null && json.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(json);
        _cachedCategories = decoded
            .map((item) => Category.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        _cachedCategories = [];
      }
    } catch (e) {
      _cachedCategories = [];
    }
  }

  /// Persiste todos os produtos no SharedPreferences
  Future<void> _persistProducts() async {
    try {
      final jsonList = _cachedProducts.map((p) => p.toJson()).toList();
      await _prefs.setString(_productsKey, jsonEncode(jsonList));
    } catch (e) {
      // Erro ignorado
    }
  }

  /// Persiste todas as categorias no SharedPreferences
  Future<void> _persistCategories() async {
    try {
      final jsonList = _cachedCategories.map((c) => c.toJson()).toList();
      await _prefs.setString(_categoriesKey, jsonEncode(jsonList));
    } catch (e) {
      // Erro ignorado
    }
  }

  /// Retorna todos os produtos
  Future<List<Product>> getAllProducts() async {
    return List.from(_cachedProducts);
  }

  /// Retorna todos os produtos de uma categoria específica
  Future<List<Product>> getProductsByCategory(String categoryId) async {
    return _cachedProducts.where((p) => p.categoryId == categoryId).toList();
  }

  /// Retorna um produto pelo ID
  Future<Product?> getProductById(String id) async {
    try {
      return _cachedProducts.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Cria um novo produto com ID gerado automaticamente
  Future<Product> createProduct(Product product) async {
    // Gera um ID se não tiver
    final id = product.id.isEmpty ? const Uuid().v4() : product.id;
    final newProduct = product.copyWith(id: id);
    _cachedProducts.add(newProduct);
    await _persistProducts();
    return newProduct;
  }

  /// Atualiza um produto existente
  Future<void> updateProduct(Product product) async {
    final index = _cachedProducts.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _cachedProducts[index] = product;
      await _persistProducts();
    }
  }

  /// Deleta um produto pelo ID
  Future<void> deleteProduct(String id) async {
    _cachedProducts.removeWhere((p) => p.id == id);
    await _persistProducts();
  }

  /// Retorna todas as categorias
  Future<List<Category>> getAllCategories() async {
    return List.from(_cachedCategories);
  }

  /// Retorna uma categoria pelo ID
  Future<Category?> getCategoryById(String id) async {
    try {
      return _cachedCategories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Cria uma nova categoria com ID gerado automaticamente
  Future<Category> createCategory(Category category) async {
    // Gera um ID se não tiver
    final id = category.id.isEmpty ? const Uuid().v4() : category.id;
    final newCategory = category.copyWith(id: id);
    _cachedCategories.add(newCategory);
    await _persistCategories();
    return newCategory;
  }

  /// Atualiza uma categoria existente
  Future<void> updateCategory(Category category) async {
    final index = _cachedCategories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      _cachedCategories[index] = category;
      await _persistCategories();
    }
  }

  /// Deleta uma categoria pelo ID
  /// Nota: Deveria ser tratado que produtos de uma categoria deletada precisam de reatribuição
  Future<void> deleteCategory(String id) async {
    _cachedCategories.removeWhere((c) => c.id == id);
    await _persistCategories();
  }

  /// Limpa todo o cache (útil para testes ou reset)
  Future<void> clearAll() async {
    _cachedProducts.clear();
    _cachedCategories.clear();
    await _prefs.remove(_productsKey);
    await _prefs.remove(_categoriesKey);
  }
}

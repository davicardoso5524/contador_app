// lib/services/inventory_service.dart
// Serviço para gerenciar CRUD de produtos e categorias com persistência em SharedPreferences
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../models/category.dart';
import 'counter_service.dart';

class InventoryService {
  late SharedPreferences _prefs;
  static const String _productsKey = 'inventory:products';
  static const String _categoriesKey = 'inventory:categories';

  // inventory:movements:YYYY-MM-DD → JSON array { productId, name, qtyBefore, qtyDelta, qtyAfter, unmatched }
  // inventory:deducted:YYYY-MM-DD → boolean
  // inventory:autoApply → boolean
  // Observação: Para integração futura com Firestore, trocar persistência abaixo

  List<Product> _cachedProducts = [];
  List<Category> _cachedCategories = [];

  // Singleton pattern para evitar múltiplas instâncias
  static final InventoryService _instance = InventoryService._internal();
  bool _initialized = false;

  factory InventoryService() {
    return _instance;
  }

  InventoryService._internal();

  /// Inicializa o serviço, carrega dados do SharedPreferences e sincroniza com CounterService
  /// Utiliza flag _initialized para evitar múltiplas inicializações
  Future<void> init() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();
    await _loadCategories();
    await _loadProducts();

    // Sincroniza produtos com CounterService (cria default category se necessário)
    await _syncProductsWithCounterService();

    _initialized = true;
  }

  /// Sincroniza produtos da aplicação com os counters do CounterService
  /// Garante que cada counter tenha um produto correspondente no inventário
  Future<void> _syncProductsWithCounterService() async {
    try {
      // Cria categoria "Sem categoria" se não existir
      const uncategorizedId = 'uncategorized';
      final uncategorizedExists = _cachedCategories.any(
        (c) => c.id == uncategorizedId,
      );

      if (!uncategorizedExists) {
        _cachedCategories.add(
          Category(
            id: uncategorizedId,
            name: 'Sem categoria',
            colorValue: null,
          ),
        );
        await _persistCategories();
      }

      // Sincroniza produtos a partir dos counters
      final counterService = CounterService();
      await counterService.init();
      final counters = counterService.counters;

      // Para cada counter, cria um produto se não existir
      bool hasChanges = false;
      for (final counter in counters) {
        final productExists = _cachedProducts.any((p) => p.id == counter.id);

        if (!productExists) {
          _cachedProducts.add(
            Product(
              id: counter.id,
              name: counter.name,
              categoryId: uncategorizedId,
              price: 0.0,
              quantity: 0,
              description: 'Produto originário do contador',
              imagePath: null,
            ),
          );
          hasChanges = true;
        }
      }

      // Adiciona os "Mais Sabores" como produtos padrão também
      final moreFlavorIds = {
        'churritos': 'Churritos',
        'doce-de-leite': 'Doce de Leite',
        'chocolate': 'Chocolate',
        'kibes': 'Kibes',
      };

      for (final entry in moreFlavorIds.entries) {
        final productExists = _cachedProducts.any((p) => p.id == entry.key);

        if (!productExists) {
          _cachedProducts.add(
            Product(
              id: entry.key,
              name: entry.value,
              categoryId: uncategorizedId,
              price: 0.0,
              quantity: 0,
              description: 'Sabor adicional',
              imagePath: null,
            ),
          );
          hasChanges = true;
        }
      }

      if (hasChanges) {
        await _persistProducts();
      }
    } catch (e) {
      // Erro ignorado na sincronização
    }
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

  // ==================== MÉTODOS DE DEDUCÇÃO DE ESTOQUE ====================

  /// Aplica as vendas diárias ao estoque baseado na data fornecida.
  ///
  /// Fluxo:
  /// 1. Verifica se já foi aplicado para esta data (isDailyDeductionApplied)
  /// 2. Chama CounterService.totalsForSingleDateAsync(date) para obter todas as vendas
  /// 3. Para cada venda (flavorId, qty):
  ///    - Converte flavorId para flavorName usando mapa de nomes
  ///    - Procura produto com product.name == flavorName (case-insensitive, com trim)
  ///    - Se encontrado, subtrai qty do product.quantity (mínimo 0)
  ///    - Registra movimento: { productId, name, qtyBefore, qtyDelta, qtyAfter, unmatched }
  /// 4. Salva produtos atualizados
  /// 5. Salva movimentos em inventory:movements:YYYY-MM-DD
  /// 6. Marca data como aplicada em inventory:deducted:YYYY-MM-DD
  ///
  /// Retorna lista de movimentos efetivamente aplicados.
  /// Se já foi aplicado, retorna lista vazia.
  Future<List<Map<String, dynamic>>> applyDailySalesToStock(
    DateTime date, {
    bool matchByName = true,
  }) async {
    // Verifica se já foi aplicado
    final alreadyApplied = await isDailyDeductionApplied(date);
    if (alreadyApplied) {
      return [];
    }

    final movements = <Map<String, dynamic>>[];
    final counterService = CounterService();
    await counterService.init();

    try {
      // Obtém todas as vendas do dia (6 sabores originais + 4 adicionais)
      final dailySales = await counterService.totalsForSingleDateAsync(date);

      // Mapa de ID/Nome para nome do sabor (para conversão)
      const flavorMap = {
        'frango': 'Frango',
        'frango_bacon': 'Frango c/ Bacon',
        'carne_do_sol': 'Carne do Sol',
        'queijo': 'Queijo',
        'calabresa': 'Calabresa',
        'pizza': 'Pizza',
        'churritos': 'Churritos',
        'doce-de-leite': 'Doce de Leite',
        'chocolate': 'Chocolate',
        'kibes': 'Kibes',
      };

      // Processa cada sabor vendido
      for (final entry in dailySales.entries) {
        final flavorId = entry.key;
        final qty = entry.value;

        if (qty == 0) continue; // Pula se não teve venda

        // Converte flavorId para flavorName
        final flavorName = flavorMap[flavorId];
        if (flavorName == null) {
          movements.add({
            'flavorId': flavorId,
            'qty': qty,
            'unmatched': true,
            'reason': 'Sabor não mapeado',
          });
          continue;
        }

        // Procura produto com nome igual (case-insensitive)
        final product = _cachedProducts.firstWhere(
          (p) => p.name.toLowerCase().trim() == flavorName.toLowerCase().trim(),
          orElse: () => Product(
            id: '',
            name: '',
            categoryId: '',
            price: 0.0,
            quantity: 0,
          ),
        );

        if (product.id.isEmpty) {
          // Produto não encontrado
          movements.add({
            'flavorId': flavorId,
            'name': flavorName,
            'qty': qty,
            'unmatched': true,
            'reason': 'Produto não encontrado no estoque',
          });
          continue;
        }

        // Deduz a quantidade do estoque
        final qtyBefore = product.quantity;
        final newQty = (product.quantity - qty)
            .clamp(0, double.infinity)
            .toInt();
        final qtyDelta = -(qty); // Negativo porque é uma dedução

        _cachedProducts[_cachedProducts.indexOf(product)] = product.copyWith(
          quantity: newQty,
        );

        movements.add({
          'productId': product.id,
          'name': product.name,
          'qtyBefore': qtyBefore,
          'qtyDelta': qtyDelta,
          'qtyAfter': newQty,
          'unmatched': false,
        });
      }

      // Salva produtos atualizados
      await _persistProducts();

      // Salva movimentos
      await _saveMovements(date, movements);

      // Marca como aplicado
      await markDailyDeduction(date, true);

      return movements;
    } catch (e) {
      rethrow;
    }
  }

  /// Reverte a deducção de vendas para uma data específica.
  ///
  /// Fluxo:
  /// 1. Lê movimentos gravados para a data
  /// 2. Para cada movimento: restaura product.quantity = qtyBefore
  /// 3. Salva produtos atualizados
  /// 4. Remove/marca movimentos como revertidos
  /// 5. Marca data como não aplicada (inventory:deducted:YYYY-MM-DD = false)
  Future<void> revertDailySalesForDate(DateTime date) async {
    final movements = await getDailyStockMovements(date);

    if (movements.isEmpty) {
      return;
    }

    try {
      for (final movement in movements) {
        // Pula movimentos unmatched (não afetam o estoque)
        if (movement['unmatched'] == true) {
          continue;
        }

        final productId = movement['productId'] as String;
        final qtyBefore = movement['qtyBefore'] as int;

        // Localiza e restaura o produto
        final productIndex = _cachedProducts.indexWhere(
          (p) => p.id == productId,
        );
        if (productIndex != -1) {
          final product = _cachedProducts[productIndex];
          _cachedProducts[productIndex] = product.copyWith(quantity: qtyBefore);
        }
      }

      // Salva produtos restaurados
      await _persistProducts();

      // Remove movimentos (apaga a entrada)
      await _removeMovements(date);

      // Marca como não aplicado
      await markDailyDeduction(date, false);
    } catch (e) {
      rethrow;
    }
  }

  /// Verifica se a deducção já foi aplicada para uma data.
  /// Retorna true se foi aplicada, false caso contrário.
  Future<bool> isDailyDeductionApplied(DateTime date) async {
    final key = 'inventory:deducted:${_formatDate(date)}';
    return _prefs.getBool(key) ?? false;
  }

  /// Marca uma data como aplicada ou não aplicada.
  /// Se [applied] for true, marca que a deducção foi realizada.
  /// Se [applied] for false, marca que a deducção não foi realizada (reversão).
  Future<void> markDailyDeduction(DateTime date, bool applied) async {
    final key = 'inventory:deducted:${_formatDate(date)}';
    if (applied) {
      await _prefs.setBool(key, true);
    } else {
      // Remove a flag se for false (para economizar espaço)
      await _prefs.remove(key);
    }
  }

  /// Retorna lista de movimentos para uma data específica.
  /// Cada movimento contém: { productId, name, qtyBefore, qtyDelta, qtyAfter, unmatched }
  Future<List<Map<String, dynamic>>> getDailyStockMovements(
    DateTime date,
  ) async {
    final key = 'inventory:movements:${_formatDate(date)}';
    final json = _prefs.getString(key);

    if (json == null || json.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(json);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Salva movimentos para uma data (sobrescreve movimentos anteriores).
  /// [movements] é lista de { productId, name, qtyBefore, qtyDelta, qtyAfter, unmatched }
  Future<void> _saveMovements(
    DateTime date,
    List<Map<String, dynamic>> movements,
  ) async {
    final key = 'inventory:movements:${_formatDate(date)}';
    try {
      await _prefs.setString(key, jsonEncode(movements));
    } catch (e) {
      rethrow;
    }
  }

  /// Remove movimentos gravados para uma data.
  Future<void> _removeMovements(DateTime date) async {
    final key = 'inventory:movements:${_formatDate(date)}';
    try {
      await _prefs.remove(key);
    } catch (e) {
      rethrow;
    }
  }

  /// Formata DateTime como YYYY-MM-DD para uso em chaves
  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // ==================== FIM DOS MÉTODOS DE DEDUCÇÃO ====================

  /// Limpa todo o cache (útil para testes ou reset)
  Future<void> clearAll() async {
    _cachedProducts.clear();
    _cachedCategories.clear();
    await _prefs.remove(_productsKey);
    await _prefs.remove(_categoriesKey);
  }
}

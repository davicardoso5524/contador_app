// lib/pages/stock_page.dart
// Tela de gerenciamento de estoque com listagem, filtro por categorias e CRUD de produtos
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../services/inventory_service.dart';
import 'product_editor_page.dart';
import 'category_editor_page.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> with TickerProviderStateMixin {
  final InventoryService _inventoryService = InventoryService();
  List<Product> _allProducts = [];
  List<Category> _categories = [];
  List<Product> _filteredProducts = [];
  String _selectedCategoryId = 'all';
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _inventoryService.init();
    final products = await _inventoryService.getAllProducts();
    final categories = await _inventoryService.getAllCategories();

    if (!mounted) return;
    setState(() {
      _allProducts = products;
      _categories = categories;
      _filterProducts();
      _loading = false;
    });
  }

  void _filterProducts() {
    if (_selectedCategoryId == 'all') {
      _filteredProducts = List.from(_allProducts);
    } else {
      _filteredProducts = _allProducts
          .where((p) => p.categoryId == _selectedCategoryId)
          .toList();
    }
  }

  Future<void> _openProductEditor({Product? product}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductEditorPage(product: product)),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deletar Produto?'),
        content: Text('Tem certeza que deseja deletar "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deletar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _inventoryService.deleteProduct(product.id);
      _loadData();
    }
  }

  Future<void> _openCategoryEditor({Category? category}) async {
    final result = await Navigator.of(context).push<Category>(
      MaterialPageRoute(builder: (_) => CategoryEditorPage(category: category)),
    );

    // Se uma categoria foi criada ou editada, recarrega dados
    if (result != null) {
      _loadData();
    }
  }

  Future<void> _deleteCategory(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deletar Categoria?'),
        content: Text(
          'Tem certeza que deseja deletar "${category.name}"? '
          'Os produtos não serão deletados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Deletar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _inventoryService.deleteCategory(category.id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estoque'),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Produtos', icon: Icon(Icons.shopping_bag)),
            Tab(text: 'Categorias', icon: Icon(Icons.category)),
            Tab(text: 'Movimentos', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Aba 1: Produtos
                _buildProductsTab(),
                // Aba 2: Categorias
                _buildCategoriesTab(),
                // Aba 3: Movimentos
                _buildMovementsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openProductEditor(),
        tooltip: 'Adicionar Produto',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Constrói a aba de Produtos
  Widget _buildProductsTab() {
    return SafeArea(
      child: Column(
        children: [
          // Filtro por categorias
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                _buildCategoryChip(
                  label: 'Todos',
                  isSelected: _selectedCategoryId == 'all',
                  onTap: () {
                    setState(() {
                      _selectedCategoryId = 'all';
                      _filterProducts();
                    });
                  },
                ),
                const SizedBox(width: 8),
                ..._categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildCategoryChip(
                      label: category.name,
                      isSelected: _selectedCategoryId == category.id,
                      backgroundColor: category.getColor(),
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = category.id;
                          _filterProducts();
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // Grid de produtos
          if (_filteredProducts.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Nenhum produto encontrado',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = _filteredProducts[index];
                  // RepaintBoundary melhora performance ao isolar repaints
                  return RepaintBoundary(child: _buildProductCard(product));
                },
                // Addons para performance
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
              ),
            ),
        ],
      ),
    );
  }

  /// Constrói a aba de Categorias (gerenciamento de categorias)
  Widget _buildCategoriesTab() {
    return SafeArea(
      child: _categories.isEmpty
          ? const Center(
              child: Text(
                'Nenhuma categoria criada',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: category.getColor(),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    title: Text(category.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteCategory(category),
                    ),
                    onTap: () => _openCategoryEditor(category: category),
                  ),
                );
              },
            ),
    );
  }

  /// Constrói a aba de Movimentos (histórico de deduções)
  Widget _buildMovementsTab() {
    return FutureBuilder<List<DateTime>>(
      future: _getMovementDates(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final dates = snapshot.data ?? [];

        if (dates.isEmpty) {
          return const Center(
            child: Text(
              'Nenhum movimento registrado',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: dates.length,
          itemBuilder: (context, index) {
            final date = dates[index];
            return _buildMovementTile(date);
          },
        );
      },
    );
  }

  /// Carrega todas as datas que têm movimentos registrados
  Future<List<DateTime>> _getMovementDates() async {
    // Procura por chaves de movimento nos últimos 30 dias
    final dates = <DateTime>[];
    final now = DateTime.now();

    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final movements = await _inventoryService.getDailyStockMovements(date);
      if (movements.isNotEmpty) {
        dates.add(date);
      }
    }

    return dates.toList();
  }

  /// Constrói um card de movimento para uma data
  Widget _buildMovementTile(DateTime date) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _inventoryService.getDailyStockMovements(date),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final movements = snapshot.data ?? [];
        final matchedMovements = movements
            .where((m) => m['unmatched'] != true)
            .toList();
        final unmatchedCount = movements
            .where((m) => m['unmatched'] == true)
            .length;

        // Calcula totais
        int totalSubtracted = 0;
        for (final m in matchedMovements) {
          totalSubtracted += (m['qtyDelta'] as int?)?.abs() ?? 0;
        }

        final dateFormatted = _formatDate(date);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateFormatted,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${matchedMovements.length} produto(s) - '
                          'Total: $totalSubtracted un.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                        if (unmatchedCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '⚠️ $unmatchedCount não encontrado(s)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showRevertDialog(date),
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Reverter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[100],
                        foregroundColor: Colors.red[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Lista resumida dos produtos afetados
                if (matchedMovements.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: matchedMovements.take(3).map((m) {
                        final name = m['name'] as String? ?? 'Desconhecido';
                        final delta = m['qtyDelta'] as int? ?? 0;
                        return Text(
                          '  • $name: $delta un.',
                          style: const TextStyle(fontSize: 12),
                        );
                      }).toList(),
                    ),
                  ),
                if (matchedMovements.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '  ... e ${matchedMovements.length - 3} mais',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Mostra diálogo de confirmação para reverter
  Future<void> _showRevertDialog(DateTime date) async {
    final dateFormatted = _formatDate(date);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reverter Movimentos?'),
        content: Text(
          'Tem certeza que deseja reverter a deducção de $dateFormatted? '
          'Os estoques serão restaurados aos valores anteriores.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Reverter',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _inventoryService.revertDailySalesForDate(date);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deducção de $dateFormatted foi revertida com sucesso!',
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        // Recarrega dados
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao reverter: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Formata data como dd/MM/yyyy
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    Color? backgroundColor,
    required VoidCallback onTap,
  }) {
    final bgColor = backgroundColor ?? Colors.blue[300];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final isOutOfStock = product.quantity == 0;
    final category = _categories.firstWhere(
      (c) => c.id == product.categoryId,
      orElse: () => Category(id: '', name: 'Sem categoria'),
    );

    return InkWell(
      onTap: () => _openProductEditor(product: product),
      onLongPress: () => _deleteProduct(product),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isOutOfStock
                ? Border.all(color: Colors.red[300]!, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header com categoria
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: category.getColor() ?? Colors.blue[100],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                width: double.infinity,
                child: Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Conteúdo do card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome do produto
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Descrição (opcional)
                      if (product.description != null &&
                          product.description!.isNotEmpty)
                        Text(
                          product.description!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                      const Spacer(),
                    ],
                  ),
                ),
              ),

              // Footer com quantidade
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isOutOfStock ? Colors.red[50] : Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isOutOfStock)
                      const Text(
                        'Esgotado',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      )
                    else
                      Text(
                        'Qtd: ${product.quantity}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    Icon(Icons.edit, size: 14, color: Colors.blue[400]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

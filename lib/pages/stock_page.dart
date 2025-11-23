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

class _StockPageState extends State<StockPage> {
  final InventoryService _inventoryService = InventoryService();
  List<Product> _allProducts = [];
  List<Category> _categories = [];
  List<Product> _filteredProducts = [];
  String _selectedCategoryId = 'all';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  Future<void> _openCategoryEditor() async {
    final result = await Navigator.of(context).push<Category>(
      MaterialPageRoute(builder: (_) => const CategoryEditorPage()),
    );

    // Se uma categoria foi criada, recarrega dados
    if (result != null) {
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
        actions: [
          IconButton(
            onPressed: _openCategoryEditor,
            icon: const Icon(Icons.category),
            tooltip: 'Criar Categoria',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Filtro por categorias
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
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
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.75,
                            ),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          // RepaintBoundary melhora performance ao isolar repaints
                          return RepaintBoundary(
                            child: _buildProductCard(product),
                          );
                        },
                        // Addons para performance
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: false,
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openProductEditor(),
        tooltip: 'Adicionar Produto',
        child: const Icon(Icons.add),
      ),
    );
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

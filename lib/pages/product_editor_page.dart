// lib/pages/product_editor_page.dart
// Página para criar/editar produtos com formulário e validações
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../services/inventory_service.dart';
import 'category_editor_page.dart';

class ProductEditorPage extends StatefulWidget {
  final Product? product; // Se null, é criação; se preenchido, é edição

  const ProductEditorPage({super.key, this.product});

  @override
  State<ProductEditorPage> createState() => _ProductEditorPageState();
}

class _ProductEditorPageState extends State<ProductEditorPage> {
  final InventoryService _inventoryService = InventoryService();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  late TextEditingController _descriptionController;
  late TextEditingController _imagePathController;

  List<Category> _categories = [];
  String? _selectedCategoryId;
  bool _loading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _priceController = TextEditingController(
      text: widget.product?.price.toString() ?? '',
    );
    _quantityController = TextEditingController(
      text: widget.product?.quantity.toString() ?? '0',
    );
    _descriptionController = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _imagePathController = TextEditingController(
      text: widget.product?.imagePath ?? '',
    );
    _selectedCategoryId = widget.product?.categoryId;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    await _inventoryService.init();
    final categories = await _inventoryService.getAllCategories();

    if (!mounted) return;
    setState(() {
      _categories = categories;
      // Se não há categoria selecionada e há categorias disponíveis, seleciona a primeira
      if (_selectedCategoryId == null && categories.isNotEmpty) {
        _selectedCategoryId = categories.first.id;
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    _imagePathController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    // Validações
    if (_nameController.text.trim().isEmpty) {
      _showError('Nome do produto é obrigatório');
      return;
    }

    if (_priceController.text.trim().isEmpty) {
      _showError('Preço é obrigatório');
      return;
    }

    final price = double.tryParse(_priceController.text);
    if (price == null || price < 0) {
      _showError('Preço deve ser um número válido >= 0');
      return;
    }

    // Se não houver categorias, usa categoria default
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      _selectedCategoryId = 'uncategorized';
    }

    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity < 0) {
      _showError('Quantidade deve ser um número inteiro >= 0');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final product = Product(
        id: widget.product?.id ?? '',
        name: _nameController.text.trim(),
        categoryId: _selectedCategoryId!,
        price: price,
        quantity: quantity,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        imagePath: _imagePathController.text.trim().isEmpty
            ? null
            : _imagePathController.text.trim(),
      );

      if (widget.product == null) {
        // Criar novo produto
        await _inventoryService.createProduct(product);
      } else {
        // Atualizar produto existente
        await _inventoryService.updateProduct(product);
      }

      if (!mounted) return;
      Navigator.pop(context, true); // Retorna true indicando que dados mudaram
    } catch (e) {
      _showError('Erro ao salvar produto: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openCategoryEditor() async {
    final result = await Navigator.of(context).push<Category>(
      MaterialPageRoute(builder: (_) => const CategoryEditorPage()),
    );

    // Se uma categoria foi criada, recarrega a lista e seleciona a nova
    if (result != null) {
      await _loadCategories();
      if (mounted) {
        setState(() {
          _selectedCategoryId = result.id;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    final title = isEditing ? 'Editar Produto' : 'Novo Produto';

    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Nome
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nome do Produto *',
                        hintText: 'Ex: Coxinha de Frango',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // Categoria
                    if (_categories.isEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning, color: Colors.orange),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Nenhuma categoria criada. Crie uma categoria agora.',
                                    style: TextStyle(color: Colors.orange),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _openCategoryEditor,
                            icon: const Icon(Icons.add),
                            label: const Text('Criar Categoria'),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCategoryId,
                            items: _categories
                                .map(
                                  (category) => DropdownMenuItem(
                                    value: category.id,
                                    child: Text(category.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() => _selectedCategoryId = value);
                            },
                            decoration: InputDecoration(
                              labelText: 'Categoria',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _openCategoryEditor,
                            icon: const Icon(Icons.add),
                            label: const Text('Criar nova categoria'),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),

                    // Preço
                    TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Preço (R\$) *',
                        hintText: '0.00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // Quantidade
                    TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantidade *',
                        hintText: '0',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // Descrição (opcional)
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Descrição (opcional)',
                        hintText: 'Ex: Deliciosa coxinha caseira',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      maxLines: 3,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // Caminho da Imagem (opcional)
                    TextField(
                      controller: _imagePathController,
                      decoration: InputDecoration(
                        labelText: 'Caminho da Imagem (opcional)',
                        hintText: 'Ex: assets/images/coxinha.png',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 24),

                    // Botões de ação
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _saveProduct,
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(isEditing ? 'Atualizar' : 'Criar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

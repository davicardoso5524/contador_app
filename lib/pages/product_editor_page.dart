// lib/pages/product_editor_page.dart
// Página para criar/editar produtos com formulário e validações
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
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
  late TextEditingController _quantityController;
  late TextEditingController _descriptionController;
  final ImagePicker _imagePicker = ImagePicker();

  List<Category> _categories = [];
  String? _selectedCategoryId;
  String? _selectedImagePath;
  bool _loading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _quantityController = TextEditingController(
      text: widget.product?.quantity.toString() ?? '0',
    );
    _descriptionController = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _selectedImagePath = widget.product?.imagePath;
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
    _quantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    // Validações
    if (_nameController.text.trim().isEmpty) {
      _showError('Nome do produto é obrigatório');
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
        price: 0.0,
        quantity: quantity,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        imagePath: _selectedImagePath,
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

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // Copia a imagem para o diretório de aplicação
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory('${appDir.path}/product_images');
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
        final savedImage = await File(
          pickedFile.path,
        ).copy('${imagesDir.path}/$fileName');

        if (mounted) {
          setState(() {
            _selectedImagePath = savedImage.path;
          });
        }
      }
    } catch (e) {
      _showError('Erro ao selecionar imagem: $e');
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImagePath = null;
    });
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

                    // Seleção de Imagem (opcional)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Imagem do Produto (opcional)',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        if (_selectedImagePath != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(_selectedImagePath!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _pickImage,
                                      icon: const Icon(Icons.image),
                                      label: const Text('Trocar Imagem'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _clearImage,
                                    icon: const Icon(Icons.close),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    label: const Text('Remover'),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.add_photo_alternate),
                            label: const Text('Selecionar Imagem'),
                          ),
                      ],
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

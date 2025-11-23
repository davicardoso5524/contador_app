// lib/pages/category_editor_page.dart
// Página para criar/editar categorias com formulário simples
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/inventory_service.dart';

class CategoryEditorPage extends StatefulWidget {
  final Category? category; // Se null, é criação; se preenchido, é edição

  const CategoryEditorPage({super.key, this.category});

  @override
  State<CategoryEditorPage> createState() => _CategoryEditorPageState();
}

class _CategoryEditorPageState extends State<CategoryEditorPage> {
  final InventoryService _inventoryService = InventoryService();
  late TextEditingController _nameController;
  Color? _selectedColor;
  bool _isSubmitting = false;

  final List<Color> _colorOptions = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lime,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    if (widget.category?.colorValue != null) {
      _selectedColor = Color(widget.category!.colorValue!);
    } else {
      _selectedColor = Colors.blue;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Nome da categoria é obrigatório');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final category = Category(
        id: widget.category?.id ?? '',
        name: _nameController.text.trim(),
        colorValue: _selectedColor?.toARGB32(),
      );

      if (widget.category == null) {
        // Criar nova categoria
        final newCategory = await _inventoryService.createCategory(category);
        if (!mounted) return;
        Navigator.pop(context, newCategory); // Retorna a categoria criada
      } else {
        // Atualizar categoria existente
        await _inventoryService.updateCategory(category);
        if (!mounted) return;
        Navigator.pop(context, category);
      }
    } catch (e) {
      _showError('Erro ao salvar categoria: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteCategory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deletar Categoria?'),
        content: Text(
          'Tem certeza que deseja deletar "${widget.category!.name}"? '
          'Os produtos desta categoria não serão deletados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Deletar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSubmitting = true);

      try {
        await _inventoryService.deleteCategory(widget.category!.id);
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Categoria deletada com sucesso!'),
            duration: Duration(seconds: 2),
          ),
        );
        
        Navigator.pop(context); // Volta sem retornar nada
      } catch (e) {
        _showError('Erro ao deletar categoria: $e');
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;
    final title = isEditing ? 'Editar Categoria' : 'Nova Categoria';

    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nome
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nome da Categoria *',
                  hintText: 'Ex: Bebidas, Doces, Salgados',
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
              const SizedBox(height: 24),

              // Seletor de Cor
              Text(
                'Cor (opcional)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _colorOptions.length,
                itemBuilder: (context, index) {
                  final color = _colorOptions[index];
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedColor = color);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Center(
                              child: Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 24,
                              ),
                            )
                          : null,
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Botões de ação
              if (isEditing)
                // Se está editando, mostra botão de deletar em cima
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _deleteCategory,
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text(
                      'Deletar Categoria',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
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
                      onPressed: _isSubmitting ? null : _saveCategory,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
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

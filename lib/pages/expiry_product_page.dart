// lib/pages/expiry_product_page.dart
import 'package:flutter/material.dart';
import '../models/expiry_product.dart';
import '../services/expiry_service.dart';
import 'package:intl/intl.dart';

class ExpiryProductPage extends StatefulWidget {
  const ExpiryProductPage({super.key});

  @override
  State<ExpiryProductPage> createState() => _ExpiryProductPageState();
}

class _ExpiryProductPageState extends State<ExpiryProductPage> {
  final ExpiryService _expiryService = ExpiryService();
  List<ExpiryProduct> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await _expiryService.getProducts();
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  void _showProductDialog({ExpiryProduct? product}) {
    final nameController = TextEditingController(text: product?.name ?? '');
    final quantityController = TextEditingController(text: product?.quantity.toString() ?? '1');
    DateTime selectedDate = product?.expiryDate ?? DateTime.now();
    int selectedNotifyDays = product?.notifyDaysBefore ?? 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                product == null ? 'Novo Produto' : 'Editar Produto',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Nome do Produto',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.shopping_bag_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantidade',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.orange),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Data de Vencimento', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(selectedDate),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedNotifyDays,
                      decoration: InputDecoration(
                        labelText: 'Notificar antes',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.notifications_active_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 dia antes')),
                        DropdownMenuItem(value: 7, child: Text('7 dias antes')),
                        DropdownMenuItem(value: 15, child: Text('15 dias antes')),
                        DropdownMenuItem(value: 30, child: Text('30 dias antes')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedNotifyDays = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      final newProduct = ExpiryProduct(
                        id: product?.id ?? '',
                        name: nameController.text,
                        expiryDate: selectedDate,
                        notifyDaysBefore: selectedNotifyDays,
                        quantity: int.tryParse(quantityController.text) ?? 1,
                      );
                      await _expiryService.saveProduct(newProduct);
                      if (context.mounted) Navigator.pop(context);
                      _loadProducts();
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Produtos & Validade', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.orange,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Gerencie o estoque e evite desperdícios',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Text(
                  '${_products.length} Produtos Cadastrados',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: _products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('Nenhum produto encontrado', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final p = _products[index];
                      
                      // Cálculo de dias comparando apenas as datas (sem as horas)
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final expiry = DateTime(p.expiryDate.year, p.expiryDate.month, p.expiryDate.day);
                      final daysRemaining = expiry.difference(today).inDays;
                      
                      final isExpired = daysRemaining < 0;
                      final isToday = daysRemaining == 0;
                      final isClose = daysRemaining > 0 && daysRemaining <= p.notifyDaysBefore;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: IntrinsicHeight(
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  color: isExpired ? Colors.red : (isToday || isClose ? Colors.orange : Colors.green),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                p.name.toUpperCase(),
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Qtd: ${p.quantity}',
                                                style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.event, size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Vence em: ${DateFormat('dd/MM/yyyy').format(p.expiryDate)}',
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        _buildStatusBadge(daysRemaining, p.notifyDaysBefore),
                                      ],
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                      onPressed: () => _showProductDialog(product: p),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _showDeleteConfirm(p),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(),
        backgroundColor: Colors.orange,
        label: const Text('NOVO PRODUTO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildStatusBadge(int days, int notifyLimit) {
    String text;
    Color color;
    
    if (days < 0) {
      text = 'JÁ VENCEU';
      color = Colors.red;
    } else if (days == 0) {
      text = 'VENCE HOJE';
      color = Colors.orange;
    } else if (days <= notifyLimit) {
      text = 'VENCE EM $days DIAS';
      color = Colors.orange;
    } else {
      text = 'EM DIA';
      color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showDeleteConfirm(ExpiryProduct p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Produto?'),
        content: Text('Deseja realmente remover "${p.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              await _expiryService.deleteProduct(p.id);
              if (mounted) Navigator.pop(context);
              _loadProducts();
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

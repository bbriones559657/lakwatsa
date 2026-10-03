import 'package:flutter/material.dart';

import '../domain/packing.dart';
import '../repositories/packing_repository.dart';
import 'ui_helpers.dart';
import '../theme/app_theme.dart';
import 'widgets/retro_widgets.dart';

class ItemEditor extends StatefulWidget {
  final PackingRepository repository;
  final Belonging? item;
  const ItemEditor({super.key, required this.repository, this.item});
  @override
  State<ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<ItemEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name);
  late final _quantity = TextEditingController(
    text: '${widget.item?.quantity ?? 1}',
  );
  late String _category = widget.item?.category ?? 'Electronics';
  late final _id = widget.item?.id ?? widget.repository.newId();
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.repository.saveItem(
        Belonging(
          id: _id,
          name: _name.text,
          category: _category,
          quantity: int.parse(_quantity.text),
          archived: widget.item?.archived ?? false,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Add item' : 'Edit item'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.item == null ? 'Add Item' : 'Edit Item',
              style: AppTextStyles.heading.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _name,
              enabled: !_busy,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Item name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter an item name.' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: [
                'Electronics',
                'Documents',
                'Clothing',
                'Personal Care',
                'Other',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: _busy ? null : (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantity,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final q = int.tryParse(v ?? '');
                return q != null && q >= 1 && q <= 999
                    ? null
                    : 'Use a whole number from 1 to 999.';
              },
            ),
            const SizedBox(height: 20),
            RetroPanel(
              color: AppColors.card,
              child: Row(
                children: [
                  RetroIcon(categoryIcon(_category)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '$_category icon',
                      style: AppTextStyles.bodyBold,
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              'Every saved item has a unique QR code. Open its QR button to view and label your belongings.',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(_busy ? 'Saving...' : 'Save item'),
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

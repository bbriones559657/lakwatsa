import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final TextEditingController itemNameController = TextEditingController();

  String selectedCategory = 'Electronics';
  int quantity = 1;
  bool hasQrCode = false;

  @override
  void dispose() {
    itemNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Item',
                      style: AppTextStyles.heading.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 22),

                    _FieldLabel('Item Name'),
                    const SizedBox(height: 7),
                    _TextField(
                      controller: itemNameController,
                      hintText: 'Enter item name',
                    ),

                    const SizedBox(height: 18),

                    _FieldLabel('Category'),
                    const SizedBox(height: 7),
                    _CategoryDropdown(
                      value: selectedCategory,
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value;
                        });
                      },
                    ),

                    const SizedBox(height: 18),

                    _FieldLabel('Quantity'),
                    const SizedBox(height: 7),
                    _QuantitySelector(
                      quantity: quantity,
                      onDecrease: () {
                        if (quantity > 1) {
                          setState(() {
                            quantity--;
                          });
                        }
                      },
                      onIncrease: () {
                        setState(() {
                          quantity++;
                        });
                      },
                    ),

                    const SizedBox(height: 22),

                    _FieldLabel('Item Icon'),
                    const SizedBox(height: 7),
                    _IconPreview(),

                    const SizedBox(height: 18),

                    _FieldLabel('Photo'),
                    const SizedBox(height: 7),
                    _PhotoButton(),

                    const SizedBox(height: 22),

                    _QrSection(
                      hasQrCode: hasQrCode,
                      onChanged: (value) {
                        setState(() {
                          hasQrCode = value;
                        });
                      },
                    ),

                    const SizedBox(height: 28),

                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            text: 'Cancel',
                            filled: false,
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            text: 'Save Item',
                            filled: true,
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.ink, width: 2)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.arrow_back, color: AppColors.ink, size: 24),
            ),
          ),
          const Spacer(),
          Text(
            'New Item',
            style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.bodyBold.copyWith(fontSize: 13));
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const _TextField({required this.controller, required this.hintText});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.body.copyWith(fontSize: 13),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.ink, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.green, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _CategoryDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.ink),
          style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
          dropdownColor: AppColors.background,
          items: const [
            DropdownMenuItem(value: 'Electronics', child: Text('Electronics')),
            DropdownMenuItem(value: 'Documents', child: Text('Documents')),
            DropdownMenuItem(value: 'Clothing', child: Text('Clothing')),
            DropdownMenuItem(value: 'Toiletries', child: Text('Toiletries')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _QuantitySelector({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuantityButton(text: '−', onPressed: onDecrease),
        Container(
          width: 70,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border.symmetric(
              horizontal: BorderSide(color: AppColors.ink, width: 2),
            ),
          ),
          child: Text(
            quantity.toString(),
            style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
          ),
        ),
        _QuantityButton(text: '+', onPressed: onIncrease),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _QuantityButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.ink,
          border: Border.all(color: AppColors.ink, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: AppTextStyles.bodyBold.copyWith(
            color: AppColors.background,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _IconPreview extends StatelessWidget {
  const _IconPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.inventory_2_outlined,
        color: AppColors.ink,
        size: 38,
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  const _PhotoButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        '+ Add Photo',
        style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
      ),
    );
  }
}

class _QrSection extends StatelessWidget {
  final bool hasQrCode;
  final ValueChanged<bool> onChanged;

  const _QrSection({required this.hasQrCode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code_2, size: 36, color: AppColors.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('QR Code', style: AppTextStyles.bodyBold),
                const SizedBox(height: 3),
                Text(
                  hasQrCode
                      ? 'QR code will be created for this item.'
                      : 'Optional. You can add one later.',
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),
          Switch(
            value: hasQrCode,
            onChanged: onChanged,
            activeThumbColor: AppColors.background,
            activeTrackColor: AppColors.green,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final bool filled;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.text,
    required this.filled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: filled ? AppColors.ink : AppColors.background,
          border: Border.all(color: AppColors.ink, width: 2),
          borderRadius: BorderRadius.circular(4),
          boxShadow: filled
              ? const [BoxShadow(color: AppColors.green, offset: Offset(3, 3))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: AppTextStyles.bodyBold.copyWith(
            color: filled ? AppColors.background : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

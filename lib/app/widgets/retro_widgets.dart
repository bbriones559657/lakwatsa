import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Shared visual language from the original Lakwatsa screens.
class RetroPanel extends StatelessWidget {
  final Widget child;
  final Color color, shadowColor;
  final EdgeInsetsGeometry padding, margin;
  final VoidCallback? onTap;
  const RetroPanel({
    super.key,
    required this.child,
    this.color = AppColors.background,
    this.shadowColor = AppColors.ink,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsets.only(bottom: 16, right: 4),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(4, 4))],
    ),
    child: Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: AppColors.ink, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class RetroBadge extends StatelessWidget {
  final String label;
  final Color color;
  const RetroBadge(this.label, {super.key, this.color = AppColors.green});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: AppColors.ink, width: 1.5),
      borderRadius: BorderRadius.circular(2),
    ),
    child: Text(label, style: AppTextStyles.pixelWhite.copyWith(fontSize: 7)),
  );
}

class RetroIcon extends StatelessWidget {
  final IconData icon;
  const RetroIcon(this.icon, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: AppColors.card,
      border: Border.all(color: AppColors.ink, width: 1.5),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Icon(icon, color: AppColors.ink, size: 26),
  );
}

IconData categoryIcon(String category) => switch (category) {
  'Electronics' => Icons.devices,
  'Documents' => Icons.description_outlined,
  'Clothing' => Icons.checkroom_outlined,
  'Personal Care' => Icons.cleaning_services_outlined,
  _ => Icons.inventory_2_outlined,
};

class RetroEmpty extends StatelessWidget {
  final String title, message;
  final IconData icon;
  const RetroEmpty({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => RetroPanel(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
    child: Column(
      children: [
        RetroIcon(icon),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: AppTextStyles.bodyBold),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center, style: AppTextStyles.body),
      ],
    ),
  );
}

class RetroBottomNavigation extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const RetroBottomNavigation({
    super.key,
    required this.index,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.background,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.ink, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: Semantics(
                  selected: i == index,
                  button: true,
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 2,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              const ['Home', 'Items', 'Lists', 'Activities'][i],
                              style: i == index
                                  ? AppTextStyles.navSelected
                                  : AppTextStyles.nav,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 4,
                              height: 4,
                              color: i == index
                                  ? AppColors.ink
                                  : Colors.transparent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class RetroSearch extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const RetroSearch({super.key, required this.hint, required this.onChanged});
  @override
  Widget build(BuildContext context) => RetroPanel(
    padding: EdgeInsets.zero,
    margin: const EdgeInsets.only(right: 4, bottom: 4),
    child: TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    ),
  );
}

class RetroProgress extends StatelessWidget {
  final int found, total;
  final String label;
  const RetroProgress({
    super.key,
    required this.found,
    required this.total,
    this.label = 'Packing',
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.pixelDark)),
          Text('$found/$total', style: AppTextStyles.pixelDark),
        ],
      ),
      const SizedBox(height: 8),
      Container(
        height: 16,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.ink, width: 2),
          borderRadius: BorderRadius.circular(2),
        ),
        child: LinearProgressIndicator(
          value: total == 0 ? 0 : (found / total).clamp(0, 1),
          color: AppColors.green,
          backgroundColor: AppColors.background,
          semanticsLabel: '$label: $found of $total item types',
        ),
      ),
    ],
  );
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LakwatsaBackgroundDots extends StatelessWidget {
  const LakwatsaBackgroundDots({super.key});

  static const _positions = <Alignment>[
    Alignment(-.84, -.86),
    Alignment(.78, -.76),
    Alignment(-.76, -.35),
    Alignment(.80, -.40),
    Alignment(-.78, .12),
    Alignment(.84, .08),
    Alignment(-.64, .58),
    Alignment(.66, .62),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: _positions.map((alignment) {
          return Align(
            alignment: alignment,
            child: Container(
              width: 4,
              height: 4,
              color: AppColors.ink.withValues(alpha: .05),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class LakwatsaTopBar extends StatelessWidget {
  final String title;
  final List<Widget> actions;

  const LakwatsaTopBar({
    super.key,
    required this.title,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: AppMetrics.topBarHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.pagePadding,
        vertical: 6,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: AppColors.ink,
            width: AppMetrics.borderWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.heading,
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 12),
            ..._withSpacing(actions),
          ],
        ],
      ),
    );
  }

  static List<Widget> _withSpacing(List<Widget> actions) {
    final widgets = <Widget>[];

    for (var index = 0; index < actions.length; index++) {
      if (index > 0) {
        widgets.add(const SizedBox(width: 8));
      }
      widgets.add(actions[index]);
    }

    return widgets;
  }
}

class LakwatsaHeaderAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final String? text;
  final IconData? icon;
  final bool filled;
  final bool bordered;
  final double? width;

  const LakwatsaHeaderAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.text,
    this.icon,
    this.filled = false,
    this.bordered = true,
    this.width,
  }) : assert(text != null || icon != null);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = filled ? AppColors.background : AppColors.ink;
    final compactVisual = icon != null || text == '+';
    final visualWidth = width ?? (compactVisual ? 36.0 : null);

    final visual = Container(
      width: visualWidth,
      height: 36,
      padding: EdgeInsets.symmetric(
        horizontal: compactVisual ? 0 : 4,
      ),
      decoration: bordered
          ? BoxDecoration(
              color: filled ? AppColors.ink : AppColors.background,
              border: Border.all(
                color: AppColors.ink,
                width: filled
                    ? AppMetrics.strongBorderWidth
                    : AppMetrics.borderWidth,
              ),
              borderRadius: BorderRadius.circular(AppMetrics.radius),
            )
          : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppMetrics.radius),
          child: Center(
            child: icon != null
                ? Icon(icon, color: foreground, size: 18)
                : Text(
                    text!,
                    maxLines: 1,
                    style: AppTextStyles.bodyBold.copyWith(
                      color: foreground,
                      fontSize: text == '+' ? 20 : 12,
                    ),
                  ),
          ),
        ),
      ),
    );

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        child: Opacity(
          opacity: enabled ? 1 : .5,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppMetrics.touchTarget,
              minHeight: AppMetrics.touchTarget,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: visual,
            ),
          ),
        ),
      ),
    );
  }
}

class LakwatsaSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final EdgeInsetsGeometry margin;

  const LakwatsaSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hintText,
    this.margin = const EdgeInsets.symmetric(horizontal: AppMetrics.pagePadding),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(
          color: AppColors.ink,
          width: AppMetrics.borderWidth,
        ),
        borderRadius: BorderRadius.circular(AppMetrics.radius),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.body.copyWith(
          color: AppColors.ink,
          fontSize: 13,
        ),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTextStyles.body.copyWith(fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: AppColors.ink, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

class LakwatsaPixelCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color shadowColor;
  final Offset shadowOffset;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final double? minHeight;

  const LakwatsaPixelCard({
    super.key,
    required this.child,
    this.color = AppColors.background,
    this.shadowColor = AppColors.ink,
    this.shadowOffset = const Offset(4, 4),
    this.padding,
    this.height,
    this.minHeight,
  }) : assert(
         height == null || minHeight == null || height >= minHeight,
         'height must be at least minHeight when both are provided.',
       );

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: height,
          constraints: minHeight == null
              ? null
              : BoxConstraints(minHeight: minHeight!),
          padding: padding,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(
              color: AppColors.ink,
              width: AppMetrics.strongBorderWidth,
            ),
            borderRadius: BorderRadius.circular(AppMetrics.radius),
            boxShadow: [
              BoxShadow(color: shadowColor, offset: shadowOffset),
            ],
          ),
          child: child,
        ),
        const Positioned(left: -3, top: -3, child: _PixelCorner()),
        const Positioned(right: -3, top: -3, child: _PixelCorner()),
        const Positioned(left: -3, bottom: -3, child: _PixelCorner()),
        const Positioned(right: -3, bottom: -3, child: _PixelCorner()),
      ],
    );
  }
}

class _PixelCorner extends StatelessWidget {
  const _PixelCorner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 6,
      height: 6,
      child: DecoratedBox(
        decoration: BoxDecoration(color: AppColors.ink),
      ),
    );
  }
}

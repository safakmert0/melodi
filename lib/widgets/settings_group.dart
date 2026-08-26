import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Background fill for grouped cards, matching the SpotiFLAC settings look.
Color settingsGroupColor(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark
      ? Color.alphaBlend(
          Colors.white.withValues(alpha: 0.08),
          colorScheme.surface,
        )
      : Color.alphaBlend(
          Colors.black.withValues(alpha: 0.04),
          colorScheme.surface,
        );
}

double _wideInsetForWidth(double width) {
  if (width > 1200) return (width - 1100) / 2;
  if (width > 840) return 64;
  if (width > 600) return 32;
  return 0;
}

class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  const SettingsGroup({super.key, required this.children, this.margin});

  @override
  Widget build(BuildContext context) {
    final cardColor = settingsGroupColor(context);
    final colorScheme = Theme.of(context).colorScheme;

    final decoration = BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(context.tokens.radiusCard),
      border: Border.all(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
    );
    final child = Material(
      color: Colors.transparent,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );

    if (margin != null) {
      return Container(
        margin: margin,
        decoration: decoration,
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        margin: EdgeInsets.symmetric(
          horizontal:
              16 + (constraints.hasBoundedWidth ? _wideInsetForWidth(constraints.maxWidth) : 0),
          vertical: 4,
        ),
        decoration: decoration,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class SettingsItem extends StatelessWidget {
  final IconData? icon;
  final String title;
  final Widget? titleTrailing;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const SettingsItem({
    super.key,
    this.icon,
    required this.title,
    this.titleTrailing,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          splashColor: colorScheme.primary.withValues(alpha: 0.12),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: colorScheme.onSurfaceVariant, size: 24),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          if (titleTrailing != null) ...[
                            const SizedBox(width: 8),
                            titleTrailing!,
                          ],
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ] else if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: icon != null ? 56 : 20,
            endIndent: 20,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
      ],
    );
  }
}

class SettingsSwitchItem extends StatelessWidget {
  final IconData? icon;
  final String title;
  final Widget? titleTrailing;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool showDivider;
  final bool enabled;

  const SettingsSwitchItem({
    super.key,
    this.icon,
    required this.title,
    this.titleTrailing,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.showDivider = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDisabled = !enabled || onChanged == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: InkWell(
            onTap: isDisabled ? null : () => onChanged!(!value),
            splashColor: colorScheme.primary.withValues(alpha: 0.12),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      color: isDisabled
                          ? colorScheme.outline
                          : colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: isDisabled
                                          ? colorScheme.outline
                                          : null,
                                    ),
                              ),
                            ),
                            if (titleTrailing != null) ...[
                              const SizedBox(width: 8),
                              titleTrailing!,
                            ],
                          ],
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: isDisabled
                                      ? colorScheme.outline
                                      : colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: value,
                    onChanged: isDisabled ? null : onChanged,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: icon != null ? 56 : 20,
            endIndent: 20,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
      ],
    );
  }
}

class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

enum SettingsChipLayout { row, column }

class SettingsChoiceChip extends StatelessWidget {
  const SettingsChoiceChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.layout = SettingsChipLayout.row,
    this.expand = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final SettingsChipLayout layout;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(tokens.radiusCover);

    final unselectedColor = isDark
        ? Color.alphaBlend(
            Colors.white.withValues(alpha: 0.05),
            colorScheme.surface,
          )
        : colorScheme.surfaceContainerHigh;
    final foreground = isSelected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    final labelText = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        color: foreground,
      ),
    );

    final Widget content;
    if (icon == null) {
      content = Center(child: labelText);
    } else if (layout == SettingsChipLayout.column) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground),
          SizedBox(height: tokens.gapXs + 2),
          labelText,
        ],
      );
    } else {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: foreground),
          SizedBox(width: tokens.gapSm),
          Flexible(child: labelText),
        ],
      );
    }

    final chip = Material(
      color: isSelected ? colorScheme.primaryContainer : unselectedColor,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: tokens.minTouchTarget),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: tokens.gapMd,
              horizontal: tokens.gapMd,
            ),
            child: content,
          ),
        ),
      ),
    );

    return expand ? Expanded(child: chip) : chip;
  }
}

class SettingsChoiceGrid extends StatelessWidget {
  const SettingsChoiceGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final spacing = context.tokens.gapSm;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 320).floor().clamp(2, 4);
        final chipWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: chipWidth, child: child),
          ],
        );
      },
    );
  }
}

enum SettingsInfoTone { neutral, warning, error }

class SettingsInfoCard extends StatelessWidget {
  const SettingsInfoCard({
    super.key,
    required this.message,
    this.icon,
    this.title,
    this.tone = SettingsInfoTone.neutral,
    this.action,
    this.margin,
  });

  final String message;
  final IconData? icon;
  final String? title;
  final SettingsInfoTone tone;
  final Widget? action;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (background, foreground) = switch (tone) {
      SettingsInfoTone.neutral => (
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        colorScheme.onSurfaceVariant,
      ),
      SettingsInfoTone.warning => (
        colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        colorScheme.onTertiaryContainer,
      ),
      SettingsInfoTone.error => (
        colorScheme.errorContainer.withValues(alpha: 0.6),
        colorScheme.onErrorContainer,
      ),
    };

    return Container(
      margin: margin ??
          EdgeInsets.symmetric(
            horizontal: tokens.gapLg,
            vertical: tokens.gapXs,
          ),
      padding: EdgeInsets.all(tokens.gapLg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: tokens.borderRadiusCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: foreground),
            SizedBox(width: tokens.gapMd),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: tokens.gapXs),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(color: foreground),
                ),
                if (action != null) ...[
                  SizedBox(height: tokens.gapSm),
                  Align(alignment: Alignment.centerLeft, child: action!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

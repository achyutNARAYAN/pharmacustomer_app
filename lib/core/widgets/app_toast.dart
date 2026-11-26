import 'package:flutter/material.dart';
import '../theme.dart';

/// Blinkit / Zomato-style Floating Toast Pill.
///
/// Features:
/// - Clears any active SnackBar immediately before presenting a new one.
/// - Floats above bottom navigation and sheet content (`SnackBarBehavior.floating`).
/// - Pill shape with rounded corners (`16px`).
/// - Signature brand teal background (`AppTheme.primaryDark` / `0xFF055A63`).
/// - Contextual icons and optional high-contrast tap actions.
class AppToast {
  AppToast._();

  /// Primary Toast display method.
  static void show(
    BuildContext context,
    String message, {
    IconData? icon = Icons.check_circle_rounded,
    Color? iconColor = const Color(0xFF34D399),
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    Color? backgroundColor,
  }) {
    if (!context.mounted) return;
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    // 1. Instantly clear any previously showing SnackBar (Pehle pura snack bar delete/clear karo)
    messenger.clearSnackBars();

    // 2. Brand teal background by default
    final bg = backgroundColor ?? AppTheme.primaryDark;

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        backgroundColor: bg,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: duration ?? const Duration(milliseconds: 2800),
        content: Row(
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: iconColor ?? Colors.white),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                trimmed,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  messenger.hideCurrentSnackBar();
                  onAction?.call();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      color: Color(0xFF6EE7B7),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Success Toast with Green checkmark icon on brand teal.
  static void success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    show(
      context,
      message,
      icon: Icons.check_circle_rounded,
      iconColor: const Color(0xFF34D399),
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Error / Alert Toast with Red/Coral alert icon on brand teal.
  static void error(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    show(
      context,
      message,
      icon: Icons.error_outline_rounded,
      iconColor: const Color(0xFFFCA5A5),
      duration: duration ?? const Duration(milliseconds: 3200),
    );
  }

  /// Informational / Warning Toast with Amber icon on brand teal.
  static void info(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    show(
      context,
      message,
      icon: Icons.info_outline_rounded,
      iconColor: const Color(0xFFFCD34D),
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Cart action toast with shopping cart icon and action button.
  static void cart(
    BuildContext context,
    String message, {
    VoidCallback? onViewCart,
    Duration? duration,
  }) {
    show(
      context,
      message,
      icon: Icons.shopping_bag_rounded,
      iconColor: const Color(0xFF6EE7B7),
      actionLabel: 'VIEW CART',
      onAction: onViewCart,
      duration: duration,
    );
  }
}

import 'package:flutter/material.dart';

class InAppNotification {
  final String title;
  final String message;
  final NotificationType type;
  final Duration duration;
  final VoidCallback? onTap;
  final bool dismissible;

  InAppNotification({
    required this.title,
    required this.message,
    this.type = NotificationType.info,
    this.duration = const Duration(seconds: 4),
    this.onTap,
    this.dismissible = true,
  });
}

enum NotificationType {
  success,
  error,
  warning,
  info,
}

class InAppNotificationService {
  static final InAppNotificationService _instance =
      InAppNotificationService._internal();

  factory InAppNotificationService() {
    return _instance;
  }

  InAppNotificationService._internal();

  final List<InAppNotification> _notifications = [];
  VoidCallback? _onNotificationAdded;

  void setOnNotificationAdded(VoidCallback callback) {
    _onNotificationAdded = callback;
  }

  void showNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
    bool dismissible = true,
  }) {
    final notification = InAppNotification(
      title: title,
      message: message,
      type: type,
      duration: duration,
      onTap: onTap,
      dismissible: dismissible,
    );

    _notifications.add(notification);
    _onNotificationAdded?.call();

    // Auto-remove after duration
    Future.delayed(duration, () {
      _notifications.remove(notification);
      _onNotificationAdded?.call();
    });
  }

  void showSuccess({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
  }) {
    showNotification(
      title: title,
      message: message,
      type: NotificationType.success,
      duration: duration,
      onTap: onTap,
    );
  }

  void showError({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 5),
    VoidCallback? onTap,
  }) {
    showNotification(
      title: title,
      message: message,
      type: NotificationType.error,
      duration: duration,
      onTap: onTap,
    );
  }

  void showWarning({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
  }) {
    showNotification(
      title: title,
      message: message,
      type: NotificationType.warning,
      duration: duration,
      onTap: onTap,
    );
  }

  void showInfo({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
  }) {
    showNotification(
      title: title,
      message: message,
      type: NotificationType.info,
      duration: duration,
      onTap: onTap,
    );
  }

  void dismissNotification(InAppNotification notification) {
    _notifications.remove(notification);
    _onNotificationAdded?.call();
  }

  void dismissAll() {
    _notifications.clear();
    _onNotificationAdded?.call();
  }

  List<InAppNotification> getNotifications() {
    return List.unmodifiable(_notifications);
  }
}

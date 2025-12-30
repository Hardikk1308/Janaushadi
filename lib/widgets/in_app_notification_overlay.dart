import 'package:flutter/material.dart';
import 'package:jan_aushadi/services/in_app_notification_service.dart';

class InAppNotificationOverlay extends StatefulWidget {
  final Widget child;

  const InAppNotificationOverlay({
    super.key,
    required this.child,
  });

  @override
  State<InAppNotificationOverlay> createState() =>
      _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState extends State<InAppNotificationOverlay> {
  final InAppNotificationService _notificationService =
      InAppNotificationService();

  @override
  void initState() {
    super.initState();
    _notificationService.setOnNotificationAdded(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Column(
              children: _notificationService
                  .getNotifications()
                  .map((notification) =>
                      _NotificationWidget(notification: notification))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationWidget extends StatefulWidget {
  final InAppNotification notification;

  const _NotificationWidget({required this.notification});

  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    switch (widget.notification.type) {
      case NotificationType.success:
        return const Color(0xFF4CAF50);
      case NotificationType.error:
        return const Color(0xFFf44336);
      case NotificationType.warning:
        return const Color(0xFFff9800);
      case NotificationType.info:
        return const Color(0xFF2196F3);
    }
  }

  IconData _getIcon() {
    switch (widget.notification.type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.error:
        return Icons.error;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.info:
        return Icons.info;
    }
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      InAppNotificationService().dismissNotification(widget.notification);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: () {
            widget.notification.onTap?.call();
            if (widget.notification.dismissible) {
              _dismiss();
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getBackgroundColor(),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  _getIcon(),
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.notification.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.notification.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (widget.notification.dismissible) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _dismiss,
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

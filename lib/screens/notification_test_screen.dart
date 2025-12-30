import 'package:flutter/material.dart';
import 'package:jan_aushadi/services/notification_service.dart';
import 'package:jan_aushadi/services/in_app_notification_service.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  final NotificationService _notificationService = NotificationService();
  final InAppNotificationService _inAppNotificationService =
      InAppNotificationService();
  bool _isLoading = false;

  Future<void> _testSuccessNotification() async {
    setState(() => _isLoading = true);
    try {
      final success = await _notificationService.sendPushNotification(
        title: 'Test Success',
        description: 'This is a test success notification',
      );

      if (success) {
        _inAppNotificationService.showSuccess(
          title: 'Notification Sent',
          message: 'Push notification sent successfully!',
        );
      } else {
        _inAppNotificationService.showError(
          title: 'Failed',
          message: 'Failed to send push notification',
        );
      }
    } catch (e) {
      _inAppNotificationService.showError(
        title: 'Error',
        message: e.toString(),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testErrorNotification() async {
    setState(() => _isLoading = true);
    try {
      final success = await _notificationService.sendPushNotification(
        title: 'Test Error',
        description: 'This is a test error notification',
      );

      if (success) {
        _inAppNotificationService.showError(
          title: 'Error Notification Sent',
          message: 'Error notification sent successfully!',
        );
      } else {
        _inAppNotificationService.showError(
          title: 'Failed',
          message: 'Failed to send error notification',
        );
      }
    } catch (e) {
      _inAppNotificationService.showError(
        title: 'Error',
        message: e.toString(),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testWarningNotification() async {
    setState(() => _isLoading = true);
    try {
      final success = await _notificationService.sendPushNotification(
        title: 'Test Warning',
        description: 'This is a test warning notification',
      );

      if (success) {
        _inAppNotificationService.showWarning(
          title: 'Warning Notification Sent',
          message: 'Warning notification sent successfully!',
        );
      } else {
        _inAppNotificationService.showError(
          title: 'Failed',
          message: 'Failed to send warning notification',
        );
      }
    } catch (e) {
      _inAppNotificationService.showError(
        title: 'Error',
        message: e.toString(),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testInfoNotification() async {
    setState(() => _isLoading = true);
    try {
      final success = await _notificationService.sendPushNotification(
        title: 'Test Info',
        description: 'This is a test info notification',
      );

      if (success) {
        _inAppNotificationService.showInfo(
          title: 'Info Notification Sent',
          message: 'Info notification sent successfully!',
        );
      } else {
        _inAppNotificationService.showError(
          title: 'Failed',
          message: 'Failed to send info notification',
        );
      }
    } catch (e) {
      _inAppNotificationService.showError(
        title: 'Error',
        message: e.toString(),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showInAppSuccessNotification() {
    _inAppNotificationService.showSuccess(
      title: 'In-App Success',
      message: 'This is an in-app success notification',
      duration: const Duration(seconds: 4),
    );
  }

  void _showInAppErrorNotification() {
    _inAppNotificationService.showError(
      title: 'In-App Error',
      message: 'This is an in-app error notification',
      duration: const Duration(seconds: 5),
    );
  }

  void _showInAppWarningNotification() {
    _inAppNotificationService.showWarning(
      title: 'In-App Warning',
      message: 'This is an in-app warning notification',
      duration: const Duration(seconds: 4),
    );
  }

  void _showInAppInfoNotification() {
    _inAppNotificationService.showInfo(
      title: 'In-App Info',
      message: 'This is an in-app info notification',
      duration: const Duration(seconds: 4),
    );
  }

  void _showMultipleNotifications() {
    _inAppNotificationService.showSuccess(
      title: 'First Notification',
      message: 'This is the first notification',
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      _inAppNotificationService.showInfo(
        title: 'Second Notification',
        message: 'This is the second notification',
      );
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      _inAppNotificationService.showWarning(
        title: 'Third Notification',
        message: 'This is the third notification',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Testing'),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFFAFAFA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Push Notifications Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Push Notifications (API)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Send notifications via API to test backend integration',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildButton(
                    label: 'Send Success Notification',
                    onPressed: _testSuccessNotification,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildButton(
                    label: 'Send Error Notification',
                    onPressed: _testErrorNotification,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  _buildButton(
                    label: 'Send Warning Notification',
                    onPressed: _testWarningNotification,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildButton(
                    label: 'Send Info Notification',
                    onPressed: _testInfoNotification,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // In-App Notifications Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'In-App Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Display notifications directly in the app',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildButton(
                    label: 'Show Success',
                    onPressed: _showInAppSuccessNotification,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildButton(
                    label: 'Show Error',
                    onPressed: _showInAppErrorNotification,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  _buildButton(
                    label: 'Show Warning',
                    onPressed: _showInAppWarningNotification,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildButton(
                    label: 'Show Info',
                    onPressed: _showInAppInfoNotification,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  _buildButton(
                    label: 'Show Multiple Notifications',
                    onPressed: _showMultipleNotifications,
                    color: const Color(0xFF9C27B0),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Info Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2196F3).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Testing Guide',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoItem(
                    '1. Push Notifications',
                    'Use the API buttons to send notifications via your backend. Check the console logs for API responses.',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoItem(
                    '2. In-App Notifications',
                    'Use the in-app buttons to display notifications directly in the app without API calls.',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoItem(
                    '3. Multiple Notifications',
                    'Stack multiple notifications to see how they appear together.',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoItem(
                    '4. Check Logs',
                    'Open the console to see detailed logs of all notification operations.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF2196F3),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              '•',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

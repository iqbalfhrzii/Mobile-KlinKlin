import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../data/notification_model.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  Future<List<NotificationItem>> fetchNotifications() async {
    try {
      final response = await ApiClient.instance.get('/notifications');
      if (response.statusCode == 200) {
        final data = response.data;
        final unreadCount = data['unread_count'] as int? ?? 0;
        unreadCountNotifier.value = unreadCount;

        List<dynamic> rawList = [];
        final dynamic rawData = data['data'];
        if (rawData is List) {
          rawList = rawData;
        } else if (rawData is Map) {
          rawList = rawData.values.toList();
        }

        return rawList
            .map((item) {
              if (item is Map) {
                return NotificationItem.fromJson(Map<String, dynamic>.from(item));
              }
              return null;
            })
            .whereType<NotificationItem>()
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      final response = await ApiClient.instance.get('/notifications');
      if (response.statusCode == 200) {
        final data = response.data;
        final unreadCount = data['unread_count'] as int? ?? 0;
        unreadCountNotifier.value = unreadCount;
      }
    } catch (_) {}
  }

  Future<bool> markAsRead(String id) async {
    try {
      final response = await ApiClient.instance.post('/notifications/$id/mark-as-read');
      if (response.statusCode == 200) {
        final count = response.data['unread_count'] as int?;
        if (count != null) {
          unreadCountNotifier.value = count;
        } else if (unreadCountNotifier.value > 0) {
          unreadCountNotifier.value -= 1;
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      final response = await ApiClient.instance.post('/notifications/mark-all-as-read');
      if (response.statusCode == 200) {
        unreadCountNotifier.value = 0;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      return false;
    }
  }

  Future<bool> deleteNotification(String id) async {
    try {
      final response = await ApiClient.instance.delete('/notifications/$id');
      if (response.statusCode == 200) {
        final count = response.data['unread_count'] as int?;
        if (count != null) {
          unreadCountNotifier.value = count;
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      return false;
    }
  }
}

class NotificationItem {
  final String id;
  final String type;
  final String title;
  final String message;
  final String? url;
  final String? screen;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;
  final String timeAgo;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.url,
    this.screen,
    required this.data,
    this.readAt,
    required this.createdAt,
    required this.timeAgo,
  });

  bool get isRead => readAt != null;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'info',
      title: json['title']?.toString() ?? 'Notifikasi',
      message: json['message']?.toString() ?? '',
      url: json['url']?.toString(),
      screen: json['screen']?.toString(),
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : <String, dynamic>{},
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      timeAgo: json['time_ago']?.toString() ?? '',
    );
  }

  NotificationItem copyWith({
    String? id,
    String? type,
    String? title,
    String? message,
    String? url,
    String? screen,
    Map<String, dynamic>? data,
    DateTime? readAt,
    DateTime? createdAt,
    String? timeAgo,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      url: url ?? this.url,
      screen: screen ?? this.screen,
      data: data ?? this.data,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      timeAgo: timeAgo ?? this.timeAgo,
    );
  }
}

class NotificationInfo {
  const NotificationInfo({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final String icon;

  Map<String, String> toJson() {
    return {
      'title': title,
      'message': message,
      'icon': icon,
    };
  }
}

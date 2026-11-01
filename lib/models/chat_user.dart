class ChatUser {
  ChatUser({
    required this.image,
    required this.about,
    required this.name,
    required this.createdAt,
    required this.isOnline,
    required this.lastActive,
    required this.id,
    required this.email,
    required this.pushToken,
    this.username = '',
  });
  late String image;
  late String about;
  late String name;
  late String createdAt;
  late bool isOnline;
  late String lastActive;
  late String id;
  late String email;
  late String pushToken;
  late String username;

  ChatUser.fromJson(Map<String, dynamic> json){
    image = json['image']?.toString() ?? '';
    about = json['about']?.toString() ?? '';
    name = json['name']?.toString() ?? '';
    createdAt = json['created_at']?.toString() ?? '';
    isOnline = json['is_online'] is bool ? json['is_online'] as bool : false;
    lastActive = json['last_active']?.toString() ?? '';
    id = json['id']?.toString() ?? '';
    email = json['email']?.toString() ?? '';
    pushToken = json['push_token']?.toString() ?? '';
    username = json['username']?.toString() ?? '';
    if (username.isEmpty) {
      final emailStr = json['email']?.toString() ?? '';
      username = emailStr.contains('@')
          ? emailStr.split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '')
          : (json['name']?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '') ?? '');
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['image'] = image;
    data['about'] = about;
    data['name'] = name;
    data['created_at'] = createdAt;
    data['is_online'] = isOnline;
    data['last_active'] = lastActive;
    data['id'] = id;
    data['email'] = email;
    data['push_token'] = pushToken;
    data['username'] = username;
    return data;
  }
}
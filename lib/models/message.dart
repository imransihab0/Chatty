class Message {
  Message({
    required this.toId,
    required this.msg,
    required this.read,
    required this.type,
    required this.sent,
    required this.fromId,
    this.reaction = '',
    this.replyMsg = '',
    this.replyUser = '',
  });
  late final String toId;
  late final String msg;
  late final String read;
  late final String sent;
  late final String fromId;
  late final Type type;
  late String reaction;
  late String replyMsg;
  late String replyUser;

  Message.fromJson(Map<String, dynamic> json){
    toId = json['toId']?.toString() ?? '';
    msg = json['msg']?.toString() ?? '';
    read = json['read']?.toString() ?? '';
    if (json['type']?.toString() == Type.image.name) {
      type = Type.image;
    } else if (json['type']?.toString() == Type.audio.name) {
      type = Type.audio;
    } else {
      type = Type.text;
    }
    sent = json['sent']?.toString() ?? '';
    fromId = json['fromId']?.toString() ?? '';
    reaction = json['reaction']?.toString() ?? '';
    replyMsg = json['reply_msg']?.toString() ?? '';
    replyUser = json['reply_user']?.toString() ?? '';
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['toId'] = toId;
    data['msg'] = msg;
    data['read'] = read;
    data['type'] = type.name;
    data['sent'] = sent;
    data['fromId'] = fromId;
    data['reaction'] = reaction;
    if (replyMsg.isNotEmpty) data['reply_msg'] = replyMsg;
    if (replyUser.isNotEmpty) data['reply_user'] = replyUser;
    return data;
  }
}

enum Type { text, image, audio }
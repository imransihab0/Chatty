import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/my_date_util.dart';
import 'package:chatty/main.dart';
import 'package:chatty/models/chat_user.dart';
import 'package:chatty/models/message.dart';
import 'package:chatty/screens/chat_screen.dart';
import 'package:flutter/material.dart';

class ChatUserCard extends StatefulWidget {
  final ChatUser user;

  const ChatUserCard({super.key, required this.user});

  @override
  State<ChatUserCard> createState() => _ChatUserCardState();
}

class _ChatUserCardState extends State<ChatUserCard> {

  // last msg if null
  Message ? _message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: mq.width * .03, vertical: 4),
      color: Colors.yellow.shade100,
      elevation: 1,
      child: InkWell(
        onTap: () {
          // go to chatting page
          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(user: widget.user)));
        },
        child: StreamBuilder(
          stream: APIs.getLastMessages(widget.user),
          builder: (context, snapshot) {

            final data = snapshot.data?.docs;
            final list = data?.map((e) => Message.fromJson(e.data())).toList() ?? [];
            if(list.isNotEmpty){
              _message = list[0];
            }

            return ListTile(
              //user profile picture here
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(mq.height * .3),
                child: CachedNetworkImage(
                  width: mq.height * .055,
                  height: mq.height * .055,
                  fit: BoxFit.cover,
                  imageUrl: widget.user.image,
                  progressIndicatorBuilder: (context, url, downloadProgress) =>
                      CircularProgressIndicator(value: downloadProgress.progress),
                  errorWidget: (context, url, error) => const CircleAvatar(child: Icon(Icons.person)),
                ),
              ),
              //user name
              title: Text(widget.user.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0),),
              //user last message
              subtitle: Text(_message != null ? _message!.msg : widget.user.about, maxLines: 1, style: const TextStyle(fontSize: 13, letterSpacing: 0),),
              //last message time

              trailing: _message == null ? null :
              _message!.read.isEmpty && _message!.fromId != APIs.user.uid
                  ?
              Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10))
              ) : Text(MyDateUtil.getFormattedTime(context: context, time: _message!.sent), style: const TextStyle(color: Colors.black54)),
            );
        },)
      ),
    );
  }
}

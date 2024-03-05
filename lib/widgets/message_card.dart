
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/my_date_util.dart';
import 'package:chatty/main.dart';
import 'package:chatty/models/message.dart';
import 'package:flutter/material.dart';

// for every single message
class MessageCard extends StatefulWidget {
  const MessageCard({super.key, required this.message});

  final Message message;

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  @override
  Widget build(BuildContext context) {
    return APIs.user.uid == widget.message.fromId ? _whiteMessage() : _yellowMessage();
  }

  // sender-B
  Widget _yellowMessage(){

    // update last rd msg if sender & receiver are diff
    if(widget.message.read.isEmpty){
      APIs.updateMessageReadStatus(widget.message);
    }

    return Row(

      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: mq.width * 0.04, vertical: mq.width * 0.02),
            margin: EdgeInsets.symmetric(horizontal: mq.height * .01),
            decoration: BoxDecoration(
              color: Color(0xffdedede),
              border: Border.all(color: Color(0xff6e6d6d)),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(15),
                topLeft: Radius.circular(15),
                bottomRight: Radius.circular(15),
              )
            ),

            child:
            widget.message.type == Type.text ?
            Text(widget.message.msg, style: const TextStyle(
              fontSize: 15, color: Colors.black87,
            ),) 
                : ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: CachedNetworkImage(
                fit: BoxFit.cover,
                imageUrl: widget.message.msg,
                placeholder: (context, url) => const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.image, size: 70),
              ),
            ),
          ),
        ),

        Padding(
          padding: EdgeInsets.only(right: mq.width * .04),
          child: Text(MyDateUtil.getFormattedTime(context: context, time: widget.message.sent), style: const TextStyle(
            fontSize: 13, color: Colors.black54,
          ),),
        ),
SizedBox(height: mq.height * .04,),
      ],
    );
  }

  // receiver-G
  Widget _whiteMessage(){
    return Row(

      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [

        Row(

          children: [
            // for adding space
            SizedBox(width: mq.width * .04),
            // double tick icon
            if(widget.message.read.isNotEmpty)
            const Icon(Icons.done_all_outlined, color: Colors.black, size: 20,),
            // space box
            const SizedBox(width: 2),
            // read time
            Text(MyDateUtil.getFormattedTime(context: context, time: widget.message.sent), style: const TextStyle(
              fontSize: 13, color: Colors.black54,
            ),),
          ],

        ),
        Flexible(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: mq.width * 0.04, vertical: mq.width * 0.02),
            margin: EdgeInsets.symmetric(horizontal: mq.height * .01),
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black26),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(15),
                  topLeft: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                )
            ),
            child: widget.message.type == Type.text ?
            Text(widget.message.msg, style: const TextStyle(
              fontSize: 15, color: Colors.black87,
            ),)
                : ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: CachedNetworkImage(
                fit: BoxFit.cover,
                imageUrl: widget.message.msg,
                placeholder: (context, url) => const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.image, size: 70),
              ),
            ),
          ),
        ),
      ],
    );
  }

}


import 'dart:developer';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/apis.dart';
import '../main.dart';
import '../models/chat_user.dart';
import '../models/message.dart';
import '../widgets/message_card.dart';

class ChatScreen extends StatefulWidget {
  final ChatUser user;

  const ChatScreen({super.key, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {

  // for storing msg
  List<Message> _list = [];

  final _textController = TextEditingController();

  bool _showEmoji = false, _isUploading = false;

  @override
  Widget build(BuildContext context) {
    // for notification bar/status bar color set
    // SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.white));

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: _appBar(),
        ),

        // backgroundColor: Colors.blue.shade100,

        //for body
        body: Column(children: [
          Expanded(
            child: StreamBuilder(
              stream: APIs.getAllMessages(widget.user),
              builder: (context, snapshot){
                switch(snapshot.connectionState){
                //if data is loading
                  case ConnectionState.waiting:
                  case ConnectionState.none:
                    return const SizedBox();
            
                //if some or all data is loaded then show it
                  case ConnectionState.active:
                  case ConnectionState.done:
                    final data = snapshot.data?.docs;
                    _list = data?.map((e) => Message.fromJson(e.data())).toList() ?? [];

                    if(_list.isNotEmpty){
                      return ListView.builder(
                        reverse: true,
                          itemCount: _list.length,
                          padding: EdgeInsets.only(top: mq.height * .01),
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (context, index){
                            return MessageCard(message: _list[index]);
                          });
                    }else{
                      return const Center(child: Text('👋 Say Assalamuyalaikum!', style: TextStyle(fontSize: 24, letterSpacing: 0, fontWeight: FontWeight.normal),));
                    }
                }
              },
            ),
          ),

        // img uploading indicator for gallery imgs
        if(_isUploading)
          const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                  child: CircularProgressIndicator(strokeWidth: 2,))),

          _chatInput(),
        ],),
      ),
    );
  }

  // app bar
  Widget _appBar(){
    return InkWell(
      onTap: (){},
      child: StreamBuilder(stream: APIs.getUserInfo(widget.user), builder: (context, snapshot) {
        final data = snapshot.data?.docs;
        final list = data?.map((e) => ChatUser.fromJson(e.data())).toList() ?? [];



        return Row(children: [
         // back btn
         IconButton(
             onPressed: () => Navigator.pop(context),
             icon: const Icon(Icons.arrow_back_rounded, color: Colors.black,)),
         // profile picture
         ClipRRect(
           borderRadius: BorderRadius.circular(mq.height * .3),
           child: CachedNetworkImage(
             width: mq.height * .048,
             height: mq.height * .048,
             fit: BoxFit.cover,
             imageUrl: list.isNotEmpty ? list[0].image : widget.user.image,
             progressIndicatorBuilder: (context, url, downloadProgress) =>
                 CircularProgressIndicator(value: downloadProgress.progress),
             errorWidget: (context, url, error) => const CircleAvatar(child: Icon(Icons.person)),
           ),
         ),

         // sized box for space
         const SizedBox(width: 10),

         Column(
           mainAxisAlignment: MainAxisAlignment.center,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [

             // name
             Text(list.isNotEmpty ? list[0].name : widget.user.name, style: const TextStyle(
               fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87,
             ),),
             //sized box for between gap
             //  ---- const SizedBox(height: 0),  ----
             // last seen text box
             const Text('Last seen under const', style: TextStyle(
               fontSize: 10, fontWeight: FontWeight.normal, color: Colors.black54,
             ),)
           ],)

       ],);

      })   );
  }

  // bottom chat text input field
  Widget _chatInput(){
    return Padding(
      padding: EdgeInsets.symmetric(vertical: mq.height * .01, horizontal: mq.width * .025),
      child: Row(
        children: [
          Expanded(
            child: Card(
              color: Colors.yellow.shade300,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              child: Row(
                children: [
                  // emoji feature
                  IconButton(
                      onPressed: (){
                        FocusScope.of(context).unfocus();
                        setState(() => _showEmoji = !_showEmoji);
                      },
                      icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.black,)),

                  //the text input area
                  Expanded(child: TextField(
                    controller: _textController,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    onTap: () {
                      if (_showEmoji) setState(() => _showEmoji = !_showEmoji);
                    },
                    decoration: const InputDecoration(
                      hintText: 'Message', border: InputBorder.none,
                    ),
                  )),

                  //image btn to pick
                  IconButton(
                      onPressed: () async {
                        //taking multiple img
                        final ImagePicker picker = ImagePicker();
                        final List<XFile> images = await picker.pickMultiImage(imageQuality: 20);
                        // upload and send img from gallery
                        for(var i in images){
                          log('Image Path: ${i.path}');
                          setState(() => _isUploading = true);
                          await APIs.sendChatImage(widget.user, File(i.path));
                          setState(() => _isUploading = false);
                        }

                      },
                      icon: const Icon(Icons.image, color: Colors.black,)),

                  //camera btn to pick
                  IconButton(
                      onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                      // Pick an image.
                      final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 20);
                      if(image != null) {
                        log('Image Path: ${image.path}');
                        setState(() => _isUploading = true);
                        await APIs.sendChatImage(widget.user, File(image.path));
                        setState(() => _isUploading = false);
                        }
                      },
                      icon: const Icon(Icons.camera_alt, color: Colors.black,)),

                  // padding in the last for camera btn
                  SizedBox(width: mq.width * .02,),
                ],
              ),
            ),
          ),

          // sending btn
          MaterialButton(onPressed: (){
            if(_textController.text.isNotEmpty){
              APIs.sendMessage(widget.user, _textController.text, Type.text);
              _textController.text = '';
            }
          },
            padding: EdgeInsets.symmetric(vertical: mq.height * .016, horizontal: mq.width * .025),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            // height: mq.height * 0.065,
            // minWidth: mq.width * 0.18,
            color: Colors.black,
            child: const Icon(Icons.send, color: Colors.white, size: 28,),
          )
        ],
      ),
    );
  }

}

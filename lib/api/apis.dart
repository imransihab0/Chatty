import 'dart:developer';
import 'dart:io';
import 'package:chatty/models/chat_user.dart';
import 'package:chatty/models/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class APIs{
  // for authentication
  static FirebaseAuth auth = FirebaseAuth.instance;
  // for accessing cloud firestore database
  static FirebaseFirestore firestore = FirebaseFirestore.instance;
  // for accessing firebase storage to upload image
  static FirebaseStorage storage = FirebaseStorage.instance;
  // for storing my Info
  static late ChatUser me;

  //to return current user
  static User get user => auth.currentUser!;
  //for checking if user exists or not?
  static Future<void> getMyInfo() async {
    await firestore.collection('users').doc(user.uid).get().then((user) async {

      if(user.exists){
        me = ChatUser.fromJson(user.data()!);
        log('My Data: ${user.data()}');
      }else{
        await createUser().then((value) => getMyInfo());
      }
    });
  }

  //for getting current user info
  static Future<bool> userExists() async {
    return (await firestore.collection('users').doc(user.uid).get()).exists;
  }

  //for creating a new user
  static Future<void> createUser() async {
    final time = DateTime.now().millisecondsSinceEpoch.toString();
    final chatUser = ChatUser(image: user.photoURL.toString(), about: "Hey, I'm using Chatty!", name: user.displayName.toString(), createdAt: time, isOnline: false, lastActive: time, id: user.uid, email: user.email.toString(), pushToken: '');
    return await firestore.collection('users').doc(user.uid).set(chatUser.toJson());
  }

  // for getting all user from firestore database
  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllUsers(){
    return firestore.collection('users').where('id', isNotEqualTo: user.uid).snapshots();
  }

  //for updating current user info
  static Future<void> updateUserInfo() async {
    await firestore.collection('users').doc(user.uid).update({
      'name': me.name,
      'about': me.about,
    });
  }

  // for updating profile picture
  static Future<void> updateProfilePicture(File file) async {
    final ext = file.path.split('.').last;
    log('Extension: $ext');
    final ref = storage.ref().child('profile_pictures/${user.uid}.$ext');
    await ref.putFile(file, SettableMetadata(contentType: 'image/$ext')).then((p0) {
      log('Data Transferred: ${p0.bytesTransferred/1000}kb');
    });
    me.image = await ref.getDownloadURL();
    await firestore.collection('users').doc(user.uid).update({
      'image': me.image
    });
  }

  // online/offline feature related apis
  static Stream<QuerySnapshot<Map<String, dynamic>>> getUserInfo(ChatUser chatUser) {
    return firestore
        .collection('users')
        .where('id', isNotEqualTo: chatUser.id)
        .snapshots();
  }

  // for updating active status
  static Future<void> updateActiveStatus(bool isOnline) async {
    firestore
        .collection('user')
        .doc(user.uid)
        .update({
      'is_online': isOnline,
      'last_active': DateTime.now().millisecondsSinceEpoch.toString()
        });
  }

  ///****** Chat Screen Related apis ******

  // get conversation id
  static String getConversationID(String id) => user.uid.hashCode <= id.hashCode
      ? '${user.uid}_$id'
      : '${id}_${user.uid}';

  // for getting all messages of a single conversation
  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllMessages(ChatUser user){
    return firestore.collection('chats/${getConversationID(user.id)}/messages/').orderBy('sent', descending: true).snapshots();
  }

  // chats (collection) --> conversation_id (doc) --> messages (collection) --> message (doc)
  // --------------------------------------------------------------------------------------//
  // for sending msg
  static Future<void> sendMessage(ChatUser chatUser, String msg, Type type) async {

    final time = DateTime.now().millisecondsSinceEpoch.toString();
    
    final Message message = Message(toId: chatUser.id, msg: msg, read: '', type: type, sent: time, fromId: user.uid);
    
    final ref = firestore.collection('chats/${getConversationID(chatUser.id)}/messages/');
    await ref.doc(time).set(message.toJson());
  }

  // message status
  static Future<void> updateMessageReadStatus(Message message) async {
    firestore.collection('chats/${getConversationID(message.fromId)}/messages/').doc(message.sent).update({'read': DateTime.now().millisecondsSinceEpoch.toString()});
  }

  // last message
  static Stream<QuerySnapshot<Map<String, dynamic>>> getLastMessages(ChatUser user){
    return firestore.collection('chats/${getConversationID(user.id)}/messages/').orderBy('sent', descending: true).limit(1).snapshots();
  }

  // send img
  static Future<void> sendChatImage(ChatUser chatUser, File file) async {
    final ext = file.path.split('.').last;
    log('Extension: $ext');
    final ref = storage.ref().child('images/${getConversationID(chatUser.id)}/${DateTime.now().millisecondsSinceEpoch}.$ext');
    await ref.putFile(file, SettableMetadata(contentType: 'image/$ext')).then((p0) {
      log('Data Transferred: ${p0.bytesTransferred/1000}kb');
    });
    final imageUrl = await ref.getDownloadURL();
    await sendMessage(chatUser, imageUrl, Type.image);
  }

}
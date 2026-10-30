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
  static ChatUser? _me;
  static ChatUser get me =>
      _me ??
      ChatUser(
        id: auth.currentUser?.uid ?? '',
        name: auth.currentUser?.displayName ?? '',
        email: auth.currentUser?.email ?? '',
        about: "Hey, I'm using Chatty!",
        image: auth.currentUser?.photoURL ?? '',
        createdAt: '',
        isOnline: false,
        lastActive: '',
        pushToken: '',
      );
  static set me(ChatUser val) => _me = val;

  //to return current user
  static User get user => auth.currentUser!;
  //for checking if user exists or not?
  static Future<void> getMyInfo() async {
    if (auth.currentUser == null) return;
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
    if (auth.currentUser == null) return false;
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
    if (auth.currentUser == null) return;
    await firestore.collection('users').doc(user.uid).update({
      'name': me.name,
      'about': me.about,
    });
  }

  // for updating profile picture
  static Future<bool> updateProfilePicture(File file) async {
    try {
      if (auth.currentUser == null) return false;
      final ext = file.path.split('.').last;
      log('Extension: $ext');
      final ref = storage.ref().child('profile_pictures/${user.uid}.$ext');
      final p0 = await ref.putFile(file, SettableMetadata(contentType: 'image/$ext'));
      log('Data Transferred: ${p0.bytesTransferred / 1000}kb');
      me.image = await ref.getDownloadURL();
      await firestore.collection('users').doc(user.uid).update({
        'image': me.image
      });
      return true;
    } catch (e) {
      log('Error updateProfilePicture: $e');
      return false;
    }
  }

  // online/offline feature related apis
  static Stream<QuerySnapshot<Map<String, dynamic>>> getUserInfo(ChatUser chatUser) {
    return firestore
        .collection('users')
        .where('id', isEqualTo: chatUser.id)
        .snapshots();
  }

  // for updating active status
  static Future<void> updateActiveStatus(bool isOnline) async {
    if (auth.currentUser == null) return;
    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'is_online': isOnline,
        'last_active': DateTime.now().millisecondsSinceEpoch.toString()
      });
    } catch (e) {
      log('Error updateActiveStatus: $e');
    }
  }

  ///****** Chat Screen Related apis ******

  // get conversation id
  static String getConversationID(String id) {
    final myId = auth.currentUser?.uid ?? '';
    return myId.hashCode <= id.hashCode
        ? '${myId}_$id'
        : '${id}_$myId';
  }

  // for getting all messages of a single conversation
  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllMessages(ChatUser user){
    return firestore.collection('chats/${getConversationID(user.id)}/messages/').orderBy('sent', descending: true).snapshots();
  }

  // chats (collection) --> conversation_id (doc) --> messages (collection) --> message (doc)
  // --------------------------------------------------------------------------------------//
  // for sending msg
  static Future<bool> sendMessage(ChatUser chatUser, String msg, Type type) async {
    try {
      if (auth.currentUser == null) return false;
      final time = DateTime.now().millisecondsSinceEpoch.toString();
      
      final Message message = Message(
          toId: chatUser.id,
          msg: msg,
          read: '',
          type: type,
          sent: time,
          fromId: user.uid);
      
      final ref = firestore.collection('chats/${getConversationID(chatUser.id)}/messages/');
      await ref.doc(time).set(message.toJson());
      return true;
    } catch (e) {
      log('Error sendMessage: $e');
      return false;
    }
  }

  // message status
  static Future<void> updateMessageReadStatus(Message message) async {
    try {
      await firestore
          .collection('chats/${getConversationID(message.fromId)}/messages/')
          .doc(message.sent)
          .update({'read': DateTime.now().millisecondsSinceEpoch.toString()});
    } catch (e) {
      log('Error updateMessageReadStatus: $e');
    }
  }

  // last message
  static Stream<QuerySnapshot<Map<String, dynamic>>> getLastMessages(ChatUser user){
    return firestore.collection('chats/${getConversationID(user.id)}/messages/').orderBy('sent', descending: true).limit(1).snapshots();
  }

  // send img
  static Future<bool> sendChatImage(ChatUser chatUser, File file) async {
    try {
      final ext = file.path.split('.').last;
      log('Extension: $ext');
      final ref = storage.ref().child('images/${getConversationID(chatUser.id)}/${DateTime.now().millisecondsSinceEpoch}.$ext');
      final p0 = await ref.putFile(file, SettableMetadata(contentType: 'image/$ext'));
      log('Data Transferred: ${p0.bytesTransferred / 1000}kb');
      final imageUrl = await ref.getDownloadURL();
      await sendMessage(chatUser, imageUrl, Type.image);
      return true;
    } catch (e) {
      log('Error sendChatImage: $e');
      return false;
    }
  }

  // delete message
  static Future<void> deleteMessage(Message message) async {
    try {
      await firestore
          .collection('chats/${getConversationID(message.toId)}/messages/')
          .doc(message.sent)
          .delete();

      if (message.type == Type.image) {
        await storage.refFromURL(message.msg).delete().catchError((_) {});
      }
    } catch (e) {
      log('Error deleteMessage: $e');
    }
  }

  // edit message
  static Future<void> updateMessage(Message message, String updatedMsg) async {
    try {
      await firestore
          .collection('chats/${getConversationID(message.toId)}/messages/')
          .doc(message.sent)
          .update({'msg': updatedMsg});
    } catch (e) {
      log('Error updateMessage: $e');
    }
  }

  // search users across entire Firestore database
  static Future<List<ChatUser>> searchUsers(String query) async {
    try {
      final cleanQuery = query.trim().toLowerCase();
      if (cleanQuery.isEmpty) return [];

      final snapshot = await firestore
          .collection('users')
          .where('id', isNotEqualTo: auth.currentUser?.uid ?? '')
          .get();

      return snapshot.docs
          .map((e) => ChatUser.fromJson(e.data()))
          .where((u) =>
              u.name.toLowerCase().contains(cleanQuery) ||
              u.email.toLowerCase().contains(cleanQuery) ||
              u.about.toLowerCase().contains(cleanQuery))
          .toList();
    } catch (e) {
      log('Error searchUsers: $e');
      return [];
    }
  }

}
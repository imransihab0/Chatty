import 'dart:developer';
import 'dart:io';
import 'dart:math' show Random;
import 'package:chatty/models/chat_user.dart';
import 'package:chatty/models/message.dart';
import 'package:chatty/services/conversation_controller.dart';
import 'package:chatty/services/image_compressor.dart';
import 'package:chatty/services/r2_storage_service.dart';
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
  static User? get currentUser => auth.currentUser;
  static User get user => auth.currentUser!;
  static String get myUid => auth.currentUser?.uid ?? '';

  //for checking if user exists or not?
  static Future<void> getMyInfo() async {
    final curUser = auth.currentUser;
    if (curUser == null) return;
    try {
      final doc = await firestore.collection('users').doc(curUser.uid).get();
      if (doc.exists && doc.data() != null) {
        me = ChatUser.fromJson(doc.data()!);
        log('My Data: ${doc.data()}');
      } else {
        await createUser();
        await getMyInfo();
      }
    } catch (e) {
      log('Error getMyInfo: $e');
    }
  }

  //for getting current user info
  static Future<bool> userExists() async {
    final curUser = auth.currentUser;
    if (curUser == null) return false;
    try {
      final doc = await firestore.collection('users').doc(curUser.uid).get();
      return doc.exists;
    } catch (e) {
      log('Error userExists: $e');
      return false;
    }
  }

  // Check if a username is available (unique in Firestore)
  static Future<bool> isUsernameAvailable(String username) async {
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    if (clean.length < 3 || clean.length > 20) return false;
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(clean)) return false;

    try {
      final snap = await firestore
          .collection('users')
          .where('username', isEqualTo: clean)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return true;
      return snap.docs.first.id == (auth.currentUser?.uid ?? '');
    } catch (e) {
      log('Error isUsernameAvailable: $e');
      return false;
    }
  }

  // Generates a random unique username fallback
  static Future<String> generateUniqueUsername(String? base) async {
    String clean = (base ?? 'user')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (clean.isEmpty) clean = 'user';
    if (clean.length > 14) clean = clean.substring(0, 14);

    if (await isUsernameAvailable(clean)) return clean;

    final random = Random();
    for (int i = 0; i < 20; i++) {
      final candidate = '${clean}_${random.nextInt(9000) + 1000}';
      if (await isUsernameAvailable(candidate)) return candidate;
    }

    return 'user_${DateTime.now().millisecondsSinceEpoch % 1000000}';
  }

  //for creating a new user with optional chosen username
  static Future<void> createUser({String? chosenUsername}) async {
    final curUser = auth.currentUser;
    if (curUser == null) return;
    try {
      final time = DateTime.now().millisecondsSinceEpoch.toString();
      String rawName = (curUser.displayName != null &&
              curUser.displayName!.trim().isNotEmpty)
          ? curUser.displayName!.trim()
          : (curUser.email?.split('@').first ?? 'User');
      if (rawName.length > 25) rawName = rawName.substring(0, 25);

      String finalUsername = chosenUsername
              ?.trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9_]'), '') ??
          '';
      if (finalUsername.isEmpty ||
          !(await isUsernameAvailable(finalUsername))) {
        finalUsername = await generateUniqueUsername(
            curUser.email?.split('@').first);
      }

      final chatUser = ChatUser(
        image: curUser.photoURL ?? '',
        about: "Hey, I'm using Chatty!",
        name: rawName,
        createdAt: time,
        isOnline: true,
        lastActive: time,
        id: curUser.uid,
        email: curUser.email ?? '',
        pushToken: '',
        username: finalUsername,
      );
      await firestore
          .collection('users')
          .doc(curUser.uid)
          .set(chatUser.toJson());
      me = chatUser;
    } catch (e) {
      log('Error createUser: $e');
    }
  }

  // for updating username
  static Future<bool> updateUsername(String newUsername) async {
    final clean = newUsername.trim().toLowerCase().replaceAll('@', '');
    if (!(await isUsernameAvailable(clean))) return false;
    if (auth.currentUser == null) return false;

    try {
      await firestore.collection('users').doc(user.uid).update({
        'username': clean,
      });
      me.username = clean;
      return true;
    } catch (e) {
      log('Error updateUsername: $e');
      return false;
    }
  }

  // for getting all user from firestore database
  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllUsers() {
    final myUid = auth.currentUser?.uid ?? '';
    return firestore
        .collection('users')
        .where('id', isNotEqualTo: myUid)
        .snapshots();
  }

  //for updating current user info
  static Future<void> updateUserInfo() async {
    if (auth.currentUser == null) return;
    if (me.name.length > 25) me.name = me.name.substring(0, 25);
    await firestore.collection('users').doc(user.uid).update({
      'name': me.name,
      'about': me.about,
    });
  }

  // for updating profile picture
  static Future<bool> updateProfilePicture(File file) async {
    try {
      if (auth.currentUser == null) return false;

      // 1. If Cloudflare R2 is configured, upload to R2
      if (R2StorageService.isConfigured) {
        final r2Url =
            await R2StorageService.uploadProfilePicture(file, user.uid);
        if (r2Url != null) {
          me.image = r2Url;
          await firestore
              .collection('users')
              .doc(user.uid)
              .update({'image': me.image});
          return true;
        }
      }

      // 2. Otherwise compress and fallback to Firebase Storage
      final compressed = await ImageCompressor.compressUnder100Kb(file);
      final ext = compressed.path.split('.').last;
      log('Extension: $ext');
      final ref = storage.ref().child('profile_pictures/${user.uid}.$ext');
      final p0 =
          await ref.putFile(compressed, SettableMetadata(contentType: 'image/$ext'));
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

  // update live typing indicator in conversation
  static Future<void> updateTypingStatus(ChatUser chatUser, bool isTyping) async {
    if (auth.currentUser == null) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await firestore
          .collection('chats')
          .doc(getConversationID(chatUser.id))
          .set({
        'typing_${user.uid}': isTyping,
        'typing_time_${user.uid}': now,
        'typing_time': now,
      }, SetOptions(merge: true));
    } catch (e) {
      log('Error updateTypingStatus: $e');
    }
  }

  // stream conversation metadata (e.g., typing indicator)
  static Stream<DocumentSnapshot<Map<String, dynamic>>> getChatMeta(ChatUser chatUser) {
    return firestore
        .collection('chats')
        .doc(getConversationID(chatUser.id))
        .snapshots();
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
  static Future<bool> sendMessage(ChatUser chatUser, String msg, Type type,
      {String replyMsg = '', String replyUser = ''}) async {
    try {
      if (auth.currentUser == null) return false;
      final time = DateTime.now().millisecondsSinceEpoch.toString();

      final Message message = Message(
          toId: chatUser.id,
          msg: msg,
          read: '',
          type: type,
          sent: time,
          fromId: user.uid,
          replyMsg: replyMsg,
          replyUser: replyUser);

      final convoId = getConversationID(chatUser.id);
      final ref = firestore.collection('chats/$convoId/messages/');
      await ref.doc(time).set(message.toJson());

      // Update conversation metadata on the parent document
      await firestore.collection('chats').doc(convoId).set({
        'last_message_time': time,
        'last_message': msg,
        'last_message_type': type.name,
        'last_from_id': user.uid,
      }, SetOptions(merge: true));

      // Record connection between both users in Firestore
      firestore
          .collection('users')
          .doc(user.uid)
          .collection('my_users')
          .doc(chatUser.id)
          .set({'connected_at': time}, SetOptions(merge: true))
          .catchError((_) {});
      firestore
          .collection('users')
          .doc(chatUser.id)
          .collection('my_users')
          .doc(user.uid)
          .set({'connected_at': time}, SetOptions(merge: true))
          .catchError((_) {});

      // Optimistically update conversation controller for instant reordering and filter updates
      ConversationController.updateLastMessage(chatUser.id, message);

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
      final convoId = getConversationID(chatUser.id);

      // 1. If Cloudflare R2 is configured, compress and upload to R2
      if (R2StorageService.isConfigured) {
        final r2Url = await R2StorageService.uploadChatImage(file, convoId);
        if (r2Url != null) {
          await sendMessage(chatUser, r2Url, Type.image);
          return true;
        }
      }

      // 2. Otherwise compress and fallback to Firebase Storage
      final compressed = await ImageCompressor.compressUnder100Kb(file);
      final ext = compressed.path.split('.').last;
      log('Extension: $ext');
      final ref = storage.ref().child('images/$convoId/${DateTime.now().millisecondsSinceEpoch}.$ext');
      final p0 = await ref.putFile(compressed, SettableMetadata(contentType: 'image/$ext'));
      log('Data Transferred: ${p0.bytesTransferred / 1000}kb');
      final imageUrl = await ref.getDownloadURL();
      await sendMessage(chatUser, imageUrl, Type.image);
      return true;
    } catch (e) {
      log('Error sendChatImage: $e');
      return false;
    }
  }

  // send voice note
  static Future<bool> sendVoiceNote(
      ChatUser chatUser, File audioFile, int durationMs) async {
    try {
      final convoId = getConversationID(chatUser.id);
      String? audioUrl;

      // 1. If Cloudflare R2 is configured, upload to R2
      if (R2StorageService.isConfigured) {
        audioUrl = await R2StorageService.uploadVoiceNote(audioFile, convoId);
      }

      // 2. Otherwise fallback to Firebase Storage
      if (audioUrl == null) {
        final ext = audioFile.path.split('.').last;
        log('Voice note extension: $ext');
        final ref = storage.ref().child(
            'audio/$convoId/${DateTime.now().millisecondsSinceEpoch}.$ext');
        final p0 = await ref.putFile(
            audioFile, SettableMetadata(contentType: 'audio/$ext'));
        log('Voice note uploaded: ${p0.bytesTransferred / 1000}kb');
        audioUrl = await ref.getDownloadURL();
      }

      // Send as audio message with duration stored in Firestore
      if (auth.currentUser == null) return false;
      final time = DateTime.now().millisecondsSinceEpoch.toString();
      final Message message = Message(
        toId: chatUser.id,
        msg: audioUrl,
        read: '',
        type: Type.audio,
        sent: time,
        fromId: user.uid,
        durationMs: durationMs,
      );

      final msgRef = firestore.collection('chats/$convoId/messages/');
      await msgRef.doc(time).set(message.toJson());

      await firestore.collection('chats').doc(convoId).set({
        'last_message_time': time,
        'last_message': '🎙️ Voice note',
        'last_message_type': Type.audio.name,
        'last_from_id': user.uid,
      }, SetOptions(merge: true));

      ConversationController.updateLastMessage(chatUser.id, message);

      // Clean up local temporary file after upload
      if (await audioFile.exists()) {
        try {
          await audioFile.delete();
        } catch (_) {}
      }

      return true;
    } catch (e) {
      log('Error sendVoiceNote: $e');
      return false;
    }
  }

  // delete message
  static Future<void> deleteMessage(Message message) async {
    try {
      final otherId =
          message.fromId == (auth.currentUser?.uid ?? '') ? message.toId : message.fromId;
      await firestore
          .collection('chats/${getConversationID(otherId)}/messages/')
          .doc(message.sent)
          .delete();

      if (message.type == Type.image || message.type == Type.audio) {
        if (message.msg.contains('r2.dev') ||
            message.msg.contains('cloudflarestorage.com') ||
            (R2StorageService.isConfigured &&
                message.msg.contains(R2StorageService.publicDomain))) {
          await R2StorageService.deleteObject(message.msg);
        } else {
          await storage.refFromURL(message.msg).delete().catchError((_) {});
        }
      }
    } catch (e) {
      log('Error deleteMessage: $e');
    }
  }

  // edit message
  static Future<void> updateMessage(Message message, String updatedMsg) async {
    try {
      final otherId =
          message.fromId == (auth.currentUser?.uid ?? '') ? message.toId : message.fromId;
      await firestore
          .collection('chats/${getConversationID(otherId)}/messages/')
          .doc(message.sent)
          .update({'msg': updatedMsg});
    } catch (e) {
      log('Error updateMessage: $e');
    }
  }

  // set or toggle emoji reaction on a message
  static Future<void> setMessageReaction(
      Message message, String reaction) async {
    try {
      final otherId =
          message.fromId == user.uid ? message.toId : message.fromId;
      final newReaction = message.reaction == reaction ? '' : reaction;
      await firestore
          .collection('chats/${getConversationID(otherId)}/messages/')
          .doc(message.sent)
          .update({'reaction': newReaction});
    } catch (e) {
      log('Error setMessageReaction: $e');
    }
  }

  // delete entire conversation with a user
  static Future<bool> deleteConversation(ChatUser chatUser) async {
    try {
      final convoId = getConversationID(chatUser.id);
      final messages = await firestore
          .collection('chats/$convoId/messages/')
          .get();
      for (final doc in messages.docs) {
        final data = doc.data();
        final type = data['type']?.toString();
        final msg = data['msg']?.toString() ?? '';
        if (type == Type.image.name || type == Type.audio.name) {
          if (msg.contains('r2.dev') ||
              msg.contains('cloudflarestorage.com') ||
              (R2StorageService.isConfigured &&
                  msg.contains(R2StorageService.publicDomain))) {
            await R2StorageService.deleteObject(msg);
          } else {
            await storage.refFromURL(msg).delete().catchError((_) {});
          }
        }
        await doc.reference.delete();
      }
      ConversationController.setLastMessageTime(chatUser.id, 0);
      return true;
    } catch (e) {
      log('Error deleteConversation: $e');
      return false;
    }
  }

  // mark all incoming unread messages in a conversation as read
  static Future<void> markConversationAsRead(ChatUser chatUser) async {
    try {
      final convoId = getConversationID(chatUser.id);
      final unreadDocs = await firestore
          .collection('chats/$convoId/messages/')
          .where('fromId', isEqualTo: chatUser.id)
          .where('read', isEqualTo: '')
          .get();
      final now = DateTime.now().millisecondsSinceEpoch.toString();
      for (final doc in unreadDocs.docs) {
        await doc.reference.update({'read': now});
      }
      ConversationController.markRead(chatUser.id);
    } catch (e) {
      log('Error markConversationAsRead: $e');
    }
  }

  // Search users across entire Firestore database strictly by username (@handle) or email
  static Future<List<ChatUser>> searchUsers(String query) async {
    try {
      final raw = query.trim().toLowerCase();
      final cleanQuery = raw.replaceAll('@', '');
      if (cleanQuery.isEmpty) return [];

      final snapshot = await firestore
          .collection('users')
          .where('id', isNotEqualTo: auth.currentUser?.uid ?? '')
          .get();

      return snapshot.docs
          .map((e) => ChatUser.fromJson(e.data()))
          .where((u) {
            final username = u.username.toLowerCase();
            final email = u.email.toLowerCase();
            final emailPrefix =
                email.contains('@') ? email.split('@').first : email;

            // User must connect via unique @username or email address
            return username == cleanQuery ||
                username.startsWith(cleanQuery) ||
                username.contains(cleanQuery) ||
                email == raw ||
                email == cleanQuery ||
                email.startsWith(raw) ||
                emailPrefix == cleanQuery;
          })
          .toList();
    } catch (e) {
      log('Error searchUsers: $e');
      return [];
    }
  }

}
import 'dart:developer';
import 'dart:io';
// import 'dart:math';

import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/dialogs.dart';
import 'package:chatty/main.dart';
import 'package:chatty/screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  _handleGoogleBtnClick(){
    Dialogs.showProgressbar(context, color: Colors.amberAccent);
    _signInWithGoogle().then((user) async {

      Navigator.pop(context);

      if(user != null){
        log('\nUser: ${user.user}');
        log('\nUserAdditionalInfo: ${user.additionalUserInfo}');

        if((await APIs.userExists())){
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }else{
          await APIs.createUser().then((value) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
          });
        }


      }
    });
  }

  Future<UserCredential?> _signInWithGoogle() async {
    try {
      await InternetAddress.lookup('google.com');
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // Obtain the auth details from the request
      final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      // Once signed in, return the UserCredential
      return await APIs.auth.signInWithCredential(credential);
    } catch (e) {
      log('\n_signInWithGoogle: $e');
      Dialogs.showSnackbar(context, 'Something went wrong, check your internet connection!');
      return null;
    }
  }


  @override
  Widget build(BuildContext context) {
    // mq = MediaQuery.of(context).size;

    return Scaffold(
      //app bar start here
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Welcome to Chatty', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),),
      ),

      body: Stack(children: [
        Positioned(
            top: mq.height * .15,
            left: mq.width * .25,
            width: mq.width * .5,
            child: Image.asset('images/icon.png')),
        Positioned(
            bottom: mq.height * .15,
            left: mq.width * .05,
            width: mq.width * .9,
            height: mq.height * .07,
            child: ElevatedButton.icon(style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white60,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5.0),
              ),
            ),onPressed: (){
              _handleGoogleBtnClick();
            }, icon: Image.asset('images/google.png', height: mq.height * .045), label: const Text('Sign in with Google', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black,
            ),))),
      ],),

    );
  }
}
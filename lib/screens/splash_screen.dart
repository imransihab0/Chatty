import 'dart:developer';
import 'package:chatty/api/apis.dart';
import 'package:chatty/main.dart';
import 'package:chatty/screens/auth/login_screen.dart';
import 'package:chatty/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


// splash Splash Screen

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 3000), (){
      // exit full screen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(systemNavigationBarColor: Colors.white, statusBarColor: Colors.white));
      if(APIs.auth.currentUser != null){
        log('\nUser: ${APIs.auth.currentUser}');
        // navigate to home screen
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }else{
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    mq = MediaQuery.of(context).size;

    return Scaffold(
      //app bar start here
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Welcome to Chatty', textAlign: TextAlign.center, style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 24.0, color: Colors.black, wordSpacing: 3.5, letterSpacing: 0,
        ),),
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
            child: const Text("by Imran Shihab X FerTech", textAlign: TextAlign.center, style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 17.0, color: Colors.black, wordSpacing: 3.5, letterSpacing: 0,
            ),
              maxLines: 2, // Set the maximum number of lines
              overflow: TextOverflow.ellipsis, // Specify the overflow behavior
            ),
        )],),

    );
  }
}
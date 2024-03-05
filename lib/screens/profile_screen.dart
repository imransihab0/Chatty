import 'dart:developer';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/dialogs.dart';
import 'package:chatty/main.dart';
import 'package:chatty/models/chat_user.dart';
import 'package:chatty/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

// profile screen, to show sign in user info

class ProfileScreen extends StatefulWidget {

  final ChatUser user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  final _formKey = GlobalKey<FormState>();
  String ? _image;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        //app bar start here
        appBar: AppBar(
          title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Lexend'),),
        ),
        // floating button to logout
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FloatingActionButton.extended(
            backgroundColor: Colors.white,
            onPressed: () async {
              //for showing progress circle
            Dialogs.showProgressbar(context);
            await APIs.auth.signOut().then((value) async {
              await GoogleSignIn().signOut().then((value) {
                // for hiding progress circle
                Navigator.pop(context);
                // for moving to home screen
                Navigator.pop(context);
                // navigate to login screen
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              });
            });
          }, icon: const Icon(Icons.logout_outlined), label: const Text('Logout',style: TextStyle(
            color: Colors.black
          ),),),
        ),
        body: Form(
          key: _formKey,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: mq.width * .05),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // for adding space from side and up
                  SizedBox(width: mq.width, height: mq.height * .03,),
                  Stack(
                    children: [

                      // local image from device
                      _image != null ?
                      ClipRRect(
                        borderRadius: BorderRadius.circular(mq.height * .3),
                        child: Image.file(
                          File(_image!),
                          width: mq.height * .2,
                          height: mq.height * .2,
                          fit: BoxFit.cover,
                          
                        ),
                      )
                          :

                      // profile picture (from firebase server)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(mq.height * .3),
                        child: CachedNetworkImage(
                          width: mq.height * .2,
                          height: mq.height * .2,
                          fit: BoxFit.cover,
                          imageUrl: widget.user.image,
                          progressIndicatorBuilder: (context, url, downloadProgress) =>
                              CircularProgressIndicator(value: downloadProgress.progress),
                          errorWidget: (context, url, error) => const CircleAvatar(child: Icon(Icons.person)),
                        ),
                      ),
                      // image editing btn
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: MaterialButton(onPressed: (){
                          _showBottomSheet();
                        },
                          elevation: 1,
                          shape: const CircleBorder(),
                          color: Colors.white,
                          child: const Icon(Icons.edit, color: Colors.black,)
                          ,),
                      )
                    ],
                  ),
                  // for adding space from side and uo
                  SizedBox(width: mq.width, height: mq.height * .03),
                  Text(widget.user.email, style: const TextStyle(color: Colors.black54, fontSize: 16),),


                  // name Field
                  SizedBox(width: mq.width, height: mq.height * .05),
                  TextFormField(
                    initialValue: widget.user.name,
                    onSaved: (val) => APIs.me.name = val ?? '',
                    validator: (val) => val != null && val.isNotEmpty ? null: 'Required Field',
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                      hintText: 'eg. Imran Sihab',
                      labelText: 'Name',
                      // contentPadding: EdgeInsets.fromLTRB(12, 16, 12, 8),
                    ),
                  ),


                  // about Field
                  SizedBox(width: mq.width, height: mq.height * .02),
                  TextFormField(
                    initialValue: widget.user.about,
                    onSaved: (val) => APIs.me.about = val ?? '',
                    validator: (val) => val != null && val.isNotEmpty ? null: 'Required Field',
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.info_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                      hintText: "eg. Hey, I'm using Chatty!",
                      labelText: 'About',
                      // contentPadding: EdgeInsets.fromLTRB(12, 16, 12, 8),
                    ),
                  ),
          
                  SizedBox(width: mq.width, height: mq.height * .02),
                  SizedBox(
                      width: double.infinity,
                      height: mq.height * .05,
                      child: ElevatedButton.icon(onPressed: (){
                        if(_formKey.currentState!.validate()){
                          _formKey.currentState!.save();
                          APIs.updateUserInfo().then((value){
                            Dialogs.showSnackbar(context, 'Profile Updated Successfully!');
                          });
                        }
                      }, icon: const Icon(Icons.edit_note, color: Colors.white,), label: const Text(
                          'UPDATE YOUR INFO',
                        style: TextStyle(color: Colors.white),
                      ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7)
                          ),
                          backgroundColor: Colors.black,
                        ),
                      )
                  )
                ],
              ),
            ),
          ),
        )
      ),
    );
  }

  // bottom sheet for taking image for profile picture
  void _showBottomSheet(){
    showModalBottomSheet(context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))),
        builder: (_){
      return ListView(
        shrinkWrap: true,
        padding: EdgeInsets.only(top: mq.height * .03, bottom: mq.height * .1),
        children: [
          const Text('Profile picture', textAlign: TextAlign.center, style: TextStyle(
            fontSize: 23, fontWeight: FontWeight.w500,
          )),

          //for adding space between buttons and title
          SizedBox(height: mq.height * .02),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // for gallery
              ElevatedButton
            (
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                fixedSize: Size(mq.width * .3, mq.height * .15),
              ),
              onPressed: () async {
                final ImagePicker picker = ImagePicker();
                // Pick an image.
                final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 10);
                if(image != null){
                  log('Image Path: ${image.path} -- MimeType: ${image.mimeType}');
                  setState(() {
                    _image = image.path;
                  });

                  APIs.updateProfilePicture(File(_image!));
                  // profile picture piking sheet hiding
                  Navigator.pop(context);
                }
              }, child: Image.asset('images/add_image.png')),

              // for camera
              ElevatedButton
                (
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    fixedSize: Size(mq.width * .3, mq.height * .15),
                  ),
                  onPressed: () async {
                    final ImagePicker picker = ImagePicker();
                    // Pick an image.
                    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 10);
                    if(image != null){
                      log('Image Path: ${image.path}');
                      setState(() {
                        _image = image.path;
                      });

                      APIs.updateProfilePicture(File(_image!));
                      // profile picture piking sheet hiding
                      Navigator.pop(context);
                    }
                  }, child: Image.asset('images/camera.png')),

            ],
          )
        ],
      );
    });
  }

}
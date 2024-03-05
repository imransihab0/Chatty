import 'package:chatty/api/apis.dart';
import 'package:chatty/main.dart';
import 'package:chatty/models/chat_user.dart';
import 'package:chatty/screens/profile_screen.dart';
import 'package:chatty/widgets/chat_user_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ChatUser> _list = [];
  final List<ChatUser> _searchList = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    APIs.getMyInfo();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // for hiding the keyboard on tapping anywhere of the screen
      onTap: () => FocusScope.of(context).unfocus(),
      child: WillPopScope(
        onWillPop: (){
          if(_isSearching){
            setState(() {
              _isSearching = !_isSearching;
            });
            return Future.value(false);
          }else{
            return Future.value(true);
          }
        },
        child: Scaffold(
          //app bar start here
          appBar: AppBar(
            leading: const Icon(Icons.home_max_rounded),
            title: _isSearching ?
                TextField(
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search...',
                  ),
                  autofocus: true,
                  // update search list when search text changing
                  onChanged: (val){
                  // logic for search feature
                    _searchList.clear();

                    for(var i in _list){
                      if(i.name.toLowerCase().contains(val.toLowerCase()) || i.email.toLowerCase().contains(val.toLowerCase())){
                        _searchList.add(i);
                      }
                      setState(() {
                        _searchList;
                      });
                    }
                  },
                )
                : const Text('Chatty', style: TextStyle(fontWeight: FontWeight.normal,
                fontSize: 20,
                fontFamily: 'Lexend',
            ),),
            actions: [
              // search user button
              IconButton(onPressed: (){
                setState(() {
                  _isSearching = !_isSearching;
                });
              }, icon: Icon(_isSearching ? CupertinoIcons.clear_fill : Icons.person_search)),
              // more features button (3 dot btn in the corner man!)
              IconButton(onPressed: (){
                Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(user: APIs.me)));
              }, icon: const Icon(Icons.more_vert)),
            ],
          ),
          // floating button to add new user
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FloatingActionButton(onPressed: () {},
                backgroundColor: Color(0xffdedede),
                  child: const Icon(Icons.add_comment_sharp)),
          ),
          body: StreamBuilder(
            stream: APIs.getAllUsers(),
            builder: (context, snapshot){
              switch(snapshot.connectionState){
                //if data is loading
                case ConnectionState.waiting:
                case ConnectionState.none:
                  return const Center(child: CircularProgressIndicator());

                //if some or all data is loaded then show it
                case ConnectionState.active:
                case ConnectionState.done:
                  final data = snapshot.data?.docs;
                  _list = data?.map((e) => ChatUser.fromJson(e.data())).toList() ?? [];

                  if(_list.isNotEmpty){
                    return ListView.builder(
                        itemCount: _isSearching ? _searchList.length : _list.length,
                        padding: EdgeInsets.only(top: mq.height * .01),
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index){
                          return ChatUserCard(user: _isSearching ? _searchList[index] : _list[index]);
                          // return Text('Name: ${list[index]}');
                        });
                  }else{
                    return const Center(child: Text('No Friends Found', style: TextStyle(fontSize: 24, letterSpacing: 0, fontWeight: FontWeight.normal),));
                  }
              }
            },
          ),
        ),
      ),
    );
  }
}
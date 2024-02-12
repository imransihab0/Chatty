import 'package:flutter/material.dart';

class Dialogs{
  static void showSnackbar(BuildContext context, String msg){
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static void showProgressbar(BuildContext context, {Color? color}) {
    showDialog(
      context: context,
      builder: (_) => Center(
        child: CircularProgressIndicator(
          valueColor: color != null ? AlwaysStoppedAnimation<Color>(color) : null,
        ),
      ),
    );
  }

}
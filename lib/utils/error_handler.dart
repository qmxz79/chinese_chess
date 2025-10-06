import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ErrorHandler {
  static void handleError(BuildContext context, dynamic error) {
    if (kDebugMode) {
      print('Error occurred: $error');
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('发生错误: ${error.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
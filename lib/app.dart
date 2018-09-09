import 'package:flutter/material.dart';
import 'page.dart';

class JukephoneApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jukephone',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      home: JukephonePage(
        origin: Uri.http('jukephone.gerhut.me', '/')
      ),
    );
  }
}

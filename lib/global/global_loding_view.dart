import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoadingView extends GetView {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("加载中..."),
      ),
    );
  }
}
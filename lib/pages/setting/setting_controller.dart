import 'package:bujuan/global/global_config.dart';
import 'package:bujuan/global/global_theme.dart';
import 'package:bujuan/pages/home/home_controller.dart';
import 'package:bujuan/utils/bujuan_util.dart';
import 'package:bujuan/utils/sp_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:starry/starry.dart';

class SettingController extends GetxController {
  var isDark = Get.isDarkMode.obs;
  var isSystemTheme = true.obs;
  var isIgnoreAudioFocus = false.obs;

  @override
  void onReady() {
    isIgnoreAudioFocus.value = SpUtil.getBool(IS_IGNORE_AUDIO_FOCUS, defValue: false);
    isSystemTheme.value = SpUtil.getBool(IS_SYSTEM_THEME_SP, defValue: true);
    super.onReady();
  }

  changeTheme(isSystem, {value}){
    if (isSystem) {
      if (!isSystemTheme.value) {
        isSystemTheme.value = true;
        SpUtil.putBool(IS_SYSTEM_THEME_SP, true);
        Get.find<HomeController>()
            .isSystemTheme
            .value = true;
        Get.find<HomeController>().didChangePlatformBrightness();
      }
    } else {
      isDark.value = value;
      isSystemTheme.value = false;
      SpUtil.putBool(IS_SYSTEM_THEME_SP, false);
        Get.changeTheme(!value ? lightTheme : darkTheme);
        Future.delayed(Duration(milliseconds: 300), () {
          SystemChrome.setSystemUIOverlayStyle(BuJuanUtil.setNavigationBarTextColor(Get.isDarkMode));
          SpUtil.putBool(IS_DARK_SP, value);
        });
    }
    Future.delayed(Duration(milliseconds: 300), ()=>Get.back());
  }

  bool isDarkTheme(){
    return isSystemTheme.value?Get.isPlatformDarkMode:Get.isDarkMode;
  }
  toggleAudioFocus(value) async {
    isIgnoreAudioFocus.value = value;
    var i = await Starry.toggleAudioFocus(value);
    if (i == 1) {
      SpUtil.putBool(IS_IGNORE_AUDIO_FOCUS, value);
    }
  }

  exit() {
    Get.defaultDialog(
        radius: 6.0,
        title: '退出登录',
        content: Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Text('退出之后部分功能无法正常使用！')),
        textCancel: '迷途知返',
        textConfirm: '一意孤行',
        buttonColor: Colors.transparent,
        onConfirm: () {
          SpUtil.putString(USER_ID_SP, '');
          Get
              .find<HomeController>()
              .login
              .value = false;
          Get.find<HomeController>().changeIndex(1);
          Get.back();
          Get.back();
        });
  }
}
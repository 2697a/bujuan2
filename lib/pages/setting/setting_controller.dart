import 'package:bujuan/global/global_config.dart';
import 'package:bujuan/global/global_theme.dart';
import 'package:bujuan/pages/home/home_controller.dart';
import 'package:bujuan/utils/bujuan_util.dart';
import 'package:bujuan/utils/sp_util.dart';
import 'package:bujuan/widget/preload_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:starry/starry.dart';

class SettingController extends GetxController {
  var isDark = Get.isDarkMode.obs;
  var isSystemTheme = true.obs;
  var isIgnoreAudioFocus = false.obs;
  var firstIndex = 1.obs;
  final quality = '128000'.obs;
  PreloadPageController pageController;
  var playViewIndex = 0;

  @override
  void onInit() {
    var initialPage2 = SpUtil.getBool(SECOND_PLAY_VIEW, defValue: false) ? 1 : 0;
    playViewIndex = initialPage2;
    pageController = PreloadPageController(
        viewportFraction: .8,
        initialPage: initialPage2);
    quality.value = SpUtil.getString(QUALITY, defValue: '128000');
    firstIndex.value = SpUtil.getInt(HOME_INDEX, defValue: 1);
    super.onInit();
  }

  @override
  void onReady() {
    isIgnoreAudioFocus.value =
        SpUtil.getBool(IS_IGNORE_AUDIO_FOCUS, defValue: false);
    isSystemTheme.value = SpUtil.getBool(IS_SYSTEM_THEME_SP, defValue: true);
    super.onReady();
  }

  changeTheme(isSystem, {value}) {
    if (isSystem) {
      if (!isSystemTheme.value) {
        isSystemTheme.value = true;
        SpUtil.putBool(IS_SYSTEM_THEME_SP, true);
        HomeController.to.isSystemTheme.value = true;
        Get.changeThemeMode(ThemeMode.system);
        Get.find<HomeController>().didChangePlatformBrightness();
      }
    } else {
      isDark.value = value;
      isSystemTheme.value = false;
      SpUtil.putBool(IS_SYSTEM_THEME_SP, false);
      Get.changeThemeMode(isDark.value ? ThemeMode.dark : ThemeMode.light);
      SpUtil.putBool(IS_DARK_SP, isDark.value);
      Get.changeTheme(!value ? lightTheme : darkTheme);
      Future.delayed(Duration(milliseconds: 300), () {
        SystemChrome.setSystemUIOverlayStyle(
            BuJuanUtil.setNavigationBarTextColor(isDark.value));
        SpUtil.putBool(IS_DARK_SP, value);
      });
    }
    Future.delayed(Duration(milliseconds: 300), () => Get.back());
  }

  changeQuality(qualityData) {
    quality.value = qualityData;
    SpUtil.putString(QUALITY, qualityData);
    Get.back();
  }

  toggleAudioFocus(value) async {
    isIgnoreAudioFocus.value = value;
    var i = await Starry.toggleAudioFocus(value);
    if (i == 1) {
      SpUtil.putBool(IS_IGNORE_AUDIO_FOCUS, value);
    }
  }

  changeFirstIndex(bool value) {
    SpUtil.putInt(HOME_INDEX, value ? 0 : 1);
    firstIndex.value = value ? 0 : 1;
  }
}

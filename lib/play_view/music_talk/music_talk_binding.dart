import 'package:bujuan/play_view/music_talk/music_talk_controller.dart';
import 'package:get/get.dart';

class MusicTalkBinding extends Bindings{
  @override
  void dependencies() {
    Get.lazyPut<MusicTalkController>(() => MusicTalkController());
  }

}
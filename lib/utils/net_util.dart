import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:bujuan/api/netease_cloud_music.dart';
import 'package:bujuan/entity/ablum_newest.dart';
import 'package:bujuan/entity/album_details.dart';
import 'package:bujuan/entity/dj_recommend.dart';
import 'package:bujuan/entity/fm_entity.dart';
import 'package:bujuan/entity/heart.dart';
import 'package:bujuan/entity/program_detail.dart';
import 'package:bujuan/entity/search_album.dart';
import 'package:bujuan/entity/search_hot_entity.dart';
import 'package:bujuan/entity/search_mv_entity.dart';
import 'package:bujuan/entity/search_sheet_entity.dart';
import 'package:bujuan/entity/search_singer_entity.dart';
import 'package:bujuan/entity/top_artists_entity.dart';
import 'package:bujuan/entity/user_di_program.dart';
import 'package:bujuan/entity/user_dj.dart';
import 'package:bujuan/entity/week_data.dart';
import 'package:bujuan/generated/json/base/json_convert_content.dart';
import 'package:bujuan/global/global_config.dart';
import 'package:bujuan/global/global_controller.dart';
import 'package:bujuan/main.dart';
import 'package:bujuan/entity/banner_entity.dart';
import 'package:bujuan/entity/cloud_entity.dart';
import 'package:bujuan/entity/login_entity.dart';
import 'package:bujuan/entity/lyric_entity.dart';
import 'package:bujuan/entity/music_talk.dart';
import 'package:bujuan/entity/new_song_entity.dart';
import 'package:bujuan/entity/personal_entity.dart';
import 'package:bujuan/entity/play_history_entity.dart';
import 'package:bujuan/entity/search_song_entity.dart';
import 'package:bujuan/entity/sheet_by_classify.dart';
import 'package:bujuan/entity/sheet_details_entity.dart';
import 'package:bujuan/entity/today_song_entity.dart';
import 'package:bujuan/entity/top_entity.dart';
import 'package:bujuan/entity/user_order_entity.dart';
import 'package:bujuan/entity/user_profile_entity.dart';
import 'package:bujuan/utils/bujuan_util.dart';
import 'package:bujuan/utils/sp_util.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:get/get.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:starry/music_item.dart';
import 'package:starry/starry.dart';

class NetUtils {
  static final NetUtils _netUtils = NetUtils._internal(); //1
  factory NetUtils() {
    return _netUtils;
  }

  NetUtils._internal();

  ///统一请求'msg' -> 'data inconstant when unbooked playlist, pid:2427280345 userId:302618605'
  Future<Map> _doHandler(String url, {cacheName, Map param = const {}}) async {
    var answer =
        await cloudMusicApi(url, parameter: param, cookie: await _getCookie());
    var map;
    if (answer.status == 200) {
      if (answer.cookie != null && answer.cookie.length > 0) {
        await _saveCookie(answer.cookie);
      }
      map = answer.body;
      if (!GetUtils.isNullOrBlank(cacheName) && map['code'] == 200)
        _saveCache(cacheName, map);
      log('$url======${jsonEncode(map)}');
    }
    return map;
  }

  ///简陋的本地文件缓存
  _saveCache(String cacheName, dynamic data) {
    debugPrint('简陋的本地文件缓存');
    var directory = Get.find<FileService>().directory.value;
    File file = File('${directory.path}$cacheName');
    if (file.existsSync()) file.deleteSync();
    file.createSync();
    file.writeAsStringSync(jsonEncode(data));
  }

  ///保存cookie
  Future<void> _saveCookie(List<Cookie> cookies) async {
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path;
    CookieJar cookie = new PersistCookieJar(dir: tempPath, ignoreExpires: true);
    cookie.saveFromResponse(Uri.parse('https://music.163.com/weapi/'), cookies);
  }

  ///获取cookie
  Future<List<Cookie>> _getCookie() async {
    var directory = Get.find<FileService>().directory.value;
    String tempPath = directory.path;
    CookieJar cookie = new PersistCookieJar(dir: tempPath, ignoreExpires: true);
    return cookie.loadForRequest(Uri.parse('https://music.163.com/weapi/'));
  }

  ///手机号登录
  Future<LoginEntity> loginByPhone(String phone, String password) async {
    var login;
    var map = await _doHandler('/login/cellphone',
        param: {'phone': phone, 'password': password});
    if (map != null) {
      login = LoginEntity.fromJson(map);
    }
    return login;
  }

  ///邮箱登录
  Future<LoginEntity> loginByEmail(String email, String password) async {
    var login;
    var map = await _doHandler('/login',
        param: {'email': email, 'password': password});
    if (map != null) login = LoginEntity.fromJson(map);
    return login;
  }

  ///刷新登录，token换token(总把新桃换旧符)
  Future<Map> refreshLogin() async {
    var map = await _doHandler('/login/refresh');
    return map;
  }

  ///获取歌单详情
  Future<SheetDetailsEntity> getPlayListDetails(id,
      {count, forcedRefresh = false}) async {
    SheetDetailsEntity sheetDetails;
    if (await BuJuanUtil.checkFileExists('$id') && !forcedRefresh) {
      debugPrint("$id歌单已缓存，直接拿哈");
      var data = await BuJuanUtil.readStringFile('$id');
      if (data != null) sheetDetails = SheetDetailsEntity.fromJson(data);
    } else {
      debugPrint("$id歌单未缓存");
      var map = await _doHandler('/playlist/detail', param: {'id': id});
      if (map != null) sheetDetails = SheetDetailsEntity.fromJson(map);
      var trackIds2 = sheetDetails.playlist.trackIds;
      // if (count != null) {
      //   trackIds2 = trackIds2.sublist(0, 3);
      // } else {
      if (trackIds2.length > 1000) trackIds2 = trackIds2.sublist(0, 1000);
      // }
      List<int> ids = [];
      await Future.forEach(trackIds2, (id) => ids.add(id.id));
      var list = await getSongDetails(ids.join(','));
      sheetDetails.playlist.tracks = list;
      _saveCache('$id', sheetDetails.toJson());
    }

    return sheetDetails;
  }

  ///获取歌曲详情
  Future<List<SheetDetailsPlaylistTrack>> getSongDetails(ids) async {
    var songDetails;
    var map = await _doHandler('/song/detail', param: {'ids': ids});
    if (map != null) {
      var body = map['songs'];
      List<SheetDetailsPlaylistTrack> songs = [];
      await Future.forEach(body, (element) {
        var sheetDetailsPlaylistTrack =
            SheetDetailsPlaylistTrack.fromJson(element);
        songs.add(sheetDetailsPlaylistTrack);
      });
      songDetails = songs;
    }
    return songDetails;
  }

  ///每日推荐
  Future<List<SheetDetailsPlaylistTrack>> getTodaySongs() async {
    var todaySongs;
    var map = await _doHandler('/recommend/songs');
    var todaySongEntity = TodaySongEntity.fromJson(map);
    if (map != null) {
      List<int> ids = [];
      await Future.forEach(todaySongEntity.recommend, (id) => ids.add(id.id));
      todaySongs = await getSongDetails(ids.join(','));
    }
    return todaySongs;
  }

  ///获取个人信息
  Future<UserProfileEntity> getUserProfile(userId) async {
    var profile;
    var map = await _doHandler('/user/detail',
        param: {'uid': userId}, cacheName: CACHE_USER_PROFILE);
    if (map != null)
      profile = UserProfileEntity.fromJson(Map<String, dynamic>.from(map));
    return profile;
  }

  ///获取用户歌单
  Future<UserOrderEntity> getUserPlayList(userId,
      {forcedRefresh = false}) async {
    var playlist;
    if (await BuJuanUtil.checkFileExists(CACHE_USER_PLAY_LIST) &&
        !forcedRefresh) {
      debugPrint("用户歌单已缓存，直接拿哈");
      var data = await BuJuanUtil.readStringFile(CACHE_USER_PLAY_LIST);
      if (data != null) playlist = UserOrderEntity.fromJson(data);
    } else {
      debugPrint("用户歌单未缓存");
      var map = await _doHandler('/user/playlist',
          param: {'uid': userId}, cacheName: CACHE_USER_PLAY_LIST);
      if (map != null) playlist = UserOrderEntity.fromJson(map);
    }
    return playlist;
  }

  ///推荐歌单
  Future<PersonalEntity> getRecommendResource({forcedRefresh = false}) async {
    var playlist;
    if (await BuJuanUtil.checkFileExists(CACHE_TODAY_SHEET) && !forcedRefresh) {
      debugPrint("推荐歌单已缓存，直接拿哈");
      var data = await BuJuanUtil.readStringFile(CACHE_TODAY_SHEET);
      if (data != null) playlist = PersonalEntity.fromJson(data);
    } else {
      debugPrint("推荐歌单未缓存");
      var map = await _doHandler('/personalized', cacheName: CACHE_TODAY_SHEET);
      if (map != null) playlist = PersonalEntity.fromJson(map);
    }
    return playlist;
  }

  ///banner
  Future<BannerEntity> getBanner() async {
    var banner;
    var map = await _doHandler('/banner');
    if (map != null) banner = BannerEntity.fromJson(map);
    return banner;
  }

  ///新歌推荐
  Future<NewSongEntity> getNewSongs({forcedRefresh = false}) async {
    var newSongs;
    if (await BuJuanUtil.checkFileExists(CACHE_NEW_SONG) && !forcedRefresh) {
      debugPrint("新歌推荐已缓存，直接拿哈");
      var data = await BuJuanUtil.readStringFile(CACHE_NEW_SONG);
      if (data != null) newSongs = NewSongEntity.fromJson(data);
    } else {
      debugPrint("新歌推荐未缓存");
      var map =
          await _doHandler('/personalized/newsong', cacheName: CACHE_NEW_SONG);
      if (map != null) newSongs = NewSongEntity.fromJson(map);
    }
    return newSongs;
  }

  ///新歌推荐
  Future<AlbumNewest> getNewAlbum() async {
    var newAlbum;
    var map = await _doHandler('/album/newest');
    if (map != null) newAlbum = AlbumNewest.fromJson(map);
    return newAlbum;
  }

  ///获取歌曲播放地址
  Future<String> getSongUrl(songId) async {
    var songUrl = '';
    if (GlobalController.to.playListMode.value == PlayListMode.RADIO) {
      var userDjProgram = await programDetail(songId);
      if (userDjProgram != null && userDjProgram.code == 200) {
        songId = userDjProgram.program.mainTrackId;
        GlobalController.to.song.value.radioId = '$songId';
      }
    }
    var map = await _doHandler('/song/url', param: {
      'id': songId,
      'br': SpUtil.getString(QUALITY, defValue: '128000')
    });
    if (map != null && map['code'] == 200) songUrl = map['data'][0]['url'];
    return songUrl;
  }

  ///根据id获取排行榜/top/list
  Future<TopEntity> getTopData(id) async {
    var top;
    var map = await _doHandler('/top/list', param: {'idx': id});
    if (map != null) top = TopEntity.fromJson(map);
    return top;
  }

  ///根据ID删除创建歌单
  Future<bool> delPlayList(id) async {
    var del = false;
    var map = await _doHandler('/playlist/del', param: {'id': id});
    if (map != null && map['code'] == 200) del = true;
    return del;
  }

  ///1收藏0取消收藏
  Future<bool> subPlaylist(bool isSub, id) async {
    bool sub = false;
    var map = await _doHandler('/playlist/subscribe',
        param: {'t': isSub ? 1 : 0, 'id': id});
    sub = map != null;
    return sub;
  }

  ///創建歌單
  Future<bool> createPlayList(name, privacy) async {
    bool create = false;
    var map = await _doHandler('/playlist/create',
        param: {'name': name, 'privacy': privacy ? 10 : 0});
    create = map != null;
    return create;
  }

  ///搜索// 1: 单曲, 10: 专辑, 100: 歌手, 1000: 歌单, 1002: 用户, 1004: MV, 1006: 歌词, 1009: 电台, 1014: 视频
  Future<dynamic> search(content, type) async {
    var searchData;
    var map =
        await _doHandler('/search', param: {'keywords': content, 'type': type});
    if (map != null) {
      if (type == 1) {
        var data = SearchSongEntity.fromJson(map);
        List<int> ids = [];
        await Future.forEach(data.result.songs, (id) => ids.add(id.id));
        searchData = await getSongDetails(ids.join(','));
      }
      if (type == 100) searchData = SearchSingerEntity.fromJson(map);
      if (type == 1000) searchData = SearchSheetEntity.fromJson(map);
      if (type == 1004) searchData = SearchMvEntity.fromJson(map);
      if (type == 10) searchData = SearchAlbumEntity.fromJson(map);
    }
    return searchData;
  }

  ///获取热搜列表
  Future<SearchHotEntity> searchList({forcedRefresh = false}) async {
    var searchData;
    if (await BuJuanUtil.checkFileExists(CACHE_SEARCH_SUGGEST) &&
        !forcedRefresh) {
      debugPrint("热搜列表已缓存，直接拿哈");
      var data = await BuJuanUtil.readStringFile(CACHE_SEARCH_SUGGEST);
      if (data != null) searchData = SearchHotEntity.fromJson(data);
    } else {
      debugPrint("热搜列表未缓存");
      var map = await _doHandler('/search/hot/detail',
          cacheName: CACHE_SEARCH_SUGGEST);
      if (map != null) searchData = SearchHotEntity.fromJson(map);
    }
    return searchData;
  }

  ///听歌历史 1: 最近一周, 0: 所有时间
  Future<dynamic> getHistory(uid, type) async {
    var history;
    var map =
        await _doHandler('/user/record', param: {'uid': uid, 'type': type});
    if (map != null) {
      if (type == 0) {
        history = PlayHistoryEntity.fromJson(map);
      } else {
        history = WeekHistory.fromJson(map);
      }
    }
    return history;
  }

  ///歌词
  Future<LyricEntity> getMusicLyric(id) async {
    var lyric;
    if (await BuJuanUtil.checkFileExists('$id')) {
      debugPrint("lyric已缓存，直接拿哈");
      var data = await BuJuanUtil.readStringFile('$id');
      if (data != null) lyric = LyricEntity.fromJson(data);
    } else {
      debugPrint("lyric未缓存");
      var map = await _doHandler('/lyric', param: {'id': id}, cacheName: '$id');
      if (map != null) lyric = LyricEntity.fromJson(map);
    }
    return lyric;
  }

  ///获取云盘数据
  Future<List<SheetDetailsPlaylistTrack>> getCloudData(offset) async {
    CloudEntity cloud;
    var map = await _doHandler('/user/cloud', param: {'offset': offset});
    if (map != null) cloud = CloudEntity.fromJson(map);
    List<int> ids = [];
    await Future.forEach(cloud.data, (id) => ids.add(id.songId));
    var list = await getSongDetails(ids.join(','));
    return list;
  }

  ///根据分类获取歌单
  Future<SheetByClassify> getSheetByClassify(cat, offset) async {
    var sheetByClassify;
    var map = await _doHandler('/top/playlist',
        param: {'cat': cat, 'offset': offset});
    if (map != null) sheetByClassify = SheetByClassify.fromJson(map);
    return sheetByClassify;
  }

  ///获取歌曲评论
  Future<MusicTalk> getMusicTalk(id, type, pageNo) async {
    var talk;
    var map = await _doHandler('/comment/new',
        param: {'id': id, 'type': type, 'pageNo': pageNo});
    if (map != null) talk = MusicTalk.fromJson(map);
    return talk;
  }

  ///获取歌曲楼层评论
  Future<void> getMusicFloorTalk(parentId, id, time) async {
    var map = await _doHandler('/comment/floor', param: {
      'parentCommentId': parentId,
      'type': 0,
      'id': id,
      'time': time
    });
    log('message');
  }

  ///获取fm歌曲
  Future<FmEntity> getFm() async {
    var fm;
    var map = await _doHandler('/personal_fm');
    if (map != null) fm = FmEntity.fromJson(map);
    return fm;
  }

  ///获取喜欢歌曲列表
  Future<List<String>> getLikeSongs() async {
    var likeSongs;
    var userId = SpUtil.getString(USER_ID_SP, defValue: '');
    if (!GetUtils.isNullOrBlank(userId)) {
      var map = await _doHandler('/likelist', param: {'uid': userId});
      if (map != null) {
        List<int> data = map['ids'].cast<int>();
        likeSongs = data.join(',').split(',');
      }
    }
    return likeSongs;
  }

  ///喜欢和不喜欢歌曲
  Future<bool> likeOrUnlike(id, isLike) async {
    var likeSong = false;
    var map = await _doHandler('/like', param: {'id': id, 'like': '$isLike'});
    if (map != null && map['code'] == 200) {
      likeSong = true;
    }
    return likeSong;
  }

  ///心动模式
  Future<List<MusicItem>> getHeart(id, pid) async {
    List<MusicItem> heartSong = [];
    var map = await _doHandler('/playmode/intelligence/list',
        param: {'id': id, 'pid': pid});
    if (map != null) {
      var heart = Heart.fromJson(map);
      heart.data.forEach((track) {
        MusicItem musicItem = MusicItem(
          musicId: '${track.songInfo.id}',
          duration: track.songInfo.dt,
          iconUri: "${track.songInfo.al.picUrl}",
          title: track.songInfo.name,
          uri: '${track.songInfo.id}',
          artist: track.songInfo.ar[0].name,
        );
        heartSong.add(musicItem);
      });
    }

    return heartSong;
  }

  Future<File> getLocalImage(id, type,
      {format, size, requestPermission}) async {
    var imagePath;
    var bool = await BuJuanUtil.checkFileExists('$id.png');
    if (!bool) {
      var uint8list = await OnAudioQuery().queryArtworks(id, type,
          format ?? ArtworkFormat.PNG, size ?? 200, requestPermission ?? false);
      if (uint8list == null) return null;
      await _saveImageCache('$id.png', uint8list);
    }
    var directory = Get.find<FileService>().directory.value;
    imagePath = File('${directory.path}$id.png');
    return imagePath;
  }

  ///简陋的本地文件缓存
  _saveImageCache(String cacheName, dynamic data) async {
    debugPrint('简陋的本地图片缓存');
    var directory = Get.find<FileService>().directory.value;
    File file = File('${directory.path}$cacheName');
    if (await file.exists()) await file.delete();
    await file.create();
    await file.writeAsBytes(data);
  }

  ///获取专辑详情
  Future<AlbumData> getAlbumDetails(id) async {
    var songDetails;
    var map = await _doHandler('/album', param: {'id': id});
    if (map != null) {
      AlbumDetails album = AlbumDetails.fromJson(map);
      List<int> ids = [];
      await Future.forEach(album.songs, (id) => ids.add(id.id));
      var list = await getSongDetails(ids.join(','));
      songDetails = AlbumData(list, album.album);
    }
    return songDetails;
  }

  ///听歌打卡
  Future<bool> scrobble(id, sid, time) async {
    var songDetails = false;
    var map = await _doHandler('/user/scrobble',
        param: {'id': id, 'sid': sid, 'time': time});
    if (map != null && map['code'] == 200) {
      songDetails = true;
    }
    return songDetails;
  }

  ///用户订阅的电台
  Future<UserDj> userDjSublist(offset) async {
    var songDetails;
    var map = await _doHandler('/user/dj/sublist', param: {'offset': offset});
    if (map != null) {
      songDetails = UserDj.fromJson(map);
    }
    return songDetails;
  }

  ///电台详情列表
  Future<UserDjProgram> userProgram(rid, offset, asc) async {
    var userDjProgram;
    var map = await _doHandler('/dj/program',
        param: {'rid': rid, 'offset': offset, 'asc': asc});
    if (map != null) {
      userDjProgram = UserDjProgram.fromJson(map);
    }
    return userDjProgram;
  }

  ///获取节目详情
  Future<ProgramDetail> programDetail(id) async {
    var userDjProgram;
    var map = await _doHandler('/dj/program/detail', param: {'id': id});
    if (map != null) {
      userDjProgram = ProgramDetail.fromJson(map);
    }
    return userDjProgram;
  }

  ///推荐电台（需登录）
  Future<DjRecommend> djRecommend() async {
    var djRecommend;
    var map = await _doHandler('/dj/recommend');
    if (map != null) {
      djRecommend = DjRecommend.fromJson(map);
    }
    return djRecommend;
  }

  ///添加或删除歌单中的歌曲
  Future<bool> addOrDelSongToPlayList(op, playlistId, songId) async {
    var djRecommend;
    var map = await _doHandler('/playlist/tracks',
        param: {'op': op, 'pid': playlistId, 'tracks': songId});
    if (map != null && map['code'] == 200) {
      djRecommend = true;
    }
    return djRecommend;
  }

  ///热门歌手 /top/artists
  Future<TopArtistsEntity> getTopArtists(offset) async {
    var topArtists;
    var map = await _doHandler('/top/artists', param: {'offset': offset});
    if (map != null) {
      topArtists = JsonConvert.fromJsonAsT<TopArtistsEntity>(map);
    }
    return topArtists;
  }
}

class AlbumData {
  final List<SheetDetailsPlaylistTrack> data;
  final Album album;

  AlbumData(this.data, this.album);
}

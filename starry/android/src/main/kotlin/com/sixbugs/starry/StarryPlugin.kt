package com.sixbugs.starry

import android.app.Activity
import android.util.Log
import androidx.annotation.NonNull
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.Observer
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStoreOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import snow.player.Player
import snow.player.PlayerClient
import snow.player.audio.MusicItem
import snow.player.lifecycle.PlayerViewModel
import snow.player.playlist.Playlist

/** StarryPlugin */
class StarryPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var playerClient: PlayerClient
    private lateinit var changeListener: (MusicItem?, Int, Int) -> Unit
    private lateinit var starryPlaybackStateChangeListener: StarryPlaybackStateChangeListener
    private lateinit var onStalledChangeListener: (Boolean, Int, Long) -> Unit
    lateinit var liveProgress : LiveProgress
    companion object {
        lateinit var channel: MethodChannel
        lateinit var activity: Activity
    }


    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "starry")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {

        when (call.method) {
            "PLAY_MUSIC" -> {
                val songList = call.argument<String>("PLAY_LIST")!!
                val index = call.argument<Int>("INDEX")!!
                val jsonToList = GsonUtil.jsonToList(songList, MusicItem::class.java)
                val appendAll = Playlist.Builder().appendAll(jsonToList.toMutableList()).build()
                playerClient.setPlaylist(appendAll, index, true)
                result.success("success")
            }
            "PLAY_BY_INDEX" -> {
                //根据ID播放
                val index = call.argument<Int>("INDEX")!!
                playerClient.getPlaylist { data ->
                    if (data.allMusicItem.size > index) {
                        playerClient.skipToPosition(index)
                    }
                }
                result.success("success")
            }
            "NOW_PLAYING" -> {
                //获取当前播放的歌曲
                val playingMusicItem = playerClient.playingMusicItem
                val playingSongStr = GsonUtil.GsonString(playingMusicItem)
                result.success(playingSongStr)
            }
            "PAUSE" -> {
                //暂停
                if (playerClient.isPlaying) {
                    playerClient.pause()
                }
                result.success("success")
            }
            "RESTORE" -> {
                //播放
                playerClient.play()
                result.success("success")
            }
            "NEXT" -> {
                //下一首
                playerClient.skipToNext()
                result.success("success")
            }
            "PREVIOUS" -> {
                //上一首
                playerClient.skipToPrevious()
                result.success("success")
            }

            else -> result.notImplemented()

        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        playerClient.removeOnPlayingMusicItemChangeListener(changeListener)
        playerClient.removeOnPlaybackStateChangeListener(starryPlaybackStateChangeListener)
        liveProgress.unsubscribe()
    }

    override fun onDetachedFromActivity() {
        playerClient.removeOnPlayingMusicItemChangeListener(changeListener)
        playerClient.removeOnPlaybackStateChangeListener(starryPlaybackStateChangeListener)
        playerClient.removeOnStalledChangeListener(onStalledChangeListener)
        liveProgress.unsubscribe()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    }

    override fun onDetachedFromActivityForConfigChanges() {
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        // 创建一个 PlayerClient 对象
        playerClient = PlayerClient.newInstance(binding.activity.applicationContext, MyPlayerService::class.java)
        playerClient.connect { success -> Log.d("App", "connect: $success"); }

        //监听歌曲播放状态
        starryPlaybackStateChangeListener = StarryPlaybackStateChangeListener()
        playerClient.addOnPlaybackStateChangeListener(starryPlaybackStateChangeListener)

        //播放歌曲发生变化
        changeListener = { musicItem, _, _ -> channel.invokeMethod("SWITCH_SONG_INFO", GsonUtil.GsonString(musicItem)) }
        playerClient.addOnPlayingMusicItemChangeListener(changeListener)

        liveProgress = LiveProgress(playerClient,object : LiveProgress.OnUpdateListener {
            override fun onUpdate(progressSec: Int, durationSec: Int, textProgress: String?, textDuration: String?) {
                channel.invokeMethod("PLAY_PROGRESS", progressSec)
            }
        })
        liveProgress.subscribe()
//        onSeekCompleteListener = { progress, _,        _ ->  }
//        playerClient.addOnSeekCompleteListener(onSeekCompleteListener)
    }


    class StarryPlaybackStateChangeListener : Player.OnPlaybackStateChangeListener {
        override fun onPlay(stalled: Boolean, playProgress: Int, playProgressUpdateTime: Long) {
            channel.invokeMethod("PLAYING_SONG_INFO", null)
        }

        override fun onPause(playProgress: Int, updateTime: Long) {
            channel.invokeMethod("PAUSE_OR_IDEA_SONG_INFO", null)
        }

        override fun onStop() {
            channel.invokeMethod("STOP_SONG_INFO", null)
        }

        override fun onError(errorCode: Int, errorMessage: String?) {
            channel.invokeMethod("PLAY_ERROR", null)
        }

    }
}

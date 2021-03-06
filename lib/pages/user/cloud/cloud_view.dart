import 'package:bujuan/global/global_loding_view.dart';
import 'package:bujuan/pages/play_widget/play_widget_view.dart';
import 'package:bujuan/widget/over_scroll.dart';
import 'package:bujuan/widget/state_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import 'cloud_controller.dart';

class CloudView extends GetView<CloudController>{
  @override
  Widget build(BuildContext context) {
    return _buildCloudView(context);
  }


  Widget _buildCloudView(context){
    return PlayWidgetView( _buildContent(context));
  }

  Widget _buildContent(context){
    return Obx(()=>StateView(controller.loadState.value, ScrollConfiguration(behavior: OverScrollBehavior(), child: SmartRefresher(
      controller: controller.refreshController,
      enablePullUp: controller.enableLoadMore.value,
      header:  WaterDropMaterialHeader(
        color: Theme.of(context).accentColor,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      footer: ClassicFooter(),
      onRefresh: ()=>controller.refreshData(),
      onLoading: ()=>controller.loadMoreData(),
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            elevation: 0.0,
            floating: true,
            pinned: true,
            title: Text('云盘'),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                return controller.clouds.length >0?InkWell(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 2.0, vertical: 5.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          margin: EdgeInsets.only(right: 5.0),
                          height: 50.0,
                          alignment: Alignment.center,
                          constraints: BoxConstraints(maxWidth: 40, minHeight: 30.0),
                          child: Text(
                            '${index + 1}',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16.0,color: Colors.grey[500]),
                          ),
                        ),
                        Expanded(
                            child: Column(
                              children: [
                                Container(
                                  height: 25,
                                  alignment: Alignment.centerLeft,
                                  child: Text(controller.clouds[index].name==null?'未知':controller.clouds[index].name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 16.0)),
                                ),
                                Container(
                                  height: 25,
                                  alignment: Alignment.centerLeft,
                                  child: Text(controller.clouds[index].ar[0].name != null?controller.clouds[index].ar[0].name:'未知', maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 14.0,color: Colors.grey[500])),
                                )
                              ],
                            )),
                        IconButton(icon: Icon(Icons.more_vert,color: Colors.grey[500],),onPressed: (){},)
                      ],
                    ),
                  ),
                  onTap: ()=>controller.playSong(index),
                ):LoadingView.buildGeneralLoadingView();
              },
              childCount: controller.clouds.length >0
                  ? controller.clouds.length
                  : 15,
            ),
          )
        ],
      ),
    ))));
  }

}
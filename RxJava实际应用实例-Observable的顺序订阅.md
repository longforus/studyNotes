# RxJava实际应用实例-Observable的依次订阅

  最近项目的图片上传中遇到一个问题.后台限制只能一次上传一张图片,且不可以并发上传,必须等前一张上传完毕后才能上传第二张图片.依次将多张图片上传完毕后,才能进行下一步操作.这里不吐槽后台的无能.我开始使用递归调用带回调解决了这个问题,如下:

## 常规实现

```kotlin
   val imgs = Collections.synchronizedList(ArrayList<String>())
            listBean.imgs = imgs
            mView.showLoadDialog("上传中...")
            val allSize = bean.commontImgs.size - 1//减去add button
            val path = SelectImgLayout.getUpLoadImgPath(bean.commontImgs.removeAt(0))
            val localListener = object : UploadListener {//使用接口监听器
                override fun onOk(uploadResultBean: UploadResultBean) {
                    imgs.add(uploadResultBean.fileName)//保存当前上传结果
                    if (!bean.commontImgs.isEmpty() && imgs.size != allSize) {//待上传list不空,且已上传数量!=所有数量
                        realUpload(SelectImgLayout.getUpLoadImgPath(bean.commontImgs.removeAt(0)), this, mModel, 3)//上传下一张,传入当前Listener,进行结果监听
                    } else if (imgs.size == allSize) {//全部完成
                        list.add(listBean)
                        listener.onOk(true)
                    }
                }
            }
            realUpload(path, localListener, mModel, 3)//开始上传
            
            -----------
            
fun realUpload(path: String, listener: UploadListener, model: IDisposablePool, type: Int) {
    val map = FecFileRequestMap()
    map.put("file", File(path))
    map.put("picType", type)
    AxkcCoreHttpManager.getManager().deal(object : FileSubscribe<UploadResultBean, AxkcCoreHttpService>(model, map) {
        override fun getObservable(axkcCoreHttpService: AxkcCoreHttpService, factory: FileRequestMapBuild): Observable<BaseEntity<UploadResultBean>> {
            return axkcCoreHttpService.upload(factory.build())
        }
    }).subscribe(object : AxkcObserver<UploadResultBean>("上传") {
        override fun onNextSuccess(uploadResultBean: UploadResultBean) {
            listener.onOk(uploadResultBean)//当前上传完成 通知回调
        }
    })
}
```

常规实现也可以实现目的.



## RxJava尝试

  后来我想到既然在使用RxJava,那这个问题能不能用RxJava实现呢?答案是肯定的,但是没有想到怎么做,开始以为可以使用Flowable实现,尝试后发现不能,看了一下RxJava的操作符以后发现也没有很合适的方案.后来一位群友提醒:

"自己实现observer接口，在onSubscribe方法中拿到subscribtion对象，在onNext方法中处理结果后再调用一次subscribtion.request(1)"

在RxJava2中貌似已经移除了subscribtion.后来我想到了下面这样的方式:

```kotlin
val obList = mutableListOf<Observable<UploadResultBean>>()//被观察者list
            bean.commontImgs.forEach {
                if (it.path == null) {
                    return@forEach
                }
                val map = FecFileRequestMap()
                map.put("file", File(it.path))
                map.put("picType", 3)
                val observable = AxkcCoreHttpManager.getManager().deal(object : FileSubscribe<UploadResultBean, AxkcCoreHttpService>(model, map) {
                    override fun getObservable(axkcCoreHttpService: AxkcCoreHttpService, factory: FileRequestMapBuild): Observable<BaseEntity<UploadResultBean>> {
                        return axkcCoreHttpService.upload(factory.build())
                    }
                })
                obList.add(observable)//把每个Observable放到list中
            }
            var imgE: ObservableEmitter<Observable<UploadResultBean>>? =null
            Observable.create(ObservableOnSubscribe<Observable<UploadResultBean>> { e ->//创建这个Observable的Observable 
                imgE = e//保存发射器
                imgE?.onNext(obList.removeAt(0))//发射一个 触发
            }).subscribe({
                //订阅上游发送的Observable
                it.subscribe { t: UploadResultBean? ->//这里只订阅了onNext的情况  onError也可以的
                    if (t?.isOk == true && obList.isNotEmpty()) {//当前Observable返回 成功且list不空
                        println(t.fileName)//处理本次数据
                        imgE?.onNext(obList.removeAt(0))//发射下一个Observable
                    } else {//队列完成
                        ToastUtil.showShort(context,"upload Finish")
                    }
                }
            })
```



也能实现目的,比起常规实现方式感觉也没有方便,优雅很多.应该还有更好的实现方式,以后发现了再实践.
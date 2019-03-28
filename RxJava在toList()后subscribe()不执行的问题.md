# RxJava在toList()后subscribe()不执行的问题

今天在项目中遇到一个问题:需要遍历一个list在经过2次异步调用修改list中的一些值之后,刷新adapter,通知数据修改.略显复杂,一般的同步修改倒是没有什么了,但是需要进行2次异步调用修改,而且要跳过一些item,还要进行类型转换.最后还要根据异步调用返回的值进行排序,这个就略显复杂了.项目中引入了RxJava2,近几年的项目也一直都在用,今天面临的这种数据流的操作,最合适的也就是它了.

## 遍历

数据源就是一个list,很简单用`fromIterable`操作符就好了,这个操作符接收一个`Iterable<? extends T> source`,会依次发送里面的每一个item,发送完成后会调用`onComplete()`发送结束事件.

```kotlin
Observable.fromIterable(adatper!!.data)
```

## 跳过和转型

跳过的话可以调用`skip(long count)`操作符,它会跳过`0..count`个item,不像下游发送.转型的话直接使用`map(Function<? super T, ? extends R> mapper)`在里面把上游发送的被观察数据类型转为想要的类型就好了,会以新的类型继续向下游发送.

```kotlin
Observable.fromIterable(adatper!!.data).skip(3).map { it as Ques }
```

## 被观察者类型转换

今天的例子中,在开始的时候我接收到上游发送的数据后,需要进行异步调用,根据上游数据查询一个值,然后发送到下游,继续背观察.要实现这种功能的话要使用`Observable<R> flatMap(Function<? super T, ? extends ObservableSource<? extends R>> mapper) `操作符,接收到上游数据后新建一个Observable返回给下游,异步回调后,调用这个Observable的`emitter.onNext()`把数据发送给下游.

```kotlin
Observable.create<Int> {
               RongIMClient.getInstance().getUnreadCount(Conversation.ConversationType.GROUP, bean.askCode, object : RongIMClient.ResultCallback<Int>() {
                    override fun onSuccess(p0: Int?) {
                        val old = bean.msgCount
                        if (old == p0 ?: 0) return
                        it.onNext(p0 ?: 0)
                        it.onComplete()
                    }

                    override fun onError(p0: RongIMClient.ErrorCode?) {
                        val old = bean.msgCount
                        if (old == 0) return
                        it.onNext(0)
                        it.onComplete()
                    }
                })
            }
```

## 合并2个Observable

上面的异步调用我进行了2次,获取到不同的值后,需要合并并发送到下游,下游接收到已经统一处理,notify adapter更新.实现这个功能可以使用`zip()`操作符,合并2个Observable并发送到下游,使用`.zipWith()`效果也是一样的.

```
Observable.zip(countOb, msgOb, object : BiFunction<Int, Triple<String, String,String>, Ques> {
                override fun apply(t1: Int, t2: Triple<String, String,String>): Ques {
                    bean.msgCount = t1
                    if (t2.first.isNotEmpty()) {
                        bean.content = t2.first
                    }
                    bean.questionTime = t2.second
                    bean.sortTime = t2.third
                    return bean
                }

            })
```

## 组合上游item为list

每个item都经过处理后会依次被下游的Observer接收到,但是我每次只接收一个插入到adapter然后notify,总是感觉不够优雅,在全部接收完之后再统一notify会不会更好了?这个时候就可以使用`toList()`操作符了,它会收集上游发送的所有item放到一个list中,直到上游调用`onComplete()`后将整个list发送到下游.而且还提供了一个`toSortedList()`的操作符可以对这个list进行排序,可以传入`Comparator`进行自定义排序,可谓非常的方便.

```kotlin
.toSortedList { o1, o2 ->
                o2.sortTime.compareTo(o1.sortTime)
            }
```

## 改进和踩坑

代码写到后面,发现不用把异步调用的结果单独进行发射,因为结果最后也要赋值给被观察item的成员变量,这种情况下使用别的操作符来代替flatMap行不行呢?或许是可以的,改天有应该试试,总之zip操作符在我的处理流中就暂时舍去了.把异步调用的结果直接赋值给上游发送的item再把这个item发射出去,(那用`doOnNext()`行不行呢?`doOnNext()`接收上游发送的item但是并不返回或者发送这个item,待测试),

我在写完上述代码后添加了`toSortedList()`操作符,这个时候意想不到的情况出现了,这个也是今天要说的重点:

**后续的`subscribe()没有被调用,`toSortedList()`自身也没有被调用**,开始以为是线程切换的问题,删除线程切换后问题依旧,搜索后说是上游没有调用`onComplete()`,但是我的源头是使用的`fromIterable()`啊肯定是会调用`onComplete()`的,查看源码也证实了这一点,到这里就卡住了.

我没有想到的是源头虽然调用了`onComplete()`,但是中游的`flatMap()`并没有调用啊,开始我一厢情愿的以为`fromIterable()`会跟着流一直传递,事实证明我想得太天真,对源码也没有深耕.想到这一点后**在中游的`flatMap()`加入`onComplete()`的调用**,问题就解决了.

最后的代码如下:

```kotlin
Observable.fromIterable(adatper!!.data)
						.skip(3)//跳过不需要的数据
            .map { it as Ques }//转型
            .flatMap { ques ->//进行异步调用
                Observable.create<Ques> {RongIMClient.getInstance().getUnreadCount(Conversation.ConversationType.GROUP, ques.askCode, object : RongIMClient.ResultCallback<Int>() {
                        override fun onSuccess(p0: Int?) {
                            ques.msgCount = p0 ?: 0
                            it.onNext(ques)//发射异步调用结果
                            it.onComplete()//别忘了这个哦
                        }

                        override fun onError(p0: RongIMClient.ErrorCode?) {
                            ques.msgCount = 0
                            it.onNext(ques)
                            it.onComplete()
                        }
                    })
                }
            }.flatMap { ques ->
                Observable.create<Ques> {RongIMClient.getInstance().getLatestMessages(Conversation.ConversationType.GROUP, ques.askCode, 1, object : RongIMClient.ResultCallback<List<Message>>() {
                        override fun onSuccess(p0: List<Message>?) {
                            if (p0?.isNotEmpty() == true) {
                                val message = p0[0]
                                val content = message.content
                                val isToday = TimeUtils.getTimeSpanByNow(message.receivedTime, TimeConstants.DAY) == 0L
                                val timeStr = if (isToday) {
                                    TimeUtils.millis2String(message.receivedTime, TimeUtils.FORMAT_HH_mm)
                                } else {
                                    TimeUtils.millis2String(message.receivedTime, TimeUtils.FORMAT_yyyy_MM_dd)
                                }
                                ques.questionTime = timeStr
                                ques.sortTime = TimeUtils.millis2String(message.receivedTime)
                                if (content is TextMessage) {
                                    ques.content = content.content
                                }
                                it.onNext(ques)
                            } else {
                                ques.sortTime = ques.questionTime
                                it.onNext(ques)
                            }
                            it.onComplete()
                        }

                        override fun onError(p0: RongIMClient.ErrorCode?) {
                            it.onNext(ques)
                            it.onComplete()
                        }

                    })
                }
            }.toSortedList { o1, o2 ->//排序并组合成list
                o2.sortTime.compareTo(o1.sortTime)
            }
            .subscribeOn(Schedulers.io())
            .observeOn(AndroidSchedulers.mainThread())
            .subscribe { t ->
                newList.addAll(t)
                adatper?.setNewData(newList)
            }
```



RxJava博大精深,上手简单,要玩6还差得远,暂记于此,多用多想,希望早点玩6.
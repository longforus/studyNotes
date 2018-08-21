# RxNote

标签（空格分隔）： Android

---

## map 
把一种类型的被观察者转换为任意类型的被观察者

    Observable.create({ e: ObservableEmitter<Int>? ->//发送的int
    		e?.onNext(1)
    		e?.onNext(2)
    		e?.onNext(3)
    		println(Thread.currentThread().name)
    		e?.onComplete()
    	})
        //.map(object :Function<Int,String>{
        //override fun apply(t : Int?) : String {
        //	return "this map result $t"
    	    //}
        //})
    	.map { t->("this map result $t")}//转换为string ,  lambada 形式
    	.subscribeOn(Schedulers.io()).observeOn(AndroidSchedulers.mainThread())
    	.subscribe({ t: String ->  println(t) },Throwable::printStackTrace, {
    		println(Thread.currentThread().name)
    		println("complete")
    	})
##flatMap
将一个发送事件的上游Observable变换为多个发送事件的Observables，然后将它们发射的事件合并后放进一个单独的Observable里.
**事件是无序的,需要严格有序的话使用 concatMap**

        Observable.create({ e: ObservableEmitter<Int>? ->//发送一个int
    		e?.onNext(1)
    		e?.onNext(2)
    		e?.onNext(3)
    		println(Thread.currentThread().name)
    		e?.onComplete()
    	})
    //		.flatMap(object :Function<Int,ObservableSource<String>>{
    //			override fun apply(t : Int?) : ObservableSource<String> {
    //				var list = listOf<String>()
    //				for (i in 0 .. 2) {
    //					list+="flatMap $i : $t"
    //				}
    //				return Observable.fromIterable(list).delay(10, TimeUnit.MILLISECONDS)
    //			}
    //		})
    		.flatMap { t ->
    			var list = listOf<String>()
    			for (i in 0 .. 2) {
    				list+="flatMap $i : $t"
    			}
    	    	Observable.fromIterable(list).delay(10, TimeUnit.MILLISECONDS)//转换为3个string发送  delay是为了看到无序的效果
    			}
    			.subscribeOn(Schedulers.io()).observeOn(AndroidSchedulers.mainThread())
    			.subscribe({ t: String ->  println(t) },Throwable::printStackTrace, {
    				println(Thread.currentThread().name)
    				println("complete")
    			})
##zip
按照发送顺序把2个被观察者发送的数据组合成一个新的被观察者发送
        
        val o1 = Observable.create({ e: ObservableEmitter<String>? ->
            println("o1 a")
            e?.onNext("a")
            SystemClock.sleep(500)
            println("o1 b")
            e?.onNext("b")
            SystemClock.sleep(500)
            println("o1 c")
            e?.onNext("c")
            SystemClock.sleep(500)
            println("o1 d")
            e?.onNext("d")
            SystemClock.sleep(500)
            println("o1 com" + Thread.currentThread().name)
            e?.onComplete()
            }).subscribeOn(Schedulers.newThread())
        val o2 = Observable.create({ e: ObservableEmitter<Int>? ->
            println("o2 1")
            e?.onNext(1)
            SystemClock.sleep(500)
            println("o2 2")
            e?.onNext(2)
            SystemClock.sleep(500)
            println("o2 3")
            e?.onNext(3)
            SystemClock.sleep(500)
            println("o2 com " + Thread.currentThread().name)
            e?.onComplete()
        }).subscribeOn(Schedulers.newThread())
        //      Observable.zip(o1,o2,object :io.reactivex.functions.BiFunction<String?,Int?,String?>{
        //          override fun apply(t1: String?, t2: Int?): String? {
        //             return t1+ t2
        //          }
        //      })
        Observable.zip(o1, o2, BiFunction<String?, Int?, String?> { t1, t2 -> t1 + t2 })//按照发送顺序把o1和o2发送的数据组合起来组合完成就马上发送,只要接收到了一个源的onComplete 就发送这个zip的onComplete
    //   .subscribeOn(Schedulers.io())
        .observeOn(AndroidSchedulers.mainThread())
        .subscribe({ t: String? -> println(t) }, Throwable::printStackTrace, {
               println(Thread.currentThread().name)
               println("complete")
         })
##sample
每隔多少时间进行一次取样,取得的value将发送给下游的观察者

		.sample(2,TimeUnit.SECONDS,Schedulers.io())//取样 指定间隔时间和线程

#Flowable

类似Observable但是比Observable多了背压控制的功能,使用方式和Observable类似,但是在性能方面比Observable弱一些,在不需要控制背压的地方还是应该使用Observable

		    Flowable.create({e: FlowableEmitter<String>? ->
	        println("emitter 1")
	        e?.onNext("1test")
	        println("emitter 2")
	        e?.onNext("2test")
	        println("emitter 3")
	        e?.onNext("3test")
	        println("emitter 4")
	        e?.onNext("4test")
	        println("emitter o")
	        e?.onComplete()
	    },BackpressureStrategy.ERROR)
	    //BackpressureStrategy标识出现背压时的处理策略
	        // 1.ERROR是在缓冲池满了以后抛出error
	        // 2.BUFFER是使用无限大的缓冲池,会有OOM的危险
	        // 3.DROP 是默认缓冲池可以装的时候就装进去 其他的扔掉  下游每request(n)个  默认缓冲池就装如上游正在发送的n个value
	        //4.LATEST 和DROP的不同之处是 latest总是会保留最后发送的value到缓冲池中 ,而DROP则不会
	        
	        //  在不同线程的异步订阅中  在flowable和subscribe中间有一个容量128 的value池  在下游没有请求vlaue的时候  flowable发送的value缓冲在这个池中,  如果池满了 就会抛出异常
	        .subscribeOn(Schedulers.io())//如果在同一线程中上游的发送的vlaue数量超过了 下游可以接收的数量就会抛出异常  在不同线程中则不会
	        .observeOn(AndroidSchedulers.mainThread())
	        .subscribe({ t: String? -> println(t) },Throwable::printStackTrace,{
	        println(Thread.currentThread().name)
	        println("on Complete")
	    },{t: Subscription? ->
		// t?.request(Long.MAX_VALUE) //告诉上游的flowable 下游的订阅者可以接收的vlaue数量  这句代码每被调用一次,上游就收到参数  发送<=参数个value下来
		  //可以把t: Subscription保存起来需要n个vlaue的时候 调用一下t?.request(n) 上游的缓冲池便会发送n个value下来,但是缓冲池的默认大小只有128
	        println("onSub")
	    })

按需供应的例子:
		
		Flowable.create({ e : FlowableEmitter<Int>? ->
			println("on start " + e?.requested())
			var flag = false
			for ( i in 0.. Int.MAX_VALUE) {
				flag = false
				while (e?.requested() == 0L) {//如果下游已经没有处理能力 通过阻塞线程来暂停发送event  
				//当下游调用mSubscription?.request(n)(n>=96的时候会触发e?.requested()的结果被赋值.否则下游消费了<96个event這里也不会被赋值)
				// 的时候這里的值就不为0了,继续发送event到中间的缓冲池中
					if (!flag) {
						println("can't emit value")
						flag = true
					}
				}
				e?.onNext(i)
				println("emit  $i   request = "+e?.requested())
			}
		}, BackpressureStrategy.ERROR)
			.subscribeOn(Schedulers.io())
			.observeOn(AndroidSchedulers.mainThread())
			.subscribe({ t -> println(t) }, Throwable::printStackTrace, { println("on complete") }, { t     : Subscription ->
				this.mSubscription = t
	            //mSubscription?.request(n) 向中间的缓冲池请求可以消费n个事件  缓冲池内事件容量>=96的时候会触发上游的e?.requested()的重新赋值  上游可以继续发送event到中间缓冲池 直到装满128个
					println("on sub")
				})



##简化版的Observable

#### Single

只发射一条单一的数据，或者一条异常通知，不能发射完成通知，其中数据与通知只能发射一个。

#### Completable

只发射一条完成通知，或者一条异常通知，不能发射数据，其中完成通知与异常通知只能发射一个

#### Maybe

可发射一条单一的数据，以及发射一条完成通知，或者一条异常通知，其中完成通知和异常通知只能发射一个，发射数据只能在发射完成通知或者异常通知之前，否则发射数据无效.



##interval

interval操作符发送Long型的事件, 从0开始, 每隔指定的时间就把数字加1并发送出来

		  Flowable.interval(1, TimeUnit.MILLISECONDS)//interval发送Long型的事件, 从0开始, 每隔指定的时间就把数字加1并发送出来,在这里每隔1毫秒发送1个
	        .onBackpressureDrop()//对于interval这种非自己创建的Flowable要控制背压可以使用这样的方法连点  效果和对应的参数相同
	        .subscribeOn(Schedulers.io())
	        .observeOn(AndroidSchedulers.mainThread())
	        .subscribe({ t ->
	            println(t)
	        }, Throwable::printStackTrace, { println("on complete") }, { t: Subscription? ->
	            this.subscription = t   //subscription保存起来点击触发 
	        })

---

##other
###CompositeDisposable
disposeable的容易可以装多个,在不需要再发生的时候执行clean方法,释放资源

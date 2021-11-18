# 开启MultiDex仍然报65535方法数的一种情况的解决



最近项目打Release包的时候,爆出了65535的错误,之前一直是正常的.在网上搜索,都是叫开MultiDex,现在的正经项目,没有几个没开了的吧?我的肯定是开了的.但是MainDex还是爆了.我的maindexlist.txt也只keep了最主要的类:

```tex
com/longforu/xx/SmAppProxy.class //TinkerApplication代理类
androidx/multidex/MultiDex.class
retrofit2/http/PATCH.class
```

有一篇文章讲到了这个情况[android studio开启multiDexEnabled后依然出现超出方法数的问题 - GoldenVein的个人空间 - OSCHINA - 中文开源技术交流社区](https://my.oschina.net/u/435726/blog/1518565),里面说到2种解决方法:

1. 精简代码:

    ​	我真实的Application有3层继承,里面初始化了很多的库,包括自己封装的网络库,数据库,flutterBoost,Mob,aliTlog等等.都是挺必要的.几个月前第一次遇到这个问题的时候,就把tlog的初始化移到splashActivity里,暂时解决了这个问题.后来又不行了,只好删除了暂时没用到融云,坚持了没多久,上周又不行了,已经没用多少东西适合移动或删除了.精简比较难.

2. 使用DexKnife开源库,定制mainDex具体的类:

    ​	这个库已经4年没有更新了,对于其中的具体细节也不甚了解,而且我还用了tinker,会不会造成影响呢?最终没有选择这个方法.

通过之前在Application中精简代码就可以暂时规避这个问题来说,我猜测是Application依赖的类太多了,被Application依赖的类的依赖也被引入到mainDex中,而且R8也不能自己分割这些依赖的类了,如果再继续把部分初始化代码移到splashActivity中,会不会有问题呢?再进程重建或者直接跳入其他activity启动app的时候,splashActivity中的这些初始化代码还能不能得到执行呢?当然是不会的,这样的话后续可能会造成一些莫名其妙的bug.这些库的初始化是很重要的, 库?.....初始化?......:thinking: ,忽然就想到了一个专门初始化库的库: [App Startup  | Android Developers (google.cn)](https://developer.android.google.cn/topic/libraries/app-startup)The App Startup library provides a straightforward, performant way to initialize components at application startup.我这种情况下是否适用呢?可是既然是在Application 启动的时候是否意味这这些初始化的代码还是需要打包到mainDex呢?如果是打包到mainDex那还是解决不了65535的问题.实践发现连`androidx.startup.Initializer`的实现类都不会打到mainDex中,而是在classes2.dex中,Initializer的执行时机是在`MultiDex: Installing application`之后,既然MultiDex已经安装好了,那么不在mainDex也没事了.

目前我通过引入App Startup,移动部分库的初始化到Initializer中,暂时解决了开启MultiDex后还报65535的问题,如果你有同样的问题,也可以试一下.具体的代码很简单就不放了,但是要注意一下Initializer代码的执行时机:

```flow
st=>start: Start
op=>operation: com.longforus.core.base.CoreApplication#onBaseContextAttached
op1=>operation: androidx.startup.Initializer#create
op2=>operation: com.longforus.core.base.CoreApplication#onCreate
e=>end: End
st->op->op1->op2->e
```

注意Initializer的代码和其他Initializer之间以及Application#onCreate之间的执行顺序,可以使用`androidx.startup.Initializer#dependencies`来辅助调整执行依赖.

:smiley:ok,就这样.
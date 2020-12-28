# ARouter 配合Fragment :"Fetch fragment instance error"异常的处理

现在的项目中使用ARouter来处理组件化开发中的跳转和部分数据传递的需求,使用一直很顺畅,今天遇到一个不太常见的异常.记录一下:

## 异常信息

```
E/ARouter::: Fetch fragment instance error,     at java.lang.reflect.Constructor.newInstance0(Native Method)
at java.lang.reflect.Constructor.newInstance(Constructor.java:430)
at com.alibaba.android.arouter.launcher._ARouter._navigation(_ARouter.java:380)
at com.alibaba.android.arouter.launcher._ARouter.navigation(_ARouter.java:329)
at com.alibaba.android.arouter.launcher.ARouter.navigation(ARouter.java:183)
at com.alibaba.android.arouter.facade.Postcard.navigation(Postcard.java:149)
at com.alibaba.android.arouter.facade.Postcard.navigation(Postcard.java:140)
at com.fec.yunmall.MainActivity$MainAdapter.<init>(MainActivity.java:181)
at com.fec.yunmall.MainActivity.initTab(MainActivity.java:274)
at com.fec.yunmall.MainActivity.initView(MainActivity.java:91)
at com.fec.fecCommon.ui.activity.FecBaseActivity.onCreate(FecBaseActivity.java:45)
at android.app.Activity.performCreate(Activity.java:6679)
at android.app.Instrumentation.callActivityOnCreate(Instrumentation.java:1118)
at android.app.ActivityThread.performLaunchActivity(ActivityThread.java:2618)
at android.app.ActivityThread.handleLaunchActivity(ActivityThread.java:2726)
at android.app.ActivityThread.-wrap12(ActivityThread.java)
at android.app.ActivityThread$H.handleMessage(ActivityThread.java:1477)
at android.os.Handler.dispatchMessage(Handler.java:102)
at android.os.Looper.loop(Looper.java:154)
at android.app.ActivityThread.main(ActivityThread.java:6119)
at java.lang.reflect.Method.invoke(Native Method)
at com.android.internal.os.ZygoteInit$MethodAndArgsCaller.run(ZygoteInit.java:886)
at com.android.internal.os.ZygoteInit.main(ZygoteInit.java:776)
```



为了方便遇到类似问题的童鞋好找,把异常信息都贴出来了,有点长. 主要信息是获取Fragment错误.我在MainActivity中通过ARouter可以直接获取Fragment实例的功能,获取在业务组件中的Fragment.之前一直是没有问题的.忽然出现了这样的异常.页面获取失败,在MainActivity里面切换,造成App崩溃.



## 问题分析

查看ARouter的异常处代码:

```java
case FRAGMENT:
                Class fragmentMeta = postcard.getDestination();
                try {
                    Object instance = fragmentMeta.getConstructor().newInstance();
                    if (instance instanceof Fragment) {
                        ((Fragment) instance).setArguments(postcard.getExtras());
                    } else if (instance instanceof android.support.v4.app.Fragment) {
                        ((android.support.v4.app.Fragment) instance).setArguments(postcard.getExtras());
                    }

                    return instance;
                } catch (Exception ex) {
                    logger.error(Consts.TAG, "Fetch fragment instance error, " + TextUtils.formatStackTrace(ex.getStackTrace()));
                }
```



可见这里的实现是通过反射实现的.通过断点观察MainActivity中的Fragment List,发现出现问题的是3号Fragment,这个Fragment是Kotlin实现的.以为是这里的问题,但是2号也是Kotlin实现的并没有出现问题.之前也没有出现过这样的问题,也没有更深层次的异常信息.因为之前才将App的compileSdkVersion和buildToolsVersion提升到27+,便略有怀疑是Sdk版本的问题,但是从感觉可能性不大,准备在其他方法无果的时候再降低SdkVersion测试.仔细观察出现问题的3号Fragment发现了可能的原因.测试后发现是这个原因.

## 处理过程

在3号Fragment中起初有如下代码:

```kotlin
@Route(path = "/memberCenter/memberCenter")
class MemberCenterFragment : BaseMvcFragment() {
    val loginCallBack = object : NavCallback() {//构建公用的callBack在未登录的状态页面跳转被拦截的情况下,跳转到登录页面,面对切面编程

        override fun onInterrupt(postcard: Postcard?) {
            member_center_tv_name.post {
              initView2Start()
            }
            ARouter.getInstance().build("/memberCenter/selectLoginActivity").navigation(activity, FecBaseFragment.REQUEST_REFRESH_KEY)
        }

        override fun onArrival(postcard: Postcard?) {

        }

    }
```

```java
//Decompile java:
public final class MemberCenterFragment extends BaseMvcFragment {
   @NotNull
   private final NavCallback loginCallBack = (NavCallback)(new NavCallback() {
      public void onInterrupt(@Nullable Postcard postcard) {
         ((TextView)MemberCenterFragment.this._$_findCachedViewById(id.member_center_tv_name)).post((Runnable)(new Runnable() {
            public final void run() {
               MemberCenterFragment.this.initView2Start();
            }
         }));
         ARouter.getInstance().build("/memberCenter/selectLoginActivity").navigation((Activity)MemberCenterFragment.this.getActivity(), '픍');
      }

      public void onArrival(@Nullable Postcard postcard) {
      }
   });
```

后来因为其他的地方也用到类似的代码,所以抽取了一个公用的callBack,重新赋值该变量如下:

```kotlin
@Route(path = "/memberCenter/memberCenter")
class MemberCenterFragment : BaseMvcFragment() {
    private val loginCallBack =  LoginNVCallBack(activity,FecBaseFragment.REQUEST_REFRESH_KEY) {
        member_center_tv_name.post {
            initView2Start()
        }
    }
    
```

```java
 //使用activity(实际调用getActivity()方法)时的 Decompile java:
 public final class MemberCenterFragment extends BaseMvcFragment {
 private final LoginNVCallBack loginCallBack = new LoginNVCallBack((Activity)this.getActivity(), '픍', (Function0)(new Function0() {
      // $FF: synthetic method
      // $FF: bridge method
      public Object invoke() {
         this.invoke();
         return Unit.INSTANCE;
      }

      public final void invoke() {
         ((TextView)MemberCenterFragment.this._$_findCachedViewById(id.member_center_tv_name)).post((Runnable)(new Runnable() {
            public final void run() {
               MemberCenterFragment.this.initView2Start();
            }
         }));
      }
   }));
```

```java
   //使用mActivity,(自己定义的字段)时的 Decompile java:
   public final class MemberCenterFragment extends BaseMvcFragment {
   @NotNull
   private final LoginNVCallBack loginCallBack;//注意:初始化被放到了构造方法中
   public MemberCenterFragment() {
      this.loginCallBack = new LoginNVCallBack(this.mActivity, '픍', (Function0)(new Function0() {
         // $FF: synthetic method
         // $FF: bridge method
         public Object invoke() {
            this.invoke();
            return Unit.INSTANCE;
         }

         public final void invoke() {
            ((TextView)MemberCenterFragment.this._$_findCachedViewById(id.member_center_tv_name)).post((Runnable)(new Runnable() {
               public final void run() {
                  MemberCenterFragment.this.initView2Start();
               }
            }));
         }
      }));
   }
```

```kotlin
class LoginNVCallBack(val context: Context?, val requestCode: Int = FecBaseActivity.REQUEST_REFRESH_KEY,private var callback: (() -> Unit)? = null) : NavCallback() {
    constructor(activity: Activity?, requestCode: Int = FecBaseActivity.REQUEST_REFRESH_KEY, callback: (() -> Unit)? = null) : this(activity as Context, requestCode, callback)
     
    override fun onArrival(postcard: Postcard?) {
    }
     
    override fun onInterrupt(postcard: Postcard?) {
        callback?.invoke()
        if (context is Activity) {
            ARouter.getInstance().build("/memberCenter/selectLoginActivity").navigation(context, requestCode)
        } else {
            ARouter.getInstance().build("/memberCenter/selectLoginActivity").navigation(context)
        }
    }

}
```

看起来和之前的代码并没有太大差距,但正式因为这点改动造成了这个Fragment的反射实例化失败.为什么呢?是因为在loginCallBack新建的时候引用到的activity(实际调用的是getActivity()方法)还没有赋值吗?很有可能.就算使用mActivity还一样的结果.还是因为使用的函数,在编译后成为匿名类,引用了外面的Fragment? 通过后面的java代码查看,感觉应该是activity为空的原因,不管是直接赋值还是在构造方法中,getActivity()和mActivity都是为null的.但是在onCreate()的时候都不为空了.

修改如下解决问题:

```kotlin
@Route(path = "/memberCenter/memberCenter")
class MemberCenterFragment : BaseMvcFragment() {
   lateinit var loginCallBack : LoginNVCallBack
    
    override fun init(savedInstanceState: Bundle?) {//该方法调用的时候mActivity已经赋值
        loginCallBack =  LoginNVCallBack(mActivity,FecBaseFragment.REQUEST_REFRESH_KEY) {
            member_center_tv_name.post {
                initView2Start()
            }
        }
    }
```
具体的原因还需要继续研究.在研究这个问题的时候发现了一个小细节:

loginCallBack在使用activity,(实际调用的是getActivity()方法)的时候被直接赋值初始化,在使用mActivity(自己定义的字段在onCreate()方法中被赋值为getActivity())的时候,初始化则被放到了构造方法中.



## 后记

最终找到原因,比较以外的问题出在LoginNVCallBack上面:

```kotlin
class LoginNVCallBack(var context: Context?,val requestCode: Int = FecBaseActivity.REQUEST_REFRESH_KEY,private var callback: (() -> Unit)? = null) : NavCallback() {
    constructor(activity: Activity?, requestCode: Int = FecBaseActivity.REQUEST_REFRESH_KEY, callback: (() -> Unit)? = null) : this(activity as Context?,//前面在这里强转为非空类型
        requestCode, callback)

    override fun onArrival(postcard: Postcard?) {
    }
    
    override fun onInterrupt(postcard: Postcard?) {
        callback?.invoke()
        if (context is Activity) {
            ARouter.getInstance().build("/memberCenter/selectLoginActivity").navigation(context as Activity, requestCode)
        } else {
            ARouter.getInstance().build("/memberCenter/selectLoginActivity").navigation(context)
        }
    }
}
```

因为前面在被赋值的时候,MemberCenterFragment里面不管的getActivity()还是mActivity都是为null的. LoginNVCallBack构造方法的activity: Activity?也为null,但是在调用主构造方法的时候被强转为非空类型,所以出现了异常.可能以为混编的问题,错误日志也没有得到输出.造成了上述的问题,以后要注意.

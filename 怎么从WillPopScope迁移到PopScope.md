# 怎么从WillPopScope迁移到PopScope

 最近把flutter升级到了3.22.0-0.1.pre,3.19的正式版在我的项目上有些问题,先到预览版过渡一下.

发现WillPopScope被弃用了:

```dart
@Deprecated(
  'Use PopScope instead. '
  'This feature was deprecated after v3.12.0-1.0.pre.',
)
class WillPopScope extends StatefulWidget {
```

迁移到了PopScope,但是PopScope接受的是否pop的参数和WillPopScope相比变化较大,

WillPopScope:

```dart
  /// Called to veto attempts by the user to dismiss the enclosing [ModalRoute].
  ///
  /// If the callback returns a Future that resolves to false, the enclosing
  /// route will not be popped.
  final WillPopCallback? onWillPop;
  
  typedef WillPopCallback = Future<bool> Function();
  
```

本来是接收一个返回Future<bool> 的callback的,方便我们在里面进行一些异步的操作判断当前是否需要pop,用起来是非常方便的.但是PopScope的改成了:

```dart
  /// {@template flutter.widgets.PopScope.canPop}
  /// When false, blocks the current route from being popped.
  ///
  /// This includes the root route, where upon popping, the Flutter app would
  /// exit.
  ///
  /// If multiple [PopScope] widgets appear in a route's widget subtree, then
  /// each and every `canPop` must be `true` in order for the route to be
  /// able to pop.
  ///
  /// [Android's predictive back](https://developer.android.com/guide/navigation/predictive-back-gesture)
  /// feature will not animate when this boolean is false.
  /// {@endtemplate}
  final bool canPop;
  
  
    /// {@template flutter.widgets.PopScope.onPopInvoked}
  /// Called after a route pop was handled.
  /// {@endtemplate}
  ///
  /// It's not possible to prevent the pop from happening at the time that this
  /// method is called; the pop has already happened. Use [canPop] to
  /// disable pops in advance.
  ///
  /// This will still be called even when the pop is canceled. A pop is canceled
  /// when the relevant [Route.popDisposition] returns false, such as when
  /// [canPop] is set to false on a [PopScope]. The `didPop` parameter
  /// indicates whether or not the back navigation actually happened
  /// successfully.
  ///
  /// See also:
  ///
  ///  * [Route.onPopInvoked], which is similar.
  final PopInvokedCallback? onPopInvoked;


typedef PopInvokedCallback = void Function(bool didPop);
```

直接接收一个bool,和一个不好用的回调,不能再愉快的进行异步调用判断是否要pop了,个人觉得是反向升级.那么在PopScope下怎么进行异步判断呢?

```dart
    return WillPopScope(
      onWillPop: () async {
        return await checkHasNoUpload();
 	},
 	child:child
 	};
 	~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 	 return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if(didPop){
          return;
        }
        if (await checkHasNoUpload()) {
          Get.back();
        }
      },
      child:child
 	};
 	
```

麻烦了不少.
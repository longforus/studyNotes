# Kotlin的inline noinline笔记

## inline

这个关键字用于函数声明,表示这个函数的内联的,编译器在编译时会对这种函数进行优化,如何优化的呢?

先有如下代码:

```kotlin
fun main(args: Array<String>) {
    fun1("123123")
}
inline fun fun1(arg: String) {
    println("这里是fun1")
    fun2(arg)
}
fun fun2(arg: String) {
    println("这里是fun2")
    println(arg)
}
```



1. 把这个函数的函数体复制到所有调用到它的地方.形参也会被复制到这个方法内使用到的地方.我们看一下kotlin编译后的字节码反编译回来的java代码.

   ```java
     public static final void main(@NotNull String[] args) {
         Intrinsics.checkParameterIsNotNull(args, "args");
         //看这里并没有调用fun1,而是直接把fun1的代码复制到了这里
         String arg$iv = "123123";
         String var2 = "这里是fun1";
         System.out.println(var2);
         fun2(arg$iv);
      }
   
      public static final void fun1(@NotNull String arg) {
         Intrinsics.checkParameterIsNotNull(arg, "arg");
         String var2 = "这里是fun1";
         System.out.println(var2);
         fun2(arg);
      }
   
      public static final void fun2(@NotNull String arg) {
         Intrinsics.checkParameterIsNotNull(arg, "arg");
         String var1 = "这里是fun2";
         System.out.println(var1);
         System.out.println(arg);
      }
   ```

2. 还会做一些比较基础的代码的优化.

   ```kotlin
   /**
    * 简单启动Activity
    */
   inline fun <reified C : Activity> Activity.myStartActivity(vararg args: Pair<String, String>,  requestCode: Int = -1) {
       val intent = Intent(this, C::class.java)
       for (arg in args) {
           intent.putExtra(arg.first, arg.second)
       }
       if (requestCode > 0) {
           this.startActivityForResult(intent, requestCode)
       } else {
           this.startActivity(intent)
       }
   }
   ```

   先这么调用`myStartActivity<MainActivity>("key" to "value")`内联后的结果是:

   ```java
     Pair[] args$iv = new Pair[]{TuplesKt.to("key", "value")};
         int requestCode$iv = true;
         Intent intent$iv = new Intent((Context)this, MainActivity.class);
         int var8 = args$iv.length;
         for(int var9 = 0; var9 < var8; ++var9) {
            Pair arg$iv = args$iv[var9];
            intent$iv.putExtra((String)arg$iv.getFirst(), (String)arg$iv.getSecond());
         }
   	//看这里,根据参数直接决定调用哪个方法,省去了if判断
         this.startActivity(intent$iv);
   ```

   再这么调用`myStartActivity<MainActivity>("key" to "value",requestCode = 123)`,结果是:

   ```java
    byte requestCode$iv = 123;
         Pair[] args$iv = new Pair[]{TuplesKt.to("key", "value")};
         Intent intent$iv = new Intent((Context)this, MainActivity.class);
         int var7 = args$iv.length;
         for(int var8 = 0; var8 < var7; ++var8) {
            Pair arg$iv = args$iv[var8];
            intent$iv.putExtra((String)arg$iv.getFirst(), (String)arg$iv.getSecond());
         }
   	//看这里,根据参数直接决定调用哪个方法,省去了if判断
         this.startActivityForResult(intent$iv, requestCode$iv);
   ```



   这些就是目前我了解到的关于inline的一些细节.


## noinline

在inline的方法里默认所有形参都是inline的,内联后会被复制到这个函数中使用到的位置.如果形参是函数类型,同样会被复制到这个位置.假如有一个这样的方法:

```kotlin
fun main(args: Array<String>) {
    val lock = ReentrantLock()
    check(lock){
        println("funfun")
    }
}

inline fun <T> check( lock: Lock, body: () -> T): T {
    lock.lock()
    try {
        return body()
    } finally {
        lock.unlock()
    }
}
```

在内联后会变成:

```java
 public static final void main(@NotNull String[] args) {
      Intrinsics.checkParameterIsNotNull(args, "args");
      ReentrantLock lock = new ReentrantLock();
     //注意把check()的方法体复制到了这里,并没有调用check()
      ((Lock)lock).lock();
      try {
         //body的内容被复制到了这里,body这个函数被删除了 
         String var2 = "funfun";
         System.out.println(var2);
         Unit var7 = Unit.INSTANCE;
      } finally {
         ((Lock)lock).unlock();
      }
   }
   
   public static final Object check(@NotNull Lock lock, @NotNull Function0 body) {
      Intrinsics.checkParameterIsNotNull(lock, "lock");
      Intrinsics.checkParameterIsNotNull(body, "body");
      lock.lock();
      Object var3;
      try {
         var3 = body.invoke();
      } finally {
         InlineMarker.finallyStart(1);
         lock.unlock();
         InlineMarker.finallyEnd(1);
      }
      return var3;
   }

```

这种情况下就会出现一个问题,如果我要把body再传给其他的函数使用呢?比如这样:

```kotlin
inline fun <T> check(lock: Lock, body: () -> T): T {
    lock.lock()
    try {
        otherCheck(body)//会报错,说内联的参数需要被声明为noinline的才可以传给其他函数
        return body()
    } finally {
        lock.unlock()
    }
}

fun <T> otherCheck(body: () -> T) {
    println("check $body")
}
```

这种情况下就需要用到noinline这个关键字:

```kotlin
inline fun <T> check(lock: Lock,noinline body: () -> T): T {
    lock.lock()
    try {
        otherCheck(body)//OK
        return body()
    } finally {
        lock.unlock()
    }
}

fun <T> otherCheck(body: () -> T) {
    println("check $body")
}
```

这样body在编译的时候就不会被内联优化,反编译得:

```java
public static final void main(@NotNull String[] args) {
      Intrinsics.checkParameterIsNotNull(args, "args");
      ReentrantLock lock = new ReentrantLock();
    //body函数被保留了 没有被内联优化
      Function0 body$iv = (Function0)null.INSTANCE;
      ((Lock)lock).lock();
      try {
          //可以传给otherCheck()函数
         otherCheck(body$iv);
         Object var3 = body$iv.invoke();
      } finally {
         ((Lock)lock).unlock();
      }
   }

   public static final Object check(@NotNull Lock lock, @NotNull Function0 body) {
      Intrinsics.checkParameterIsNotNull(lock, "lock");
      Intrinsics.checkParameterIsNotNull(body, "body");
      lock.lock();
      Object var3;
      try {
         otherCheck(body);
         var3 = body.invoke();
      } finally {
         InlineMarker.finallyStart(1);
         lock.unlock();
         InlineMarker.finallyEnd(1);
      }
      return var3;
   }

   public static final void otherCheck(@NotNull Function0 body) {
      Intrinsics.checkParameterIsNotNull(body, "body");
      String var1 = "check " + body;
      System.out.println(var1);
   }
```

就是这样被noinline修饰的函数类型参数不会被内联优化.
# RxJava使用filter时如何知道是否所有的item都被过滤了?

有时候会使用rxJava的filter操作符来过滤重复的数据,用起来非常的方便,返回true的元素会通过,返回false的元素则会被丢弃.但是存在这样一种情况,如果所有的元素都被过滤掉了,丢弃了,后续subscribe的onNext()也不会被调用.这个时候我们要如何得知呢?大多数情况下都不需要关心,但是在有的情况下我们又需要知道,是不是所有的元素都被过滤了.

filter操作符本身并没有提供这样的功能,只能通过其他的方式了:

```kotlin
var hasElement = false
map = map.filter {
   return 过滤结果
 }.doOnNext {
       hasElement = true
 }.doOnTerminate {
     if (!hasElement) {
        	//全被过滤了
         onResult.invoke(0)
   }
}
```

这样在onTerminate的时候我们查看是否有元素被发射,就知道有没有被全部过滤掉了.


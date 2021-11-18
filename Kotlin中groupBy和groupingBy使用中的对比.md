# Kotlin中groupBy和groupingBy使用中的对比

今天在看Kotlin的Coroutines官方文档练英文的时候,它有个[Hands-on](https://play.kotlinlang.org/hands-on/Introduction%20to%20Coroutines%20and%20Channels/02_BlockingRequest),在里面要实现一个aggregate的功能,先来看看我的初版实现:

```kotlin
fun List<User>.aggregate(): List<User> {
    val map = this.groupBy { it.login }
    val result = ArrayList<User>(map.keys.size)
    for (login in map.keys) {
        result.add(User(login, map[login]?.sumOf { it.contributions } ?: 0))
    }
    result.sortByDescending { it.contributions }
    return result
}
```

再来看看官方的实现:

```kotlin
fun List<User>.aggregate(): List<User>  = groupBy { it.login }
    .map { (k,v)-> User(k, v.sumOf { it.contributions })}
    .sortedByDescending { it.contributions }
```

我自己的实现和官方的解决方案都用了`groupBy`,这个函数的功能就是根据给定的key遍历list进行分组:

```kotlin
/**
 * Groups elements of the original collection by the key returned by the given [keySelector] function
 * applied to each element and returns a map where each group key is associated with a list of corresponding elements.
 * 
 * The returned map preserves the entry iteration order of the keys produced from the original collection.
 * 
 * @sample samples.collections.Collections.Transformations.groupBy
 */
public inline fun <T, K> Iterable<T>.groupBy(keySelector: (T) -> K): Map<K, List<T>> {
    return groupByTo(LinkedHashMap<K, MutableList<T>>(), keySelector)
}
```

相比官方我没有用map而是用了一个局部变量来接收`groupBy`的结果供后续处理,排序也没有注意到有一个`sortByDescending`还有一个`sortedByDescending`,明显不如官方的简练.

但是在文章中后面又说:`An alternative is to use the function `groupingBy` instead of `groupBy`.😳😳😳还有一个`groupingBy`吗?之前都没有注意到有这个东西,让我来康康:

```kotlin
/**
 * Creates a [Grouping] source from a collection to be used later with one of group-and-fold operations
 * using the specified [keySelector] function to extract a key from each element.
 * 
 * @sample samples.collections.Grouping.groupingByEachCount
 */
@SinceKotlin("1.1")
public inline fun <T, K> Iterable<T>.groupingBy(crossinline keySelector: (T) -> K): Grouping<T, K> {
    return object : Grouping<T, K> {
        override fun sourceIterator(): Iterator<T> = this@groupingBy.iterator()
        override fun keyOf(element: T): K = keySelector(element)
    }
}

```

看代码这里并没有进行遍历操作而是直接返回了一个`Grouping`类型的源数据的*界面*.不处理数据直接交给后续的操作处理.在这个例子中相对于`groupBy`可以减少一次遍历.那用`groupingBy`如何实现呢?

```kotlin
fun List<User>.aggregateFromGrouping(): List<User> = groupingBy { it.login }
    .aggregate<User, String, Int> { _, accumulator, element, _ ->
        element.contributions + (accumulator ?: 0)
    }
    .map { (k, v) -> User(k, v) }
    .sortedByDescending { it.contributions }
```

看起来比`groupBy`复杂一点点,在`aggregate`这真正的遍历操作数据的这一步这里需要要繁杂一点点,但是因为少了一次遍历,在我的电脑上重复一千万次会比使用`groupBy`快一些:

```kotlin
 println("start groupingBy")
 val s2 = System.currentTimeMillis()
 repeat(10000000){
     actual = list.aggregateFromGrouping()
 }
 println("end groupingBy ${System.currentTimeMillis()-s2}ms")

 println("start groupBy")
 val s1 = System.currentTimeMillis()
 repeat(10000000){
     actual = list.aggregate()
 }
 println("end groupBy ${System.currentTimeMillis()-s1}ms")

-------------------------------result-------------------------
start groupingBy
end groupingBy 2064ms
start groupBy
end groupBy 2439ms
```

综上在性能要求严格的情况下推荐使用`groupingBy`.

水完,下班.🚍


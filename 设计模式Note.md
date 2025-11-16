# 设计模式Note

标签（空格分隔）： Note 设计模式 基础知识 

[TOC]

## 1.OO原则

- **封装变化**
- **多用组合,少用继承**
- **针对接口编程,不针对实现编程**
- **为交互对象之间的松耦合设计而努力**
- 开闭原则 :**类对扩展开放,对修改封闭**
- 依赖倒置原则 :**要依赖抽象,而不依赖具体的类**
- 最少知识原则(得墨忒耳原则):**只和你的密友谈话**  ,减少对象之间的交互,不要让太多的类耦合在一起.
对象 O 的 M 方法，可以访问/调用如下的：
    - 对象 O 本身
    - M 方法的传入参数
    - M 方法中创建或实例化的任意对象
    - 对象 O 直接的组件对象
    - 在M范围内，可被O访问的全局变量
- 好莱坞原则:**别调用我们,我们会调用你** ,让底层组件不要主动调用高层组件,而是让高层组件主动调用底层组件.
- 单一责任原则: **一个类应该只有一个引起变化的原因**,一个类的职责应该是单一的,如果存在一种以上职责那么引起这个类变化的因素将会大大增加,应该把一个职责只指派给一个类.这样才能提高类的内聚性.(当一个类或者模块被设计成只支持一组相关的功能的时候,就可以说这个设计的高内聚的,反之被设计成支持一组不相关的功能时则是低内聚的,高内聚的设计往往更容易维护).

---
## 2.策略模式

把一个类的"动作",(一般都用方法来实现)封装为一个field,将这个"动作"抽象为一个Interface,类持有这个Interface的实现,在要调用这个"动作"的时候调用这个实现的method.从而达到"动作"和类的解耦,也可以在运行时动态的替换这个"动作"的具体实现方式.比如说:机器人的说话这个动作,常规实现的话是以一个方法来实现的,要说话的时候就调用说话()这个方法,说什么内容在法内部实现,如果使用策略模式的话就把 说话这个动作抽象为一个接口,在构造或者其他地方传入说话这个方法的具体实现, 说"呵呵"  ,说"呵呵"这个动作不仅仅在机器人可以做,人也可以做.这样就让说"呵呵"这个动作和机器人解耦了,在运行时也可以,动态的替换 说话这个接口的实现 让他说"哈哈",如果用方法来实现话,这就不太容易实现了.

## 3.观察者模式

让任意对象能够第一时间了解到关心的对象的状态,被观察者实现被观察者的接口,在内部maintain一个实现了观察者接口的订阅者的列表.观察者实现观察者接口,调用被观察者的subscribe方法,把自己添加到被观察者的订阅者列表中,被观察者在自己发生改变后,遍历列表调用观察者接口的方法,通知观察者自己发生了改变.优势是观察者可以及时获悉被观察者的变化,而且加入订阅和解除订阅的灵活的,可以在运行中动态改变

## 4.装饰者模式

装饰者和被装饰者实现同样的接口,这样在本来调用被装饰者的地方就可以使用装饰者进行替换,在原本调用被装饰者的方法处,实际调用的却是装饰者的方法,装饰者在该方法中再调用被装饰者的对应方法,但是装饰者就可以在被装饰者的对应方法执行前或者执行后,执行额外的代码,将被装饰的方法进行装饰,而且可以多层嵌套,适用于对不可更改的被装饰者类进行扩展.
``` kotlin
abstract class Beverage {//装饰接口
  abstract var des:String
  abstract var price:Double
  abstract var size: Size
  abstract fun cost():Double

  override fun toString(): String {
    return "我是 $des 我的价格是 $price"
  }
}

class DarkRoast(override var size: Size) : Beverage() {//被装饰者

  override fun cost(): Double {
      price = 11.0
      println(this)
      return price
  }

  override var des: String = "深焙咖啡"

  override var price: Double = 10.0
}

abstract class DecorateBeverage(var beverage: Beverage?) : Beverage() {//装饰者接口和被装饰者实现相同的接口,并持有被装饰者的引用
  abstract var classify:String
  override fun cost(): Double {
    println(this)
    return price + if (beverage==null) 0.0 else (beverage as Beverage).cost()
  }

  override var size: Size = Size.MID

  override fun toString(): String {
    return super.toString()+"  种类 : $classify"
  }
}

class Mocha (beverage: Beverage): DecorateBeverage(beverage){//装饰者实现
  override var classify: String= "可可类"
   
  override var des: String = "摩卡"
   
  override var price: Double= 1.0

}


  var result: Beverage = DarkRoast(Size.BIG)
  result = Mocha(result)//装饰者持有被装饰者且可以多层嵌套装饰
  result = Whip(result)
  result = Whip(result)
  println(result.cost())

```
## 5.工厂模式

### 5.1工厂方法
父类持有需要产品的接口引用,在不了解也不关心产品的具体实现的情况下对产品执行后续的公用操作,定义一个abstract的工厂方法生产产品,具体的产品实现交给子类来实现,让父类和具体的产品解耦,而只关心对产品的公共逻辑操作.

### 5.2抽象工厂
与工厂方法不同的是抽象工厂更适合一组对象的创建,定义一个接口,提供多个抽象的产品抽象生产方法,具体的工厂来实现这个接口,在实现的方法中生产具体的对应产品并返回.也达到了消费者和具体的产品的解耦,消费者依赖产品的抽象,实现具体的逻辑,而不必关心,具体的产品细节.


## 6.单例模式
整个生命周期仅对外提供唯一的实例.

* volatile 关键字 在多线程的cpu当中,总是把一个变量从内存读到cache中再进行操作,完成 后再放回内存当中,假设 int a = 10,可能存在这样的一种情况,假设变量在Thread1读取a到cache中,执行a+=1,执行完成后a应该等于11,但是这期间Thread2也读取a到cache中执行 b = a+1 的操作,这时候因为Thread1尚未将a的新值11,刷回到内存中,所以Thread2读取到的a为10,执行的结果b=11,Thread1在执行完后把等于11的a放回内存中,这时a==11,Thread2也把执行的结果放回内存中,b==11,就和本来预期的b==12不同了,出现错误.volatile关键字的作用在于:被它修饰的变量的值如果被改变,会马上刷新回内存中,这样Thread2读取到新的a的值的情况加大,但是也无法保证a的原子性(原子性和Fragment的transaction类似,开启一个transaction后所执行的所有操作都只在这个transaction commit后才全部一起执行,保证不会因为一些原因造成这一些列的操作只执行了一部分而中断),貌似也无法完全避免并发出错的情况.


## 7.命令模式

将请求动作封装成命令对象,让命令动作不在针对具体的对象,只管发出命令,具体的执行命令对象和具体的动作由实现命令接口的命令对象来实现.
``` kotlin
    interface Command   {
    fun execute()
    fun undo()
    }
    
    class LightOnCommand(var light:Light) :Command {
    override fun undo() {//命令模式的撤销操作就是做执行操作的反动作
        light.off()
    }

    override fun execute() {//执行具体的命令    执行命令的具体是谁,执行了什么命令,发送命令者是不知道,不关心的
        light.on()
    }
    }

    class RemoteControl {
    var slot:Command?  = null//持有命令对象

    fun onPressed(){//发出命令
        slot?.execute()
    }

    fun onRepeal() {
        slot?.undo()
    }
    }
    
    val remoteControl = RemoteControl()//命令发送方
    val light = Light()//具体的命令接收方
    val lightOnCommand = LightOnCommand(light)//命令对象
     remoteControl.slot = lightOnCommand//命令发送方只持有命令对象,具体的接收命令方和具体的动作不关心
    remoteControl.onPressed()//发出命令
    remoteControl.onRepeal()//撤销命令
    val door = Door()
    val doorOnCommand = DoorOnCommand(door = door)
    remoteControl.slot = doorOnCommand//运行中也可以改变命令对象
    remoteControl.onPressed()
```

## 8.适配器和外观模式
### 8.1适配器
1. *对象适配器:*假如现有接口A和B,一个method(Client)需要一个A的实现,但是实际情况我们却需要传一个B的实现(被适配者)给它,在不修改既有代码的情况下怎么实现呢?新建一个adapter对象实现A接口,让adapter持有B的实现,在实现A的接口方法中调用需要用到的B接口的实现方法,现在把这个adapter传给需要A接口的method就可以实现了.Client和被适配对象之间的解耦的,并不知道对方,Client以为自己调用的A接口的实现,但是实际通过adapter调用的却是B的实现.    

2. 假如存在这样一种情况,1中原来Client需要A的实现,我们用adapter进行了适配实现,后来Client有了升级现在直接需要B的实现了,这就会导致部分前面的代码使用adapter实现而新的部分则没有,不统一,这种情况下,可以让adapter同时实现A接口和B接口,在实现的B方法中调用A接口的方法.既可以被当作A也可以被当作B.

3. 还有一种用法是现有接口A拥有很多的抽象方法,可是在实际需要中可能只需要其中的一两个,难道每次都实现A接口,空着一堆的空实现么?这个时候就可以创建一个adapter实现A接口,但是每一个方法(需要每一个实例都实现的方法可以不实现,让adapter成为一个abstract class)都只做空实现,在需要A接口的地方我们传入adapter的实现,再选择性的实现自己需要的方法,就可以避免到处都有很多空实现方法的情况,awt和swing包的设计(e.g. clickListener)里面这样的思想比较常见.
4. *类适配器:*适配器同时继承Client需求的接口类和被适配接口类,在Client调用的接口方法中调用被适配接口的实现方法,不能在java等不支持多继承的语言中实现.

``` kotlin
/**
 * Created by XQ Yang on 2017/9/7  19:12.
 * Description : 对象适配器模式
 */
class EnumerationIterator<T>(var enum:Enumeration<T>/*持有被适配对象的引用*/):MutableIterator<T> {//继承自客户要求的接口
    
    override fun remove() {
        throw UnsupportedOperationException()
    }

    override fun next(): T {
        return enum.nextElement()//转交给被适配对象
    }

    override fun hasNext(): Boolean {
         return  enum.hasMoreElements()
    }
}

    //使用
    var vector:Vector<Int> = Vector()
    vector.addElement(1)
    vector.addElement(2)
    vector.addElement(3)
    vector.addElement(5)
    var list = arrayListOf<Int>(6,7,8,9)
    var itrator :MutableIterator<Int> =  EnumerationIterator<Int>(vector.elements())//面向接口不面向实现,所以要使用接口声明实现,传入被适配对象
    while (itrator.hasNext()) {
        println(itrator.next())
    }
    itrator = list.iterator()//同样的适配器接口调用
    while (itrator.hasNext()) {
        println(itrator.next())
    }
```
### 8.2和装饰者模式的区别
装饰者和被装饰者实现同样的接口,且持有和自己继承接口同类型的被装饰者的引用,装饰者模式还可以实现互不可见的嵌套装饰,主要用途是**扩展**
适配器不继承自被适配对象的接口,而是继承自客户要求的接口,持有的被适配对象也不是继承接口的实现.主要用途是**传送**
### 8.3外观模式
有时候需要达到目的,需要按照一定的顺序调用一堆的接口,外观模式就是简化这个过程的:提供一个统一的接口来访问子系统中的一群接口,定义高层接口,简化使用过程.具体使用:定义一个外观接口,实现中持有所有需要调用的子系统中的接口的实现示例,暴露高层接口,在高层接口的实现中按照要求调用子系统的接口,达到简化操作的目的.


适配模式-转换接口
外观模式-统一接口,简化操作

## 9.模版方法
在父类中定义一个算法框架(经常是一个方法,最好声明为final的,防止子类篡改,对算法进行保护.里面按照固定的顺序执行一系列的操作),把共同操作实现,把非共性的方法声明为abstract的方法,延迟到具体的子类中实现.让子类在不修改算法结构的前提下,重新定义算法中的一些步骤.对于一些非所有子类都需要实现的步骤,不必声明为abstract的,空实现即可,子类可以选择性的来覆写它,实现一些步骤,或者返回一个值(booblen等等)而对算法的执行逻辑进行一些改变,这样的方法叫做:"hook".

## 10.迭代器模式
提供一种方法访问内部持有集合,而不用关心内部集合的具体实现.(Array?List?Set...),达到解耦和保护内部集合的目的.可以自行定义接口或者使用`java.util.Iterator<E>`接口.
``` kotlin
interface MyIterator<T> {
    fun hasNext():Boolean
    fun next():T
    fun remove():T
}

class ArrayIteratorImpl<T>(val array: Array<T>):MyIterator<T> {
    var index:Int = -1
    override fun next(): T {
     return array[++index]
    }
    override fun remove(): T {
        throw UnsupportedOperationException()
    }
    override fun hasNext(): Boolean {
        return index+1<array.size-1&&array[index+1]!=null
    }
}

//kotlin的Array和list的默认就可以使用同样的方法 方便
class ListIteratorImpl<T>(val list: List<T>): MyIterator<T> {
    var index:Int = -1
    override fun next(): T {
     return list[++index]
    }
    override fun remove(): T {
        if (list is MutableList) {
            return list.removeAt(index)
        } else {
            throw UnsupportedOperationException()
        }
    }
    override fun hasNext(): Boolean {
        return index<list.size-1
    }
}

    var array = arrayOf("2","3","5","6")
    var  list = listOf<String>("a","b","d","g")

    var myIt:MyIterator<String> = ArrayIteratorImpl(array)
    showIterator(myIt)//这里的方法就得到了复用
     myIt = ListIteratorImpl(list)
    showIterator(myIt)

private fun showIterator(myIt: MyIterator<String>) {
    while (myIt.hasNext()) {
        println(myIt.next())
    }
}

```
## 11.组合模式
适用于有数个对象集合,他们之间存在着"部分/整体"的模式,定义一个接口Inf,既持有需要持有的对象A a(可以是一个集合),也持有一个和自己类型相同的引用inf,这样它既可以代表需要持有的对象a(这时候一般不会持有inf),也可以代表inf(这时候一般不会持有a),inf同样可以持有A类型的a1和Inf类型的 inf2.达到同种数据结构嵌套的目的.让Client可以用相同的方式来处理个别对象和组合的对象.

```kotlin
interface CompsiteMenu<T>:Iterator<T>  {
    var subMenu:CompsiteMenu<T>?
}

class CompsiteMenuImpl(var array: Array<String>?, override var subMenu: CompsiteMenu<String>?) :CompsiteMenu<String>{
    var index = -1
    override fun hasNext(): Boolean {
        if (array == null) {
            return false
        } else {
            return index+1<= array!!.size-1&&!array?.get(index+1)?.isEmpty()!!
        }
    }
    override fun next(): String {
        if (array == null) {
            return ""
        }
        return array?.get(++index)!!
    }
}

    var array = arrayOf("2", "3", "5", "6")
    var array1 = arrayOf("a", "b", "d", "g")
    var cmi = CompsiteMenuImpl(array, null)
    var cmi1 = CompsiteMenuImpl(null, CompsiteMenuImpl(array1, null))
    var carray = arrayOf(cmi, cmi1)
    for (impl in carray) {
        printImpl(impl)//使用统一的方式处理组合对象
    }

fun printImpl(impl: CompsiteMenu<String>) {
    val iterator = impl!!.iterator()
    while (iterator.hasNext()) {
        println(iterator.next())
    }
    if (impl.subMenu != null) {
        printImpl(impl.subMenu!!)//递归遍历
    }
}
```
## 12.状态模式
允许对象在内部状态改变时修改他的行为,抽象一个接口IState,拥有对象A的所有行为方法,根据不同的状态,实现IState的不同的实例,实现对应状态下不同方法的不同操作.A持有当前状态的实例curState,在A的状态改变的时候,切换A中当前状态curState持有的引用,在调用A的动作的时候,委托给当前状态的实现,从而改变不同状态下的不同行为.这和策略模式很像,不同的地方是:对于策略模式,不同的行为通常是由客户来指定的,而状态模式下,客户对于状态的切换通常是不关心,甚至是不可见的.把状态对象声明为static的并只在调用curState的时候传入A对象就能实现状态对象的复用.
```kotlin
interface IState {
    var curStateStr:String
    var machine:GumballMachine
    fun insert()//定义所有的行为
    fun retrieve()//每一个state实现对象状态下的对应行为
    fun turnCrank()
    fun dispense()
}

interface IGumballMachine {
    fun insert()
    fun retrieve()
    fun turnCrank()
    fun releaseBall()//如何限制这个方法只能被IState的子类调用?
}


class GumballMachine(gumballCount: Int) :IGumballMachine{
   lateinit  var curState:IState
    var curCount = gumballCount
    var curMoneyCount = 0
    val noMoneyState:IState = NoMoneyState("noMoney",this)//可以声明为static  放到别的类中  实现复用
    val hasMoneyState:IState = HasMoneyState("hasMoney",this)
    val soldOutState:IState = SoldOutState("soldOut",this)
    val soldState:IState = SoldState("sold",this)
    init {
        if (curCount >0) curState =noMoneyState else soldOutState
    }
    override fun insert() {
        curState.insert()
    }

    override fun retrieve() {
       curState.retrieve()
    }

    override fun turnCrank() {
        curState.turnCrank()
        curState.dispense()
    }

    override  fun releaseBall() {
        curMoneyCount--
        if (--curCount>0) (if (curMoneyCount>0) curState = hasMoneyState else curState  =noMoneyState) else curState = soldOutState
        println("卖了一个球,还剩下${curCount}个")
    }
}


class HasMoneyState(override var curStateStr: String, override var machine: GumballMachine) :IState {
    override fun insert() {
        machine.curMoneyCount++
        println("现在有${machine.curMoneyCount}个钱")
    }

    override fun retrieve() {
        machine.curMoneyCount--
        println("退了一个钱 还有${machine.curMoneyCount}个")
        if (machine.curMoneyCount<1) machine.curState = machine.noMoneyState else machine.curState=machine.hasMoneyState
    }

    override fun turnCrank() {
        machine.curState = machine.soldState
    }

    override fun dispense() {

    }
}


class NoMoneyState(override var curStateStr: String, override var machine: GumballMachine) :IState {
    override fun insert() {
        machine.curMoneyCount++
        println("投入1个钱")
        machine.curState = machine.hasMoneyState
    }

    override fun retrieve() {
        if (machine.curMoneyCount < 1) {
            println("钱都没投退个毛")
        } else {
            throw IllegalStateException("没有钱的状态其实有钱")
        }
    }

    override fun turnCrank() {
        println("钱都没投拉个毛")
    }

    override fun dispense() {

    }
}

class SoldOutState(override var curStateStr: String, override var machine: GumballMachine) : IState {
    override fun insert() {
        println("没有球了,别投了")
    }

    override fun retrieve() {
        if (machine.curMoneyCount < 1) {
            println("钱都没投退个毛")
        } else {
            throw IllegalStateException("没有球的状态其实有钱")
        }
    }

    override fun turnCrank() {
        println("没有球了,拉毛啊")
    }

    override fun dispense() {

    }
}

class SoldState(override var curStateStr: String, override var machine: GumballMachine) : IState {
    override fun insert() {
        println("正在出球")
    }

    override fun retrieve() {
        println("买都买了不能退了哦")
    }

    override fun turnCrank() {
        println("正在出球")
    }

    override fun dispense() {
        machine.releaseBall()
    }
}

val machine = GumballMachine(5)
    machine.retrieve()
    machine.turnCrank()
    machine.insert()
    machine.retrieve()
    machine.insert()
    machine.turnCrank()
    machine.insert()
    ~~~~~

```

## 13.代理模式
*为另一个对象提供一个替身或占位符以访问这个对象*,代理对象和被代理对象实现同样的接口(貌似是可选的),代理对象持有被代理对象的引用(或负责创建被代理对象),Client访问代理,代理可选的调用被代理对象的方法,把结果返回给Client.这样代理可以对被代理对象的访问进行控制和保护.这和装饰者模式很像,区别是装饰者模式的目的是增加行为,代理的目的是控制访问.

- 虚拟代理
在某些消耗过大的对象创建或者耗时操作进行的时候,通过虚拟代理代理客户对这些对象的访问,在被代理对象未准备好之前,并不把客户的访问转交,在被代理对象创建完成或者操作完成后,才正的把Client的操作转交给被代理对象.这种模式下被代理对象一般都是由proxy创建的.

- 远程代理
代理本地Client对远程对象的访问,本地Client访问proxy,proxy再访问远程对象,并把result返回给Client,让本地Client访问远程对象感觉就像访问本地对象一样.,java一般使用rmi包下的类来实现,和安卓的aidl实现方式很类似.

- 保护代理
控制对被代理对象的访问.下面的java的动态代理示例.
**只适用于java环境**
``` java
interface IPerson {
    var name:String
    var rating:Int
    var ratingCount:Int
    var gender:String
    fun setHotOrNot( rating:Int)
}

class Person(override var name: String, override var gender: String) : IPerson {
    override fun setHotOrNot(rating: Int) {
        this.rating+=rating
        ratingCount++
    }

    override var rating: Int = 0
    override var ratingCount: Int = 0
}

class OwnerInvocktionHandler(val person: IPerson):InvocationHandler {
    override fun invoke(proxy: Any?, method: Method?, args: Array<out Any>?): Any? {
        if (method == null) {
            return null
        }
        if (method.name == "setHotOrNot") {//不允许自己调用的方法
            throw IllegalStateException("not set")
        }else if (method.name.startsWith("get")||method.name.startsWith("set")) {
            return method.invoke(person,args)
        }
        return null
    }
}

class OtherHandler implements InvocationHandler {
    private IPerson mPerson;

    public OtherHandler(IPerson person) {
        mPerson = person;
    }

    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        if (method == null) {
            return null;
        }
        if (method.getName().startsWith("get")||method.getName().equals("setHotOrNot") ) {
            return method.invoke(mPerson, args);
        }else if (method.getName().startsWith("set")) {//别人不允许调用设置自身属性的方法
            throw new IllegalStateException("not set");
        }
        return null;
    }
}


class PersonProxy {
    fun getOwenProxy(person: IPerson):IPerson{
        return Proxy.newProxyInstance(person.javaClass.classLoader,person.javaClass.interfaces,OwnerInvocktionHandler(person = person)) as IPerson
    }
    fun getOtherProxy(person: IPerson):IPerson{
        return Proxy.newProxyInstance(person.javaClass.classLoader,person.javaClass.interfaces,OtherHandler(person)) as IPerson
    }
}

    var person = Person("花儿","美眉")
    val proxy = PersonProxy()
    val otherProxy = proxy.getOtherProxy(person = person)
    val owenProxy = proxy.getOwenProxy(person)
    otherProxy.setHotOrNot(1)
    println(otherProxy.name)
    otherProxy.gender = "haha"//不允许别人修改自己的属性 
```

- 类似模式的区别
| 模式        | 描述   |
| --------   | :-----:  |
| 装饰者     |包装另一个对象,并提供额外的行为|
| 适配器     |包装另一个对象,并提供不同的接口(调用的其实是另外不同的接口)  |
| 代理        |  包装另一个对象,并控制对他的访问  |
| 外观        |  包装许多对象以简化他们的接口  |

## 14.复合模式
结合2个以上的模式,组成一个解决方案,解决一再发生的一般性问题.

## 15.桥接模式
在当前存在的抽象A(**抽象层**)的实现中可能存在多个角度的分类(比如:抽象车这个类,车从动力系统上就可以分成几类),每一种分类都可能出现变化(比如:动力系统的抽象需要添加一个抽象方法,如果不进行分离,那么所有的车的实现都需要实现这个方法),那就可以把这种多角度分离出来(把引擎抽象出来),成为另外的抽象B(**实现层**),A的实现持有B的实现,B的结构和的具体实现的变化不会再影响到A(比如B增加了抽象方法,不会对A造成任何影响,只需要B的实现去实现就好了),减少他们之间的耦合,(不同类型车持有不同类型引擎的具体实现,不关心实现的具体细节,只保持自己的相应调用).抽象和实现都可以独立扩展,不会影响到对方,这种模式下A 具有 has B的关系.

```kotlin
interface Abstraction {//抽象类层次
    var im:Implementor?//Implementor是Abstraction的一部分
    fun operation(){//如果Abstraction有无数的实现, 在Implementor发生扩展后,这些实现都无需更改
        im?.operationImpl()
    }
}

interface Implementor {//实现类层次
    fun operationImpl()//如果Implementor结构发生了改变,那么只要它的实现进行修改就好了  不会影响到 Abstraction
}

class RefinedAbstraction:Abstraction {
    override var im: Implementor? = null
}

class ConcreteImplmentorA:Implementor {
    override fun operationImpl() {
        println("concrete A")
    }
}

class ConcreteImplmentorB : Implementor {
    override fun operationImpl() {
        println("concrete B")
    }
}

fun main(args: Array<String>) {
    val abstraction = RefinedAbstraction()
    abstraction.im = ConcreteImplmentorA()
    abstraction.operation()
    abstraction.im = ConcreteImplmentorB()
    abstraction.operation()
}
```
## 16.构建者/生成器/Builder
在需要按照一定的步骤创建复杂的对象的时候可以使用构建者模式,先把需要的参数保存到构建者类中(通过调用的方法返回this,可以实现连点操作),最后构建的时候才按照一定的顺序,规则把参数组合生成被构建对象,返回给Client.这样对Client隐藏了产品的具体构建过程,而且产品还能够被替换.
## 17.一句话总结
| 模式        | 描述   |  备注    |
| --------   | :-----:  |    |
| 工厂方法  |  由子类决定要创建的具体类是哪一个  |  通过继承实现[^extends]  创建型   |
|抽象工厂  | 允许client创建一组对象,而不用指定他们的具体类  |   创建型    |
| 单例 | 确保只有一个对象被创建 |创建型|
| 构建者 | 管理创建过程,隐藏产品的内部细节 |创建型|
| 策略     |封装请求成为对象|  行为型    |
| 观察者    |让对象能在状态改变时得到通知  |    行为型  |
| 状态 | 封装基于状态的集合,并使用委托在行为之间切换 |  行为型   |
| 模版方法 | 由子类决定,如何实现一组算法中的一个步骤  | 通过继承实现   行为型 |
|迭代器  | 在对象的集合之间游走,而不暴露具体的集合实现 |  行为型  |
| 命令 | 封装可以互换的行为,并使用委托来决定使用哪一个 | 行为型   |
| 适配器 | 封装对象并提供不同的接口 |通过继承实现  结构型 |
| 外观 | 简化一群类的接口 |结构型|
| 装饰者       |  包装另一个对象,以提供新的行为  |  结构型   |
| 组合 | Client使用一致的方法处理对象的集合和单个对象  | 结构型   |
| 代理 | 包装对象,并控制对这个对象的访问  | 结构型   |
| 桥接 | 把可能会变化的抽象结构从主体中分离出来,即便发生改变也不会影响到主体  | 结构型   |

- *创建型* :涉及到将对象实例化,这类模式都提供一个方法,将Client从需要的实例化对象中解耦.
- *行为型* :都涉及到类和对象的交互和分配职责.
- *结构型* :把类或者对象组合到更大的结构中.

[^extends]: 类模式的建立在编译时.其他未标出的模式使用组合实现,对象模式的建立在运行时,更加的动态具有弹性.
# Java Note

## 泛型

Manager是Employee的子类.

- extends

  提供返回值,但是不提供方法参数.不能调用与类型有关的方法.因为类型擦除后,可以保证返回的结果肯定是Employee的子类实例,可以用Employee类型的变量接收.

  ```java
   List<? extends Employee> eList = new ArrayList<>();
   List<? extends Manager> mList = new ArrayList<>();
   eList = mList;//OK ,可以把一个List<? extends Manager> 或者 List<Manager>赋值给他
   Employee employee = new Employee("e", 1, 1, 1, 1);
   eList.add(employee);//error 也不能添加Employee的对象
   eList.add(ceo);//error 也不能添加Manager的对象
   boolean b = eList.addAll(mList);//error,不能添加Manager类型的对象或者list到里面,
   Employee e = eList.get(0);//但是获取到的对象的是Employee类型
  ```

- super

  不提供返回值,但是能调用与类型有关的方法.上界限定不是说限定于Employee的超类,而是与extends相反,擦除后可以接收的方法类型参数保证是Employee的子类实例,但是返回值类型不能确定.

  ```java
   List<? super Employee> eList = new ArrayList<>();
   List<Manager> mList = new ArrayList<>();
   eList = mList;//error ,不可以把一个List<? extends Manager> 或者 List<Manager>赋值给他
   Employee employee = new Employee("e", 1, 1, 1, 1);
   eList.add(employee);//ok 
   eList.add(ceo);//ok 
   eList.addAll(mList);//ok
   Object object = eList.get(0);//但是获取到的对象的是Object类型
  ```
  **直观地讲，带有超类型限定的通配符可以向泛型对象写人，带有子类型限定的通配符可以从泛型对象读取。** 

## Other

- 默认方法

  ```java
  interface IPerson {
       String getName();
  }
  ​```
  interface INamed {
     default String getName(){
         return "INamed";
     }
  }
  ​```
  class Person implements IPerson,INamed {
      @Override
      public String getName() {
          return INamed.super.getName();//实现的接口中拥有签名的方法时,需要显式指定调用父类的方法
      }
  }
  ```


## 多线程

### ReentrantLock

重入锁是可以重新取得锁并执行的锁,比`synchronized`更加灵活.

```java
public class Alipay {
    private double[] accounts;
    private ReentrantLock mLock;
    private Condition mCondition;

    public Alipay(int size,double initMoney) {
        accounts = new double[size];
        mLock = new ReentrantLock();
        //创建重入条件
        mCondition = mLock.newCondition();
        for (int i = 0; i < size; i++) {
            accounts[i] = initMoney;
        }
    }

    public void transfer(int from,int to,double money) throws InterruptedException{
        mLock.lock();//获得锁
        System.out.println(Thread.currentThread().getName()+" enter");
        try {
            while (accounts[from] < money) {
                System.out.println("accounts[from] < money await "+Thread.currentThread().getName());
                //条件不达到,阻塞当前线程,并放弃锁
                mCondition.await();
            }
            accounts[from] -= money;
            accounts[to] += money;
            System.out.println("success form = "+accounts[from]+" "+Thread.currentThread().getName());
            System.out.println("success to = "+accounts[to]+" "+Thread.currentThread().getName());
            //解除等待线程的阻塞， 以便这些线程能
            //够在当前线程退出同步方法后， 通过竞争实现对对象的访问
            mCondition.signalAll();
        }finally {
            System.out.println(Thread.currentThread().getName()+" exit");
            mLock.unlock();//在这里释放锁是必须的,防止运行中出现异常没有放弃锁,导致死锁.
        }
    }
	
    /**
    * 应该尽量使用synchronized 配合wait 和 notifyAll来实现同步,在一定需要ReentrantLock的时候才使用
    */
      public synchronized void transferV2(int from, int to, double money) throws InterruptedException {
        System.out.println(Thread.currentThread().getName() + " enter");
        while (accounts[from] < money) {
            System.out.println("accounts[from] < money await " + Thread.currentThread().getName());
            //条件不达到,阻塞当前线程,并放弃锁
            wait();
        }
        accounts[from] -= money;
        accounts[to] += money;
        System.out.println("success form = " + accounts[from] + " " + Thread.currentThread().getName());
        System.out.println("success to = " + accounts[to] + " " + Thread.currentThread().getName());
        //通知其他等待线程
        notifyAll();
        System.out.println(Thread.currentThread().getName() + " exit");
    }
    
     public void transferV3(int from, int to, double money) throws InterruptedException {
        synchronized (oLock) {
            System.out.println(Thread.currentThread().getName() + " enter");
            while (accounts[from] < money) {
                System.out.println("accounts[from] < money await " + Thread.currentThread().getName());
                //条件不达到,阻塞当前线程,并放弃锁
                oLock.wait();
            }
            accounts[from] -= money;
            accounts[to] += money;
            System.out.println("success form = " + accounts[from] + " " + Thread.currentThread().getName());
            System.out.println("success to = " + accounts[to] + " " + Thread.currentThread().getName());
            //唤醒使用这个锁wait的其他线程
            oLock.notifyAll();
            System.out.println(Thread.currentThread().getName() + " exit");
        }
    }
    
    public static void main(String... args) {
        Alipay alipay = new Alipay(10, 500);
        Thread t1 = new Thread(() -> {
            try {
                alipay.transfer(0,1,600);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }, "t1");
        Thread t2 = new Thread(() -> {
            try {
                alipay.transfer(3,0,200);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }, "t2");

        t1.start();
        //延迟启动t2,凸显等待效果.
        try {
            Thread.sleep(1000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        t2.start();
    }
}

```

运行结果:

```
t1 enter
accounts[from] < money await t1 //条件满足t1阻塞并且放弃了锁
t2 enter //t2获得了锁
success form = 300.0 t2
success to = 700.0 t2  //t2通过条件取消了这个条件的阻塞线程的阻塞
t2 exit
success form = 100.0 t1 //t1取得锁判断条件成立,继续执行
success to = 1100.0 t1
t1 exit
```



## Useful Code

- 扩张任意类型数组
  ```java
   /**
  * @param obj 要扩张的数组
  * @param newLength 新数组的长度
  * @return 已扩张的数组, 大小为obj.lenght()和newLength的最小者
  */
   @SuppressWarnings("SuspiciousSystemArraycopy")
   public static Object copyArray(Object obj, int newLength) {
     Class<?> objClass = obj.getClass();
     if (!objClass.isArray()) {
         return null;
     }
     Class<?> componentType = objClass.getComponentType();
     int length = Array.getLength(obj);
     Object instance = Array.newInstance(componentType, newLength);
     System.arraycopy(obj, 0, instance, 0, Math.min(length, newLength));
     return instance;
   }
  ```

## 位运算等

- 判断是不是偶数

  ```java
  int a = 10;
  if(a & 1 == 0){
      //是偶数
  }
  ```

- 算数运算

  ```
  int a = 10;
  int b = a<<1;//等于*2
  int c = b>>1;//等于/2
  ```

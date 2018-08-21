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

  ​

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

  
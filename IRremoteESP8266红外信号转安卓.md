# IRremoteESP8266红外信号转安卓

最近换了Redmi Note12T,又带红外了,还是比较方便的,但是一些冷门的遥控在MIUI的遥控器里面是找不到的,比如我的DAC(SMSL SU-9),之前我是通过手机发送指令通过阿里云到esp8266来模拟控制实现手机遥控的,现在手机自带了红外也可以添加一个直接控制的途径.

## IRremoteESP8266的实现



```c++
  if (irrecv.decode(&results))
  {
    // print() & println() can't handle printing long longs. (uint64_t)
    Serial.printf("irrecv %d -> value = %s addr = %d command = %d decode_type = ", irRecCount++, uint64ToString(results.value, HEX), results.address, results.command);
    Serial.println(results.decode_type);
  }

-------------读取遥控器红外输入的结果为--------------
       value = 486C807F addr = 13842 command = 1 
       decode_type = 3
---------------------------
```

esp8266模拟直接发送库读取到的value就可以了`irsend.sendNEC(0x486C807FUL);`

## 安卓的发送

参考了[红外遥控及Android手机红外遥控器开发_android红外遥控器开发_Huangrong_000的博客-CSDN博客](https://blog.csdn.net/u010127332/article/details/98968350),文章中提到的用户码,数据码概念在IRremoteESP8266库中都没有具体体现.使用方式和IRremoteESP8266区别较大.

```java
ConsumerIrManagerApi.transmit(38000,NecPattern.buildPattern(0X08,0XE6, 0X41);
```

到处都没有找到如何进行转化的方法,问chatGPT一堆,它也一直在瞎说.经过一番尝试终于成功了.

### `buildPattern`方法的`用户编码`就是IRremoteESP8266的address

比如上面的地址是13842,就是0X3612,反转后为0X1236,即为用户编码.

### `buildPattern`方法的`键数据码`就是IRremoteESP8266的command

所以`irsend.sendNEC(0x486C807FUL);`转为安卓即为:

```kotlin
ConsumerIrManagerApi.transmit(38000, NecPattern.buildPattern(0X12,0X36, 0X01))
```




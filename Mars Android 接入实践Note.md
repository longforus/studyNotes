# Mars Android 接入实践 Note

## 起源

最近的一个项目中,需要接收服务器的消息推送.为了保证消息的及时有效性,自建长连接应该是比较保险的.百度后看中了

[mars](https://github.com/Tencent/mars)这个库,大厂出品,微信验证,demo齐全,star很多.貌似是没问题的了.但是在后续的过程中,也遇到了一些问题.水水博客,记录一下.

## 接入

简单的demo接入尝试的话,按照官方说明接入,差不多就能跑起来了.我是直接clone整个项目,让后导入mars-wrapper这个module的.module比较完善,实现了独立进程的service,通过AIDL实现进程间通信.demo中的服务端,应该也都能跑起来,不过gradle不要使用太高的版本,貌似超过4.0,jetty这个插件就被去掉了,开始我的gradle是6.1.1的跑不起来,调下去就好了.

## 需求

项目的需求是在客户用微信或者我们的APP,扫码后发送一个消息给另外一个设备B,B做出相应的反应.就需要保证B和服务器的连接稳定而且快速.demo跑起来以后遇到的问题是,如何缓存当前连接在需要的时候服务器能够拿到这个连接,向目标设备发出消息.在mars的服务端demo中并没有对连接进行标识,只是在`io.netty.channel.ChannelInboundHandlerAdapter#channelActive(ChannelHandlerContext ctx)`方法中把这个ctx缓存了起来,一旦收到聊天室中的用户发来消息就遍历缓存,向所有缓存了的ctx转发消息.如果我们也按照这样的做法,就需要在接受消息的B设备端,通过消息内容来判断这个消息是不是发给当前设备的,是则接受,否则丢弃.比较浪费资源.还是定向发送的好.而且在`io.netty.channel.ChannelInboundHandlerAdapter#channelInactive(ChannelHandlerContext ctx)`这个方法被调用后,这个ctx貌似就不能再用了.

## 目前的解决方法

### 缓存Channel而不是ChannelHandlerContext

我在[<Netty入门教程——认识Netty>](https://www.jianshu.com/p/b9f3f6a16911)中看到:

- Channel，表示一个连接，可以理解为每一个请求，就是一个Channel。

- **ChannelHandler**，核心处理业务就在这里，用于处理业务请求。

- ChannelHandlerContext，用于传输业务数据。

- ChannelPipeline，用于保存处理过程需要用到的ChannelHandler和ChannelHandlerContext。

后猜想Channel是更高级的抽象,生命周期应该比ChannelHandlerContext的生命周期更长才对,而且也确实可以通过ChannelHandlerContext获得Channel,通过Channel获取ChannelHandlerContext用于发送数据:

```java
 Channel channe = ctx.channel();
 ChannelHandlerContext context = channel.pipeline().context(this);
```

在`io.netty.channel.ChannelInboundHandlerAdapter#channelInactive(ChannelHandlerContext ctx)`方法调用后,通过客户端的key获取到缓存的Channel对象再获取到的ChannelHandlerContext仍旧可以向目标发送数据.结果和mars服务端demo不同的就是缓存<Key,Channel>而不仅仅是ChannelHandlerContext.

### 自定义心跳包的body传值

上面的操作结果是,在客户端断线后,即使客户端重新连线,服务端也不能再用之前的Channel再给客户端发消息了,必须要在合适的时机,获取到客户端的key,缓存新的Channel,现在找到比较合适的时候就是收到心跳包的时候,但问题是收到心跳包并不能知道是哪一个客户端发过来的.解决方法就是在心跳包中带上客户端的key.要实现这个功能,就需要自定义心跳包的body,需要自己添加后,重新编译mars.

#### 自定义心跳包body

按照官方指引在`mars\mars\libraries\mars_android_sdk\jni\longlink_packer.cc`文件夹中找到了`longlink_noop_req_body`方法,在其中添加自己需要的字段:

```c++
void (*longlink_noop_req_body)(AutoBuffer& _body, AutoBuffer& _extend)
= [](AutoBuffer& _body, AutoBuffer& _extend) {
     std::string _bodyStr =   NetSource::GetNoopingBody();
     const char *cstr = _bodyStr.c_str();
      _body.Write(cstr);
};
```

字段是从Java端传过来的,JNI部分不再熬诉.如有需要参阅其他方法的实现或相关教程.

#### 构建

构建流程参考官方指引,但是我在构建的过程中遇到了几点问题:

1. 这是一个比较大的坑,mars的master分支下的C++端的代码和Java端的代码是不匹配的,好多方法的签名都不相同,可能是有些合并,代码没有合全,而且分支众多,不知道用哪一个.发现后没有办法,只能从tag 1.3,拉出分支来,重新实现相关逻辑,最终才搞成功.

2. 官方指引中有一段:

    ```shell
    执行命令后，会让选择:
    
    Enter menu:
    1. Clean && build mars.
    2. Build incrementally mars.
    3. Clean && build xlog.
    4. Exit
    
    如需要自定义日志加密算法或者长短连协议加解包，请选择static libs选项，即 2 和 3。选项 1 和 2 输出结果全部在 mars_android_sdk 目录中，3 和 4 输出结果全部在 mars_xlog_sdk 目录中。
    ```

    运行脚本后出来的选项和`请选择static libs选项，即 2 和 3。····`这一段一对比确实让人很摸不着头脑,应该是构建脚本已经更新了,但是说明还没有更新.在这里只需要选1,直接构建即可,说明中的选几无需理会.

3. 开始在win10中构建,可能是我的gcc没有装好,报错无法成功,后来在子系统的ubuntu18.04中才构建成功,如果你在win10下不行的话,也可以试试.

## 结束

现在暂时能达到要求了,但是在正式使用后,肯定还会遇到一些难题,希望自己不要轻易放弃,难不怕,搞一搞或许还是有可能的.


# Fridia Java.classFactory.loader:Cannot assign to 'loader' because it is a read-only property.

当在使用fridia hook非默认的classloader加载的class(也就是插件化,动态化使用`dalvik.system.PathClassLoader`进行加载的)的时候,我们按照前辈的经验写下:

```typescript
Java.enumerateClassLoaders({
        "onMatch": function(loader) {
            if (loader.toString().indexOf("main.so") >= 0 ) {
                Java.classFactory.loader = loader;
                console.log("loader = ",loader.toString());
            }
        },
        "onComplete": function() {
            console.log("success");
        }
    });
```

的时候,我的Pycharm(我用Pycharm来写的typeScript)提示我:`Attempt to assign to const or readonly variable 
TS2540: Cannot assign to 'loader' because it is a read-only property.`点进loader去看

```typescript

        /**
         * Class loader currently being used. For the default class factory this
         * is updated by the first call to `Java.perform()`.
         */
        readonly loader: Wrapper | null;

```

果然是readonly的,是fridia的api升级了吗?还是因为我用的ts的原因?没有仔细研究,不过也正好发现了上面的:

```typescript

        /**
         * Gets the class factory instance for a given class loader, or the
         * default factory when passing `null`.
         *
         * The default class factory used behind the scenes only interacts
         * with the application's main class loader. Other class loaders
         * can be discovered through APIs such as `Java.enumerateMethods()` and
         * `Java.enumerateClassLoaders()`, and subsequently interacted with
         * through this API.
         */
        static get(classLoader: Wrapper | null): ClassFactory;
```



经过一番尝试,发现了正确的使用姿势:

```typescript
Java.enumerateClassLoaders({
        "onMatch": function(loader) {
            if (loader.toString().indexOf("main.so") >= 0 ) {
                console.log("loader = ",loader.toString());
                //Java.classFactory.loader = loader;
                var secondFactory =  Java.ClassFactory.get(loader)
                var  clazz =  secondFactory.use('com.xxx.TargetClass');
                //这里就可以对clazz正常使用了
                clazz.xxx.implementation = function(){
                    ......
                }
            }
        },
        "onComplete": function() {
            console.log("onComplete");
        }
    });
```

随便水水.::laughing:


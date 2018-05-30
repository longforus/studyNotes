# Android studio项目编译期字节码插入实践Note

标签（空格分隔）： Android

---

## 出发点
希望通过编译器的字节码插入,实现组件化项目,模块的生命周期初始化工作,在编码期完全不调用子模块的任何代码,包括子模块的生命周期初始化,达到完全解耦的目的.这个做法来自:[Android彻底组件化方案实践][1],在作者的文中对这部分未做详细的说明,在文末贴出的gradle插件也还未做测试.但是在主要参考了:[ Android热补丁动态修复技术（三）—— 使用Javassist注入字节码，完成热补丁框架雏形（可使用）][2]一文后根据作者代码进行实践,终于达到目的,对gradle也有了进基本的了解,作笔记如下,代码主要复制于第二篇文章中.



##实现
通过添加一个gradle插件添加一个构建过程中的TransformTask : transformClassesWithPreDexForDebug在这个task中获取到已经生成的class文件,使用javassist进行字节码直接插入.

##步骤
**几乎全部引用自AItsuki的[文章][3]**
###自定义一个plugin:
   1. 新建一个module，选择library module，module名字必须叫BuildSrc 
   2. 删除module下的所有文件，除了build.gradle，替换build.gradle中的内容 
    ```
    apply plugin: 'groovy'
    
    repositories {
      jcenter()
    }
    
    dependencies {
      compile gradleApi()
      compile 'com.android.tools.build:gradle:2.3.3'
      compile 'org.javassist:javassist:3.20.0-GA'
    }
   ```
   3. 然后新建以下目录 src-main-groovy，同步
   4.  这时候就可以像普通module一样新建package和类了，不过这里的类是以groovy结尾，新建类的时候选择file，并且以.groovy作为后缀。
    ```
    package com.longforus
    
    import com.android.build.gradle.AppExtension
    import org.gradle.api.Plugin
    import org.gradle.api.Project
   
    public class TestPlugin implements Plugin<Project> {
      @Override
      public void apply(Project project) {
        project.logger.error "================自定义插件成功！=========="
        def android = project.extensions.findByType(AppExtension.class)
        android.registerTransform(new PreDexTransform(project))//调用自定义的transform进行
      }
    }
  ```
   5.在app module下的buiil.gradle中添apply 插件 
   ```
   import com.longforus.TestPlugin
apply plugin: 'com.android.application'
apply plugin: TestPlugin//应用插件
......
  ```
*说明：如果plugin所在的module名不叫BuildSrc，这里是无法apply包名的，会提示找不到。所以之前也说明取名一定要叫buildsrc*
运行一下项目就可以看到”================自定义插件成功！==========”这句话了 
和gradle有关的输出都会显示在gradle console这个窗口中。 
### 自定义Transfrom
新建一个groovy继承Transfrom，注意这个Transfrom是要com.android.build.api.transform.Transform这个包的
代码如下:
```
package com.longforus

import com.android.build.api.transform.*
import com.android.build.gradle.internal.pipeline.TransformManager
import com.android.utils.FileUtils
import org.gradle.api.Project
import org.apache.commons.codec.digest.DigestUtils

public class PreDexTransform extends Transform {
  //        http://blog.csdn.net/u010386612/article/details/51131642

  Project project
  // 添加构造，为了方便从plugin中拿到project对象，待会有用
  public PreDexTransform(Project project) {
    this.project = project
  }

  // Transfrom在Task列表中的名字
  // TransfromClassesWithPreDexForXXXX
  @Override
  String getName() {
    return "preDex"
  }

  // 指定input的类型
  @Override
  Set<QualifiedContent.ContentType> getInputTypes() {
    return TransformManager.CONTENT_CLASS
  }

  // 指定Transfrom的作用范围
  @Override
  Set<QualifiedContent.Scope> getScopes() {
    return TransformManager.SCOPE_FULL_PROJECT
  }

  @Override
  boolean isIncremental() {
    return false
  }

  @Override
  void transform(Context context, Collection<TransformInput> inputs,
      Collection<TransformInput> referencedInputs,
      TransformOutputProvider outputProvider, boolean isIncremental) throws IOException, TransformException, InterruptedException {

    // inputs就是输入文件的集合
    // outputProvider可以获取outputs的路径

    // Transfrom的inputs有两种类型，一种是目录，一种是jar包，要分开遍历

    inputs.each { TransformInput input ->

      input.directoryInputs.each { DirectoryInput directoryInput ->

        //TODO 这里可以对input的文件做处理，比如代码注入！
        Inject.injectDir(directoryInput.file.absolutePath)//调用方法进行注入
        // 获取output目录
        def dest = outputProvider.getContentLocation(directoryInput.name,
            directoryInput.contentTypes, directoryInput.scopes, Format.DIRECTORY)

        // 将input的目录复制到output指定目录
        FileUtils.copyDirectory(directoryInput.file, dest)
      }

      input.jarInputs.each { JarInput jarInput ->
        //TODO 这里可以对input的文件做处理，比如代码注入！

        String jarPath = jarInput.file.absolutePath;
        String projectName = project.rootProject.name;
        if(jarPath.endsWith("classes.jar")
            && jarPath.contains("exploded-aar\\"+projectName)//这里的路径在我的项目中并不存在, gradle版本不同可能已经不一样了
            // hotpatch module是用来加载dex，无需注入代码
            && !jarPath.contains("exploded-aar\\"+projectName+"\\hotpatch")) {
          Inject.injectJar(jarPath)//调用对jar进行注入的方法
        }


        // 重命名输出文件（同目录copyFile会冲突）
        def jarName = jarInput.name
        def md5Name = DigestUtils.md5Hex(jarInput.file.getAbsolutePath())
        if (jarName.endsWith(".jar")) {
          jarName = jarName.substring(0, jarName.length() - 4)
        }
        def dest = outputProvider.getContentLocation(jarName + md5Name, jarInput.contentTypes, jarInput.scopes, Format.JAR)
//        project.logger.error("dest = "+dest.absolutePath+"="+dest.exists())
//        project.logger.error("jarInput.file = "+jarInput.file.absolutePath+"="+jarInput.file.exists())
        dest.mkdirs()//需要先创建文件才可以哦
        dest.createNewFile()
        FileUtils.copyFile(jarInput.file, dest)
      }
    }
  }
}
```
Clean项目运行就可以,在获取inputs复制到outpus目录之前，对class注入代码.
###查看inputs和ouputs
在app module下的build.gradle的android节点中添加以下代码:
```
    applicationVariants.all { variant->//输出  class文件的保存目录
            def dexTask = project.tasks.findByName("transformClassesWithDexForDebug")
            def preDexTask = project.tasks.findByName("transformClassesWithPreDexForDebug")
            if(preDexTask) {
                project.logger.error "======preDexTask======"
                preDexTask.inputs.files.files.each {file ->
                    project.logger.error "inputs =$file.absolutePath"
                }
                preDexTask.outputs.files.files.each {file ->
                    project.logger.error "outputs =$file.absolutePath"
                }
            }
        if(dexTask) {
            project.logger.error "======dexTask======"
            dexTask.inputs.files.files.each {file ->
                project.logger.error "inputs =$file.absolutePath"
            }
            dexTask.outputs.files.files.each {file ->
                project.logger.error "outputs =$file.absolutePath"
            }
        }
    }
```
即可获取inputs和ouputs的目录我实际获取到的目录与原作者所说的不一样,可能是版本问题,未做深究.

###使用javassist注入代码
* app module编译后class文件保存在debug目录，直接遍历这个目录使用javassist注入代码就行了
* app module依赖的module，编译后会被打包成jar，放在exploded-aar这个目录，需要将jar包解压–遍历注入代码–重新打包成jar

在插件中需要添加2个类,格式和上面的Transform一样:
操作javassist注入代码的inject类:
```
import com.longforus.JarZipUtil
import javassist.ClassPool
import javassist.CtClass
import javassist.CtConstructor
import org.apache.commons.io.FileUtils
/**
 * Created by AItsuki on 2016/4/7.
 * 注入代码分为两种情况，一种是目录，需要遍历里面的class进行注入
 * 另外一种是jar包，需要先解压jar包，注入代码之后重新打包成jar
 */
public class Inject {

    private static ClassPool pool= ClassPool.getDefault()

    /**
     * 添加classPath到ClassPool
     * @param libPath
     */
    public static void appendClassPath(String libPath) {
        pool.appendClassPath(libPath)
    }

    /**
     * 遍历该目录下的所有class，对所有class进行代码注入。
     * 其中以下class是不需要注入代码的：
     * --- 1. R文件相关
     * --- 2. 配置文件相关（BuildConfig）
     * --- 3. Application
     * @param path 目录的路径
     */
    public static void injectDir(String path) {
        pool.appendClassPath(path)
        File dir = new File(path)
        if (dir.isDirectory()) {
            dir.eachFileRecurse { File file ->

                String filePath = file.absolutePath
                if (filePath.endsWith(".class")
                    && !filePath.contains('R$')
                    && !filePath.contains('R.class')
                    && !filePath.contains("BuildConfig.class")
                    // 这里是application的名字，可以通过解析清单文件获得，先写死了
                    && !filePath.contains("App.class")) {
                    // 这里是应用包名，也能从清单文件中获取，先写死
                    int index = filePath.indexOf("com\\fec\\modifymethoddemo")
                    if (index != -1) {
                        int end = filePath.length() - 6 // .class = 6
                        String className = filePath.substring(index, end).replace('\\', '.').replace('/', '.')
                        injectClass(className, path)
                    }
                }
            }
        }
    }

    /**
     * 这里需要将jar包先解压，注入代码后再重新生成jar包
     * @path jar包的绝对路径
     */
    public static void injectJar(String path) {
        if (path.endsWith(".jar")) {
            File jarFile = new File(path)

            // jar包解压后的保存路径
            String jarZipDir = jarFile.getParent() + "/" + jarFile.getName().replace('.jar', '')

            // 解压jar包, 返回jar包中所有class的完整类名的集合（带.class后缀）
            List classNameList = JarZipUtil.unzipJar(path, jarZipDir)

            // 删除原来的jar包
            jarFile.delete()

            // 注入代码
            pool.appendClassPath(jarZipDir)
            for (String className : classNameList) {
                if (className.endsWith(".class")
                    && !className.contains('R$')
                    && !className.contains('R.class')
                    && !className.contains("BuildConfig.class")) {
                    className = className.substring(0, className.length() - 6)
                    injectClass(className, jarZipDir)
                }
            }

            // 从新打包jar
            JarZipUtil.zipJar(jarZipDir, path)

            // 删除目录
            FileUtils.deleteDirectory(new File(jarZipDir))
        }
    }

    private static void injectClass(String className, String path) {
        println(path)
        CtClass c = pool.getCtClass(className)
        if (c.isFrozen()) {
            c.defrost()
        }
        println(className)
        if (c.name.contains("MainActivity")) {
            for (int i = 0; i < c.declaredMethods.size(); i++) {
                def method = c.declaredMethods[i]
                println(method.name)
                if (method.name.contains("init")){
                    method.insertAfter("com.fec.modifymethoddemo.Printer.print(\"测试插入\",mContext);")
                    println("插入成功")//测试成功的插入代码
                }

            }
        }
        /*CtConstructor[] cts = c.getDeclaredConstructors()

        if (cts == null || cts.length == 0) {
            insertNewConstructor(c)
        } else {
            cts[0].insertBeforeBody("System.out.println(123123);")
        }*/
        c.writeFile(path)
        c.detach()
    }

    private static void insertNewConstructor(CtClass c) {
        CtConstructor constructor = new CtConstructor(new CtClass[0], c)
        constructor.insertBeforeBody("System.out.println(321321);")
        c.addConstructor(constructor)
    }

}
```

解压缩jar包的类:
```
package com.longforus

import java.util.jar.JarEntry
import java.util.jar.JarFile
import java.util.jar.JarOutputStream
import java.util.zip.ZipEntry
/**
 * Created by hp on 2016/4/13.
 */
public class JarZipUtil {

    /**
     * 将该jar包解压到指定目录
     * @param jarPath jar包的绝对路径
     * @param destDirPath jar包解压后的保存路径
     * @return 返回该jar包中包含的所有class的完整类名类名集合，其中一条数据如：com.aitski.hotpatch.Xxxx.class
     */
    public static List unzipJar(String jarPath, String destDirPath) {

        List list = new ArrayList()
        if (jarPath.endsWith('.jar')) {

            JarFile jarFile = new JarFile(jarPath)
            Enumeration<JarEntry> jarEntrys = jarFile.entries()
            while (jarEntrys.hasMoreElements()) {
                JarEntry jarEntry = jarEntrys.nextElement()
                if (jarEntry.directory) {
                    continue
                }
                String entryName = jarEntry.getName()
                if (entryName.endsWith('.class')) {
                    String className = entryName.replace('\\', '.').replace('/', '.')
                    list.add(className)
                }
                String outFileName = destDirPath + "/" + entryName
                File outFile = new File(outFileName)
                outFile.getParentFile().mkdirs()
                InputStream inputStream = jarFile.getInputStream(jarEntry)
                FileOutputStream fileOutputStream = new FileOutputStream(outFile)
                fileOutputStream << inputStream
                fileOutputStream.close()
                inputStream.close()
            }
            jarFile.close()
        }
        return list
    }

    /**
     * 重新打包jar
     * @param packagePath 将这个目录下的所有文件打包成jar
     * @param destPath 打包好的jar包的绝对路径
     */
    public static void zipJar(String packagePath, String destPath) {

        File file = new File(packagePath)
        JarOutputStream outputStream = new JarOutputStream(new FileOutputStream(destPath))
        file.eachFileRecurse { File f ->
            String entryName = f.getAbsolutePath().substring(packagePath.length() + 1)
            outputStream.putNextEntry(new ZipEntry(entryName))
            if(!f.directory) {
                InputStream inputStream = new FileInputStream(f)
                outputStream << inputStream
                inputStream.close()
            }
        }
        outputStream.close()
    }
}
```
clean 再运行就能注入成功了.
### 插件的debug
在上面的项目中我想要在插件的代码中打断点,方便调试,但是以前对插件都没有过多的了解,很单纯的和项目代码一样点上bug,就点击调试运行,结果的无法进入断点的.搜索资料加实践后成功进入断点,参考了[Intellij / Android Studio 调试 Gradle Plugin][4]这篇文章,在原文的基础上多次尝试,写了一个bat文件在需要断点调试时运行:
```
@rem 只有在clean之后才会进入断点
call gradlew clean
call gradlew assembleDebug -Dorg.gradle.daemon=false -Dorg.gradle.debug=true
pause>nul
```
放在项目根目录下,打好断点->运行bat->点击远程任务的调试启动 即可进入断点.


  [1]: http://www.jianshu.com/p/1b1d77f58e84
  [2]: http://blog.csdn.net/u010386612/article/details/51131642
  [3]: http://blog.csdn.net/u010386612/article/details/51131642
  [4]: http://blog.csdn.net/ceabie/article/details/55271161
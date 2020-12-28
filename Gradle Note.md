# Gradle Note

---
[TOC]

## 运行参数

- -q 不输出太多任务信息,只输入基本信息
- -x 制定跳过任务

        //跳过后面的tT0,不执行
         gradle  gT -x tT0

- -b 指定任务执行的文件,默认为:build.gradle

        gradle -b test.gradle

- -D jvm系统参数
- -P 传入脚本中使用的脚本参数

        输入: gradle -P appId=long-for-us cloudBAI
         gradle -PappId=123123 -PwarFile="todo.war" cBDW //多个用-P开头 空格隔开
        直接使用外面输入时使用的name: inputs.property('appId', appId)

## Task

### 依赖
```groovy
version = '1.0'
task first{
    println 'first-configration' //doFirst 和doLast action 块之外的代码在task的配置阶段执行 ,每一次的任何task的执行都会触发配置代码的执行 
    doFirst{//块内的代码在task的执行阶段执行
        println 'first-first'
    }
    doLast{//块内的代码在task的执行阶段执行
        println 'first-last'
    }
}
task second(){
  doFirst{
        println 'second'
  }
}
task printVersion(dependsOn:[second,first]){
    doLast{
        logger.quiet "version =  $version"
    }
}
task third(){
    doFirst{
        println 'third'
    }
}

// third.dependsOn('printVersion')//被依赖的任务使用 '' 包起来,third依赖了printV任务,所以在third任务执行前会先执行printV任务

third.finalizedBy printVersion//printV被设为third的终结task ,third执行完成后printV 会被执行

//添加内部任务的依赖 写在android{} 之外,autoBuildPrepare任务的之后 ,这样内部的assembleRelease任务就会依赖与 //autoBuildPrepare,在它执行之后才会执行
rootProject.task('assembleRelease').dependsOn autoBuildPrepare
```
### 输入输出
定义task的输入和输出可以让gradle知道这个任务是否该执行,如果输入和输出没有改变的话,这个任务会被跳过,提高运行效率,任务被跳过时会显示:**up-to-date**,输入和输出可以是一个或多个文件,properties等
```groovy
task makeReleaseVersion(group: 'versioning', description: 'Makes project a release version.') {
    inputs.property('release', version.release) //任务输入
    outputs.file versionFile//任务输入

    doLast {
        version.release = true
        ant.propertyfile(file: versionFile) {
            entry(key: 'release', type: 'string', operation: '=', value: 'true')
        }
    }
}
```
### 增强task
```groovy
task makeReleaseVersion(type: ReleaseVersionTask) {//指明这个task的父类型
    release = version.prodReady//为输入输出赋值
    destFile = new File('project-version.properties')
}

class ReleaseVersionTask extends DefaultTask {//继承自默认的task
    @Input 
    @Optional //注解输入允许为null
    Boolean release//使用注解标注输入和输出
    @OutputFile File destFile //可以存在多个同类型的输入,都需要用Annotation标注

    ReleaseVersionTask() {
        group = 'versioning'//构造方法中给默认属性赋值
        description = 'Makes project a release version.'
    }

    //注解具体执行的动作
    @TaskAction
    void start() {//方法名可自定义(父类execute()除外)
        project.version.prodReady = true
        ant.propertyfile(file: destFile) {
            entry(key: 'release', type: 'string', operation: '=', value: 'true')
        }
    }
}
```
执行makeReleaseVersion这个task就会执行ReleaseVersionTask的action

### 获取task的输入和输出
```groovy
task incrementVersion(group:'versioning',description:'longforus test'){
    inputs.property('version',version)
    outputs.file(versionFile)  
    doLast{
       def v =  inputs.getProperties().get('version')//获取输入的属性
        ++v.minor
        ++v.major
        ant.propertyfile(file:outputs.getFiles().getAt(0)){//获取输出的文件
            entry(key:'minor',type:'int',operation:'=',value:v.minor)
            entry(key:'major',type:'int',operation:'=',value:v.major)
        }
    }
}
```

### task的隐式依赖
```groovy
task createDistribution(type: Zip, dependsOn: makeReleaseVersion) {//依赖到 makeReleaseVersion task
    from war.outputs.files//依赖到war task   所以这个任务会在war和makeReleaseVersion都执行完之后才执行

    from(sourceSets*.allSource) {//使用父类型zip的方法 进行zip打包操作
        into 'src'
    }

    from(rootDir) {
        include versionFile.name
    }
}

task backupReleaseDistribution(type: Copy) {
    from createDistribution.outputs.files//使用到createDistribution task的输出 隐式依赖到这个任务,被依赖的这个任务必须比他先执行
    into "$buildDir/backup"
}
```
### rule  规则声明
```groovy
tasks.addRule("Pattern: increment<Classifier>Version – Increments the project version classifier.这里都是描述信息") { String taskName ->
    if (taskName.startsWith('increment') && taskName.endsWith('Version')) {//如果输入的taskName符合这个规则
        task(taskName) << {//动态插入一个doLast方法
            String classifier = (taskName - 'increment' - 'Version').toLowerCase()//输入的taskName减去前面和后面剩下中间部分
            String currentVersion = version.toString()
             //根据获取的classifier执行后续操作   
            switch (classifier) {
                case 'major': ++version.major
                    break
                case 'minor': ++version.minor
                    break
                default: throw new GradleException("Invalid version type '$classifier. Allowed types: ['Major', 'Minor']")
            }

            String newVersion = version.toString()
            logger.info "Incrementing $classifier project version: $currentVersion -> $newVersion"

            ant.propertyfile(file: versionFile) {
                entry(key: classifier, type: 'int', operation: '+', value: 1)
            }
        }
    }
}
```
相当于同时声明了incrementMajorVersion incrementMinorVersion 这2个任务,根据任务名执行不同的操作.可以直接执行这2个任务,as中的不同flavor构建的一系列任务可能就是这么做的.

### 生命周期hook

```groovy
//对生命周期进行hook 插入操作
gradle.taskGraph.whenReady { TaskExecutionGraph taskGraph ->
//这里的代码在taskGraph准备好的时候被调用
    if (taskGraph.hasTask(release)) {//执行release的时候才会继续 防止非预期的改动 可能执行任意task都会触发这个hook
        if (!version.release) {
            version.release = true
            ant.propertyfile(file: versionFile) {
                entry(key: 'release', type: 'string', operation: '=', value: 'true')
            }
        }
    }
}

task createDistribution(type: Zip) {//相比前面的代码这里没有 依赖保存release属性到properties文件的任务 这个操作放到了上面的hook操作中
    from war.outputs.files

    from(sourceSets*.allSource) {
        into 'src'
    }

    from(rootDir) {
        include versionFile.name
    }
}
```

### Listener
```groovy
class ReleaseVersionListener implements TaskExecutionGraphListener {//实现Listener接口
    final static String listenTaskPath = ':release'
    @Override
    void graphPopulated(TaskExecutionGraph graph) {//实现抽象方法
        if (graph.hasTask(listenTaskPath)) {//使用taskPath从Graph中找任务
            List<Task> list = graph.getAllTasks()
            Task listenTask = list.find { it.path == listenTaskPath }//过滤出path相同的任务
            Project project = listenTask.project//获取到project进行后续操作
            if (!project.version.release) {
                project.version.release = true
                project.ant.propertyfile(file: project.versionFile) {
                    entry(key: 'release', type: 'string', operation: '=', value: 'true')
                }
            }
        }
    }
}

gradle.taskGraph.addTaskExecutionGraphListener(new ReleaseVersionListener())//注册监听器
```



## 依赖管理

### 自定义依赖配置
```groovy
configurations {
cargo {//自定义配置 默认就是complier
    description = 'Classpath for Cargo Ant tasks.'
    visible = false
 }
}
```
### 排除某个

```groovy
dependencies {
    cargo('org.codehaus.cargo:cargo-ant:1.3.1') {//排除这个依赖下的子依赖
        exclude group: 'xml-apis', module: 'xml-apis'
    }
    cargo 'xml-apis:xml-apis:2.0.2'//单独另外指定版本
}
```

### 排除所有
```groovy
dependencies {
cargo('org.codehaus.cargo:cargo-ant:1.3.1') {//注意和下面的不同,依赖信息要加上括号
    transitive = false //排除这个依赖的所有传递性依赖
}
// Selectively declare required dependencies
cargo 'org.codehaus.cargo:cargo-core-uberjar:1.3.1'
}
```

### 设置缓存策略
```groovy
configurations.cargo.resolutionStrategy {
force "$cargoGroup:cargo-ant:1.3.0"//当依赖冲突时强制指定依赖版本
cacheDynamicVersionsFor 0,'seconds'//动态依赖版本0秒超时,总是获取最新的版本
cacheChangingModulesFor 0,'seconds'//缓存0秒超时,不缓存
}
```

## 多项目构建
### BuildSrc
**如果把类放在buildSrc目录下就可以很轻松的在项目之间共享他们**,所以编写自定义插件放在buildSrc目录下就可以不用在:/resources/META-INF/gradle-plugins/com.fec.yunmall.buildplugin.properties文件下指定:

    implementation-class=com.fec.yunmall.buildplugin.AutoBuild
插件名称了
### 顶级项目中
```groovy
project(':model') {//在顶级项目中为指定的子项目添加操作
    group = projectIds.group
    version = projectIds.version
    apply plugin: 'java'
}

```
### 同名任务
在任意项目中定义同名的task,后在顶级项目目录下执行该task所有的同名task都会被执行.根项目的task最先被执行,然后子项目根据项目名称字母排序的顺序执行,和settings.gradle文件中的顺序没有关系.

### 跨项目的任务依赖
```groovy
//跨项目的任务依赖 保证:repository:hello 任务比这个hello任务先执行
    task hello(dependsOn: ':repository:hello') << {
        println 'Hello from model project'
    }
```

### 公共行为定义
```groovy
allprojects {//所有项目包括顶级项目
    group = 'com.manning.gia'
    version = '0.1'
}

subprojects {//子项目
    apply plugin: 'java'
}
```

### 自定义子项目构建文件名
settings.gradle
```groovy
include 'todo-model', 'todo-repository', 'todo-web'

rootProject.name = 'todo' //指定根项目名称  

rootProject.children.each {//指定每个子项目的项目文件名 子项目的文件夹有todo-的前缀
    it.buildFileName = it.name + '.gradle' - 'todo-'//删除后为 model.gradle  子项目的构建文件叫这个名字就能被找到了  
}
```
## 插件
### 脚本插件
- 定义:
```groovy
buildscript {//可以定义单独的构建脚本
    repositories {
        mavenCentral()
    }
    dependencies {
        classpath 'com.cloudbees:cloudbees-api-client:1.4.0'
    }
}
ext {
    apiUrl = 'https://api.cloudbees.com/api'
    apiFormat = 'xml'
    apiVersion = '1.0'
}
logger.quiet "in plugin project=$project"//可以在脚本插件中直接获取到调用它的project  属性就更不用说了
logger.quiet "in plugin rootProject=$rootProject"

if (project.hasProperty('cloudbeesApiKey')) {//从project中可以直接获取到该project.gradle文件同目录下gradle.properties文件中定义的属性
    ext.apiKey = project.property('cloudbeesApiKey')
}
//可以显式导入classpath中定义的依赖的类后 进行使用
import com.cloudbees.api.ApplicationInfo
import com.cloudbees.api.BeesClient 
BeesClient client = new BeesClient(apiUrl, apiKey, secret, 'xml', '1.0')

```
- 使用:

    ```groovy
    apply from: 'cloudbees.gradle'//最后的文件名即为脚本插件名
    apply from: "${rootProject.rootDir}/config.gradle"
    ```
### 对象插件
- 定义
  在/buildSrc/src/main/groovy/包名/目录下定义插件实现org.gradle.api.Plugin接口
```groovy
package com.manning.gia.plugins.cloudbees

import org.gradle.api.Plugin
import org.gradle.api.Project

class CloudBeesPlugin implements Plugin<Project> {
    void apply(Project project) {
        project.plugins.apply(WarPlugin)//do some thing
        addTasks(project)
    }
}

​`````````````````````build script
apply plugin:'groovy'
repositories {
    google()
    jcenter()
}
dependencies {
    implementation 'com.android.tools.build:gradle:3.2.1'
//    implementation group: 'org.javassist', name: 'javassist', version: '3.20.0-GA'
    //gradle sdk
//    implementation 'com.android.tools.build:gradle-api:3.1.4'
    implementation gradleApi()
    //groovy sdk
    implementation localGroovy()
}
```
- 使用
1. 如果是定义在/buildSrc/src/main/groovy/包名/目录下的可以直接使用全类名进行导入

          apply plugin: com.manning.gia.plugins.cloudbees.CloudBeesPlugin 

2. 如果在\buildsrc\src\main\resources\META-INF\gradle-plugins\目录下定义了短插件名的,可以使用短插件名.
    定义方法:在该目录下创建 短插件名.properties,比如:com.fec.yunmall.buildplugin.properties
    内容为:

        implementation-class=com.fec.yunmall.buildplugin.AutoBuild//实现插件全类名
    使用时即可使用短插件名:
    ​        

    ```groovy
    apply plugin: 'com.fec.yunmall.buildplugin'
    ```

    如果插件不是定义在buildSrc模块下的话,会提示找不到插件.

3. 使用打包好的(外部)插件的,需要在顶级build.gradle中声明classPath

          classpath 'com.fec.yunmall:buildsrc:+'
### 插件扩展
- 定义
  在插件目录下定义bean:
```groovy
package com.manning.gia.plugins.cloudbees

class CloudBeesPluginExtension {
    String apiUrl
    String apiKey
    String secret
    String appId
}
```
- 使用
1. 在使用插件的地方添加扩展闭包:

      ```groovy
      apply plugin: com.manning.gia.plugins.cloudbees.CloudBeesPlugin
      
      cloudBees {//扩展闭包
          apiUrl = 'https://api.cloudbees.com/api'
          apiKey = project.apiKey
          secret = project.secret
          appId = 'gradle-in-action/todo'
      }
      ```
2. 在插件中注册使用
```groovy
package com.manning.gia.plugins.cloudbees

class CloudBeesPlugin implements Plugin<Project> {
    static final String EXTENSION_NAME = 'cloudBees'//应该需要和build.gradle中定义的扩展闭包同名

    void apply(Project project) {
        project.plugins.apply(WarPlugin)
        project.extensions.create(EXTENSION_NAME, CloudBeesPluginExtension)//注册扩展
        addTasks(project)
    }
    private void addTasks(Project project) {
        project.tasks.withType(CloudBeesTask) {
            def extension = project.extensions.findByName(EXTENSION_NAME)//使用扩展
            conventionMapping.apiUrl = { extension.apiUrl }
            conventionMapping.apiUrl = { project.cloudBees.apiUrl }//也可以这样直接使用
            conventionMapping.apiKey = { extension.apiKey }
            conventionMapping.secret = { extension.secret }
            logger.quiet "2 secret = $extension.secret"//只有在task的执行阶段,这里才会有值
        }
        addAppTasks(project)
    }
}
```
另一个例子:
```groovy
apply plugin: DateAndTimePlugin
dateAndTime {//扩展闭包
    timeFormat = 'HH:mm:ss'
    dateFormat = 'MM/dd/yyyy'
}

class DateAndTimePlugin implements Plugin<Project> {
    void apply(Project project) {

        project.extensions.create("dateAndTime", DateAndTimePluginExtension)//注册扩展

        project.task('showTime') << {
            println "Current time is " + new Date().format(project.dateAndTime.timeFormat)//使用扩展
        }

        project.tasks.create('showDate') << {
            println "Current date is " + new Date().format(project.dateAndTime.dateFormat)
        }
    }
}

class DateAndTimePluginExtension {//定义bean
    String timeFormat = "MM/dd/yyyyHH:mm:ss.SSS"
    String dateFormat = "yyyy-MM-dd"
}

```
## 打包,上传
### 添加源码示例
```groovy
apply plugin: 'maven'
uploadArchives {
    repositories {
        mavenDeployer {
            repository(url: 'http://192.168.2.105:8908/repository/axkc/') {
                authentication(userName: "void", password: "void")
            }
            pom.project {
                version '0.0.4'
                artifactId "core"
                groupId 'com.fec.axkc'
                description "test"
            }
        }
    }
}
task androidSourcesJar(type: Jar) {//定义源码jar Task,Jar任务的增强类型
    classifier = 'sources'//指定jar类型为源码
    from android.sourceSets.main.java.sourceFiles//指定输入源
}
artifacts {
    archives androidSourcesJar//把源码jar任务的输出注册到生成工件列表中
}
```
### publish发布
```groovy
apply plugin: 'distribution'

distributions {
    main {
        baseName = archivesBaseName

        contents {
            from { libsDir }
        }
    }

    docs {
        baseName = "$archivesBaseName-docs"

        contents {
            from(libsDir) {
                include sourcesJar.archiveName//包含源码
                include groovydocJar.archiveName//包含groovy的doc
            }
        }
    }
}

apply plugin: 'maven-publish'
publishing {
    publications {
        plugin(MavenPublication) {
            from components.java//指定发布类型为java的类型 也就是jar
            artifactId 'cloudbees-plugin'

            pom.withXml {//自定义pom文件内容
                def root = asNode()
                root.appendNode('name', 'Gradle CloudBees plugin')
                root.appendNode('description', 'Gradle plugin for managing applications and databases on CloudBees RUN@cloud.')
                root.appendNode('inceptionYear', '2013')

                def license = root.appendNode('licenses').appendNode('license')
                license.appendNode('name', 'The Apache Software License, Version 2.0')
                license.appendNode('url', 'http://www.apache.org/licenses/LICENSE-2.0.txt')
                license.appendNode('distribution', 'repo')

                def developer = root.appendNode('developers').appendNode('developer')
                developer.appendNode('id', 'bmuschko')
                developer.appendNode('name', 'longforus')
                developer.appendNode('email', 'benjamin.muschko@gmail.com')
            }

            artifact sourcesJar//添加源码
            artifact groovydocJar//添加groovy doc
        }
    }

    repositories {
        maven {
            name 'myLocal'
            url "file://$projectDir/repo"
        }
        //上下为不同的发布途径,name被包含到发布的任务中 比如:
/**publishPluginPublicationToMavenLocal - Publishes Maven publication 'plugin' to the local Maven repository.//发布到用户目录.m2/目录下的本地仓库中
publishPluginPublicationToMyLocalRepository - Publishes Maven publication 'plugin' to Maven repository 'myLocal'.
publishPluginPublicationToRemoteArtifactoryRepository - Publishes Maven publication 'plugin' to Maven repository 'remoteArtifactory'.
*/
        maven {
            name 'remoteArtifactory'
            // url project.version.endsWith('-SNAPSHOT') ? artifactorySnapshotRepoUrl : artifactoryReleaseRepoUrl
            url 'http://192.168.2.105:8908/repository/other/'

            credentials {
                username = 'void'
                password = 'void'
            }
        }
    }
```
## other
### properties文件的读写

```groovy
ext.versionFile = file('version.properties')

task loadProperties{
    Properties prop = new Properties()
    versionFile.withInputStream{stream->
        prop.load(stream)
    }
    //这里就可以从prop中读取到属性了
    
    ant.propertyfile(file:versionFile){//写入到versionFile中
        entry(key:'release',type:'string',operation:'=',value:'false')
      }
}
```

### Closure 闭包
```groovy
    void start() {
        withExceptionHandling {//这个闭包就像是lambda 这里的代码被放进闭包中
            BeesClient client = new BeesClient(apiUrl, apiKey, secret, apiFormat, apiVersion)
            executeAction(client)
        }
    }

    private void withExceptionHandling(Closure c) {
        try {
            c()//执行闭包中代码,并捕获异常
        }
        catch (Exception e) {
            throw new GradleException("Error: $e.message")
        }
    }
```

### 执行命令行命令
```groovy
task testExec(type:Exec){
    def name =  System.properties['os.name'].toLowerCase()//获取操作系统类型
    println(name)
    if(name.contains('windows')){//不同平台下执行命令有差异
     commandLine 'cmd', '/c', 'ping 192.168.2.105 -t'
    }
}
```
### manifest资源和BuildConfig资源定义

- manifest
```groovy
//定义
defaultConfig {
        resValue "string","app_name", "longforus"//注意定义了的话,values里面就不能再有同名资源了
        manifestPlaceholders = [WX_APPKEY  : weChatKey.toString()]
    }
 //使用
   android:label="@string/app_name"
   <data android:scheme="${WX_APPKEY}"/>
```
- BuildConfig
```groovy
//定义
    buildTypes {
        release {
            buildConfigField "String", "WECHAT_APPKEY", "\"${weChatKey.toString()}\""//这里的""需要转义嵌套
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
        debug{
            buildConfigField "String", "WECHAT_APPKEY", "\"${weChatKey.toString()}\""
        }
    }
 //代码中使用
   mWxapi.registerApp(BuildConfig.WECHAT_APPKEY);
```

### Transform

`com.android.build.api.transform.Transform`是安卓构建过程中的一个class和assets文件的处理流,可以自定义Transform加入到处理的流程中.

```groovy
class ByteCodeProcessors implements Plugin<Project> {
    @Override
    void apply(Project project) {
        AppExtension ext = project.getProperties().get('android')
        ext.registerTransform(new TestTransform(project))
    }
}
​``````````````````````
class TestTransform extends Transform {
    private Project mProject
    TestTransform(Project mProject) {
        this.mProject = mProject
    }
    @Override
    String getName() {
        return "TestTransform"
    }
    @Override
    Set<QualifiedContent.ContentType> getInputTypes() {
        return TransformManager.CONTENT_CLASS
    }
    @Override
    Set<? super QualifiedContent.Scope> getScopes() {
        return TransformManager.SCOPE_FULL_PROJECT
    }
    @Override
    boolean isIncremental() {
        return false
    }
    @Override
    void transform(TransformInvocation transformInvocation) throws TransformException, InterruptedException, IOException {
        super.transform(transformInvocation)
        //是否增量编译
        def incremental = transformInvocation.incremental
        def inputs = transformInvocation.inputs
        def referencedInputs = transformInvocation.referencedInputs
        def provider = transformInvocation.outputProvider
        inputs.forEach { input ->
            input.jarInputs.forEach {
                System.out.println(it.file.toString())
                def destJar = provider.getContentLocation(it.file.absolutePath, it.contentTypes, it.scopes, Format.JAR)
                //处理jar包后,输出
                FileUtils.copyFile(it.file, destJar)
            }
            input.directoryInputs.forEach{
                System.out.println(it.file.toString())
            def destDir =  provider.getContentLocation(it.getName(),it.contentTypes,it.scopes,Format.DIRECTORY)
                //处理非jar包的class后,输出
                FileUtils.copyDirectory(it.file,destDir)
            }
        }
    }
}

```




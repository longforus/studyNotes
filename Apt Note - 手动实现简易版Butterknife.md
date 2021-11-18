# Apt Note - 手动实现简易版Butterknife

早就发现了apt的强大,但是一直没有进行尝试,今天尝试使用apt和javapoet,实现一个简易版的Butterknife.

## 结构

1. anno  这个里面放的annotiation,写到单独的library中.依赖时使用compileOnly ,可以不包含到最终的app中,减少不必要的空间浪费.

2. api  这个里面放的是生成类的接口和bind需要用到的类.

3. compiler 这个是注解处理器.注解的获取和代码的生成都在这里完成.

   三个库都使用 java Library.java的Library不能依赖Android的Library.

## Anno

```java
@Target(ElementType.FIELD)
@Retention(RetentionPolicy.SOURCE)
public @interface BindView {
    int value();
}
```



## Api

```java
public interface IBind<T> {
    void bind(T target);
}

------
public class VoidBind {
    public static void bind(Object activity) {
        try {
            //反射对应的类,生成实例调用
            Class clazz = Class.forName(activity.getClass().getCanonicalName() + "$VoidBind");
            IBind instance = (IBind)clazz.newInstance();
             //调用接口方法,为bind的view赋值
            instance.bind(activity);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```



## Compiler

### VoidBindCompiler

```java
@AutoService(Processor.class)
//要处理的annotiation集合
@SupportedAnnotationTypes( { "com.longforus.voidbindanno.BindView" })
@SupportedSourceVersion(SourceVersion.RELEASE_8)
public class VoidBindCompiler extends AbstractProcessor {

    private ProcessingEnvironment mProcessingEnv;
    private SimpleDateFormat mDateFormat;

    @Override
    public synchronized void init(ProcessingEnvironment processingEnv) {
        super.init(processingEnv);
        //后续要用到
        mProcessingEnv = processingEnv;
        mDateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
    }

    @Override
    public boolean process(Set<? extends TypeElement> annotations,RoundEnvironment roundEnv) {
        //key为全类名 value为要处理的元素集合
        Map<String,List<VariableElement>> map = new HashMap<>();

        Set<? extends Element> annotatedWith = roundEnv.getElementsAnnotatedWith(BindView.class);
        for (Element element : annotatedWith) {
            VariableElement e = (VariableElement)element;
            String fullClassName = getFullClassName(e);
            //如果map中包含就返回,否则调用lambda,生成value并用K保存到map中
            List<VariableElement> elements = map.computeIfAbsent(fullClassName,k -> new ArrayList<>());
            elements.add(e);
        }

        for (Map.Entry<String,List<VariableElement>> entry : map.entrySet()) {
            if (entry.getValue() == null || entry.getValue().isEmpty()) {
                continue;
            }

            String fullName = entry.getKey();
            int i = fullName.lastIndexOf(".");
            //获取外围元素的类型,toString()其实就是全类名
            TypeName enclosingTypeName = TypeName.get(entry.getValue().get(0).getEnclosingElement().asType());
            //生成方法
            MethodSpec.Builder methodBuild = MethodSpec.methodBuilder("bind").addAnnotation(Override.class).addModifiers(Modifier.PUBLIC).returns(void.class).addParameter(
                enclosingTypeName,"target");
            for (VariableElement element : entry.getValue()) {
                methodBuild.addStatement(
                    String.format(Locale.CHINA,"target.%s=target.findViewById(%d)",element.getSimpleName().toString(),element.getAnnotation(BindView.class).value()));
            }

            String enclosingClassName = fullName.substring(i + 1,fullName.length());
            //生成带泛型的接口类型名
            ParameterizedTypeName superinterface = ParameterizedTypeName.get(ClassName.get(IBind.class),enclosingTypeName);
            TypeSpec typeSpec = TypeSpec.classBuilder(enclosingClassName + "$VoidBind")
                                        .addModifiers(Modifier.PUBLIC,Modifier.FINAL)
                                        .addSuperinterface(superinterface)
                                        .addMethod(methodBuild.build()).build();

            String packageName = fullName.substring(0,i);
            JavaFile javaFile = JavaFile.builder(packageName,typeSpec).addFileComment("This class generate by VoidBind.Don't modify it,   - "+mDateFormat.format(new Date())).build();
            try {
                //写出到generated/source/kapt/debug/包名/目录下
                javaFile.writeTo(mProcessingEnv.getFiler());
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
        return true;
    }

    private String getFullClassName(VariableElement e) {
        //获取到持有e的外围元素,这里是Activity等
        TypeElement enclosingElement = (TypeElement)e.getEnclosingElement();
        //获取外围元素的包名
        String packageName = mProcessingEnv.getElementUtils().getPackageOf(enclosingElement).getQualifiedName().toString();
        return packageName + "." + enclosingElement.getSimpleName().toString();
    }
}


```



### gradle

```groovy
apply plugin: 'java-library'

dependencies {
    implementation fileTree(dir: 'libs', include: ['*.jar'])
    implementation project(':VoidBindAnno')
    //不能依赖android library
    implementation project(':VoidBindApi')
    implementation 'com.google.auto.service:auto-service:1.0-rc4'
    implementation 'com.squareup:javapoet:1.11.0'
}

//指定编译的编码
tasks.withType(JavaCompile){
    options.encoding = "UTF-8"
}

sourceCompatibility = "1.8"
targetCompatibility = "1.8"

```


## 使用

### 添加依赖

```groovy
    //注解
    compileOnly project(':VoidBindAnno')
    //工具
    implementation project(':VoidBindApi')
    //处理注解生成代码
    kapt project(':VoidBindCompiler')
```

### 进行注解

```java
public class SecondActivity extends AppCompatActivity {

    @BindView(R.id.button)
    Button mButton;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_second);
        VoidBind.bind(this);
        mButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Toast.makeText(SecondActivity.this,"success",Toast.LENGTH_SHORT).show();
            }
        });
    }
}
```

**如果在kotlin中使用,生成的代码提示被注解的var是private的.暂时还没想到怎么解决**

## 生成的代码

```java
// This class generate by VoidBind.Don't modify it,   - 2018-05-09 14:57:29
package com.longforus.aptdemo;

import com.longforus.voidbindapi.IBind;
import java.lang.Override;

public final class SecondActivity$VoidBind implements IBind<SecondActivity> {
  @Override
  public void bind(SecondActivity target) {
    target.mButton=target.findViewById(2131165219);
  }
}


```



也算是打开了一种新的思路,工作中还没有发现适合实际应用的场景.笔记保存,方便查用.
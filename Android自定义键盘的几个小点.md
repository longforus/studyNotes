# Android自定义键盘的几个小点

最近的项目中需要输入字母,且环境有一些特殊的要求:

- 不能跳出当前APP
- 只需输入大写字母和数字

一般的第三方输入法都有跳出当前APP的路径,这是不允许存在的,机器7.0自带的键盘也非常的不好用,复杂而且不符合国人习惯.项目之前是用RecycleView在应用界面内实现输入数字,避免调起系统舒服法来解决上面的这些问题的,但是现在需要输入字母,那个方案就不行了,而且占用较大的界面面积,改版后需要弹出键盘输入.势必要改了.

之前的项目因为有的第三方输入法在使用蓝牙设备输入的时候会自动转成拼音,导致输入错误,所以当时就做过一个键盘,是根据<[Android InputMethodService|KeyboardView 自定义输入法和键盘 01](https://www.jianshu.com/p/12bcfd8c2c6e)>这个demo修改的.当时做得很简单没有遇到什么问题,大家跟着操作就好.但是这次的要求更复杂些,改的时候也遇到了一些问题,记录一下.



### 按键不够时如何让键盘铺满底部

全键盘的时候还好,但是做9键的时候遇到了因为按键不够,键盘不能铺满屏幕底部的问题.开始我用`android:horizontalGap="32.3%p"`这个属性来把按键撑开,看起来确实有点效果,但是1是很难调整,2是按键会比看起来的大,撑开的距离也是按键的范围,点击也是有响应的.后来通过修改键盘的测量尺寸解决:

```java
@Override
public void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
    setMeasuredDimension(screenWidth, getKeyboard().getHeight());
}

```

### 9键时9键不居中

默认的按键布局是从左起的,也没有发现什么控制gravity的方法.后来通过给每一个键的x加一个偏移量,实现整个9键的居中显示:

```java
 mKeyboardNum = new Keyboard(context,R.xml.digit,0, screenWidth, ViewGroup.LayoutParams.WRAP_CONTENT);
 int addWidth = (int) (screenWidth * 0.33);
 for (Keyboard.Key key : mKeyboardNum.getKeys()) {
     key.x += addWidth;
 }
 setKeyboard(mKeyboardNum);
```



### InputConnection如何清空当前的输入内容

键盘有做清空的功能,但是拿到InputConnection实例后,发现没有clear,remove之类名字的api可供调用清空,难道這么简单的功能也没提供?百度 *inputconnection 清空*也毫无结果,删除一个char的话调用的是`boolean deleteSurroundingText(int beforeLength, int afterLength);`那么多个呢?观察这个方法的注释:

```java
     * @param beforeLength The number of characters before the cursor to be deleted, in code unit.
     *        If this is greater than the number of existing characters between the beginning of the
     *        text and the cursor, then this method does not fail but deletes all the characters in
     *        that range.
     * @param afterLength The number of characters after the cursor to be deleted, in code unit.
     *        If this is greater than the number of existing characters between the cursor and
     *        the end of the text, then this method does not fail but deletes all the characters in
     *        that range.
     * @return true on success, false if the input connection is no longer valid.
     */
    boolean deleteSurroundingText(int beforeLength, int afterLength);
```

那么清空就很简单了.

```java
ic.deleteSurroundingText(Integer.MAX_VALUE,Integer.MAX_VALUE);
```

### 转发EditorAction给EditText

要通过InputConnection$sendKeyEvent,当前焦点的EditText的OnEditorActionListener才能收到action.

```java
 ic.sendKeyEvent(new KeyEvent(eventTime,eventTime,KeyEvent.ACTION_DOWN,KeyEvent.KEYCODE_ENTER,0,0,KeyCharacterMap.VIRTUAL_KEYBOARD,0,
                        KeyEvent.FLAG_SOFT_KEYBOARD | KeyEvent.FLAG_KEEP_TOUCH_MODE | KeyEvent.FLAG_EDITOR_ACTION));
```

### EditText禁用长按弹出复制菜单

长按菜单中会有分享,可能导致跳出当前app,所以要禁用掉.

```kotlin
mVB.etCode.customSelectionActionModeCallback = object : android.view.ActionMode.Callback {
  override fun onCreateActionMode(mode: android.view.ActionMode?, menu: Menu?): Boolean =
      false

  override fun onPrepareActionMode(mode: android.view.ActionMode?, menu: Menu?): Boolean =
      false

  override fun onActionItemClicked(
      mode: android.view.ActionMode?,
      item: MenuItem?
  ): Boolean = false

  override fun onDestroyActionMode(mode: android.view.ActionMode?) {

  }
}
```



### 把自己的键盘设为系统默认

即使当前系统以及切换到我们的键盘,但是如果我们的键盘升级重装的话,默认输入法又会被恢复为默认是系统键盘,如何自动的再切到我们的键盘呢?通过`Settings.Secure.getString(context.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)`可以获取到当前的默认输入法ID.而且还有一个方法`Settings.Secure.putString(context.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD,SmInputMethod.INPUT_METHOD_ID)`可以设置默认输入法的ID,是不是我们调用这个方法就可以了呢?当然没有这么简单,这个操作需要`android.permission.WRITE_SECURE_SETTINGS`权限,需要是系统APP才能调用,还有没有其他办法呢?如果机器是root了的话,是可以的.

```kotlin
 val execCmd = ShellUtils.execCmd(
     "settings put secure default_input_method ${MyInputMethod.INPUT_METHOD_ID}",
     true,
     true
 )
 LogUtils.d(TAG,execCmd?.result)
 val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager

 val string = Settings.Secure.getString(
     contentResolver,
     Settings.Secure.DEFAULT_INPUT_METHOD
 )
 LogUtils.d(TAG, "cur ime: $string")
 val find = imm.enabledInputMethodList.find { it.id == SmInputMethod.INPUT_METHOD_ID }
 if (find == null) {
     val keyBordIntent = Intent()
     keyBordIntent.action = Settings.ACTION_INPUT_METHOD_SETTINGS
     RxActivityResult.on(this@RelaunchActivity).startIntent(keyBordIntent)
         .subscribe { result ->
             result.targetUI().apply {
                     imm.showInputMethodPicker()
             }
         }
 }
```

这样就可以了,关于修改secure Settings,我还发现一种方法.

```kotlin
private fun setDefaultInputMethod() {
        try {

            val pathname = "/data/system/users/0/settings_secure.xml"
            ztlManager.execRootCmdSilent("chmod 777 $pathname")
            val localFile = File(filesDir, "settings_secure.xml")
            ztlManager.execRootCmdSilent("cp -f $pathname ${localFile.absolutePath}")
            ztlManager.execRootCmdSilent("chmod 777 ${localFile.absolutePath}")
            val factory = DocumentBuilderFactory.newInstance()
            val builder = factory.newDocumentBuilder()
            val doc = builder.parse(localFile)
            val root = doc.getElementsByTagName("settings")
            val item = root.item(0)
            val childNodes = item.childNodes
            loopOut@ for (i in 0 until childNodes.length) {
                val node = childNodes.item(i)
                val attributes = node.attributes ?: continue@loopOut
                for (j in 0 until attributes.length) {
                    val item1 = attributes.item(j)
                    if (item1.nodeValue == Settings.Secure.DEFAULT_INPUT_METHOD) {
                        val item2 = attributes.item(j + 1)
                        item2.nodeValue = SmInputMethod.INPUT_METHOD_ID
                        val item3 = attributes.item(j + 2)
                        item3.nodeValue = packageName
                        LogUtils.d(TAG, "find target ${item2.toString()}")
                        break@loopOut
                    }
                }
            }
            val tFactory = TransformerFactory.newInstance();// 将内存中的Dom保存到文件
            val transformer = tFactory.newTransformer();
//            // 设置输出的xml的格式，utf-8
            transformer.setOutputProperty("encoding", "utf-8");
            val source = DOMSource(doc)
//            //xml的存放位置
            val src = StreamResult(localFile)
            transformer.transform(source, src)
            ztlManager.execRootCmdSilent("chmod 777 $pathname")
            ztlManager.execRootCmdSilent("rm -f $pathname")
            val execCmd =
                ShellUtils.execCmd("cp -f ${localFile.absolutePath} $pathname", true, true)
            LogUtils.d(TAG,  execCmd?.errorMsg)
//            ztlManager.execRootCmdSilent("cp -f ${localFile.absolutePath} $pathname")
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
```

发现可以`settings put secure default_input_method ${MyInputMethod.INPUT_METHOD_ID}`之前我是這么实现的,好像有用.也算一个方法吧,对于不支持直接adb shell命令的内容修改,还是可以尝试的.

综上遇到的几个小点.
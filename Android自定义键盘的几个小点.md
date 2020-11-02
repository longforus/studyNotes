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



综上遇到的几个小点.
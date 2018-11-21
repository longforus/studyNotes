#!/bin/bash
echo "hello world"
var1="longforus"
echo $var1
readonly var1
var2="haner \"${var1}\""
echo $var2
#输出字符串的length
echo ${#var2}
#截取字符串,前闭后闭
echo ${var2:1:4}
array=($var1 $var2 123 "456")
echo ${array[2]}
#获取array的所有元素
echo ${array[@]}
#获取array的length
echo ${#array[@]}
#下面是多行注释,关键是<<后面的开始符号需要和最后的结束符号一致
:<<EOF
for name in $(ls /home); do
        echo "SBSB :"+$name
done
EOF
#获取this的文件名,bat文件里面用%代替$
echo "this的文件名 $0"
echo "参数0  $1"
echo "依次类推  $2"
#用esc键下面的`包起来,运算符的前后都要一个空格
rt=`expr 2 + 2`
#乘号的*前面要\
rt1=`expr 2 \* 2`
echo "2+2= $rt"
echo "2*2=$rt1"
#条件表达式[]包起来,前后空格
if [ $rt == $rt1 ]
then
        echo "rt==rt1"
fi

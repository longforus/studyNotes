echo "" >README.md
path=""
suffix=".md"
#找到当前目录下所有后缀是.md的文件,遍历
for files in `find  ./ -name "*.md"`
do
    #如果path为空直接赋值,否则append
    if [[ $path ]]; then
        path="$path $files"
    else
        path=$files
    fi
    #如果包含后缀,说明一个文件结束了
    if [[ $files =~ $suffix ]]; then
        echo $path
        #截取子串,删掉 ./*.md
        name=${path:2:-3}
        #append到文件中,-e 支持转义,${path// /%20} 是替换所有空格为%20 
        echo -e "[$name](${path// /%20})\r\n" >> README.md
        path=""
    fi
done
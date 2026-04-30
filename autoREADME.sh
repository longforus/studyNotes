#!/bin/bash

# 先执行重命名（可选，也可以手动跑上面的脚本）
# 使用 Python 的方式或 Bash 的正则，匹配所有类型的空白字符
# [[:space:]] 会匹配半角空格、全角空格、TAB等
find . -maxdepth 1 -name "*[[:space:]]*" | while read -r file
do
    # 将所有空白字符替换为下划线
    new_name=$(echo "$file" | sed -r 's/[[:space:]]+/_/g')
    
    if [ "$file" != "$new_name" ]; then
        mv "$file" "$new_name"
        echo "Renamed: $file -> $new_name"
    fi
done

# 如果你想顺便把中括号也干掉（因为它们在 Markdown 里最容易出问题）
# 取消下面几行的注释即可：
find . -maxdepth 1 -name "*[\[\]]*" | while read -r file; do
    new_name=$(echo "$file" | tr -d '[]')
    mv "$file" "$new_name"
done

# 初始化 README
echo "# Archive Index" > README.md
echo -e "Updated: $(date +'%Y-%m-%d %H:%M:%S')\n" >> README.md

# 查找 .md 和 .html
find . -maxdepth 1 \( -name "*.md" -o -name "*.html" \) ! -name "README.md" | sort | while read -r file
do
    clean_path="${file#./}"
    name="${clean_path%.*}"
    
    # 彻底转义：除了空格，把中括号也转义掉，防止破坏 Markdown 语法 [text](url)
    url=$(echo "$clean_path" | sed 's/\[/%5B/g; s/\]/%5D/g')
    
    echo "- [$name]($url)" >> README.md
done

echo "Done! All files renamed and README.md updated."
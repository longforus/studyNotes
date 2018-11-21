echo "" >README.md
path=""
suffix=".md"
for files in `find  ./ -name "*.md"`
do
    if [[ $path ]]; then
        path="$path $files"
    else
        path=$files
    fi
    if [[ $files =~ $suffix ]]; then
        echo $path
        name=${path:2:${#str}-3}
        echo "[$name](${path// /&nbsp;})" >> README.md
        path=""
    fi
done
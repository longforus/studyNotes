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
        name=${path:2:-3}
        echo -e "[$name](${path// /%20})\r\n" >> README.md
        path=""
    fi
done
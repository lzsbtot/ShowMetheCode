#!/bin/bash

if [ $# -eq 1 ]
then
    path=$1
else
    echo "Please provide the target directory!"
    exit 1;
fi


echo target files are : `ls $path`
cd $path
echo current directory is : `pwd`

read -p "Type y to mkdir for each file and move them to each directory: " input
case $input in
    [yY]) 
    for file in `ls`
    do 
        ext=${file#*.}
        if [ $ext == "go"]
        then
            dir=${file%%.*}
            mkdir $dir
            mv $file $dir
        fi
    done
    echo "Done!"
    echo target files are moved to each folder: `ls $path`
    ;;
    [nN])
    echo "Do nothing! Quit"
    exit 1;
    ;;
esac
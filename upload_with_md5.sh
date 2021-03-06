#!/bin/bash
export LANG=C
SALVEIFS=$IFS

IFS=$(echo -en "\n\b")

function send_file(){
    echo "上传文件 $list"
    str=$RANDOM
    sign=`echo -n awupload$str| md5sum | awk '{print $1}'`
    # curl 连接超时时间10秒 请求超时时间5秒 超时后最多重试3次
    info=`curl -H "Expect:" -F "file=@$list" --connect-timeout 10 --max-time 5 --retry 3 https://monitor.autowise.tech/vehicle-pose/upload-route\?token=$sign\&str=$str`

    #对响应码进行判断
    if [ "$info" == "success" ];then
        echo "处理成功，$info"
    else
        echo "处理失败，$info"
    fi
}

# function send_file(){
#     echo "上传文件 ${list}"
# }

# 定义MD5文件保存的路径
md5_path=./json_md5_log.sum
path=/opt/ros/kinetic/share/aw_global_planning/data
# path=~/桌面/newdir/data

source ~/.autowise/setup.sh
# gnome-terminal -x bash -c "roscore"
# xterm -e bash -c 'roscore' &

# 判断MD5基准校验文件是否存在，不存在则创建此文件,并修改权限只有root用户或者指定用户有读写权限
[ ! -f $md5_path ] && touch $md5_path && chmod 600 $md5_path
# read -p "请输入你需要MD5检验文件的目录,必须以\"/\"开始: " path
# if ! echo $path | grep -q "^/";then echo "不是以\"/\"开始";exit 1;fi

echo "#################################################"
# 如果所给需要md5校验的目录不存在，或者目录存在但目录下没有一个文件，则返回错误并提示用户
    if [ ! -d $path ] || [ `find $path -type f | wc -l` -eq 0 ];then
        echo "Error：Path does not exist or there is no file under the path"
        exit 1
    fi
# 判断基准文件数量
for i in `cat ${md5_path} | awk '{print $2}'`;do
    if [[ ! -f $i ]];then
        echo -e "[Detection time：`date +"%Y-%m-%d %T.%N"`]  [File：$i] \033[31m[MD5 check result：Removed]\033[0m" 2>&1
        # 去除md5 从$md5_path
        v2=${i//\//\\/}
        sed -i "${v2}/d" ${md5_path}
    fi
done

for list in `find $path -type f`;do
    new_md5_arg1=`md5sum $list | awk '{print $1}'`
    new_md5_arg2=`md5sum $list | awk '{print $2}'`
    old_md5_arg2=`awk -v List="$list" '$2 == List{print $2}' $md5_path`
    if [[ "$new_md5_arg2" == "$old_md5_arg2" ]];then
        old_md5_arg1=`awk -v List="$list" '$2 == List{print $1}' $md5_path`
        if [[ ! "$new_md5_arg1" == "$old_md5_arg1" ]];then
            echo -e "[Detection time：`date +"%Y-%m-%d %T.%N"`]  [File：$list] \033[31m[MD5 check result：Changed]\033[0m" 2>&1 
            # 去除原md5，添加新md5至 $md5_path
            v3=${list//\//\\/}
            sed -i "${v3}/d" ${md5_path}
            md5sum ${list} >> ${md5_path}
            # 执行JSON生成
            if echo ${list} | grep -q '\.json' 
            then
                send_file "${list}"
            fi
        else
            echo -e "[Detection time：`date +"%Y-%m-%d %T.%N"`]  [File：$list] \033[32m[MD5 check result：Unchanged]\033[0m"
        fi
    else
        new_file_md5=`md5sum ${list}`
        md5sum ${list} >> ${md5_path}
        echo -e "[Detection time：`date +"%Y-%m-%d %T.%N"`]  [File：$list] \033[31m[MD5 check result：Added]\033[0m" 2>&1 
        if echo ${list} | grep -q '\.json' 
        then
            send_file "${list}"
        fi
    fi
    # 如果文件数量大，可以把sleep的时间间隔设置小点。
    sleep 0.5
done

IFS=$SAVEIFS
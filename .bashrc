# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
export PATH="$HOME/toolchains/bin":$PATH
export PATH="$HOME/toolchains/apache-maven-3.6.3/bin":$PATH
export PATH="$HOME/toolchains/jdk1.8.0_131/bin":$PATH
export PATH="$HOME/toolchains/node-v12.13.0-linux-x64/bin":$PATH
export PATH="$HOME/toolchains/go/bin":$PATH
export PATH="$HOEM/toolchains/rpcsvc/bin":$PATH
export PATH=$PATH:"$HOME/miniconda3/bin"
export PATH=$PATH:"$HOME/Code/ClickHouse/build_Release/programs"
export JAVA_HOME="/mnt/disk1/hezhiqiang/toolchains/jdk1.8.0_131"

function print_result() {
    local op=$1  # Declare the variable as local to the function

    if [ $? -eq 0 ]; then
        echo -e "\033[32m${op} succeed \033[0m"
    else
        echo -e "\033[31m${op} failed \033[0m"
    fi
}

function convertType() {
    local type=$1

    case $type in
        D|Debug)
            echo "Debug"
            ;;
        R|Release)
            echo "Release"
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}



doris_home="$HOME/doris"
doris_output="$HOME/doris/output"
doris_be="$HOME/doris/be"
doris_fe="$HOME/doris/fe"
doris_workspace="$HOME/workspace"

# usage: bestop $type("Debug"/"Release") $seq(1/2)
function bestop()
{
	local type=$(convertType ${1:-D})
	validate_type "$type"
    
	if [[ $? -ne 0 ]]; then
        echo "Invalid type: $type for bestop"
		return 1
    fi

	local seq=${2:-1}
	cd "$doris_workspace/$type/be_$seq" && sh bin/stop_be.sh
	print_result "Stop BE $type $seq"
	cd - > /dev/null
}

# usage: bemake $type("Debug"/"Release"/"ASAN") $seq(1/2)
function bemake()
{
    local type=$(convertType ${1:-R})	
	validate_type "$type"
	
	if [[ $? -ne 0 ]]; then
        echo "Invalid type: $type for bemake"
                return 1
    fi

	local seq=$2
	local build_dir="$doris_be/build_$type"
 	
	cd $doris_home
	echo "BUILD_TYPE=$type" > custom_env.sh
	echo "DISABLE_BE_JAVA_EXTENSIONS=ON" >> custom_env.sh
	echo "ENABLE_STACKTRACE=OFF" >> custom_env.sh
	echo "Making doris be, type: $type"
	bash build.sh --be
	
	#rm -rf "$HOME/workspace/$type/be_$seq/lib/doris_be-prev"
	#mv "$HOME/workspace/$type/be_$seq/lib/doris_be" "$HOME/workspace/$type/be_$seq/lib/doris_be-prev"
	#echo "Copying from $doris_home/output/be/lib/doris_be to $HOME/workspace/$type/be_$seq/lib"
	#cp "$doris_home/output/be/lib/doris_be" "$HOME/workspace/$type/be_$seq/lib/doris_be"
	cd - > /dev/null
}

function makeone()
{
	local type=$(convertType ${1:-D})
	local build_dir="$doris_be/build_$type"
	local build_ninja="$build_dir/build.ninja"
	target=$(rg $2.o: "${build_ninja}" | awk -F'[ :]' '{print $2}')
	ninja -C "${build_dir}" "${target}"
}


# usage: bestart $type("Debug"/"Release") $seq(1/2)
function bestart()
{
    local type=$(convertType ${1:-R})
    validate_type "$type"
	
    if [[ $? -ne 0 ]]; then
        echo "Invalid type: $type for bestart"
                return 1
    fi

	local build_dir="$doris_be/build_$type"
	local seq=${2:-1}
	cd "$doris_workspace/$type/be_$seq"

	bestop $type $seq
	
	sh bin/start_be.sh --daemon
	print_result "Start BE $type $seq"
	
	cd - > /dev/null
}

function femake()
{
	#cd "$doris_fe/"
	#mvn package -pl fe-common,fe-core -Dskip.doc=true -DskipTests -Dcheckstyle.skip=true
    #rm -rf "$doris_output/fe/lib/*"
    #cp -r -p "$doris_fe/fe-core/target/lib" "$doris_output/fe/lib/"
	#cp -r -p "$doris_fe/fe-core/target/doris-fe.jar" "$doris_output/fe/lib/"
	cd "$doris_home"
    echo "DISABLE_JAVA_CHECK_STYLE=ON" >> custom_env.sh
	sh build.sh --fe
	cd - > /dev/null	
}

function festart()
{
	cd "$doris_workspace/fe_1"
	if [ ! -f "lib/help-resource.zip" ]; then
		local src_zip="$doris_fe/../docs/build/help-resource.zip"
		if [ ! -f $src_zip ]; then
			echo -e "\033[31mhelp-resource.zip is missing, maybe you shuold build docs first.\033[0m"
			cd -
			return 1
		else
			cp $src_zip "lib/help-resource.zip"
		fi
    fi
	sh bin/stop_fe.sh
	print_result "Stop FE"
 	
	echo -e "\033[32mStarting FE master \033[0m"
	sh bin/start_fe.sh --daemon 
	print_result "Start FE master"
	cd - > /dev/null
}

function startmysql()
{
	cd "/mnt/disk1/hezhiqiang/downloads/mysql-8.0.33-linux-glibc2.12-x86_64"
	./bin/mysqld --defaults-file=~/my.cnf --daemonize
	print_result "Start mysql server"
	cd - > /dev/null
}

function cmysql()
{
	mysql -S /tmp/mysql-hzq.sock -u root -p -P 3307
}

function cfe() 
{
	local seq=$1
    local port=$((6937 + seq - 1))
	mysql -uroot -h127.0.0.1 -P$port --verbose
}

function cc()
{
    local count=$1
    for ((i=0; i < count; i++))
    do
        mysql -uroot -h127.0.0.1 -P6937 -e "ALTER SYSTEM ADD BACKEND \"10.16.10.8:925$((1 + i))\""
		sleep 2
    done


	#mysql -uroot -h127.0.0.1 -P6937 -e "ALTER SYSTEM ADD FOLLOWER \"10.16.10.8:6918\""
	#sleep 1
	#mysql -uroot -h127.0.0.1 -P6937 -e "ALTER SYSTEM ADD FOLLOWER \"10.16.10.8:6919\""
	#sleep 1
	#mysql -uroot -h127.0.0.1 -P6937 -e "ALTER SYSTEM ADD BACKEND \"10.16.10.8:9251\"";
	sleep 1
	#mysql -uroot -h127.0.0.1 -P6937 -e "ALTER SYSTEM ADD BACKEND \"10.16.10.8:9252\"";
	sleep 5
	mysql -uroot -h127.0.0.1 -P6937 < "$doris_workspace/scripts/init-table.sql"
	sleep 1	
	curl  --location-trusted -u root: -T $doris_workspace/data_src/test.csv -H "column_separator:," http://127.0.0.1:5937/api/demo/example_tbl/_stream_load
}

function validate_type()
{
    local type=$1
   
    if [[ $type != "Debug" && $type != "Release" ]]; then
        echo "Invalid type: $type. Please choose either 'Debug' or 'Release'."
        return 1
    fi
    return 0
}




function initdoris()
{
	local type=$(convertType ${1:-D})
	validate_type "$type"
  	if [[ $? -ne 0 ]]; then
		echo "Invalid type $type for initdoris"
		return 1
	fi
	
	local fe_meta=$doris_workspace/fe_1/doris-meta
	echo "Removing fe meta: $fe_meta/*"
	rm -rf $fe_meta/*
	rm $doris_workspace/fe_1/log/*
	local be_sto=$doris_workspace/$type/be_1/storage
	echo "Removing be storage: $be_sto/*"
	rm -rf $be_sto/*
	rm $doris_workspace/$type/be_1/log/*
    festart 
	bestop Release 1
	bestop Debug 1
    
	bestart $type 1

	cd - > /dev/null
    return 0
}

function tofe()
{
	cd $doris_workspace/fe_1
}

function tobe()
{
	local type=$(convertType ${1:-R})
	local seq=${2:-1}
	cd "$doris_workspace/$type/be_$seq"
}

function ckstart()
{
	cd "/mnt/disk1/hezhiqiang/Code/ClickHouse/build_Release"
	clickhouse server --config-file="/mnt/disk1/hezhiqiang/Code/ClickHouse/programs/config.xml"
	cd - > /dev/null
}

function cck()
{
	clickhouse client --port=9888
}

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/mnt/disk1/hezhiqiang/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/mnt/disk1/hezhiqiang/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/mnt/disk1/hezhiqiang/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/mnt/disk1/hezhiqiang/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

function tmuxCC()
{
	local id=${1:-0}
	tmux -CC attach-session -t $id
}

be20="/mnt/disk1/hezhiqiang/downloads/apache-doris-2.0.2-bin-x64/be"
fe20="/mnt/disk1/hezhiqiang/downloads/apache-doris-2.0.2-bin-x64/fe"

function bestart2()
{
	cd $be20
	sh bin/stop_be.sh
	sh bin/start_be.sh --daemon
	cd - > /dev/null
}

function festart2()
{
	cd $fe20
	sh bin/stop_fe.sh
	sh bin/start_fe.sh --daemon
	cd - > /dev/null
}


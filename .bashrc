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
export PATH="$HOME/toolchains/rpcsvc/bin":$PATH
export JAVA_HOME="$HOME/toolchains/jdk1.8.0_131"

function print_result() {
    local name=$1  # Declare the variable as local to the function

    if [ $? -eq 0 ]; then
        echo -e "\033[32mStart ${name} succeed \033[0m"
    else
        echo -e "\033[31mStart ${name} failed \033[0m"
    fi
}

doris_be="$HOME/doris/be"
doris_fe="$HOME/doris/fe"
doris_workspace="$HOME/workspace"

function bemake()
{
	local type=$1
	local build_dir="$doris_be/build_$type"
	
	cd $build_dir && echo "Making doris be, type: $type"
	ninja -j 32
	cp "$doris_be/output/lib/doris_be" "$HOME/workspace/$type/be/lib"
	cd -
}

function mdb()
{
	bemake "Debug"
}

function mrb()
{
	bemake "Release"
}

function bestart()
{
	local type=$1
	cd "$doris_workspace/$type/be"

	sh bin/stop_be.sh
	if [ $? -eq 0 ];then
		echo -e "\033[32mStop be succeed \033[0m "
	else
		echo -e "\033[31mStop be failed \033[0m "
	fi
	
	sh bin/start_be.sh --daemon
	if [ $? -eq 0 ];then
		echo -e "\033[32mStart be succeed \033[0m "
	else
		echo -e "\033[31mStart be failed \033[0m "
	fi
	
	cd -
}

function sdb()
{
	bestart "Debug"
}
function srb()
{
	bestart "Release"
}

function festart()
{
	cd "$doris_workspace/fe"
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
	if [ $? -eq 0 ];then
		echo -e "\033[32mStop fe succeed \033[0m "
	else
		echo -e "\033[31mStop fe failed \033[0m "
	fi
	
    sh bin/start_fe.sh --daemon
	if [ $? -eq 0 ];then
		echo -e "\033[32mStart fe succeed \033[0m "
	else
		echo -e "\033[31mStart fe failed \033[0m "
	fi
	
    cd -
}

function startmysql()
{
	cd "$HOME/downloads/mysql-8.0.33-linux-glibc2.12-x86_64"
	./bin/mysqld --defaults-file=~/my.cnf --daemonize
	print_result "start mysql server"
	cd -
}

function cmysql()
{
	mysql -h127.0.0.1 -u root -p -P 3307
}

function cfe()
{
	mysql -uroot -h127.0.0.1 -P6937
}

function cc()
{
	mysql -uroot -h127.0.0.1 -P6937 -e 'ALTER SYSTEM ADD BACKEND "127.0.0.1:9251"';
}

function initdoris()
{
	local type=$1

	rm -rf $doris_workspace/fe/doris-meta/*
	rm -rf $doris_workspace/$type/be/storage/*

  festart
	sdb

	cd -
}


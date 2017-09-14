#!/bin/bash



############ get pwd###############

DIR="$( cd "$( dirname "$0"  )" && pwd  )"

WEB_ROOT=/data/wwwroot/default/razor
MYSQL_HOME=/usr/local/mysql/bin
CRON_TASK=/var/www/cron

RES=0


############## 检查服务是否启动 #################


check_service(){

        if [ $(netstat -lutnp|grep 3306|wc -l) -ge 0 ]
                then
                        echo -e "[\033[32m *SUCCESS \033[0m]		mysql starting success..."
                else
                        echo -e "[\033[31m *FAIL \033[0m]		mysql starting fail,plaese check the service!"
                		let RES=1
        fi


        if [ $(netstat -lutnp|grep 9000|wc -l) -ge 0 ]
                then
                        echo -e "[\033[32m *SUCCESS \033[0m]		php-fpm starting success..."
                else
                        echo -e "[\033[31m *FAIL \033[0m]		php-fpm starting fail,plaese check the service!"
              			let RES=1
        fi

        if [ $(netstat -lutnp|grep 80|wc -l) -ge 0 ]
                then
                        echo -e "[\033[32m *SUCCESS \033[0m]		nginx starting success..."
                else
                        echo -e "[\033[31m *FAIL \033[0m]		nginx starting fail,plaese check the service!"
        				let RES=1
        fi

        return $RES
}


#################################################################
#                                                               #
#                        初始化数据库                           #
#                                                               #
#################################################################


init_db(){

	/bin/cp $DIR/database.php $WEB_ROOT/application/config

	$MYSQL_HOME/mysql -u root -p123456 < $DIR/sql_script/create_dbuser.sql &>/dev/null
	$MYSQL_HOME/mysql -u root -p123456 < $DIR/sql_script/razor_db.sql &>/dev/null
	$MYSQL_HOME/mysql -u root -p123456 < $DIR/sql_script/razor_dw.sql &>/dev/null

}

db_menu(){

{
    for ((i = 0 ; i <= 100 ; i+=1)); do
        init_db &
        sleep 1
        echo $i
    done
} | whiptail --gauge "Please wait for initialzing database..." 6 50 0


}

#################################################################
#                                                               #
#                      创建站点超级用户                         #
#                                                               #
#################################################################

SUPUESER=''
PASSWD=''
EMAIL=''

create_supersuer(){
	
	    SUPUESER=$(whiptail --inputbox "Super User" 8 78 --title "Super User" $SUPUESER 3>&1 1>&2 2>&3)
	    exitstatus=$?
	    if [ $exitstatus = 0 ]; then
	        PASSWD=$(whiptail --inputbox "Password of Super User" 8 78 --title "Password" $PASSWD 3>&1 1>&2 2>&3)
	        exitstatus=$?
	        if [ $exitstatus = 0 ]; then
	        EMAIL=$(whiptail --inputbox "Your Email Account" 8 78 --title "Emain" $EMAIL 3>&1 1>&2 2>&3)
	        exitstatus=$?
	        fi
	   
		else
			echo "User selected Cancel."
		fi

	exitstatus=$?
	if [ $exitstatus = 0 ]; then

		MDPASSWD=`echo -n ${PASSWD} | md5sum | awk -F"  " '{print $1}'`

	        $MYSQL_HOME/mysql -uroot -p123456 -e "
	            USE razor_db;
                INSERT INTO razor_users (
                username,
                password,
                email,
                activated
                 ) VALUES ('"$SUPUESER"',
                '"$MDPASSWD"',
                '"$EMAIL"',
                1);
	        "
	else 
		echo "User selected Cancel."
	fi
}



#################################################################
#                                                               #
#                      Edit email.php                           #
#                                                               #
#################################################################

ehost_config(){
	SMTP_HOST=$(whiptail --inputbox "SMTP Server.  Example: smtp.exmail.sina.com" 8 78 --title "SMTP Server" $SMTP_HOST 3>&1 1>&2 2>&3)

	exitstatus=$?
	if [ $exitstatus = 0 ]; then
		if [ ! -z $SMTP_HOST ];then
			sed -i "s#\$config\['smtp_host'\]\s*= '';#\$config['smtp_host'] = '${SMTP_HOST}';#g" $WEB_ROOT/application/config/email.php
		fi
	else
		echo "User selected Cancel."

	echo "(Exit status was $exitstatus)"
	fi
}


euser_config(){
    SMTP_USER=$(whiptail --inputbox "SMTP Username  Example: yourname@sina.com" 8 78 --title "SMTP server address" $SMTP_USER 3>&1 1>&2 2>&3)

    exitstatus=$?
	if [ $exitstatus = 0 ]; then
		if [ ! -z $SMTP_USER ];then
			sed -i "s#\$config\['smtp_user'\]\s*= '';#\$config['smtp_user'] = '${SMTP_USER}';#g" $WEB_ROOT/application/config/email.php
		fi
	else
		echo "User selected Cancel."

	echo "(Exit status was $exitstatus)"
	fi
}

epass_config(){
    SMTP_PASS=$(whiptail --inputbox "SMTP Password  your email address" 8 78 --title "SMTP server account password" $SMTP_PASS 3>&1 1>&2 2>&3)

    exitstatus=$?
	if [ $exitstatus = 0 ]; then
		if [ ! -z $SMTP_USER ];then
			sed -i "s#\$config\['smtp_pass'\]\s*= '';#\$config['smtp_pass'] = '${SMTP_PASS}';#g" $WEB_ROOT/application/config/email.php
		fi
	else
		echo "User selected Cancel."

	echo "(Exit status was $exitstatus)"
	fi
}


eport_config(){
    SMTP_PORT=$(whiptail --inputbox "SMTP Port" 8 78 --title "SMTP server port" $SMTP_PORT 3>&1 1>&2 2>&3)

    exitstatus=$?
	if [ $exitstatus = 0 ]; then
		if [ ! -z $SMTP_USER ];then
			sed -i "s#\$config\['smtp_port'\]\s*= '';#\$config['smtp_port'] = '${SMTP_PORT}';#g" $WEB_ROOT/application/config/email.php
		fi
	else
		echo "User selected Cancel."

	echo "(Exit status was $exitstatus)"
	fi
}

email_config(){
    sed -i "s#\$config\['protocol'\]\s*= '';#\$config['protocol'] = 'smtp';#g" $WEB_ROOT/application/config/email.php

    ehost_config
    RET=$?
    if [ $RET -eq 0 ]; then
        euser_config
        RET=$?
        if [ $RET -eq 0 ]; then
            epass_config
        else
            exit 1
            if [ $RET -eq 0 ]; then
                eport_config
            else
                exit 1
            fi
        fi
    else
        exit 1
    fi
}
#################################################################
#                                                               #
#                       准备使用                                #
#                                                               #
#################################################################

TS_CONF=0


config_website(){

LANGUAGE=''

	URL=$(whiptail --inputbox "Your website URL.  Example: http://example.com/razor" 8 78 --title "Your website URL" $URL 3>&1 1>&2 2>&3)
	exitstatus=$?
	if [ $exitstatus = 0 ]
		then
		OPT=$(whiptail --title "Choose language" --menu "Language" 25 78 16 \
                        "1" "简体中文" \
                        "2" "英语" \
                        "3" "德语" \
                        "4" "日语" \
                        3>&1 1>&2 2>&3)

                        case "$OPT" in
                        	"1") LANGUAGE='zh_CN' ;;
      						"2") LANGUAGE='en_US' ;;
	  						"3") LANGUAGE='de_DE' ;;
	  						"4") LANGUAGE='ja_JP' ;;
        					 * ) LANGUAGE='zh_CN' ;;
                        esac
            sed -i "s#\$config\['language'\]\s*= '.*';#\$config['language']   = '${LANGUAGE}';#g" $WEB_ROOT/application/config/config.php
			sed -i "s#\$config\['base_url'\]\s*= '.*';#\$config['base_url']   = '${URL}';#g" $WEB_ROOT/application/config/config.php
		else
			echo "User selected Cancel."
	fi
}



change_mod(){

	chmod -R 755 $WEB_ROOT/application/config
	chmod -R 755 $WEB_ROOT/captcha
	chmod -R 755 $WEB_ROOT/assets/android
	chmod -R 755 $WEB_ROOT/assets/sql
}

set_task(){

	if [ -d $CRON_TASK ]; then
		cp $DIR/cron_task/razor* $CRON_TASK
	else
		mkdir -p $CRON_TASK
		cp $DIR/cron_task/razor* $CRON_TASK
	fi
	
	# 表示每个小时的第五分钟执行一次脚本
	echo "5 * * * * /var/www/cron/razor_hourly_archive.sh">>/etc/crontab

	# 表示每天的1：00执行一次脚本
	echo "0 1 * * * /var/www/cron/razor_daily_archive.sh">>/etc/crontab

	# 表示每个星期天0:30执行一次脚本
	echo "30 0 * * 0 /var/www/cron/razor_weekly_archive.sh">>/etc/crontab

	# 表示每个月第一天0:30执行一次脚本
	echo "30 0 1 * * /var/www/cron/razor_monthly_archive.sh">>/etc/crontab

	# 表示每天1:30执行一次脚本
	echo "30 1 * * * /var/www/cron/razor_laterdata_archive.sh">>/etc/crontab

	let TS_CONF=1

}



ready_start(){

	sed -i "s#\$route\['default_controller'\]\s*= ".*"#\$route['default_controller'] = "\"report/home\"";#g" $WEB_ROOT/application/config/routes.php
	sed -i "s#\$autoload\['language'\]\s*= array(.*);#\$autoload['language'] = array('allview');#g" $WEB_ROOT/application/config/autoload.php

	config_website
	change_mod

	if [ $TS_CONF = 0 ]; then
		set_task
		let TS_CONF=1
	else
		break
	fi

	
}




#################################################################
#                                                               #
#                      Main Menu                                #
#                                                               #
#################################################################

system_config(){

	FUN=$(whiptail --title "Menu" --menu "Choose an option" 25 78 16 \
		"1" "初始化数据库" \
		"2" "创建站点超级用户" \
		"3" "邮件配置" \
		"4"	"准备使用" \
		3>&1 1>&2 2>&3)

	case "$FUN" in
      "1") db_menu ;;
      "2") create_supersuer ;;
	  "3") email_config ;;
	  "4") ready_start ;;
        *) exit 1 ;;
	 esac
}

#################################################################
#                                                               #
#                     Main Function                             #
#                                                               #
#################################################################

main(){

check_service

if [ $RES -eq 0 ];then
	echo "是否准备开始安装Cobub razor.....[y/n]"
	read reply
	case $reply in
		y|Y) break ;;
		n|N) echo "Bye Bye"
			 exit 0 ;;
	esac
else
	echo "请先启动相应服务后再尝试安装...."
	read reply
	case $reply in
		* ) exit 1 ;;
	esac
fi

while true
    do
        system_config
done
}
main


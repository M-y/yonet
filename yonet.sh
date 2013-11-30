#!/bin/bash
# TODO buraya yapımcı ve lisans ekle
version='1.0'

if [ ! "`whoami`" = "root" ]
then
  echo "Please run as root."
  exit 1
fi

# Usage: checkInstalled php5
# return 0 if not installed
# return 1 if installed
checkInstalled() {
  dpkg -s $1 > /dev/null
  status=$?
  return $status
}

# Usage: aptInstall php5
aptInstall() {
  apt-get update
  apt-get install "$@" --yes
  apt-get clean
}

if ! checkInstalled dialog; then
  aptInstall dialog
fi

########
# Test #
########
testServer() {
  clear
  bash bench.sh
  read
}

settings() {
  read
}

###############
# Mail Server #
###############
mail() {
  mailInstall() {
    clear
    aptInstall ssmtp
    echo "Press enter..."
    read
  }
  
  mailConfig() {
    dialog --msgbox "Find 'Mailhub' and write your smtp server. \nYou can use gmail for example: smtp.gmail.com:587 \nWrite your 'AuthUser' and 'AuthPass'. You change any other things also. " 10 70
    nano /etc/ssmtp/ssmtp.conf
  }
  
  while true
  do
    dialog --clear --nocancel --title "Mail Server" \
    --menu "sSMTP will create /usr/sbin/sendmail. Your applications like PHP can send mail with this. You can't receive mail. Only send." 0 0 3 \
    Install "Instal sSMTP" \
    Config "Configure sSMTP" \
    Exit "Exit to install menu" 2>"${INPUT}"
    
    selected=$(<"${INPUT}")
    
    case $selected in
      Install) mailInstall;;
      Config) mailConfig;;
      Exit) clear; break;;
    esac
  done
}

##############
# Web Server #
##############
www() {
  wwwInstall() {
    clear
    aptInstall nginx php5 php5-mysql php5-sqlite php5-curl php-pear php5-gd php5-imagick php5-imap php5-mcrypt php5-xmlrpc php5-xsl php5-fpm php-apc
    
    cat >> /etc/php5/fpm/php.ini <<add
apc.enabled=1
apc.shm_size=30M
add

    cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
    sed -i "s/worker_processes .*;/worker_processes $cores;/g" /etc/nginx/nginx.conf
    sed -i "s/# server_tokens off;/server_tokens off;/g" /etc/nginx/nginx.conf
    
    sed -i "s/;emergency_restart_threshold = 0/emergency_restart_threshold = 1/g" /etc/php5/fpm/php-fpm.conf
    sed -i "s/;emergency_restart_interval = 0/emergency_restart_interval = 30/g" /etc/php5/fpm/php-fpm.conf
    
    /etc/init.d/php5-fpm restart
    /etc/init.d/nginx restart
    echo "Press enter..."
    read
  }
  
  while true
  do
    dialog --clear --nocancel --title "Web Server" \
    --menu "This will use NGINX and PHP Fast Process Manager" 0 0 2 \
    Install "Instal nginx and php" \
    Exit "Exit to install menu" 2>"${INPUT}"
    
    selected=$(<"${INPUT}")
    
    case $selected in
      Install) wwwInstall;;
      Exit) clear; break;;
    esac
  done
}

##############
# SQL Server #
##############
sql() {
  sqlInstall() {
    clear
    aptInstall mysql-server
    
    cat > /etc/mysql/my.cnf <<END
[client]
port		= 3306
socket		= /var/run/mysqld/mysqld.sock

[mysqld_safe]
socket		= /var/run/mysqld/mysqld.sock
nice		= 0

[mysqld]
user		= mysql
pid-file	= /var/run/mysqld/mysqld.pid
socket		= /var/run/mysqld/mysqld.sock
port		= 3306
basedir		= /usr
datadir		= /var/lib/mysql
tmpdir		= /tmp
lc-messages-dir	= /usr/share/mysql
skip-external-locking
bind-address		= 127.0.0.1
key_buffer = 1M
max_allowed_packet = 16M
thread_stack = 64K
thread_cache_size = 1
myisam-recover = BACKUP
max_connections = 25
table_cache = 256
query_cache_limit = 1M
query_cache_size = 16M
skip-innodb
query_cache_min_res_unit=0
tmp_table_size = 1M
max_heap_table_size = 1M
concurrent_insert = 2
sort_buffer_size = 64K
read_buffer_size = 256K
read_rnd_buffer_size = 256K
net_buffer_length = 2K
expire_logs_days = 10
max_binlog_size = 100M
[mysqldump]
quick
quote-names
[mysql]
[isamchk]
key_buffer		= 16M
!includedir /etc/mysql/conf.d/
END
    
    dialog --msgbox "Now running mysql_secure_installation. Enter your mysql root password if asked." 7 50
    mysql_secure_installation
    
    /etc/init.d/mysql restart
    echo "Press enter..."
    read
  }
  
  while true
  do
    dialog --clear --nocancel --title "SQL Server" \
    --menu "" 0 0 2 \
    Install "Instal mysql server" \
    Exit "Exit to install menu" 2>"${INPUT}"
    
    selected=$(<"${INPUT}")
    
    case $selected in
      Install) sqlInstall;;
      Exit) clear; break;;
    esac
  done
}

################
# Install Menu #
################
installServer() {
  while true
  do
    dialog --clear --nocancel --title "Install server software" \
    --menu "Enter each menu, install and configure software" 0 0 4 \
    WWW "Web server" \
    Sql "Database server" \
    Mail "Mail server" \
    Exit "Exit to main menu" 2>"${INPUT}"
    
    selected=$(<"${INPUT}")
    
    case $selected in
      WWW) www;;
      Sql) sql;;
      Mail) mail;;
      Exit) clear; break;;
    esac
  done
}

###################
# Add New Hosting #
###################
addHosting() {
  dialog --clear \
  --inputbox "User Name" 10 40 2>$OUTPUT
  respose=$?
  wwwUser=$(<$OUTPUT)
  
  if [ $respose -eq 0 ]; then
    clear
    adduser $wwwUser
    mkdir "/home/$wwwUser/public_html"
    ln -s "/home/$wwwUser/public_html" "/home/$wwwUser/www"
    chown -R $wwwUser:$wwwUser "/home/$wwwUser"
    
    dialog --clear --nocancel \
    --inputbox "Host Name (www prefix will be added automatically)" 10 40 2>$OUTPUT
    wwwHost=$(<$OUTPUT)
    cat > "/etc/nginx/sites-available/$wwwHost.conf" <<txt
server {
    server_name $wwwHost www.$wwwHost;
    root /home/$wwwUser/www/;
    index index.php;
 
        location = /favicon.ico {
                log_not_found off;
                access_log off;
        }
 
        location = /robots.txt {
                allow all;
                log_not_found off;
                access_log off;
        }
 
        location / {
                # This is cool because no php is touched for static content
                try_files \$uri \$uri/ /index.php?q=\$uri&\$args;
        }
 
        location ~ \.php\$ {
                #NOTE: You should have "cgi.fix_pathinfo = 0;" in php.ini
                include fastcgi_params;
    		fastcgi_intercept_errors on;
    		fastcgi_index index.php;
    		fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    		try_files \$uri =404;
    		fastcgi_pass unix:/var/run/php5-fpm-$wwwUser.sock;
    		error_page 404 /404page.html;
        }
 
        location ~* \.(js|css|png|jpg|jpeg|gif|ico)\$ {
                expires max;
                log_not_found off;
        }
    access_log  /var/log/nginx/$wwwHost-access.log;
    error_log  /var/log/nginx/$wwwHost-error.log;    
}
txt
  ln -s /etc/nginx/sites-available/$wwwHost.conf /etc/nginx/sites-enabled/$wwwHost.conf
    
  cat > /etc/php5/fpm/pool.d/$wwwUser.conf <<txt
[$wwwUser]
user = $wwwUser
group = $wwwUser
listen = /var/run/php5-fpm-$wwwUser.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0666
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.max_requests = 200
txt
    
  dialog --yesno "Do you want to create a database for this user?" 7 40
  if [ $? -eq 0 ]; then
    dialog --nocancel --inputbox "MySql root password" 10 40 2>$OUTPUT
    mysqlRootPass=$(<$OUTPUT)
    dialog --nocancel --inputbox "Database name" 10 40 2>$OUTPUT
    databaseName=$(<$OUTPUT)
    dialog --nocancel --inputbox "Username" 10 40 2>$OUTPUT
    username=$(<$OUTPUT)
    dialog --nocancel --inputbox "Password" 10 40 2>$OUTPUT
    password=$(<$OUTPUT)
    
    clear
    mysql -v -u root -p"$mysqlRootPass" mysql -e "CREATE DATABASE $databaseName; GRANT ALL ON  $databaseName.* TO $username@localhost IDENTIFIED BY '$password';FLUSH PRIVILEGES;"
    echo "Press enter..."
    read
    
    dialog --yesno "Do you want to import a .sql file to this database?" 7 40
    if [ $? -eq 0 ]; then
      dialog --nocancel --title "Type your location or use arrow keys and spacebar to select" --fselect / 10 50 2>$OUTPUT
      sqlFile=$(<$OUTPUT)
      clear
      mysql -u root -p"$mysqlRootPass" "$databaseName" < "$sqlFile"
      echo "Press enter..."
      read
    fi
  fi
  
  clear
  /etc/init.d/php5-fpm restart
  /etc/init.d/nginx restart
  else
    return
  fi
  
  echo "Press enter..."
  read
}

INPUT=/tmp/input.$$
OUTPUT="/tmp/output"

#############
# Main Menu #
#############
while true
do
  info="nginx "
  if ! checkInstalled nginx; then
    info+="\Z1not installed\Z0"
  else
    if [ "$(pidof nginx)" ]; then
      info+="\Z2running\Z0"
    else
      info+="\Z1not running\Z0"
    fi
  fi
  
  info+=" | php5-fpm: "
  if ! checkInstalled php5-fpm; then
    info+="\Z1not installed\Z0"
  else
    if [ "$(pidof php5-fpm)" ]; then
      info+="\Z2running\Z0"
    else
      info+="\Z1not running\Z0"
    fi
  fi
  
  info+=" | mysqld: "
  if ! checkInstalled mysql-server; then
    info+="\Z1not installed\Z0"
  else
    if [ "$(pidof mysqld)" ]; then
      info+="\Z2running\Z0"
    else
      info+="\Z1not running\Z0"
    fi
  fi
  
  info+=" | sSmtp: "
  if checkInstalled ssmtp; then
    info+="\Z2installed\Z0"
  else
    info+="\Z1not installed\Z0"
  fi
  
  dialog --begin 3 1 --colors --infobox "$info" 3 100 \
  --and-widget --begin 8 20 --keep-window --nocancel --title "Main Menu" --backtitle "Yönet $version" \
  --menu "" 0 0 5 \
  Install "Install server software" \
  Add "Create a new hosting account" \
  Test "Test network and disk IO" \
  Settings "" \
  Exit "Exit" 2>"${INPUT}"
 
  selected=$(<"${INPUT}")
  
  case $selected in
    Install) installServer;;
    Add) addHosting;;
    Test) testServer;;
    Settings) settings;;
    Exit) clear; break;;
  esac
done
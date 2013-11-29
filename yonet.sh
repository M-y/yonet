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
    Exit "Exit to main menu" 2>"${INPUT}"
    
    selected=$(<"${INPUT}")
    
    case $selected in
      Install) mailInstall;;
      Config) mailConfig;;
      Exit) clear; break;;
    esac
  done
}

###############
# Web Server #
###############
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
    
    echo "Press enter..."
    read
  }
  
  while true
  do
    dialog --clear --nocancel --title "Web Server" \
    --menu "This will use NGINX and PHP Fast Process Manager" 0 0 3 \
    Install "Instal nginx and php" \
    Exit "Exit to main menu" 2>"${INPUT}"
    
    selected=$(<"${INPUT}")
    
    case $selected in
      Install) wwwInstall;;
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
    --menu "Enter each menu, install and configure software" 0 0 3 \
    WWW "Web server" \
    Mail "Mail server" \
    Exit "Exit to main menu" 2>"${INPUT}"
    
    selected=$(<"${INPUT}")
    
    case $selected in
      WWW) www;;
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
  if [ "$(pidof nginx)" ]; then
    info+="\Z2running\Z0"
  else
    info+="\Z1not running\Z0"
  fi
  
  info+=" | php5-fpm: "
  if [ "$(pidof php5-fpm)" ]; then
    info+="\Z2running\Z0"
  else
    info+="\Z1not running\Z0"
  fi
  
  info+=" | sSmtp: "
  if checkInstalled ssmtp; then
    info+="\Z2installed\Z0"
  else
    info+="\Z1not installed\Z0"
  fi
  
  info+=" | mysqld: "
  if [ "$(pidof mysqld)" ]; then
    info+="\Z2running\Z0"
  else
    info+="\Z1not running\Z0"
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
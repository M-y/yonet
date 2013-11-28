#!/bin/bash

# if [ ! "`whoami`" = "root" ]
# then
#   echo "Please run as root."
#   exit 1
# fi

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
  apt-get install $1 --yes
}

if ! checkInstalled dialog; then
  aptInstall dialog
fi

########
# Test #
########
test() {
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
    echo "Press any key..."
    read
  }
  
  mailConfig() {
    dialog --msgbox "Find 'Mailhub' and write your smtp server. \nYou can use gmail for example: smtp.gmail.com:587 \nWrite your 'AuthUser' and 'AuthPass'. You change any other things also. " 10 70
    nano /etc/ssmtp/ssmtp.conf
  }
  
  while true
  do
    dialog --clear --nocancel --title "Mail Server" \
    --menu "sSMTP will create /usr/sbin/sendmail. Your applications like PHP can send mail with this. You can't receive mail. Only send." 0 0 4 \
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
    echo "Press any key..."
    read
  }
  
  while true
  do
    dialog --clear --nocancel --title "Web Server" \
    --menu "açıklama yaz" 0 0 4 \
    Install "Instal nginx and php" \
    Exit "Exit to main menu" 2>"${INPUT}"
    
    selected=$(<"${INPUT}")
    
    case $selected in
      Install) wwwInstall;;
      Exit) clear; break;;
    esac
  done
}

INPUT=/tmp/input.$$
OUTPUT="/tmp/output"

#############
# Main Menu #
#############
while true
do
  dialog --clear --nocancel --title "Yönet" \
  --menu "" 0 0 5 \
  WWW "Web server" \
  Mail "Mail server" \
  Test "Test network and disk IO" \
  Settings "" \
  Exit "Exit" 2>"${INPUT}"
 
  selected=$(<"${INPUT}")
  
  case $selected in
    WWW) www;;
    Test) test;;
    Mail) mail;;
    Settings) settings;;
    Exit) clear; break;;
  esac
done
Yönet
=====================
A GUI that can run on linux shell for managing web hosting environment. 

Tested on Debian 7

![Main Menu][1]

**Features:**
* Uses nginx as web server, php-fpm as PHP process manager, mysql as database server, ssmtp as send only mail server.
* Can create and delete users.
* Can automatically create config files for each user.
* Can create database for each user and import .sql file.
* Users can use sftp without having shell access.

**To install:**

    wget https://raw.github.com/M-y/yonet/master/install.sh --no-check-certificate -O - -o /dev/null|bash

**After that type this to run anytime:**

    yonet

  [1]: http://drive.google.com/uc?export=view&id=0B7_816X54Xugc1R2dGs5a0NTM2s "Main Menu"

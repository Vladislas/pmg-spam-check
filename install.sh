#!/bin/bash

echo -n "Installing depedensi "
sudo apt update -y
sudo apt install -y jq

echo -n "Create Blast,Temporary,ConfigTele Category"
pmgsh create /config/ruledb/who --name Blast
pmgsh create /config/ruledb/who --name Temporary
pmgsh create /config/ruledb/who --name ConfigTele

#### GET ID ConfigTele
ID_CONFIG_TELE=`pmgsh get /config/ruledb/who | awk -v RS='[^\n]*{|}' 'RT ~ /{/{p=RT} /ConfigTele/{ print p $0 RT }' | grep id | grep -Eo '[0-9]{1,4}'`

### Create default 100 max sending per hour and 50 max temporary
pmgsh create /config/ruledb/who/$ID_CONFIG_TELE/regex --regex "LIMIT_SENDING=100"
pmgsh create /config/ruledb/who/$ID_CONFIG_TELE/regex --regex "LIMIT_TEMPORARY=50"

echo -n "Please Input your Token Telegram: "
read -r TOKEN_TELE
pmgsh create /config/ruledb/who/$ID_CONFIG_TELE/regex --regex "TOKEN_TELEGRAM=$TOKEN_TELE"

echo -n "Please Input your Group Telegram: "
read -r GROUP_TELE
pmgsh create /config/ruledb/who/$ID_CONFIG_TELE/regex --regex "GROUP_TELEGRAM=$GROUP_TELE"

echo -n "Please Input your email to notification: "
read -r EMAIL_NOTIF
pmgsh create /config/ruledb/who/$ID_CONFIG_TELE/regex --regex "EMAIL_NOTIF=$EMAIL_NOTIF"

mkdir /opt/script
\cp spam-check.sh content.txt /opt/script/
chmod +x /opt/script/spam-check.sh
crontab -l | { cat; echo "*/15 * * * *    root    /opt/script/spam-check.sh"; } | crontab -e

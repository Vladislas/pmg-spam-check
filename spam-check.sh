#!/bin/bash
hostname=`hostname`
date=`date "+%d %B %Y %T"`
log="/var/log/spam-check.log"

### Get CONFIG Telegram from who object ConfigTele
CONFIGTELE_ID=`pmgsh get /config/ruledb/who | awk -v RS='[^\n]*{|}' 'RT ~ /{/{p=RT} /ConfigTele/{ print p $0 RT }' | grep id | grep -Eo '[0-9]{1,4}'`

#### Get TOKEN_TELEGRAM
TokenTelegram=`pmgsh get /config/ruledb/who/$CONFIGTELE_ID/objects | grep desc | grep TOKEN_TELEGRAM | awk '{print $3}' | grep -E -o "\b[0-9]+:[A-Za-z0-9_]+\b"`

#### Get GROUP_TELEGRAM
GroupID=`pmgsh get /config/ruledb/who/$CONFIGTELE_ID/objects | grep desc | grep GROUP_TELEGRAM | awk '{print $3}' | grep -E -o "(-)\b([0-9]+)"`
#GroupID='-1001622540214'

### get number limit sending per hour
limit=`pmgsh get /config/ruledb/who/$CONFIGTELE_ID/objects | grep regex | grep LIMIT_SENDING | awk '{print $3}' | grep -Eo "\b[0-9]+\b"`

### get number limit temporary sending per hour
limit_temporary=`pmgsh get /config/ruledb/who/$CONFIGTELE_ID/objects | grep regex | grep LIMIT_TEMPORARY | awk '{print $3}' | grep -Eo "\b[0-9]+\b"`

### get Content for Mail notification
CONTENT=`cat content.txt`

### get Admin Notif for mail notification
EMAIL_NOTIF=`pmgsh get /config/ruledb/who/$CONFIGTELE_ID/objects | grep regex | grep EMAIL_NOTIF | awk '{print $3}' | grep -E -o "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b"`

## ID BLAST CATEGORY
id_whiteblast=`pmgsh get /config/ruledb/who/ | awk -v RS='[^\n]*{|}' 'RT ~ /{/{p=RT} /Blast/{ print p $0 RT }' | grep id | grep -Eo '[0-9]{1,4}'`

## ID BLACKLIST CATEGORY
id_blacklist=`pmgsh get /config/ruledb/who/ | awk -v RS='[^\n]*{|}' 'RT ~ /{/{p=RT} /Blacklist/{ print p $0 RT }' | grep id | grep -Eo '[0-9]{1,4}'`

## ID TEMPORARY CATEGORY
id_temporary=`pmgsh get /config/ruledb/who/ | awk -v RS='[^\n]*{|}' 'RT ~ /{/{p=RT} /Temporary/{ print p $0 RT }' | grep id | grep -Eo '[0-9]{1,4}'`

### show email and count sent
sendersent=`pmgsh get /statistics/sender -endtime $(date +%s) -starttime $(($(date +%s) - 3600))  | jq -r '.[] | [.count, .sender] | @tsv|gsub("\t"; ";")'| head -n 15`

for i in $sendersent; do
  count=$(echo $i | cut -d ";" -f 1)
  sender=$(echo $i | cut -d ";" -f 2)
  CEKSENDER=`echo $sender | grep "="`
  if [ "$CEKSENDER" != "" ]; then
    sender=`echo $sender | awk -F"=" '{print $NF}'`
  fi

  ## SHOW BLAST CATEGORY
  userblast=`pmgsh get /config/ruledb/who/$id_whiteblast/objects | grep \"$sender\" | grep descr | awk '{print $3}' | grep -E -o "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b"` 

  ## SHOW TEMPORARY CATEGORY
  usertemp=`pmgsh get /config/ruledb/who/$id_temporary/objects | grep \"$sender\" | grep descr | awk '{print $3}' | grep -E -o "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b"` 

  ## SHOW BLACKLIST CATEGORY
  userblacklist=`pmgsh get /config/ruledb/who/$id_blacklist/objects | grep \"$sender\" | grep descr | awk '{print $3}' | grep -E -o "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b"` 

  if [[ $count -ge $limit ]]; then
    if [ "$sender" == "$userblast" ]; then
      echo $date $sender " sudah diwhitelist pada kategori BLAST, $count email terkirim dalam waktu 1 jam terakhir." >> $log
    else
      if [ "$sender" == "$userblacklist" ]; then
        echo $date $sender " sudah terblacklist pada kategori BLACKLIST." >> $log
      else
        if [ "$CEKSENDER" != "" ]; then
          pmgsh create /config/ruledb/who/$id_blacklist/regex --regex "*.$sender"
        else
          pmgsh create /config/ruledb/who/$id_blacklist/email --email $sender
        fi
        echo $date $sender " terblokir secara otomatis, $count email terkirim dalam waktu 1 jam terakhir pada server $hostname." >> $log
        MESSAGE=`tail -n 1 $log`
        curl -s -X POST https://api.telegram.org/bot$TokenTelegram/sendMessage -d text="$MESSAGE" -d chat_id=$GroupID
        sleep 5
        echo -e $CONTENT | mailx -s "user "$sender" Terindikasi mengirim spam" -r $EMAIL_NOTIF -c $EMAIL_NOTIF $sender
      fi
    fi
  fi
done

unlisted=`pmgsh get /config/ruledb/who/$id_temporary/objects | jq -r '.[] | [.id, .descr] | @tsv|gsub("\t"; ";")'`

for i in $unlisted; do
  id=$(echo $i | cut -d ";" -f 1)
  sender=$(echo $i | cut -d ";" -f 2)
  grepsender=`pmgsh get /statistics/sender -endtime $(date +%s) -starttime $(($(date +%s) - 3600))  | jq -r '.[] | [.count, .sender] | @tsv|gsub("\t"; ";")' | grep $sender` 
  count=$(echo $grepsender | cut -d ";" -f 1)
  if [[ $count -le $limit_temporary ]]; then
    pmgsh delete /config/ruledb/who/$id_temporary/objects/$id
    ruleblacklist=`pmgsh get /config/ruledb/who/$id_blacklist/objects | jq -r '.[] | [.id, .descr] | @tsv|gsub("\t"; ";")' | grep $sender`
    idbl=$(echo $ruleblacklist | cut -d ";" -f 1)
    pmgsh delete /config/ruledb/who/$id_blacklist/objects/$idbl	
    if [ $count -ge 0 ]; then
      echo $date $sender " sudah dihapus dari BLACKLIST, $count email terkirim dalam waktu 1 jam terakhir." >> $log
    else
      echo $date $sender " sudah dihapus dari BLACKLIST, tidak ada email terkirim dalam waktu 1 jam terakhir." >> $log
    fi
    MESSAGE=`tail -n 1 $log`
    curl -s -X POST https://api.telegram.org/bot$TokenTelegram/sendMessage -d text="$MESSAGE" -d chat_id=$GroupID
  fi
done

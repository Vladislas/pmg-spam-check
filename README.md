## pmg-spam-check
Proxmox Mail Gateway limit sending bash script

This script limit sending mail for proxmox mail gateway. best practice limit 100 mail per user account.
This script integrated with pmg-api v2 and sending notification to group telegram and email notification to sender and admin email


## INSTALLATION

Just run ./install.sh 

and edit content.txt to notification sender and admin mail server about indicated spam

This installation script will be automatic create Category Blast(exception), Temporary(queue delisting), ConfigTele(configuration parameter) and create cronjob every 15 minutes


# HOW SCRIPT WORK

- This script will cek statistics sender. if sender sending over 100 mail in 1 hour will be blacklist.
- if want to delisting please add email to Temporary category at who object. it will be check sender if not sending email or has a queue and not to remove from blacklist if queue or sender still sending lot of mail


# Configuration parameter
Configuration parameter in ConfigTele Category at who object.


  <code>EMAIL_NOTIF=</code>
  
  <code>GROUP_TELEGRAM=</code>
  
  <code>TOKEN_TELEGRAM=</code>
  
  <code>LIMIT_SENDING=</code>
  
  <code>LIMIT_TEMPORARY=</code>


# License
See LICENSE.md.

# Credit
Thanks to @gurnadi

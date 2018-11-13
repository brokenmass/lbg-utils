#!/usr/bin/env sh
set -ex
 
# this script is based on mcafee official documentation https://kc.mcafee.com/corporate/index?page=content&id=KB70253&pmv=print
# plus some additional steps needed for correct version verification by 'host checker'
# ensure the script has been run as sudo
if [ $EUID != 0 ]; then
  sudo "$0" "$@"
  exit $?
fi
 
TIMESTAMP=$(date +%s)
DATS_LOCATION=/usr/local/McAfee/AntiMalware/dats
DAT_VERSION=$(curl -s ftp://ftp.mcafee.com/commonupdater/oem.ini | awk -F"=" '$1 ~ /AVV-ZIP/{secFound=1} secFound==1 && $1=="DATVersion"{print $2; secFound=0}')
DAT_VERSION=${DAT_VERSION%$'\r'}
DAT_FILE="avvdat-$DAT_VERSION.zip"
 
echo "Downloading ftp://ftp.mcafee.com/commonupdater/$DAT_FILE"
curl "ftp://ftp.mcafee.com/commonupdater/$DAT_FILE" -o /tmp/$DAT_FILE
 
echo "Backing up current configuration"
cp /Library/Preferences/com.mcafee.ssm.antimalware.plist /tmp/com.mcafee.ssm.antimalware.plist.$TIMESTAMP
 
echo "Stopping FMP"
/usr/local/McAfee/fmp/bin/fmp stop
 
echo "Extracting DAT file"
unzip /tmp/$DAT_FILE -d $DATS_LOCATION/$DAT_VERSION
 
echo "Setting correct filesystem flags"
chmod 755 $DATS_LOCATION/$DAT_VERSION
chown root:wheel $DATS_LOCATION/$DAT_VERSION
chmod 644 $DATS_LOCATION/$DAT_VERSION/*.*
chown root:Virex $DATS_LOCATION/$DAT_VERSION/*.*
 
echo "Updating McAfee plist"
sudo defaults write /Library/Preferences/com.mcafee.ssm.antimalware.plist Update_DATVersion -string "$DAT_VERSION.0000"
sudo defaults write /Library/Preferences/com.mcafee.ssm.antimalware.plist Update_Last_Update_Time -string $TIMESTAMP
sudo defaults write /Library/Preferences/com.mcafee.ssm.antimalware.plist Update_DAT_Time -string $TIMESTAMP
 
echo "Restarting FMP"
/usr/local/McAfee/fmp/bin/fmp start
 
echo "Reloading McAffee"
sudo launchctl unload /Library/LaunchDaemons/com.mcafee.ssm.ScanManager.plist
sudo launchctl load /Library/LaunchDaemons/com.mcafee.ssm.ScanManager.plist
sudo launchctl unload /Library/LaunchDaemons/com.mcafee.ssm.ScanFactory.plist
sudo launchctl load /Library/LaunchDaemons/com.mcafee.ssm.ScanFactory.plist
 
echo "Done"

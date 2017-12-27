#!/bin/bash
 
SSHUser=adminUser
 
_SSHPassIsThere(){
   local RC=0
   which sshpass > /dev/null 2>&1 || local RC=1
   return $RC
}
 
_InstallSSHPass(){
   local RC=0
   apt-get install -y sshpass || local RC=$?
   return $RC
}
 
_NetworkScan(){
   local NetworkMask=$1
   {
      nmap -n -sn $NetworkMask -oG - |  tr -s '(|)| ' ':' | \
      while read HostStatus
      do
         local HostIP=$( echo $HostStatus | cut -d\: -f2 )
         local HostStatus=$( echo $HostStatus | cut -d\: -f4 )
         echo "$HostIP $HostStatus"
      done 
   } | grep -vi "^[A-Z]"
}
 
_SOScan(){
   local SO=Unknown
   local IPAddress=$1
   local tmpFile=$( mktemp -p /tmp )
   nmap -n -O -T4 -p 3389,135,139,445,7654 $IPAddress > $tmpFile
   if  grep --quiet --extended-regexp '^(3389|135|139).*open' $tmpFile; then
      local SO=Windows
   elif grep --quiet --extended-regexp '^(7654).*open' $tmpFile; then
      local SO=Linux
   fi
   [ -f $tmpFile ] && rm -rf $tmpFile > /dev/null 2>&1
   echo $SO
}
 
_SOScanB(){
   local RC=1
   local IPAddr=$1
   local SO=Unknown
   if timeout 3 nc -z  -w2 $IPAddr 7654 > /dev/null 2>&1; then
      local SO=Linux
      local RC=0
   elif timeout 3 nc -z  -w2 $IPAddr 3389 > /dev/null 2>&1; then
      local SO=Windows
      local RC=0
   fi
   echo $SO
   return $RC
}
 
_IsThereUser(){
   {
   local IPAddress=$1
   local User=$2
   local SSHOption1="ConnectTimeout=3"
   local SSHOption2="StrictHostKeyChecking=no"
   local Result="N"
   local Result=$( \
      sshpass -p "$Pass1" ssh -l $SSHUser $IPAddress -o "$SSHOption1" -o "$SSHOption2" -p 7654 -n "id $User > /dev/null 2>&1 && echo Y" || \
      sshpass -p "$Pass2" ssh -l $SSHUser $IPAddress -o "$SSHOption1" -o "$SSHOption2" -p 7654 -n "id $User > /dev/null 2>&1 && echo Y" 
   ) 
 
   if [ "${Result}x" == "Yx" ]; then
      local Answer=1
      local RC=0
   elif [ "${Result}x" == "Nx" ]; then
      local Answer=0
      local RC=1
   fi
   } 2>/dev/null 
   echo $Answer
   return $RC
}
 
_SSHPassAssuring(){
   if ! _SSHPassIsThere;then
      _InstallSSHPass
   fi
}
 
_SSHCommand(){
   local RC=0
   local IPAddress="$1"
   local Command="$2"
   {
      sshpass -p "$Pass1" ssh -l $SSHUser $IPAddress -o "$SSHOption1" -o "$SSHOption2" -p 7654 -n "$Command" || \
      sshpass -p "$Pass2" ssh -l $SSHUser $IPAddress -o "$SSHOption1" -o "$SSHOption2" -p 7654 -n "$Command" 
   } 2>/dev/null
}
 
_GetHostname(){
   _SSHCommand $1 "hostname"
}
 
_GetDistro(){
   local OutPut=$( _SSHCommand "$1" 'python -c "import platform; print platform.dist()"' )
   echo $OutPut | sed "s/[(),]//g"|tr -d "'"
}
 
_GetArch(){
    local OutPut=$( _SSHCommand "$1" "python -c 'import platform; print platform.architecture()'" )
    echo $OutPut | sed "s/[(),]//g"|tr -d "'"
}
 
_GetPlatform(){
    #_SSHCommand "$1" 'test -x `which dmidecode` && dmidecode -s system-product-name || echo Unknown'
    _SSHCommand "$1" 'dmidecode -s system-product-name'
}
 
 
#------------- INICIO DO SCRIPT -----------------#
 
 
## Two pass possibilities 
read -r -s -p "Enter $SSHUser password1: " Pass1 
read -r -s -p "Enter $SSHUser password2: " Pass2 
 
Lista=$1
_NetworkScan 10.81.10.0/24 | while read IPStatus 
#seq -f "10.81.10.%g" 254 | while read IPStatus 
do
   IPAdrr=$(  echo $IPStatus | cut -d\  -f1 )
   Status=$(  echo $IPStatus | cut -d\  -f2 )
   OSHost=$(  _SOScanB $IPAdrr )
   if [ "$OSHost" == "Linux" ]; then
      CITUser=$( _IsThereUser $IPAdrr centralit )
      TecnosolveUser=$( _IsThereUser $IPAdrr tecnosolve )
      Hostname=$( _GetHostname $IPAdrr )
      DistroVer=$( _GetDistro $IPAdrr )
      Arch=$( _GetArch $IPAdrr )
      Platform=$( _GetPlatform $IPAdrr )
   fi
 
   echo ",$IPAdrr,$Status,$OSHost,$CITUser,$TecnosolveUser,$Hostname,$DistroVer,$Arch"
   unset IPAdrr Status OSHost CITUser TecnosolveUser Hostname DistroVer Arch Platform
done

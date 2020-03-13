$srcVC="192.168.16.50"
$trgVC="192.168.16.52"
$vDSConfigPath="$env:USERPROFILE\Desktop\”

$srcAdm = "administrator@vsphere.local"
$trgAdm = "administrator@vsphere.local"
$srcPwd = "1qaz!QAZ"
$trgPwd = "1qaz!QAZ"
$ESXRoot = "root"
$ESXPwd  = "5tgb%TGB" 

$vDScount = 0

function migrate{

#Source vCenter Server

Write-Host ("Running tasks on source VC") -ForegroundColor Cyan
Write-Host ("--------------------------") -ForegroundColor Cyan

$ESXHosts = Get-VMHost -Server $srcVC
$vDSwitches = Get-VDSwitch -Server $srcVC

#Export vDS
 Write-Host ("Exporting distributed switches configuration")
 
 if ($vDSwitches){
   ForEach ($vDS in $vDSwitches) 
    {
     $vDScount++
     Export-VDSwitch -VDSwitch $vDS -Destination ($vDSConfigPath + "vDS" + $vDScount + ".zip") -Force | out-null} 
 }
  else {Write-Host "No distributed switches found"}
 
#Disconnect and remove hosts from inventory
 ForEach ($ESXi in $ESXHosts){
   Write-Host ("Disconnecting " + $ESXi.name) 
   Set-VMHost -vmhost $ESXi -Server $srcVC -State "Disconnect" -Confirm:$false | Out-Null
   Write-Host ("Removing "  + $ESXi.name + "`n") 
   Remove-VMHost $ESXi.name -Server $srcVC -Confirm:$false | Out-Null
 }	
 
Write-Host ("`nDisconnecting from source VC") -ForegroundColor Red
$srcVCconn | Disconnect-VIServer -Confirm:$false

Write-Host ("`n`nRunning tasks on target VC") -ForegroundColor Cyan
Write-Host ("--------------------------") -ForegroundColor Cyan

#Target vCenter Server
if (!(Get-Datacenter)) {New-Datacenter -Name "DC" -location (Get-folder -NoRecursion) | Out-Null}
 
 Foreach ($ESXi in $ESXHosts) {
  Write-Host ("Adding " + $ESXi.name) 
  Add-VMHost $ESXi.name -Location (Get-Datacenter)[0] -User $ESXRoot -Password $ESXPwd -Force -Confirm:$false | Out-Null
 } 

 for ($c=1; $c -le $vDScount; $c++){
  Write-Host ("`nImporting distributed switches ... ") 
  New-VDSwitch -BackupPath ($vDSConfigPath + "vDS" + $c + ".zip") -Location (get-Datacenter)[0] -KeepIdentifiers | Out-Null
  }
 
 Write-Host ("Disconnecting from target VC") -ForegroundColor Red
 $trgVCconn | Disconnect-VIServer -Confirm:$false
}

# Script entry point

if ($DefaultVIServers -ne $null) {Disconnect-VIServer * -Confirm:$false -Force | Out-Null}

$srcVCconn = Connect-VIServer $srcVC -user $srcAdm -Password $srcPwd -Force
$trgVCconn = Connect-VIServer $trgVC -user $trgAdm -Password $trgPwd -Force


if ($srcVCconn.IsConnected -and $trgVCconn.IsConnected) 
{
   clear
   Write-host ("Connected to " + $srcVCconn.name + " (" + $srvVCConn.ExtensionData.Content.About.FullName  + ")") 
   Write-host ("Connected to " + $trgVCconn.name + " (" + $trgVCConn.ExtensionData.Content.About.FullName  + ")`n")
   
   migrate
 }
   else 
      {
	   Write-Host "Source or target VC is offline" 
	   exit
	   }
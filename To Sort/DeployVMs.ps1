
#Define vCenter Server vars
 $VIServer  = "192.168.16.50"
 $VIUser    = "administrator@vsphere.local"
 $VIPass    = "1qaz!QAZ" 

#Connect to vCenter Server
 Write-Host ("`nConnecting to vCenter Server " + $ViServer)
 Connect-VIServer $VIServer -User $VIUser -Password $VIPass -InformationAction SilentlyContinue | out-null
 Write-Host ("-------------------------------------------------------------------------------------------")
 
#Compute and storage resources 
 $ESXHost   = (Get-VMHost)[0]
 $DataStore = Get-Datastore -Name "iSCSI_LUNc"
 $Location  = Get-Folder "Windows 7 Example"
 
#GOSC and Template info 
 $GOSCName  = "Windows7-Join-To-AD"
 $TempName  = "Windows7-Template"
 $TempToUse = Get-Template -Name $TempName
 
#Get list of Computer names and IP address from file
 $CSVFile   = ipcsv -Path "C:\ADComputers.csv"
 
#IP Settings included in the GOSC
 $IPMask    = "255.255.240.0"
 $IPGateway = "192.168.16.1"
 $DNS       = "192.168.16.71"

#Iterate over the values read from file (hash table)
 foreach ($VM in $CSVFile){
 
 #Read the computer name and IP address
  $CompName = $VM.VMName
  $IPAddr = $VM.IPAddress

 #Amend the computer name and IP address in the GOSC
  Write-Host ("GOSC      : Adding " + "IP Address" + $IPAddr + " and Computer Name " + $CompName)
  Get-OSCustomizationSpec $GOSCName | Set-OSCustomizationSpec -NamingPrefix $CompName -NamingScheme fixed | Out-Null
  Get-OSCustomizationNicMapping -OSCustomizationSpec $GOSCName | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $IPAddr -SubnetMask $IPMask -DefaultGateway $IPGateway -Dns $DNS | Out-Null

 #Create a new VM based on the set template and GOSC
  Write-Host ("Deploying : " + $CompName + " from template " + $TempName + "`n")
  New-VM -Name $CompName -Template $TempToUse -OSCustomizationSpec (Get-OSCustomizationSpec -Name $GOSCName) -Location $Location -VMHost $ESXHost -Datastore $Datastore | Out-Null
 }

Write-Host ("-------------------------------------------------------------------------------------------")

#Power up the VMs. This will allow the settings to be applied.
  foreach ($VM in $CSVFile){
   Write-Host("Power Up  : " + $VM.VMName)
   Start-VM -VM $VM.VMName
  }
   
Write-Host ("-------------------------------------------------------------------------------------------")


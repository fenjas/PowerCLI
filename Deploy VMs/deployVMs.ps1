#Define vCenter Server vars
 $VIServer = "192.168.32.239"
 $VIUser = "administrator"
 $VIPass = "5tgb%TGB"
 $datastoreCluster = "DatastoreCluster"
  
 $IPMask = "255.255.240.0"
 $IPGateway = "192.168.32.1"
 $DNS = "8.8.8.8"
 
 $CSVFile = ipcsv -Path "newvms.csv"
 #-------------------------------------------------------------------------------
 
 #Connect to vCenter Server
 Write-Host ("`nConnecting to vCenter Server " + $ViServer)
 Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
 Connect-VIServer $VIServer -User $VIUser -Password $VIPass | out-null
 Write-Host ("-------------------------------------------------------------------------------------------")

 #Compute and storage resources
 $ESXHost = (Get-VMHost)[0].Name
 $Location = Get-Folder "New"

 #Iterate over the values read from file (hash table)
 foreach ($VM in $CSVFile)
 {
  #Read the computer name and IP address
   $CompName = $VM.VMName
   $IPAddr = $VM.IPAddress
   $TempToUse  = Get-Template -Name $VM.Template
   $GOSCName = $VM.GOSCName
   
  #Amend the computer name and IP address in the GOSC
   Write-Host ("GOSC : Setting IP Address " + $IPAddr + " and computer name " + $CompName)
   Get-OSCustomizationSpec $GOSCName | Set-OSCustomizationSpec -NamingPrefix $CompName -NamingScheme fixed | Out-Null
   Get-OSCustomizationNicMapping -OSCustomizationSpec $GOSCName | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $IPAddr -SubnetMask $IPMask -DefaultGateway $IPGateway -Dns $DNS | Out-Null
  #Create a new VM based on the set template and GOSC
   Write-Host ("Deploying : " + $CompName + " from template " + $VM.Template + "`n")
   New-VM -Name $CompName -Template $TempToUse -OSCustomizationSpec (Get-OSCustomizationSpec -Name $GOSCName) -Location $Location -VMHost $ESXHost -DiskStorageFormat Thin -Datastore (Get-DatastoreCluster -Name $datastoreCluster | Get-Datastore | Get-Random) | Out-Null
}
Write-Host ("-------------------------------------------------------------------------------------------")

#Power up the VMs. This will allow the settings to be applied.
 foreach ($VM in $CSVFile){
  Write-Host("Power Up : " + $VM.VMName)
  Start-VM -VM $VM.VMName
 }
Write-Host ("-------------------------------------------------------------------------------------------")
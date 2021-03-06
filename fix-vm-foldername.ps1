# A PowerCLI script that makes use of Storage VMotion to realign the files and folder names on a DataStore with the
# name assigned to the virtual machine.
# Jason Fenech (Sep 16)
#----------------------------------------------------------[Libraries]-----------------------------------------------
# Uncomment the 2 lines below if running script using PowerShell (not PowerCLI)
#
# Import-Module VMware.VimAutomation.Core -ErrorAction:SilentlyContinue
# Import-Module VMware.VimAutomation.Storage -ErrorAction:SilentlyContinue
#----------------------------------------------------------[Declarations]--------------------------------------------
#Change the following as required
####################################################################################
$vCenter="192.168.16.70"
$DSDest="iSCSI_LUNB"
$DSFreeSpace=0
$user="xxxxxxxx"
$pass="xxxxxxxx"
$auto=$true
$logFile="c:\test\renameVM_folders.txt"
####################################################################################

clear

#Connect to vCenter Server
 try{
       Disconnect-VIServer -Confirm:$false -ErrorAction:SilentlyContinue
       Connect-VIServer -Server $vCenter -User $user -Password $pass -ErrorAction:Stop | Out-Null
 }
 catch{
       Write-Host "Failed to connect to vCenter Server $vCenter"
       exit #Exit script on error 
 } 

#Get virtual machine view 
 $vms = get-view -viewtype VirtualMachine

#Loop
 $vms | % {
	   
		   #Datastore Free Space
           $DSFreeSpace=(Get-Datastore -Name $DSDest).FreeSpaceGB
		   $DSFreeSpace=[Math]::Round($DSFreeSpace,3)
		   		   
		   #Retrienve VM Name, size, DS folder and current DS
		   $DSpath = $($_.summary.Config.VmPathName.Split("]").split("/").trimstart())[1]
		   $VMDS   = $_.config.DatastoreUrl.name
		   $VMName = $_.Name
		   $VMSize = ($_.Summary.Storage.Committed) / (1024*1024*1024);
		   $VMSize = [Math]::Round($VMSize,3)
		 
	       if (!$DSpath.equals($VMName))
		    {
             $_.Name | out-file -Append -FilePath $logFile
			 
			 Write-Host "-------------------------------------------------------------------------------------------------" -ForegroundColor DarkCyan
			 
			 Write-Host ("VM Name : " + $VMName);
			 Write-Host ("VM Size : " + $VMSize + " GB");
			 Write-Host ("DS Path : " + $_.summary.Config.VmPathName) -ForegroundColor DarkYellow;
			 
			 if (($VMSize -lt $DSFreeSpace) -and !($VMDS.Equals($DSDest)))
			  {
			   Write-Host ("Status  : Migration possible (DS:" + $DSFreeSpace + " GB, VM:" + $VMSize + " GB)") -ForegroundColor Green
			  
			   #Let user choose whether to migrate or not
			   $ans=read-host "`nType YES to migrate"
			   #$ans="YES"
			   
			   if ($ans.ToUpper() -eq "YES") 
			    { 
			       $DSOrig = $_.config.DatastoreUrl.name
				   Write-Host "Moving vm to DS $DSDest ..."
				   try
				    {
				      Move-VM -VM $VMName -Datastore $DSDest | Out-Null
				      Write-Host "Moving vm back to DS $DSOrig ..."
				      Move-VM -VM $VMName -Datastore $DSOrig | Out-Null
				     
					  #Re-retrieve vm's DS path 
					  $DSpath = (get-vm -Name $VMName).extensiondata.summary.config.VmPathName
					  Write-Host "New DS path is $DSpath" -ForegroundColor DarkYellow;
					 }
				   catch 
				    {
					  write-host "Unexpected migration error!"
					  exit
				    }
			    } 
				 else
			      {Write-Host "Skipping migrating!" -ForegroundColor DarkYellow}
			    } 
				
				if ($VMSize -ge $DSFreeSpace)		
				   {Write-Host ("Warning : Not enough free space on DS to migrate vm!") -ForegroundColor Red}
				   
		   		if ($VMDS.Equals($DSDest))		
				   {Write-Host ("Warning : Cannot migrate vm to same datastore!") -ForegroundColor Red}
				   
			 Write-Host "-------------------------------------------------------------------------------------------------`n" -ForegroundColor DarkCyan
          }
}
write-host "Done migrating!"
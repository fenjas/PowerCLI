   
# A PowerCLI script that recursively traverses the root of datastore $DSName looking for vmx files and copying them 
# to a local folder. Each vmx file is then parsed to extract the vm name as shown in vSphere client. The vm name is
# then compared to its parent folder to determine if there's a name mistmatch. The script also checks if the vm is
# registered in the inventory. The output is written both to console and a comma delimited file.
# Jason Fenech (Sep 16)
#--------------------------------------------------------------------------------------------------------------------
# Uncomment the 2 lines below if running script using PowerShell (not PowerCLI)
#
# Import-Module VMware.VimAutomation.Core -ErrorAction:SilentlyContinue
# Import-Module VMware.VimAutomation.Storage -ErrorAction:SilentlyContinue

#--------------------------------------------------------------------------------------------------------------------
#Change the following as required
#--------------------------------------------------------------------------------------------------------------------
 $vCenter="192.168.32.239"
 $user="administrator"
 $pass="5tgb%TGB"
 $DSName="iSCSI_AutoNas3_LUN_0"
 $VMXFolder = "c:\vmx"
 $horLine = "--------------------------------------------------------------------------------------------------------------------------------------------------------------"
 
#Pre-defined column widths for write-host -f statements
 $col1="{0,-3}"
 $col2="{1,-5}"
 $col3="{2,-30}"
 $col4="{3,-30}"
 $col5="{4,-40}"
 $col6="{5,-6}"
 $col7="{6,-4}"
 $col8="{7,-16}"
 $colSetup="$col1 $col2 $col3 $col4 $col5 $col6 $col7 $col8"
#--------------------------------------------------------------------------------------------------------------------
 
clear
 
#Connect to vCenter Server
 try
 {
 	   Write-Host "Connecting to vCenter Server " + $vCenter
	   Disconnect-VIServer -force -Confirm:$false -ErrorAction SilentlyContinue      
       Connect-VIServer -Server $vCenter -User $user -Password $pass -Force -ErrorAction Stop | Out-Null
 }
 catch
 {
       Write-Host "Failed to connect to vCenter Server $vCenter"
       exit #Exit script on error 
 } 
#--------------------------------------------------------------------------------------------------------------------
 clear 
  
 #Get list of datastores
 foreach ($ds in Get-Datastore)
 {
 
 #Name is case-sensitive hence the need to retrieve the name even though specified by user
  $DSName = $ds.name
  $DSView = Get-View $ds.id
  
  #Log File
  if (-not (Test-Path -LiteralPath $VMXFolder)) {New-Item -Path $VMXFolder -ItemType Directory | Out-Null}
  $VMXLogFile = $VMXFolder + "\vms-on-" + $DSName + "-" + (get-date -Format ddMMyy-hhmmss) + ".csv"
  
 #Fetch a list of folders and files present on the datastore
  $searchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
  $DSBrowser = get-view $DSView.browser
  $RootPath  = ("[" + $DSView.summary.Name +"]")
  $searchRes = $DSBrowser.SearchDatastoreSubFolders($RootPath, $searchSpec)
 
 #Object Counter
  $s=0; 

 #Get list of vm names residing on datastore. We'll use this to compare to the vm list created after parsing the vmx files
  $vms=(get-vm * -Datastore $ds).Name
  $templates=(get-template * -Datastore $ds).Name 
 
 #Write header to log file
 ("#,Type,VM_Name,VMX_Filename,VM_Folder,Name_Match?,Is_VM_Registered,ESXi_Host") | Out-File -FilePath  $VMXLogFile -Append
 
 #Write table header row to console
 Write-Host "Enumerating datastore $DSName for VMs ...`n"
 Write-Host $horLine
 Write-Host ($colSetup -f "#", "Type", "VM Name", "VMX Filename", "Folder Path [$DSName]","Match?" , "Reg?", "ESXi Host") -ForegroundColor white
 Write-Host $horLine
   
 #Recursively check every folder under the DS' root for vmx files.
 foreach ($folder in $searchRes)
 {
	$type       = ""        #Template or vm?
	$VMXFile    = ""        #Stores vmx/vmtx filename
	$registered = "No"      #Is the vm registered?
	$nameMatch  = "No"      #Does the folder name match that of the vm?
	$col        = "Green"   #Default console color
	
	$DCName     = $ds.Datacenter.Name
	$VMFolder   = (($folder.FolderPath.Split("]").trimstart())[1]).trimend('/')	
	$VMXFile    = ($folder.file | where {$_.Path -like "*.vmx" -or $_.Path -like "*.vmtx"}).Path
    $VMPath     = ($DSName + "/" + $VMFolder)
	$fileToCopy = ("vmstore:/" + $DCName + "/" + $VMPath  + "/" + $VMXFile)
	
	#Assuming vmx file exists ...
	if ($VMXFile -ne $null)
	 {
	  $s++
	  
	  #Extract VM name from the vmx file name. We will compare this to the value returned by displayName
	  if ($VMXFile.contains(".vmx")) {$prevVMName = $VMXFile.TrimEnd(".vmx"); $type="VM"} #VM
	  elseif ($VMXFile.contains(".vmtx")){$prevVMName = $VMXFile.TrimEnd(".vmtx"); $type="Tmpl"} #Template
	  	  
	
	  Try{
		#Copy vmx file to a local folder
		Copy-DatastoreItem $fileToCopy $vmxFolder -ErrorAction SilentlyContinue
      
	    #Extract the current vm name from the VMX file as well as the host name	
		$owningVM = ((get-content -path ($VMXFolder + "/" + $VMXfile) -ErrorAction SilentlyContinue | 
		Where-Object {$_ -match "displayName"}).split(""""))[1]
		  
		if ( $type.equals("VM")){$vmHost = (Get-VM -Name $owningVM -ErrorAction SilentlyContinue).vmhost}
		 else {$vmHost = (Get-template -Name $owningVM -ErrorAction SilentlyContinue).vmhost}
		  
		  if ($vmHost -eq $null) {$vmHost="n/a"}
		 }
	  Catch 
	     {
	      $owningVM="Error retrieving ..."
		  $vmHost="Error ..."
		 }	  
	 
	  #If the vm specified in the VMX file is found in the list of vms or templates, mark it as registered
	  if (($vms -contains $owningVM) -or ($templates -contains $owningVM)) {$registered = "Yes"} else {$col="Red"}
		  
	  #Check folder name. Set $nameMatch to true if no conflict found
	  if ($prevVMName.equals($owningVM) -and $prevVMName.equals($VMFolder)){$nameMatch="Yes"} else {$col="Red"};
	  
	  #Highlight unregistered vms in cyan
	  if ($registered.Equals("No")){$col="Cyan"}
	  
	  #Update Logfile
	  if ($owningVM.Contains(",")) {$owningVM = '"'+$owningVM+'"'}
	  ($s.ToString() + "," + $type + "," + $owningVM + "," + $VMXFile + "," + $VMFolder + "," + $nameMatch + "," + $registered + "," + $vmHost) | Out-File -FilePath  $VMXLogFile -Append 
	  
	  #Truncate strings if they do not fit the respective coloumn width
	  if ($owningVM.Length -ge 30) {$owningVM = (($owningVM)[0..26] -join "") + "..."}
	  if ($VMXfile.Length -ge 30) {$VMXfile = (($VMXfile)[0..26] -join "") + "..."}
	  if ($VMFolder.Length -ge 40) {$VMFolder = (($VMFolder)[0..36] -join "") + "..."}
	  	  
	  #Write to console
	  write-host ($colSetup -f $s.ToString() , $type , $owningVM , $VMXFile, $VMFolder, $nameMatch, $registered, $vmHost) -ForegroundColor $col
	 } 
 }
 Write-Host $horLine
 Write-Host
 }
 
 
 Disconnect-VIServer -force -Confirm:$false -ErrorAction SilentlyContinue  
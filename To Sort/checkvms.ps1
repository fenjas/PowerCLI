
# find-unregistered-vm-folders.ps1 - A PowerCLI script that finds and lists folders associated with unregistered vms
# or templates on a datastore. The script also lists those datastore folders whose names do not match those of the
# owning vm or template. The script generates a comma delimited log file in addition to writing to console.
# by Jason Fenech (14/09/16)
#--------------------------------------------------------------------------------------------------------------------
# Un-comment the 2 lines below if running script using PowerShell (not PowerCLI)
#
# Import-Module VMware.VimAutomation.Core -ErrorAction SilentlyContinue
# Import-Module VMware.VimAutomation.Storage -ErrorAction SilentlyContinue
 
#--------------------------------------------------------------------------------------------------------------------
#Change as required
#--------------------------------------------------------------------------------------------------------------------
 $vCenter="192.168.17.113"
 $user="jason.fenech"
 $pass="philipIsFit .. ha ha bla sens"
 $DSName="16.120 Secondary Datastore"
 $VMXFolder = "C:\vmx"
 $VMXLogFile = $VMXFolder + "\vms-on-" + $DSName + "-" + (get-date -Format ddMMyy-hhmmss) + ".csv"
 $horLine = "----------------------------------------------------------------------------------------------------------------------------------------"
 
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
 
#Connect to vCenter Server
 try{
 Disconnect-VIServer -force -Confirm:$false -ErrorAction SilentlyContinue 
 Connect-VIServer -Server $vCenter -User $user -Password $pass -ErrorAction Stop | Out-Null
 }
 catch{
 Write-Host "Failed to connect to vCenter Server $vCenter"
 exit #Exit script on error 
 } 
#--------------------------------------------------------------------------------------------------------------------
 clear 
 
 #If datastore name is specified incorrectly by the user, terminate
  try {$DSObj = Get-Datastore -name $DSName -ErrorAction Stop} 
   catch {Write-Host "Invalid datastore name" ; exit}
 
 #Get datastore view using id
  $DSView = Get-View $DSObj.id
 
 #Name is case-sensitive hence the need to retrieve the name even though specified by user
  $DSName = $DSObj.name
 
 #Fetch a list of folders and files present on the datastore
  $searchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
  $DSBrowser = get-view $DSView.browser
  $RootPath = ("[" + $DSView.summary.Name +"]")
  $searchRes = $DSBrowser.SearchDatastoreSubFolders($RootPath, $searchSpec)
 
 #Object Counter
  $s=0; 
 
 #Get a list of vms and templates residing on the datastore
  $vms=(get-vm * -Datastore $DSObj).Name
  $templates=(get-template * -Datastore $DSObj).Name 
 
 #Write header to log file
 ("#,Type,VM_Name,VMX_Filename,VM_Folder,Name_Match?,Is_VM_Registered,ESXi_Host") | 
   Out-File -FilePath $VMXLogFile -Append
 
 #Write table header row to console
  Write-Host "Browsing datastore $DSObj ...`n"
  Write-Host $horLine
  Write-Host ($colSetup -f "#", "Type", "VM Name", "VMX Filename", "Folder Path [$DSName]","Match?" , "Reg?", "ESXi Host")  -ForegroundColor white
  Write-Host $horLine
 
 #Recursively check every folder under the DS' root for vmx files.
  foreach ($folder in $searchRes)
  {
    $type = $null      #Template or vm?
    $VMXFile = $null   #Stores vmx/vmtx filename
    $registered = "No" #Is the vm registered?
    $nameMatch = "No"  #Does the folder name match that of the vm?
    $col = "Green"     #Default console color
 
    $DCName = $DSObj.Datacenter.Name
    $VMFolder = (($folder.FolderPath.Split("]").trimstart())[1]).trimend('/') 
    $VMXFile = ($folder.file | where {$_.Path -like "*.vmx" -or $_.Path -like "*.vmtx"}).Path  #vmtx is for templates
    $VMPath = ($DSName + "/" + $VMFolder)
    $fileToCopy = ("vmstore:/" + $DCName + "/" + $VMPath + "/" + $VMXFile)
 
 #Assuming vmx file exists ...
  if ($VMXFile -ne $null)
   {
    $s++
 
   #Extract VM name from the vmx file name. We will compare this to the value returned by displayName
    if ($VMXFile.contains(".vmx")){$prevVMName = $VMXFile.TrimEnd(".vmx"); $type="VM"} #VM
     elseif ($VMXFile.contains(".vmtx")){$prevVMName = $VMXFile.TrimEnd(".vmtx"); $type="Tmpl"} #Template
 
   #Copy vmx file to a local folder
    copy-DatastoreItem $fileToCopy $vmxFolder -ErrorAction SilentlyContinue
 
   #Extract the current vm name from the VMX file as well as the host name
    Try
    {
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
   ($s.ToString() + "," + $type + "," + $owningVM + "," + $VMXFile + "," + $VMFolder + "," + $nameMatch + "," + $registered + "," + $vmHost) | 
    Out-File -FilePath $VMXLogFile -Append 
 
 #Truncate strings if they do not fit the respective coloumn width
  if ($owningVM.Length -ge 30) {$owningVM = (($owningVM)[0..26] -join "") + "..."}
  if ($VMXfile.Length -ge 30) {$VMXfile = (($VMXfile)[0..26] -join "") + "..."}
  if ($VMFolder.Length -ge 40) {$VMFolder = (($VMFolder)[0..36] -join "") + "..."}
 
 #Write to console
  write-host ($colSetup -f $s.ToString() , $type , $owningVM , $VMXFile, $VMFolder, $nameMatch, $registered, $vmHost) -ForegroundColor $col
   } 
  }
 
 Write-Host $horLine
 Disconnect-VIServer -force -Confirm:$false -ErrorAction SilentlyContinue 
 
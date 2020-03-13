 
connect-viserver -server 192.168.32.239 -user administrator -password 5tgb%TGB
 
$Cluster = 'Cluster'
$Datastore = 'iSCSI_AutoNas3_LUN_2'
$VMFolder = 'New'
$ESXHost = Get-Cluster $Cluster | Get-VMHost | select -First 1
 
foreach($Datastore in $Datastore) {
# Searches for .VMX Files in datastore variable
$ds = Get-Datastore -Name $Datastore | %{Get-View $_.Id}
$SearchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
$SearchSpec.matchpattern = '*.vmx';
$dsBrowser = Get-View $ds.browser
$DatastorePath = '[' + $ds.Summary.Name + ']';
 
# Find all .VMX file paths in Datastore variable and filters out .snapshot
$SearchResult = $dsBrowser.SearchDatastoreSubFolders($DatastorePath, $SearchSpec) | where {$_.FolderPath -notmatch '.snapshot'} | %{$_.FolderPath + ($_.File | select Path).Path}
 
# Register all .VMX files with vCenter
foreach($VMXFile in $SearchResult) {
New-VM -VMFilePath $VMXFile -VMHost $ESXHost -Location $VMFolder -RunAsync
 }
}
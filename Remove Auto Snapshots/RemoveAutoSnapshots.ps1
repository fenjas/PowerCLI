#J.Fenech Mar 19
Set-ExecutionPolicy Unrestricted -Force
Import-Module VMware.VimAutomation.Core

Try
{
	Write-Output "Connecting to vCenter Server 192.168.32.239"
	$conn = connect-viserver 192.168.32.239 -User administrator -Password *********
	if (!$conn.IsConnected) 
	{
	 Write-Output "Failed to connect! Exiting"
	 Break
	}else {Write-Output "Connected!"}
	Write-Output ""
}
Catch
{
  Write-Output "Something went wrong while connecting to vCenter"
  Break
}

foreach ($vm in (get-vm))
{
 if ($vm.ExtensionData.Snapshot -ne $null)
  {
	#Search for snapshots named automation or Automation
 	$snapShotList = get-snapshot -name 'Automation' -VM $vm -ErrorAction SilentlyContinue
	if ($snapShotList -eq '') {$snapShotList = get-snapshot -name 'automation' -VM $vm -ErrorAction SilentlyContinue}

	if ($snapShotList -ne '' -and $snapShotList -ne $null) 
	{
		Write-Output ("Found " + $snapShotList.Length + " snapshots for VM " + $vm.Name)
		
		if ($snapShotList.Length -gt 1) {$snapShotToRevertTo = $snapShotList[0]} else {$snapShotToRevertTo = $snapShotList}
		if ($vm.PowerState -eq 'PoweredOn') 
		{
			Write-Output ('Powering off ' + $vm.Name)
			stop-vm -VM $vm -confirm:$false -RunAsync:$false | out-null
		}

		Write-Output ('Reverting to snapshot ' + $snapShotToRevertTo.Name)
		set-vm -vm $vm -Snapshot $snapShotToRevertTo -Confirm:$false -RunAsync:$false | out-null

		write-Output ('Deleting all snapshots for VM ' + $vm.Name)

		foreach ($snapshot in $snapShotList) {Remove-Snapshot -Snapshot $snapshot -confirm:$false}
	}
  } 
   else {write-output ('No snapshots found for VM ' + $vm.Name)}
	 Write-Output ""
}

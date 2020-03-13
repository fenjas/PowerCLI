Try
{
connect-viserver 192.168.32.239 -Credential  (Import-Clixml 'vcenterCreds.xml')
write-host
}
Catch
{
  Break
}


foreach ($vm in (get-vm))
{
 if ($vm.ExtensionData.Snapshot -ne $null)
 {
 		$snap = get-snapshot -name 'Automation' -VM $vm -ErrorAction SilentlyContinue

		if ($snap -ne $null -and $snap.name.ToLower().Contains('automation')) 
		{
			if ($vm.PowerState -eq 'PoweredOn') 
			{
				write-host ('Powering off ' + $vm)
				stop-vm -VM $vm -confirm:$false -RunAsync:$false | out-null
			}
			
			write-host 'Reverting to snaphot ... '
			set-vm -vm $vm.Name -Snapshot $snap -Confirm:$false -RunAsync:$false | out-null
			
			write-host 'Deleting all snapshots ... '
			remove-snapshot -Snapshot (Get-Snapshot -VM $vm -Name automation) -Confirm:$false -RunAsync:$false | out-null
		}
 } 
   else {write-host ('No snaphots found for VM ' + $vm)}
}



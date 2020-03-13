#Jason (09-02-2018)

$vhdxPath1 = 'C:\VMS\auto001\Virtual Hard Disks\auto001.vhdx'
$vhdxPath2 = 'C:\VMS\auto002\Virtual Hard Disks\auto002.vhdx'

$autovm1= get-vm -name auto001
$autovm2= get-vm -name auto002
	

		Remove-VMHardDiskDrive -vmname $autovm1.VMName -ControllerType IDE -ControllerNumber 0 -ControllerLocation 0
		Remove-Item $vhdxPath1
		new-vhd -path $vhdxPath1 -sizebytes 128MB -fixed
		Add-VMHardDiskDrive -VMName $autovm1.VMName -ControllerType IDE -ControllerNumber 0 -ControllerLocation 0 -Path $vhdxPath1 

		Remove-VMHardDiskDrive -vmname $autovm2.VMName -ControllerType IDE -ControllerNumber 0 -ControllerLocation 0
		Remove-Item $vhdxPath2
		new-vhd -path $vhdxPath2 -sizebytes 4096MB -fixed
		Add-VMHardDiskDrive -VMName $autovm2.VMName -ControllerType IDE -ControllerNumber 0 -ControllerLocation 0 -Path $vhdxPath2 

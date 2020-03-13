function Enable-PowerCLI
{
<#
.SYNOPSIS
  Load PowerCLI modules and PSSnapins
.DESCRIPTION
  This function will load all requested PowerCLI
  modules and PSSnapins.
  The function will, depending on the installed PowerCLI version,
  determine what needs to be loaded.
.NOTES
  Author:  Luc Dekens
.PARAMETER Cloud
  Switch to indicate if the Cloud related cmdlets shall be loaded
.PARAMETER InitScript
  The PowerCLI PSSnapin have associated initialisation scripts.
  This switch will indicate if that script needs to be executed or not.
.EXAMPLE
  PS> Enable-PowerCLI
.EXAMPLE
  PS> Enable-PowerCLI -Cloud
#>
 
  [CmdletBinding()]
  param(
    [Switch]$Cloud,
    [Switch]$InitScript
  )
 
  $PcliPssnapin = @{
    'VMware.VimAutomation.License' = @(2548067)
    'VMware.DeployAutomation' =@(2548067,3056836,3205540,3737840)
    'VMware.ImageBuilder' = @(2548067,3056836,3205540,3737840)
  }
 
  $PcliModule = @{
    'VMware.VimAutomation.Core' = @(2548067,3056836,3205540,3737840)
    'VMware.VimAutomation.Vds' = @(2548067,3056836,3205540,3737840)
    'VMware.VimAutomation.Cloud' = @(2548067,3056836,3205540,3737840)
    'VMware.VimAutomation.PCloud' = @(2548067,3056836,3205540,3737840)
    'VMware.VimAutomation.Cis.Core' = @(2548067,3056836,3205540,3737840)
    'VMware.VimAutomation.Storage' = @(2548067,3056836,3205540,3737840)
    'VMware.VimAutomation.HA' = @(2548067,3056836,3205540,3737840)
    'VMware.VimAutomation.vROps' = @(3056836,3205540,3737840)
    'VMware.VumAutomation' = @(3056836,3205540,3737840)
    'VMware.VimAutomation.License' = @(3056836,3205540,3737840)
  }
 
  # 32- or 64-bit process
  $procArch = (Get-Process -Id $pid).StartInfo.EnvironmentVariables["PROCESSOR_ARCHITECTURE"]
  if($procArch -eq 'x86'){
    $regPath = 'HKLM:\Software\VMware, Inc.\VMware vSphere PowerCLI'
  }
  else{
    $regPath = 'HKLM:\Software\WOW6432Node\VMware, Inc.\VMware vSphere PowerCLI'
  }
   
  # Check if PowerCLI (regular or Tenant) is installed
  if(!(Test-Path -Path $regPath))
  {
    $regPath = $regPath.Replace('VMware vSphere PowerCLI','VMware vSphere PowerCLI for Tenants')
    if(!(Test-Path -Path $regPath))
    {
        Throw 'Can not find a PowerCLI installation!'       
    }
  }
   
  # Get build
  $buildKey = 'InstalledBuild'
  Try{
    $pcliBuild = Get-ItemProperty -Path $regPath -Name $buildKey |
        Select -ExpandProperty $buildKey -ErrorAction Stop
  }
  Catch{
    Throw "PowerCLI doesn't seem to be installed on this system!"
  }
 
  # Get installation path
  $installPathKey = 'InstallPath'
  Try{
    $pcliInstallPath = Get-ItemProperty -Path $regPath -Name $installPathKey |
        Select -ExpandProperty $installPathKey -ErrorAction Stop
  }
  Catch{
    Throw "PowerCLI doesn't seem to be installed on this system!"
  }
 
  # Load modules
  if($pcliBuild -ge 2548067)
  {
    $loadedModule = Get-Module -Name VMware* -ErrorAction SilentlyContinue | %{$_.Name}
    if($loadedModule -and $pcliBuild -ge 3737840)
    {
      $loadedModule = $loadedModule | where{$_ -notmatch 'Common$|SDK$'}
    }
   
    $targetModule = $PcliModule.GetEnumerator() | where{$_.Value -contains $pcliBuild} | %{$_.Key}
    $targetModule = $targetModule | where{$loadedModule -notcontains $_}
    if(!$Cloud)
    {
      $targetModule = $targetModule | where{$_ -notmatch 'Cloud'}
    }
    if($targetModule)
    {
      $targetModule | where{$loadedModule -notcontains $_.Name} | %{
        Import-Module -Name $_ -Verbose:$false
      }
    }
  }
   
  # Load PSSnapin
  $loadedSnap = Get-PSSnapin -Name VMware* -ErrorAction SilentlyContinue | %{$_.Name}
  if($pcliBuild -ge 3737840)
  {
    $loadedSnap = $loadedSnap | where{$_ -notmatch 'Core$'}
  }
 
  $targetSnap = $PcliPssnapin.GetEnumerator() | where{$_.Value -contains $pcliBuild} | %{$_.Key}
  $targetSnap = $targetSnap | where{$loadedSnap -notcontains $_}
  if(!$Cloud)
  {
    $targetSnap = $targetSnap | where{$_ -notmatch 'Cloud'}
  }
  if($targetSnap)
  {
    $targetSnap | where{$loadedSnap -notcontains $_} | %{
      Add-PSSnapin -Name $_ -Verbose:$false
 
      # Run initialisation script
      if($InitScript)
      {
        $filePath = "{0}Scripts\Initialize-{1}.ps1" -f $pcliInstallPath,$_.ToString().Replace(".", "_")
        if (Test-Path $filePath) {
          & $filePath
        }
      }
    }
  }
}

Enable-PowerCLI

$pclihelp = {
$browser = 'chrome.exe'
$pclisites = 'https://communities.vmware.com/community/vmtn/automationtools/powercli/content?filterID=contentstatus[published]~objecttype~objecttype[thread]',
'https://www.vmware.com/support/developer/PowerCLI/PowerCLI63R1/html/index.html',
'http://pubs.vmware.com/vsphere-60/topic/com.vmware.wssdk.apiref.doc/right-pane.html',
'http://blogs.vmware.com/PowerCLI',
'http://lucd.info'
Start-Process $browser $pclisites
}

Register-EditorCommand  `
-SuppressOutput `
-Name "PowerCLI.HelpSites" `
-DisplayName "PowerCLI Help Sites" `
-ScriptBlock $pclihelp

$pclicmdhelp = {
param([Microsoft.PowerShell.EditorServices.Extensions.EditorContext]$context)
$cmdlet = $context.CurrentFile.GetText($context.SelectedRange)
$browser = 'chrome.exe'
$cmdhelp = "https://www.vmware.com/support/developer/PowerCLI/PowerCLI63R1/html/$($cmdlet).html"  
Start-Process $browser $cmdhelp  
}

Register-EditorCommand `
-SuppressOutput `
-Name "PowerCLI.HelpCmdlet" `
-DisplayName "PowerCLI Cmdlet Help" `
-ScriptBlock $pclicmdhelp

$pscountcmdlet = {
  param([Microsoft.PowerShell.EditorServices.Extensions.EditorContext]$context)  
  
  $cmdArr = @()
  $varArr = @()
  foreach($token in $context.CurrentFile.Tokens){
    switch($token.GetType().Name){
      'StringLiteralToken'{
        if($token.TokenFlags -eq 'CommandName'){
          $cmdArr += $token.Value
        }
      }
      'VariableToken'{
        $varArr += $token.Name
      }
    }
  }
  $cmdArr = $cmdArr | Sort-Object -Unique
  $varArr = $varArr | Sort-Object -Unique
  Write-Output "You used $($cmdArr.Count) different cmdlets"
  Write-Output "`t$($cmdArr -join '|')"
  Write-Output "You used $($varArr.Count) different variables"
  Write-Output "`t$($varArr -join '|')"
}


Register-EditorCommand `
-Name "PowerShell.CountCmdletVar" `
-DisplayName "Count Cmdlets/Variables" `
-ScriptBlock $pscountcmdlet

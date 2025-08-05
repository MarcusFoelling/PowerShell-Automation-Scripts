<#
  .SYNOPSIS
     Generates a report about Virtual Machine Disks.
  .DESCRIPTION
     Usefull to get awareness of all VMDKs.
  .NOTES
     Author: Marcus Andreas Fölling @ October 2018
  .PARAMETER Server
     One or more vCenter Server (Array).
  .PARAMETER Path
     Path and file name for CSV Export.
  .EXAMPLE
     get-vmdiskreport

     Description
     -----------
     Generates a report with default values.
   .EXAMPLE
     get-vmdiskreport -Server @('dc1-vc-001','dc2-vc-501')

     Description
     -----------
     Which vCenter(s) to connect (parameter for Connect-VIServer).
#>

param(
    [Parameter(Mandatory=$false, ValueFromPipeline=$false,
    HelpMessage = 'One or more vCenter Server (Array).')]
    [String[]] $Server = @('dc1-vc-001'),
    [Parameter(Mandatory=$false, ValueFromPipeline=$false,
    HelpMessage = 'Path and file name for CSV Export.')]
    [String] $Path = 'd:\reports\prod\vm_inventory_disks.csv'
)

# Vars
$AllVMDKs  = @(New-Object -TypeName PSObject)

# Main
Start-Transcript -Path "$($MyInvocation.MyCommand.Path.trim('.ps1')).log" -IncludeInvocationHeader
If(-not (Get-Module | Where-Object{$_.Name -eq 'VMware.VimAutomation.Core'}) ) { Import-Module 'VMware.VimAutomation.Core' -ErrorAction SilentlyContinue}
If(-not (Get-PSSnapin | Where-Object{$_.Name -eq 'VMware.VimAutomation.Core'}) ) { Add-PSSnapin 'VMware.VimAutomation.Core' -ErrorAction SilentlyContinue}
Set-PowerCLIConfiguration -Confirm:$false -Scope Session -ProxyPolicy NoProxy -InvalidCertificateAction Ignore
$VCServers = Connect-VIServer -Server $Server -Force
ForEach($Datacenter in Get-Datacenter | Sort-Object) {
  foreach($Cluster in $Datacenter | Get-Cluster | Sort-Object) {
    foreach($VM in Get-View -SearchRoot $Cluster.Id -ViewType 'VirtualMachine' -Filter @{'Name' = 'l.*ora.*'} -Property Name,Config.Hardware.Device -ErrorAction SilentlyContinue) {
     ForEach($VirtualDisk in $VM.Config.Hardware.Device | Where-Object{$_ -is [VMware.Vim.VirtualDisk]}) {
      $VMDK = $VirtualDisk | Select-Object @{Name='DateTime'; Expression={Get-Date -Format 'yyyy-MM-dd HH:mm'}},
      @{Name='Datacenter'; Expression={$Datacenter.Name}}, 
      @{N='Cluster'; E={$Cluster.Name}}, 
      @{N='VM'; E={$VM.Name}}, 
      @{N='Disk'; E={$VirtualDisk.DeviceInfo.Label}}, 
      @{N='SCSI_ID'; E={"$($VirtualDisk.ControllerKey):$($VirtualDisk.UnitNumber)"}}, 
      @{N='CapacityGB'; E={[math]::round($VirtualDisk.CapacityInBytes/1GB, 0)}}, 
      @{N='Persistence'; E={$VirtualDisk.Backing.DiskMode}}, 
      @{N='SerialNumber'; E={$VirtualDisk.Backing.Uuid.Replace('-','')}}, 
      @{N='Filename'; E={$VirtualDisk.Backing.FileName}}
      $AllVMDKs += $VMDK
     }
    }
  }
}

$AllVMDKs = $AllVMDKs | Sort-Object VM, Name
$AllVMDKs = $AllVMDKs | ConvertTo-Csv -NoTypeInformation -Delimiter ';'
# $AllVMDKs = $AllVMDKs -Replace '"', ''    # we can change the delimiter if needed
$AllVMDKs| Out-File -Encoding 'UTF8' -FilePath $Path  # change the encoding if needed

# Remove-Item $CSVFile
Disconnect-VIServer -Server $VCServers -Force -Confirm:$false
Stop-Transcript

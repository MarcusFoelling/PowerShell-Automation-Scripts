<#
   .SYNOPSIS
     Create a vCenter Scheduled Task for VM Snapshot Creation.
   .DESCRIPTION
     Useful to automatically create a bunch of scheduled tasks for a group of virtual machines.
   .NOTES
     Author: Marcus Andreas Fölling @ October 2020
     Version 0.00.01
   .PARAMETER VM
     a Virtual Machine Object (get-vm)
   .EXAMPLE
     # Load this script into your current session:
     . './vmware/vcenter/new-scheduledsnapshot.ps1'
     
     # Use the function with pipelining, default parameters will be used. You might adjust the default parameters in your own copy of the script:
     Get-VM abc* | New-ScheduledSnapshot 
   .EXAMPLE
     # Use the function with pipelining and parameters:
     get-vm abx* | New-ScheduledSnapshot -TextForDescription 'Meaningfull Description' -MailReceipents 'firstname.lastname@domain.tld,team@domain.tld' -RunAt (get-date '24.12.2020 18:00')

#>
function New-ScheduledSnapshot{
    param(
         [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
         [ValidateNotNullOrEmpty()]
         [VMware.VimAutomation.Types.VirtualMachine] $VM,   # check for SRM, Multi Server Support, Multi VMs
         [Parameter(Mandatory = $true)]
         [ValidateNotNullOrEmpty()]
         [datetime] $RunAt,                                  # maybe overload with string
         [Parameter(Mandatory = $true)]
         [ValidateNotNullOrEmpty()]
         [string] $TextForDescription, # check length
         [Parameter(Mandatory = $true)]
         [ValidateNotNullOrEmpty()]
         [string] $MailReceipents,     # check for valid address, comma seperated 
         [bool] $IncludeMemory = $false,
         [bool] $Quiesce = $false
         )

$Name = 'Snapshot of {0} - {1}' -f $VM.Name, $RunAt
$Description = '{0:dd.MM.yyyy} - {1} - {2}' -f (get-date), $(whoami.exe), $TextForDescription

$ScheduledTaskManager = Get-View (Get-View ServiceInstance).Content.ScheduledTaskManager
$ScheduledTaskSpec = New-Object VMware.Vim.ScheduledTaskSpec
$ScheduledTaskSpec.Name = $Name 
$ScheduledTaskSpec.Description = $Description
$ScheduledTaskSpec.Enabled = $True
$ScheduledTaskSpec.Notification = $MailReceipents

$ScheduledTaskSpec.Scheduler = New-Object VMware.Vim.OnceTaskScheduler
$ScheduledTaskSpec.Scheduler.runat = $RunAt.ToUniversalTime()    # has to be in UTC
$ScheduledTaskSpec.Action = New-Object VMware.Vim.MethodAction
$ScheduledTaskSpec.Action.Name = 'CreateSnapshot_Task'
$MethodActionArguments = @()
@($Name, $Description, $IncludeMemory, $Quiesce) | foreach{
   $MethodActionArgument = New-Object VMware.Vim.MethodActionArgument
   $MethodActionArgument.Value = $_
   $MethodActionArguments += $MethodActionArgument
}
$ScheduledTaskSpec.Action.Argument = $MethodActionArguments

$ScheduledTaskManager.CreateObjectScheduledTask($VM.ExtensionData.MoRef, $ScheduledTaskSpec)
}

# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave –Scope Process

# Script to check if a Windows machine is pending reboot
$remoteCommand =
@'
$pendingRebootTests = @(
    @{
        Name = 'RebootPending'
        Test = { Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing'  -Name 'RebootPending' -ErrorAction Ignore }
        TestType = 'ValueExists'
    }
    @{
        Name = 'RebootRequired'
        Test = { Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update'  -Name 'RebootRequired' -ErrorAction Ignore }
        TestType = 'ValueExists'
    }
    @{
        Name = 'PendingFileRenameOperations'
        Test = { Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction Ignore }
        TestType = 'NonNullValue'
    }
)

$resultHash = @{}

foreach ($test in $pendingRebootTests) {
    $result = Invoke-Command -ScriptBlock $test.Test
    if ($test.TestType -eq 'ValueExists' -and $result) {
        $resultHash.Add($test.Name, $true)
    } elseif ($test.TestType -eq 'NonNullValue' -and $result -and $result.($test.Name)) {
        $resultHash.Add($test.Name, $true)
    } else {
        $resultHash.Add($test.NAme, $false)
    }
}

if($resultHash.ContainsValue($true)) {
    return $true
}else {
    return $false
}
'@

$Conn = Get-AutomationConnection -Name 'AzureRunAsConnection'
Connect-AzAccount -ServicePrincipal -Tenant $Conn.TenantID `
-ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint | Out-Null

#Create a local file based on the script defined as $remoteCommand
Set-Content -Path .\CheckVMPendingReboot.ps1 -Value $remoteCommand

$subs = Get-AzSubscription | sort Name
$trueResults = {}.Invoke()
$falseResults = {}.Invoke()
foreach($sub in $subs)
{
  Select-AzSubscription $sub #| Out-Null
  $VMList = Get-AzVM
  foreach($VM in $VMList)
  {
    if($VM.StorageProfile.OSDisk.OsType.ToString().Contains("Windows")) {
        $result = Invoke-AzVMRunCommand -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName -CommandId 'RunPowerShellScript' -ScriptPath .\CheckVMPendingReboot.ps1
        if($result.Value[0].Message -eq $true) {
            $outputObject = [pscustomobject]@{ VMName = $VM.Name; "Pending reboot" = "Yes" }
            $trueResults.Add($outputObject)
        }else {
            $outputObject = [pscustomobject]@{ VMName = $VM.Name; "Pending reboot" = "No" }
            $falseResults.Add($outputObject)
        }
    }
  }
}
$trueResults
$falseResults

#Remove the local file after we have finished using it
Remove-Item .\CheckVMPendingReboot.ps1
$vcenter = Read-Host "FQDN of vCenter Server:"
Connect-VIServer $vcenter
$srchost = Read-Host "FQDN of the ESX server you want to place in maintenance mode:"
$srchost = Get-VMHost -name $srchost
$cluster = Get-Cluster -Name $srchost.Parent
$clusterpartners = Get-VMHost -Location $cluster | Where-Object {$_.Name -ne $srchost.Name -and $_.State -eq "Connected"}
$vmguests = Get-VM -Location $cluster
$MovedVMs = New-Object System.Collections.ArrayList
Download-Patch -RunAsync
foreach ($vmguest in $vmguests) {
    if($vmguest.VMHost -like $srchost.Name){
        $dsthost = $clusterpartners | Get-Random
        Move-VM -VM $vmguest -Destination $dsthost -Confirm:$false -RunAsync:$true
        $MovedVMs.Add($vmguest)
    }
}
Set-VMHost -VMHost $srchost -State "Maintenance"

Scan-Inventory -Entity $srchost
$baselines = Get-PatchBaseline -Entity $srchost -Inherit
Stage-Patch -Entity $srchost
Remediate-Inventory -Entity $srchost -Baseline $baselines -ClusterDisableHighAvailability $true -HostFailureAction Retry -HostNumberOfRetries 2 -RunAsync -Confirm:$false
Set-VMHost -VMHost $srchost -State "Connected"
foreach ($MovedVM in $MovedVMs){
    Move-VM -VM $MovedVM -Destination $srchost -Confirm:$false -RunAsync:$true
}
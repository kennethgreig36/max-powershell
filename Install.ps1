#setup
# needed for this script and db
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
Set-Location $scriptPath

. .\LoadConfig.ps1
. .\DefaultOpsSettings.ps1
. .\Util\MaxOpsApiClient.ps1
# internal
$storage_name = $cust + "maxstore" -replace "-", ""
$vault_name = $cust + "-vault"
$rg_name = $data.Config.resourceGroup

Function global:GetVMCPUAvg{
    #(Get-AzMetricDefinition -ResourceId $vmInfo.Id).name
    $cpu = Get-AzMetric -ResourceId $vmInfo.Id -TimeGrain 00:01:00 -DetailedOutput -MetricNames "Percentage CPU"

    foreach($sample in $cpu.Data.Average){
        $cpuTotal += $sample
    }
    
    return $cpuAvg = $cpuTotal / $cpu.Data.Count
}

if ($region -eq "" -or $region -eq $null)
{
    $region = "UK South"
}

if ($data.Config.resourceGroup -eq "" -or $data.Config.resourceGroup -eq $null)
{
    $rg_name = $cust + "_rg"
}

Write-Host "============================="
Write-Host " Max Server Builder 1.0"
Write-Host "============================="
Write-Host "Customer       : " $cust
Write-Host "Resource Group : " $rg_name
Write-Host "Region         : " $region
Write-Host "Subscription   : " $subscription_name
Write-Host "============================="
if ($data.config.database.createDatabase -eq $true)
{
    Write-Host "Will Create database $($data.config.database.name)"
}
Write-Host "Will deploy" $data.deployment.servers.length " Server(s)"
$n = 1
ForEach($srv in $data.deployment.servers)
{
    $srvname = ConfigGetVmName $srv.type $cust
    Write-Host "Server " $n "  - " $srvname
    Write-Host " - Apps: "
    ForEach($app in $srv.apps)
    {
        Write-Host "  -  " $app.name $app.version
    }
    $n++
}

#Add to ops db

# Install the networking etc

.\InstallBase.ps1 -Subscription $subscription_name -ResourceGroup $rg_name -Region $region -StorageName $storage_name -VaultName $vault_name

#.\ProvisionOps.ps1 -CustomerName -VaultName -StorageName -VmName -TelName 

if ($data.config.database.createDatabase -eq $true)
{
    Write-Host "Deploying a new database $($data.config.database.name) to $($data.config.database.serverName)"
    $servername = $data.config.database.serverName
    $templateDatabase = "max-template-2.19.0"
    $body = @{
        'databaseName' = $cust_dbName
        'serverName' = $servername
    } | ConvertTo-Json
    Invoke-WebRequest -UseBasicParsing http://10.0.20.110/database -ContentType "application/json" -Method POST -Body $body
    $body = @{
        'templateName' = $templateDatabase
        'databaseName' = $cust_dbName
        'serverName' = $servername
    } | ConvertTo-Json
    Invoke-WebRequest -UseBasicParsing http://10.0.20.110/restoremaxdb -ContentType "application/json" -Method POST -Body $body
    $body = @{
        'databaseName' = $cust_dbName
        'serverName' = $servername
    } | ConvertTo-Json
    $response = Invoke-WebRequest -UseBasicParsing http://10.0.20.110/createmaxusers -ContentType "application/json" -Method POST -Body $body
    $resJson = ConvertFrom-Json $([string]::new($response.Content)) 
    $resJson
    $secretvalue = ConvertTo-SecureString $resJson.passMax -AsPlainText -Force
    Set-AzKeyVaultSecret -VaultName $vault_name -Name 'DatabasePassword' -SecretValue $secretvalue
    Set-AzKeyVaultSecret -VaultName $vault_name -Name 'DatabasePassword-reporting' -SecretValue $secretvalue
    $secretvalue = ConvertTo-SecureString $resJson.passRep -AsPlainText -Force
    Set-AzKeyVaultSecret -VaultName $vault_name -Name 'DatabasePassword-rep' -SecretValue $secretvalue
    $database_password = $resJson.passMax
    $database_user = $resJson.userMax

    # Get the internal address and port for this connection
    # we get this from Max Api
    $mdb = GetDatabaseByName -DatabaseName $servername

    $database_address = $mdb.privateIp
    $database_address_ext = $mdb.dns
    $database_port = $mdb.port
}

# Generate the master config and store in blob container for the customer. Each server will use this
.\GenerateMasterConfig.ps1 -DatabaseAddress $database_address -DatabasePort $database_port -DatabaseName $cust_dbName -DatabaseUser $database_user -DatabasePassword $database_password -EncryptPassword $true -OutputFile "master.config"
.\UploadFileToBlob.ps1 -ResourceGroupName $rg_name -StorageAccountName $storage_name -Container "config" -FileName "master.config"

$dataCreatorAlreadyRan = $false
$conf_tel_name = $data.config.telephonyServer
$conf_reg_name = $data.config.telephonyRegistrar
$conf_vm_name = ""

# Go through each server and install it
ForEach($srv in $data.Deployment.servers)
{
    $vm_name = ConfigGetVmName $srv.type $cust
    # install each server
    .\InstallNetwork.ps1     -CustomerPrefix $cust -Region $region -VmName $vm_name -CustomerDns $cust -SubscriptionName $subscription_name -CustomerResourceGroupName $rg_name -CreateVnet $srv.vnet.create -VnetName $srv.vnet.vnetName -VNetResourceGroup $srv.vnet.vnetResourceGroup -VnetSubnet $srv.vnet.vnetSubnet -Firewall $srv.firewall
    .\WindowsServerBuild.ps1 -CustomerPrefix $cust -Region $region -VmName $vm_name -RegName $conf_reg_name -MachineType $srv.machineType -Drives $srv.drives -Dns $srv.dns -DeploymentName $srv.type -UpdateBlockNumber $updateBlock -ServerSKU $srv.osVersion -CustomerResourceGroupName $rg_name -VaultName $vault_name
    .\InstallVmExtensions.ps1 -Region $region -VmName $vm_name -CustomerResourceGroupName $rg_name
    .\CreateVmBuildSettings.ps1 -CustomerPrefix $cust -CustomerDomain "$cust.maxcontact.com" -ServerRoles $srv.systemRoles -DatabaseUser $database_user -DatabasePassword $database_password -DatabaseAddress $database_address -DatabasePort $database_port -SettingsFileName "serversettings.json" -Apps $srv.apps -Drives $srv.drives
    #Before deploying apps onto VM check that it's not busy e.g. configuring Windows updates or the deployment may fail

    $vmInfo = Get-AzVM -ResourceGroupName $cust'_rg' -Name $vm_name
    if($vmInfo -eq $null){
        Write-Warning 'VM not created yet, waiting a minute...'
        Start-Sleep -s 60
        while ($vmInfo -eq $null){
            try{
                $vmInfo = Get-AzVM -ResourceGroupName $cust'_rg' -Name $vm_name -ErrorAction Stop
            }
            catch{
                Write-Warning 'VM not created yet, waiting a minute...'
                Start-Sleep -s 60
            }
        }
    }

    $cpuAvg = GetVMCPUAvg

    if($cpuAvg -gt 20){
        Write-Host 'VM still busy, waiting a minute...'
        Start-Sleep -s 60
        while($cpuAvg -gt 20){
            Write-Host 'VM still busy, waiting a minute...'
            Start-Sleep -s 60
            $cpuAvg = GetVMCPUAvg
        }
    }

    .\DeployApps.ps1 -StorageAccountName $storage_name -VmName $vm_name -VaultName $vault_name -ResourceGroupName $rg_name -SubscriptionName $subscription_name -SettingsFileName "serversettings.json" #-DefaultSettings $defaultsettings
    .\DeployBootSscripts.ps1 -VmName $vm_name -ResourceGroupName $rg_name -SubscriptionName $subscription_name -StorageAccountName $storage_name
    .\DeployConfiguration.ps1 -VmName $vm_name -ResourceGroupName $rg_name -VaultName $vault_name -SecretName $vm_name

    if ($data.config.database.createDatabase -eq $true) {
        Write-Host "Checking if we need to run Data Creator..."
        if ($dataCreatorAlreadyRan -eq $false) {
            ForEach ($app in $srv.apps) {
                if ($app.name.ToLower() -eq "servers") {
                    Write-Host "YES. Running remotely. Please wait"
                    .\DataCreatorCreateUserAndUploadToVm.ps1 -VmName $vm_name -ResourceGroupName $rg_name -RunDataCreator $true -DatabaseServerAddress $database_address -DatabaseServerPort $database_port -DatabaseName $cust_dbName
                    $dataCreatorAlreadyRan = $true
                }
            }
        }
    }

    Restart-AzVM -ResourceGroupName $rg_name -Name $vm_name

    #
    #if ($config.telephonyServer -eq $srv.type) {
    #    $conf_vm_name = $vm_name
    #}

    if ($srv.type -eq "main") {
        $conf_vm_name = $vm_name
        # if tel is empty, assume it is the main vm. at least until a tel vm is found and overrides this
        if ($conf_tel_name -eq "") {
            $conf_tel_name = $vm_name
        }
    }
    if ($srv.type -eq "tel") {
        $conf_tel_name = $vm_name
    }
}
#Wait-Job -Job $job
#$currentjob = Get-job -Id $job.Id


# Only add to Ops DB and run app configuration changes if creating new db
if ($data.config.database.createDatabase -eq $true)
{
    # Add to ops Db
    CreateCustomer -Name $cust -DatabaseName $cust_dbName -DatabaseIp $database_address_ext -DatabasePort $database_port -DatabaseUser $database_user -DatabasePass $database_password -HostVmName $conf_vm_name -TelVmName $conf_tel_name -StorageAccountName $storage_name -BlobContainerName "recordings" -VaultName $vault_name -Subscription $subscription_name -FullName $cust_name

    # Configure the database with the gathered settings

    .\ConfigureMaxDbSettings.ps1 -CustomerName $cust -DnsName $cust -CtiServerAddress $conf_tel_name -RegistrarAddress $conf_reg_name -VaultName $vault_name -SecretName $vm_name
}

#TODO
# brekeke
# harden server
# no suffix of -inbound io domain
#rep settings


#api
#move database menu server to azure

#assets
# WAV files
# add share

#enhancements
# parallel server builds in job
# check resources before creating
# if dns exists attach instead of throw
# default mercury config
# rerunning the script regens an api pass but doesoesnt update the db
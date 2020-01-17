$json = Get-Content "maxbuildsettings.json"

# convert it to an object and go browsing.
$data = $json | ConvertFrom-Json
#$data | Get-Member


$cust_name = $data.config.customerName
$cust = $data.config.customerPrefix
$cust_dbName = $data.config.database.name
$database_name = $data.config.database.databaseName
$database_address = $data.config.database.databaseAddress
$database_port = $data.config.database.databasePort
$database_user = $data.config.database.databaseUser
$database_password = $data.config.database.databasePassword
$vm_host = $data.config.servers.vmHost
$vm_tel = $data.config.servers.vmTel
$subscription_name =  $data.config.subscription
$region =  $data.config.region

$updateBlock =  $data.config.updateBlock


$deployments = $data.deployment.servers

#$json = Get-Content "silosettings.json"

# convert it to an object and go browsing.
$silosettings = $json | ConvertFrom-Json
#$silosettings | Get-Member

function configGetServer {
    param($DeploymentName)
    ForEach($dep in $deployments) {
        if ($dep.type -eq $DeploymentName)
        {
            return $dep
        }
    }

    return $null
}

function configGetSiloSettings {
    param($SubScriptionName)
    ForEach($set in $silosettings) {
        if ($set.name -eq $SubScriptionName)
        {
            return $set.vnet
        }
    }

    return $null
}

function configGetVmName {
    param($DeploymentName, $CustomerPrefix)
    $deployment = configGetServer -DeploymentName $DeploymentName
    $vmName = "ERROR-VM-NULL"
    if ($deployment.vmName -ne "")
    {
        $vmName = $deployment.vmName 
    }
    else
    {
        $vmName = ($CustomerPrefix + "-" + $deployment.vmSuffix)
    }
    return $vmName

}
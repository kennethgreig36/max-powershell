#Loop through all Azure Subscriptions
$subscriptions = Get-AzSubscription

#Provide the name of the csv file to be exported
$reportName = "ResourceswithTags.csv"
$reportFullPath = "$home/documents/$reportName"

$report = @()

$loggedin = Get-AzContext

if ($loggedin.Account -eq $null){Write-Warning "You are not currently logged in. Prompting for login." 
        try {Connect-AzAccount -ErrorAction Stop}
        catch{Write-Warning "Login process failed."}
    }

foreach ($subscription in $subscriptions) {
    Get-AzSubscription -SubscriptionName $subscription.Name | Set-AzContext

    $resources = Get-AzResource 

    foreach($resource in $resources) {
    
        if ($resource.Tags -ne $null) {
              
              $tags = $resource.Tags.Keys
              $test = $resource.Tags[$($tags)]

              $resourceStats = [pscustomobject]@{
                Name =$resource.Name
                ResourceGroupName = $resource.ResourceGroupName
                ResourceType = $resource.Type
                

                }
                $report+=$resourceStats
        }
            
        
    }

}


$report | ft

$fileExists = Test-Path $reportFullPath
if($fileExists -eq $False){
    $report | Export-CSV $reportFullPath
}
else
{
    Write-Warning 'File already present'
    $report | Export-CSV $reportFullPath
}
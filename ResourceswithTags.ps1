###
#
# Resources with Tags v1.0
# Features:
#   Checks every Azure subscription resources which does not have tags associated
#   Outputs the results to the file ResourceswithoutTags.CSV
#
# Ken Greig Jan-2020
#
#
###

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

#Loop through each Azure subscription
foreach ($subscription in $subscriptions) {
    Get-AzSubscription -SubscriptionName $subscription.Name | Set-AzContext

    $resources = Get-AzResource 

    #Loop through each resource group
    foreach($resource in $resources) {
            
            #Check if resource contains a tag
            if ($resource.Tags -ne $null) {
                  
                  #Enumerate hashtable containing the key and value for tags
                  $resource.Tags.GetEnumerator() | ForEach-Object { 
                
                    $tags = '{0} : {1} ' -f $_.key, $_.value
      
                      $resourceStats = [pscustomobject]@{
                        Name =$resource.Name
                        ResourceGroupName = $resource.ResourceGroupName
                        ResourceType = $resource.Type
                        Tags = $tags
                      }  

                      $report+=$resourceStats
                  }
                
            } 
 
                
    }    

}        

#Output report
$report | ft

#Check if report CSV file exists
$fileExists = Test-Path $reportFullPath
if($fileExists -eq $False){
    $report | Export-CSV $reportFullPath
}
else
{
    Write-Warning 'File already present'
    $report | Export-CSV $reportFullPath
}
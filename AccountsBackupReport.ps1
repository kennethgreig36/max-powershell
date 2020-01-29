###
#
# Accounts Backup Report v1.0
# Features:
#   Check that the accounts files have backed up to the MaxCore blob storage container
#   Outputs the results to a CSV file
#
# Ken Greig Jan-2020
#
#
###
$loggedin = Get-AzContext

if ($loggedin.Account -eq $null){Write-Warning "You are not currently logged in. Prompting for login." 
        try {Connect-AzAccount -ErrorAction Stop}
        catch{Write-Warning "Login process failed."}
}

<# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process

#TODO: Change these values before putting into prod!
Connect-AzAccount -ServicePrincipal -Tenant 'c0e6a95b-8a56-4cd5-be05-708c5537b1de' `
-ApplicationId '2a0fcaab-0db4-41c7-910a-227c2a4ec618' -CertificateThumbprint '41D02643B5FAD9C964BBB66E1FE87EB33569377B' | Out-Null #>

#MaxCore subscription
$subscriptionId = "a1cf0514-871b-4671-8cb1-c198c1a23f29"
Select-AzSubscription $subscriptionId

$connectionstring = "SharedAccessSignature=sv=2018-03-28&ss=bfqt&srt=sco&sp=rwlacup&st=2020-01-27T10%3A32%3A21Z&se=2021-01-28T10%3A32%3A00Z&sig=reDgh32VCpWdur3jb8wR8J7LUR6U9FXJi3vGUgJZBwM%3D;BlobEndpoint=https://accountsbackups.blob.core.windows.net/;FileEndpoint=https://accountsbackups.file.core.windows.net/;QueueEndpoint=https://accountsbackups.queue.core.windows.net/;TableEndpoint=https://accountsbackups.table.core.windows.net/;"
$container = "backups"

$storagecontext = New-AzStorageContext -ConnectionString $connectionstring

$currentdate = (Get-Date).AddDays(-1)

$blobs = Get-AzStorageBlob -Container $container -Context $storagecontext | Where-Object {$_.LastModified -gt $currentdate} | sort @{expression="LastModified";Descending=$true}

$report = @()

Foreach ($lastestblob in $blobs) {

    $backupdate = $lastestblob.LastModified

           $backupStats = [pscustomobject]@{
                FilePath = $lastestblob.Name
                LastModified = $lastestblob.LastModified
           }

           $report+=$backupStats
}


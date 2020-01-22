###
#
# Check Accounts Backup v1.0
# Features:
#   Check that the accounts files have backed up to the MaxCore blob storage container
#   Outputs the results via email
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

#MaxCore subscription
$subscriptionId = "a1cf0514-871b-4671-8cb1-c198c1a23f29"
Select-AzSubscription $subscriptionId

$connectionstring = "SharedAccessSignature=sv=2018-03-28&ss=bfqt&srt=sco&sp=rl&st=2020-01-22T15%3A30%3A43Z&se=2021-01-22T15%3A30%3A00Z&sig=ckyAau72e54dY81tZV3hbGe%2Fc%2F4kThRU%2BgPOmxz9Ryc%3D;BlobEndpoint=https://accountsbackups.blob.core.windows.net/;FileEndpoint=https://accountsbackups.file.core.windows.net/;QueueEndpoint=https://accountsbackups.queue.core.windows.net/;TableEndpoint=https://accountsbackups.table.core.windows.net/;"
$container = "backups"
$foldername = "Accounts"

$storagecontext = New-AzStorageContext -ConnectionString $connectionstring

$currentdate = (Get-Date).AddDays(-3)

$blobs = Get-AzStorageBlob -Container $container -Context $storagecontext | sort @{expression="LastModified";Descending=$true}


Foreach ($lastestblob in $blobs) {

    $backupdate = $lastestblob.LastModified

       if ($backupdate -gt $currentdate) {
        Write-Host $lastestblob.Name $lastestblob.LastModified
       }

}

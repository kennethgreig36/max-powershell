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

Write-Output "Connecting to blob storage account.."
$storagecontext = New-AzStorageContext -ConnectionString $connectionstring

$textfile = "canary.txt"
$textfileinput = "File added"| Out-File $textfile

$currentdate = (Get-Date).AddDays(-1)

Write-Output "Copying file to blob storage.."

Set-AzStorageBlobContent -Container $container -File $textfile -Context $storagecontext -Force

Write-Output "Fetching file from storage container.."
Write-Output $blob = Get-AzStorageBlob -Container $container -Context $storagecontext
###
#
# Accounts Backup Report v1.0
# Features:
#   Check that the accounts files have backed up to the MaxCore blob storage container
#   Storages the results of the backed up files and last modified date to a CSV file
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

#Provide the name of the csv file to be exported
$reportName = "AccountsBackup.csv"
$reportFullPath = "$home/documents/$reportName"

$connectionstring = "SharedAccessSignature=sv=2018-03-28&ss=bfqt&srt=sco&sp=rl&st=2020-01-22T15%3A30%3A43Z&se=2021-01-22T15%3A30%3A00Z&sig=ckyAau72e54dY81tZV3hbGe%2Fc%2F4kThRU%2BgPOmxz9Ryc%3D;BlobEndpoint=https://accountsbackups.blob.core.windows.net/;FileEndpoint=https://accountsbackups.file.core.windows.net/;QueueEndpoint=https://accountsbackups.queue.core.windows.net/;TableEndpoint=https://accountsbackups.table.core.windows.net/;"
$container = "backups"


$storagecontext = New-AzStorageContext -ConnectionString $connectionstring

$currentdate = (Get-Date).AddDays(-1)

$blobs = Get-AzStorageBlob -Container $container -Context $storagecontext | sort @{expression="LastModified";Descending=$true}

$report = @()

Foreach ($lastestblob in $blobs) {

    $backupdate = $lastestblob.LastModified

       if ($backupdate -gt $currentdate) {
        #Write-Host $lastestblob.Name $lastestblob.LastModified
                $backupStats = [pscustomobject]@{
                FilePath = $lastestblob.Name
                LastModified = $lastestblob.LastModified
                }
           $report+=$backupStats
       }

}

$files = $report.Count
$report | ft

$fileExists = Test-Path $reportFullPath
if($fileExists -eq $False){
    $report | Export-CSV $reportFullPath
}
else
{
  $report | Export-CSV $reportFullPath
}

# Send Email
$SMTPServer = "auth.smtp.1and1.co.uk"
$SMTPPort = "587"
$Username = "reports@touchstarccs.eu"
$Password = "D4v1k3r" | ConvertTo-SecureString -asPlainText -Force

$From = "noreply@infra.maxcontact.com"
$to = "kenneth.greig@maxcontact.com"
#$bcc = "infhelpdesk@maxcontact.io"
#$who = $inputdata.email
$date3 = Get-Date -Format dd-MM-yy
$subject = "Accounts Backup Report" + $date3

$body = ( '<p>Accounts Files Backed Up:' + $files + '</p>'  `
            + '<p>Latest File Backed Up ' + $blobs[0] + '</p>' `
            + '<p> </p>')

            $message = New-Object System.Net.Mail.MailMessage
            $message.subject = $subject
            $message.body = $body
            $message.to.add($to)
            #$message.bcc.add($bcc)
            $message.from = $From
            $message.isbodyhtml = $true
        
            $smtp = New-Object System.Net.Mail.SmtpClient($SMTPServer, $SMTPPort);
            $smtp.EnableSSL = $true
            $smtp.Credentials = New-Object System.Net.NetworkCredential($Username, $Password);
            $smtp.send($message)
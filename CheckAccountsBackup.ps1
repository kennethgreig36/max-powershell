###
#
# Check Accounts Backup v1.0
# Features:
#   Check that the accounts files have backed up to the MaxCore blob storage container
#   Checks if the canary.txt file has been backed up and sends result via email
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

#Set Culture for date format
Set-Culture -CultureInfo en-GB

$connectionstring = "SharedAccessSignature=sv=2018-03-28&ss=bfqt&srt=sco&sp=rwlacup&st=2020-01-27T10%3A32%3A21Z&se=2021-01-28T10%3A32%3A00Z&sig=reDgh32VCpWdur3jb8wR8J7LUR6U9FXJi3vGUgJZBwM%3D;BlobEndpoint=https://accountsbackups.blob.core.windows.net/;FileEndpoint=https://accountsbackups.file.core.windows.net/;QueueEndpoint=https://accountsbackups.queue.core.windows.net/;TableEndpoint=https://accountsbackups.table.core.windows.net/;"
$container = "backups"

$storagecontext = New-AzStorageContext -ConnectionString $connectionstring

$currentdate = (Get-Date).AddDays(-1)

#Fetch Blobs from Azure Blob Storages
$blobs = Get-AzStorageBlob -Container $container -Context $storagecontext | Where-Object {$_.LastModified -gt $currentdate} | sort @{expression="LastModified";Descending=$true}
$filecount = $blobs.Count

if ($blobs[0].LastModified -gt $currentdate -and $blobs[0].Name -match "canary.txt") {
        $status = "SUCCESS"
        $body += "<p>The accounts backup was successful as " + $blobs[0].Name + " was backed up successfully and it was last modfied on " + `
        $blobs[0].LastModified.ToString(([cultureinfo])::CurrentCulture) + "</p><p>Files backed up: " + $filecount + "</p>" 
} else {
        $status = "FAILURE"
        $body = "The accounts backup failed as the file canary.txt was not modified after " + $currentdate + "!"
}

Write-Output $body

#Send Email
$SMTPServer = "auth.smtp.1and1.co.uk"
$SMTPPort = "587"
$Username = "reports@touchstarccs.eu"
$Password = "D4v1k3rReports!" | ConvertTo-SecureString -asPlainText -Force

$From = "noreply@infra.maxcontact.com"
$to = "kenneth.greig@maxcontact.com"
#$bcc = "infhelpdesk@maxcontact.io"
#$who = $inputdata.email
$date3 = Get-Date -Format dd-MM-yy
$subject = "Accounts Backup Status " + $date3 + " - " + $status

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
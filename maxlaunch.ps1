###
#
# Max App launcher v2.0
# New features:
#   Works with Omni Apps 
#   checks app not already running
#   Allow ancilliary apps to be added
#   Better output over email
#   Less errors (errors now caught and dealt with)
#
# Barry Carter Nov-2019
#
# Max App launcher v2.1
# Include apps like record splitter etc
#
###

$timer = Get-Date
$lf = "`n`r"

$version = "Server restarter v2.1"

$basePathOmni = "C:\Max\Applications\"
$basePathMerc = "C:\Program Files (x86)\Max Contact Now\"
$basePathMax = "C:\Program Files (x86)\Max Contact Now\"

$basePath = $basePathMax

$apps = [ordered]@{
	"CommServer" = @{ 
		"v2exe" = "MaxDial.CommServer.exe"
		"v3exe" = "QBit.Calypso.CommServer.UI.Console.Display.exe"
		"v2path" = "$basePathMax\Servers"
		"v3path" = "$basePathOmni\Servers\CommServer"
        "delayAfter" = 45
	}
	"Mercury" = @{ 
		"v2exe" = "Mercury.exe"
		"v3exe" = "Mercury.exe"
		"v2path" = "$basePathMerc\Mercury"
		"v3path" = "$basePathMerc\Mercury"
        "delayAfter" = 2
	}
	"CallServer" = @{ 
		"v2exe" = "MaxDial.CallServer.exe"
		"v3exe" = "QBit.Calypso.CallServer.UI.ConsoleDisplay.exe"
		"v2path" = "$basePathMax\Servers"
		"v3path" = "$basePathOmni\Servers\CallServer"
        "delayAfter" = 10
	}
	"ImportServer" = @{ 
		"v2exe" = "MaxDial.ImportServer.exe"
		"v3exe" = "QBit.Calypso.ImportServer.UI.exe"
		"v2path" = "$basePathMax\Servers"
		"v3path" = "$basePathOmni\Servers\ImportServer"
        "delayAfter" = 5
	}
	"AgentProxyServer" = @{ 
		"v2exe" = "MaxDial.AgentProxyServer.exe"
		"v3exe" = "AgentProxyServer.UI.exe"
		"v2path" = "$basePathMax\WebTools\AgentProxy"
		"v3path" = "$basePathOmni\WebTools\AgentProxyServer"
        "delayAfter" = 5
	}
	"StatProxyServer" = @{ 
		"v2exe" = "MaxDial.StatsServer.exe"
		"v3exe" = "StatsServer.ConsoleUI.exe"
		"v2path" = "$basePathMax\WebTools\StatServer"
		"v3path" = "$basePathOmni\WebTools\StatsServer"
        "delayAfter" = 1
	}
	"ScheduleServer" = @{ 
		"v2exe" = "MaxDial.ScheduleServer.exe"
		"v3exe" = "ScheduleServer.UI.exe"
		"v2path" = "$basePathMax\Schedule Server & OData\ScheduleServer"
		"v3path" = "$basePathOmni\Schedule Server & OData\ScheduleServer"
        "delayAfter" = 1
	}
	"MaxLauncher" = @{ 
		"v2exe" = "MaxLauncher.exe"
		"v3exe" = "MaxLauncher.ConsoleUI.exe"
		"v2path" = "$basePathMax\MaxLauncher\MaxLauncher"
		"v3path" = "$basePathOmni\Servers\MaxLauncher"
	}
	"SpeechServer" = @{ 
		"v2exe" = "MaxDial.SpeechServer.exe"
		"v3exe" = "QBit.Calypso.SpeechServer.UI.ConsoleDisplay.exe"
		"v2path" = "$basePathMax\Servers"
		"v3path" = "$basePathOmni\Servers\SpeechServer"
        "delayAfter" = 2
	}
	"Collector" = @{ 
		"v2exe" = ""
		"v3exe" = "Interaction.Collectors.TestHarness.ConsoleUI.exe"
		"v2path" = ""
		"v3path" = "$basePathOmni\Omni\Collector"
        "delayAfter" = 0
	}
	"RecordingSplitter" = @{
		"v2exe" = "Max.RecordingSplitter.Console.exe"
		"v3exe" = "Max.RecordingSplitter.Console.exe"
        "v2path" = @("C:\max\Max.RecordingSplitter.Console", "C:\Max\Max.RecordingSplitter.Console\Recording Splitter\Max.RecordingSplitter.Console")
        "v3path" = @("C:\max\Max.RecordingSplitter.Console", "C:\Max\Max.RecordingSplitter.Console\Recording Splitter\Max.RecordingSplitter.Console")
		"delayAfter" = 0
	}
    "LeadIntegration" = @{
        "v2exe" = "Max.Integration.Host.exe"
		"v3exe" = "Max.Integration.Host.exe"
		"v2path" = @("C:\Program Files (x86)\Integration Engine", "C:\max\IntegrationApplication\Lead_Integration")
		"v3path" = @("C:\Program Files (x86)\Integration Engine", "C:\max\IntegrationApplication\Lead_Integration")
		"delayAfter" = 0
    }
}

Write-Host "Starting Max $version"

if(Test-Path $basePathOmni) {
	#OmniMax 3.x. Yes we are omni
	$isOmni = $true
    Write-Host "*** This is an OMNI v3 system ***"
}

$numToCheck = 0

ForEach($appKey in $apps.Keys) {
    $app = $apps[$appKey]
	Write-Host "Starting App :-   " $appKey
    $path = $app.v2path
    $exe = $app.v2exe

	if ($isOmni) {
        $path = $app.v3path
        $exe = $app.v3exe
	}

    if ($path -eq "") {
        $app.present = $false
        continue
    }

    $tmppath = $path
    if ($path.GetType().BaseType.Name -eq "Array") {
        # if the path is an array of paths, loop until we find a valid app
        ForEach($p in $tmppath) {
            if(Test-Path $p\$exe) {
                $path = $p
                break;
            }
        }
    }

    # The path is not blank and we have something to test
    # Lets see if the application exists
    if(Test-Path $path\$exe) {
		Set-Location $path
        try {
            # Check if it is already running. Is it is, we won't try and run it again
            $proc = Get-Process $exe.Replace(".exe", "") -ErrorAction SilentlyContinue

            if ($proc) {
                Write-Host "Already Running"
                $app.present = $true
                continue
            }
		    Start-Process $exe -Verbose -WindowStyle Minimized
            $app.present = $true
            $numToCheck++
            Write-Host "Sleeping for " $app.delayAfter "s"
            Start-Sleep $app.delayAfter            
        }
        catch {
            $app.failed = $true
        }
    }
    else {
        $app.present = $false
    }
}

Write-Host "Sleeping while the apps come up. Please wait"
start-sleep 15

$appReport = @()

function Add-EmailLine($app, $status) {
    $a = "{0, -25} {1, 25}" -f $app, $status
    Write-Host $a
    return $a
}


$numRunning = 0

# Generate the report
ForEach($appKey in $apps.Keys) {
    $app = $apps[$appKey]

    if ($app.present -eq $false) {
        $appReport += Add-EmailLine $appKey "Not Installed"
        continue
    }

    $exe = $app.v2exe
    if ($isOmni) {
        $exe = $app.v3exe
	}

    $exe = $exe.Replace(".exe", "")

    # Check if the process is running
    $proc = Get-Process $exe -ErrorAction SilentlyContinue

    if ($proc) {
        # it's running
        $app.isRunning = $true
        $appReport += Add-EmailLine $appKey "OK"
        $numRunning++
    }
    else {
        $appReport += Add-EmailLine $appKey "*** FAILED ***"
        $app.isRunning = $false
    }
}

$isSuccess = $false
if ($numToCheck -eq $numRunning) {
    $isSuccess = $true
}


$finish = Get-Date
$time = $finish-$timer
$masterconfig = [xml](Get-content -Path "C:\Max\master.config")
$cusname = $masterconfig.appSettings.add[2].value

[string]$finaltime = ($time.Minutes.ToString()+" minute(s) and "+$time.Seconds.ToString()+" second(s)")

#Email is built and sent to the important parties

$SMTPServer = "auth.smtp.1and1.co.uk"
$SMTPPort = "587"
$Username = "reports@touchstarccs.eu"
$Password = "D4v1k3r"

$From = "reboot@infra.maxcontact.com"

[string]$finaltime = ($time.Minutes.ToString()+" minute(s) and "+$time.Seconds.ToString()+" second(s)")

$date3 = Get-Date -Format dd-MM-yy

$stat = "FAIL"
if ($isSuccess -eq $true) {
    $stat = "SUCCESS"
}
$subject = "$stat : Customer $cusname on server " + $env:COMPUTERNAME + " Has rebooted"

$body = "Server " + $env:COMPUTERNAME + " Has rebooted $lf"
$body += "{0, -15}{1, 25} $lf" -f "Status:", "$stat"
$body += "{0, -15}{1, 25} $lf" -f "Startup Time:", "$finaltime"
$body += "{0, -15}{1, 25} $lf" -f "Script Ver:", "$version"

$body += "{0, -15}{1, 25} $lf" -f "Type:", $(if($isOmni) { "Omni" } else { "Max 2.0" } )
$body += "$lf Apps $lf"
$body += "=========================== $lf"

ForEach($app in $appReport) {
    $body += "$app $lf"
}


$message = New-Object System.Net.Mail.MailMessage
$message.subject = $subject
$message.body = $body
$message.to.add("infrastructure@maxcontact.com")
$message.to.add("engineers@maxcontact.com")
$message.to.add("help@maxcontact.com")


$message.from = $from
$message.Priority = 2

$smtp = New-Object System.Net.Mail.SmtpClient($SMTPServer, $SMTPPort);
$smtp.EnableSSL = $true
$smtp.Credentials = New-Object System.Net.NetworkCredential($Username, $Password);
$error.clear()
$smtp.send($message)

if($error)
{
  new-item -ItemType file -Path ("C:\Max\log\MaxRestarterFailedToSendEmailLog-" + $(Get-date).ToString("yyyy-MM-dd") + ".txt") `
  -Value $body
}

$smtp = $null
$message = $null
$Password = $null
$Username = $null
$masterconfig = $null
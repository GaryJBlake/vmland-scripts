<#
.SYNOPSIS   Configure NTP and Enable SSH using a CSV
.NOTES      Author: Gary Blake
.NOTES      Blog: www.http://vmland.blogspot.co.uk/
.NOTES      Version: 1.0
.EXAMPLE    ./SetNTPnSSH.ps1 Hosts-SetNTPnSSH.csv
#>

# Import host details from a CSV file and populate values
Param($InputCSV=$(throw "You must specify the csv to be used")) 
$HostList = Import-CSV $InputCSV

ForEach ($HostEntry in $HostList){
 	$HostIp = $($HostEntry.HostIP)
 	$NTPServer0 = $($HostEntry.NTPServer0)
	$NTPServer1 = $($HostEntry.NTPServer1)
 	$Username = $($HostEntry.Username)
 	$Password = $($HostEntry.Password)
	
	Try {
		Clear-Host
		Write-Host "Step 1 - Connecting to ESXi host: $Hostip" -ForegroundColor Green
		$ConnectHost = Connect-VIServer $HostIp -User $Username -Password $Password
		$TargetHost = Get-VMHost | where { $_.name -eq $HostIp }
		Write-Host ""
		Write-Host "Success" -ForegroundColor yellow 
		Write-Host ""
		
		Write-Host "Step 2 - Enable SSH and set the start policy on ESXi host: $Hostip" -ForegroundColor Green
		Write-Host ""
		#Service: TSM-SSH start
		Get-VMHostService | Where {$_.key -eq 'TSM-SSH'} | Start-VMHostService -Confirm:$false
		#Service: TSM-SSH start and stop with host
		Set-VMHostService -HostService (Get-VMHostservice | Where {$_.key -eq "TSM-SSH"}) -Policy "On"
		#Disable the warning for SSH
		$shellWarning = Get-VMHost | Get-AdvancedSetting | Where {$_.Name -eq "UserVars.SuppressShellWarning"} -ErrorAction SilentlyContinue
		if($shellWarning){
			if($shellWarning.Value -ne "1"){
				Set-AdvancedSetting -AdvancedSetting $shellWarning -Value "1" -Confirm:$false
			}
		} else {
			#the advanced setting does not exist so create it
			Get-VMHost | New-AdvancedSetting -Name "UserVars.SuppressShellWarning" -Value "1" -Force:$true -Confirm:$false
		}
		Write-Host ""
		Write-Host "Success" -ForegroundColor yellow 

		Write-Host ""
		Write-Host "Step 3 - Configure NTP Server and set the start policy on ESXi host: $Hostip" -ForegroundColor Green
		Write-Host ""
		# Service: TSM-SSH start
		# NTP Servers
		Get-VMHostService | Where {$_.key -eq 'ntpd'} | Stop-VMHostService -Confirm:$false
		$currentNTPServerList = Get-VMHostNtpServer
		#Delete any existing ntp servers
		if ($currentNTPServerList){
			Remove-VMHostNtpServer -NtpServer $currentNTPServerList -Confirm:$false
		}
		# Add the new NTP servers
		Add-VMHostNtpServer -NtpServer $NTPServer0 -Confirm:$false
		Add-VMHostNtpServer -NtpServer $NTPServer1 -Confirm:$false
		#Service NTP : start
		Get-VMHostService | Where {$_.key -eq 'ntpd'} | Start-VMHostService -Confirm:$false
		#Service: NTP start and stop with host
		Set-VMHostService -HostService (Get-VMHostservice | Where {$_.key -eq "ntpd"}) -Policy "On"
		Write-Host ""
		Write-Host "Success" -ForegroundColor yellow 
		
		Disconnect-viserver -Server $TargetHost.Name -force -confirm:$false
	}
	Catch {
		$ErrorMessage = $_.Exception.Message
		Write-Host "    Error occurred while processing host " $HostIp " with error message: " $ErrorMessage
	}
}	

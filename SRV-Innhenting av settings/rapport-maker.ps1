# Kjør som administrator
$rapport = "C:\SRV-rapport-$(hostname)-$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

"==== RAPPORT FOR SRV-OPPGAVE ====" | Out-File -FilePath $rapport

"--- NETTVERKSINNSTILLINGER ---" | Out-File -Append $rapport
Get-NetIPAddress | Out-File -Append $rapport
Get-DnsClientServerAddress | Out-File -Append $rapport

"--- DOMENE OG AD-INNSTILLINGER ---" | Out-File -Append $rapport
Get-ADDomain | Out-File -Append $rapport
Get-ADForest | Out-File -Append $rapport
Get-ADUser -Filter * -Properties Department | Select-Object Name,SamAccountName,Department | Out-File -Append $rapport
Get-ADGroup -Filter * | Select-Object Name,GroupScope | Out-File -Append $rapport

"--- HJEMMEOMRÅDER OG FELLESOMRÅDER ---" | Out-File -Append $rapport
Get-SmbShare | Out-File -Append $rapport

"--- DHCP-KONFIGURASJON ---" | Out-File -Append $rapport
Get-DhcpServerv4Scope | Out-File -Append $rapport

"--- SKRIVERE ---" | Out-File -Append $rapport
Get-Printer | Out-File -Append $rapport

"--- BACKUP STATUS ---" | Out-File -Append $rapport
wbadmin get status | Out-File -Append $rapport

"--- TILLEGGSTJENESTER (IIS/IPAM/WDS etc.) ---" | Out-File -Append $rapport
Get-WindowsFeature | Where-Object {$_.InstallState -eq "Installed"} | Out-File -Append $rapport

"--- TIDSSYNKRONISERING ---" | Out-File -Append $rapport
w32tm /query /status | Out-File -Append $rapport

"=== SLUTT PÅ RAPPORT ===" | Out-File -Append $rapport

Write-Host "Rapport lagret i: $rapport"

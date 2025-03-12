
$InterfaceIndex = (Get-NetAdapter | Where-Object {$_.Status -eq "Up"}).InterfaceIndex

# Muuda parameetrid
$IPAddress = "192.168.1.10"
$SubnetMask = 24
$Gateway = "192.168.1.1"
$DNSServers = "192.168.1.1", "8.8.8.8"
$DomainName = "minunimi.sise"

Write-Host "IP seadete püsivaks muutmine..."
Remove-NetIPAddress -InterfaceIndex $InterfaceIndex -Confirm:$false -ErrorAction SilentlyContinue
Remove-NetRoute -InterfaceIndex $InterfaceIndex -Confirm:$false -ErrorAction SilentlyContinue
New-NetIPAddress -InterfaceIndex $InterfaceIndex -IPAddress $IPAddress -PrefixLength $SubnetMask -DefaultGateway $Gateway
Set-DnsClientServerAddress -InterfaceIndex $InterfaceIndex -ServerAddresses $DNSServers
Write-Host "Active Directory rollide paigaldamine..."
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools
Write-Host "Domeeni loomine ja serveri edutamine domeeni kontrolleriks..."
$SecureString = ConvertTo-SecureString "P@ssw0rd1" -AsPlainText -Force
Install-ADDSForest -DomainName $DomainName -SafeModeAdministratorPassword $SecureString -InstallDns:$true -Force:$true -NoRebootOnCompletion:$true
Write-Host "Turvauuenduste automatiseerimine..."
$AutoUpdatePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
if(!(Test-Path $AutoUpdatePath)) {
    New-Item -Path $AutoUpdatePath -Force
}
Set-ItemProperty -Path $AutoUpdatePath -Name "AUOptions" -Value 4
Set-ItemProperty -Path $AutoUpdatePath -Name "NoAutoUpdate" -Value 0
Set-ItemProperty -Path $AutoUpdatePath -Name "ScheduledInstallDay" -Value 0
Set-ItemProperty -Path $AutoUpdatePath -Name "ScheduledInstallTime" -Value 3
Write-Host "Täiendava kettaressursi loomine ja varunduse teenuse paigaldamine..."
$Disk = Get-Disk | Where-Object {$_.PartitionStyle -eq 'RAW'}
if ($Disk) {
    Initialize-Disk -Number $Disk.Number -PartitionStyle GPT
    $Partition = New-Partition -DiskNumber $Disk.Number -UseMaximumSize -AssignDriveLetter
    $DriveLetter = $Partition.DriveLetter
    Format-Volume -DriveLetter $DriveLetter -FileSystem NTFS -NewFileSystemLabel "Backup" -Confirm:$false
    Install-WindowsFeature -Name Windows-Server-Backup -IncludeManagementTools
    $Policy = New-WBPolicy
    $BackupDrive = New-WBBackupTarget -Disk (Get-WBDisk | Where-Object {$_.DriveLetter -eq $DriveLetter})
    Add-WBBackupTarget -Policy $Policy -Target $BackupDrive
    Add-WBSystemState -Policy $Policy
    $Schedule = New-WBSchedule -Daily -At "02:00"
    Set-WBSchedule -Policy $Policy -Schedule $Schedule
    Set-WBPolicy -Policy $Policy
}
else {
    Write-Warning "Vaba ketast varunduse jaoks ei leitud!"
}
Write-Host "Server on vaja taaskäivitada, et muudatused jõustuksid"
Write-Host "Pärast taaskäivitust on server seadistatud kui $DomainName domeeni kontroller"
Write-Host "Kas soovid serveri kohe taaskäivitada? (J/E)"
$restart = Read-Host
if ($restart -eq "J" -or $restart -eq "j") {
    Restart-Computer -Force
}
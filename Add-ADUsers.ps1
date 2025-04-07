Param(
    [string]$CsvPath = "C:\Users\Administrator\Desktop\brukere.csv",
    [string]$Domain = "jovian.local",
    [string]$GroupBaseOuPath = "OU=Jovian,DC=jovian,DC=local"
)

Import-Module ActiveDirectory -ErrorAction Stop

try {
    $baseOU = Get-ADOrganizationalUnit -Filter { DistinguishedName -eq $GroupBaseOuPath } -ErrorAction SilentlyContinue
    if (-not $baseOU) {
        $ouName = ($GroupBaseOuPath -replace '^OU=([^,]+).*$','$1')
        New-ADOrganizationalUnit -Name $ouName -Path ($GroupBaseOuPath -replace '^OU=[^,]+,','')
    }
} catch {}

$HomeFolderBase = "C:\Delinger\Hjemmeområde"
if (-not (Test-Path $HomeFolderBase)) {
    New-Item -ItemType Directory -Path $HomeFolderBase -Force
}

$users = Import-Csv -Path $CsvPath -Encoding UTF8

$defaultPassword = "Admin:123"

foreach ($user in $users) {
    if (-not $user.Fnavn -or -not $user.Enavn -or -not $user.Avdeling) {
        continue
    }

    if ($user.Mnavn -and $user.Mnavn.Trim() -ne "") {
        $fullName = "$($user.Fnavn) $($user.Mnavn) $($user.Enavn)"
    } else {
        $fullName = "$($user.Fnavn) $($user.Enavn)"
    }

    $samAccountName = ($user.Fnavn + "." + $user.Enavn).Replace(" ", "")
    if ($samAccountName.Length -gt 20) {
        $samAccountName = $samAccountName.Substring(0,20)
    }

    $upn = "$($samAccountName)@$Domain"
    $rawAvdeling = $user.Avdeling
    if ([string]::IsNullOrWhiteSpace($rawAvdeling)) {
        continue
    }

    $avdelingList = @()
    foreach ($a in ($rawAvdeling -split '/')) {
        $clean = ($a -replace '[^\p{L}\p{N}\- ]', '').Trim()
        if ($clean -ne "") { $avdelingList += $clean }
    }

    Write-Host "DEBUG: Avdeling = '$rawAvdeling' ➜ Renset = $($avdelingList -join ', ')"

    if ($avdelingList.Count -eq 1) {
        $deptOUName = $avdelingList[0]
    } else {
        $deptOUName = ($avdelingList | Sort-Object) -join "-"
    }

    Write-Host "DEBUG: Bruker '$fullName' skal inn i OU: '$deptOUName'"

    $userOUPath = "OU=$deptOUName,$GroupBaseOuPath"

    try {
        $deptOU = Get-ADOrganizationalUnit -Filter { Name -eq $deptOUName } -SearchBase $GroupBaseOuPath -ErrorAction SilentlyContinue
        if (-not $deptOU) {
            New-ADOrganizationalUnit -Name $deptOUName -Path $GroupBaseOuPath
        }
    } catch { continue }

    try {
        New-ADUser `
            -Name $fullName `
            -GivenName $user.Fnavn `
            -Surname $user.Enavn `
            -DisplayName $fullName `
            -SamAccountName $samAccountName `
            -UserPrincipalName $upn `
            -AccountPassword (ConvertTo-SecureString $defaultPassword -AsPlainText -Force) `
            -Enabled $true `
            -ChangePasswordAtLogon $false `
            -Path $userOUPath `
            -OtherAttributes @{ description = "Født: $($user.Født) | Avdeling: $rawAvdeling" }
        Write-Host "✅ Bruker opprettet: $samAccountName"
        Start-Sleep -Seconds 1
    } catch {
        Write-Warning "❌ Klarte ikke opprette bruker: $samAccountName"
        continue
    }

    if (-not (Get-ADUser -Identity $samAccountName -ErrorAction SilentlyContinue)) {
        Write-Warning "❌ Bruker $samAccountName finnes ikke etter opprettelse – hopper over icacls."
        continue
    }

    $homeFolder = Join-Path -Path $HomeFolderBase -ChildPath $samAccountName
    if (-not (Test-Path $homeFolder)) {
        New-Item -ItemType Directory -Path $homeFolder -Force
    }

    $domainPrefix = "JOVIAN"
    icacls $homeFolder /inheritance:r
    icacls $homeFolder /grant "${domainPrefix}\\${samAccountName}:(OI)(CI)F" /grant "Administrators:F" /grant "SYSTEM:F"

    $groupOUPath = $userOUPath
    try {
        $group = Get-ADGroup -Filter { Name -eq $deptOUName } -SearchBase $groupOUPath -ErrorAction SilentlyContinue
        if (-not $group) {
            New-ADGroup -Name $deptOUName -SamAccountName $deptOUName -GroupScope Global -GroupCategory Security -Path $groupOUPath -Description "Avdeling: $deptOUName"
            $group = Get-ADGroup -Filter { Name -eq $deptOUName } -SearchBase $groupOUPath -ErrorAction Stop
        }
    } catch { continue }

    try {
        Add-ADGroupMember -Identity $group -Members $samAccountName
    } catch {}
}

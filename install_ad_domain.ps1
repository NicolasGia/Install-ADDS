# Déclaration de Variables
$StaticIP = "192.168.0.1"
$NewComName = "SRV-Nico"
$Domain = "sete.local"
$DomainNetbios = "SETELOCAL"
$InterfaceAlias = "Ethernet"
$Gateway = "192.168.0.254"



$groupes = @("Apprenants", "Formateurs", "Administration")
$ouGroupes = "OU=Groupes,DC=sete,DC=local"

$stepFile = "C:\Users\Administrateur.WIN-E4LNC7DKCLG.000\Desktop\step.txt"



# Création et MAJ du compteur d'étape
if (-not(Test-Path $stepFile)) {
    Set-Content -Path $stepFile -Value 0
}

$step = [int](Get-Content -Path $stepFile)



# Début de la configuration

if ($step -eq 0) {
    Set-Content -Path $stepFile -Value 1

# 1 Définir une adresse IP statique sur le carte réseau
    New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $StaticIP -PrefixLength 24 -DefaultGateway $Gateway

# 2 Renommer l’ordinateur
    Rename-Computer -NewName $NewComName -Force -Restart
    
}
elseif ($step -eq 1){
    Set-Content -Path $stepFile -Value 2

# 3 Installer les rôles nécessaires (AD DS, DNS)
    Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools

# 4 Promouvoir le serveur en tant que DC d'une nouvelle forêt
    Install-addsforest -DomainName $Domain -DomainNetBIOSName $DomainNetbios -SafeModeAdministratorPassword (Read-Host -AsSecureString "Mot de passe DSRM")
}
else{


# 5 Créer des OU
    New-ADOrganizationalUnit -Name "Utilisateurs" -Path "DC=sete,DC=local"
    New-ADOrganizationalUnit -Name "Groupes" -Path "DC=sete,DC=local"


# 6 Créer des utilisateurs et des groupes
#   Avec deux méthodes pour le ForEach
    
Import-Csv "C:\Users\Administrateur.WIN-E4LNC7DKCLG.000\Desktop\utilisateurs.csv" | ForEach-Object {
    $SecurePass = ConvertTo-SecureString $_.MDP -AsPlainText -Force

    New-ADUser `
        -SamAccountName $_.SamAccountName `
        -UserPrincipalName "$($_.SamAccountName)@sete.local" `
        -Name "$($_.Nom) $($_.Prenom)" `
        -GivenName $_.Prenom `
        -Surname $_.Nom `
        -Path $_.OU `
        -AccountPassword $SecurePass `
        -Enabled $true `
}


foreach ($groupe in $groupes) {
    New-ADGroup -Name $groupe `
                -GroupScope Global `
                -GroupCategory Security `
                -Path $ouGroupes
}



# 7 Créer un dossier partagé
New-Item -Path "C:\Partages\Docs" -ItemType Directory
New-SmbShare -Name "Docs" -Path "C:\Partages\Docs" -FullAccess "sete.local\Administrateurs"

# 8 Configurer des GPO de domaine
New-GPO -Name "GPO Sécurité"
New-GPLink -Name "GPO Sécurité" -Target "OU=Utilisateurs,DC=sete,DC=local"

# 9 Désactiver ou configurer le pare-feu Windows
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

}


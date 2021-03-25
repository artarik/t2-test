#1.       Написать запрос к ya.ru , в случае если ответ не 200, отправлять письмо произвольного содержания на произвольную почту. 

if ((Invoke-WebRequest -Uri "https://ya.ru").StatusCode -ne 200){Send-SmtpMail -SmtpHost "smtp.domain.com" -PortNumber "25" -To "username@domain.com" -Body "Status Code != 200"  -From "from@domain.com"}

#2.      Нужно сделать несколько файлов (txt/PS) в директории C:\Scripts, у некоторых прописать в содержимом "Enable-ADAccount". В директории найти все скрипты содержащие командлет Enable-ADAccount.

if (-not (Test-Path "C:\Scripts")){
    New-Item -Path "C:\Scripts" -ItemType Directory
}

Set-Location "C:\Scripts"
$array = 1..(Get-Random -Minimum 5 -Maximum 20) 
foreach($obj in $array) {
    $tmpfilename = ([System.IO.Path]::GetRandomFileName() -replace "\..+", (Get-Random -InputObject ".txt", ".ps1"))
    if ([bool]((Get-Random -Minimum 1 -Maximum 4) % 2)){
        Add-Content -Value "Enable-ADAccount" -Path $tmpfilename
    }else{
        $null = New-Item -Path $tmpfilename -ItemType File
    }
}
 $mathces = Get-ChildItem -Filter "*.ps1" | Select-String "Enable-AdAccount" -List | Select Path
 $mathces.Path
 $mathces.Count
 
 <#
 3.       Существует 3 сервера со скриптами:
•         Server-test-01
•         Server-test-02
•         Server-test-03
Путь к скриптам C:\Scripts\*, у некоторых скриптов в том же каталоге (рядом) может быть .log –файл имя которого полностью совпадает с именем скрипта
Необходимо удаленно, со своего компьютера, произвести поиск аналогично первому заданию на всех 3х серверах, результаты у себя выгрузить в .csv – файл вида:
Имя сервера | полный путь к скрипту | Логирование (да/нет). Кодировка не важна.
#>


Invoke-Command 'Server-test-01', 'Server-test-02', 'Server-test-03' -ScriptBlock {
    Get-ChildItem -Path C:\Scripts\ -Filter "*.ps1" | Select-String "Enable-AdAccount" -List | Select-Object @{L="Path";E={$PSItem.Path}}, @{
        label='log' ;expression={
            if(Test-Path($PSItem.Path -replace "\.ps1", ".log")){
                "Да"
            }else{
                "Нет"
            }
        }
    }
} | Select-Object @{L = "Имя Сервера"; E={$PSItem.PSComputerName}}, `
                  @{L = "полный путь к скрипту"; E={$PSItem.Path}}, `
                  @{L = "Логирование (да/нет)"; E={$PSItem.log}} | Export-Csv -Path c:\temp\export.csv -Encoding UTF8 -NoTypeInformation




<#
4.       Аналогично прошлому заданию необходимо добавить использование credentials,
Логин и пароль произвольные, однако, хранить их в открытом виде в скрипте нельзя. (использование планировщика не предполагается)
 
(задача на "хранение кредов")
#>
$creds = Import-Clixml ~\creds.xml
Invoke-Command 'Server-test-01', 'Server-test-02', 'Server-test-03' -ScriptBlock {
    Get-ChildItem -Path C:\Scripts\ -Filter "*.ps1" | Select-String "Enable-AdAccount" -List | Select-Object @{L="Path";E={$PSItem.Path}}, @{
        label='log' ;expression={
            if(Test-Path($PSItem.Path -replace "\.ps1", ".log")){
                "Да"
            }else{
                "Нет"
            }
        }
    }
} -Credential $creds | Select-Object @{L = "Имя Сервера"; E={$PSItem.PSComputerName}}, `
                                     @{L = "полный путь к скрипту"; E={$PSItem.Path}}, `
                                     @{L = "Логирование (да/нет)"; E={$PSItem.log}} | Export-Csv -Path c:\temp\export.csv -Encoding UTF8 -NoTypeInformation

<#
 
5.       Необходимо сделать 2 группы в AD, наполнить произвольными УЗ.  Перенести участников группы 1 в группу2, исключая учетные записи из массива login-ов $exclude. Массив $exclude сделать произвольный.
 
[array]$exclude=@(“ivan.ivanov”,
“artem.artemov”,
….) 
#>


New-ADGroup -Name Group1 -SamAccountName SG.Group1 -GroupCategory Security -GroupScope Global -DisplayName "Group 1" 
New-ADGroup -Name Group2 -SamAccountName SG.Group2 -GroupCategory Security -GroupScope Global -DisplayName "Group 2" 

$group1 = Get-ADGroup -f {samaccountname -eq 'SG.Group1'}
$group2 = Get-ADGroup -f {samaccountname -eq 'SG.Group2'}

$users = Get-aduser -f {Enabled -eq "true"} | select Name, samaccountName
$users | select -First 10  |%{ Add-ADGroupMember $group1 -Members $PSItem.samaccountname }
$users | select -Last 10  |%{ Add-ADGroupMember -Identity $group2 -Members $PSItem.samaccountname }
[array]$exclude= (1..5 | %{$users | Select -Index (Get-Random -Minimum 1 -Maximum 10)}).samaccountname

(Get-ADGroupMember $group1).samaccountname | foreach{
    if($exclude -notcontains $PSItem){
        Add-ADGroupMember $group2 -Members $PSItem
        Remove-ADGroupMember $group1 -Members $PSItem -Confirm:$false
    }
}





<#
6.       Написать функцию рассылки писем работающим внештатным сотрудника (свойство учетной записи Staff равно $False), где тело письма это развернутый .docx файл,
Файлы для рассылки лежат в подкаталоге текущей директории (каталог со скриптом/attachments) и именуются следующим образом email.docx
(то есть файл не должен быть вложением)
#> 

function Send-MailToOut{

Import-Module ActiveDirectory
$filepath = [System.IO.Path]::Combine($PSScriptRoot,"attachments","email.docx")

$word = New-Object -ComObject Word.Application
$doc = $word.Documents.Open($filepath)
$body = $doc.Content.Text



$doc.Close()
$word.Quit()

$users = Get-ADUser -f{(Enabled -eq "True") -and (Staff -eq "False") -and (mail -ne "null")} -prop mail
foreach ($user in $users){
    Send-SmtpMail -to $user.mail -SmtpHost "smtp.domain.com" -Body $body -From "from@domain.com"
  
    }

}



#7.       Написать рекурсивную функцию поиска всех подчиненных указанного руководителя (по ФИО), необходимо учитывать только работающих сотрудников. 
function Get-UniqueManagerItem{
    
    [CmdletBinding()]
        param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$sn
    )

    Import-Module ActiveDirectory
    [array]$Manager = Get-aduser -f {sn -eq $sn} 
        if(!([bool]$manager)){
            throw "User not found"
        }
    
        if($Manager.Count -gt 1){
            Write-Host "Found some users"
            $Manager | foreach{
                Write-Host ($manager.IndexOf($PSItem) + 1) `t$PSItem 
            }
            [int]$selector = Read-Host "Which user do you need?"
            $ManagerSN = ($Manager[($selector-1)]).Surname
            
        }else{
            
            $ManagerSN = $Manager.Surname
            
        }
        return $ManagerSN
}

function Get-RecursiveDR{
    [CmdletBinding()]
        param(
        [Parameter(Mandatory)]
        [string]$sn
        )
    begin {
        $users = @()
        Import-Module ActiveDirectory
    }    
    process {
        foreach($surname in $sn){
            [array]$Managers = Get-aduser -f {sn -eq $sn} -prop directReports
            foreach($manager in $Managers){
                foreach ($DName in $Manager.directReports){ 
                    $user = Get-Aduser -f {(Enabled -eq "True") -and (DistinguishedName -eq $DName)} -prop mail, telephoneNumber
                    $obj = New-Object psobject -Property @{
                        Name = $user.name
                        mail = $user.mail
                        Phone = $user.telephoneNumber
                    }
                    $users +=$obj
                    #$user.Name
                    if ($user.sn){
                        Get-RecursiveDR -sn $user.Surname
                    }
                }
            }
        }
    }

     End{
       return $users | Sort-Object Name
     }
}


#Get-RecursiveDR -sn (Get-UniqueManagerItem -sn "Surname")
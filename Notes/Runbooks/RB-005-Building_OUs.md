I ran a help command on New-ADorganizationalunit cmdlet

I created the root OU named Chronos

I created SubOUs under Chronos

I created the finance, sales, and IT OUs under clients OU initially.

i ran a help command for redircmp unsuccessfully

plain use of the command however got me what i was looking for

I used the distinguished name of the staging OU for the redircmp command to change the default directory where objects are placed upon access into the domain.

I ran a help command on Move-ADobject 

After multiple unsuccessful attempts which involved me passing an identity flag on Move-ADobject and trying to unintentionally move the entire container rather than a single object and research on the internet, a workaround which involved me using the Get-ADComputer to extract the object name, then piping it with the Move-ADobject to move the CL01 object to the workstation OU successfully moved the object.

After going through my OU_design and what i built, i realised there was a mismatch between what i specified in the design and what i deployed, this was due to a confusion during research which led me to believe since users was a default container name, it couldn't be used to create OUs, but after further verification, i found out that wasn't the case, prompting me to change the OU from clients to users as specified in my design.

The same verification process led me to change the "Workstation" OU into "Workstations" as present in my design.

@{
   Departments = @{
    Finance = @{
        Groups = @('GG-Finance')
        OU     = 'OU=Finance,OU=Users,OU=Chronos,DC=chronos,DC=lab'
    }
    IT = @{
        Groups = @('GG-IT')
        OU     = 'OU=IT,OU=Users,OU=Chronos,DC=chronos,DC=lab'
    }
    Sales = @{
        Groups = @('GG-Sales')
        OU     = 'OU=Sales,OU=Users,OU=Chronos,DC=chronos,DC=lab'
    }
	}
	TransitionOU = 'OU=Transition,OU=Groups,OU=Chronos,DC=chronos,DC=lab'
}
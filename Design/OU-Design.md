# OU Design: chronos.lab

![OU design](OU-design.png)

## Structure

```
chronos.lab
├── Domain Controllers            (built-in; DC01 stays here)
└── Chronos                       (top-level company OU)
    ├── Users
    │   ├── Finance
    │   ├── Sales
    │   └── IT
    ├── Computers
    │   ├── Staging               (redircmp target: new machines land here)
    │   └── Workstations
    ├── Groups                    (department birthright groups + requested-access groups)
    │   └── Transition            (per-user TEMP_Expire_* shadow groups created by the mover)
    ├── Service Accounts
    └── Leavers                   (disabled leavers; inside sync scope so they show as disabled in Entra)
```

## Distinguished names

| OU                            | Distinguished name                                          |
| ----------------------------- | ----------------------------------------------------------- |
| Chronos                       | `OU=Chronos,DC=chronos,DC=lab`                              |
| Users                         | `OU=Users,OU=Chronos,DC=chronos,DC=lab`                     |
| Finance                       | `OU=Finance,OU=Users,OU=Chronos,DC=chronos,DC=lab`          |
| Sales                         | `OU=Sales,OU=Users,OU=Chronos,DC=chronos,DC=lab`            |
| IT                            | `OU=IT,OU=Users,OU=Chronos,DC=chronos,DC=lab`               |
| Computers                     | `OU=Computers,OU=Chronos,DC=chronos,DC=lab`                 |
| Staging                       | `OU=Staging,OU=Computers,OU=Chronos,DC=chronos,DC=lab`      |
| Workstations                  | `OU=Workstations,OU=Computers,OU=Chronos,DC=chronos,DC=lab` |
| Groups                        | `OU=Groups,OU=Chronos,DC=chronos,DC=lab`                    |
| Transition                    | `OU=Transition,OU=Groups,OU=Chronos,DC=chronos,DC=lab`      |
| Service Accounts              | `OU=Service Accounts,OU=Chronos,DC=chronos,DC=lab`          |
| Leavers                       | `OU=Leavers,OU=Chronos,DC=chronos,DC=lab`                   |
| Domain Controllers (built-in) | `OU=Domain Controllers,DC=chronos,DC=lab`                   |

## Reasoning

- **Top-level `Chronos` OU:** separate from the default domain containers, so company-wide policies and admin rights can be delegated without touching the defaults.
- **Separated by object type:** user policies apply to user objects and computer policies apply to computer objects, so each policy links to exactly one OU and reaches only the objects it's meant for.
- **Domain controllers:** DC01 stays in the built-in `Domain Controllers` OU, where the Default Domain Controllers Policy is linked.
- **`redircmp` target: Staging.** redircmp lands here so newly added objects can be evaluated before being redirected to their relevant OU
- **`Leavers`:** the leaver script moves disabled accounts here. It sits inside the Entra Connect sync scope, so a leaver shows as *disabled* in Entra rather than deleted, which keeps the cloud object and its audit history.
- **`Groups/Transition`:** holds only the per-user `TEMP_Expire_<expiry>_<sam>` shadow groups the mover creates, each nested into the requested-access groups the user held before moving. Keeping them in one OU means the cleanup job and the stale-group check can scope their search to it (`-SearchBase`), so neither can touch a group anywhere else, and anything in this OU past its expiry date points to a failed cleanup.
- **Birthright vs requested access is not shown by OU placement.** Department birthright groups and requested-access groups both sit in `Groups`. The classification lives in one place only, `chronos-roles.psd1`: a group listed there is birthright, and any other group is requested access. Encoding the same split in the OU structure would create a second source of truth that could drift from the file.

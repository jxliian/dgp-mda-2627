# Modelo relacional de cuentas y perfiles

La foto de perfil pertenece a la entidad común `users`. Las especializaciones de rol heredan esa propiedad al referenciar `users.username`.

```mermaid
erDiagram
    Avatar ||--o{ users : "foto de perfil"
    users ||--o| Admn : "especialización"
    users ||--o| Staff : "especialización"
    users ||--o| Student : "especialización"
    users ||--o| Parents : "especialización"

    Avatar {
        int avatar_id PK
        string avatar_alt
        bytes avatar_bin
    }
    users {
        string username PK
        string full_name
        string password
        string token
        int avatar_id_fk FK
    }
    Admn {
        string admn_usr PK,FK
    }
    Staff {
        string staff_usr PK,FK
    }
    Student {
        string stud_usr PK,FK
        string stud_access_main_col
        string stud_access_sec_col
        int stud_access_ntasks_visible
        boolean stud_access_pictograms
        boolean stud_access_contrast
        int stud_access_fontsize
        boolean stud_access_filters
        int stud_access_ndays_visible
        boolean stud_access_prof_mod
        boolean stud_access_timebar
        boolean stud_access_talkback
        boolean stud_access_profile_mod
        boolean stud_access_task_mod
    }
    Parents {
        string par_usr PK,FK
    }
```

`users.avatar_id_fk` es obligatorio y referencia `Avatar.avatar_id`. En cada alta se crea una silueta predeterminada. Al cambiar la foto se actualiza la referencia común y se retira la imagen anterior cuando ninguna cuenta la usa. Cada cuenta pertenece a una especialización de rol; solo `Student` añade los campos de accesibilidad.

Para una base nueva, la definición vigente está en [CreacionTablas.sqlscript](CreacionTablas.sqlscript). 

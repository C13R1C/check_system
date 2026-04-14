# Limpieza automática semanal (hard delete)

Se implementó una tarea de mantenimiento con hard delete real para:

1. **Foro**: elimina todos los `forum_comments` y `forum_posts`.
2. **Objetos perdidos**: elimina solo casos en estado equivalente a entregado (`RETURNED`, `DELIVERED`, `RESOLVED`, `RETURNED_TO_OWNER`), incluyendo archivo físico de evidencia si está dentro de `app/static/uploads/lostfound/`.

## Comando manual

```bash
flask weekly-hard-cleanup
```

## Programación sugerida (mínima y estable): cron

Horario preferido sin clases: **domingo por la noche**.

Ejemplo (`crontab -e` del usuario de despliegue):

```cron
30 23 * * 0 /bin/bash /ruta/a/check_system/scripts/weekly_hard_cleanup.sh >> /var/log/coyolabs_weekly_cleanup.log 2>&1
```

Si operación requiere ventana previa, alternativa segura:

```cron
30 23 * * 6 /bin/bash /ruta/a/check_system/scripts/weekly_hard_cleanup.sh >> /var/log/coyolabs_weekly_cleanup.log 2>&1
```

## Logging técnico

Cada ejecución deja traza:

- `app.logger` con totales eliminados.
- evento en `logbook_events` (`module=SYSTEM`, `action=WEEKLY_HARD_CLEANUP`) con conteos.

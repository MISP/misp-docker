# Custom MISP Scripts

Dieses Verzeichnis enthält benutzerdefinierte Skripte, die nach der MISP-Initialisierung ausgeführt werden.

## Funktionsweise

Das Custom Scripts Feature entspricht der `CUSTOM_PATH` Funktionalität aus dem MISP Docker Setup. Skripte in diesem Verzeichnis werden automatisch in den MISP Container gemountet und nach der Initialisierung ausgeführt.

## Konfiguration

1. **Aktivierung in values.yaml:**
   ```yaml
   misp:
     mispConfig:
       customScripts:
         enabled: true
         configMapName: "misp-custom-scripts"
         mountPath: "/custom"
         scripts:
           - "customize_misp.sh"
           - "custom_config.py"
   ```

2. **Skripte hinzufügen:**
   - Legen Sie Ihre Skripte in das `files/custom/` Verzeichnis
   - Unterstützte Dateitypen: `.sh`, `.py`, `.php`
   - Skripte müssen ausführbar sein (wird automatisch gesetzt)

## Verfügbare Umgebungsvariablen

Die Skripte haben Zugriff auf alle MISP Umgebungsvariablen:
- `BASE_URL` - MISP Base URL
- `ADMIN_KEY` - Admin API Key  
- `CUSTOM_PATH` - Pfad zu den Custom Scripts (z.B. `/custom`)
- `MYSQL_HOST`, `MYSQL_USER`, `MYSQL_DATABASE` - Database Verbindung
- `REDIS_HOST` - Redis Verbindung
- Alle benutzerdefinierten Variablen aus `extraVars`

## Beispiel-Skripte

### customize_misp.sh
Bash-Skript für grundlegende MISP-Konfiguration mit `cake` Befehlen.

**Benutzerdefinierte Variablen:**
```yaml
misp:
  mispConfig:
    extraVars:
      CUSTOM_ORG_NAME: "Meine Organisation"
      CUSTOM_SMTP_HOST: "mail.example.com"
      ENABLE_CUSTOM_MODULE: "true"
      CUSTOM_TAGS: "internal,critical,malware"
      DISABLE_CORRELATION: "false"
      UPDATE_WARNINGLISTS: "true"
      UPDATE_TAXONOMIES: "true"
      UPDATE_OBJECT_TEMPLATES: "true"
      UPDATE_GALAXY_CLUSTERS: "true"
```

### custom_config.py
Python-Skript für erweiterte Konfiguration mit PyMISP.

**Benötigte Pakete:** Stellen Sie sicher, dass PyMISP im Container verfügbar ist.

**Benutzerdefinierte Variablen:**
```yaml
misp:
  mispConfig:
    extraVars:
      CUSTOM_TAGS: "tag1,tag2,tag3"
      CREATE_SAMPLE_EVENT: "true"
      CUSTOM_FEEDS_JSON: |
        [
          {
            "name": "Custom Feed 1",
            "url": "https://feeds.example.com/feed1.json",
            "provider": "Example Provider",
            "enabled": true
          }
        ]
```

## Ausführungsreihenfolge

Skripte werden in der Reihenfolge ausgeführt, wie sie in der `scripts` Liste definiert sind:

1. `customize_misp.sh` (falls aktiviert)
2. `custom_config.py` (falls aktiviert)
3. Weitere Skripte...

## Best Practices

1. **Fehlerbehandlung:** Verwenden Sie `set -e` in Bash-Skripten
2. **Logging:** Nutzen Sie `echo` für Statusmeldungen  
3. **Warten auf MISP:** Prüfen Sie, ob MISP bereit ist, bevor Sie API-Calls machen
4. **Idempotenz:** Skripte sollten mehrfach ausführbar sein
5. **Umgebungsvariablen:** Nutzen Sie Umgebungsvariablen für Konfiguration
6. **Read-only Filesystem:** Skripte werden nach `/tmp` kopiert für Ausführung
7. **Working Directory:** Skripte laufen in `/var/www/MISP` Kontext
8. **Fallback-Methoden:** Verwenden Sie sowohl cake-Kommandos als auch API-Calls

## Häufige Probleme

### Problem: "Read-only file system" beim chmod
**Lösung:** Bereits gelöst - Skripte werden automatisch nach `/tmp` kopiert

### Problem: "Plugin SysLogLogable could not be found"
**Gelöst:** Skripte warten jetzt auf `/misp/readiness/ready.log` - die gleiche Prüfung wie Kubernetes Readiness Probe

### Problem: Cake-Kommandos schlagen fehl
**Gelöst:** 
- Skripte warten auf `grep -i 'MISP is ready' /misp/readiness/ready.log`
- Cake-Kommandos funktionieren zuverlässig nach dieser Prüfung
- API-Fallback verfügbar falls trotzdem Probleme auftreten

### Neue Cake-Kommandos verfügbar:
```bash
# Über Environment-Variablen steuerbar:
UPDATE_WARNINGLISTS=true      # Aktualisiert Warning Lists
UPDATE_TAXONOMIES=true        # Aktualisiert Taxonomies  
UPDATE_OBJECT_TEMPLATES=true  # Aktualisiert Object Templates
UPDATE_GALAXY_CLUSTERS=true   # Aktualisiert Galaxy Clusters
```

## Debugging

1. **Container Logs prüfen:**
   ```bash
   kubectl logs -f deployment/misp-core -c misp
   ```

2. **In Container einsteigen:**
   ```bash
   kubectl exec -it deployment/misp-core -c misp -- /bin/bash
   ```

3. **Skript manuell ausführen:**
   ```bash
   kubectl exec -it deployment/misp-core -c misp -- /custom/customize_misp.sh
   ```

## Erweiterte Nutzung

### ConfigMap manuell erstellen

Falls Sie die ConfigMap manuell erstellen möchten:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: misp-custom-scripts
data:
  customize_misp.sh: |
    #!/bin/bash
    echo "Custom script executed!"
    # Ihr Code hier
```

### Externe ConfigMap verwenden

Sie können auch eine bereits existierende ConfigMap verwenden:

```yaml
misp:
  mispConfig:
    customScripts:
      enabled: true
      configMapName: "my-existing-configmap"
```

## 🔍 **Ausführung & Logging:**

### ⚠️ **Wichtig: MISP-Start wird NIE blockiert!**
- Scripts warten automatisch bis MISP vollständig bereit ist (`/users/heartbeat`)
- MISP startet normal, Scripts laufen danach
- Kein Risiko von Startup-Verzögerungen

### Hintergrund-Ausführung (Standard)
```yaml
misp:
  mispConfig:
    customScripts:
      enabled: true
      runInBackground: true  # Standard
```
- **Ausführung**: Alle Scripts parallel im Hintergrund
- **Logs**: Start/Ende-Nachrichten sichtbar
- **Vollständige Ausgabe**: In `/var/log/custom-scripts.log`
- **Vorteil**: Schnellste Ausführung

### Sequenzielle Ausführung (Debugging)
```yaml
misp:
  mispConfig:
    customScripts:
      enabled: true
      runInBackground: false
```
- **Ausführung**: Scripts nacheinander in Reihenfolge
- **Logs**: Vollständige Ausgabe in Container Logs
- **Vorteil**: Einfaches Debugging mit `kubectl logs`
- **Verwendung**: Entwicklung und Fehlersuche

### Log-Zugriff Commands:
```bash
# Container Logs anzeigen
kubectl logs -f deployment/misp-core -c misp

# Bei Hintergrund-Ausführung: Script-Log im Container
kubectl exec -it deployment/misp-core -c misp -- tail -f /var/log/custom-scripts.log

# Script manuell testen
kubectl exec -it deployment/misp-core -c misp -- /custom/customize_misp.sh
```

## Sicherheitshinweise

- Skripte laufen mit den gleichen Berechtigungen wie der MISP Container
- Sensible Daten sollten über Secrets eingebunden werden
- Vermeiden Sie Hardcoding von Passwörtern oder API-Keys
- Testen Sie Skripte in einer Entwicklungsumgebung
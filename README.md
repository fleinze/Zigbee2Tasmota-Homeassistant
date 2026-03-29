# Zigbee2Tasmota – Home Assistant Discovery

Berry-Skript für Tasmota, das Zigbee-Geräte (verwaltet durch Zigbee2Tasmota) automatisch in Home Assistant per MQTT Discovery sichtbar macht – ohne Serial-over-TCP.

## Funktionsweise

Tasmota verwaltet das Zigbee-Netzwerk vollständig selbst. Das Skript publiziert beim Boot ein Discovery-`sensors`-Topic, sodass Home Assistant die Geräte automatisch erkennt. Anschließend werden eingehende Zigbee-Nachrichten abgefangen, die Attributnamen in HA-kompatible Keys übersetzt und ins `SENSOR`-Topic geschrieben.

```
Zigbee-Gerät
    │  (Funk)
    ▼
Tasmota (Zigbee2Tasmota)
    │  attributes_final() Handler
    ▼
MQTT Broker
    ├── tasmota/discovery/<MAC>/sensors   (retain, einmalig beim Boot)
    └── tele/tasmota_<MAC>/SENSOR         (live, bei jedem Empfang)
    │
    ▼
Home Assistant
```

## Voraussetzungen

- Tasmota mit Zigbee2Tasmota (Z2T) Support
- Berry-Unterstützung (ESP32)
- MQTT Broker (z.B. Mosquitto)
- Home Assistant mit Tasmota-Integration aktiviert

## Konfiguration

Folgender Befehl muss **einmalig** in der Tasmota-Konsole ausgeführt werden:

```
setoption83 1
```

| Option | Bedeutung |
|--------|-----------|
| `setoption83 1` | Verwendet den Friendlyname anstelle der Adresse in der Payload |

## Installation

1. Skript auf das Tasmota-Dateisystem hochladen (Tasmota Webinterface → Konsole → `upload`)
2. In autoexec.be `load('hass')` einfügen um das Skript beim Systemstart zu laden
3. Tasmota neu starten
4. In Home Assistant unter **Einstellungen → Geräte & Dienste → Tasmota** sollten die Geräte automatisch erscheinen

## Unterstützte Gerätetypen

| Zigbee-Attribut (Z2T) | MQTT-Key (HA) | Einheit |
|-----------------------|---------------|---------|
| `Temperature` | `Temperature` | °C |
| `Humidity` | `Humidity` | % |
| `RMSVoltage` | `Voltage` | V |
| `RMSCurrent` | `Current` | A |
| `ActivePower` | `Power` | W |
| `CurrentSummationDelivered` | `Total` | kWh (÷ 1000) |

**Nicht unterstützt:**
- Relais-/Schalterzustand (kein `POWER`-Topic)
- Empfang von Befehlen aus Home Assistant (read-only)

## MQTT Topics

| Topic | Retain | Inhalt |
|-------|--------|--------|
| `tasmota/discovery/<MAC>/sensors` | ja | Gerätestruktur für HA Auto-Discovery |
| `tele/tasmota_<SHORTMAC>/SENSOR` | nein | Live-Messwerte |

`<MAC>` = vollständige MAC-Adresse ohne Doppelpunkte (z.B. `AABBCCDDEEFF`)  
`<SHORTMAC>` = letzte 6 Zeichen der MAC

### Beispiel-Payload `sensors` (Discovery)

```json
{
  "sn": {
    "Time": "2026-03-29T12:00:00",
    "Wohnzimmer": { "Temperature": 21.5, "Humidity": 48.0 },
    "Mess-Steckdose": { "Voltage": 235, "Current": 0.0, "Power": 0.0, "Total": 11.555 },
    "TempUnit": "C"
  },
  "ver": 1
}
```

### Beispiel-Payload `SENSOR` (live)

```json
{
  "Time": "2026-03-29T12:00:00",
  "Mess-Steckdose": {
    "Voltage": 235,
    "Current": 0.006,
    "Power": 1.3,
    "Total": 11.556
  }
}
```

## Bekannte Einschränkungen

- **`CurrentSummationDelivered`**: Der Divisor 1000 (→ kWh) ist gerätespezifisch und muss ggf. angepasst werden. Manche Geräte liefern die Einheit in 1/10 kWh.
- Nach dem Systemstart erscheinen die Werte erst, wenn sie das erste Mal über Zigbee erneut empfangen werden.

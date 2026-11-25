# fhem_badluefter

FHEM modul zur Kontrolle eines Badlüfters mit Hilfe eines Luftfeuchte Sensors. Der Actor (Schalter) wird über den Trend der Luftfeuchte Werte für eine kontrollierte Zeit eingeschaltet.

Die Luftfeuchte wird vom Sensor periodisch abgefragt und in einer Liste gespeichert. Wenn die Luftfeuchte steigt, wird der Schalter mittel on-for-timer eingeschaltet.

## Definition

    define badluefter BadLuefter <HumidityDevice> <HumidityReading> <SchalterDevice>

## DefMod

    defmod badluefter BadLuefter HM_633ADB_Climate humidity schalterbadfeuchte2
    attr badluefter Interval 60
    attr badluefter room TEST
  
    setstate badluefter off
    setstate badluefter 2026-11-25 08:46:24 ValueList 75, 75, 75, 75, 75, 75, 75, 75, 75
    setstate badluefter 2026-11-25 08:46:24 state off
    setstate badluefter 2026-11-25 08:46:24 trend 0

## Set

Unterstütze Set Befehle
 
    HumidityDevice  setzt den Sensor Namen, der gelesen werden soll
    HumidityReading  setzt den Reading Namen der gelesen werden soll
    SwitchDevice  setzt den Namen des Schalter Devices

## Atribute

    Interval  Zeit Interval in Sekunde für die periodische Abfrage, Default=60 Sekunden = 1 Minute
    on_time  Zeitdauer, die der Lüfter eingeschaltet werden soll. Default=300 Sekunden = 5 Minuten
    verbose  Verbose Level für Logging
    

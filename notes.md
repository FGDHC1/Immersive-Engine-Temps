## This Document is just for my thoughts and not really relevant


## Offen

### Gauges / Anzeige
- [x] Getrennte gauge temperatur bereiche
- [x] Operating temperaturs nochmals überarbeiten
- [ ] C/H-Buchstaben an den Bogen-Enden (2D)
- [ ] UI Shows up delayed at start
- [ ] 3D HUD Dials make full turn as startup animation
- [ ] Make option available to enable 2d Hud only in 3rd person

### Phase 3 – 3D-HUD
- [ ] Helligkeits-Slider
- [ ] Option: Nadel nach Temperatur einfärben

### Engine Readiness (gehört zusammen)
- [ ] Engine is warm if vehicle is called (erst recherchieren: lässt sich das Rufen erkennen?)
- [ ] Weniger Leistung bei kaltem Motor (README Phase 3)


### Simulation / Logik
- [ ] Temperature Persistence over game restart (inkl. gelernte Max-RPM)
- [ ] Cars with a gearbox that is always high reving, are likely to have higher Temperatures. I have to investigate that a little further
- [ ] Optimising the unmounted logic
- [ ] Optimising the ambient temperature logic
- [ ] Maybe a clean up logic, that cleans up the vehicles that returned to ambient temperature

### Settings
- [ ] Implement mod config edit, maybe via Native Settings UI

### Ideen (wäre cool)
- [ ] Überhitzungs-Warnung (blinkender Text oder Symbol)
- [ ] Folgen bei Überhitzung (weniger Leistung, Rauch)
- [ ] Blaue Kaltlampe, solange der Motor nicht warm ist

## Erledigt

### Features
- [x] Timeskip detection
- [x] Implement HUD config edit
- [x] Max RPM beim ersten Auto-Eintrag aus der TweakDB lesen (lernt danach weiter)

### Phase 3 – 3D-HUD
- [x] Eigener 3D-Atlas mit Gauge-Texturen
- [x] Platzhalter-Ziffernblatt im 3D durch eigene Gauge ersetzen
- [x] Nadel drehen
- [x] Pitch 90 als Default in config (Plane liegt flach)

### Cleanup / Optimierung
#### Lua
- [x] `S.import` wird nicht mehr genutzt (Presets ersetzen es) → entfernen
- [x] `dirty` ist gemeinsam für Sim- und HUD-Tab → pro Tab trennen
- [x] "Save To this Car" setzt dirty zurück, obwohl HUD-Änderungen nicht gespeichert werden
- [x] `DEBUG.engineReadyness` fehlt in der DEBUG-Starttabelle
- [x] Funktionsname `loadVehicleValues` → `loadSimValues` (lädt auch Presets)
- [x] Scale parameter genauer machen, ist sehr nervig mit den grossen schritten
- [x] Division durch 0 bei der RPM-Normierung abgesichert (`math.max`)

#### Redscript 2D
- [x] Fest verdrahtete Werte in Felder ausgelagert: 8000 RPM, Temp-Bereich 20–120, segCount 16
- [x] `ColorForTemp`-Schwellen (100 / 115) als Felder
- [x] EngineTempSystem aus 2DHUD.reds in eigene System.reds verschieben

#### Redscript 3D
- [x] Diagnose-Logs (`ResourceExists`, "NOT FOUND") entfernt
- [x] Stage-Logs hinter Debug-Schalter (`debugLog`)
- [x] `placementDirty` entfernen (wird nicht mehr gelesen)
- [x] Feld `gauge` nach oben zu den anderen Feldern
- [x] `visualScale` in `OnHostAssemble` entfernen (wird von `ApplyPlacement` überschrieben)

#### Assets (WolvenKit)
- [x] `parameters[1]` in `iet_plate.mesh` prüfen

#### Repo
- [x] README: Codeware als Abhängigkeit eintragen


## Nicht gemacht
- [ ] ~~Ambient temperature should influence cooling (its minimal but i thik its a nice detail)~~ (keinen Bock)
- [ ] ~~Implement in 2d hud that it dissapears when in wheapon wheel~~ (hab keinen Bock)
- [ ] ~~Zeilenenden vereinheitlichen (`.gitattributes`)~~ (nicht nötig)
**Konstanten**
```
Leerlauf_RPM = 850
Standard_Max_RPM = 6000            // Startwert, wächst pro Fahrzeug bei Überschreitung
Referenz_Geschwindigkeit_Kühlung = 160 km/h

Optimale_Kühlwassertemperatur = 90°C
Optimale_Mindest_Öltemperatur = 90°C
Kritische_Kühlwassertemperatur = 118°C   (Obergrenze in Formel: 130°C)
Kritische_Öltemperatur = 150°C           (Obergrenze in Formel: 160°C)

Tiefpunkt: 5 Uhr, 20°C   |   Peak: 14 Uhr, 36°C
```

**Ambient (Timer: alle 5-10 Min neu berechnet, sonst gecacht)**
```
Anstiegsphase (5-14 Uhr, 9h) / Abklingphase (14-5 Uhr, 15h),
jeweils mit (1-cos(π·Fortschritt))/2 als weicher S-Kurve zwischen Tief- und Peak-Wert
```

**Bekannter Max-RPM pro Fahrzeug**
```
Wenn aktuelle_RPM > Bekannter_Max_RPM(Fahrzeug): Bekannter_Max_RPM(Fahrzeug) = aktuelle_RPM
Start: 6000, wächst nur, schrumpft nie
```

**Kühlwasser** (`k ≈ 0.020`, τ≈50s)
```
Ziel = 90 + RPM_normiert·25 - Speed_normiert·8
Neu = Alt + (Ziel-Alt)·k·dt
```

**Öl** (`k ≈ 0.010`, τ≈100s, folgt Kühlwasser mit +8°C Versatz)
```
Ziel = Kühlwassertemperatur + 8
Neu = Alt + (Ziel-Alt)·k·dt
```

**Engine Capacity** (abgeleitet, keine eigene Trägheit)
```
Bereitschaft = clamp01((Temp-Ambient)/(90-Ambient)) je für Kühlwasser & Öl
Capacity = clamp01(Kühlwasser_Bereitschaft·0.8 + Öl_Bereitschaft·0.2)
```

**Abkühlen wenn nicht gefahren** (Timer alle 30-60s, plus In-Game-Zeitsprung-Erkennung)
```
Verwendete_Zeit = Ingame_Sprung, falls dieser deutlich größer als der normale Timer-Wert ist,
                  sonst = normaler Timer-Wert (30-60s)
Temp = Temp + (Ambient-Temp)·Anpassungsrate_Ausgekühlt·Verwendete_Zeit
Timer wird danach immer auf 0 zurückgesetzt
```


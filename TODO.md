# TODO

Kvarvarande punkter efter sessionen 2026-11-14 (hovring, dra och släpp, ny meny,
inställningar, papperskorgen, uppdelning av `DockPanelBase.qml`).

## Nästa: inställningspanel

- [ ] **Inställningspanel från högerklickmenyn** (ny rad, till exempel
  "Dockinställningar…" under Dock-raden) där man ställer in:
  - ikonstorlek (`iconSize`, finns redan som nyckel i `dock-settings.json`)
  - hovringsgrad (`hoverScale`, finns redan; 1 = ingen förstoring)
  - bakgrund: solid eller genomskinlig, och hur genomskinlig. Idag är pillret
    hårdkodat till `Util.alpha(Color.background, 0.50)` i `DockWindow.qml`. Lägg
    till en nyckel som `backgroundOpacity` (0–1, där 1 = solid).
  Skriv direkt till skalet vid reglaget (live-förhandsvisning) och spara i
  `dock-settings.json`. Gör den som en liten `PanelWindow` med samma stil som
  menyn. Gör först punkten om att `saveSettings()` skriver över hela filen, annars
  riskerar fler nycklar att skriva över andra dockars inställningar.

## Fel och risker

- [ ] **Ikonbytardialogen visar bara få förhandsvisningar (oftast en).** I
  "Byt ikon…" visas bara ett fåtal ikoner i rutnätet, ofta bara en, trots att
  sökningen säger "23 icons found". Övriga rutor är tomma. Gäller alla appar, inte
  bara Claude. Gissning: ikonerna hämtas/laddas lazy eller asynkront (nätverk eller
  cache) och bilderna visas aldrig, eller så begränsas antalet samtidiga
  nedladdningar/delegater. Börja i `DockMenu.qml`/`DockPanelBase.qml`
  (`picker.*`, ikonsökning mot macOSicons): logga laddningsstatus per bild och
  kontrollera om `Image.status` fastnar på `Loading` eller `Error`.
- [ ] **Docken "ryckte" vid första ikonen.** När pekaren hovrar strax till vänster
  om mitten av den första ikonen på en dock börjar hela docken vibrera ett par
  pixlar fram och tillbaka. Det syns inte på de andra ikonerna. Ej reproducerat
  än. Min gissning: återkoppling vid träffytans kant. Den första ikonen
  växer och flyttar sig åt vänster (raden centreras om symmetriskt), så pekaren
  hamnar växelvis innanför och utanför ikonens `MouseArea`. Varje in- och
  utträde kör `hoverPointerChanged` och `applyLayout()` på nytt. Möjlig åtgärd:
  låt en `MouseArea` på hela raden, i den fasta viloramen, avgöra vilken ikon som
  hovras (`slotIndexAt`) och driva tooltip och förstoring därifrån, så att
  hovringen inte beror på ikonernas animerade geometri. Börja med att
  logga `hoveredItemId` och `hoveredMouseX` per bildruta och se om `itemId`
  växlar.
- [ ] **`saveSettings()` skriver över hela `dock-settings.json`.** `serializeSettings`
  skriver bara dockens egna nycklar. Filen delas med andra Omarchy-dockar
  (`~/.config/omarchy/dock-settings.json` har till exempel `dockEnabled`,
  `widgetsEnabled`, `dockWidgets`). Läs in den befintliga filen och slå ihop
  nycklarna i stället för att ersätta den. Kontrollera först om det redan hänt.
- [ ] **Första-parts-dockens lager (`omarchy-dock`, ca 207 px högt längst ned)**
  överlappar vår dock på båda skärmarna. Kolla om det stjäl pekaren över de
  nedersta pixlarna eller stör kantzonen.
- [ ] **Sidodockor:** avståndet längs sidan är en tumregel (`effSlotWidth =
  max(slotWidth, iconSize + 10)`). Träffytan i `DockItem` är högre än platsen
  (`iconSize + 18`), så grannarna överlappar lite. Gör träffytan lika hög som
  platsen, eller räkna ut höjden från prickens storlek.

## Förbättringar

- [ ] `hoverEffect: "magnify" | "lift" | "none"` (från ursprungsplanen) och
  `magnifyReach` som inställning. Idag finns bara `iconSize` och `hoverScale`.
- [ ] Ta bort död kod i `DockItem.qml`: `y: -targetLift`, dess `Behavior` och
  `targetLift`-plumbingen (ankring via `anchors.centerIn` gör att `y` aldrig gäller).
- [ ] Menyn: fler språk än `i18n/en.json`. Kontrollera att nya nycklar
  (`menu.keepInDock`, `menu.closeAll` m.fl.) finns överallt.
- [ ] Fönstertitlar i menyn: begränsa längd och antal (idag max 8, elidering).

## Uppdelning av `DockPanelBase.qml` (2 208 rader kvar)

- [ ] Lyft ut miniatyr- och ikonflödet (`snapshotWindows`, `thumbnail*`,
  `nativeIcon*`, ca 500 rader) till en egen tjänst.
- [ ] Lyft ut Alt+Tab-logiken (`buildAltTabApps`, `altTab*`, MRU).
- [ ] Lyft ut inställnings- och pin-filerna (`FileView`, `saveSettings`, `savePinned`).
- [ ] Lyft ut Hyprland-anslutningarna (`Connections`, `activeToplevelInfo`).
- [ ] Överväg att slå ihop `DockPanel.qml` / `DockPanelBase.qml` och
  `DockModel.js` / `DockModelBase.js`, som nu bara är tunna omslag.

## Test

- [ ] Det finns inga tester på QML-nivå, bara på modellen. Lägg till ett enkelt
  rökprov (starta skalet, läs `screenState`, kontrollera loggen).
- [ ] Hovring och drag kunde inte testas automatiskt: syntetiska pekarrörelser
  (`hyprctl dispatch movecursor`) nådde inte docken på ett pålitligt sätt.

## Uppströms (diskuteras nästa gång)

- [ ] PR #28 (papperskorgen) väntar på granskning:
  https://github.com/ifubaraboye/omarchy-dock/pull/28
- [ ] Besluta hur resten ska skickas uppströms utan att trampa någon på tårna, och om
  forken ska publiceras som ett eget projekt. Kandidater till små PR:er:
  fixen för dra och släpp (opacity 0 avbryter musgreppet), konfigurerbara
  storlekar, den kompakta menyn och den nya förstoringsmotorn.
- [ ] `main` i forken ligger före upstream med fyra commits (se `git log
  upstream/main..main`). Bestäm om forken ska följa upstream (`git merge
  upstream/main`) eller gå sin egen väg.

## Lokalt

- [ ] `~/.config/omarchy/plugins/macos.dock` är en symlänk till detta repo.
  Din gamla klon ligger i `~/.config/omarchy/backups/macos.dock-clone-2026-11-14`
  och kan tas bort när du är nöjd.

# TODO

Kvarvarande punkter efter sessionen 2026-11-14 (hovring, dra och släpp, ny meny,
inställningar, papperskorgen, uppdelning av `DockPanelBase.qml`).

## Issues

Buggar och funktioner följs som issues på https://github.com/pkenell/omarchy-dock/issues:

- #1 Inställningspanel (gör först #4)
- #2 Ikonbytardialogen visar få förhandsvisningar
- #3 Docken ryckte vid första ikonen
- #4 `saveSettings()` skriver över `dock-settings.json`
- #5 Första-parts-dockens lager överlappar
- #6 Sidodockor: träffyta högre än platsen

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

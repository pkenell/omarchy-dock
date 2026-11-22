# Överlämning: "Hämta fönster hit" i dockmenyn

Status: byggt på grenen `feat/bring-windows-here` (2026-11-22). Enhetstesterna går igenom
och dispatcherna är provade i en nästlad Hyprland. Kvar: prova i menyn på riktigt och i
Gliff-scenariot (se Test).

Beslut som togs när funktionen byggdes:

- Minimerade fönster (`special:minimized`) hämtas också. `gatherWindowsForApp()` satte
  tidigare alltid `minimized: false`, eftersom Hyprlands IPC saknar fältet. Nu läses det
  från arbetsytans namn.
- Fönster på andra specialarbetsytor (till exempel scratchpad) lämnas där de är.
- Flytande fönster från en annan skärm centreras med `hl.dsp.window.center`. I nästlat
  test räknade Hyprland redan om positionen till den nya skärmen, så centreringen är en
  extra säkerhet.
- Texten: "Hämta fönster hit" eller "Hämta 3 fönster hit" (`menu.bringHere`, med plural).

## Bakgrund

På 172.16.16.52 (`nucomarchy`, ingen fysisk skärm) körs skrivbordet via Gliff, både från
Gliff-appen och från webbklienten i `~/Projects/portainer/gliff_web`. Med `--headless`
skapar varje Gliff-session en egen virtuell skärm (`gliff-<pid>`) och tar bort den när
sessionen slutar. Hyprland flyttar då den skärmens arbetsytor till en annan skärm (till
exempel `hypr-rdp`). Nästa session får en ny skärm med en tom arbetsyta, och fönstren från
förra sessionen ligger kvar på en skärm som inte syns. Docken visar att programmet körs,
men det finns inget sätt att få tillbaka fönstret.

Samma sak gäller vanliga flerskärmsuppsättningar: ett fönster på en annan skärm eller
arbetsyta går att fokusera från menyn, men inte flytta till den skärm man arbetar på.

## Funktionen

Högerklick på en programikon → **Hämta fönster hit**. Alla programmets fönster som inte
ligger på den fokuserade skärmens aktiva arbetsyta flyttas dit, och det sista får fokus.

- Raden visas bara när minst ett fönster ligger någon annanstans.
- Om det rör sig om flera fönster kan antalet stå i texten: "Hämta 3 fönster hit".
- Tillägg (valfritt): markera i fönsterlistan vilka fönster som ligger på en annan skärm
  eller arbetsyta, och låt ett klick på ett sådant fönster hämta just det fönstret i stället
  för att hoppa dit. Bestäm beteendet innan det byggs; idag hoppar klicket till fönstret.

## Var i koden

| Vad | Var |
|---|---|
| Menyns rader | `DockMenu.qml`, `buildRows()`: lägg raden efter fönsterlistan (före "Nytt fönster"). `windows` är redan en egenskap. |
| Fönsterlistan till menyn | `DockPanelBase.qml`, `openMenu()` anropar `gatherWindowsForApp(id)`, som redan ger `workspaceId`, `minimized` och `address` per fönster. Lägg till skärmen (`ipc.monitor`) om listan ska visa den. |
| Åtgärden | `DockPanelBase.qml`, `menuAction()`: ny gren `bringHere` → ny funktion `bringWindowsHere(item.id)`. |
| Urvalet (ren logik) | `DockModelBase.js`: till exempel `windowsToBring(windows, targetWorkspaceId)`, så att det kan testas i `tests/DockModel.test.js` (`tests/run.sh`). |
| Texter | `i18n/en.json` och `i18n/sv.json`, till exempel `menu.bringHere`: "Move windows here" / "Hämta fönster hit". Nya nycklar måste in i alla språkfiler. |

## Hyprland-anropen

Det här Omarchy-bygget använder Hyprlands Lua-syntax för dispatchers (se kommentaren i
`focusWindowAddress()`). Syntaxen nedan är hämtad från kod som redan körs, inte provad
fristående:

- Flytta ett fönster utan att följa med:
  `hl.dsp.window.move({ workspace = "<id>", follow = false, window = "address:0x…" })`.
  Förlagor: `/usr/share/omarchy/default/hypr/monitor-workspaces.lua` (rad ~462) och
  Omarchys egen dock, `/usr/share/omarchy/shell/plugins/dock/Dock.qml`, `bringForward()`
  (rad ~190–214). Där återställs ett minimerat fönster till den aktiva arbetsytan på exakt
  det här sättet, med `no_anim` medan det flyttas.
- Målarbetsytan: `Hyprland.focusedMonitor.activeWorkspace.id` (samma som `bringForward()`).
  Avbryt om id:t är mindre än 1 (specialarbetsytor har negativa id).
- Fokus efteråt: använd den befintliga `focusWindowAddress()`, som redan hanterar att
  pekaren inte ska hoppa (`no_warps`).

Skiss:

```js
function bringWindowsHere(id) {
  var monitor = Hyprland.focusedMonitor
  var target = monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
  if (!(target >= 1)) return
  var moved = DockModel.windowsToBring(root.gatherWindowsForApp(id), target)
  for (var i = 0; i < moved.length; i++) {
    var address = moved[i].address.indexOf("0x") === 0 ? moved[i].address : "0x" + moved[i].address
    Hyprland.dispatch("hl.dsp.window.move({ workspace = \"" + target + "\", follow = false, window = \"address:" + address + "\" })")
  }
  if (moved.length > 0) root.focusWindowAddress(moved[moved.length - 1].address)
}
```

## Öppna frågor

- **Flytande fönster** behåller sina koordinater från den gamla skärmen och kan hamna
  utanför den nya. Ta reda på hur de ska placeras, till exempel genom att centrera dem
  efter flytten. Kontrollera dispatcherns namn i Omarchys Lua-filer innan den används;
  gissa inte.
- **Minimerade fönster**: ska de också hämtas och visas? `bringForward()` gör så för ett
  fönster i taget, så det är rimligt.
- **Skärmen måste ha en dock.** Kontrollera att docken dyker upp på en ny Gliff-skärm.
  `DockPanelBase.qml` lyssnar på `monitoradded`/`monitorremoved` (rad ~1991), men det är
  inte provat med Gliffs skärmar.

## Test

- Kör dispatchers mot en **nästlad Hyprland** först. Otestade dispatchers via
  `hyprctl eval` har kraschat sessionen tidigare.
- Var försiktig med att skapa och ta bort virtuella skärmar för hand (`hyprctl output
  create headless` / `output remove`). Enligt Gliffs `hardware-quirks.md` kan Hyprland
  0.56.2 krascha (SIGABRT) om en skärm tas bort medan muspekaren fångas på den.
- Riktigt scenario: öppna ett program i en Gliff-session på 172.16.16.52, koppla från,
  anslut igen, högerklicka på ikonen → **Hämta fönster hit**. Fönstret ska dyka upp på den
  nya skärmen med fokus.
- Enhetstest av `windowsToBring()`: fönster på målarbetsytan, på andra arbetsytor och
  minimerade, samt ett tomt resultat.

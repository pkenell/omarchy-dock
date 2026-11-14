const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const vm = require("node:vm")

function loadQmlJs(path) {
  const source = fs.readFileSync(path, "utf8").replace(/^\.pragma library\s*/, "")
  const context = { module: { exports: {} }, console }
  // Provide a minimal Qt mock so Qt.include works under Node.js.
  context.Qt = {
    include: (includePath) => {
      const incSource = fs.readFileSync(includePath, "utf8").replace(/^\.pragma library\s*/, "")
      vm.runInNewContext(incSource, context, { filename: includePath })
    }
  }
  vm.runInNewContext(source, context, { filename: path })
  return context.module.exports
}

const model = loadQmlJs("DockModel.js")

test("parses and normalizes pinned ids", () => {
  assert.deepEqual(Array.from(model.parsePinned('{"pinned":["code.desktop","code","ghostty"]}')), ["code", "ghostty"])
})

test("merges app-library and desktop entries for installed apps without windows", () => {
  const merged = model.mergeAppEntries(
    [{ entry: { id: "running.desktop", name: "Running", icon: "running-icon" } }],
    [
      { id: "running.desktop", name: "Duplicate", icon: "duplicate-icon" },
      { id: "idle.desktop", name: "Idle App", icon: "idle-icon" },
    ],
  )

  assert.deepEqual(JSON.parse(JSON.stringify(merged)), [
    { id: "running", name: "Running", icon: "running-icon" },
    { id: "idle", name: "Idle App", icon: "idle-icon" },
  ])
})

test("merged app entries preserve searchable names and ids", () => {
  const merged = model.mergeAppEntries([], [
    { desktopId: "org.example.Writer.desktop", displayName: "Writer" },
    { id: "terminal", name: "Terminal", iconName: "kitty" },
  ])

  assert.equal(merged[0].id, "org.example.Writer")
  assert.equal(merged[0].name, "Writer")
  assert.equal(merged[1].id, "terminal")
  assert.equal(merged[1].icon, "kitty")
})

test("round trips pins", () => {
  assert.deepEqual(Array.from(model.parsePinned(model.serializePinned(["code", "ghostty"]))), ["code", "ghostty"])
})

test("serializePinned persists the full order alongside pins", () => {
  const content = model.serializePinned(["spotify"], ["firefox", "terminal", "vscode", "spotify", "files"])
  const parsed = JSON.parse(content)
  assert.deepEqual(Array.from(parsed.pinned), ["spotify"])
  assert.deepEqual(Array.from(parsed.order), ["firefox", "terminal", "vscode", "spotify", "files"])
  assert.equal(parsed.version, 1)
})

test("parseOrder reads the order field and falls back safely", () => {
  const content = model.serializePinned(["a"], ["x", "a", "y"])
  assert.deepEqual(Array.from(model.parseOrder(content, [])), ["x", "a", "y"])
  assert.deepEqual(Array.from(model.parseOrder('{"pinned":["a"]}', ["old"])), ["old"])
  assert.deepEqual(Array.from(model.parseOrder("not json", ["old"])), ["old"])
  assert.deepEqual(Array.from(model.parseOrder("", ["old"])), ["old"])
  assert.deepEqual(Array.from(model.parseOrder('{"order":["a","a","b.desktop"]}', [])), ["a", "b"])
})

test("restored order is a preference, not an authority", () => {
  const restored = model.reconcileDockOrder(["a", "b", "c", "d"], ["a", "c", "d"], ["a", "c", "d"])
  assert.deepEqual(Array.from(restored), ["a", "c", "d"])
  const afterLaunch = model.reconcileDockOrder(restored, ["a", "c", "d"], ["a", "b", "c", "d"])
  assert.deepEqual(Array.from(afterLaunch), ["a", "c", "d", "b"])
})

test("acceptance: pin keeps position, survives restart, unpin removes", () => {
  let dockOrder = model.reconcileDockOrder([], [], ["firefox", "terminal", "vscode", "spotify", "files"])
  const persisted = model.serializePinned(["spotify"], dockOrder)
  let pinned = model.parsePinned(persisted, [])
  let restored = model.parseOrder(persisted, [])
  assert.deepEqual(Array.from(pinned), ["spotify"])

  // Pin does not reorder: membership changes, order does not.
  const before = dockOrder.join("|")
  dockOrder = model.reconcileDockOrder(dockOrder, pinned, ["firefox", "terminal", "vscode", "spotify", "files"])
  assert.equal(dockOrder.join("|"), before)

  // Spotify closes; restart with only some apps running: it stays mid-dock.
  dockOrder = model.reconcileDockOrder(restored, pinned, ["firefox", "terminal", "vscode"])
  assert.deepEqual(Array.from(dockOrder), ["firefox", "terminal", "vscode", "spotify"])

  // Unpin, close, restart: Spotify gone; relaunch appends at the end.
  pinned = model.removePinned(pinned, "spotify")
  dockOrder = model.reconcileDockOrder(dockOrder, pinned, ["firefox", "terminal", "vscode"])
  assert.equal(dockOrder.indexOf("spotify"), -1)
  dockOrder = model.reconcileDockOrder(dockOrder, pinned, ["firefox", "terminal", "vscode", "spotify"])
  assert.deepEqual(Array.from(dockOrder), ["firefox", "terminal", "vscode", "spotify"])
})

test("toggles and reorders pins", () => {
  assert.deepEqual(Array.from(model.togglePinned(["a"], "b")), ["a", "b"])
  assert.deepEqual(Array.from(model.togglePinned(["a", "b"], "a")), ["b"])
  assert.deepEqual(Array.from(model.reorderPinned(["a", "b", "c"], 0, 2)), ["b", "c", "a"])
})

test("builds pinned and running items with Downloads and Trash after a separator", () => {
  const items = model.buildDockItems(["a"], [{ id: "a", name: "A" }, { id: "b", name: "B" }], ["a", "b"])
  assert.equal(items[0].running, true)
  assert.equal(items[0].pinned, true)
  assert.equal(items[1].id, "b")
  assert.equal(items[1].pinned, false)
  assert.equal(items[1].running, true)
  assert.deepEqual(Array.from(items.map(item => item.id)), ["a", "b", "__separator__", "downloads", "trash"])
  assert.equal(items[2].separator, true)
  assert.equal(items[3].icon, "folder-download")
  assert.equal(items[3].special, true)
  assert.equal(items[3].pinned, false)
  assert.equal(items[4].icon, "user-trash")
  assert.equal(items[4].running, false)
})

test("special section stays after apps and honors showDownloads/showTrash", () => {
  const full = model.appendSpecialItems(model.buildFlow(["a", "downloads", "b"], ["x"], "b", 1), { trashFull: false })
  assert.deepEqual(Array.from(full.map(item => item.id)), ["a", "__phantom__", "x", "__separator__", "downloads", "trash"])
  assert.equal(full[3].separator, true)
  assert.equal(full[4].icon, "folder-download")
  assert.equal(full[5].icon, "user-trash")

  const fullTrash = model.buildDockItems(["pin"], [], ["run"], { showDownloads: true, showTrash: true, trashFull: true })
  assert.deepEqual(Array.from(fullTrash.map(item => item.id)), ["pin", "run", "__separator__", "downloads", "trash"])
  assert.equal(fullTrash[fullTrash.length - 1].icon, "user-trash-full")

  const trashOnly = model.buildDockItems(["a"], [], ["b"], { showDownloads: false, showTrash: true, trashFull: true })
  assert.deepEqual(Array.from(trashOnly.map(item => item.id)), ["a", "b", "__separator__", "trash"])
  assert.equal(trashOnly[3].icon, "user-trash-full")

  const downloadsOnly = model.appendSpecialItems([{ id: "a" }], { showDownloads: true, showTrash: false })
  assert.deepEqual(Array.from(downloadsOnly.map(item => item.id)), ["a", "__separator__", "downloads"])

  const appsOnly = model.buildDockItems(["downloads", "a"], [], ["trash", "b"], { showDownloads: false, showTrash: false })
  assert.deepEqual(Array.from(appsOnly.map(item => item.id)), ["a", "b"])
  assert.equal(appsOnly.some(item => item.separator), false)
})

test("special ids are stripped from the reorderable dock", () => {
  assert.equal(model.isSpecialId("downloads"), true)
  assert.equal(model.isSpecialId("trash.desktop"), true)
  assert.equal(model.isSpecialId("__separator__"), true)
  assert.equal(model.isSpecialId("firefox"), false)
  assert.deepEqual(Array.from(model.stripSpecialIds(["firefox", "downloads", "trash", "__separator__", "files"])), ["firefox", "files"])
})

test("separator keeps its own width and does not magnify", () => {
  const opts = model.LAYOUT_OPTS
  const flow = model.appendSpecialItems([{ id: "a" }, { id: "b" }], { showDownloads: true, showTrash: true })
  const rest = model.computeLayout(flow, -1, opts)
  const separatorX = opts.slotWidth * 2 + opts.spacing * 2
  assert.equal(rest.placements.__separator__.x, separatorX)
  assert.equal(rest.placements.downloads.x, separatorX + opts.separatorWidth + opts.spacing)
  assert.equal(rest.placements.trash.x, rest.placements.downloads.x + opts.slotWidth + opts.spacing)
  assert.ok(rest.placements.trash.x > rest.placements.b.x, "specials sit after the apps")

  const center = rest.placements.__separator__.x + opts.separatorWidth / 2
  const mag = model.computeLayout(flow, center, opts)
  assert.equal(mag.placements.__separator__.scale, 1)
  assert.equal(mag.placements.__separator__.width, opts.separatorWidth)
  assert.equal(mag.placements.a.scale >= 1, true)
})

test("write guard ignores matching content", () => {
  model.resetWrittenGuard()
  model.markWritten("hello")
  assert.equal(model.shouldReprocess("hello"), false)
  assert.equal(model.shouldReprocess("world"), true)
})

test("inserts and removes pins", () => {
  assert.deepEqual(Array.from(model.insertPinned(["a", "c"], "b", 1)), ["a", "b", "c"])
  assert.deepEqual(Array.from(model.insertPinned(["a"], "x", 5)), ["a", "x"])
  assert.deepEqual(Array.from(model.insertPinned(["a", "b"], "b", 0)), ["a", "b"])
  assert.deepEqual(Array.from(model.removePinned(["a", "b", "c"], "b")), ["a", "c"])
  assert.deepEqual(Array.from(model.removePinned(["a"], "z")), ["a"])
})

test("buildFlow inserts phantom among pinned and appends running unpinned", () => {
  assert.deepEqual(Array.from(model.buildFlow(["a", "b", "c"], ["x", "y"], "", -1).map(i => i.id)), ["a", "b", "c", "x", "y"])
  assert.deepEqual(Array.from(model.buildFlow(["a", "b", "c"], [], "", 1).map(i => i.id)), ["a", "__phantom__", "b", "c"])
  assert.deepEqual(Array.from(model.buildFlow(["a", "b", "c"], [], "", 0).map(i => i.id)), ["__phantom__", "a", "b", "c"])
  assert.deepEqual(Array.from(model.buildFlow(["a", "b", "c"], [], "", 3).map(i => i.id)), ["a", "b", "c", "__phantom__"])
  assert.equal(model.buildFlow(["a", "b", "c"], [], "", 1).filter(i => i.phantom).length, 1)
})

test("buildFlow excludes the floating item", () => {
  assert.deepEqual(Array.from(model.buildFlow(["a", "b", "c"], ["x"], "b", 1).map(i => i.id)), ["a", "__phantom__", "c", "x"])
  assert.deepEqual(Array.from(model.buildFlow(["a"], ["x", "y"], "y", -1).map(i => i.id)), ["a", "x"])
})

test("buildFlow phantom tracks the full flow including running apps", () => {
  assert.deepEqual(Array.from(model.buildFlow(["a"], ["x", "y"], "y", 1).map(i => i.id)), ["a", "__phantom__", "x"])
  assert.deepEqual(Array.from(model.buildFlow(["a"], ["x", "y"], "y", 2).map(i => i.id)), ["a", "x", "__phantom__"])
  assert.deepEqual(Array.from(model.buildFlow(["a"], ["x", "y"], "x", 0).map(i => i.id)), ["__phantom__", "a", "y"])
  assert.deepEqual(Array.from(model.buildFlow(["a"], ["x", "y"], "y", 9).map(i => i.id)), ["a", "x", "__phantom__"])
})

test("pinnedIndexForInsertion maps a full-flow index into the pinned cluster", () => {
  const pinned = ["a", "b"]
  const running = ["x", "y"]
  assert.deepEqual(Array.from(model.buildDockOrder(pinned, running, [])), ["a", "b", "x", "y"])
  assert.deepEqual(Array.from(model.buildDockOrder(pinned, running, ["a", "x", "b", "y"])), ["a", "b", "x", "y"])
})

test("buildDockOrder preserves the previous relative order of running apps", () => {
  assert.deepEqual(Array.from(model.buildDockOrder(["a"], ["x", "y"], ["a", "y", "x"])), ["a", "y", "x"])
  assert.deepEqual(Array.from(model.buildDockOrder(["a"], ["x", "y", "z"], ["a", "y", "x"])), ["a", "y", "x", "z"])
})

test("reconcileDockOrder keeps session slots and appends new apps", () => {
  assert.deepEqual(Array.from(model.reconcileDockOrder(["a", "x", "y"], ["a"], ["a", "x", "y"])), ["a", "x", "y"])
  assert.deepEqual(Array.from(model.reconcileDockOrder(["a", "x"], ["a"], ["a", "x", "y"])), ["a", "x", "y"])
  assert.deepEqual(Array.from(model.reconcileDockOrder(["a", "x", "y"], ["a"], ["a", "x"])), ["a", "x"])
  assert.deepEqual(Array.from(model.reconcileDockOrder(["x"], ["a", "b"], ["x"])), ["x", "a", "b"])
})

test("moveInOrder reorders any app without touching the pinned list", () => {
  assert.deepEqual(Array.from(model.moveInOrder(["a", "x", "y"], "x", 0)), ["x", "a", "y"])
  assert.deepEqual(Array.from(model.moveInOrder(["a", "x", "y"], "y", 1)), ["a", "y", "x"])
  assert.deepEqual(Array.from(model.moveInOrder(["a", "x"], "z", 2)), ["a", "x", "z"])
  assert.deepEqual(Array.from(model.moveInOrder(["a", "x", "y"], "a", 0)), ["a", "x", "y"])
})

test("orderPinned keeps only pinned members in order", () => {
  assert.deepEqual(Array.from(model.orderPinned(["b", "x", "a"], ["a", "b"])), ["b", "a"])
  assert.deepEqual(Array.from(model.orderPinned(["x", "y"], ["a"])), ["a"].filter(i => ["x", "y"].includes(i)))
  assert.deepEqual(Array.from(model.orderPinned(["x", "a", "y"], ["a"])), ["a"])
})

test("computeLayout rests evenly with no cursor and grows with magnification", () => {
  const opts = model.LAYOUT_OPTS
  const flow = [{ id: "a" }, { id: "b" }, { id: "c" }]
  const rest = model.computeLayout(flow, -1, opts)
  assert.equal(rest.totalWidth, opts.slotWidth * 3 + opts.spacing * 2 + 2 * opts.sidePadding)
  assert.equal(rest.restWidth, opts.slotWidth * 3 + opts.spacing * 2)
  assert.deepEqual({ ...rest.placements.a }, { x: 0, width: opts.slotWidth, scale: 1, lift: 0, phantom: false })
  assert.equal(rest.placements.b.x, opts.slotWidth + opts.spacing)
  assert.equal(rest.placements.c.x, 2 * (opts.slotWidth + opts.spacing))

  const center = rest.placements.b.x + opts.slotWidth / 2
  const mag = model.computeLayout(flow, center, opts)
  assert.ok(mag.placements.b.scale > 1, "hovered icon magnifies")
  assert.ok(mag.placements.a.scale < mag.placements.b.scale, "neighbors are smaller than hovered icon")
  assert.ok(mag.totalWidth > rest.totalWidth, "dock grows as the cursor approaches")
})

test("magnified icons sit edge to edge for any hoverScale", () => {
  const flow = Array.from({ length: 8 }, (_, i) => ({ id: "i" + i }))
  for (const hoverScale of [1.2, 1.6, 2.0]) {
    const opts = { ...model.LAYOUT_OPTS, hoverScale }
    for (let cursor = 0; cursor <= 8 * (opts.slotWidth + opts.spacing); cursor += 7) {
      const { placements } = model.computeLayout(flow, cursor, opts)
      for (let i = 0; i < flow.length - 1; i++) {
        const a = placements["i" + i]
        const b = placements["i" + (i + 1)]
        assert.ok(Math.abs(b.x - (a.x + a.width + opts.spacing)) < 1e-9, `gap at ${i} (scale ${hoverScale}, cursor ${cursor})`)
      }
    }
  }
})

test("magnification stays centered on the resting row", () => {
  const opts = { ...model.LAYOUT_OPTS, hoverScale: 1.8 }
  const flow = Array.from({ length: 5 }, (_, i) => ({ id: "i" + i }))
  const r = model.computeLayout(flow, 20, opts)
  const first = r.placements.i0
  const last = r.placements.i4
  const left = -first.x
  const right = last.x + last.width - r.restWidth
  assert.ok(Math.abs(left - right) < 1e-9, "grows equally on both sides")
})

test("layout moves continuously with the pointer", () => {
  const opts = { ...model.LAYOUT_OPTS, hoverScale: 1.8 }
  const flow = Array.from({ length: 6 }, (_, i) => ({ id: "i" + i }))
  let prev = model.computeLayout(flow, 0, opts)
  for (let c = 1; c <= 6 * (opts.slotWidth + opts.spacing); c++) {
    const next = model.computeLayout(flow, c, opts)
    for (const id of Object.keys(prev.placements))
      assert.ok(Math.abs(next.placements[id].x - prev.placements[id].x) < 2, `jump for ${id} at ${c}`)
    prev = next
  }
})

test("amount 0 is the resting layout and amount fades the effect", () => {
  const opts = model.LAYOUT_OPTS
  const flow = [{ id: "a" }, { id: "b" }, { id: "c" }]
  const rest = model.computeLayout(flow, -1, opts)
  const off = model.computeLayout(flow, 40, { ...opts, amount: 0 })
  assert.deepEqual(JSON.parse(JSON.stringify(off)), JSON.parse(JSON.stringify(rest)))
  const half = model.computeLayout(flow, 40, { ...opts, amount: 0.5 })
  const full = model.computeLayout(flow, 40, opts)
  assert.ok(half.placements.a.scale > 1 && half.placements.a.scale < full.placements.a.scale)
})

test("slotIndexAt is stable with the placeholder anywhere", () => {
  const opts = model.LAYOUT_OPTS
  const stride = opts.slotWidth + opts.spacing
  for (let phantom = 0; phantom <= 3; phantom++) {
    const flow = model.buildFlow(["a", "b", "c"], [], "x", phantom)
    for (let slot = 0; slot < flow.length; slot++) {
      const cursor = slot * stride + opts.slotWidth / 2
      assert.equal(model.slotIndexAt(cursor, flow, opts), slot)
    }
  }
})

test("multi-item flowWidth equals the content span", () => {
  const opts = model.LAYOUT_OPTS
  const rest = model.computeLayout([{ id: "a" }, { id: "b" }], -1, opts)
  assert.equal(rest.flowWidth, opts.slotWidth + opts.spacing + opts.slotWidth)
})

test("insertionIndexFor picks the nearest slot", () => {
  const opts = model.LAYOUT_OPTS
  const stride = opts.slotWidth + opts.spacing
  const flow = [{ id: "a" }, { id: "b" }, { id: "c" }]
  assert.equal(model.insertionIndexFor(0, flow, opts), 0)
  assert.equal(model.insertionIndexFor(stride + 1, flow, opts), 1)
  assert.equal(model.insertionIndexFor(stride + opts.slotWidth, flow, opts), 2)
  assert.equal(model.insertionIndexFor(9999, flow, opts), 3)
})

test("settings parse and serialize autoHide", () => {
  assert.equal(model.parseSettings('{"autoHide":true}', { autoHide: false }).autoHide, true)
  assert.equal(model.parseSettings('{"autoHide":false}', { autoHide: true }).autoHide, false)
  assert.equal(model.parseSettings('', { autoHide: true }).autoHide, true)
  assert.equal(model.parseSettings('not json', { autoHide: false }).autoHide, false)
  assert.equal(model.parseSettings('{}', { autoHide: true }).autoHide, true)
  const s = model.serializeSettings({ autoHide: false })
  const parsed = JSON.parse(s)
  assert.equal(parsed.autoHide, false)
  assert.equal(parsed.version, 1)
  assert.equal(model.parseSettings(s, { autoHide: true }).autoHide, false)
  assert.equal(model.serializeSettings({ autoHide: true }).includes('"autoHide": true'), true)
})

test("settings parse and serialize dockSide", () => {
  assert.equal(model.parseSettings('{"dockSide":"left"}', {}).dockSide, "left")
  assert.equal(model.parseSettings('{"dockSide":"right"}', {}).dockSide, "right")
  assert.equal(model.parseSettings('{"dockSide":"top"}', {}).dockSide, "bottom")
  assert.equal(model.parseSettings('{"dockSide":"LEFT"}', {}).dockSide, "left")
  assert.equal(model.parseSettings('', {}).dockSide, "bottom")
  assert.equal(model.parseSettings('not json', { dockSide: "left" }).dockSide, "left")
  const s = model.serializeSettings({ autoHide: true, dockSide: "right" })
  const parsed = JSON.parse(s)
  assert.equal(parsed.dockSide, "right")
  assert.equal(model.parseSettings(s, {}).autoHide, true)
  assert.equal(model.parseSettings(s, {}).dockSide, "right")
  assert.equal(model.serializeSettings({ autoHide: true }).includes('"dockSide": "bottom"'), true)
  assert.equal(model.serializeSettings({ autoHide: true, dockSide: "weird" }).includes('"dockSide": "bottom"'), true)
})

test("settings default showDownloads and showTrash to true", () => {
  const defaults = model.parseSettings("{}", {})
  assert.equal(defaults.showDownloads, true)
  assert.equal(defaults.showTrash, true)
  assert.equal(model.parseSettings("", { autoHide: true }).showDownloads, true)
  assert.equal(model.parseSettings('{"showDownloads":false,"showTrash":false}', {}).showDownloads, false)
  assert.equal(model.parseSettings('{"showDownloads":false,"showTrash":false}', {}).showTrash, false)
  assert.equal(model.parseSettings('{"showDownloads":"true","showTrash":"false"}', {}).showDownloads, true)
  assert.equal(model.parseSettings('{"showDownloads":"true","showTrash":"false"}', {}).showTrash, false)
  const raw = model.serializeSettings({ autoHide: true, dockSide: "left", showDownloads: false, showTrash: true })
  const parsed = JSON.parse(raw)
  assert.equal(parsed.showDownloads, false)
  assert.equal(parsed.showTrash, true)
  assert.equal(parsed.dockSide, "left")
  assert.equal(model.parseSettings(raw, { showDownloads: true, showTrash: false }).showDownloads, false)
  assert.equal(model.parseSettings(raw, { showDownloads: true, showTrash: false }).showTrash, true)
  assert.equal(model.serializeSettings({ autoHide: true }).includes('"showDownloads": true'), true)
  assert.equal(model.serializeSettings({ autoHide: true }).includes('"showTrash": true'), true)
  // Existing files without the keys stay on.
  assert.equal(model.parseSettings('{"autoHide":false,"dockSide":"right"}', {}).showDownloads, true)
  assert.equal(model.parseSettings('{"autoHide":false,"dockSide":"right"}', {}).showTrash, true)
  assert.equal(model.parseSettings('{"autoHide":false,"dockSide":"right"}', {}).autoHide, false)
})

test("settings write guard ignores matching content", () => {
  model.resetSettingsGuard()
  model.markSettingsWritten('{"autoHide":true}\n')
  assert.equal(model.shouldReprocessSettings('{"autoHide":true}\n'), false)
  assert.equal(model.shouldReprocessSettings('{"autoHide":false}\n'), true)
})

test("auto-hide state machine: shouldHideDock and shouldScheduleHide require ready, engaged, suppressed", () => {
  const base = { autoHide: true, enabled: true, dockReady: true, autoHidden: false, dockEngaged: false, hideSuppressed: false, dockHovered: false, edgeHovered: false }
  assert.equal(model.shouldHideDock(base), true)
  assert.equal(model.shouldScheduleHide(base), true)

  // Disabled variants
  assert.equal(model.shouldHideDock({ ...base, autoHide: false }), false)
  assert.equal(model.shouldHideDock({ ...base, enabled: false }), false)
  assert.equal(model.shouldHideDock({ ...base, dockReady: false }), false)
  assert.equal(model.shouldHideDock({ ...base, autoHidden: true }), false)
  assert.equal(model.shouldHideDock({ ...base, dockEngaged: true }), false)
  assert.equal(model.shouldHideDock({ ...base, dockHovered: true }), false)
  assert.equal(model.shouldHideDock({ ...base, edgeHovered: true }), false)
  assert.equal(model.shouldHideDock({ ...base, hideSuppressed: true }), false)

  assert.equal(model.shouldScheduleHide({ ...base, dockReady: false }), false)
  assert.equal(model.shouldScheduleHide({ ...base, hideSuppressed: true }), false)
  assert.equal(model.shouldScheduleHide({ ...base, dockEngaged: true }), false)
})

test("auto-hide shouldRevealDock only when hidden and edge hovered", () => {
  const hiddenAtEdge = { autoHide: true, enabled: true, autoHidden: true, edgeHovered: true }
  assert.equal(model.shouldRevealDock(hiddenAtEdge), true)
  assert.equal(model.shouldRevealDock({ ...hiddenAtEdge, edgeHovered: false }), false)
  assert.equal(model.shouldRevealDock({ ...hiddenAtEdge, autoHidden: false }), false)
  assert.equal(model.shouldRevealDock({ ...hiddenAtEdge, autoHide: false }), false)
  assert.equal(model.shouldRevealDock({ ...hiddenAtEdge, enabled: false }), false)
})

test("auto-hide matrix: menu/picker/preview/floating/altTab suppress hide", () => {
  const idle = { autoHide: true, enabled: true, dockReady: true, autoHidden: false, dockEngaged: false, hideSuppressed: false }
  assert.equal(model.shouldHideDock(idle), true)
  assert.equal(model.shouldHideDock({ ...idle, hideSuppressed: true }), false)
  // hideSuppressed covers menu/picker/preview/floating/altTab
  assert.equal(model.shouldHideDock({ ...idle, dockEngaged: true }), false)
  assert.equal(model.shouldRevealDock({ autoHide: true, enabled: true, autoHidden: true, edgeHovered: true }), true)
  assert.equal(model.shouldRevealDock({ autoHide: true, enabled: true, autoHidden: true, edgeHovered: false }), false)
})

test("auto-hide hide→reveal→hide cycle is deterministic", () => {
  // Start visible, idle → hide
  let s = { autoHide: true, enabled: true, dockReady: true, autoHidden: false, dockEngaged: false, hideSuppressed: false, edgeHovered: false, dockHovered: false }
  assert.equal(model.shouldHideDock(s), true)
  s.autoHidden = true
  // Hidden, edge not hovered → no reveal
  assert.equal(model.shouldRevealDock(s), false)
  // Edge hovered → reveal
  s.edgeHovered = true
  s.dockEngaged = true
  assert.equal(model.shouldRevealDock(s), true)
  s.autoHidden = false
  s.edgeHovered = false
  s.dockEngaged = false
  // Back to idle → should hide again
  assert.equal(model.shouldHideDock(s), true)
  // Repeat without stuck state
  s.autoHidden = true
  s.edgeHovered = true
  s.dockEngaged = true
  assert.equal(model.shouldRevealDock(s), true)
})

test("isWebAppClass gates browser-generated classes", () => {
  assert.equal(model.isWebAppClass("firefox"), false)
  assert.equal(model.isWebAppClass("opencode"), false)
  assert.equal(model.isWebAppClass("vlc"), false)
  assert.equal(model.isWebAppClass("google-chrome"), false)
  assert.equal(model.isWebAppClass("x.com"), true)
  assert.equal(model.isWebAppClass("web.whatsapp.com"), true)
  assert.equal(model.isWebAppClass("chrome-web.whatsapp.com__-Default"), true)
  assert.equal(model.isWebAppClass("chrome-youtube.com__-Default-123"), true)
})

test("issue #19: short web-app Name does not hijack firefox", () => {
  const entries = [
    { id: "firefox", name: "Firefox" },
    { id: "X", name: "X" },
  ]
  assert.equal(model.desktopIdForWindow("firefox", entries), "firefox")
  assert.equal(model.desktopIdForWindow("opencode", entries), "opencode")
  assert.equal(model.desktopIdForWindow("vlc", entries), "vlc")
})

test("issue #19: web-app classes still resolve via Name fallback", () => {
  const entries = [
    { id: "firefox", name: "Firefox" },
    { id: "X", name: "X" },
    { id: "whatsapp", name: "WhatsApp" },
  ]
  assert.equal(model.desktopIdForWindow("x.com", entries), "X")
  assert.equal(
    model.desktopIdForWindow("chrome-web.whatsapp.com__-Default", entries),
    "whatsapp",
  )
})

test("desktopIdForWindow prefers exact id over Name fallback", () => {
  const entries = [
    { id: "X", name: "Firefox" },
    { id: "firefox", name: "Firefox" },
  ]
  assert.equal(model.desktopIdForWindow("firefox", entries), "firefox")
  assert.equal(model.desktopIdForWindow("unknown-app", entries), "unknown-app")
})

test("parses the screen mode, defaulting to every output", () => {
  assert.equal(model.parseSettings("{}", {}).screenMode, "all")
  assert.equal(model.parseSettings("", {}).screenMode, "all")
  assert.equal(model.parseSettings("not json", {}).screenMode, "all")
  assert.equal(model.parseSettings('{"screenMode":"primary"}', {}).screenMode, "primary")
  assert.equal(model.parseSettings('{"screenMode":"DP-1"}', {}).screenMode, "DP-1")
  assert.equal(model.parseSettings('{"screenMode":"  DP-1  "}', {}).screenMode, "DP-1")
  assert.equal(model.parseSettings('{"screenMode":"PRIMARY"}', {}).screenMode, "primary")
  assert.equal(model.parseSettings('{"screenMode":""}', {}).screenMode, "all")
  assert.equal(model.parseSettings('{"screenMode":42}', {}).screenMode, "all")
})

test("serializes the screen mode and round-trips it", () => {
  assert.equal(
    model.serializeSettings({ autoHide: true, screenMode: "primary" }).includes('"screenMode": "primary"'),
    true,
  )
  assert.equal(
    model.serializeSettings({ autoHide: true }).includes('"screenMode": "all"'),
    true,
  )
  const s = model.serializeSettings({ autoHide: false, dockSide: "left", screenMode: "DP-2" })
  assert.equal(model.parseSettings(s, {}).screenMode, "DP-2")
  assert.equal(model.parseSettings(s, {}).dockSide, "left")
  assert.equal(model.parseSettings(s, {}).autoHide, false)
})

test("round-trips every persisted setting together", () => {
  const settings = {
    autoHide: false,
    dockSide: "left",
    screenMode: "DP-2",
    showDownloads: false,
    showTrash: true,
    iconSize: 44,
    hoverScale: 1.8,
  }
  const parsed = model.parseSettings(model.serializeSettings(settings), {})
  assert.equal(parsed.iconSize, 44)
  assert.equal(parsed.hoverScale, 1.8)
  assert.equal(parsed.autoHide, false)
  assert.equal(parsed.dockSide, "left")
  assert.equal(parsed.screenMode, "DP-2")
  assert.equal(parsed.showDownloads, false)
  assert.equal(parsed.showTrash, true)
})

test("resolves the screen mode to output names", () => {
  const screens = [{ name: "eDP-1" }, { name: "DP-1" }]
  assert.deepEqual(Array.from(model.resolveScreenNames(screens, "all")), ["eDP-1", "DP-1"])
  assert.deepEqual(Array.from(model.resolveScreenNames(screens, "")), ["eDP-1", "DP-1"])
  assert.deepEqual(Array.from(model.resolveScreenNames(screens, "primary")), ["eDP-1"])
  assert.deepEqual(Array.from(model.resolveScreenNames(screens, "DP-1")), ["DP-1"])
  assert.deepEqual(Array.from(model.resolveScreenNames(screens, "DP-9")), ["eDP-1"])
  assert.deepEqual(Array.from(model.resolveScreenNames([], "all")), [])
})

test("computes the dock surface position on each output", () => {
  // surfaceFor lives in another VM realm: compare plain JSON, like the other tests.
  const at = (...args) => JSON.parse(JSON.stringify(model.surfaceFor(...args)))
  assert.deepEqual(at("bottom", 1920, 1200, 600, 78, 4, 0), { x: 660, y: 1118 })
  assert.deepEqual(at("right", 1920, 1200, 78, 600, 4, 0), { x: 1838, y: 300 })
  assert.deepEqual(at("left", 1920, 1200, 78, 600, 4, 0), { x: 4, y: 300 })
  assert.deepEqual(at("bottom", 2560, 1440, 600, 78, 4, 0), { x: 980, y: 1358 })
  assert.deepEqual(at("bottom", 1920, 1200, 600, 78, 4, 82), { x: 660, y: 1200 })
})

test("iconSize and hoverScale are optional, clamped settings", () => {
  const d = model.parseSettings("", {})
  assert.equal(d.iconSize, model.LAYOUT_OPTS.iconSize)
  assert.equal(d.hoverScale, model.LAYOUT_OPTS.hoverScale)
  const p = model.parseSettings('{"iconSize": 9999, "hoverScale": 0.2}', {})
  assert.equal(p.iconSize, 128)
  assert.equal(p.hoverScale, 1)
  assert.equal(model.parseSettings('{"iconSize": "x"}', { iconSize: 40 }).iconSize, 40)
})

test("serializeSettings keeps keys it does not own", () => {
  const existing = '{"dockEnabled":true,"dockWidgets":["a","b"],"dockSide":"left","autoHide":false}'
  const out = JSON.parse(model.serializeSettings({ autoHide: true, dockSide: "right" }, existing))
  assert.equal(out.dockEnabled, true)
  assert.deepEqual(out.dockWidgets, ["a", "b"])
  assert.equal(out.dockSide, "right")
  assert.equal(out.autoHide, true)
  // Broken or non-object files fall back to a fresh file.
  assert.equal(JSON.parse(model.serializeSettings({}, "not json")).version, 1)
  assert.equal(JSON.parse(model.serializeSettings({}, "[1,2]")).version, 1)
})

test("backgroundOpacity is clamped, defaults to 0.5 and round-trips", () => {
  assert.equal(model.parseSettings("{}", {}).backgroundOpacity, 0.5)
  assert.equal(model.parseSettings('{"backgroundOpacity":1}', {}).backgroundOpacity, 1)
  assert.equal(model.parseSettings('{"backgroundOpacity":0}', {}).backgroundOpacity, 0)
  assert.equal(model.parseSettings('{"backgroundOpacity":7}', {}).backgroundOpacity, 1)
  assert.equal(model.parseSettings('{"backgroundOpacity":-2}', {}).backgroundOpacity, 0)
  assert.equal(model.parseSettings('{"backgroundOpacity":"x"}', {}).backgroundOpacity, 0.5)
  assert.equal(JSON.parse(model.serializeSettings({ backgroundOpacity: 0.8 })).backgroundOpacity, 0.8)
  assert.equal(JSON.parse(model.serializeSettings({})).backgroundOpacity, 0.5)
})

test("dockPadding defaults to 22, is clamped and round-trips", () => {
  assert.equal(model.parseSettings("{}", {}).dockPadding, 22)
  assert.equal(model.parseSettings('{"dockPadding":30}', {}).dockPadding, 30)
  assert.equal(model.parseSettings('{"dockPadding":999}', {}).dockPadding, 48)
  assert.equal(model.parseSettings('{"dockPadding":0}', {}).dockPadding, 8)
  assert.equal(JSON.parse(model.serializeSettings({ dockPadding: 14 })).dockPadding, 14)
  assert.equal(JSON.parse(model.serializeSettings({})).dockPadding, 22)
})

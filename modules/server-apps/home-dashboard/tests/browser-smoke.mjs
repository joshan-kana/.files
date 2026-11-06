import { spawn } from "node:child_process";
import fs from "node:fs";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../app/static",
);
const browser =
  process.env.CHROME_BIN ||
  (process.platform === "darwin"
    ? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    : "chromium");
const logs = {
  requests: {},
  actions: [],
  streams: { home: 0, sonarr: 0, radarr: 0 },
  closed: { home: 0, sonarr: 0, radarr: 0 },
};
const entities = [
  {
    entity_id: "fan.bedroom",
    state: "on",
    attributes: {
      friendly_name: "Bedroom fan",
      percentage: 33,
      percentage_step: 33,
      supported_features: 1,
    },
  },
  {
    entity_id: "fan.lounge",
    state: "off",
    attributes: {
      friendly_name: "Lounge fan",
      percentage: 0,
      percentage_step: 33,
      supported_features: 1,
    },
  },
  {
    entity_id: "light.ledwall",
    state: "on",
    attributes: {
      friendly_name: "LEDWALL",
      brightness: 135,
      rgb_color: [220, 80, 10],
      supported_color_modes: ["rgb"],
      color_mode: "rgb",
    },
  },
  {
    entity_id: "sensor.temperature",
    state: "22",
    attributes: {
      friendly_name: "Bedroom temperature",
      unit_of_measurement: "°C",
    },
  },
];
const metadata = {
  areas: {
    "fan.bedroom": "Bedroom",
    "fan.lounge": "Lounge",
    "light.ledwall": "Bedroom",
    "sensor.temperature": "Bedroom",
  },
  devices: {
    "fan.bedroom": {
      id: "fan1",
      name: "Bedroom fan",
      room: "Bedroom",
      model: "3-speed",
    },
    "fan.lounge": {
      id: "fan2",
      name: "Lounge fan",
      room: "Lounge",
      model: "3-speed",
    },
    "light.ledwall": {
      id: "led1",
      name: "LEDWALL",
      room: "Bedroom",
      model: "LED",
    },
  },
  roomIcons: { Bedroom: "mdi:bed-king", Lounge: "mdi:sofa" },
};
const session = {
  name: "sim",
  admin: true,
  pages: { overview: true, home: true, media: true, apps: true },
  credentials: { homeassistant: true, sonarr: true, radarr: true },
  favorites: [],
  rooms: {},
  hand: "right",
  theme: "carbon",
  accent: "mint",
  show_unavailable: false,
  app_favorites: [],
  app_visits: {},
};
const mockCatalog = [
  {
    id: "jellyfin",
    name: "Jellyfin",
    category: "Media",
    url: "http://127.0.0.1:65534",
    page: "media",
  },
  {
    id: "immich",
    name: "Immich",
    category: "Photos",
    url: "http://127.0.0.1:65534",
    page: "apps",
  },
  {
    id: "paperless",
    name: "Paperless",
    category: "Documents",
    url: "http://127.0.0.1:65534",
    page: "apps",
  },
];
if (process.env.HAVEN_SMOKE_STRESS) {
  for (let index = 0; index < 250; index++) {
    const entityID = "switch.simulated_" + String(index).padStart(3, "0");
    const area = index % 2 ? "Bedroom" : "Lounge";
    entities.push({
      entity_id: entityID,
      state: "off",
      attributes: { friendly_name: "Simulated switch " + index },
    });
    metadata.areas[entityID] = area;
    metadata.devices[entityID] = {
      id: "simulated-" + index,
      name: "Simulated switch " + index,
      room: area,
      model: "Virtual fixture",
    };
  }
}
const fileNames = {
  "/": "index.html",
  "/app.js": "app.js",
  "/styles.css": "styles.css",
};
const streams = new Set();
const server = http.createServer((req, res) => {
  const url = new URL(req.url, "http://localhost");
  const p = url.pathname;
  logs.requests[p] = (logs.requests[p] || 0) + 1;
  if (p === "/api/session" || p === "/api/catalog") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify(p === "/api/session" ? session : mockCatalog));
    return;
  }
  if (p === "/api/profile/apps") {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      session.app_favorites = JSON.parse(body).favorites;
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end('{"ok":true}');
    });
    return;
  }
  if (p.startsWith("/api/apps/") && p.endsWith("/launch")) {
    const id = p.split("/")[3];
    session.app_visits[id] = (session.app_visits[id] || 0) + 1;
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ launches: session.app_visits[id] }));
    return;
  }
  if (p === "/api/profile/home") {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      const preferences = JSON.parse(body);
      session.hand = preferences.hand;
      session.show_unavailable = preferences.show_unavailable;
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end('{"ok":true}');
    });
    return;
  }
  if (p === "/api/ha/action") {
    let data = "";
    req.on("data", (x) => (data += x));
    req.on("end", () => {
      logs.actions.push(JSON.parse(data));
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end('{"ok":true}');
    });
    return;
  }
  if (p === "/api/ha/events" || p.startsWith("/api/arr/events/")) {
    const key =
      p === "/api/ha/events"
        ? "home"
        : p.endsWith("/sonarr")
          ? "sonarr"
          : "radarr";
    logs.streams[key]++;
    res.writeHead(200, {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-store",
    });
    const send = (name, data) => {
      if (!res.destroyed)
        res.write(
          "event: " + name + "\ndata: " + JSON.stringify(data) + "\n\n",
        );
    };
    const timers = [];
    const after = (ms, fn) => timers.push(setTimeout(fn, ms));
    if (key === "home") {
      after(80, () => send("snapshot", { entities }));
      after(130, () => send("metadata", metadata));
      after(1450, () =>
        send("delta", {
          changes: [
            {
              ...entities[0],
              attributes: { ...entities[0].attributes, percentage: 66 },
            },
          ],
          removed: [],
        }),
      );
    } else {
      after(120, () =>
        send("queue", {
          totalRecords: 1,
          records: [
            {
              id: 1,
              title: key + " test item",
              status: "queued",
              size: 100,
              sizeleft: 90,
            },
          ],
        }),
      );
      after(900, () =>
        send("queue", {
          totalRecords: 1,
          records: [
            {
              id: 1,
              title: key + " test item",
              status: "downloading",
              size: 100,
              sizeleft: 20,
            },
          ],
        }),
      );
    }
    streams.add(res);
    req.on("close", () => {
      logs.closed[key]++;
      streams.delete(res);
      timers.forEach(clearTimeout);
    });
    return;
  }
  if (p in fileNames) {
    const name = fileNames[p];
    res.writeHead(200, {
      "Content-Type": name.endsWith(".js")
        ? "application/javascript"
        : name.endsWith(".css")
          ? "text/css"
          : "text/html",
    });
    if (name === "app.js")
      res.end(
        fs.readFileSync(path.join(root, name), "utf8") +
          "\nwindow.__havenSim={state,move,homeDevices};" +
          "\nconst __originalTile=homeTile;window.__tileRenders=0;homeTile=function(device){window.__tileRenders++;return __originalTile(device);};" +
          "\nconst __originalRender=renderHomeEvent;window.__renderDurations=[];renderHomeEvent=function(...args){const start=performance.now();const result=__originalRender(...args);window.__renderDurations.push(performance.now()-start);return result;};",
      );
    else fs.createReadStream(path.join(root, name)).pipe(res);
    return;
  }
  res.writeHead(404);
  res.end();
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const temp = fs.mkdtempSync(path.join(os.tmpdir(), "haven-final-sim."));
const profile = path.join(temp, "chrome");
const chrome = spawn(
  browser,
  [
    "--headless=new",
    "--disable-gpu",
    "--no-first-run",
    "--no-default-browser-check",
    "--remote-debugging-port=0",
    "--user-data-dir=" + profile,
    "about:blank",
  ],
  { stdio: "ignore" },
);
let ws;
try {
  const portFile = path.join(profile, "DevToolsActivePort");
  for (let i = 0; i < 120 && !fs.existsSync(portFile); i++) await sleep(100);
  if (!fs.existsSync(portFile)) throw Error("Chrome startup failed");
  const port = Number(fs.readFileSync(portFile, "utf8").split("\n")[0]);
  const tabs = await (
    await fetch("http://127.0.0.1:" + port + "/json/list")
  ).json();
  ws = new WebSocket(tabs.find((t) => t.type === "page").webSocketDebuggerUrl);
  await new Promise((res, rej) => {
    ws.addEventListener("open", res, { once: true });
    ws.addEventListener("error", rej, { once: true });
  });
  let id = 0;
  const requests = new Map();
  const exceptions = [];
  ws.addEventListener("message", (event) => {
    const msg = JSON.parse(event.data);
    if (msg.method === "Runtime.exceptionThrown")
      exceptions.push(
        msg.params.exceptionDetails.exception?.description ||
          msg.params.exceptionDetails.text,
      );
    if (msg.id && requests.has(msg.id)) {
      const [ok, bad] = requests.get(msg.id);
      requests.delete(msg.id);
      msg.error ? bad(Error(msg.error.message)) : ok(msg.result);
    }
  });
  const call = (method, params = {}) =>
    new Promise((ok, bad) => {
      const ident = ++id;
      requests.set(ident, [ok, bad]);
      ws.send(JSON.stringify({ id: ident, method, params }));
    });
  const evaljs = async (expression) => {
    const x = await call("Runtime.evaluate", {
      expression,
      returnByValue: true,
      awaitPromise: true,
    });
    if (x.exceptionDetails)
      throw Error(
        x.exceptionDetails.exception?.description || x.exceptionDetails.text,
      );
    return x.result.value;
  };
  await call("Page.enable");
  await call("Runtime.enable");
  await call("Emulation.setDeviceMetricsOverride", {
    width: 390,
    height: 844,
    deviceScaleFactor: 1,
    mobile: true,
    screenWidth: 390,
    screenHeight: 844,
  });
  await call("Page.navigate", {
    url: "http://127.0.0.1:" + server.address().port + "/#home",
  });
  for (let attempt = 0; attempt < 40; attempt++) {
    const loaded = await evaljs(
      'document.querySelectorAll("#home-grid [data-card-id]").length',
    );
    if (loaded >= 3) break;
    await sleep(100);
  }
  await sleep(120);
  const first = await evaljs(
    '(()=>{const cards=[...document.querySelectorAll("#home-grid [data-card-id]")];const fan=cards.find(c=>c.textContent.includes("Bedroom fan"));window.__unchangedCard=cards.find(c=>c.textContent.includes("Lounge fan"));window.__shell=document.querySelector(".sidebar");fan?.querySelectorAll("button[data-ha-percentage]")[1]?.focus();return {page:window.__havenSim.state.page,cards:cards.length,fanOff:fan?.querySelectorAll("[data-ha-percentage]").length,selected:fan?.querySelector("[data-ha-percentage].active")?.dataset.haPercentage,renders:window.__tileRenders,overflow:document.documentElement.scrollWidth>innerWidth}})()',
  );
  if (
    first.page !== "home" ||
    first.cards < 3 ||
    first.fanOff !== 4 ||
    first.selected !== "33" ||
    first.overflow
  )
    throw Error(
      "initial mobile/home fan controls invalid " + JSON.stringify(first),
    );
  if (process.env.HAVEN_SMOKE_SCREENSHOTS) {
    const shot = await call("Page.captureScreenshot", {
      format: "jpeg",
      quality: 45,
    });
    fs.writeFileSync(
      path.join(process.env.HAVEN_SMOKE_SCREENSHOTS, "home-mobile.jpg"),
      Buffer.from(shot.data, "base64"),
    );
  }
  await sleep(1300);
  const second = await evaljs(
    '(()=>{const card=[...document.querySelectorAll("#home-grid [data-card-id]")].find(c=>c.textContent.includes("Bedroom fan"));return {changed:window.__havenSim.state.entities.find(x=>x.entity_id==="fan.bedroom").attributes.percentage,unchanged:window.__unchangedCard?.isConnected,identical:window.__unchangedCard===[...document.querySelectorAll("#home-grid [data-card-id]")].find(c=>c.textContent.includes("Lounge fan")),shellSame:window.__shell===document.querySelector(".sidebar"),focused:document.activeElement?.dataset.haPercentage,renders:window.__tileRenders,renderMs:window.__renderDurations.at(-1),overflow:document.documentElement.scrollWidth>innerWidth}})()',
  );
  if (
    second.changed !== 66 ||
    !second.identical ||
    !second.shellSame ||
    second.focused !== "33" ||
    second.renders - first.renders > 2 ||
    second.overflow
  )
    throw Error("targeted update failed " + JSON.stringify(second));
  const focus = await evaljs(
    '(()=>{const c=[...document.querySelectorAll("#home-grid [data-card-id]")].find(x=>x.textContent.includes("Bedroom fan"));const b=c.querySelectorAll("[data-ha-percentage]")[0];b.click();return {label:b.getAttribute("aria-label"),offCount:[...c.querySelectorAll("[data-ha-percentage]")].filter(x=>x.dataset.haPercentage==="0").length,powerCount:c.querySelectorAll(".tile-power").length}})()',
  );
  if (focus.offCount !== 1 || focus.powerCount !== 0)
    throw Error("fan has redundant power control " + JSON.stringify(focus));
  await sleep(200);
  if (
    !logs.actions.some(
      (a) =>
        a.action === "percentage" &&
        a.percentage === 0 &&
        a.entity === "fan.bedroom",
    )
  )
    throw Error("fan Off did not issue zero percentage command");
  await evaljs('window.__havenSim.move("media")');
  await sleep(350);
  await evaljs('document.querySelector("[data-media-filter]")?.focus()');
  await sleep(800);
  const media = await evaljs(
    "({page:window.__havenSim.state.page,sonarr:window.__havenSim.state.arr.sonarr?.records?.[0]?.status,radarr:window.__havenSim.state.arr.radarr?.records?.[0]?.status,focused:document.activeElement?.dataset.mediaFilter,overflow:document.documentElement.scrollWidth>innerWidth})",
  );
  if (
    media.page !== "media" ||
    media.sonarr !== "downloading" ||
    media.radarr !== "downloading" ||
    media.focused !== "All" ||
    media.overflow
  )
    throw Error("media push/focus invalid " + JSON.stringify(media));
  if (process.env.HAVEN_SMOKE_SCREENSHOTS) {
    const shot = await call("Page.captureScreenshot", {
      format: "jpeg",
      quality: 45,
    });
    fs.writeFileSync(
      path.join(process.env.HAVEN_SMOKE_SCREENSHOTS, "media-mobile.jpg"),
      Buffer.from(shot.data, "base64"),
    );
  }
  await call("Emulation.setDeviceMetricsOverride", {
    width: 320,
    height: 740,
    deviceScaleFactor: 1,
    mobile: true,
    screenWidth: 320,
    screenHeight: 740,
  });
  await sleep(180);
  const narrow = await evaljs(
    "({width:innerWidth,overflow:document.documentElement.scrollWidth>innerWidth})",
  );
  if (narrow.overflow) throw Error("mobile overflow at 320px");
  await evaljs('window.__havenSim.move("apps")');
  await sleep(180);
  if (logs.closed.sonarr < 1 || logs.closed.radarr < 1)
    throw Error("media stream still open away from media");
  await call("Emulation.setDeviceMetricsOverride", {
    width: 1366,
    height: 850,
    deviceScaleFactor: 1,
    mobile: false,
    screenWidth: 1366,
    screenHeight: 850,
  });
  await evaljs('window.__havenSim.move("home")');
  await sleep(450);
  const desktop = await evaljs(
    '({width:innerWidth,overflow:document.documentElement.scrollWidth>innerWidth,rooms:document.querySelectorAll(".room-pill").length,tiles:document.querySelectorAll("#home-grid [data-card-id]").length})',
  );
  if (desktop.width !== 1366 || desktop.overflow || desktop.tiles < 3)
    throw Error("desktop layout failed " + JSON.stringify(desktop));
  const keyboardEnabled = await evaljs(
    'window.matchMedia("(pointer: fine)").matches',
  );
  if (!keyboardEnabled) throw Error("desktop keyboard mode did not activate");
  const press = async (key, code, virtual) => {
    await call("Input.dispatchKeyEvent", {
      type: "keyDown",
      key,
      code,
      windowsVirtualKeyCode: virtual,
      nativeVirtualKeyCode: virtual,
      text: key.length === 1 ? key : "",
    });
    await call("Input.dispatchKeyEvent", {
      type: "keyUp",
      key,
      code,
      windowsVirtualKeyCode: virtual,
      nativeVirtualKeyCode: virtual,
    });
  };
  await press("4", "Digit4", 52);
  await sleep(90);
  if ((await evaljs("window.__havenSim.state.page")) !== "apps")
    throw Error("desktop page shortcut 4 did not open Applications");
  await press("2", "Digit2", 50);
  await sleep(90);
  if ((await evaljs("window.__havenSim.state.page")) !== "home")
    throw Error("desktop page shortcut 2 did not open Smart Home");
  await press("/", "Slash", 191);
  await sleep(60);
  if ((await evaljs("document.activeElement?.id")) !== "home-search")
    throw Error("desktop search shortcut did not focus device search");
  await press("Escape", "Escape", 27);
  await evaljs("document.activeElement?.blur()");
  const opened = await evaljs(
    '(()=>{const opener=document.querySelector(".home-tile .tile-open");opener?.click();return {open:!!document.querySelector(".overlay [role=dialog]"),focused:document.querySelector(".overlay [role=dialog]")?.contains(document.activeElement)}})()',
  );
  if (!opened.open || !opened.focused)
    throw Error("device details did not focus the modal dialog");
  await press("Escape", "Escape", 27);
  const returned = await evaljs(
    '({closed:!document.querySelector(".overlay"),focused:document.activeElement?.matches(".home-tile .tile-open")})',
  );
  if (!returned.closed || !returned.focused)
    throw Error("Escape did not restore focus to the device tile");

  if (process.env.HAVEN_SMOKE_SCREENSHOTS) {
    const shot = await call("Page.captureScreenshot", {
      format: "jpeg",
      quality: 55,
    });
    fs.writeFileSync(
      path.join(process.env.HAVEN_SMOKE_SCREENSHOTS, "home-desktop.jpg"),
      Buffer.from(shot.data, "base64"),
    );
  }
  await evaljs('window.__havenSim.move("apps")');
  await evaljs(
    'document.querySelector("[data-app-favorite=paperless]")?.click()',
  );
  await sleep(100);
  const appFav = await evaljs(
    '({favorite:window.__havenSim.state.me.app_favorites.includes("paperless"),first:document.querySelector("#apps-results [data-app-launch]")?.dataset.appLaunch})',
  );
  if (!appFav.favorite || appFav.first !== "paperless")
    throw Error("app favourite sorting failed: " + JSON.stringify(appFav));
  await evaljs(
    '(()=>{const link=document.querySelector("[data-app-launch=immich]");link.addEventListener("click",e=>e.preventDefault(),{once:true});link.click()})()',
  );
  await sleep(90);
  await evaljs('window.__havenSim.move("overview")');
  const appOverview = await evaljs(
    '({first:document.querySelector("#page-content [data-app-launch]")?.dataset.appLaunch,visit:window.__havenSim.state.me.app_visits.immich})',
  );
  if (appOverview.first !== "paperless" || appOverview.visit !== 1)
    throw Error(
      "overview app activity sorting failed: " + JSON.stringify(appOverview),
    );
  await call("Emulation.setDeviceMetricsOverride", {
    width: 390,
    height: 844,
    deviceScaleFactor: 1,
    mobile: true,
    screenWidth: 390,
    screenHeight: 844,
  });
  await evaljs('window.__havenSim.move("settings")');
  await evaljs('document.querySelectorAll("button[data-hand]")[1].click()');
  await sleep(100);
  await evaljs('window.__havenSim.move("home")');
  await sleep(250);
  const oneHand = await evaljs(
    '(()=>{const rect=document.querySelector(".home-thumb-dock")?.getBoundingClientRect();return {hand:document.documentElement.dataset.hand,left:rect?.left,overflow:document.documentElement.scrollWidth>innerWidth}})()',
  );
  if (oneHand.hand !== "left" || oneHand.left >= 195 || oneHand.overflow)
    throw Error(
      "left-hand thumb controls unusable: " + JSON.stringify(oneHand),
    );
  for (const p of [
    "/api/ha/areas",
    "/api/ha/devices",
    "/api/ha/room-icons",
    "/api/ha/entities",
    "/api/arr/sonarr",
    "/api/arr/radarr",
  ])
    if (logs.requests[p])
      throw Error(
        "unexpected polling/obsolete API: " + p + " " + logs.requests[p],
      );
  if (exceptions.length)
    throw Error("JS exception " + JSON.stringify(exceptions));
  console.log(
    JSON.stringify(
      {
        passed: true,
        first,
        second,
        focus,
        media,
        narrow,
        desktop,
        oneHand,
        appFav,
        appOverview,
        requests: logs.requests,
        opened: logs.streams,
        closed: logs.closed,
        actions: logs.actions,
        exceptions: 0,
      },
      null,
      2,
    ),
  );
} catch (error) {
  console.error("SIM FAILURE", error.stack);
  process.exitCode = 1;
} finally {
  ws?.close();
  chrome.kill();
  server.close();
  setTimeout(
    () => fs.rmSync(temp, { recursive: true, force: true }),
    400,
  ).unref();
}

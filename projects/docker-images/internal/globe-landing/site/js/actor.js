const DEFAULT_ACTOR_ID = "default";

function getActorId() {
  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get("actor");
  if (fromQuery) return fromQuery;
  try {
    return localStorage.getItem("globe.actor.id") || DEFAULT_ACTOR_ID;
  } catch (_) {
    return DEFAULT_ACTOR_ID;
  }
}

async function loadActorWebConfig(actorId) {
  const safeActorId = encodeURIComponent(actorId);
  const url = `api/${safeActorId}/web/config.json`;
  const response = await fetch(url, { cache: "no-store" });
  if (!response.ok) throw new Error(`Actor config HTTP ${response.status} (${url})`);
  return response.json();
}

function renderDetails(actorConfig) {
  const details = document.querySelector("#actor-details");
  if (!details) return;
  const actor = actorConfig?.actor || {};
  const first = Array.isArray(actorConfig?.web_config) ? actorConfig.web_config[0] : null;
  const attrs = first?.attributes || {};

  const rows = [
    ["Actor id", actor.id || "-"],
    ["Email", actor.email || "-"],
    ["Mode", attrs.mode || "-"],
    ["Controls", String(Boolean(attrs.controls))],
    ["Poster", attrs.poster || "-"],
  ];

  details.innerHTML = rows
    .map(([k, v]) => `<dt>${k}</dt><dd>${v}</dd>`)
    .join("");
}

function initLogout() {
  const logout = document.querySelector("#actor-logout");
  if (!logout) return;
  logout.addEventListener("click", () => {
    try {
      localStorage.removeItem("globe.actor.id");
      localStorage.removeItem("globe.actor.email");
    } catch (_) {
      // noop
    }
    window.location.assign("index.html");
  });
}

function initLoginConfig(actorId) {
  const configButton = document.querySelector("#actor-login-config");
  if (!configButton) return;
  configButton.addEventListener("click", () => {
    const next = new URL("index.html", window.location.href);
    next.searchParams.set("actor", actorId);
    next.searchParams.set("controls", "1");
    next.searchParams.set("mode", "interactive");
    window.location.assign(next.toString());
  });
}

async function main() {
  const status = document.querySelector("#actor-info-status");
  const actorId = getActorId();
  initLogout();
  initLoginConfig(actorId);
  try {
    const config = await loadActorWebConfig(actorId);
    if (status) status.textContent = "Actor loaded.";
    renderDetails(config);
  } catch (error) {
    console.error("Failed to load actor info:", error);
    if (status) status.textContent = "Actor could not be loaded.";
  }
}

main();


/**
 * WebGL Earth sphere — equirectangular texture uses standard sphere UVs (geographic proportions).
 * Camera distance is computed so the full sphere fits the view (not a cropped “zoomed” hemisphere).
 */
import * as THREE from "three";

/** Bump with `version.txt`, `index.html` `?v=`, and docker tag together. */
const GLOBE_SCRIPT_ASSET_TAG = "0.0.6";

const GLOBE_SEL = ".globe";
const TEXTURE = "assets/earth-equirect.jpg";
const IMAGE_ASSET_DIR = "assets/images";
const ACTOR_INDEX_URL = "api/actors/index.json";
const DEFAULT_ACTOR_ID = "default";
const DEFAULT_TONE = {
  brightness: 1.31,
  contrast: 1.42,
  saturation: 1.57,
  waterLift: 0.7,
};
const DEFAULT_CALIBRATION = {
  lonOffsetDeg: 85,
  latOffsetDeg: -6,
  rotationSpeed: -0.3,
  viewYawDeg: 0,
};
const DEFAULT_STARS = {
  density: 1,
  brightness: 1,
};

function getControlsEnabled(baseEnabled = false) {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("controls");
  if (raw === null) return baseEnabled;
  return raw === "1" || raw === "true";
}

function getRenderMode(baseMode = "poster") {
  const params = new URLSearchParams(window.location.search);
  const mode = params.get("mode");
  if (mode === "interactive" || mode === "poster") return mode;
  return baseMode;
}

function getPosterName(basePoster = "default") {
  const params = new URLSearchParams(window.location.search);
  return params.get("poster") || basePoster;
}

function getActorId() {
  const params = new URLSearchParams(window.location.search);
  return params.get("actor") || DEFAULT_ACTOR_ID;
}

function getToneFromQuery(baseTone = DEFAULT_TONE) {
  const params = new URLSearchParams(window.location.search);
  const parse = (key, fallback) => {
    const raw = params.get(key);
    if (raw === null) return fallback;
    const n = Number.parseFloat(raw);
    return Number.isFinite(n) ? n : fallback;
  };
  return {
    brightness: parse("brightness", baseTone.brightness),
    contrast: parse("contrast", baseTone.contrast),
    saturation: parse("saturation", baseTone.saturation),
    waterLift: parse("waterLift", baseTone.waterLift),
  };
}

function getCalibrationFromQuery(baseCalibration = DEFAULT_CALIBRATION) {
  const params = new URLSearchParams(window.location.search);
  const lonRaw = params.get("lonOffset");
  const latRaw = params.get("latOffset");
  const rotRaw = params.get("rotationSpeed");
  const yawRaw = params.get("viewYaw");
  const lon = lonRaw === null ? baseCalibration.lonOffsetDeg : Number.parseFloat(lonRaw);
  const lat = latRaw === null ? baseCalibration.latOffsetDeg : Number.parseFloat(latRaw);
  const rot =
    rotRaw === null ? baseCalibration.rotationSpeed : Number.parseFloat(rotRaw);
  const yaw = yawRaw === null ? baseCalibration.viewYawDeg : Number.parseFloat(yawRaw);
  return {
    lonOffsetDeg: Number.isFinite(lon) ? lon : baseCalibration.lonOffsetDeg,
    latOffsetDeg: Number.isFinite(lat) ? lat : baseCalibration.latOffsetDeg,
    rotationSpeed: Number.isFinite(rot) ? rot : baseCalibration.rotationSpeed,
    viewYawDeg: Number.isFinite(yaw) ? yaw : baseCalibration.viewYawDeg,
  };
}

function getStarsFromQuery(baseStars = DEFAULT_STARS) {
  const params = new URLSearchParams(window.location.search);
  const densityRaw = params.get("starsDensity");
  const brightnessRaw = params.get("starsBrightness");
  const density = densityRaw === null ? baseStars.density : Number.parseFloat(densityRaw);
  const brightness =
    brightnessRaw === null ? baseStars.brightness : Number.parseFloat(brightnessRaw);
  return {
    density: Number.isFinite(density) ? density : baseStars.density,
    brightness: Number.isFinite(brightness) ? brightness : baseStars.brightness,
  };
}

/**
 * Build randomized stars as a full-screen PNG data URL.
 * This avoids visible grid patterns from repeated CSS tiles.
 */
function makeStarLayerDataUrl(width, height, count, sizeRange, alphaRange) {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) return "none";
  ctx.clearRect(0, 0, width, height);

  for (let i = 0; i < count; i += 1) {
    const x = Math.random() * width;
    const y = Math.random() * height;
    const r = sizeRange[0] + Math.random() * (sizeRange[1] - sizeRange[0]);
    const a = alphaRange[0] + Math.random() * (alphaRange[1] - alphaRange[0]);
    const tint = 220 + Math.floor(Math.random() * 35);
    ctx.fillStyle = `rgba(${tint}, ${tint}, 255, ${a.toFixed(3)})`;
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fill();
  }
  return `url("${canvas.toDataURL("image/png")}")`;
}

function showPosterImage(container, src, altText) {
  return new Promise((resolve) => {
    const img = new Image();
    img.className = "globe-poster";
    img.alt = altText;
    img.decoding = "async";
    img.loading = "eager";
    img.src = src;
    img.addEventListener("load", () => {
      container.innerHTML = "";
      container.appendChild(img);
      resolve(true);
    });
    img.addEventListener("error", () => resolve(false));
  });
}

async function loadPosterImage(container, posterName) {
  const safeName = posterName.replace(/[^a-zA-Z0-9_-]/g, "_");
  const path = `${IMAGE_ASSET_DIR}/${safeName}.png`;
  const ok = await showPosterImage(container, path, `Earth poster ${safeName}`);
  if (ok) return { ok: true, path, safeName };
  return { ok: false, safeName };
}

async function loadDefaultsFromFile() {
  try {
    const response = await fetch("config/defaults.json", { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();
    const numOr = (value, fallback) => {
      const n = Number(value);
      return Number.isFinite(n) ? n : fallback;
    };
    return {
      tone: {
        brightness: numOr(data?.tone?.brightness, DEFAULT_TONE.brightness),
        contrast: numOr(data?.tone?.contrast, DEFAULT_TONE.contrast),
        saturation: numOr(data?.tone?.saturation, DEFAULT_TONE.saturation),
        waterLift: numOr(data?.tone?.waterLift, DEFAULT_TONE.waterLift),
      },
      calibration: {
        lonOffsetDeg: numOr(data?.calibration?.lonOffsetDeg, DEFAULT_CALIBRATION.lonOffsetDeg),
        latOffsetDeg: numOr(data?.calibration?.latOffsetDeg, DEFAULT_CALIBRATION.latOffsetDeg),
        rotationSpeed: numOr(
          data?.calibration?.rotationSpeed,
          DEFAULT_CALIBRATION.rotationSpeed
        ),
        viewYawDeg: numOr(data?.calibration?.viewYawDeg, DEFAULT_CALIBRATION.viewYawDeg),
      },
      stars: {
        density: numOr(data?.stars?.density, DEFAULT_STARS.density),
        brightness: numOr(data?.stars?.brightness, DEFAULT_STARS.brightness),
      },
    };
  } catch (error) {
    console.warn("Using built-in defaults (config/defaults.json unavailable):", error);
    return {
      tone: { ...DEFAULT_TONE },
      calibration: { ...DEFAULT_CALIBRATION },
      stars: { ...DEFAULT_STARS },
    };
  }
}

async function loadActorIndex() {
  const response = await fetch(ACTOR_INDEX_URL, { cache: "no-store" });
  if (!response.ok) throw new Error(`Actor index HTTP ${response.status}`);
  return response.json();
}

async function findActorByEmail(email) {
  const index = await loadActorIndex();
  const actors = Array.isArray(index?.actors) ? index.actors : [];
  return (
    actors.find(
      (actor) =>
        typeof actor?.email === "string" &&
        actor.email.toLowerCase() === email.toLowerCase()
    ) || null
  );
}

async function loadActorWebConfig(actorId) {
  const safeActorId = encodeURIComponent(actorId);
  const url = `api/${safeActorId}/web/config.json`;
  const response = await fetch(url, { cache: "no-store" });
  if (!response.ok) throw new Error(`Actor config HTTP ${response.status} (${url})`);
  return response.json();
}

function getConfigForHost(webConfigList, host) {
  if (!Array.isArray(webConfigList) || webConfigList.length === 0) return null;
  return (
    webConfigList.find((cfg) => cfg?.base_url === host) ||
    webConfigList.find((cfg) => cfg?.base_url === "*") ||
    null
  );
}

function initActorLogin(currentActor, options = {}) {
  const form = document.querySelector("#actor-login");
  const input = document.querySelector("#actor-username");
  const status = document.querySelector("#actor-status");
  if (!form || !input || !status) return;
  if (options.hide === true) {
    form.style.display = "none";
    return;
  }

  if (currentActor?.email && currentActor.email !== "default@local") {
    input.value = currentActor.email;
  }
  status.textContent = "";

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const email = input.value.trim();
    if (!email) return;
    status.textContent = "Looking up actor...";
    try {
      const actor = await findActorByEmail(email);
      if (!actor?.id) {
        status.textContent = "Actor could not be found.";
        return;
      }
      try {
        localStorage.setItem("globe.actor.id", actor.id);
        localStorage.setItem("globe.actor.email", actor.email || email);
      } catch (_) {
        // Ignore storage issues; query fallback still works.
      }
      const next = new URL("actor.html", window.location.href);
      next.searchParams.set("actor", actor.id);
      window.location.assign(next.toString());
    } catch (error) {
      console.error("Actor lookup failed:", error);
      status.textContent = "Actor lookup failed. Check local API files.";
    }
  });
}

/** Unit sphere in scene; texture maps 1:1 with real equirectangular longitude/latitude. */
const SPHERE_RADIUS = 1;
const MARKER_SURFACE_OFFSET = 0.018;
// Texture-to-geometry longitude calibration.
// This map's prime meridian is 180° offset from our current front-center assumption.
const BOSTON = {
  name: "Boston, MA",
  lat: 42.3601,
  lon: -71.0589,
};

/** Vertical field of view (deg). Narrower = must move camera farther to fit sphere — do not use to “zoom” texture; use distance instead. */
const FIELD_OF_VIEW_DEG = 40;

/**
 * Minimum camera distance so a sphere of radius R fits fully in the perspective frustum
 * (considers both vertical and horizontal FOV when aspect ≠ 1).
 * See: angular radius of sphere α = asin(R/d), need 2α ≤ FOV → d ≥ R / sin(FOV/2).
 */
function minDistanceForSphereToFitView(camera, radius) {
  const vFov = THREE.MathUtils.degToRad(camera.fov);
  const hFov = 2 * Math.atan(Math.tan(vFov / 2) * camera.aspect);
  const dVert = radius / Math.sin(vFov / 2);
  const dHoriz = radius / Math.sin(hFov / 2);
  return Math.max(dVert, dHoriz);
}

function prefersReducedMotion() {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

/**
 * Convert geographic coordinates to Three.js sphere position.
 * lon: east positive, west negative. lat: north positive, south negative.
 */
function latLonToVector3(
  latDeg,
  lonDeg,
  radius,
  lonOffsetDeg = DEFAULT_CALIBRATION.lonOffsetDeg,
  latOffsetDeg = DEFAULT_CALIBRATION.latOffsetDeg
) {
  const lat = THREE.MathUtils.degToRad(latDeg + latOffsetDeg);
  const lon = THREE.MathUtils.degToRad(lonDeg + lonOffsetDeg);
  const cosLat = Math.cos(lat);
  // Calibrated to Three.js SphereGeometry UV orientation + map's longitudinal offset.
  return new THREE.Vector3(
    radius * cosLat * Math.sin(lon),
    radius * Math.sin(lat),
    radius * cosLat * Math.cos(lon)
  );
}

/**
 * Boost visual separation between land/water and sharpen coastlines.
 * This keeps the source asset static while improving readability.
 */
function enhanceEarthTexture(texture, tone) {
  const img = texture.image;
  if (!img || !img.width || !img.height) return texture;

  const canvas = document.createElement("canvas");
  canvas.width = img.width;
  canvas.height = img.height;
  const ctx = canvas.getContext("2d", { willReadFrequently: true });
  if (!ctx) return texture;

  ctx.drawImage(img, 0, 0);
  const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
  const data = imageData.data;

  // Tuned for shoreline readability, overridable via query/controls.
  const { brightness, contrast, saturation, waterLift } = tone;

  for (let i = 0; i < data.length; i += 4) {
    let r = data[i] / 255;
    let g = data[i + 1] / 255;
    let b = data[i + 2] / 255;

    // Brightness
    r *= brightness;
    g *= brightness;
    b *= brightness;

    // Contrast around midpoint
    r = (r - 0.5) * contrast + 0.5;
    g = (g - 0.5) * contrast + 0.5;
    b = (b - 0.5) * contrast + 0.5;

    // Saturation
    const luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    r = luma + (r - luma) * saturation;
    g = luma + (g - luma) * saturation;
    b = luma + (b - luma) * saturation;

    // Selective ocean lift:
    // - detect water-like colors (blue channel dominant over red/green)
    // - gently lift ocean brightness to improve coastline/island readability
    const blueDominance = Math.max(0, b - Math.max(r, g));
    const greenVsRed = g - r; // keeps cyan/blue oceans, avoids over-lifting tan deserts
    const waterMask = Math.max(0, Math.min(1, blueDominance * 2.8 + greenVsRed * 0.9));
    const lift = waterLift * waterMask;

    r = Math.min(1, r + lift * 0.22);
    g = Math.min(1, g + lift * 0.55);
    b = Math.min(1, b + lift * 1.0);

    data[i] = Math.max(0, Math.min(255, Math.round(r * 255)));
    data[i + 1] = Math.max(0, Math.min(255, Math.round(g * 255)));
    data[i + 2] = Math.max(0, Math.min(255, Math.round(b * 255)));
  }

  ctx.putImageData(imageData, 0, 0);

  // Tiny sharpen pass to help coastline edges read at smaller globe sizes.
  ctx.filter = "contrast(108%)";
  ctx.drawImage(canvas, 0, 0);

  const enhanced = new THREE.CanvasTexture(canvas);
  enhanced.colorSpace = THREE.SRGBColorSpace;
  enhanced.anisotropy = texture.anisotropy;
  enhanced.wrapS = THREE.ClampToEdgeWrapping;
  enhanced.wrapT = THREE.ClampToEdgeWrapping;
  enhanced.needsUpdate = true;
  return enhanced;
}

async function main() {
  const container = document.querySelector(GLOBE_SEL);
  if (!container) return;
  console.info("[globe-landing] globe.js", GLOBE_SCRIPT_ASSET_TAG);
  const actorId = getActorId();
  let actorConfig = null;
  try {
    actorConfig = await loadActorWebConfig(actorId);
  } catch (error) {
    console.warn(`Using fallback actor config for "${actorId}":`, error);
  }

  const hostConfig = getConfigForHost(actorConfig?.web_config, window.location.host);
  const actorWeb = hostConfig?.attributes || {};
  const actor = actorConfig?.actor || { id: actorId };

  const renderMode = getRenderMode(actorWeb.mode || "poster");
  let isInteractive = renderMode === "interactive";
  const fileDefaults = await loadDefaultsFromFile();
  const actorParams = actorWeb.params || {};
  const baseTone = {
    ...fileDefaults.tone,
    brightness:
      Number.isFinite(Number(actorParams.brightness))
        ? Number(actorParams.brightness)
        : fileDefaults.tone.brightness,
    contrast:
      Number.isFinite(Number(actorParams.contrast))
        ? Number(actorParams.contrast)
        : fileDefaults.tone.contrast,
    saturation:
      Number.isFinite(Number(actorParams.saturation))
        ? Number(actorParams.saturation)
        : fileDefaults.tone.saturation,
    waterLift:
      Number.isFinite(Number(actorParams.waterLift))
        ? Number(actorParams.waterLift)
        : fileDefaults.tone.waterLift,
  };
  const baseCalibration = {
    ...fileDefaults.calibration,
    lonOffsetDeg:
      Number.isFinite(Number(actorParams.lonOffset))
        ? Number(actorParams.lonOffset)
        : fileDefaults.calibration.lonOffsetDeg,
    latOffsetDeg:
      Number.isFinite(Number(actorParams.latOffset))
        ? Number(actorParams.latOffset)
        : fileDefaults.calibration.latOffsetDeg,
    rotationSpeed:
      Number.isFinite(Number(actorParams.rotationSpeed))
        ? Number(actorParams.rotationSpeed)
        : fileDefaults.calibration.rotationSpeed,
    viewYawDeg:
      Number.isFinite(Number(actorParams.viewYaw))
        ? Number(actorParams.viewYaw)
        : fileDefaults.calibration.viewYawDeg,
  };
  const baseStars = {
    ...fileDefaults.stars,
    density:
      Number.isFinite(Number(actorParams.starsDensity))
        ? Number(actorParams.starsDensity)
        : fileDefaults.stars.density,
    brightness:
      Number.isFinite(Number(actorParams.starsBrightness))
        ? Number(actorParams.starsBrightness)
        : fileDefaults.stars.brightness,
  };

  let tone = getToneFromQuery(baseTone);
  let calibration = getCalibrationFromQuery(baseCalibration);
  let stars = getStarsFromQuery(baseStars);
  const controlsEnabled = getControlsEnabled(Boolean(actorWeb.controls));
  const hideLogin = actorId !== DEFAULT_ACTOR_ID && controlsEnabled;
  initActorLogin(actor, { hide: hideLogin });
  let starsDirty = true;
  function applyStars() {
    document.documentElement.style.setProperty("--stars-density", stars.density.toFixed(2));
    document.documentElement.style.setProperty("--stars-brightness", stars.brightness.toFixed(2));
    if (!starsDirty) return;
    const w = Math.max(window.innerWidth || 1280, 1280);
    const h = Math.max(window.innerHeight || 720, 720);
    const densityScale = Math.max(0.5, Math.min(2, stars.density));
    const nearCount = Math.round(260 * densityScale);
    const farCount = Math.round(420 * densityScale);
    const nearLayer = makeStarLayerDataUrl(w, h, nearCount, [0.7, 2.0], [0.28, 0.95]);
    const farLayer = makeStarLayerDataUrl(w, h, farCount, [0.35, 1.2], [0.18, 0.7]);
    document.documentElement.style.setProperty("--stars-layer-near", nearLayer);
    document.documentElement.style.setProperty("--stars-layer-far", farLayer);
    starsDirty = false;
  }
  applyStars();

  if (renderMode === "poster") {
    const result = await loadPosterImage(container, getPosterName(actorWeb.poster || "default"));
    if (result.ok) return;
    console.warn(
      `Poster not found at ${IMAGE_ASSET_DIR}/${result.safeName}.png; falling back to snapshot render.`
    );
    isInteractive = false;
  }

  const scene = new THREE.Scene();

  const camera = new THREE.PerspectiveCamera(FIELD_OF_VIEW_DEG, 1, 0.1, 100);
  camera.position.set(0, 0, 3);

  const renderer = new THREE.WebGLRenderer({
    antialias: true,
    alpha: true,
    powerPreference: "high-performance",
  });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.2;
  container.appendChild(renderer.domElement);

  const group = new THREE.Group();
  /* Slight tilt for 3D read; small angle so it doesn’t dominate framing scale */
  group.rotation.x = 0.12;
  group.rotation.y = THREE.MathUtils.degToRad(calibration.viewYawDeg);
  scene.add(group);

  const geometry = new THREE.SphereGeometry(SPHERE_RADIUS, 96, 64);

  const ambient = new THREE.AmbientLight(0x6b7f95, 0.55);
  scene.add(ambient);

  const hemi = new THREE.HemisphereLight(0x9fc7ff, 0x1a2f44, 0.35);
  scene.add(hemi);

  const sun = new THREE.DirectionalLight(0xffffff, 2.35);
  sun.position.set(4.5, 1.2, 2.5);
  scene.add(sun);

  const fill = new THREE.DirectionalLight(0xa7c7e8, 0.62);
  fill.position.set(-3, -0.5, -2);
  scene.add(fill);

  const mat = new THREE.MeshStandardMaterial({
    color: 0x1a3d66,
    roughness: 0.48,
    metalness: 0.03,
  });
  const mesh = new THREE.Mesh(geometry, mat);
  group.add(mesh);

  // Location marker: Boston, MA.
  const markerPos = latLonToVector3(
    BOSTON.lat,
    BOSTON.lon,
    SPHERE_RADIUS + MARKER_SURFACE_OFFSET,
    calibration.lonOffsetDeg,
    calibration.latOffsetDeg
  );
  const marker = new THREE.Mesh(
    new THREE.SphereGeometry(0.02, 20, 20),
    new THREE.MeshBasicMaterial({ color: 0xff2b2b })
  );
  marker.position.copy(markerPos);
  group.add(marker);

  // Subtle halo ring to make the marker easier to spot.
  const halo = new THREE.Mesh(
    new THREE.RingGeometry(0.028, 0.045, 48),
    new THREE.MeshBasicMaterial({
      color: 0xff5a5a,
      transparent: true,
      opacity: 0.7,
      side: THREE.DoubleSide,
    })
  );
  halo.position.copy(markerPos);
  halo.lookAt(halo.position.clone().multiplyScalar(2)); // Face outward from globe center.
  group.add(halo);

  const loader = new THREE.TextureLoader();
  let sourceTexture = null;

  function applyTone() {
    if (!sourceTexture) return;
    mat.map = enhanceEarthTexture(sourceTexture, tone);
    mat.needsUpdate = true;
  }

  function renderFrame() {
    renderer.render(scene, camera);
  }

  function createToneControls() {
    if (!controlsEnabled) return;
    const panel = document.createElement("div");
    panel.className = "controls";
    panel.innerHTML = `
      <h2>Tone</h2>
      <label title="Overall Earth texture brightness. Higher values make oceans/land lighter.">Brightness <input id="brightness" title="Overall Earth texture brightness. Higher values make oceans/land lighter." type="range" min="0.85" max="1.35" step="0.01" value="${tone.brightness.toFixed(2)}" /> <output id="brightness-out">${tone.brightness.toFixed(2)}</output></label>
      <label title="Earth texture contrast. Higher values increase separation between dark/light areas.">Contrast <input id="contrast" title="Earth texture contrast. Higher values increase separation between dark/light areas." type="range" min="0.90" max="1.60" step="0.01" value="${tone.contrast.toFixed(2)}" /> <output id="contrast-out">${tone.contrast.toFixed(2)}</output></label>
      <label title="Earth texture saturation. Higher values increase color intensity.">Saturation <input id="saturation" title="Earth texture saturation. Higher values increase color intensity." type="range" min="0.85" max="1.60" step="0.01" value="${tone.saturation.toFixed(2)}" /> <output id="saturation-out">${tone.saturation.toFixed(2)}</output></label>
      <label title="Selective ocean brightening to improve island/coastline visibility.">Water lift <input id="waterLift" title="Selective ocean brightening to improve island/coastline visibility." type="range" min="0.00" max="0.70" step="0.01" value="${tone.waterLift.toFixed(2)}" /> <output id="waterLift-out">${tone.waterLift.toFixed(2)}</output></label>
      <label title="Longitude calibration offset for marker placement on this texture.">Lon offset <input id="lonOffsetDeg" title="Longitude calibration offset for marker placement on this texture." type="range" min="-180" max="180" step="1" value="${calibration.lonOffsetDeg.toFixed(0)}" /> <output id="lonOffsetDeg-out">${calibration.lonOffsetDeg.toFixed(0)}</output></label>
      <label title="Latitude calibration offset for marker placement on this texture.">Lat offset <input id="latOffsetDeg" title="Latitude calibration offset for marker placement on this texture." type="range" min="-30" max="30" step="1" value="${calibration.latOffsetDeg.toFixed(0)}" /> <output id="latOffsetDeg-out">${calibration.latOffsetDeg.toFixed(0)}</output></label>
      <label title="Rotation speed and direction. Negative reverses direction, zero stops rotation.">Rotation <input id="rotationSpeed" title="Rotation speed and direction. Negative reverses direction, zero stops rotation." type="range" min="-0.30" max="0.30" step="0.005" value="${calibration.rotationSpeed.toFixed(3)}" /> <output id="rotationSpeed-out">${calibration.rotationSpeed.toFixed(3)}</output></label>
      <label title="Random star count. Higher density creates more stars.">Stars density <input id="starsDensity" title="Random star count. Higher density creates more stars." type="range" min="0.50" max="2.00" step="0.01" value="${stars.density.toFixed(2)}" /> <output id="starsDensity-out">${stars.density.toFixed(2)}</output></label>
      <label title="Starfield brightness (and overall scene lift in current styling).">Stars bright <input id="starsBrightness" title="Starfield brightness (and overall scene lift in current styling)." type="range" min="0.50" max="2.00" step="0.01" value="${stars.brightness.toFixed(2)}" /> <output id="starsBrightness-out">${stars.brightness.toFixed(2)}</output></label>
      <button id="createPoster" type="button">Create assets</button>
      <button id="saveDefaults" type="button">Save default config</button>
    `;
    document.body.appendChild(panel);

    const bindSlider = (key) => {
      const input = panel.querySelector(`#${key}`);
      const out = panel.querySelector(`#${key}-out`);
      input.addEventListener("input", () => {
        tone[key] = Number.parseFloat(input.value);
        out.value = tone[key].toFixed(2);
        applyTone();
        if (!isInteractive) renderer.render(scene, camera);
      });
    };

    bindSlider("brightness");
    bindSlider("contrast");
    bindSlider("saturation");
    bindSlider("waterLift");
    const lonInput = panel.querySelector("#lonOffsetDeg");
    const lonOut = panel.querySelector("#lonOffsetDeg-out");
    const latInput = panel.querySelector("#latOffsetDeg");
    const latOut = panel.querySelector("#latOffsetDeg-out");
    const rotationInput = panel.querySelector("#rotationSpeed");
    const rotationOut = panel.querySelector("#rotationSpeed-out");
    const starsDensityInput = panel.querySelector("#starsDensity");
    const starsDensityOut = panel.querySelector("#starsDensity-out");
    const starsBrightnessInput = panel.querySelector("#starsBrightness");
    const starsBrightnessOut = panel.querySelector("#starsBrightness-out");
    const createPosterBtn = panel.querySelector("#createPoster");
    const saveDefaultsBtn = panel.querySelector("#saveDefaults");
    const updateMarkerFromCalibration = () => {
      const newPos = latLonToVector3(
        BOSTON.lat,
        BOSTON.lon,
        SPHERE_RADIUS + MARKER_SURFACE_OFFSET,
        calibration.lonOffsetDeg,
        calibration.latOffsetDeg
      );
      marker.position.copy(newPos);
      halo.position.copy(newPos);
      halo.lookAt(halo.position.clone().multiplyScalar(2));
      if (!isInteractive) renderer.render(scene, camera);
    };
    lonInput.addEventListener("input", () => {
      calibration.lonOffsetDeg = Number.parseFloat(lonInput.value);
      lonOut.value = calibration.lonOffsetDeg.toFixed(0);
      updateMarkerFromCalibration();
    });
    latInput.addEventListener("input", () => {
      calibration.latOffsetDeg = Number.parseFloat(latInput.value);
      latOut.value = calibration.latOffsetDeg.toFixed(0);
      updateMarkerFromCalibration();
    });
    rotationInput.addEventListener("input", () => {
      calibration.rotationSpeed = Number.parseFloat(rotationInput.value);
      rotationOut.value = calibration.rotationSpeed.toFixed(3);
      rotationSpeed = prefersReducedMotion() ? 0 : calibration.rotationSpeed;
      if (!isInteractive) renderer.render(scene, camera);
    });
    starsDensityInput.addEventListener("input", () => {
      stars.density = Number.parseFloat(starsDensityInput.value);
      starsDensityOut.value = stars.density.toFixed(2);
      starsDirty = true;
      applyStars();
    });
    starsBrightnessInput.addEventListener("input", () => {
      stars.brightness = Number.parseFloat(starsBrightnessInput.value);
      starsBrightnessOut.value = stars.brightness.toFixed(2);
      applyStars();
    });

    const triggerDownload = (href, fileName) => {
      const a = document.createElement("a");
      a.href = href;
      a.download = fileName;
      document.body.appendChild(a);
      a.click();
      a.remove();
    };

    const exportPosterAndIcon = (name) => {
      // Render current frame first, then export poster + icon assets.
      renderer.render(scene, camera);
      const src = renderer.domElement;
      const w = src.width;
      const h = src.height;
      const posterCanvas = document.createElement("canvas");
      posterCanvas.width = w;
      posterCanvas.height = h;
      const ctx = posterCanvas.getContext("2d");
      if (!ctx) return;

      // Draw frame.
      ctx.clearRect(0, 0, w, h);
      ctx.drawImage(src, 0, 0, w, h);

      // Keep only globe circle; remove rectangular edges.
      ctx.globalCompositeOperation = "destination-in";
      ctx.beginPath();
      ctx.arc(w / 2, h / 2, Math.min(w, h) / 2, 0, Math.PI * 2);
      ctx.closePath();
      ctx.fill();
      ctx.globalCompositeOperation = "source-over";

      const posterHref = posterCanvas.toDataURL("image/png");

      // Build square icon from center crop of masked poster.
      const makeIconHref = (iconSize) => {
        const iconCanvas = document.createElement("canvas");
        iconCanvas.width = iconSize;
        iconCanvas.height = iconSize;
        const iconCtx = iconCanvas.getContext("2d");
        if (iconCtx) {
          iconCtx.clearRect(0, 0, iconSize, iconSize);
          iconCtx.drawImage(posterCanvas, 0, 0, iconSize, iconSize);
        }
        return iconCanvas.toDataURL("image/png");
      };
      const iconHref256 = makeIconHref(256);
      const iconHref32 = makeIconHref(32);

      // Three downloads from one action.
      triggerDownload(posterHref, `${name}.png`);
      setTimeout(() => triggerDownload(iconHref256, `${name}-icon.png`), 60);
      setTimeout(() => triggerDownload(iconHref32, `${name}-icon-32.png`), 120);
    };

    createPosterBtn.addEventListener("click", () => {
      const suggested = getPosterName();
      const raw = window.prompt("Asset base name (letters, numbers, - or _)", suggested);
      if (!raw) return;
      const safeName = raw.trim().replace(/[^a-zA-Z0-9_-]/g, "_");
      if (!safeName) return;
      exportPosterAndIcon(safeName);
      window.alert(
        `Downloaded assets for "${safeName}". Move files to ${IMAGE_ASSET_DIR}/${safeName}.png, ${safeName}-icon.png, and ${safeName}-icon-32.png`
      );
    });

    saveDefaultsBtn.addEventListener("click", () => {
      // Static site cannot write server files directly; export JSON for commit/api seed.
      const payload = {
        tone: {
          brightness: Number(tone.brightness.toFixed(2)),
          contrast: Number(tone.contrast.toFixed(2)),
          saturation: Number(tone.saturation.toFixed(2)),
          waterLift: Number(tone.waterLift.toFixed(2)),
        },
        calibration: {
          lonOffsetDeg: Number(calibration.lonOffsetDeg.toFixed(0)),
          latOffsetDeg: Number(calibration.latOffsetDeg.toFixed(0)),
          rotationSpeed: Number(calibration.rotationSpeed.toFixed(3)),
          viewYawDeg: Number(THREE.MathUtils.radToDeg(group.rotation.y).toFixed(2)),
        },
        stars: {
          density: Number(stars.density.toFixed(2)),
          brightness: Number(stars.brightness.toFixed(2)),
        },
      };
      const blob = new Blob([`${JSON.stringify(payload, null, 2)}\n`], {
        type: "application/json",
      });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "globe-defaults.json";
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
    });
  }

  createToneControls();

  loader.load(
    TEXTURE,
    (texture) => {
      texture.colorSpace = THREE.SRGBColorSpace;
      texture.anisotropy = Math.min(16, renderer.capabilities.getMaxAnisotropy());
      /* Standard equirectangular: one full 360°×180° wraps the sphere; no repeat. */
      texture.wrapS = THREE.ClampToEdgeWrapping;
      texture.wrapT = THREE.ClampToEdgeWrapping;
      sourceTexture = texture;
      applyTone();
      mat.color.setHex(0xffffff);
      mat.roughness = 0.44;
      mat.metalness = 0.04;
      mat.needsUpdate = true;
      // Snapshot/fallback mode needs a post-texture render.
      if (!isInteractive) renderFrame();
    },
    undefined,
    (err) => {
      console.error("Earth texture failed to load:", err);
    }
  );

  let rotationSpeed = prefersReducedMotion() ? 0 : calibration.rotationSpeed;
  const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
  mq.addEventListener("change", () => {
    rotationSpeed = prefersReducedMotion() ? 0 : calibration.rotationSpeed;
  });

  const clock = new THREE.Clock();

  /** Extra margin: tilted group needs a slightly larger distance so the sphere silhouette stays inside the circle. */
  const TILT_MARGIN = 1.08;

  function resize() {
    // getBoundingClientRect() after layout tends to match paint better than clientWidth/Height
    // during resize drags (especially vertical / mobile visual viewport).
    const rect = container.getBoundingClientRect();
    const w = Math.max(1, Math.round(rect.width));
    const h = Math.max(1, Math.round(rect.height));
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    const d = minDistanceForSphereToFitView(camera, SPHERE_RADIUS) * TILT_MARGIN;
    camera.position.z = d;
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setSize(w, h, false);
    renderFrame();
  }

  let resizeRaf = 0;
  function scheduleResize() {
    if (resizeRaf) return;
    resizeRaf = requestAnimationFrame(() => {
      resizeRaf = 0;
      resize();
    });
  }

  const ro = new ResizeObserver(() => scheduleResize());
  ro.observe(container);
  window.addEventListener("resize", () => {
    scheduleResize();
    starsDirty = true;
    applyStars();
  });
  window.visualViewport?.addEventListener?.("resize", scheduleResize);
  window.visualViewport?.addEventListener?.("scroll", scheduleResize);
  resize();

  function animate() {
    requestAnimationFrame(animate);
    const dt = clock.getDelta();
    if (rotationSpeed !== 0) {
      group.rotation.y += rotationSpeed * dt;
    }
    renderFrame();
  }
  if (isInteractive) {
    animate();
  } else {
    // Snapshot mode: one render, no continuous loop.
    rotationSpeed = 0;
    renderFrame();
  }
}

main().catch((error) => {
  console.error("Failed to initialize globe:", error);
});

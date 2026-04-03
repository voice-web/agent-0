// Minimal globe + starfield for default-html (aligned with globe-landing defaults).
// Loads tone / calibration / stars from static `config/defaults.json`, with the same
// object inlined below as fallback if fetch fails.

import * as THREE from "three";

const GLOBE_SEL = ".globe";
const EARTH_TEXTURE_URL = "assets/earth-equirect.jpg";

/** Inlined copy of `config/defaults.json` — keep in sync when changing defaults. */
const STATIC_GLOBE_DEFAULTS = {
  tone: {
    brightness: 1.31,
    contrast: 1.42,
    saturation: 1.57,
    waterLift: 0.7,
  },
  calibration: {
    lonOffsetDeg: 85,
    latOffsetDeg: -6,
    rotationSpeed: -0.3,
    viewYawDeg: -3311.38,
  },
  stars: {
    density: 1,
    brightness: 1,
  },
};

const SPHERE_RADIUS = 1;
const FIELD_OF_VIEW_DEG = 40;
const TILT_MARGIN = 1.08;

function prefersReducedMotion() {
  return window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches ?? false;
}

function numOr(value, fallback) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

async function loadDefaultsFromFile() {
  try {
    const response = await fetch("config/defaults.json", { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();
    const base = STATIC_GLOBE_DEFAULTS;
    return {
      tone: {
        brightness: numOr(data?.tone?.brightness, base.tone.brightness),
        contrast: numOr(data?.tone?.contrast, base.tone.contrast),
        saturation: numOr(data?.tone?.saturation, base.tone.saturation),
        waterLift: numOr(data?.tone?.waterLift, base.tone.waterLift),
      },
      calibration: {
        lonOffsetDeg: numOr(data?.calibration?.lonOffsetDeg, base.calibration.lonOffsetDeg),
        latOffsetDeg: numOr(data?.calibration?.latOffsetDeg, base.calibration.latOffsetDeg),
        rotationSpeed: numOr(data?.calibration?.rotationSpeed, base.calibration.rotationSpeed),
        viewYawDeg: numOr(data?.calibration?.viewYawDeg, base.calibration.viewYawDeg),
      },
      stars: {
        density: numOr(data?.stars?.density, base.stars.density),
        brightness: numOr(data?.stars?.brightness, base.stars.brightness),
      },
    };
  } catch (error) {
    console.warn("default-html globe: using inlined defaults (config/defaults.json unavailable):", error);
    return {
      tone: { ...STATIC_GLOBE_DEFAULTS.tone },
      calibration: { ...STATIC_GLOBE_DEFAULTS.calibration },
      stars: { ...STATIC_GLOBE_DEFAULTS.stars },
    };
  }
}

function makeStarLayerDataUrl(width, height, count, sizeRange, alphaRange) {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) return null;

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

  return canvas.toDataURL("image/png");
}

function applyStars(stars) {
  document.documentElement.style.setProperty("--stars-density", stars.density.toFixed(2));
  document.documentElement.style.setProperty("--stars-brightness", stars.brightness.toFixed(2));

  const w = Math.max(window.innerWidth || 1280, 1280);
  const h = Math.max(window.innerHeight || 720, 720);
  const densityScale = Math.max(0.5, Math.min(2, stars.density));

  const nearCount = Math.round(260 * densityScale);
  const farCount = Math.round(420 * densityScale);

  const nearDataUrl = makeStarLayerDataUrl(w, h, nearCount, [0.7, 2.0], [0.28, 0.95]);
  const farDataUrl = makeStarLayerDataUrl(w, h, farCount, [0.35, 1.2], [0.18, 0.7]);

  document.documentElement.style.setProperty(
    "--stars-layer-far",
    farDataUrl ? `url("${farDataUrl}")` : "none"
  );
  document.documentElement.style.setProperty(
    "--stars-layer-near",
    nearDataUrl ? `url("${nearDataUrl}")` : "none"
  );
}

function minDistanceForSphereToFitView(camera, radius) {
  const vFov = THREE.MathUtils.degToRad(camera.fov);
  const hFov = 2 * Math.atan(Math.tan(vFov / 2) * camera.aspect);
  const dVert = radius / Math.sin(vFov / 2);
  const dHoriz = radius / Math.sin(hFov / 2);
  return Math.max(dVert, dHoriz);
}

/**
 * Boost land/water separation and coastline readability (same idea as globe-landing).
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

  const { brightness, contrast, saturation, waterLift } = tone;

  for (let i = 0; i < data.length; i += 4) {
    let r = data[i] / 255;
    let g = data[i + 1] / 255;
    let b = data[i + 2] / 255;

    r *= brightness;
    g *= brightness;
    b *= brightness;

    r = (r - 0.5) * contrast + 0.5;
    g = (g - 0.5) * contrast + 0.5;
    b = (b - 0.5) * contrast + 0.5;

    const luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    r = luma + (r - luma) * saturation;
    g = luma + (g - luma) * saturation;
    b = luma + (b - luma) * saturation;

    const blueDominance = Math.max(0, b - Math.max(r, g));
    const greenVsRed = g - r;
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

async function init() {
  const container = document.querySelector(GLOBE_SEL);
  if (!container) return;

  const defaults = await loadDefaultsFromFile();
  applyStars(defaults.stars);

  const renderer = new THREE.WebGLRenderer({
    antialias: true,
    alpha: true,
    powerPreference: "high-performance",
  });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.2;
  container.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(FIELD_OF_VIEW_DEG, 1, 0.1, 100);
  camera.position.set(0, 0, 3);

  const group = new THREE.Group();
  group.rotation.x = 0.12;
  group.rotation.y = THREE.MathUtils.degToRad(defaults.calibration.viewYawDeg);
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
  const earth = new THREE.Mesh(geometry, mat);
  group.add(earth);

  let sourceTexture = null;
  function applyTone() {
    if (!sourceTexture) return;
    mat.map = enhanceEarthTexture(sourceTexture, defaults.tone);
    mat.color.setHex(0xffffff);
    mat.roughness = 0.44;
    mat.metalness = 0.04;
    mat.needsUpdate = true;
  }

  const textureLoader = new THREE.TextureLoader();
  try {
    await new Promise((resolve) => {
      textureLoader.load(
        EARTH_TEXTURE_URL,
        (texture) => {
          texture.colorSpace = THREE.SRGBColorSpace;
          texture.anisotropy = Math.min(16, renderer.capabilities.getMaxAnisotropy());
          texture.wrapS = THREE.ClampToEdgeWrapping;
          texture.wrapT = THREE.ClampToEdgeWrapping;
          sourceTexture = texture;
          applyTone();
          resolve(true);
        },
        undefined,
        (err) => {
          console.warn("default-html globe: texture load failed:", EARTH_TEXTURE_URL, err);
          resolve(false);
        }
      );
    });
  } catch (_) {
    // ignore
  }

  const reduced = prefersReducedMotion();
  let rotationSpeed = reduced ? 0 : defaults.calibration.rotationSpeed;
  const mq = window.matchMedia?.("(prefers-reduced-motion: reduce)");
  mq?.addEventListener?.("change", () => {
    rotationSpeed = prefersReducedMotion() ? 0 : defaults.calibration.rotationSpeed;
  });

  function resize() {
    const w = Math.max(container.clientWidth, 1);
    const h = Math.max(container.clientHeight, 1);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    const d = minDistanceForSphereToFitView(camera, SPHERE_RADIUS) * TILT_MARGIN;
    camera.position.z = d;
    renderer.setSize(w, h, false);
  }

  resize();
  window.addEventListener("resize", () => {
    resize();
    applyStars(defaults.stars);
  });

  let last = performance.now();
  function tick(now) {
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;

    if (!reduced && rotationSpeed !== 0) {
      group.rotation.y += rotationSpeed * dt;
    }
    renderer.render(scene, camera);
    requestAnimationFrame(tick);
  }

  requestAnimationFrame(tick);
}

init().catch(() => {
  // WebGL failed; starfield CSS layers were already applied.
});

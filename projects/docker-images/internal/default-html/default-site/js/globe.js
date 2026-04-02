// Minimal globe + starfield for default-html.
// - Generates two CSS star layers via data-URLs (near/far) using the same mechanism as globe-landing.
// - Renders a rotating Earth sphere if `assets/earth-equirect.jpg` is present.
//
// This intentionally has no actor/login UI and no in-page configuration controls.

import * as THREE from "three";

const GLOBE_SEL = ".globe";
const EARTH_TEXTURE_URL = "assets/earth-equirect.jpg";

const DEFAULTS = {
  // Use baked defaults aligned with globe-landing's default config.
  // (In full app these normally come from config/api-driven settings.)
  rotationSpeed: 0.0,
  starsDensity: 1.43,
  starsBrightness: 1.25,
};

function prefersReducedMotion() {
  return window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches ?? false;
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

function setStarsCssVars({ density, brightness }) {
  document.documentElement.style.setProperty("--stars-brightness", Number(brightness).toFixed(2));

  const w = Math.max(window.innerWidth || 1280, 1280);
  const h = Math.max(window.innerHeight || 720, 720);
  const densityScale = Math.max(0.5, Math.min(2, Number(density)));

  // Two layers: fewer/smaller for far, slightly larger/more opaque for near.
  const farCount = Math.round(180 * densityScale);
  const nearCount = Math.round(260 * densityScale);

  const farDataUrl = makeStarLayerDataUrl(w, h, farCount, [0.6, 1.4], [0.08, 0.42]);
  const nearDataUrl = makeStarLayerDataUrl(w, h, nearCount, [0.8, 1.9], [0.14, 0.6]);

  // CSS expects `background-image: var(--stars-layer-far)`, so we set vars to url(...)
  document.documentElement.style.setProperty(
    "--stars-layer-far",
    farDataUrl ? `url("${farDataUrl}")` : "none"
  );
  document.documentElement.style.setProperty(
    "--stars-layer-near",
    nearDataUrl ? `url("${nearDataUrl}")` : "none"
  );
}

function computeCameraDistanceToFitSphere(camera, sphereRadius) {
  // Keep simple: pick distance from vertical FOV.
  const vFov = THREE.MathUtils.degToRad(camera.fov);
  return sphereRadius / Math.sin(vFov / 2);
}

async function init() {
  const container = document.querySelector(GLOBE_SEL);
  if (!container) return;

  setStarsCssVars({
    density: DEFAULTS.starsDensity,
    brightness: DEFAULTS.starsBrightness,
  });

  // Create renderer
  const renderer = new THREE.WebGLRenderer({
    antialias: true,
    alpha: true,
    powerPreference: "high-performance",
  });
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.2;
  container.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(40, 1, 0.1, 1000);

  // Globe mesh
  const sphereRadius = 1;
  const geometry = new THREE.SphereGeometry(sphereRadius, 64, 64);

  // Keep texture un-darkened; use white base color so map renders at intended brightness.
  const material = new THREE.MeshBasicMaterial({ color: 0xffffff });
  const earth = new THREE.Mesh(geometry, material);
  scene.add(earth);

  // Load earth texture if available.
  // If it fails, we still render the mesh (just without texture).
  const textureLoader = new THREE.TextureLoader();
  try {
    await new Promise((resolve) => {
      textureLoader.load(
        EARTH_TEXTURE_URL,
        (texture) => {
          texture.colorSpace = THREE.SRGBColorSpace;
          texture.wrapS = THREE.ClampToEdgeWrapping;
          texture.wrapT = THREE.ClampToEdgeWrapping;
          material.map = texture;
          material.needsUpdate = true;
          resolve(true);
        },
        undefined,
        () => resolve(false)
      );
    });
  } catch (_) {
    // Ignore texture load errors.
  }

  const reduced = prefersReducedMotion();

  function resize() {
    const w = Math.max(container.clientWidth, 1);
    const h = Math.max(container.clientHeight, 1);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();

    const distance = computeCameraDistanceToFitSphere(camera, sphereRadius);
    camera.position.z = distance * 1.02;

    renderer.setSize(w, h, false);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  }

  // Initial sizing + attach.
  resize();

  let last = performance.now();
  function tick(now) {
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;

    if (!reduced) {
      earth.rotation.y += DEFAULTS.rotationSpeed * dt;
    }
    renderer.render(scene, camera);
    requestAnimationFrame(tick);
  }

  window.addEventListener("resize", resize);
  requestAnimationFrame(tick);
}

init().catch(() => {
  // If WebGL fails entirely, we still want the CSS starfield to show.
  // (Star layers were already generated before init started.)
});


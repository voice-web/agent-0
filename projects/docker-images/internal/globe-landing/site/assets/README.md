# Assets placeholder

This image package includes the static HTML/CSS/JS/config/api content for globe-landing.

Optional runtime assets usually expected by the page:
- `assets/earth-equirect.jpg`
- `assets/images/default-icon.png`
- `assets/images/default-icon-32.png`
- `assets/images/default.png` (poster mode default image)

To fetch Earth texture into this folder:

```bash
curl -fsSL -o assets/earth-equirect.jpg \
  "https://raw.githubusercontent.com/mrdoob/three.js/r152/examples/textures/planets/earth_atmos_2048.jpg"
```


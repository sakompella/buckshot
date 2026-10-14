import * as THREE from "three";

// <gun-model>: an optional 3D accent. It draws the shotgun from above, muzzle
// down, dithered at a low resolution to match the board, over the SVG gun it
// replaces once it has drawn a frame. Attributes: data-sawed shortens the
// barrel, data-held lifts the gun off the cloth, and a new data-shot value
// flashes the muzzle. It draws only while something changes.

const VERTEX = `
varying vec2 vUv;
void main() { vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }
`;

const FRAGMENT = `
uniform sampler2D tScene;
uniform vec2 lowRes;
varying vec2 vUv;
float bayer(vec2 p) {
  int i = int(mod(p.x, 4.0)) + int(mod(p.y, 4.0)) * 4;
  int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
  return (float(m[i]) + 0.5) / 16.0;
}
void main() {
  vec2 px = floor(vUv * lowRes);
  vec4 texel = texture2D(tScene, (px + 0.5) / lowRes);
  vec3 c = pow(max(texel.rgb, 0.0), vec3(1.0 / 2.2));
  float l = dot(c, vec3(0.299, 0.587, 0.114));
  c = mix(c, mix(vec3(0.16, 0.09, 0.1), vec3(1.0, 0.9, 0.74), l), 0.3);
  c = floor(c * 7.0 + bayer(px)) / 7.0;
  gl_FragColor = vec4(c, step(0.5, texel.a));
}
`;

/** Pixels of the element per pixel of the drawing. */
const PIXEL = 2;

const LIFT_MS = 260;

const FLASH_MS = 220;

const material = (color: string): THREE.MeshStandardMaterial => new THREE.MeshStandardMaterial({ color, roughness: 0.8, metalness: 0.15, flatShading: true });

const part = (geometry: THREE.BufferGeometry, color: string, place: readonly [number, number, number]): THREE.Mesh => {
  const piece = new THREE.Mesh(geometry, material(color));

  piece.position.set(...place);

  return piece;
};

interface Gun {
  readonly root: THREE.Group;
  /** Scaled along z to saw the barrel off. */
  readonly barrel: THREE.Group;
  readonly muzzle: THREE.Vector3;
}

/** The shotgun along +z, muzzle forward. */
const buildGun = (): Gun => {
  const pump = part(new THREE.CylinderGeometry(0.21, 0.21, 0.7, 8), "#6a3828", [0, -0.08, 1.05]);
  const tube = part(new THREE.CylinderGeometry(0.13, 0.13, 1.9, 8), "#4a4940", [0, 0, 0.95]);
  const magazine = part(new THREE.CylinderGeometry(0.11, 0.11, 1.4, 8), "#2e2d28", [0, -0.15, 0.7]);

  pump.rotation.x = Math.PI / 2;
  tube.rotation.x = Math.PI / 2;
  magazine.rotation.x = Math.PI / 2;

  const barrel = new THREE.Group();

  barrel.position.set(0, 0.1, 0.55);
  barrel.add(tube);

  const root = new THREE.Group();

  root.add(
    part(new THREE.BoxGeometry(0.5, 0.42, 1.25), "#5b2f24", [0, -0.05, -1.25]),
    part(new THREE.BoxGeometry(0.32, 0.3, 0.5), "#4a2a20", [0, -0.02, -0.45]),
    part(new THREE.BoxGeometry(0.42, 0.34, 0.8), "#25241f", [0, 0.04, 0.15]),
    pump,
    magazine,
    barrel,
  );

  return { root, barrel, muzzle: new THREE.Vector3(0, 0.1, 2.45) };
};

class GunModel extends HTMLElement {
  static readonly observedAttributes = ["data-sawed", "data-held", "data-shot"];

  readonly #scene = new THREE.Scene();
  readonly #camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 20);
  readonly #gun = buildGun();
  readonly #flash = new THREE.PointLight("#ffd29a", 0, 4, 2);
  readonly #target = new THREE.WebGLRenderTarget(1, 1, { minFilter: THREE.NearestFilter, magFilter: THREE.NearestFilter });
  readonly #post = new THREE.ShaderMaterial({ vertexShader: VERTEX, fragmentShader: FRAGMENT, uniforms: { tScene: { value: this.#target.texture }, lowRes: { value: new THREE.Vector2(1, 1) } }, transparent: true, depthTest: false });
  readonly #postScene = new THREE.Scene();
  readonly #postCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
  #renderer: THREE.WebGLRenderer | null = null;
  #observer: ResizeObserver | null = null;
  #frame = 0;
  #lift = 0;
  #liftFrom = 0;
  #liftTo = 0;
  #liftStart = 0;
  #flashStart = Number.NEGATIVE_INFINITY;

  constructor() {
    super();

    const key = new THREE.DirectionalLight("#ffd7a3", 3.2);

    key.position.set(-2, 6, 1);
    this.#flash.position.copy(this.#gun.muzzle);
    this.#scene.add(this.#gun.root, key, this.#flash, new THREE.AmbientLight("#6e6450", 1.1));

    // Looking straight down with -z up the screen, so the muzzle (+z) points down.
    this.#camera.position.set(0, 8, 0.28);
    this.#camera.up.set(0, 0, -1);
    this.#camera.lookAt(0, 0, 0.28);

    const quad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), this.#post);

    quad.frustumCulled = false;
    this.#postScene.add(quad);
  }

  connectedCallback(): void {
    const canvas = document.createElement("canvas");

    canvas.style.cssText = "display:block;width:100%;height:100%;image-rendering:pixelated";
    this.append(canvas);
    this.#renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: false, powerPreference: "low-power" });
    this.#renderer.setClearColor(0x000000, 0);
    this.#observer = new ResizeObserver(() => this.#resize());
    this.#observer.observe(this);
    this.#resize();
  }

  disconnectedCallback(): void {
    cancelAnimationFrame(this.#frame);
    this.#observer?.disconnect();
    this.#renderer?.dispose();
    this.#renderer = null;
    this.replaceChildren();
  }

  attributeChangedCallback(name: string, previous: string | null, next: string | null): void {
    if (name === "data-held") {
      this.#liftFrom = this.#lift;
      this.#liftTo = next === "true" ? 1 : 0;
      this.#liftStart = performance.now();
    }

    if (name === "data-shot" && next !== null && next !== "" && next !== previous) this.#flashStart = performance.now();

    this.#schedule();
  }

  #resize(): void {
    const renderer = this.#renderer;
    const width = Math.max(1, this.clientWidth);
    const height = Math.max(1, this.clientHeight);

    if (renderer === null) return;

    renderer.setPixelRatio(1);
    renderer.setSize(width, height, false);
    this.#target.setSize(Math.ceil(width / PIXEL), Math.ceil(height / PIXEL));
    this.#post.uniforms["lowRes"]?.value.set(Math.ceil(width / PIXEL), Math.ceil(height / PIXEL));

    // The gun is about 4.4 long; fit it to the element's height.
    const halfHeight = 2.4;
    const halfWidth = (halfHeight * width) / height;

    this.#camera.left = -halfWidth;
    this.#camera.right = halfWidth;
    this.#camera.top = halfHeight;
    this.#camera.bottom = -halfHeight;
    this.#camera.updateProjectionMatrix();
    this.#schedule();
  }

  #schedule(): void {
    cancelAnimationFrame(this.#frame);
    this.#frame = requestAnimationFrame((now) => this.#draw(now));
  }

  #draw(now: number): void {
    const renderer = this.#renderer;

    if (renderer === null) return;

    const liftProgress = Math.min(1, (now - this.#liftStart) / LIFT_MS);
    const flashProgress = (now - this.#flashStart) / FLASH_MS;

    this.#lift = this.#liftFrom + (this.#liftTo - this.#liftFrom) * (1 - (1 - liftProgress) ** 2);
    // Turned a little onto its side so the light shows its depth; lifting turns it further.
    this.#gun.root.rotation.z = 0.35 + this.#lift * 0.4;
    this.#gun.root.scale.setScalar(1 + this.#lift * 0.08);
    this.#gun.barrel.scale.z = this.dataset["sawed"] === "true" ? 0.5 : 1;
    this.#flash.intensity = flashProgress >= 0 && flashProgress < 1 ? 40 * (1 - flashProgress) : 0;
    renderer.setRenderTarget(this.#target);
    renderer.clear();
    renderer.render(this.#scene, this.#camera);
    renderer.setRenderTarget(null);
    renderer.clear();
    renderer.render(this.#postScene, this.#postCamera);
    this.dataset["ready"] = "";

    if (liftProgress < 1 || (flashProgress >= 0 && flashProgress < 1)) this.#schedule();
  }
}

export const defineGunModel = (): void => {
  if (customElements.get("gun-model") === undefined) customElements.define("gun-model", GunModel);
};

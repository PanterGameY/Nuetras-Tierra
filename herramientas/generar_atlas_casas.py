"""
Generador de Atlas de Texturas PBR Fotorrealistas (2048x2048, grilla 4x4 de 512x512)
para el Sistema Modular de Casas de Nuestra Tierra 2.0.

Mejoras de realismo:
  - Micro-grano de alta frecuencia y variación orgánica (sin colores planos/cartoon).
  - Vetas de madera anisotrópicas y metal cepillado real.
  - Biseles suavizados con filtro gaussiano para Normal Maps naturales.
  - Oclusión ambiental (AO) en juntas, marcos, rejas y paneles.
  - Vidrios con reflejo de cielo/interior sutil y profundidad.
"""

import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "recursos",
    "texturas_casas",
)
TILE = 512
GRID = 4
SIZE = TILE * GRID  # 2048


def _rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def _fbm(h: int, w: int, seed: int, octaves: int = 5, base_freq: int = 4) -> np.ndarray:
    """Ruido fractal tileable multifrecuencia."""
    rng = _rng(seed)
    acc = np.zeros((h, w), dtype=np.float32)
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        freq = min(h, base_freq * (2 ** o))
        grid = rng.random((freq, freq), dtype=np.float32)
        img = Image.fromarray((grid * 255).astype(np.uint8), mode="L").resize(
            (w, h), resample=Image.Resampling.BICUBIC
        )
        acc += (np.asarray(img, dtype=np.float32) / 255.0) * amp
        norm += amp
        amp *= 0.5
    return np.clip(acc / norm, 0.0, 1.0)


def _wood_grain(h: int, w: int, seed: int, vertical: bool = False) -> np.ndarray:
    """Vetas de madera realistas anisotrópicas."""
    rng = _rng(seed)
    gh, gw = (8, 96) if vertical else (96, 8)
    g = rng.random((gh, gw), dtype=np.float32)
    base = np.asarray(
        Image.fromarray((g * 255).astype(np.uint8), mode="L").resize(
            (w, h), resample=Image.Resampling.BICUBIC
        ),
        dtype=np.float32,
    ) / 255.0
    fine = _fbm(h, w, seed + 17, octaves=4, base_freq=8)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    coord = xx if vertical else yy
    rings = np.sin(coord * 0.14 + fine * 9.0) * 0.5 + 0.5
    return np.clip(base * 0.55 + rings * 0.30 + fine * 0.15, 0.0, 1.0)


def _height_to_normal(height: np.ndarray, strength: float = 3.5) -> np.ndarray:
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5 * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5 * strength
    nz = np.ones_like(height)
    length = np.sqrt(dx * dx + dy * dy + nz * nz) + 1e-6
    nx = -dx / length
    ny = -dy / length
    nz = nz / length
    rgb = np.stack([nx * 0.5 + 0.5, ny * 0.5 + 0.5, nz * 0.5 + 0.5], axis=-1)
    return (np.clip(rgb, 0.0, 1.0) * 255).astype(np.uint8)


def _make_atlas_buffers(has_emission: bool = False):
    alb = np.zeros((SIZE, SIZE, 3), dtype=np.uint8)
    nrm = np.zeros((SIZE, SIZE, 3), dtype=np.uint8)
    nrm[..., 0] = 128
    nrm[..., 1] = 128
    nrm[..., 2] = 255
    rgh = np.full((SIZE, SIZE), 200, dtype=np.uint8)
    emi = np.zeros((SIZE, SIZE, 3), dtype=np.uint8) if has_emission else None
    return alb, nrm, rgh, emi


def _place(buf_a, buf_n, buf_r, idx: int, a, h, r, e=None, strength=3.5, buf_e=None):
    row, col = divmod(idx, GRID)
    y0, y1 = row * TILE, (row + 1) * TILE
    x0, x1 = col * TILE, (col + 1) * TILE
    buf_a[y0:y1, x0:x1] = np.clip(a * 255.0, 0, 255).astype(np.uint8)
    buf_n[y0:y1, x0:x1] = _height_to_normal(h.astype(np.float32), strength)
    buf_r[y0:y1, x0:x1] = np.clip(r * 255.0, 0, 255).astype(np.uint8)
    if buf_e is not None and e is not None:
        buf_e[y0:y1, x0:x1] = np.clip(e * 255.0, 0, 255).astype(np.uint8)


# ============================================================================
# 1. ATLAS DE FACHADAS (16 materiales arquitectónicos fotorrealistas)
# ============================================================================
def generar_atlas_fachadas():
    alb, nrm, rgh, _ = _make_atlas_buffers()
    yy, xx = np.mgrid[0:TILE, 0:TILE].astype(np.float32)
    micro = _rng(999).random((TILE, TILE), dtype=np.float32) * 0.04

    # 0: Estuco / Pañete Liso (con micro-porosidad y sutil variación de humedad)
    n0 = _fbm(TILE, TILE, 100, 6, 6)
    n0_macro = _fbm(TILE, TILE, 1100, 3, 2)
    h0 = 0.5 + (n0 - 0.5) * 0.22 + micro * 1.5
    c0 = 0.87 + (n0 - 0.5) * 0.08 + (n0_macro - 0.5) * 0.06 - micro * 0.5
    a0 = np.stack([c0, c0 * 0.995, c0 * 0.985], axis=-1)
    r0 = np.clip(0.84 + (n0 - 0.5) * 0.10, 0.72, 0.95)
    _place(alb, nrm, rgh, 0, a0, h0, r0, strength=2.2)

    # 1: Pañete Rústico / Bahareque Colonial
    n1 = _fbm(TILE, TILE, 101, 6, 5)
    trowel = np.sin(xx * 0.045 + n1 * 5.0) * np.cos(yy * 0.04 + n1 * 4.0) * 0.14
    h1 = np.clip(n1 * 0.65 + trowel + 0.18 + micro, 0, 1)
    shade1 = 0.80 + (h1 - 0.5) * 0.24 - micro * 0.4
    a1 = np.stack([shade1, shade1 * 0.985, shade1 * 0.96], axis=-1)
    r1 = np.clip(0.90 - h1 * 0.08, 0.75, 0.96)
    _place(alb, nrm, rgh, 1, a1, h1, r1, strength=5.0)

    # 2: Ladrillo a la Vista Colombiano / Terracota (con bisel y AO en mortero)
    rows, cols = 16, 8
    bh, bw = TILE // rows, TILE // cols
    brick_mask = np.zeros((TILE, TILE), dtype=np.float32)
    brick_c = np.zeros((TILE, TILE, 3), dtype=np.float32)
    rng = _rng(102)
    noise_b = _fbm(TILE, TILE, 103, 5, 6)
    for r in range(rows):
        offset = (bw // 2) if (r % 2 == 1) else 0
        for c in range(cols + 1):
            x0 = (c * bw + offset) % TILE
            y0 = r * bh
            tone = 0.68 + rng.random() * 0.30
            red_shift = rng.uniform(-0.03, 0.03)
            tint = np.array([0.52 * tone + red_shift, 0.27 * tone, 0.20 * tone])
            for dy in range(3, bh - 2):
                yy_i = (y0 + dy) % TILE
                for dx in range(3, bw - 2):
                    xx_i = (x0 + dx) % TILE
                    brick_mask[yy_i, xx_i] = 1.0
                    brick_c[yy_i, xx_i] = tint * (0.80 + noise_b[yy_i, xx_i] * 0.34 - micro[yy_i, xx_i])
    # Suavizado de bordes para bisel realista
    brick_blur = np.asarray(
        Image.fromarray((brick_mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.4)),
        dtype=np.float32,
    ) / 255.0
    brick_h = np.clip(0.22 + brick_blur * 0.65 + (noise_b - 0.5) * 0.18 + micro, 0, 1)
    mortar_col = np.array([0.50, 0.49, 0.46])[None, None, :] * (0.84 + noise_b[..., None] * 0.24)
    # AO oscuro justo en la transición mortero-ladrillo
    ao2 = 1.0 - np.clip(1.0 - np.abs(brick_blur - 0.5) * 2.0, 0, 1) * 0.25
    a2 = (brick_c * brick_blur[..., None] + mortar_col * (1.0 - brick_blur[..., None])) * ao2[..., None]
    r2 = np.where(brick_blur < 0.4, 0.94, 0.80 + noise_b * 0.12)
    _place(alb, nrm, rgh, 2, a2, brick_h, r2, strength=6.5)

    # 3: Ladrillo Pintado / Enjalbegado (tintable)
    a3_val = (0.88 * brick_blur + 0.74 * (1.0 - brick_blur)) * ao2 * (0.92 + (noise_b - 0.5) * 0.12)
    a3 = np.stack([a3_val, a3_val, a3_val], axis=-1)
    r3 = np.where(brick_blur < 0.4, 0.90, 0.76)
    _place(alb, nrm, rgh, 3, a3, brick_h, r3, strength=5.5)

    # 4: Concreto Visto / Formaleta Moderna (tintable)
    n4 = _fbm(TILE, TILE, 104, 6, 4)
    seam_y = ((yy % 128) < 3).astype(np.float32)
    seam_x = ((xx % 256) < 2).astype(np.float32)
    seam4 = np.asarray(
        Image.fromarray((np.maximum(seam_y, seam_x) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)),
        dtype=np.float32,
    ) / 255.0
    holes = ((xx % 128 - 64) ** 2 + (yy % 128 - 64) ** 2 < 18).astype(np.float32)
    h4 = np.clip(0.75 + (n4 - 0.5) * 0.24 - seam4 * 0.35 - holes * 0.4 + micro, 0, 1)
    c4 = 0.74 + (n4 - 0.5) * 0.18 - seam4 * 0.15 - holes * 0.22 - micro * 0.5
    a4 = np.stack([c4, c4, c4 * 1.01], axis=-1)
    r4 = np.clip(0.80 + (1.0 - n4) * 0.14, 0.65, 0.95)
    _place(alb, nrm, rgh, 4, a4, h4, r4, strength=4.5)

    # 5: Madera Machihembrada Horizontal (tintable, vetas reales)
    plank_h = 64
    plank_idx = (yy // plank_h).astype(np.int32)
    grain5 = _wood_grain(TILE, TILE, 105, vertical=False)
    groove5 = np.asarray(
        Image.fromarray((((yy % plank_h) < 4).astype(np.uint8) * 255)).filter(ImageFilter.GaussianBlur(1.2)),
        dtype=np.float32,
    ) / 255.0
    plank_var = ((plank_idx * 37) % 11) / 11.0 * 0.14
    h5 = np.clip(0.72 + grain5 * 0.20 - groove5 * 0.60, 0, 1)
    c5 = np.clip(0.84 - plank_var + (grain5 - 0.5) * 0.22 - groove5 * 0.35, 0.18, 0.98)
    a5 = np.stack([c5, c5 * 0.97, c5 * 0.93], axis=-1)
    r5 = np.clip(0.64 + grain5 * 0.16 + groove5 * 0.22, 0.50, 0.94)
    _place(alb, nrm, rgh, 5, a5, h5, r5, strength=5.0)

    # 6: Madera Vertical / Tablón Rústico
    plank_idx_v = (xx // 64).astype(np.int32)
    grain6 = _wood_grain(TILE, TILE, 106, vertical=True)
    groove6 = np.asarray(
        Image.fromarray((((xx % 64) < 4).astype(np.uint8) * 255)).filter(ImageFilter.GaussianBlur(1.2)),
        dtype=np.float32,
    ) / 255.0
    pvar_v = ((plank_idx_v * 53) % 13) / 13.0 * 0.16
    h6 = np.clip(0.72 + grain6 * 0.22 - groove6 * 0.62, 0, 1)
    c6 = np.clip(0.66 - pvar_v + (grain6 - 0.5) * 0.24 - groove6 * 0.32, 0.12, 0.95)
    a6 = np.stack([c6 * 0.90, c6 * 0.64, c6 * 0.42], axis=-1)
    r6 = np.clip(0.70 + grain6 * 0.16 + groove6 * 0.20, 0.55, 0.95)
    _place(alb, nrm, rgh, 6, a6, h6, r6, strength=5.5)

    # 7: Piedra Laja / Mampostería Andina
    rng7 = _rng(107)
    pts_y = rng7.integers(0, TILE, 42)
    pts_x = rng7.integers(0, TILE, 42)
    pts_t = 0.50 + rng7.random(42) * 0.44
    min_d1 = np.full((TILE, TILE), 1e9, dtype=np.float32)
    min_d2 = np.full((TILE, TILE), 1e9, dtype=np.float32)
    stone_tone = np.zeros((TILE, TILE), dtype=np.float32)
    for py, px, pt in zip(pts_y, pts_x, pts_t):
        dy = np.minimum(np.abs(yy - py), TILE - np.abs(yy - py))
        dx = np.minimum(np.abs(xx - px), TILE - np.abs(xx - px)) * 0.72
        d = np.sqrt(dy * dy + dx * dx)
        m1 = d < min_d1
        min_d2 = np.where(m1, min_d1, np.minimum(min_d2, d))
        min_d1 = np.where(m1, d, min_d1)
        stone_tone = np.where(m1, pt, stone_tone)
    edge = np.clip((min_d2 - min_d1) / 9.0, 0.0, 1.0)
    n7 = _fbm(TILE, TILE, 108, 6, 5)
    h7 = np.clip(edge * 0.70 + n7 * 0.30 + micro, 0, 1)
    c7 = np.where(edge < 0.22, 0.34 + n7 * 0.08, stone_tone * (0.72 + n7 * 0.36))
    a7 = np.stack([c7 * 0.95, c7 * 0.91, c7 * 0.85], axis=-1)
    r7 = np.where(edge < 0.22, 0.95, 0.78 + n7 * 0.14)
    _place(alb, nrm, rgh, 7, a7, h7, r7, strength=7.5)

    # 8: Piedra Caliza / Sillar Colonial
    sillar_y = ((yy % 128) < 4).astype(np.float32)
    off_x = ((yy // 128) % 2) * 128
    sillar_x = (((xx + off_x) % 256) < 4).astype(np.float32)
    seam8 = np.asarray(
        Image.fromarray((np.maximum(sillar_y, sillar_x) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.4)),
        dtype=np.float32,
    ) / 255.0
    n8 = _fbm(TILE, TILE, 109, 5, 5)
    h8 = np.clip(0.80 + (n8 - 0.5) * 0.26 - seam8 * 0.55 + micro, 0, 1)
    c8 = np.clip(0.84 + (n8 - 0.5) * 0.16 - seam8 * 0.25, 0.28, 0.95)
    a8 = np.stack([c8, c8 * 0.96, c8 * 0.89], axis=-1)
    r8 = np.clip(0.82 + seam8 * 0.10, 0.72, 0.95)
    _place(alb, nrm, rgh, 8, a8, h8, r8, strength=5.5)

    # 9: Mármol / Travertino Moderno (tintable)
    n9a = _fbm(TILE, TILE, 110, 5, 4)
    n9b = _fbm(TILE, TILE, 111, 5, 6)
    vein = np.abs(np.sin((xx * 0.02 + yy * 0.015) + n9a * 6.0))
    vein = np.power(1.0 - vein, 6.0)
    h9 = 0.7 + (n9b - 0.5) * 0.08 - vein * 0.05
    c9 = 0.91 - vein * 0.24 - (n9b - 0.5) * 0.07
    a9 = np.stack([c9, c9 * 0.99, c9 * 0.97], axis=-1)
    r9 = np.clip(0.20 + vein * 0.16 + n9b * 0.08, 0.14, 0.48)
    _place(alb, nrm, rgh, 9, a9, h9, r9, strength=1.5)

    # 10: Paneles Arquitectónicos / Concreto Ranurado
    rib = np.sin(xx * (2 * np.pi / 32.0)) * 0.5 + 0.5
    panel_gap = ((yy % 256) < 4).astype(np.float32)
    n10 = _fbm(TILE, TILE, 112, 4, 5)
    h10 = np.clip(0.4 + rib * 0.5 - panel_gap * 0.4 + micro, 0, 1)
    c10 = 0.74 + rib * 0.15 + (n10 - 0.5) * 0.10 - panel_gap * 0.28
    a10 = np.stack([c10, c10, c10], axis=-1)
    r10 = np.full((TILE, TILE), 0.64)
    _place(alb, nrm, rgh, 10, a10, h10, r10, strength=5.0)

    # 11: Guadua / Bambú Tejido
    culm = np.sin(xx * (2 * np.pi / 42.666))
    culm_h = np.sqrt(np.clip(1.0 - culm * culm * 0.45, 0, 1))
    node = ((yy + (xx // 43) * 70) % 180 < 5).astype(np.float32)
    n11 = _fbm(TILE, TILE, 113, 4, 6)
    h11 = np.clip(culm_h * 0.8 + node * 0.15, 0, 1)
    c11 = 0.70 * culm_h + (n11 - 0.5) * 0.12 - node * 0.20
    a11 = np.stack([c11 * 1.04, c11 * 0.86, c11 * 0.50], axis=-1)
    r11 = np.clip(0.52 + (1.0 - culm_h) * 0.28, 0.4, 0.9)
    _place(alb, nrm, rgh, 11, a11, h11, r11, strength=6.5)

    # 12: Lámina Metálica Acanalada (tintable)
    wave = np.sin(xx * (2 * np.pi / 32.0)) * 0.5 + 0.5
    n12 = _fbm(TILE, TILE, 114, 4, 6)
    h12 = wave * 0.85 + 0.1
    c12 = 0.72 + wave * 0.22 + (n12 - 0.5) * 0.08
    a12 = np.stack([c12, c12, c12 * 1.02], axis=-1)
    r12 = np.full((TILE, TILE), 0.36)
    _place(alb, nrm, rgh, 12, a12, h12, r12, strength=5.5)

    # 13: Graniplast / Estuco Texturizado (tintable)
    n13 = _fbm(TILE, TILE, 115, 6, 8)
    grit = _rng(116).random((TILE, TILE), dtype=np.float32)
    h13 = np.clip(n13 * 0.5 + grit * 0.5, 0, 1)
    c13 = 0.82 + (h13 - 0.5) * 0.24
    a13 = np.stack([c13, c13, c13], axis=-1)
    r13 = np.full((TILE, TILE), 0.91)
    _place(alb, nrm, rgh, 13, a13, h13, r13, strength=6.5)

    # 14: Cerámica / Azulejo Exterior (tintable)
    tile_g = np.maximum(((xx % 64) < 3).astype(np.float32), ((yy % 64) < 3).astype(np.float32))
    t_idx = ((xx // 64) * 7 + (yy // 64) * 13) % 5
    n14 = _fbm(TILE, TILE, 117, 4, 5)
    h14 = np.clip(0.85 - tile_g * 0.55, 0, 1)
    c14 = np.where(tile_g > 0.5, 0.52, 0.85 + (t_idx - 2) * 0.03 + (n14 - 0.5) * 0.06)
    a14 = np.stack([c14, c14, c14], axis=-1)
    r14 = np.where(tile_g > 0.5, 0.86, 0.24)
    _place(alb, nrm, rgh, 14, a14, h14, r14, strength=4.5)

    # 15: Zócalo / Base de Concreto & Piedra (tintable)
    n15 = _fbm(TILE, TILE, 118, 6, 5)
    band = np.where(yy < 36, 0.95, 0.78)
    h15 = np.clip(band + (n15 - 0.5) * 0.28 + micro, 0, 1)
    h15[34:39, :] = 0.2
    c15 = 0.76 + (n15 - 0.5) * 0.18
    c15[34:39, :] = 0.44
    a15 = np.stack([c15, c15, c15], axis=-1)
    r15 = np.full((TILE, TILE), 0.87)
    _place(alb, nrm, rgh, 15, a15, h15, r15, strength=4.5)

    Image.fromarray(alb).save(os.path.join(OUT_DIR, "atlas_fachadas_albedo.png"))
    Image.fromarray(nrm).save(os.path.join(OUT_DIR, "atlas_fachadas_normal.png"))
    Image.fromarray(rgh).save(os.path.join(OUT_DIR, "atlas_fachadas_roughness.png"))
    print("OK atlas_fachadas_*")


# ============================================================================
# Helpers realistas para Ventanas y Puertas (con textura, AO, bisel y vidrio)
# ============================================================================
def _finalize_architectural_tile(img_alb, img_h, img_r, img_e=None, seed=500, is_metal=False):
    """Aplica micro-textura orgánica, AO en bordes de altura y bisel suave al heightmap."""
    a = np.asarray(img_alb, dtype=np.float32) / 255.0
    h_raw = np.asarray(img_h, dtype=np.float32) / 255.0
    r = np.asarray(img_r, dtype=np.float32) / 255.0
    e = np.asarray(img_e, dtype=np.float32) / 255.0 if img_e is not None else None

    # Suavizar heightmap ligeramente para biseles 3D realistas en normal map
    h_smooth = np.asarray(img_h.filter(ImageFilter.GaussianBlur(1.6)), dtype=np.float32) / 255.0
    grain = _wood_grain(TILE, TILE, seed, vertical=True) if not is_metal else _fbm(TILE, TILE, seed, 5, 16)

    is_glass = r < 0.16
    # Aplicar veta/textura solo fuera del vidrio
    tex_mod = 0.90 + grain * 0.20
    a_out = np.where(is_glass[..., None], a, np.clip(a * tex_mod[..., None], 0.0, 1.0))

    # Oclusión ambiental sutil donde hay cambios de profundidad
    ao_diff = np.clip((h_smooth - h_raw) * 1.8, 0.0, 0.35)
    a_out = np.where(is_glass[..., None], a_out, a_out * (1.0 - ao_diff[..., None]))

    h_out = np.where(is_glass, h_raw, np.clip(h_smooth + (grain - 0.5) * 0.06, 0.0, 1.0))
    r_out = np.where(is_glass, r, np.clip(r + (grain - 0.5) * 0.10, 0.20, 0.95))
    return a_out, h_out, r_out, e


def _new_canvas(bg_col=(215, 212, 206), bg_h=170, bg_r=170, with_e=False):
    ia = Image.new("RGB", (TILE, TILE), bg_col)
    ih = Image.new("L", (TILE, TILE), bg_h)
    ir = Image.new("L", (TILE, TILE), bg_r)
    ie = Image.new("RGB", (TILE, TILE), (0, 0, 0)) if with_e else None
    return ia, ih, ir, ie


def _draw_glass_rect(ia, ih, ir, ie, box, glow=(255, 200, 125)):
    """Dibuja vidrio arquitectónico oscuro realista con profundidad interior y sombra de marco."""
    x0, y0, x1, y1 = box
    da, dh, dr = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir)
    de = ImageDraw.Draw(ie) if ie is not None else None

    # Gradiente vertical oscuro realista (reflejo sutil arriba, interior profundo abajo)
    for y in range(y0, y1):
        t = (y - y0) / max(1, (y1 - y0))
        r_c = int(22 * (1 - t) + 10 * t)
        g_c = int(30 * (1 - t) + 14 * t)
        b_c = int(38 * (1 - t) + 18 * t)
        da.line([(x0, y), (x1, y)], fill=(r_c, g_c, b_c))

    # Reflejo diagonal muy sutil de cristal
    da.polygon([(x0 + 4, y0 + 4), (x0 + (x1 - x0) // 2, y0 + 4), (x0 + 4, y0 + (y1 - y0) // 2)], fill=(30, 42, 52))
    # Sombra interior del marco (AO)
    da.rectangle([x0, y0, x1, y0 + 10], fill=(8, 10, 12))
    da.rectangle([x0, y0, x0 + 6, y1], fill=(10, 12, 15))

    dh.rectangle(box, fill=55)
    dr.rectangle(box, fill=16)  # roughness ~ 0.06 -> vidrio realista
    if de is not None:
        de.rectangle(box, fill=glow)


# ============================================================================
# 2. ATLAS DE VENTANAS (16 estilos realistas)
# ============================================================================
def generar_atlas_ventanas():
    alb, nrm, rgh, emi = _make_atlas_buffers(has_emission=True)

    # 0: Colonial Madera con Postigos
    ia, ih, ir, ie = _new_canvas((212, 208, 200), 210, 175, True)
    da, dh, dr, de = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir), ImageDraw.Draw(ie)
    for sx0, sx1 in [(12, 108), (404, 500)]:
        da.rectangle([sx0, 32, sx1, 480], fill=(192, 186, 176), outline=(105, 100, 94), width=4)
        dh.rectangle([sx0, 32, sx1, 480], fill=200, outline=120, width=4)
        for ly in range(56, 460, 26):
            da.line([(sx0 + 12, ly), (sx1 - 12, ly)], fill=(125, 120, 114), width=5)
            dh.line([(sx0 + 12, ly), (sx1 - 12, ly)], fill=150, width=5)
    da.rectangle([112, 24, 400, 488], fill=(222, 218, 212), outline=(115, 110, 105), width=6)
    dh.rectangle([112, 24, 400, 488], fill=225, outline=140, width=6)
    _draw_glass_rect(ia, ih, ir, ie, [142, 54, 370, 458])
    da.rectangle([248, 54, 264, 458], fill=(216, 212, 205))
    dh.rectangle([248, 54, 264, 458], fill=215)
    dr.rectangle([248, 54, 264, 458], fill=175)
    de.rectangle([248, 54, 264, 458], fill=(0, 0, 0))
    for my in [188, 324]:
        da.rectangle([142, my - 8, 370, my + 8], fill=(216, 212, 205))
        dh.rectangle([142, my - 8, 370, my + 8], fill=215)
        dr.rectangle([142, my - 8, 370, my + 8], fill=175)
        de.rectangle([142, my - 8, 370, my + 8], fill=(0, 0, 0))
    _place(alb, nrm, rgh, 0, *_finalize_architectural_tile(ia, ih, ir, ie, 400), strength=4.5, buf_e=emi)

    # 1: Colonial con Reja de Hierro Forjado
    ia, ih, ir, ie = _new_canvas((222, 218, 214), 220, 175, True)
    da, dh, dr, de = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir), ImageDraw.Draw(ie)
    _draw_glass_rect(ia, ih, ir, ie, [56, 48, 456, 452])
    da.rectangle([248, 48, 264, 452], fill=(212, 208, 202))
    dh.rectangle([248, 48, 264, 452], fill=215)
    dr.rectangle([248, 48, 264, 452], fill=175)
    de.rectangle([248, 48, 264, 452], fill=(0, 0, 0))
    for rx in range(84, 440, 56):
        da.rectangle([rx - 5, 36, rx + 5, 464], fill=(44, 47, 50))
        dh.rectangle([rx - 5, 36, rx + 5, 464], fill=240)
        dr.rectangle([rx - 5, 36, rx + 5, 464], fill=110)
        de.rectangle([rx - 5, 36, rx + 5, 464], fill=(0, 0, 0))
    for ry in [140, 360]:
        da.rectangle([44, ry - 6, 468, ry + 6], fill=(44, 47, 50))
        dh.rectangle([44, ry - 6, 468, ry + 6], fill=240)
        dr.rectangle([44, ry - 6, 468, ry + 6], fill=110)
        de.rectangle([44, ry - 6, 468, ry + 6], fill=(0, 0, 0))
    _place(alb, nrm, rgh, 1, *_finalize_architectural_tile(ia, ih, ir, ie, 401), strength=5.0, buf_e=emi)

    # 2: Moderna Marco Minimalista
    ia, ih, ir, ie = _new_canvas((212, 216, 220), 220, 115, True)
    da, dh, dr, de = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir), ImageDraw.Draw(ie)
    _draw_glass_rect(ia, ih, ir, ie, [32, 32, 480, 480])
    da.rectangle([248, 32, 264, 480], fill=(202, 206, 210))
    dh.rectangle([248, 32, 264, 480], fill=220)
    dr.rectangle([248, 32, 264, 480], fill=115)
    de.rectangle([248, 32, 264, 480], fill=(0, 0, 0))
    _place(alb, nrm, rgh, 2, *_finalize_architectural_tile(ia, ih, ir, ie, 402, True), strength=4.0, buf_e=emi)

    # 3: Ventanal Piso-a-Techo / Corredizo Moderno
    ia, ih, ir, ie = _new_canvas((216, 218, 222), 220, 110, True)
    da, dh, dr, de = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir), ImageDraw.Draw(ie)
    _draw_glass_rect(ia, ih, ir, ie, [20, 20, 492, 492])
    for mx in [176, 336]:
        da.rectangle([mx - 6, 20, mx + 6, 492], fill=(202, 206, 210))
        dh.rectangle([mx - 6, 20, mx + 6, 492], fill=215)
        dr.rectangle([mx - 6, 20, mx + 6, 492], fill=115)
        de.rectangle([mx - 6, 20, mx + 6, 492], fill=(0, 0, 0))
    _place(alb, nrm, rgh, 3, *_finalize_architectural_tile(ia, ih, ir, ie, 403, True), strength=4.0, buf_e=emi)

    # 4: Ventana de Barrio LATAM con Reja de Seguridad
    ia, ih, ir, ie = _new_canvas((218, 218, 218), 215, 135, True)
    da, dh, dr, de = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir), ImageDraw.Draw(ie)
    _draw_glass_rect(ia, ih, ir, ie, [36, 36, 476, 476])
    da.rectangle([250, 36, 262, 476], fill=(208, 208, 208))
    dr.rectangle([250, 36, 262, 476], fill=135)
    de.rectangle([250, 36, 262, 476], fill=(0, 0, 0))
    for ry in range(88, 460, 74):
        da.rectangle([24, ry - 4, 488, ry + 4], fill=(64, 66, 70))
        dh.rectangle([24, ry - 4, 488, ry + 4], fill=240)
        dr.rectangle([24, ry - 4, 488, ry + 4], fill=120)
        de.rectangle([24, ry - 4, 488, ry + 4], fill=(0, 0, 0))
    for rx in [140, 256, 372]:
        da.rectangle([rx - 4, 24, rx + 4, 488], fill=(64, 66, 70))
        dh.rectangle([rx - 4, 24, rx + 4, 488], fill=240)
        dr.rectangle([rx - 4, 24, rx + 4, 488], fill=120)
        de.rectangle([rx - 4, 24, rx + 4, 488], fill=(0, 0, 0))
    _place(alb, nrm, rgh, 4, *_finalize_architectural_tile(ia, ih, ir, ie, 404, True), strength=5.0, buf_e=emi)

    # 5: Celosía Aluminio
    ia, ih, ir, ie = _new_canvas((214, 218, 222), 215, 115, True)
    da, dh, dr, de = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir), ImageDraw.Draw(ie)
    _draw_glass_rect(ia, ih, ir, ie, [36, 36, 476, 476])
    for ly in range(60, 470, 30):
        da.rectangle([36, ly - 3, 476, ly + 3], fill=(182, 188, 194))
        dh.rectangle([36, ly - 3, 476, ly + 3], fill=200)
        dr.rectangle([36, ly - 3, 476, ly + 3], fill=115)
        de.rectangle([36, ly - 3, 476, ly + 3], fill=(0, 0, 0))
    da.rectangle([250, 36, 262, 476], fill=(202, 206, 210))
    dh.rectangle([250, 36, 262, 476], fill=220)
    dr.rectangle([250, 36, 262, 476], fill=115)
    de.rectangle([250, 36, 262, 476], fill=(0, 0, 0))
    _place(alb, nrm, rgh, 5, *_finalize_architectural_tile(ia, ih, ir, ie, 405, True), strength=5.0, buf_e=emi)

    # 6: Arco Colonial
    ia, ih, ir, ie = _new_canvas((220, 216, 208), 210, 180, True)
    da, dh, dr, de = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir), ImageDraw.Draw(ie)
    da.pieslice([56, 40, 456, 440], 180, 360, fill=(34, 50, 66))
    dh.pieslice([56, 40, 456, 440], 180, 360, fill=55)
    dr.pieslice([56, 40, 456, 440], 180, 360, fill=18)
    de.pieslice([56, 40, 456, 440], 180, 360, fill=(255, 208, 132))
    _draw_glass_rect(ia, ih, ir, ie, [56, 236, 456, 472])
    da.rectangle([248, 44, 264, 472], fill=(220, 216, 208))
    dh.rectangle([248, 44, 264, 472], fill=215)
    dr.rectangle([248, 44, 264, 472], fill=175)
    de.rectangle([248, 44, 264, 472], fill=(0, 0, 0))
    da.rectangle([56, 230, 456, 246], fill=(220, 216, 208))
    dh.rectangle([56, 230, 456, 246], fill=215)
    dr.rectangle([56, 230, 456, 246], fill=175)
    de.rectangle([56, 230, 456, 246], fill=(0, 0, 0))
    _place(alb, nrm, rgh, 6, *_finalize_architectural_tile(ia, ih, ir, ie, 406), strength=5.0, buf_e=emi)

    # 7: Industrial Loft
    ia, ih, ir, ie = _new_canvas((198, 202, 206), 220, 110, True)
    da, dh, dr, de = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir), ImageDraw.Draw(ie)
    _draw_glass_rect(ia, ih, ir, ie, [28, 28, 484, 484])
    for mx in [142, 256, 370]:
        da.rectangle([mx - 5, 28, mx + 5, 484], fill=(178, 182, 186))
        dh.rectangle([mx - 5, 28, mx + 5, 484], fill=220)
        dr.rectangle([mx - 5, 28, mx + 5, 484], fill=110)
        de.rectangle([mx - 5, 28, mx + 5, 484], fill=(0, 0, 0))
    for my in [142, 256, 370]:
        da.rectangle([28, my - 5, 484, my + 5], fill=(178, 182, 186))
        dh.rectangle([28, my - 5, 484, my + 5], fill=220)
        dr.rectangle([28, my - 5, 484, my + 5], fill=110)
        de.rectangle([28, my - 5, 484, my + 5], fill=(0, 0, 0))
    _place(alb, nrm, rgh, 7, *_finalize_architectural_tile(ia, ih, ir, ie, 407, True), strength=4.5, buf_e=emi)

    # 8: Tradicional Paisa
    ia, ih, ir, ie = _new_canvas((222, 218, 210), 225, 170, True)
    da, dh, dr, de = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir), ImageDraw.Draw(ie)
    _draw_glass_rect(ia, ih, ir, ie, [64, 48, 448, 360])
    da.rectangle([248, 48, 264, 360], fill=(218, 212, 204))
    dr.rectangle([248, 48, 264, 360], fill=170)
    de.rectangle([248, 48, 264, 360], fill=(0, 0, 0))
    da.rectangle([40, 368, 472, 488], fill=(208, 202, 192), outline=(136, 130, 124), width=5)
    dh.rectangle([40, 368, 472, 488], fill=230)
    for bx in range(72, 450, 48):
        da.rectangle([bx, 386, bx + 24, 470], fill=(172, 166, 158))
        dh.rectangle([bx, 386, bx + 24, 470], fill=180)
    _place(alb, nrm, rgh, 8, *_finalize_architectural_tile(ia, ih, ir, ie, 408), strength=5.0, buf_e=emi)

    # 9..15
    for idx, box, extra_fn in [
        (9, [44, 44, 468, 468], lambda da, dh, dr, de: (
            da.rectangle([44, 164, 468, 180], fill=(224, 220, 215)),
            dr.rectangle([44, 164, 468, 180], fill=155),
            de.rectangle([44, 164, 468, 180], fill=(0, 0, 0)),
            da.rectangle([248, 44, 264, 468], fill=(224, 220, 215)),
            dr.rectangle([248, 44, 264, 468], fill=155),
            de.rectangle([248, 44, 264, 468], fill=(0, 0, 0)),
        )),
        (10, [56, 136, 456, 376], lambda da, dh, dr, de: (
            da.rectangle([250, 136, 262, 376], fill=(212, 212, 212)),
            dr.rectangle([250, 136, 262, 376], fill=150),
            de.rectangle([250, 136, 262, 376], fill=(0, 0, 0)),
        )),
        (11, [18, 18, 494, 456], lambda da, dh, dr, de: (
            da.rectangle([18, 456, 494, 498], fill=(192, 196, 200)),
            dr.rectangle([18, 456, 494, 498], fill=160),
        )),
        (13, [24, 96, 488, 416], lambda da, dh, dr, de: (
            da.rectangle([250, 96, 262, 416], fill=(204, 208, 212)),
            dr.rectangle([250, 96, 262, 416], fill=115),
            de.rectangle([250, 96, 262, 416], fill=(0, 0, 0)),
        )),
        (14, [52, 52, 460, 460], lambda da, dh, dr, de: (
            da.rectangle([246, 52, 266, 460], fill=(192, 184, 174)),
            da.rectangle([52, 246, 460, 266], fill=(192, 184, 174)),
            dr.rectangle([246, 52, 266, 460], fill=185),
            dr.rectangle([52, 246, 460, 266], fill=185),
            de.rectangle([246, 52, 266, 460], fill=(0, 0, 0)),
            de.rectangle([52, 246, 460, 266], fill=(0, 0, 0)),
        )),
    ]:
        ia, ih, ir, ie = _new_canvas((216, 216, 214), 215, 145, True)
        da, dh, dr, de = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir), ImageDraw.Draw(ie)
        _draw_glass_rect(ia, ih, ir, ie, box)
        extra_fn(da, dh, dr, de)
        _place(alb, nrm, rgh, idx, *_finalize_architectural_tile(ia, ih, ir, ie, 400 + idx, idx in [11, 13]), strength=4.5, buf_e=emi)

    # 12: Circular
    ia, ih, ir, ie = _new_canvas((218, 218, 218), 215, 150, True)
    da, dh, dr, de = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir), ImageDraw.Draw(ie)
    da.ellipse([48, 48, 464, 464], fill=(28, 42, 56), outline=(175, 175, 175), width=16)
    dh.ellipse([48, 48, 464, 464], fill=55, outline=235, width=16)
    dr.ellipse([64, 64, 448, 448], fill=18)
    de.ellipse([64, 64, 448, 448], fill=(255, 208, 132))
    da.rectangle([250, 64, 262, 448], fill=(208, 208, 208))
    da.rectangle([64, 250, 448, 262], fill=(208, 208, 208))
    dr.rectangle([250, 64, 262, 448], fill=150)
    dr.rectangle([64, 250, 448, 262], fill=150)
    de.rectangle([250, 64, 262, 448], fill=(0, 0, 0))
    de.rectangle([64, 250, 448, 262], fill=(0, 0, 0))
    _place(alb, nrm, rgh, 12, *_finalize_architectural_tile(ia, ih, ir, ie, 412), strength=5.0, buf_e=emi)

    # 15: Muro cortina
    ia, ih, ir, ie = _new_canvas((194, 200, 208), 215, 100, True)
    da, dh, dr, de = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir), ImageDraw.Draw(ie)
    _draw_glass_rect(ia, ih, ir, ie, [10, 10, 502, 502], glow=(205, 228, 255))
    for mx in [170, 342]:
        da.rectangle([mx - 4, 10, mx + 4, 502], fill=(182, 188, 196))
        dr.rectangle([mx - 4, 10, mx + 4, 502], fill=100)
        de.rectangle([mx - 4, 10, mx + 4, 502], fill=(0, 0, 0))
    for my in [170, 342]:
        da.rectangle([10, my - 4, 502, my + 4], fill=(182, 188, 196))
        dr.rectangle([10, my - 4, 502, my + 4], fill=100)
        de.rectangle([10, my - 4, 502, my + 4], fill=(0, 0, 0))
    _place(alb, nrm, rgh, 15, *_finalize_architectural_tile(ia, ih, ir, ie, 415, True), strength=4.0, buf_e=emi)

    Image.fromarray(alb).save(os.path.join(OUT_DIR, "atlas_ventanas_albedo.png"))
    Image.fromarray(nrm).save(os.path.join(OUT_DIR, "atlas_ventanas_normal.png"))
    Image.fromarray(rgh).save(os.path.join(OUT_DIR, "atlas_ventanas_roughness.png"))
    Image.fromarray(emi).save(os.path.join(OUT_DIR, "atlas_ventanas_emission.png"))
    print("OK atlas_ventanas_*")


# ============================================================================
# 3. ATLAS DE PUERTAS (16 estilos con vetas de madera/metal y AO)
# ============================================================================
def generar_atlas_puertas():
    alb, nrm, rgh, _ = _make_atlas_buffers()

    # 0: Colonial Tallada Doble
    ia, ih, ir, _ = _new_canvas((210, 204, 194), 210, 175)
    da, dh, dr = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir)
    da.rectangle([28, 20, 484, 500], fill=(192, 186, 176), outline=(115, 108, 100), width=8)
    dh.rectangle([28, 20, 484, 500], fill=190, outline=235, width=8)
    da.line([(256, 20), (256, 500)], fill=(90, 85, 80), width=6)
    dh.line([(256, 20), (256, 500)], fill=80, width=6)
    for hx in [60, 282]:
        for py, ph in [(56, 120), (200, 120), (344, 120)]:
            da.rectangle([hx, py, hx + 170, py + ph], fill=(170, 162, 154), outline=(112, 106, 98), width=5)
            dh.rectangle([hx, py, hx + 170, py + ph], fill=160, outline=220, width=5)
    da.ellipse([222, 246, 244, 278], fill=(205, 170, 90))
    da.ellipse([268, 246, 290, 278], fill=(205, 170, 90))
    dr.ellipse([222, 246, 244, 278], fill=70)
    dr.ellipse([268, 246, 290, 278], fill=70)
    _place(alb, nrm, rgh, 0, *_finalize_architectural_tile(ia, ih, ir, None, 500)[:3], strength=5.0)

    # 1: Paisa con Postigo
    ia, ih, ir, _ = _new_canvas((218, 212, 204), 215, 165)
    da, dh, dr = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir)
    da.rectangle([32, 20, 480, 500], fill=(202, 196, 188), outline=(120, 114, 106), width=8)
    da.rectangle([96, 68, 416, 224], fill=(162, 156, 148), outline=(108, 102, 95), width=6)
    dh.rectangle([96, 68, 416, 224], fill=150, outline=220, width=6)
    for bx in range(132, 400, 54):
        da.rectangle([bx, 74, bx + 8, 218], fill=(66, 68, 72))
        dh.rectangle([bx, 74, bx + 8, 218], fill=235)
    da.rectangle([88, 260, 424, 464], fill=(180, 174, 166), outline=(116, 110, 102), width=6)
    dh.rectangle([88, 260, 424, 464], fill=170, outline=215, width=6)
    _place(alb, nrm, rgh, 1, *_finalize_architectural_tile(ia, ih, ir, None, 501)[:3], strength=5.0)

    # 2: Moderna Madera y Vidrio
    ia, ih, ir, _ = _new_canvas((210, 206, 200), 215, 145)
    da, dh, dr = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir)
    da.rectangle([28, 18, 484, 500], fill=(196, 192, 186), outline=(108, 106, 102), width=8)
    for gy in range(60, 480, 60):
        da.line([(28, gy), (484, gy)], fill=(152, 148, 142), width=3)
        dh.line([(28, gy), (484, gy)], fill=150, width=3)
    _draw_glass_rect(ia, ih, ir, None, [330, 52, 406, 468])
    da.rectangle([92, 140, 108, 380], fill=(220, 225, 230))
    dr.rectangle([92, 140, 108, 380], fill=55)
    _place(alb, nrm, rgh, 2, *_finalize_architectural_tile(ia, ih, ir, None, 502)[:3], strength=4.5)

    # 3: Minimalista Pivotante
    ia, ih, ir, _ = _new_canvas((198, 202, 206), 220, 120)
    da, dh, dr = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir)
    da.rectangle([24, 16, 488, 502], fill=(182, 186, 190), outline=(92, 96, 100), width=10)
    da.rectangle([376, 110, 396, 400], fill=(225, 228, 232))
    dh.rectangle([376, 110, 396, 400], fill=245)
    dr.rectangle([376, 110, 396, 400], fill=50)
    _place(alb, nrm, rgh, 3, *_finalize_architectural_tile(ia, ih, ir, None, 503, True)[:3], strength=4.0)

    # 4: Residencial con Reja
    ia, ih, ir, _ = _new_canvas((212, 212, 212), 215, 145)
    da, dh, dr = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir)
    da.rectangle([32, 20, 480, 500], fill=(172, 172, 172), outline=(96, 96, 96), width=8)
    for rx in range(68, 460, 48):
        da.rectangle([rx - 4, 28, rx + 4, 492], fill=(50, 52, 56))
        dh.rectangle([rx - 4, 28, rx + 4, 492], fill=245)
        dr.rectangle([rx - 4, 28, rx + 4, 492], fill=110)
    for ry in [130, 260, 390]:
        da.rectangle([32, ry - 5, 480, ry + 5], fill=(50, 52, 56))
        dh.rectangle([32, ry - 5, 480, ry + 5], fill=245)
        dr.rectangle([32, ry - 5, 480, ry + 5], fill=110)
    _place(alb, nrm, rgh, 4, *_finalize_architectural_tile(ia, ih, ir, None, 504, True)[:3], strength=5.0)

    # 5: Vidrio Doble
    ia, ih, ir, _ = _new_canvas((208, 212, 216), 220, 110)
    da, dh, dr = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir)
    da.rectangle([28, 28, 244, 496], fill=(182, 186, 190))
    da.rectangle([268, 28, 484, 496], fill=(182, 186, 190))
    _draw_glass_rect(ia, ih, ir, None, [42, 42, 230, 482])
    _draw_glass_rect(ia, ih, ir, None, [282, 42, 470, 482])
    da.rectangle([210, 220, 224, 320], fill=(225, 228, 232))
    da.rectangle([288, 220, 302, 320], fill=(225, 228, 232))
    _place(alb, nrm, rgh, 5, *_finalize_architectural_tile(ia, ih, ir, None, 505, True)[:3], strength=4.0)

    # 6: Cortina Santamaría
    ia, ih, ir, _ = _new_canvas((198, 202, 206), 200, 120)
    da, dh, dr = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir)
    for sy in range(16, 500, 24):
        da.rectangle([16, sy, 496, sy + 20], fill=(180, 184, 190), outline=(118, 122, 128), width=2)
        dh.rectangle([16, sy, 496, sy + 20], fill=215, outline=100, width=2)
    da.rectangle([210, 446, 302, 472], fill=(88, 92, 96))
    _place(alb, nrm, rgh, 6, *_finalize_architectural_tile(ia, ih, ir, None, 506, True)[:3], strength=5.5)

    # 7: Garaje Seccional
    ia, ih, ir, _ = _new_canvas((210, 214, 218), 210, 125)
    da, dh, dr = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir)
    for sy in range(20, 492, 118):
        da.rectangle([20, sy, 492, sy + 108], fill=(194, 198, 202), outline=(128, 132, 136), width=4)
        dh.rectangle([20, sy, 492, sy + 108], fill=210, outline=110, width=4)
    for wx in [56, 176, 296, 416]:
        _draw_glass_rect(ia, ih, ir, None, [wx, 44, wx + 64, 96])
    _place(alb, nrm, rgh, 7, *_finalize_architectural_tile(ia, ih, ir, None, 507, True)[:3], strength=4.5)

    # 8..15
    for idx, fn in [
        (8, lambda ia, ih, ir, da, dh, dr: (
            da.rectangle([16, 16, 496, 502], fill=(182, 174, 162), outline=(108, 100, 90), width=10),
            [da.line([(px, 16), (px, 502)], fill=(118, 110, 100), width=4) for px in range(48, 480, 48)],
            da.line([(24, 24), (250, 490)], fill=(58, 56, 54), width=14),
            da.line([(488, 24), (262, 490)], fill=(58, 56, 54), width=14),
        )),
        (9, lambda ia, ih, ir, da, dh, dr: (
            da.pieslice([40, 28, 472, 420], 180, 360, fill=(174, 166, 156), outline=(104, 96, 88), width=8),
            da.rectangle([40, 220, 472, 502], fill=(174, 166, 156), outline=(104, 96, 88), width=8),
            da.line([(256, 32), (256, 502)], fill=(98, 92, 86), width=6),
        )),
        (10, lambda ia, ih, ir, da, dh, dr: (
            [da.rectangle([px, 16, px + 60, 502], fill=(180, 172, 160), outline=(110, 102, 92), width=3) for px in range(24, 490, 66)],
            [da.rectangle([32, ry, 480, ry + 32], fill=(138, 132, 124)) for ry in [110, 400]],
        )),
        (11, lambda ia, ih, ir, da, dh, dr: (
            da.rectangle([28, 20, 484, 500], fill=(192, 196, 200), outline=(118, 122, 126), width=8),
            _draw_glass_rect(ia, ih, ir, None, [146, 74, 366, 190]),
            da.rectangle([92, 240, 420, 464], fill=(178, 182, 186), outline=(118, 122, 126), width=4),
        )),
        (12, lambda ia, ih, ir, da, dh, dr: (
            _draw_glass_rect(ia, ih, ir, None, [44, 28, 468, 112]),
            da.rectangle([36, 128, 476, 500], fill=(208, 204, 196), outline=(128, 122, 116), width=8),
            [da.rectangle([86, py, 232, py + 132], fill=(190, 186, 178), outline=(128, 122, 116), width=4) for py in [160, 328]],
            [da.rectangle([280, py, 426, py + 132], fill=(190, 186, 178), outline=(128, 122, 116), width=4) for py in [160, 328]],
        )),
        (13, lambda ia, ih, ir, da, dh, dr: (
            da.rectangle([20, 20, 250, 496], fill=(192, 196, 200)),
            da.rectangle([262, 20, 492, 496], fill=(192, 196, 200)),
            _draw_glass_rect(ia, ih, ir, None, [32, 32, 238, 484]),
            _draw_glass_rect(ia, ih, ir, None, [274, 32, 480, 484]),
        )),
        (14, lambda ia, ih, ir, da, dh, dr: (
            da.rectangle([16, 20, 496, 500], fill=(168, 172, 176), outline=(88, 92, 96), width=10),
            da.line([(256, 20), (256, 500)], fill=(78, 82, 86), width=8),
            [da.rectangle([rx, 44, rx + 8, 240], fill=(54, 56, 60)) for rx in range(52, 476, 44)],
        )),
        (15, lambda ia, ih, ir, da, dh, dr: (
            da.rectangle([28, 20, 484, 500], fill=(68, 70, 74)),
            _draw_glass_rect(ia, ih, ir, None, [40, 32, 472, 488]),
            [da.rectangle([rx - 5, 24, rx + 5, 496], fill=(58, 60, 64)) for rx in [140, 256, 372]],
            [da.rectangle([32, ry - 5, 480, ry + 5], fill=(58, 60, 64)) for ry in [160, 340]],
        )),
    ]:
        ia, ih, ir, _ = _new_canvas((208, 204, 198), 215, 145)
        da, dh, dr = ImageDraw.Draw(ia), ImageDraw.Draw(ih), ImageDraw.Draw(ir)
        fn(ia, ih, ir, da, dh, dr)
        _place(alb, nrm, rgh, idx, *_finalize_architectural_tile(ia, ih, ir, None, 500 + idx, idx in [11, 13, 14, 15])[:3], strength=5.0)

    Image.fromarray(alb).save(os.path.join(OUT_DIR, "atlas_puertas_albedo.png"))
    Image.fromarray(nrm).save(os.path.join(OUT_DIR, "atlas_puertas_normal.png"))
    Image.fromarray(rgh).save(os.path.join(OUT_DIR, "atlas_puertas_roughness.png"))
    print("OK atlas_puertas_*")


# ============================================================================
# 4. ATLAS DE TECHOS Y PISOS (16 materiales realistas)
# ============================================================================
def generar_atlas_techos():
    alb, nrm, rgh, _ = _make_atlas_buffers()
    yy, xx = np.mgrid[0:TILE, 0:TILE].astype(np.float32)
    micro = _rng(888).random((TILE, TILE), dtype=np.float32) * 0.04

    # 0: Teja de Barro Española / Colonial
    n0 = _fbm(TILE, TILE, 300, 5, 6)
    wave_x = np.sin(xx * (2 * np.pi / 42.666)) * 0.5 + 0.5
    row_step = (yy % 64) / 64.0
    ao_row = np.clip((yy % 64) / 10.0, 0.55, 1.0)
    h0 = np.clip(wave_x * 0.62 + row_step * 0.38 + (n0 - 0.5) * 0.14 + micro, 0, 1)
    shade0 = (0.64 + h0 * 0.34 + (n0 - 0.5) * 0.16) * ao_row
    a0 = np.stack([0.54 * shade0, 0.28 * shade0, 0.20 * shade0], axis=-1)
    r0 = np.full((TILE, TILE), 0.80)
    _place(alb, nrm, rgh, 0, a0, h0, r0, strength=7.0)

    # 1: Teja de Barro Envejecida / Antigua
    moss = np.clip((n0 - 0.52) * 2.5, 0, 1)
    a1 = np.stack([
        0.54 * shade0 * (1 - moss * 0.5) + 0.20 * moss,
        0.27 * shade0 * (1 - moss * 0.3) + 0.28 * moss,
        0.17 * shade0 * (1 - moss * 0.5) + 0.14 * moss,
    ], axis=-1)
    r1 = np.full((TILE, TILE), 0.88)
    _place(alb, nrm, rgh, 1, a1, h0, r1, strength=7.0)

    # 2: Shingle Asfáltico Oscuro
    n2 = _fbm(TILE, TILE, 302, 6, 8)
    sh_y = ((yy % 48) < 3).astype(np.float32)
    off2 = ((yy // 48) % 2) * 64
    sh_x = (((xx + off2) % 128) < 3).astype(np.float32)
    h2 = np.clip(0.75 + (n2 - 0.5) * 0.28 - np.maximum(sh_y, sh_x) * 0.45 + micro * 2.0, 0, 1)
    c2 = 0.24 + (n2 - 0.5) * 0.12 - sh_y * 0.08
    a2 = np.stack([c2, c2 * 1.01, c2 * 1.04], axis=-1)
    r2 = np.full((TILE, TILE), 0.88)
    _place(alb, nrm, rgh, 2, a2, h2, r2, strength=5.0)

    # 3: Teja de Zinc / Eternit Ondulada (tintable)
    wave3 = np.sin(xx * (2 * np.pi / 32.0)) * 0.5 + 0.5
    n3 = _fbm(TILE, TILE, 303, 4, 5)
    h3 = wave3 * 0.85 + 0.1
    c3 = 0.72 + wave3 * 0.22 + (n3 - 0.5) * 0.10
    a3 = np.stack([c3, c3, c3 * 1.02], axis=-1)
    r3 = np.full((TILE, TILE), 0.42)
    _place(alb, nrm, rgh, 3, a3, h3, r3, strength=6.0)

    # 4: Standing Seam Metálico (tintable)
    seam4 = ((xx % 128) < 6).astype(np.float32)
    n4 = _fbm(TILE, TILE, 304, 4, 6)
    h4 = np.clip(0.35 + seam4 * 0.65, 0, 1)
    c4 = 0.80 + (n4 - 0.5) * 0.08 - seam4 * 0.15
    a4 = np.stack([c4, c4, c4], axis=-1)
    r4 = np.full((TILE, TILE), 0.34)
    _place(alb, nrm, rgh, 4, a4, h4, r4, strength=5.5)

    # 5: Losa de Concreto / Terraza Plana
    n5 = _fbm(TILE, TILE, 305, 6, 5)
    grid5 = np.maximum(((xx % 256) < 3).astype(np.float32), ((yy % 256) < 3).astype(np.float32))
    h5 = np.clip(0.7 + (n5 - 0.5) * 0.28 - grid5 * 0.35 + micro, 0, 1)
    c5 = 0.64 + (n5 - 0.5) * 0.18 - grid5 * 0.16
    a5 = np.stack([c5, c5, c5], axis=-1)
    r5 = np.full((TILE, TILE), 0.88)
    _place(alb, nrm, rgh, 5, a5, h5, r5, strength=4.5)

    # 6: Paja / Palma Tropical
    n6 = _fbm(TILE, TILE, 306, 6, 6)
    straw = np.sin(xx * 1.4 + n6 * 12.0) * 0.5 + 0.5
    layer6 = (yy % 64) / 64.0
    h6 = np.clip(straw * 0.5 + layer6 * 0.4 + n6 * 0.2, 0, 1)
    c6 = 0.50 + straw * 0.24 + (n6 - 0.5) * 0.18
    a6 = np.stack([c6 * 1.04, c6 * 0.85, c6 * 0.46], axis=-1)
    r6 = np.full((TILE, TILE), 0.94)
    _place(alb, nrm, rgh, 6, a6, h6, r6, strength=6.5)

    # 7: Pizarra Negra
    n7 = _fbm(TILE, TILE, 307, 5, 5)
    sl_y = ((yy % 64) < 3).astype(np.float32)
    sl_x = (((xx + ((yy // 64) % 2) * 64) % 128) < 3).astype(np.float32)
    h7 = np.clip(0.75 + (n7 - 0.5) * 0.26 - np.maximum(sl_y, sl_x) * 0.5, 0, 1)
    c7 = 0.26 + (n7 - 0.5) * 0.10 - np.maximum(sl_y, sl_x) * 0.10
    a7 = np.stack([c7, c7 * 1.02, c7 * 1.06], axis=-1)
    r7 = np.full((TILE, TILE), 0.55)
    _place(alb, nrm, rgh, 7, a7, h7, r7, strength=5.5)

    # 8: Policarbonato
    rib8 = np.sin(xx * (2 * np.pi / 24.0)) * 0.5 + 0.5
    h8 = rib8 * 0.6 + 0.2
    c8 = 0.84 + rib8 * 0.12
    a8 = np.stack([c8 * 0.94, c8 * 0.98, c8], axis=-1)
    r8 = np.full((TILE, TILE), 0.18)
    _place(alb, nrm, rgh, 8, a8, h8, r8, strength=4.0)

    # 9: Deck de Madera
    grain9 = _wood_grain(TILE, TILE, 309, vertical=False)
    groove9 = ((yy % 64) < 4).astype(np.float32)
    h9 = np.clip(0.78 - groove9 * 0.6 + (grain9 - 0.5) * 0.18, 0, 1)
    c9 = 0.66 - groove9 * 0.30 + (grain9 - 0.5) * 0.18
    a9 = np.stack([c9 * 0.96, c9 * 0.72, c9 * 0.48], axis=-1)
    r9 = np.full((TILE, TILE), 0.68)
    _place(alb, nrm, rgh, 9, a9, h9, r9, strength=5.0)

    # 10: Baldosa Roja Azotea
    grid10 = np.maximum(((xx % 64) < 3).astype(np.float32), ((yy % 64) < 3).astype(np.float32))
    n10 = _fbm(TILE, TILE, 310, 5, 5)
    h10 = np.clip(0.85 - grid10 * 0.5 + micro, 0, 1)
    c10 = np.where(grid10 > 0.5, 0.40, 0.70 + (n10 - 0.5) * 0.14)
    a10 = np.stack([c10 * 0.98, c10 * 0.52, c10 * 0.36], axis=-1)
    r10 = np.where(grid10 > 0.5, 0.88, 0.54)
    _place(alb, nrm, rgh, 10, a10, h10, r10, strength=4.5)

    # 11: Adoquín / Piedra
    grid11 = np.maximum(((xx % 64) < 3).astype(np.float32), ((yy % 32) < 3).astype(np.float32))
    n11 = _fbm(TILE, TILE, 311, 5, 6)
    h11 = np.clip(0.80 - grid11 * 0.55 + (n11 - 0.5) * 0.22, 0, 1)
    c11 = np.where(grid11 > 0.5, 0.36, 0.64 + (n11 - 0.5) * 0.16)
    a11 = np.stack([c11, c11 * 0.96, c11 * 0.92], axis=-1)
    r11 = np.full((TILE, TILE), 0.82)
    _place(alb, nrm, rgh, 11, a11, h11, r11, strength=5.5)

    # 12: Concreto Pulido
    n12 = _fbm(TILE, TILE, 312, 5, 5)
    h12 = 0.6 + (n12 - 0.5) * 0.16
    c12 = 0.72 + (n12 - 0.5) * 0.12
    a12 = np.stack([c12, c12, c12], axis=-1)
    r12 = np.full((TILE, TILE), 0.58)
    _place(alb, nrm, rgh, 12, a12, h12, r12, strength=2.5)

    # 13: Teja Esmaltada (tintable)
    a13 = np.stack([0.85 * (0.65 + h0 * 0.35)] * 3, axis=-1)
    r13 = np.full((TILE, TILE), 0.28)
    _place(alb, nrm, rgh, 13, a13, h0, r13, strength=6.5)

    # 14: Grava de Azotea
    grit14 = _rng(314).random((TILE, TILE), dtype=np.float32)
    n14 = _fbm(TILE, TILE, 315, 5, 8)
    h14 = grit14 * 0.6 + n14 * 0.4
    c14 = 0.50 + (h14 - 0.5) * 0.30
    a14 = np.stack([c14, c14, c14], axis=-1)
    r14 = np.full((TILE, TILE), 0.92)
    _place(alb, nrm, rgh, 14, a14, h14, r14, strength=7.5)

    # 15: Cielorraso Machihembrado
    grain15 = _wood_grain(TILE, TILE, 316, vertical=True)
    groove15 = ((xx % 48) < 3).astype(np.float32)
    h15 = np.clip(0.8 - groove15 * 0.55 + (grain15 - 0.5) * 0.14, 0, 1)
    c15 = 0.74 - groove15 * 0.25 + (grain15 - 0.5) * 0.14
    a15 = np.stack([c15 * 0.95, c15 * 0.74, c15 * 0.50], axis=-1)
    r15 = np.full((TILE, TILE), 0.65)
    _place(alb, nrm, rgh, 15, a15, h15, r15, strength=4.5)

    Image.fromarray(alb).save(os.path.join(OUT_DIR, "atlas_techos_albedo.png"))
    Image.fromarray(nrm).save(os.path.join(OUT_DIR, "atlas_techos_normal.png"))
    Image.fromarray(rgh).save(os.path.join(OUT_DIR, "atlas_techos_roughness.png"))
    print("OK atlas_techos_*")


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    generar_atlas_fachadas()
    generar_atlas_ventanas()
    generar_atlas_puertas()
    generar_atlas_techos()
    print(f"Todos los atlas realistas generados en: {OUT_DIR}")

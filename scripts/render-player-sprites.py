"""Bake the approved local v3 model into native-resolution runtime frames.

Run with Blender --background --python scripts/render-player-sprites.py.
Requires the approved local source and its palette/propeller helper scripts.
Use -- --preview for a small scale/outline check before the full bake.
No model edits, per-frame recentering, camera movement or image interpolation.
"""
import sys
import math
import json
import hashlib
from pathlib import Path
import bpy
from mathutils import Quaternion

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'work/blender'))
import render_airframe_poses as source
from propeller_speed_fx import add_speed_effects, FRAME_COUNT, FRAME_MS

OUT = ROOT / 'work/player-sprite-bake'
VIEWS = [('side', '横版', (80, 60)), ('top', '俯视', (64, 64)),
         ('chase', '追尾', (112, 84))]
STEPS = 9


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    scene, root, source_hash, geometry_hash = source.rig()
    cameras = {name: source.make_camera(label)[0] for name, label, _ in VIEWS}
    source.pixel_materials()
    # Native-size painted metal already separates the surfaces. At 64 px,
    # outlining every 3D silhouette erases small parts; the atlas packer adds
    # one outside-only pixel contour instead. No smoothing/upscaling pass.
    scene.render.use_freestyle = False
    scene.render.image_settings.compression = 30
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 8
    fx = add_speed_effects(root)
    root.rotation_mode = 'QUATERNION'
    preview = '--preview' in sys.argv
    body_only = '--body-only' in sys.argv
    if body_only:
        for obj in scene.objects:
            if obj.get('propeller_fx', False):
                obj.hide_render = True
    report = {'source_sha256': source_hash, 'geometry_sha256': geometry_hash,
              'roll_steps': STEPS, 'prop_frames': FRAME_COUNT, 'frame_ms': FRAME_MS,
              'views': {}, 'propeller_fx': fx, 'poses': {}}
    for name, label, size in VIEWS:
        folder = OUT / name
        folder.mkdir(exist_ok=True)
        pitch_steps = STEPS if name == 'chase' else 1
        report['views'][name] = {'size': size, 'pitch_steps': pitch_steps,
                                 'roll_max': 25 if name == 'chase' else 26}
        for p in range(pitch_steps):
            pitch = 0 if pitch_steps == 1 else (p - 4) / 4 * (23 if p >= 4 else 25)
            for r in range(STEPS):
                roll = (r - 4) / 4 * report['views'][name]['roll_max']
                if preview and (r, p) not in ([(4, 0), (0, 0), (8, 0)] if name != 'chase' else [(4, 4), (4, 0), (8, 8)]):
                    continue
                # Pitch about fixed lateral axis, then roll around the local
                # longitudinal axis: diagonal input adds no unintended yaw.
                root.rotation_quaternion = (Quaternion((1, 0, 0), math.radians(pitch))
                                            @ Quaternion((0, 1, 0), math.radians(roll)))
                bpy.context.view_layer.update()
                scene.camera = cameras[name]
                scene.render.resolution_x, scene.render.resolution_y = size
                key = f'{name}-p{p}-r{r}'
                report['poses'][key] = source.orientation_check(scene, root, cameras[name], key, roll, pitch)
                for phase in range(1 if preview or body_only else FRAME_COUNT):
                    scene.frame_set(phase + 1)
                    target = folder / (f'p{p}-r{r}-body.png' if body_only else f'p{p}-r{r}-f{phase}.png')
                    source.render(scene, cameras[name], size, target)
                print('BAKE POSE', key, flush=True)
    assert source.geometry_hash() == geometry_hash
    assert source.checksum() == source_hash
    report['source_unchanged'] = True
    report['geometry_unchanged'] = True
    (OUT / ('body-manifest.json' if body_only else 'preview.json' if preview else 'manifest.json')).write_text(json.dumps(report, indent=2), encoding='utf-8')
    print('PLAYER BAKE PASS:', len(report['poses']), 'rigid poses; source and geometry unchanged', flush=True)


if __name__ == '__main__':
    main()

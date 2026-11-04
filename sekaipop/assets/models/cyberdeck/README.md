# SKP-01 cyberdeck model

Original geometry created for SekaiPop, distributed under the repository license.
`cyberdeck.obj` and `cyberdeck.mtl` are the runtime model and materials. No third-party
assets or textures are used. Rebuild deterministically with `python3 build-model.py`.

Model coordinates match CyberdeckFace's 1100 × 670 design space, centered at the
origin with +Y up and +Z toward the camera. The interactive face is at z=20;
keycaps end at z=18, the recessed screen rails at z=23. The back shell reaches
z=-62. Keep these dimensions aligned when changing the face layout. Qt loads the
mesh via RuntimeLoader; no Balsam, Blender or qsb is required to import it.

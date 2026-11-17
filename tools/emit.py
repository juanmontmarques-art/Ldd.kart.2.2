import sys; sys.path.insert(0,'/home/claude/tools')
from gen_layouts import *

def fmt_list(vals):
    return '[' + ', '.join(vals) + ']'

lines = []
lines.append('class_name TrackLayouts')
lines.append('extends RefCounted')
lines.append('')
lines.append('# GERADO por tools/gen_layouts.py - traçados dos mapas extras (Deserto, Gelo, Vulcão).')
lines.append('# "points" = pontos de controle (x, altura, z) da curva Catmull-Rom; o resto são índices de amostra')
lines.append('# (a cada 2,5 m) de abismos, penhascos, pads etc. Veja track_data.gd para o significado.')
lines.append('')
lines.append('static func get_layout(map_id: String) -> Dictionary:')
lines.append('    match map_id:')
lines.append('        "deserto":')
lines.append('            return _deserto()')
lines.append('        "gelo":')
lines.append('            return _gelo()')
lines.append('        "vulcao":')
lines.append('            return _vulcao()')
lines.append('    return {}')
lines.append('')
stats = {}
for name, sp in SPEC.items():
    r = build_map(name, sp['verts'], sp['anchors'], sp['start'], sp['feats'], None, sp['lakes'], sp['peak'], sp['seed'])
    cps = r['cps']
    flat = []
    for (x, h, z) in cps:
        flat += ['%.1f' % x, '%.1f' % h, '%.1f' % z]
    hairpins = sum(1 for g in r['path']['segs'] if g['kind']=='arc' and math.degrees(g['theta'])>95)
    hs = [q[1] for q in r['pts']]
    stats[name] = dict(km=r['length']/1000, gaps=len(r['gaps']), cliffs=len(r['cliffs']), hairpins=hairpins, alt=max(hs)-min(hs), ctrl=len(cps), count=r['count'])
    lines.append('static func _%s() -> Dictionary:' % name)
    lines.append('    var pts := PackedFloat32Array([')
    for i in range(0, len(flat), 15):
        lines.append('        ' + ', '.join(flat[i:i+15]) + ',')
    lines.append('    ])')
    lines.append('    return {')
    lines.append('        "points": pts,')
    lines.append('        "gaps": [' + ', '.join('Vector3(%d, %d, %.1f)' % g for g in r['gaps']) + '],')
    lines.append('        "cliffs": [' + ', '.join('Vector2i(%d, %d)' % c for c in r['cliffs']) + '],')
    lines.append('        "canyons": [' + ', '.join('Vector2i(%d, %d)' % c for c in r['canyons']) + '],')
    pads = r['pads']; lats = r['pad_lats']
    lines.append('        "pads": [' + ', '.join(str(i) for i in pads) + '],')
    lines.append('        "pad_lats": [' + ', '.join('%.1f' % l for l in lats) + '],')
    lines.append('        "ramps": [' + ', '.join(str(i) for i in r['ramps']) + '],')
    lines.append('        "boxes": [' + ', '.join(str(i) for i in r['boxes']) + '],')
    lines.append('        "barrels": [' + ', '.join(str(i) for i in r['barrels']) + '],')
    lines.append('        "movers": [' + ', '.join(str(i) for i in r['movers']) + '],')
    lines.append('        "lakes": [' + ', '.join('Vector4(%.0f, %.0f, %.0f, %.1f)' % l for l in r['lakes']) + '],')
    if r['peak']:
        pk = r['peak']
        lines.append('        "peaks": [Vector4(%.0f, %.0f, %.0f, %.0f)],' % (pk[0], pk[1], pk[2], pk[3]))
        lines.append('        "craters": [%.1f],' % pk[4])
    else:
        lines.append('        "peaks": [],')
        lines.append('        "craters": [],')
    lines.append('    }')
    lines.append('')
open('/home/claude/kart_src/track_layouts.gd','w').write('\n'.join(lines))
for k,v in stats.items(): print(k, v)

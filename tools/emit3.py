import sys; sys.path.insert(0,'/home/claude/tools')
import math, gen3, specs3

L = []
L.append('class_name TrackLayoutsExt')
L.append('extends RefCounted')
L.append('')
L.append('# GERADO por tools/emit3.py - traçados dos mapas v10 (Lagoa, Cume, Selva).')
L.append('# Além dos campos de TrackLayouts: "tunnels" (início, fim, tipo), "bridges" (início, fim, tipo),')
L.append('# "branches" (atalhos) e parâmetros de inclinação lateral das curvas.')
L.append('')
L.append('static func get_layout(map_id: String) -> Dictionary:')
L.append('    match map_id:')
for n in specs3.SPEC3:
    L.append('        "%s":' % n)
    L.append('            return _%s()' % n)
L.append('    return {}')
L.append('')
stats = {}
for name, sp in specs3.SPEC3.items():
    r = gen3.build_map3(name, sp)
    flat = []
    for (x, h, z) in r['cps']:
        flat += ['%.1f' % x, '%.1f' % h, '%.1f' % z]
    hairpins = sum(1 for g in r['path']['segs'] if g['kind'] == 'arc' and math.degrees(g['theta']) > 95)
    hs = [q[1] for q in r['pts']]
    stats[name] = dict(km=round(r['length']/1000, 2), gaps=len(r['gaps']), tunnels=len(r['tunnels']), bridges=len(r['bridges']),
                       branches=len(r['branches']), alt=round(max(hs)-min(hs)), sep=round(r['sep']), count=r['count'], frac=round(r['frac'], 3))
    L.append('static func _%s() -> Dictionary:' % name)
    L.append('    var pts := PackedFloat32Array([')
    for i in range(0, len(flat), 15):
        L.append('        ' + ', '.join(flat[i:i+15]) + ',')
    L.append('    ])')
    L.append('    var branches: Array = []')
    for b in r['branches']:
        bf = []
        for (x, h, z) in b['ctrl']:
            bf += ['%.1f' % x, '%.1f' % h, '%.1f' % z]
        L.append('    branches.append({')
        L.append('        "a": %d, "c": %d, "half": %.1f,' % (b['a'], b['c'], b['half']))
        tm = b['tunnel']
        L.append('        "tunnel": Vector2i(%d, %d),' % ((tm[0], -tm[1]) if tm else (-1, -1)))
        L.append('        "ramps": [' + ', '.join(str(i) for i in b['ramps']) + '],')
        L.append('        "ctrl": PackedFloat32Array([' + ', '.join(bf) + ']),')
        L.append('    })')
    L.append('    return {')
    L.append('        "points": pts,')
    L.append('        "gaps": [' + ', '.join('Vector3(%d, %d, %.1f)' % g for g in r['gaps']) + '],')
    L.append('        "cliffs": [' + ', '.join('Vector2i(%d, %d)' % c for c in r['cliffs']) + '],')
    L.append('        "canyons": [' + ', '.join('Vector2i(%d, %d)' % c for c in r['canyons']) + '],')
    L.append('        "pads": [' + ', '.join(str(i) for i in r['pads']) + '],')
    L.append('        "pad_lats": [' + ', '.join('%.1f' % l for l in r['pad_lats']) + '],')
    L.append('        "ramps": [' + ', '.join(str(i) for i in r['ramps']) + '],')
    L.append('        "boxes": [' + ', '.join(str(i) for i in r['boxes']) + '],')
    L.append('        "barrels": [' + ', '.join(str(i) for i in r['barrels']) + '],')
    L.append('        "movers": [' + ', '.join(str(i) for i in r['movers']) + '],')
    L.append('        "lakes": [' + ', '.join('Vector4(%.0f, %.0f, %.0f, %.1f)' % l for l in r['lakes']) + '],')
    L.append('        "peaks": [' + ', '.join('Vector4(%.0f, %.0f, %.0f, %.0f)' % tuple(p[:4]) for p in r['peaks']) + '],')
    L.append('        "craters": [],')
    L.append('        "tunnels": [' + ', '.join('Vector3i(%d, %d, %d)' % t for t in r['tunnels']) + '],')
    L.append('        "bridges": [' + ', '.join('Vector3i(%d, %d, %d)' % t for t in r['bridges']) + '],')
    L.append('        "twists": [' + ', '.join('Vector4(%d, %d, %.1f, %.1f)' % t for t in r['twists']) + '],')
    L.append('        "branches": branches,')
    L.append('        "bank_gain": %.1f,' % r['bank_gain'])
    L.append('        "bank_max": %.2f,' % r['bank_max'])
    L.append('    }')
    L.append('')
open('/home/claude/kart_src/track_layouts_ext.gd', 'w').write('\n'.join(L))
for k, v in stats.items(): print(k, v)

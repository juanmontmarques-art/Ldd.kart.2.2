"""WONDERLAND - definição das peças do circuito (8 setores) + plano macro (rumos no fim de cada setor)."""
from wonderland_path import *

Y0 = 400.0   # altura da plataforma de largada (a altura final fecha com a subida do Setor 8)

SECTORS = {
    1: [  # THE EDGE - plataforma no topo da montanha, cristas, pontes suspensas
        L('s1_plat', 360, 0.0, 1),
        A('s1_a1', -70, 140, -0.015, 1),
        L('s1_bridge1', 230, -0.02, 1),
        A('s1_a2', 118, 90, -0.02, 1),
        L('s1_l3', 150, -0.025, 1),
        A('s1_a3', -80, 105, -0.02, 1),
        L('s1_bridge2', 230, -0.03, 1),
        A('s1_a4', 55, 120, -0.025, 1),
        L('s1_lip', 120, -0.02, 1),
    ],
    2: [  # FREEFALL
        L('s2_f1', 90, -0.95, 2),
        L('s2_p1', 50, -0.02, 2),
        A('s2_f2', 100, 52, -0.80, 2),
        L('s2_p2', 44, -0.03, 2),
        L('s2_f3', 100, -0.78, 2),
        L('s2_f4', 40, -1.05, 2),
        A('s2_f5', -85, 60, -0.65, 2),
        L('s2_p3', 80, -0.03, 2),
    ],
    3: [  # THE ABYSS
        L('s3_b1', 170, -0.012, 3),
        A('s3_a1', 70, 100, -0.012, 3),
        L('s3_j1', 190, -0.012, 3),
        A('s3_a2', -100, 90, -0.012, 3),
        L('s3_b2', 200, -0.012, 3),
        A('s3_a3', 80, 85, -0.012, 3),
        L('s3_j2', 170, -0.012, 3),
        A('s3_a4', -60, 100, -0.012, 3),
        L('s3_b3', 190, -0.012, 3),
    ],
    4: [  # UNDERWORLD
        L('s4_in', 140, -0.035, 4),
        A('s4_a1', 95, 130, -0.02, 4),
        L('s4_riv1', 270, -0.025, 4),
        A('s4_a2', -105, 110, -0.03, 4),
        L('s4_lake', 210, -0.02, 4),
        A('s4_a3', 80, 120, -0.03, 4),
        L('s4_fall', 200, -0.03, 4),
    ],
    5: [  # CRYSTAL LABYRINTH
        A('s5_a1', -75, 52, -0.025, 5),
        L('s5_l1', 70, -0.02, 5),
        A('s5_a2', 110, 46, -0.025, 5),
        L('s5_l2', 60, -0.02, 5),
        A('s5_a3', -95, 48, -0.025, 5),
        L('s5_l3', 90, -0.02, 5),
        A('s5_a4', 120, 50, -0.025, 5),
        L('s5_l4', 70, -0.02, 5),
        A('s5_a5', -110, 50, -0.025, 5),
        L('s5_l5', 100, -0.02, 5),
        A('s5_a6', 85, 55, -0.025, 5),
        L('s5_l6', 120, -0.02, 5),
    ],
    6: [  # THE INFERNO
        L('s6_in', 130, -0.03, 6),
        A('s6_a1', -90, 120, -0.02, 6),
        L('s6_bridge', 300, -0.015, 6),
        A('s6_a2', 100, 100, -0.025, 6),
        L('s6_l2', 160, -0.02, 6),
        A('s6_a3', -80, 90, -0.025, 6),
        L('s6_l3', 190, -0.03, 6),
    ],
    7: [  # GRAVITY BREAK
        L('s7_in', 130, -0.04, 7),
        L('s7_screw', 240, -0.02, 7),
        A('s7_h1', 360, 88, -0.10, 7),
        L('s7_inv', 330, -0.02, 7),
        A('s7_a2', 90, 90, -0.05, 7),
        L('s7_l2', 170, -0.05, 7),
    ],
    8: [  # THE ASCENT
        L('s8_in', 300, 0.18, 8, slope0=0.18),
        A('s8_sp1', -360, 115, 0.20, 8, slope0=0.20),
        LIFT('s8_lift1', 26, 45, 8),
        A('s8_sp2', -360, 108, 0.20, 8, slope0=0.20),
        LIFT('s8_lift2', 26, 45, 8),
        L('s8_l1', 350, 0.18, 8, slope0=0.18),
    ],
}

POST = {8: [L('s8_fin', 260, 0.0, 8)]}

# rumo (graus, desenrolado mod 360) ao FIM de cada setor; o conector (arco) de cada setor é calculado.
# Rumo 0 = leste; negativo = horário.
MACRO_END = {1: -35, 2: -75, 3: -150, 4: -180, 5: -180, 6: -200, 7: -270, 8: -360}
CONN_R = {1: 150, 2: 120, 3: 130, 4: 150, 5: 80, 6: 150, 7: 130, 8: 140}
CONN_SLOPE = {1: -0.02, 2: -0.03, 3: -0.012, 4: -0.03, 5: -0.02, 6: -0.03, 7: -0.04, 8: 0.0}
CONN_SLOPE0 = {8: 0.0}

# retas com comprimento livre para o fechamento (nome: (min, max))
FREE = {
    's1_l3': (60, 400), 's1_lip': (80, 220),
    's3_b1': (100, 300), 's3_j1': (150, 260), 's3_b2': (120, 300), 's3_j2': (140, 240), 's3_b3': (100, 300),
    's4_in': (100, 260), 's4_riv1': (180, 420), 's4_lake': (120, 360), 's4_fall': (120, 320),
    's5_l1': (40, 140), 's5_l3': (40, 140), 's5_l5': (40, 140), 's5_l6': (60, 220),
    's6_in': (80, 260), 's6_bridge': (200, 460), 's6_l2': (100, 320), 's6_l3': (100, 320),
    's7_in': (80, 260), 's7_inv': (250, 420), 's7_l2': (80, 300),
    's8_in': (100, 900), 's8_l1': (100, 1000), 's8_fin': (200, 400),
}

CLIMB = ['s8_in', 's8_sp1', 's8_sp2', 's8_l1']


def assemble(macro_end=None, conn_r=None):
    macro_end = macro_end or MACRO_END
    conn_r = conn_r or CONN_R
    pieces = []
    heading = 0.0
    for sec in range(1, 9):
        part = [dict(p) for p in SECTORS[sec]]
        for p in part:
            if p['kind'] == 'arc':
                heading += p['ang']
        diff = macro_end[sec] - heading
        diff = (diff + 180.0) % 360.0 - 180.0
        if abs(diff) > 0.01:
            r = conn_r[sec]
            c = A('s%d_turn' % sec, diff, r, CONN_SLOPE[sec], sec)
            if sec == 8:
                c['slope'] = 0.0
            part.append(c)
            heading += diff
        pieces += part
        for q in POST.get(sec, []):
            pieces.append(dict(q))
    return pieces

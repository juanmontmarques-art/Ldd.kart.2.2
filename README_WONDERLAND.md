# WONDERLAND — pista extrema vertical (Godot 4.3, GL Compatibility)

Mapa novo `wonderland` (menu → seleção de mapas → "Wonderland"). 13,0 km, circuito fechado contínuo, desnível de ~600 m
(de +400 m no cume até −194 m no fundo do inferno, e subida de volta). Tudo procedural; nenhum arquivo de textura/modelo externo.
Os outros mapas, personagens e a física do kart continuam intactos (regressão: os 7 outros mapas sobem e rodam corrida completa em simulação).

## Os 8 setores
| # | Setor | Amostras (2,5 m) | O que é |
|---|-------|------------------|---------|
| 1 | THE EDGE | 0–782 | plataforma no topo, pontes suspensas, mar de nuvens, atalho secreto (ramal) |
| 2 | FREEFALL | 782–1104 | descidas reais de −35…−45°, saltos grandes, faixa de gelo |
| 3 | THE ABYSS | 1104–1664 | pontes estreitas sobre abismo, vãos, pilares/monólitos, rampa móvel (cristal), plataformas que desabam, obstáculos que surgem |
| 4 | UNDERWORLD | 1664–2263 | cavernas reais, lagos, cachoeiras, estalactites, bioluminescência, géiseres; relevo da montanha **por cima** |
| 5 | CRYSTAL LABYRINTH | 2263–2727 | túneis estreitos, bifurcações (ramal de risco), passagem secreta, trilhos inclinados, cristais emissivos |
| 6 | THE INFERNO | 2727–3314 | lava (visual + perigo), pontes que desabam, queda de pedras, géiseres, plataformas móveis, ramal sobre a lava |
| 7 | GRAVITY BREAK | 3314–4066 | parafuso (corkscrew), pista invertida, zonas de gravidade magnética, trecho de baixa gravidade, trilho a ~58° |
| 8 | THE ASCENT | 4066–5197 | túneis ascendentes, espirais, 2 elevadores, saltos finais, chegada panorâmica |

## Os 14 mecanismos (todos determinísticos por relógio de corrida, com colisão real)
1. **Plataformas que desabam** (S3 1357–1390, S6 2913–2977): tremem ≥0,9 s; só caem depois que ninguém está sobre elas (ou após 2,6 s parado); reerguem sozinhas.
2. **Pontes móveis / plataformas deslizantes** (1562, 3006): período 8–9 s, abertas 60–62 %.
3. **Portões** (7 pares/trios; períodos 6–7 s): descem/sobem; anti-esmagamento (não fecham sobre quem está embaixo).
4. **Pedras rolantes** (4 + 1 no fim): vêm no sentido dos pilotos, a cada 9–11 s.
5. **Queda de pedras do teto** (11): sombra/aviso e queda periódica.
6. **Géiseres lançadores** (6): lançam o kart (potência 17–18).
7. **Elevadores** (S8, 2×; sobem 45 m em 11 s) + mini-elevador (S6): carregam o piloto, com barreira.
8. **Cristais que acionam mecanismos** (4): rampa móvel, portão de boost, porta secreta, ponte da lava (ativam ao passar perto).
9. **Rampas móveis** (tilt ramp, 1228).
10. **Atalhos secretos** (3 ramais: s1_secret, s5_risk, s6_lava) — a IA e o HUD reconhecem o ramal.
11. **Áreas de boost** (5 faixas com chevrons).
12. **Superfícies escorregadias** (5 trechos; `grip_mod` 0,3).
13. **Obstáculos que aparecem na corrida** (4 "emerge").
14. **Passagens que fecham temporariamente** (portões + porta secreta).
Zonas extras: baixa gravidade (3820–3877, `grav_mod` 0,45) e gravidade magnética (parafuso/inversão), via API do kart.

## Física / recuperação
- Usa o sistema de kart existente (`grip_mod`, `grav_mod`, `external_boost`, `spin`, `immunity`); `kart.gd` ganhou gravidade magnética (`set_mag_mode`, `mag_up`, `mag_target`) que segue a normal da pista mesmo no ar.
- Fora da pista / queda / lava → volta ao **último checkpoint** (por piloto); a câmera tem anticolisão e modo magnético.
- Câmera cinematográfica de abertura (~28 s, pula com qualquer toque/tecla) e a câmera normal de corrida continua funcionando.

## Organização
`wonderland/` — `wonderland_main.gd` (+ alias `wonderland_builder.gd`), `wonderland_track.gd`, `wonderland_terrain.gd`, `wonderland_caves.gd`, `wonderland_environment.gd`, `wonderland_props.gd`, `wonderland_hazards.gd`, `wonderland_mechanics.gd`, `wonderland_checkpoints.gd`, `wonderland_cinematic.gd`, `wonderland_materials.gd`, `wonderland_layout.gd` (gerado), `data/terrain.bin` (relevo baked).
Cenas: `wonderland/scenes/Wonderland_{Main,Track,Terrain,Mountains,Caves,Environment,Props,Hazards,Mechanics,Checkpoints,Finish}.tscn` (Main carrega o mundo; as demais são nós-âncora que localizam o grupo de nós criado proceduralmente).
Ferramentas: `tools/wonderland_*.py` (gerador do traçado e do relevo; rode `wonderland_terrain.py` se alterar o traçado).

## Validação feita
Simulação headless de corrida com 5 pilotos de IA, vários trechos e voltas parciais, corrigindo travamentos (bancos, bifurcações, junções de ramal, portões, desabamentos, parafuso, câmara do setor 7). Todas as 11 cenas carregam sem erro.

## Limitações honestas
- Testado em headless/software-GL (sem GPU real): **desempenho em celular não foi medido**. Mitigações: dois LODs de terreno, faixas de visibilidade, luzes com fade por distância, MultiMesh nas decorações.
- A IA completa o circuito, mas no Inferno (S6) e no parafuso (S7) ainda cai ocasionalmente (géiseres/lava/parafuso) e volta ao checkpoint — jogadores humanos devem achar esses trechos exigentes, de propósito.
- Os efeitos de Forward+ (SDFGI, volumétrico) são desligados no GL Compatibility; brilho/névoa são usados no lugar.
- Visual conferido por capturas em software renderer; vale um olhar humano no hardware real.

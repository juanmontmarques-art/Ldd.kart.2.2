# Kart Livre 3D — Circuito Aventura v6

Projeto Godot 4.3+ (GL Compatibility). Todo o cenário é gerado por código ao iniciar
(leva alguns segundos; aparece "Carregando circuito...").

## O que mudou
- **Pista de ~2 km** (curva suave por 26 pontos de controle): reta de largada, curvas largas,
  grampo, S, passagem pelo infield, desfiladeiro de arenito, descida pelo lado oeste.
  Zebras vermelho/branco, faixas, barreiras nas curvas externas, placas de curva.
- **Relevo de verdade**: morros, montanhas nas bordas (com neve), lago, subidas/descidas.
  O terreno acompanha a altura da pista.
- **Física**: o kart é uma esfera rígida que rola no terreno (gravidade, inclinação, saltos).
  Árvores, rochas, barreiras, pórtico e arquibancada têm colisão — não atravessa mais.
  Fora da pista o kart perde velocidade (grama).
- **Rampas** (2), **pads de nitro** (6), **nitro com tanque** (segure o botão).
- **Corrida**: contagem 3-2-1, 3 voltas, tempo por volta, minimapa, aviso de sentido errado,
  volta automática à pista se sair do mapa, botão/tecla R para reposicionar.
- **Joystick novo**: flutuante (aparece onde você toca na metade esquerda), move para todas as
  direções, direção analógica com curva suave. Para cima também acelera, para baixo freia/ré.
- **Botões redondos** grandes: ACELERAR, FREIO, NITRO (+ botão de reiniciar posição).
  Deslizar o dedo entre botões troca a ação. Multitoque.
- Mouse vira toque (project.godot), então dá para testar no editor.

## Teclado
W/↑ acelera · S/↓ freio/ré · A/D ou ←/→ direção · Shift/Espaço nitro · R reposiciona

## Ajustes rápidos
- Velocidade/aderência/direção: variáveis `@export` em `kart.gd`.
- Traçado: lista `control_points` em `track_data.gd` (x, altura, z).
- Densidade de árvores: `placed >= 900` em `world_builder.gd`.

## Aviso
Este código foi escrito sem poder executar o Godot no ambiente de desenvolvimento.
Se aparecer algum erro no Output ao rodar, me envie a mensagem que eu corrijo.


## Novidades da v5
- **4 adversários com IA** (cores diferentes): seguem a pista, freiam em curvas, usam nitro nas retas e usam itens.
  Ritmo "elástico": quem fica muito para trás acelera um pouco, quem dispara folga. Colidem entre si e com você.
- **Posição na corrida** (1º a 5º), minimapa com todos os karts e resultado final.
- **Itens** (caixas "?" na pista): TURBO, BANANA (cai atrás, quem pisa rodopia) e CASCO (teleguiado, mira em quem está à frente).
  Botão **ITEM** na tela (ou tecla E/Q). Quem está atrás recebe itens melhores.
- **Sons gerados por código** (sem arquivos): motor (muda com a velocidade), nitro, pickup, batidas, banana, casco,
  contagem, volta, chegada e **música de fundo**. Botão de som no topo (ou tecla M) silencia tudo.


## Novidades da v6 — Mapa grande
- **Circuito de ~3,8 km** (antes ~2 km), **2 voltas**. Largada na reta sul, subida da montanha em
  zigue-zague (até ~54 m de altura), desfiladeiro, serpentina pelo meio do mapa e descida pelo lado oeste.
  Terreno maior, mais árvores, lago no centro-sul.
- **2 abismos para saltar** (com placas de aviso, boost e rampa de lançamento): o chão do outro lado é
  mais baixo. Se cair, você volta ~100 m antes para pegar embalo. Rampas de salto extras pelo caminho.
- **Obstáculos**: chicanes de barris (com colisão) e **barreiras deslizantes** que cobrem metade da pista
  (passe pelo outro lado!). Os adversários desviam deles.
- Mais pads de nitro e caixas de item espalhadas pela volta.


## Fluxo do jogo (v8)
1. **Vinheta da empresa — Beberibe Studios** (`Intro.tscn`, `intro_company.gd`)
2. **Vinheta do jogo em 3D** (`VinhetaJogo.tscn`, `vinheta_jogo.gd`): seu kart chega derrapando ao pôr do sol, a câmera orbita e o título explode na tela. Usa o kart/piloto salvos.
3. **Menu** (`Menu.tscn`, `menu.gd`): JOGAR, CORRIDA RÁPIDA, GARAGEM, RECORDES, OPÇÕES, SAIR. Kart 3D girando, saldo de moedas.
4. **Garagem** (`Garagem.tscn`, `garagem.gd`): passo 1 piloto → passo 2 kart → CORRER. Itens bloqueados: compre com moedas ou cumpra a conquista.
5. **Corrida** (`Main.tscn`, `main.gd`): usa a seleção, tem moedas na pista, pausa (botão II ou Esc), tela final com prêmio, recordes e desbloqueios.

Toque/tecla pula as vinhetas. Transições com fade em todas as trocas de tela.

## Sistema de salvamento (`save_game.gd`, autoload `SaveGame`)
Arquivo `user://kartlivre_save.json` (+ cópia `.bak`). Guarda moedas, personagens/karts desbloqueados,
seleção atual, recordes por pista (melhor tempo, melhor volta, top 5), estatísticas e opção de som.
- Grava com arquivo temporário + backup; se o principal corromper, usa o backup.
- Salva sozinho ao mudar algo, ao pausar o app (celular) e ao fechar.
- Saves antigos/incompletos são completados com valores padrão.
- Moedas pegas na pista entram no save na hora (nada se perde se sair da corrida).

### Economia (ajuste em `save_game.gd` e `catalog.gd`)
- Prêmio por posição: 1º 120, 2º 80, 3º 55, 4º 35, 5º 20 (x bônus de moedas do piloto).
- Novo recorde de tempo +50, de volta +25 (a partir da 2ª corrida na pista).
- ~100 moedas por volta na pista (reaparecem a cada volta), 1 moeda cada.

## Personagens e karts (`catalog.gd`)
6 pilotos e 6 karts, cada um com multiplicadores (velocidade, aceleração, direção, aderência, nitro, moedas).
Desbloqueio: grátis, comprado com moedas, ou por conquista (vencer N corridas / terminar N corridas).
Para criar um novo, copie uma linha da lista `CHARACTERS` ou `KARTS`. Adversários são sorteados entre os outros pilotos.
O piloto 3D (capacete, viseira, enfeites) é montado por código em `kart_model.gd`; o kart é o GLB pintado na cor escolhida.

## Arquivos novos da v8
`catalog.gd` · `save_game.gd` · `flow.gd` · `ui_kit.gd` · `backdrop.gd` · `coin_badge.gd` · `kart_model.gd` · `kart_preview.gd` ·
`vinheta_jogo.gd` · `menu.gd` · `garagem.gd` · `coin_manager.gd` + cenas `VinhetaJogo.tscn`, `Menu.tscn`, `Garagem.tscn`.
Alterados: `main.gd`, `kart.gd` (nitro configurável), `sfx.gd` (sons de menu/vinheta/moeda), `intro_company.gd`, `project.godot` (autoloads).

## Aviso v8
Escrito sem poder rodar o Godot. Se aparecer erro no Output ao abrir/rodar, me envie a mensagem que eu corrijo.


## v9 — 3 novos mapas temáticos

| Mapa | Extensão | Como liberar | Destaques |
|---|---|---|---|
| Deserto das Pirâmides | ~5 km | 300 moedas | dunas, pirâmides, obeliscos, ruínas, mesas, balões, oásis; saltos sobre buracos nas retas |
| Pico Gelado | ~5,4 km | 600 moedas | chão escorregadio (grip ×0,62), neve caindo, aurora boreal, igloos, pinguins, pontes quebradas e penhascos sem proteção |
| Vulcão | ~5,8 km | 4 vitórias | lava (lagos e cratera), brasas, fumaça, obsidiana, abismos e penhascos |

- **Garagem:** novo passo 3 "PISTA" (prévia do traçado, quedas livres em vermelho/laranja, pads em amarelo). Corrida é o passo 4.
- **Recordes:** cada pista tem seu próprio recorde e top 5 (menu → RECORDES).
- **Opções → LIBERAR TUDO (TESTE):** libera pilotos, karts e pistas para testar.
- **Quedas livres:** buracos (com rampa e pads antes), cadeias de buracos e trechos de penhasco sem proteção; cair devolve o kart ~100 m antes.

### Arquivos novos
`map_theme.gd` (visual/física de cada mapa), `theme_decor.gd` (cenário, árvores e clima), `track_layouts.gd` (traçados gerados), `map_preview.gd` (prévia 2D).
Para regerar os traçados: `python3 tools/emit.py` (pasta `tools/`, saída `track_layouts.gd`).

> Aviso: esta versão foi escrita sem poder executar o Godot. Abra o projeto no Godot 4.3 e veja o painel "Saída/Depurador" na primeira corrida de cada mapa.


## v10 — três mapas técnicos (Lagoa Esmeralda, Cume das Nuvens, Selva das Cachoeiras)

Novos recursos de pista (definidos em `track_layouts_ext.gd`):
- **Túneis** (montanha, cachoeira, caverna): `tunnels` = (início, fim, tipo). Aparecem no HUD ("TÚNEL", "CAVERNA", "CACHOEIRA") com escurecimento, e em roxo no minimapa/prévia.
- **Pontes**: suspensa sobre lago (tipo 0) ou estreita de pedra entre penhascos (tipo 1).
- **Atalhos** (`branches`): curva aberta ligando dois pontos da pista; o progresso é mapeado para a volta, com respawn dentro do atalho.
- **Inclinação lateral** automática nas curvas (`bank_gain`, `bank_max`), desligada perto de saltos, pontes e túneis.
- Distância mínima de 146 m entre trechos não adjacentes (verificada pelo gerador `tools/emit3.py`).
- Cume: a espiral tem 270° (0,75 volta); uma espiral completa sobreposta violaria a regra dos 146 m.

Regerar os traçados: `python3 tools/emit3.py` (usa `tools/specs3.py`).
Desbloqueio: Lagoa 900 moedas, Cume 6 vitórias, Selva 20 corridas.
**Não testado no Godot** (apenas revisão estática).

## LDD KART — intro 3D e menu (novo)
- `LddIntro.tscn` + `ldd_main.gd`: sequência de 15 s (pista vazia → karts derrapando → fumaça → logo 3D → menu). Toque/tecla pula.
- `Menu.tscn` usa o mesmo script com `play_intro = false` (nasce já no menu, ao voltar da garagem).
- `ldd_world.gd`: pista, zebras, barreiras, pórtico, arquibancadas, palmeiras, igrejinha, lagoa (tudo por código).
- `ldd_menu_ui.gd`, `ldd_button.gd`, `ldd_icons.gd`: botões reais do Godot, ícones vetoriais desenhados por código.
- `assets/ldd/logo.png`: logo recortada (fundo cinza removido).
- Fluxo: Intro empresa → LddIntro → Menu. JOGAR/PERSONALIZAÇÃO → garagem (piloto), SELEÇÃO DE KARTS → garagem (kart).

## Karts v2 (procedurais, malha suave)
- `kart_mesh.gd`: gerador de malhas (loft, revolução, tubo, elipsoide) com normais suaves; sem cilindros/esferas prontas.
- `kart_model.gd`: 6 modelos (classico, foguete, besouro, relampago, fantasma, ouro) + piloto + rodas com aros. `KartModel.build(cor, cor_piloto, estilo, id)`.
- `KartShowcase.tscn`: vitrine para ver os 6 karts lado a lado.
- Rivais na corrida usam modelos diferentes do seu.


## v11 — mapas HARDCORE (Lagoa, Cume e Selva refeitos)
Os 3 mapas v10 foram redesenhados (8–9 km, volta única — mude `laps` em `catalog.gd` se quiser mais):
- **Lagoa Esmeralda** 9,0 km: serpentina de 6 hairpins, rampas até 32%, 5 saltos (3 sobre a água), ponte suspensa + ponte estreita, 3 túneis, 3 parafusos e atalho pela caverna (-150 m).
- **Cume das Nuvens** 8,4 km: saltos de 40 m, 4 pontes estreitas entre penhascos, descida em espiral de 270°, 4 túneis, curvas de parede (inclinação até 35°) e 2 parafusos.
- **Selva das Cachoeiras** 8,1 km: S encadeados, 9 saltos entre plataformas, 2 cachoeiras, 3 cavernas, 2 parafusos e atalho de curvas fechadas.

Novo recurso: **parafuso** (`twists` no layout) — a pista rola de -35° a +35° (ou o inverso) ao longo de ~100–250 m.
Inclinação automática das curvas agora chega a 35° (`bank_max` 0,6–0,7).
Regerar: `python3 tools/emit3.py` (specs em `tools/specs3.py`; v10 antigo em `tools/specs3_v10_backup.py`).
**Loop vertical 360° NÃO foi implementado** (exigiria gravidade invertida na física do kart). Não testado no Godot.

### v11.1 — menos "pulos" na pista
- Inclinação lateral suavizada (janela ±12 amostras, desvanecimento 28 amostras) e limitada (`bank_max` 0,5, `bank_gain` 14); parafusos de ±30° com entrada/saída suave (34 amostras).
- Antes, as pontas dos parafusos mudavam a inclinação a 0,028/m (a borda externa da pista subia/descia ~5 m em 25 m e catapultava o kart); agora ≤ 0,011/m (aceleração vertical de pico < 0,35 g a 31 m/s). `tools/bankcheck.py` repete essa análise.
- `kart.gd`: o "grude" no chão em lombas passou de 3,2 para 4,5 m/s (rampas continuam lançando).

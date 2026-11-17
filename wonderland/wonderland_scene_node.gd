extends Node3D

# Nó de cena do Wonderland. Os módulos são montados em tempo de execução por WonderlandMain (procedural);
# cada cena .tscn de wonderland/scenes/ nomeia o grupo de nós que ele cria e permite localizá-lo:
#   Wonderland_Main -> raiz (WonderlandMain)       Wonderland_Track -> pista + atalhos
#   Wonderland_Terrain -> montanha                  Wonderland_Mountains -> relevo/picos/pilares
#   Wonderland_Caves -> cavernas/túneis             Wonderland_Environment -> céu, névoa, luz por setor
#   Wonderland_Props -> pontes, árvores, arcos      Wonderland_Hazards -> lava, quedas, obstáculos
#   Wonderland_Mechanics -> 14 mecanismos           Wonderland_Checkpoints -> arcos e retorno
#   Wonderland_Finish -> arco de chegada
@export var module_name := ""

func world() -> Node:
    var n: Node = self
    while n != null and not (n is WonderlandMain):
        n = n.get_parent()
    return n

func group_root() -> Node:
    var w := world()
    if w == null:
        return null
    return w.get_node_or_null(module_name)

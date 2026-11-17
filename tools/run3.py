import sys; sys.path.insert(0,'/home/claude/tools')
import importlib, gen3, specs3
names = sys.argv[1:] or list(specs3.SPEC3)
res = {}
for n in names:
    res[n] = gen3.build_map3(n, specs3.SPEC3[n]); gen3.report(n, res[n])
gen3.plot(res)

"""Construit SmashArena.rbxlx (place complète) et des .rbxmx à insérer dans une place existante."""
import os
HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = [("SmashConfig", "ModuleScript", "ReplicatedStorage"),
           ("SmashServer", "Script", "ServerScriptService"),
           ("SmashClient", "LocalScript", "StarterPlayerScripts")]

def src(name):
    s = open(os.path.join(HERE, "src", name + ".lua"), encoding="utf-8").read()
    return s.replace("]]>", "]]]]><![CDATA[>")

def item(name, cls, ref):
    return (f'<Item class="{cls}" referent="{ref}"><Properties><string name="Name">{name}</string>'
            f'<ProtectedString name="Source"><![CDATA[{src(name)}]]></ProtectedString></Properties></Item>')

out = os.path.join(HERE, "build"); os.makedirs(out, exist_ok=True)
for i, (n, c, _) in enumerate(SCRIPTS):
    open(os.path.join(out, n + ".rbxmx"), "w", encoding="utf-8").write(f'<roblox version="4">{item(n, c, "RBX%d" % i)}</roblox>')
cfg, srv, cli = [item(n, c, "RBX%d" % i) for i, (n, c, _) in enumerate(SCRIPTS)]
place = ('<roblox version="4">'
  '<Item class="Workspace" referent="W"><Properties><string name="Name">Workspace</string></Properties></Item>'
  f'<Item class="ReplicatedStorage" referent="RS"><Properties><string name="Name">ReplicatedStorage</string></Properties>{cfg}</Item>'
  f'<Item class="ServerScriptService" referent="SSS"><Properties><string name="Name">ServerScriptService</string></Properties>{srv}</Item>'
  '<Item class="StarterPlayer" referent="SP"><Properties><string name="Name">StarterPlayer</string></Properties>'
  f'<Item class="StarterPlayerScripts" referent="SPS"><Properties><string name="Name">StarterPlayerScripts</string></Properties>{cli}</Item></Item>'
  '</roblox>')
open(os.path.join(out, "SmashArena.rbxlx"), "w", encoding="utf-8").write(place)
print("ok ->", out, sorted(os.listdir(out)))

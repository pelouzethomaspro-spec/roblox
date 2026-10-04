import bpy, os, shutil
SRC = '/root/.claude/uploads/c725c065-cb20-5868-b02f-9a238e45d840/8f15f63b-PACK_10_3_1.fbx'
DIR = '/mnt/user-data/outputs/Stockage'
os.makedirs(DIR, exist_ok=True)
OUT = DIR + '/Stockage_Cartons_Rayonnages.fbx'
GARDER = ('carton_grand', 'carton_moyen', 'carton_petit', 'pile_cartons', 'rayonnage_vide', 'rayonnage_plein')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=SRC)
def racine(o):
    while o.parent: o = o.parent
    return o
garde = {o for o in bpy.data.objects if any(racine(o).name.startswith(g) for g in GARDER)}
for o in list(bpy.data.objects):
    if o not in garde: bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.outliner.orphans_purge(do_recursive=True) if hasattr(bpy.ops.outliner, 'orphans_purge') else None
# images utilisees par les objets gardes : ecrites sur disque a cote du FBX
imgs = set()
for o in garde:
    for s in getattr(o, 'material_slots', []):
        if s.material and s.material.node_tree:
            for n in s.material.node_tree.nodes:
                if n.type == 'TEX_IMAGE' and n.image: imgs.add(n.image)
for im in imgs:
    chemin = os.path.join(DIR, os.path.basename(im.filepath) or (im.name + '.png'))
    im.filepath_raw = chemin; im.file_format = 'PNG'; im.save()
    print('texture', chemin, os.path.getsize(chemin))
for o in garde: o.select_set(True)
bpy.ops.export_scene.fbx(filepath=OUT, use_selection=True, path_mode='COPY', embed_textures=True, apply_scale_options='FBX_SCALE_ALL')
print('ecrit', OUT, os.path.getsize(OUT))

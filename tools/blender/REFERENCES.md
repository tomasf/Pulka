# Animal modelling references

These photographs are visual references only. No photograph or texture from
these sources is included in the exported game assets.

## Roe deer (`deer`)

- [Side profile, Naturfotografen-Forum / Andreas Nowack](https://naturfotografen-forum.de/o1309407-Gabelbock-Breitseite)
- [Head detail, Nature Photogallery](https://www.nature-photogallery.eu/cz/foto/2822-srnec-obecny-detail/?puvod=47)

Compare the level back, full rump, slender upright neck, short wedge-shaped
face and large leaf-shaped ears. Antlers are short branched beams rather
than long rods. The pale rump patch belongs on the rear coat and must not
follow the head bone. The game uses a muted brown coat for its winter setting.

## Reindeer (`reindeer`)

- [Caribou photograph, National Geographic Kids](https://kids.nationalgeographic.com/animals/mammals/facts/caribou)
  ([image](https://i.natgeofesb.com/k/6a8fa5a6-d254-4bb0-ad6c-01de03d9954e/caribou-walking-snow_3x2.jpg))

Compare the deep barrel, thick winter neck, broad pale ruff, blunt furry
muzzle and broad split hooves. The beams sweep back before curling up;
forward brow tines distinguish the silhouette from a roe deer. The reference
is a caribou, so its exact body proportions are not a template for every
Scandinavian domestic reindeer.

## Dog (`dog`)

- [Gallivant Joyful Jester, Labrador profile](https://www.gallivantlabradors.com/gallivant-joyful-jester-labrador)

Compare the deep chest, modest abdominal tuck, substantial thigh, broad skull,
blunt muzzle, drop ears, and thick-based tapering tail. Preserve the game's
warm brown coat and red collar. Paws must merge with the wrists instead of
appearing as separate hoof-like disks.

## Mountain hare (`hare`)

- [Winter head and ears, ZooGalaxy](https://zoogalaxy.net/en/photos/mammalia/lagomorpha/lepus-timidus)
- [Body and legs, Forskning.no](https://www.forskning.no/dyreverden-ukas-art-artsdatabanken/ukas-art-hare--med-naeringsrik-mokk/533296)

Compare the arched back, large folded hindquarters, long furry hind feet,
compact head and lateral eyes. Ears are thin pointed leaves with black tips,
not cylinders; their roots must meet the skull. The body reference has a
transitional grey coat; the game keeps the white winter coat shown in the
head reference.

## Verification

`tools/gallery.gd` groups `deer_review`, `reindeer_review`, `dog_review` and
`hare_review` use fixed cameras and framing for before/after comparisons.
Inspect both full-body silhouette and front view, plus walk/idle and each
species' gallop or hop and flail. Shared rig names and clip names remain
compatible with `CreatureRig` and Santa's reindeer attachments.

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

## Red fox (`fox`)

- [Rödräv, Svenska Jägareförbundet](https://jagareforbundet.se/viltarter/daggdjur-hela-listan/rodrav/)
- [Winter full-body photograph](https://jagareforbundet.se/contentassets/aa5718c3f2fb40c396d4d846b60a85e4/10419275-fox-in-the-winter.jpg)
- [Winter head and chest photograph](https://jagareforbundet.se/contentassets/38c75ec244244c00befa41b9cb7a0f57/red-fox-in-white-snow-cold-winter-with-orange-fur-fox-hunting-anima.jpg)

Compare the elongated, level back, narrow pointed muzzle, upright triangular
ears, white cheeks and throat, black lower legs and full low brush with a
pale tip. The coat, legs, ears and tail form one welded surface. Small pads
sit within the paws and the eyes are embedded in the skull. A diagonal trot,
small head movements and a restrained tail sway distinguish it from the dog.
Review `fox_review` and all six phases in `fox_motion` using the native renderer.

## Domestic cat (`cat`)

- [Full-body walking cat, Hoo House Nursery](https://hoohouse.co.uk/about/)
  ([photograph](https://hoohouse.co.uk/img/nursery-21.jpg))
- [Round skull, cheeks and eyes, Battersea](https://www.battersea.org.uk/pet-advice/cat-advice/my-cat-happy)
  ([photograph](https://www.battersea.org.uk/sites/default/files/inline-images/Happy%20and%20relaxed%20grey%20cat.jpg))
- [Relaxed walking posture, Cats Protection](https://www.cats.org.uk/help-and-advice/cat-behaviour/cat-body-language)

Compare the low, level body, short blunt muzzle, full cheeks, almond-shaped
eyes, triangular ears and thin upright tail with a softly hooked tip. The
cat has a four-beat walk rather than the fox's diagonal trot. Coat, paws,
ears and tail are welded; whiskers begin inside the muzzle and the eyes
sit within the skull. Grey, ginger and dark coats share geometry; the white
bib and socks keep their own colour. Review `cat_review` and `cat_motion`.

## Verification

`tools/gallery.gd` groups `deer_review`, `reindeer_review`, `dog_review` and
`hare_review` use fixed cameras and framing for before/after comparisons.
Inspect both full-body silhouette and front view, plus walk/idle and each
species' gallop or hop and flail. Shared rig names and clip names remain
compatible with `CreatureRig` and Santa's reindeer attachments.

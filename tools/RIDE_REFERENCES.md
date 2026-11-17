# Åkdon: fotoreferenser och formjämförelse

Fotografierna granskades visuellt mot renderingar av modellerna från ovan,
sidan och undersidan, samt med spelets riktiga spelarmodell. Bilderna är
referenser för konstruktion och proportioner; de ingår inte som spelresurser.

| Åkdon | Referens | Ändring jämfört med den tidigare modellen |
| --- | --- | --- |
| Pulka | [STIGA Pacer hos XXL](https://www.xxl.se/stiga-pacer-pulka-rod/p/1084459_2_Style) | Längre, avsmalnande plastskrov med högre bakände, tunn vikt kant, upphöjd räfflad sits, bromshandtag, reflexer och draglina. Tidigare kort och djup balja. |
| Stjärtlapp | [STIGA Slider Mix hos SkatePro](https://www.skatepro.se/236-14993.htm) | Tunn skålad, päronformad sits med bakre lober, uppdraget skaft och ett genombrutet grepp. Tidigare fyrkantig kudde med dekorstreck och lös ring. |
| Snowracer | [STIGA Snowracer Classic hos Multitrend](https://www.multitrend.no/stiga-snowracer-classic-rattkjelke-rod-sort/cat-p/c/p10511439) | Öppen böjd rörram, plan räfflad plastsadel, uppböjda formgjutna skidor, gaffel, fästen och fotbroms. Tidigare kapselliknande kåpa, ryggstöd och raka metallklossar till skidor. |
| Tefat | [AlpenGaudi UFO hos Maverino](https://www.maverino.com/prodotto/disco-neve-ufo-alpengaudi/) | Låg plastskål med sammanhängande undersida, bred formad kant och låga handgrepp. Tidigare enkel skålyta med vita mittfält och stående gula ringar. |
| Wok | [Pyrolux kolstålswok, tillverkarens foto](https://pyrolux.com.au/cdn/shop/files/11701_c-Pyrolux.jpg?v=1747872714&width=1000), [tillverkarens kolstålsserie](https://pyrolux.com.au/collections/carbon-steel/) | Tunn stålskål med både in- och utsida, smal vikt kant, nitade handtagsfästen, träskaft med ådring och främre hjälpgrepp. Tidigare tjock ringkant och diskformad färgfläck i botten. |

Modellerna behåller spelets färger och stil. Plast, trä och metall får olika
ytfinish inom samma cachade mesh och en enda opak materialyta per åkdon.
Sittpunkter och köregenskaper behålls.

Granskning:

```sh
godot --path . --script res://tools/gallery.gd -- ride_review /tmp/pulka-vehicles.png 500
godot --path . --script res://tools/gallery.gd -- rider3d /tmp/pulka-riders.png 500
godot --path . --script res://tools/menu_flow_test.gd -- --capture
```

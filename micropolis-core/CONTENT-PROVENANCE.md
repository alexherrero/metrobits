# Where the game's content comes from

Metrobits carries only the cities, pictures, sounds and text the game uses. Each file is listed below with the file it comes from in `micropolis-activity`, Electronic Arts' 2008 open-source release of Micropolis. That release's README puts all of its non-text files under the GNU General Public License, version 3, with Electronic Arts' additional terms (`MicropolisGPLLicenseNotice.md`).

How to read the second column:

- **The same pixels:** the picture is identical to the original.
- **A shade off:** one or two pixels differ by a single step of colour, from converting the file.
- **The same bytes, or a percentage:** a city file that matches the original exactly, or almost exactly.
- **MicropolisCore's own:** a text file MicropolisCore wrote to hold the original game's text.

The table is written by `packaging/trace_content.py`. The original game files that the game reads directly are listed in `olpc/PROVENANCE.md`.

| File | Its original in micropolis-activity | SHA-256 (first 16) |
|---|---|---|
| `content/cities/about.cty` | cities/about.cty, the same bytes | `659e4e3675147a14` |
| `content/cities/badnews.cty` | cities/badnews.cty, the same bytes | `77cbfc846f1b7c94` |
| `content/cities/bluebird.cty` | cities/bluebird.cty, the same bytes | `7da0b406d856c9bb` |
| `content/cities/bruce.cty` | cities/bruce.cty, the same bytes | `bfc4d874b617ede8` |
| `content/cities/deadwood.cty` | cities/deadwood.cty, the same bytes | `dc5f603f4cf97586` |
| `content/cities/finnigan.cty` | cities/finnigan.cty, the same bytes | `932f7da9fcc8b76b` |
| `content/cities/freds.cty` | cities/freds.cty, the same bytes | `e9ebaa967b5eea4d` |
| `content/cities/haight.cty` | cities/haight.cty, the same bytes | `510fcdbd90d1ab86` |
| `content/cities/happisle.cty` | cities/happisle.cty, the same bytes | `84925f4518eccc4f` |
| `content/cities/joffburg.cty` | cities/joffburg.cty, the same bytes | `e810f654295ca3ff` |
| `content/cities/kamakura.cty` | cities/kamakura.cty, the same bytes | `fe6637e5795f2bbd` |
| `content/cities/kobe.cty` | cities/kobe.cty, the same bytes | `157e5acc9f261715` |
| `content/cities/kowloon.cty` | cities/kowloon.cty, the same bytes | `03eabae903f9b2e1` |
| `content/cities/kyoto.cty` | cities/kyoto.cty, the same bytes | `1f1cd1f3251ed7c5` |
| `content/cities/linecity.cty` | cities/linecity.cty, the same bytes | `f81648b1015672d1` |
| `content/cities/med_isle.cty` | cities/med_isle.cty, the same bytes | `37359ca3cd647275` |
| `content/cities/ndulls.cty` | cities/ndulls.cty, the same bytes | `4e3e2f4cf315f14c` |
| `content/cities/neatmap.cty` | cities/neatmap.cty, the same bytes | `970644296503ee3c` |
| `content/cities/radial.cty` | cities/radial.cty, the same bytes | `3ded35f8763d26a6` |
| `content/cities/scenario_bern.cty` | res/snro.444, 99.96% the same bytes | `c0d66e25c6c16fdb` |
| `content/cities/scenario_boston.cty` | res/snro.777, 99.96% the same bytes | `aea17edc47a5892f` |
| `content/cities/scenario_detroit.cty` | res/snro.666, 99.94% the same bytes | `849a287169a727d2` |
| `content/cities/scenario_dullsville.cty` | res/snro.111, 99.92% the same bytes | `b3b85b64f11c35df` |
| `content/cities/scenario_hamburg.cty` | res/snro.333, 99.93% the same bytes | `88bbba917b585e27` |
| `content/cities/scenario_rio_de_janeiro.cty` | res/snro.888, 99.95% the same bytes | `6f32994326f0bf8f` |
| `content/cities/scenario_san_francisco.cty` | res/snro.222, 99.95% the same bytes | `928d2ac8578dab01` |
| `content/cities/scenario_tokyo.cty` | res/snro.555, 99.96% the same bytes | `bc8200782dd90051` |
| `content/cities/senri.cty` | cities/senri.cty, the same bytes | `d21685b5b95e6732` |
| `content/cities/southpac.cty` | cities/southpac.cty, the same bytes | `152375e26e6af0c1` |
| `content/cities/splats.cty` | cities/splats.cty, the same bytes | `4c1ded455b395cd7` |
| `content/cities/wetcity.cty` | cities/wetcity.cty, the same bytes | `0858c04180509d33` |
| `content/cities/yokohama.cty` | cities/yokohama.cty, the same bytes | `a2589b99ecf2a1fb` |
| `content/data/notices.xml` | MicropolisCore's own (GPLv3): the notices' layout, by id; their text is in strings_en-US.xml | `13da8a731679356a` |
| `content/data/stri.202.txt` | res/stri.202, the same lines | `2946c205a678dd9f` |
| `content/data/stri.219.txt` | res/stri.219, the same lines | `e3fb925db4f42326` |
| `content/data/stri.301.txt` | res/stri.301, the same lines | `7fffb4f2c2396dde` |
| `content/data/strings_en-US.xml` | MicropolisCore's own (GPLv3): the OLPC's text strings (res/stri.*) and notices, by id | `26afc6e0ba0c2e6b` |
| `content/images/icairp.png` | images/icairp.xpm, the same pixels | `c8c6d5799213aa54` |
| `content/images/icairphi.png` | images/icairphi.xpm, the same pixels | `d17c5321a6b626dc` |
| `content/images/icchlk.png` | images/icchlk.xpm, the same pixels | `f9400c067cd0d809` |
| `content/images/icchlkhi.png` | images/icchlkhi.xpm, the same pixels | `dcfea2d54e9f09de` |
| `content/images/iccoal.png` | images/iccoal.xpm, the same pixels | `6a55b370a096bdf2` |
| `content/images/iccoalhi.png` | images/iccoalhi.xpm, the same pixels | `09e6b042342e465f` |
| `content/images/iccom.png` | images/iccom.xpm, the same pixels | `12a71d077f0b4a69` |
| `content/images/iccomhi.png` | images/iccomhi.xpm, the same pixels | `068da9fb85a85c94` |
| `content/images/icdozr.png` | images/icdozr.xpm, the same pixels | `851a1bd54b47ce9b` |
| `content/images/icdozrhi.png` | images/icdozrhi.xpm, the same pixels | `6d1abddc1d381f46` |
| `content/images/icersr.png` | images/icersr.xpm, the same pixels | `b787c7394db9ace9` |
| `content/images/icersrhi.png` | images/icersrhi.xpm, the same pixels | `c1a8a55c6a04e5dd` |
| `content/images/icfire.png` | images/icfire.xpm, the same pixels | `36a48dfc8eacb992` |
| `content/images/icfirehi.png` | images/icfirehi.xpm, the same pixels | `13fc5bc9dde83382` |
| `content/images/icind.png` | images/icind.xpm, the same pixels | `6684e70a756f6bb0` |
| `content/images/icindhi.png` | images/icindhi.xpm, the same pixels | `fab3fc4a83a3e023` |
| `content/images/icnuc.png` | images/icnuc.xpm, the same pixels | `175bcc6d2166cd24` |
| `content/images/icnuchi.png` | images/icnuchi.xpm, the same pixels | `9ab526d4306b1844` |
| `content/images/icpark.png` | images/icpark.xpm, the same pixels | `2e770aa6c82b0f9e` |
| `content/images/icparkhi.png` | images/icparkhi.xpm, the same pixels | `a3233ac9c160129b` |
| `content/images/icpol.png` | images/icpol.xpm, the same pixels | `1f2a8d5993e3166d` |
| `content/images/icpolhi.png` | images/icpolhi.xpm, the same pixels | `89aaf60d31727a80` |
| `content/images/icqry.png` | images/icqry.xpm, the same pixels | `5e51e525bf4491a1` |
| `content/images/icqryhi.png` | images/icqryhi.xpm, the same pixels | `957b8420f40f30f5` |
| `content/images/icrail.png` | images/icrail.xpm, the same pixels | `051ce07c0103db42` |
| `content/images/icrailhi.png` | images/icrailhi.xpm, the same pixels | `9ed26e1e930579a5` |
| `content/images/icres.png` | images/icres.xpm, the same pixels | `7243d313a09f192a` |
| `content/images/icreshi.png` | images/icreshi.xpm, the same pixels | `2490dd041bbdd64d` |
| `content/images/icseap.png` | images/icseap.xpm, the same pixels | `22e946f85c5e8f12` |
| `content/images/icseaphi.png` | images/icseaphi.xpm, the same pixels | `49be018100e9af47` |
| `content/images/icstad.png` | images/icstad.xpm, the same pixels | `8a01c9cd59578315` |
| `content/images/icstadhi.png` | images/icstadhi.xpm, the same pixels | `1f60c65ca53acaf8` |
| `content/images/icwire.png` | images/icwire.xpm, the same pixels | `eb8af81c7fcebc5d` |
| `content/images/icwirehi.png` | images/icwirehi.xpm, the same pixels | `fbbf18baef854445` |
| `content/images/sprite_1_0.png` | images/obj1-0.xpm, the same pixels | `a874ad779007ef9e` |
| `content/images/sprite_1_1.png` | images/obj1-1.xpm, the same pixels | `efaa636795a97a48` |
| `content/images/sprite_1_2.png` | images/obj1-2.xpm, the same pixels | `d03ee61d3b0243f3` |
| `content/images/sprite_1_3.png` | images/obj1-3.xpm, the same pixels | `1f043b513db32561` |
| `content/images/sprite_1_4.png` | images/obj1-4.xpm, the same pixels | `d1f2f356e965e5e0` |
| `content/images/sprite_2_0.png` | images/obj2-0.xpm, the same pixels | `243abd994eadd224` |
| `content/images/sprite_2_1.png` | images/obj2-1.xpm, the same pixels | `74ccb202f789e95d` |
| `content/images/sprite_2_2.png` | images/obj2-2.xpm, the same pixels | `25c2e9e2458870b5` |
| `content/images/sprite_2_3.png` | images/obj2-3.xpm, the same pixels | `3b425c14cabff6f4` |
| `content/images/sprite_2_4.png` | images/obj2-4.xpm, the same pixels | `ac0e94c614cb496f` |
| `content/images/sprite_2_5.png` | images/obj2-5.xpm, the same pixels | `061833435a3afcea` |
| `content/images/sprite_2_6.png` | images/obj2-6.xpm, the same pixels | `c7390ad59bad933c` |
| `content/images/sprite_2_7.png` | images/obj2-7.xpm, the same pixels | `7a74027e5527cb2d` |
| `content/images/sprite_3_0.png` | images/obj3-0.xpm, the same pixels | `c398d78faa9295ad` |
| `content/images/sprite_3_1.png` | images/obj3-1.xpm, the same pixels | `46441266368f1fb6` |
| `content/images/sprite_3_10.png` | images/obj3-10.xpm, the same pixels | `922f834ac9e99f51` |
| `content/images/sprite_3_2.png` | images/obj3-2.xpm, the same pixels | `3fd0c076f768cf0b` |
| `content/images/sprite_3_3.png` | images/obj3-3.xpm, the same pixels but 1 a shade off (128 for 127) | `4a81c67f9aaf9c40` |
| `content/images/sprite_3_4.png` | images/obj3-4.xpm, the same pixels | `796fca79ecf3919f` |
| `content/images/sprite_3_5.png` | images/obj3-5.xpm, the same pixels but 1 a shade off (128 for 127) | `b138221f5e0b8d8f` |
| `content/images/sprite_3_6.png` | images/obj3-6.xpm, the same pixels but 1 a shade off (128 for 127) | `13e51b97d8cee2c8` |
| `content/images/sprite_3_7.png` | images/obj3-7.xpm, the same pixels | `ecc94f2def28108f` |
| `content/images/sprite_3_8.png` | images/obj3-8.xpm, the same pixels | `df0fe9b25a533d59` |
| `content/images/sprite_3_9.png` | images/obj3-9.xpm, the same pixels | `10d76c72b2776292` |
| `content/images/sprite_4_0.png` | images/obj4-0.xpm, the same pixels | `1fb1b34a710d9a4e` |
| `content/images/sprite_4_1.png` | images/obj4-1.xpm, the same pixels but 2 a shade off (128 for 127) | `061db6924cf38ffa` |
| `content/images/sprite_4_2.png` | images/obj4-2.xpm, the same pixels but 1 a shade off (128 for 127) | `279956dbbe258509` |
| `content/images/sprite_4_3.png` | images/obj4-3.xpm, the same pixels but 1 a shade off (128 for 127) | `c902af2156b9e968` |
| `content/images/sprite_4_4.png` | images/obj4-4.xpm, the same pixels | `64beb8fddc878e78` |
| `content/images/sprite_4_5.png` | images/obj4-5.xpm, the same pixels but 1 a shade off (128 for 127) | `f329f5e0a9ef3b96` |
| `content/images/sprite_4_6.png` | images/obj4-6.xpm, the same pixels | `50ceed07a5800637` |
| `content/images/sprite_4_7.png` | images/obj4-7.xpm, the same pixels | `4f64cfe45d30da4b` |
| `content/images/sprite_5_0.png` | images/obj5-0.xpm, the same pixels but 2 a shade off (128 for 127) | `67550ce876b6fdce` |
| `content/images/sprite_5_1.png` | images/obj5-1.xpm, the same pixels but 3 a shade off (128 for 127) | `208af390d6b578fb` |
| `content/images/sprite_5_10.png` | images/obj5-10.xpm, the same pixels but 3 a shade off (128 for 127) | `d261928728309068` |
| `content/images/sprite_5_11.png` | images/obj5-11.xpm, the same pixels but 2 a shade off (128 for 127) | `db9699d8a912b129` |
| `content/images/sprite_5_12.png` | images/obj5-12.xpm, the same pixels but 2 a shade off (128 for 127) | `c3330539c9a0a3f3` |
| `content/images/sprite_5_13.png` | images/obj5-13.xpm, the same pixels but 1 a shade off (128 for 127) | `9183dd6d9cfaea1a` |
| `content/images/sprite_5_14.png` | images/obj5-14.xpm, the same pixels | `d07f1316882818f0` |
| `content/images/sprite_5_15.png` | images/obj5-15.xpm, the same pixels but 1 a shade off (128 for 127) | `57ba875f48cafefb` |
| `content/images/sprite_5_2.png` | images/obj5-2.xpm, the same pixels but 2 a shade off (128 for 127) | `f88ffcf1d9579944` |
| `content/images/sprite_5_3.png` | images/obj5-3.xpm, the same pixels | `1e3b61b607841ad9` |
| `content/images/sprite_5_4.png` | images/obj5-4.xpm, the same pixels but 2 a shade off (128 for 127) | `2f8cc40710d434dc` |
| `content/images/sprite_5_5.png` | images/obj5-5.xpm, the same pixels | `114b6ab2bf714ba1` |
| `content/images/sprite_5_6.png` | images/obj5-6.xpm, the same pixels | `2577f8e74a1c6d2f` |
| `content/images/sprite_5_7.png` | images/obj5-7.xpm, the same pixels | `710122cbc78e8284` |
| `content/images/sprite_5_8.png` | images/obj5-8.xpm, the same pixels but 1 a shade off (128 for 127) | `70852d1a75f7b8f7` |
| `content/images/sprite_5_9.png` | images/obj5-9.xpm, the same pixels but 1 a shade off (128 for 127) | `6569b1ba8ac3702b` |
| `content/images/sprite_6_0.png` | images/obj6-0.xpm, the same pixels but 1 a shade off (128 for 127) | `80af7090d3264c1f` |
| `content/images/sprite_6_1.png` | images/obj6-1.xpm, the same pixels but 2 a shade off (128 for 127) | `70745e21731da414` |
| `content/images/sprite_6_2.png` | images/obj6-2.xpm, the same pixels | `937f42dfe3b360ca` |
| `content/images/sprite_7_0.png` | images/obj7-0.xpm, the same pixels | `df756bacb0b218c2` |
| `content/images/sprite_7_1.png` | images/obj7-1.xpm, the same pixels | `a68a9710f06af769` |
| `content/images/sprite_7_2.png` | images/obj7-2.xpm, the same pixels but 1 a shade off (128 for 127) | `026ed6a30d81ffdf` |
| `content/images/sprite_7_3.png` | images/obj7-3.xpm, the same pixels | `51f850653edb3aa4` |
| `content/images/sprite_7_4.png` | images/obj7-4.xpm, the same pixels | `76ca52b778abdd3b` |
| `content/images/sprite_7_5.png` | images/obj7-5.xpm, the same pixels | `2dbb3e5d4c90379e` |
| `content/images/sprite_8_0.png` | images/obj8-0.xpm, the same pixels | `17cf63e2450adfa7` |
| `content/images/sprite_8_1.png` | images/obj8-1.xpm, the same pixels but 1 a shade off (128 for 127) | `3c115fd52536ffc4` |
| `content/images/sprite_8_2.png` | images/obj8-2.xpm, the same pixels | `6244605ee6765c20` |
| `content/images/sprite_8_3.png` | images/obj8-3.xpm, the same pixels | `fc02895cacd6aec4` |
| `content/images/tiles.png` | images/tiles.xpm, the same pixels | `e80506a7fa5d5cb8` |
| `content/sounds/ExplosionLow.mp3` | res/sounds/explosion-low.wav, 5.14 s (the MP3 5.22 s) | `3a73979dbe00fefb` |
| `content/sounds/HeavyTraffic.mp3` | res/sounds/heavytraffic.wav, 2.08 s (the MP3 2.17 s) | `5699e4142da85fcf` |
| `content/sounds/HonkHonkHigh.mp3` | res/sounds/honkhonk-high.wav, 0.66 s (the MP3 0.76 s) | `237e7efd7146f558` |
| `content/sounds/HonkHonkLow.mp3` | res/sounds/honkhonk-low.wav, 0.95 s (the MP3 1.04 s) | `a8acc65d8cde7f23` |
| `content/sounds/HonkHonkMed.mp3` | res/sounds/honkhonk-med.wav, 0.80 s (the MP3 0.89 s) | `fbc75ff01cfa836b` |
| `content/sounds/Monster.mp3` | res/sounds/monster.wav, 0.74 s (the MP3 0.84 s) | `e77c1f81b989605f` |
| `content/sounds/Siren.mp3` | res/sounds/siren.wav, 2.34 s (the MP3 2.43 s) | `40534fbc939241ec` |
| `content/sounds/Sorry.mp3` | res/sounds/sorry.wav, 0.38 s (the MP3 0.47 s) | `457dac373ab33129` |
| `content/sounds/UhUh.mp3` | res/sounds/uhuh.wav, 0.37 s (the MP3 0.47 s) | `a049576d10bf77f5` |
| `content/sounds/a.mp3` | res/sounds/a.wav, 0.10 s (the MP3 0.16 s) | `14d8889ec24552aa` |
| `content/sounds/aaah.mp3` | res/sounds/aaah.wav, 1.19 s (the MP3 1.25 s) | `d9b30b04fe0515a5` |
| `content/sounds/airport.mp3` | res/sounds/airport.wav, 0.38 s (the MP3 0.44 s) | `7cda404757413c9d` |
| `content/sounds/boing.mp3` | res/sounds/boing.wav, 0.43 s (the MP3 0.50 s) | `71f027e483af3b71` |
| `content/sounds/build.mp3` | res/sounds/build.wav, 0.42 s (the MP3 0.50 s) | `74dbea3e37e1e596` |
| `content/sounds/bulldozer.mp3` | res/sounds/bulldozer.wav, 0.39 s (the MP3 0.44 s) | `99d19d8f1dd85879` |
| `content/sounds/chalk.mp3` | res/sounds/chalk.wav, 0.36 s (the MP3 0.42 s) | `2720e3a4ccb8f740` |
| `content/sounds/coal.mp3` | res/sounds/coal.wav, 0.81 s (the MP3 0.89 s) | `74a64735a88d084a` |
| `content/sounds/computer.mp3` | res/sounds/computer.wav, 2.71 s (the MP3 2.77 s) | `2325e9296ac7aa38` |
| `content/sounds/e.mp3` | res/sounds/e.wav, 0.09 s (the MP3 0.16 s) | `88c3fe476735e06c` |
| `content/sounds/eraser.mp3` | res/sounds/eraser.wav, 0.60 s (the MP3 0.68 s) | `9d0d0e297d1e58a5` |
| `content/sounds/fire.mp3` | res/sounds/fire.wav, 0.67 s (the MP3 0.73 s) | `e0968e2ab8fb29f5` |
| `content/sounds/ind.mp3` | res/sounds/ind.wav, 0.49 s (the MP3 0.55 s) | `df286c04ea7cc8d7` |
| `content/sounds/o.mp3` | res/sounds/o.wav, 0.10 s (the MP3 0.16 s) | `4929f5886ab6db74` |
| `content/sounds/oop.mp3` | res/sounds/oop.wav, 0.11 s (the MP3 0.18 s) | `2a1efca9932439b7` |
| `content/sounds/park.mp3` | res/sounds/park.wav, 0.40 s (the MP3 0.47 s) | `7ea3d22f41a418d8` |
| `content/sounds/police.mp3` | res/sounds/police.wav, 0.83 s (the MP3 0.89 s) | `7ae0c1d7c917a728` |
| `content/sounds/query.mp3` | res/sounds/query.wav, 0.37 s (the MP3 0.44 s) | `4e01f0a8f43905ab` |
| `content/sounds/rail.mp3` | res/sounds/rail.wav, 0.32 s (the MP3 0.39 s) | `495c7852484988cf` |
| `content/sounds/res.mp3` | res/sounds/res.wav, 0.51 s (the MP3 0.57 s) | `782edb8b88a6ef01` |
| `content/sounds/road.mp3` | res/sounds/road.wav, 0.29 s (the MP3 0.37 s) | `f27de1a6633f0ab7` |
| `content/sounds/rumble.mp3` | res/sounds/rumble.wav, 0.27 s (the MP3 0.34 s) | `69e88ba9305ea694` |
| `content/sounds/seaport.mp3` | res/sounds/seaport.wav, 0.51 s (the MP3 0.57 s) | `06d3e7b7b4ef2125` |
| `content/sounds/skid.mp3` | res/sounds/skid.wav, 0.70 s (the MP3 0.76 s) | `e0ac0938d006edf1` |
| `content/sounds/stadium.mp3` | res/sounds/stadium.wav, 0.65 s (the MP3 0.73 s) | `057a50b00c316777` |
| `content/sounds/wire.mp3` | res/sounds/wire.wav, 0.37 s (the MP3 0.44 s) | `7cdeed5b77b1414c` |
| `content/sounds/woosh.mp3` | res/sounds/woosh.wav, 0.21 s (the MP3 0.26 s) | `5b1080ac2669dab2` |
| `content/sounds/zone.mp3` | res/sounds/zone.wav, 0.44 s (the MP3 0.50 s) | `9b45f89954c2a98a` |

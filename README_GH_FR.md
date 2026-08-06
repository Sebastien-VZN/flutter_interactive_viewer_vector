# interactive_viewer_vector — Référence technique

> Ceci est la référence technique complète pour GitHub. Pour la version adaptée à pub.dev, voir [README_FR.md](README_FR.md).
>
> English version: [README_GH.md](README_GH.md)

Un remplaçant direct du `InteractiveViewer` de Flutter qui supprime les reconstructions de widgets pendant le déplacement et le zoom — zéro `setState`, zéro reconstruction, juste le paint.

- **pub.dev :** https://pub.dev/packages/interactive_viewer_vector
- **Dépôt :** https://github.com/Sebastien-VZN/flutter_interactive_viewer_vector

## Le problème

Lorsque vous déplacez ou zoomez un `InteractiveViewer` standard, Flutter reconstruit **l'intégralité du sous-arbre de widgets à chaque frame** du geste. Chaque `CustomPaint`, chaque `RepaintBoundary`, chaque enfant — tout est reconstruit et re-layouté des dizaines de fois par seconde. Sur une toile lourde (une carte mentale avec des centaines de nœuds, un éditeur complexe, un dashboard peint) cette tempête de reconstructions se manifeste par des **saccades visibles et des pertes de frames sur mobile**.

C'est une limitation connue et ancienne du framework Flutter ([#78543](https://github.com/flutter/flutter/issues/78543), [#72066](https://github.com/flutter/flutter/issues/72066), [#118434](https://github.com/flutter/flutter/issues/118434), [#129150](https://github.com/flutter/flutter/issues/129150), [#60550](https://github.com/flutter/flutter/issues/60550)). Le `InteractiveViewer` du SDK s'abonne à son `TransformationController` (un `ValueNotifier<Matrix4>`) et appelle `setState` à chaque changement de transformation. Pendant un déplacement ou un zoom à deux doigts, l'intégralité du sous-arbre est reconstruite à chaque frame. Ce n'est pas corrigé en amont car la correction est architecturale — le widget devrait être restructuré pour éviter `setState`.

## La correction

Un seul changement de méthode : `_handleTransformation` n'appelle plus `setState`. Il écrit la matrice directement dans le `RenderTransform` via une `GlobalKey`, déclenchant uniquement `markNeedsPaint()`. L'arbre de widgets reste intact pendant les interactions.

```
InteractiveViewer standard :   changement matrice -> setState -> build() tout le sous-arbre -> layout/paint
InteractiveViewerVector :       changement matrice -> RenderTransform.transform = m -> markNeedsPaint seulement
```

L'API, le comportement des gestes et les paramètres du constructeur sont inchangés.

## Captures d'écran

| Android | Bureau |
|---|---|
| ![Démo Android](doc/screen_android.jpg) | ![Démo Bureau](doc/screen_desktop.jpg) |

## Résultat en conditions réelles

Validé sur un Oppo Find X2 avec une carte mentale complexe : 60fps stables pendant le déplacement et le zoom, au niveau de Mindmeister. La mitigation LOD (Level of Detail) qui était utilisée pour masquer les saccades a été supprimée après que ce fork l'ait rendue inutile.

## Nettoyage de code mort : support de rotation inachevé

Le SDK standard contient un support de geste de rotation inachevé : un `_rotateEnabled = false` hardcodé, une méthode `_matrixRotate`, un clamping de boundary tenant compte de la rotation, une valeur d'enum `_GestureType.rotate`, et deux TODOs référençant [flutter/flutter#57698](https://github.com/flutter/flutter/issues/57698) (ouvert depuis 2020). C'était conçu pour des cas d'usage de cartes géographiques. Ça n'a jamais été terminé en amont et c'est hors sujet pour les cas d'usage de ce package (cartes mentales, toiles, visionneuses d'images). Tout ce code mort a été retiré du fork pour simplifier la codebase.

## Utilisation

Remplacez `InteractiveViewer` par `InteractiveViewerVector` et `TransformationController` par `TransformationControllerVector` — mêmes paramètres, mêmes callbacks :

```dart
final _controller = TransformationControllerVector();

InteractiveViewerVector(
  transformationController: _controller,
  constrained: false,
  boundaryMargin: const EdgeInsets.all(2000),
  minScale: 0.1,
  maxScale: 3,
  onInteractionEnd: (details) { /* ... */ },
  child: MyHugeCanvas(),
)
```

Les transformations programmatiques fonctionnent comme d'habitude :

```dart
_controller.value = Matrix4.identity();
```

Toutes les variantes du constructeur sont supportées : `InteractiveViewerVector(...)`, `InteractiveViewerVector.builder(...)`, `panEnabled`, `scaleEnabled`, `panAxis`, `trackpadScrollCausesScale`, `scaleFactor`, `alignment`, `clipBehavior`, etc.

## Tests

Les tests widget vérifient qu'un enfant avec un compteur de builds est construit **exactement une fois** sur 10 mises à jour de transformation consécutives (déplacement et zoom). Avec le widget standard, chaque mise à jour déclenche une reconstruction. Ce test est la preuve que le fork fonctionne.

```bash
flutter test                              # tests unit + widget
cd example && flutter test integration_test  # intégration (appareil requis)
```

L'app `example/` affiche un compteur live "canvas builds" dans sa barre d'app : il reste plat pendant que vous déplacez/zoomez.

### Tests de performance sur appareil réel

Les tests automatisés prouvent la garantie zéro-reconstruction (le compteur de builds reste à zéro), mais ils ne mesurent pas le timing réel des frames. Pour mesurer les performances réelles :

**Toujours tester sur un appareil physique en mode profile — jamais sur un émulateur.**

```bash
cd example
flutter run --profile -d <device-id>
```

Pourquoi c'est important :

- **Les émulateurs mentent.** Les émulateurs Android (x64) tournent sans vrais pilotes GPU et avec un overhead d'interop sur chaque appel natif — les événements pointeur arrivent à des cadences irréalistes, les appels `Stopwatch` dominent le profil CPU (jusqu'à 58% du temps échantillonné), et les budgets de frame n'ont aucun sens. Vous verrez des saccades fantômes qui n'existent pas sur du vrai matériel.
- **Le mode debug masque le problème.** Avec DevTools attaché, la pression GC des cycles constants `setState`/reconstruction du `InteractiveViewer` standard _masque_ les saccades en coalesçant les reconstructions. Le mode profile retire ce filet de sécurité — compilation AOT, pas de hooks debug, vrais patterns d'allocation — et le coût réel de la reconstruction du sous-arbre à chaque frame devient visible.
- **Le mode profile + appareil physique** est la seule combinaison qui donne des temps de frame réels : vraies fréquences d'échantillonnage tactile, vrais débits de remplissage GPU, vraies contraintes thermiques.

Protocole :

1. Connecter un appareil physique : `flutter devices`
2. Lancer en mode profile : `flutter run --profile -d <device-id>`
3. Ouvrir Flutter DevTools → onglet Performance
4. Enregistrer 3-5 secondes de déplacement/zoom continu
5. Vérifier : temps de frame p50/p95, % de frames > 16,6 ms (budget 60fps), FPS pendant le drag

Résultat attendu — le thread UI reste silencieux (pas de `build()`, pas de `scheduleBuildFor`), et seul le thread raster repeint le contenu transformé :

![DevTools Performance — 60fps stables](doc/bench_profile_performance.jpg)

## Plateformes

Natif uniquement — le rendu CanvasKit/HTML sur le web a ses propres caractéristiques de performance et annule le bénéfice.

| Plateforme | Statut |
|---|---|
| Android | Validé manuellement |
| Linux | Validé manuellement |
| Windows | Validé manuellement |
| iOS | Compilé par CI, pas de tests runtime |
| macOS | Compilé par CI, pas de tests runtime |

Testé personnellement sur **Android, Linux et Windows** — c'est le matériel dont je dispose. iOS et macOS compilent proprement à chaque run CI mais je n'ai pas d'appareils pour les tester en runtime. Si vous les utilisez, une ligne "ça marche chez moi" dans une [GitHub Issue](https://github.com/Sebastien-VZN/flutter_interactive_viewer_vector/issues) aiderait à consolider la matrice de support.

## Maintenance & contribution

Je ne suis pas un mainteneur à temps plein. J'ai construit ce fork pour mon propre projet ([Axomind](https://github.com/Sebastien-VZN)), où il pilote une carte mentale lourde, et je le publie au cas où ça serait utile à d'autres travaillant sur des toiles interactives similaires.

Ce que ça signifie en pratique :

- **Rapports de bugs** — bienvenus. Ouvrez une [GitHub Issue](https://github.com/Sebastien-VZN/flutter_interactive_viewer_vector/issues) avec un repro et je regarderai. Les bugs qui cassent le comportement core déplacement/zoom ou régressent la garantie zéro-reconstruction sont la priorité.
- **Demandes de fonctionnalités** — je les considérerai seulement quand elles sont pertinentes pour mon propre cas d'usage : cartes mentales, toiles, et contenu interactif de ce type. Si une fonctionnalité demandée correspond à ce périmètre, je suis heureux d'en discuter.
- **Fonctionnalités hors périmètre** — si vous avez besoin d'un comportement visant un autre type d'app (cartes géographiques, visionneuses de documents, modes de geste exotiques, etc.), le chemin le plus propre est de forker le projet. La codebase est petite et le changement comportemental unique du fork est isolé, donc l'adapter à vos besoins devrait être direct.

C'est un fix ciblé que j'utilise en production, partagé publiquement. Des attentes claires des deux côtés gardent ça durable.

## Origine & licence

Forké du SDK Flutter (`packages/flutter/lib/src/widgets/interactive_viewer.dart`, 1300+ lignes) avec un seul changement comportemental dans `_handleTransformation`. Licence BSD 3-Clause, notice de copyright des The Flutter Authors préservée dans [LICENSE](LICENSE).

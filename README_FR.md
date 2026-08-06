# interactive_viewer_vector

Un fork du SDK Flutter `InteractiveViewer` qui met à jour le `RenderTransform` directement (`markNeedsPaint`) au lieu d'appeler `setState` à chaque frame de pan/zoom — zéro rebuild du widget tree pendant les interactions.

- **pub.dev :** https://pub.dev/packages/interactive_viewer_vector
- **Dépôt :** https://github.com/Sebastien-VZN/flutter_interactive_viewer_vector

## Le problème

Quand vous pansez ou zoomez un `InteractiveViewer` standard, Flutter rebuild **tout le sous-arbre de widgets à chaque frame** du geste. Chaque `CustomPaint`, chaque `RepaintBoundary`, chaque widget enfant — tout est reconstruit et re-layouté, des dizaines de fois par seconde, tant que votre doigt est sur l'écran.

Sur un petit widget c'est invisible. Sur un canvas lourd — un mindmap avec des centaines de nodes, un éditeur avec un arbre de couches complexe, un dashboard plein d'éléments peints — cette tempête de rebuilds se manifeste par du **jank visible et des frames dropped sur mobile**. L'interaction est laggy, et plus le canvas est gros, plus ça empire.

### Pourquoi ça arrive (technique)

Le `InteractiveViewer` du SDK s'abonne à son `TransformationController` (un `ValueNotifier<Matrix4>`) et appelle `setState(() {})` à chaque changement de transformation. Pendant un pan ou un zoom à deux doigts, ça rebuild tout le sous-arbre à chaque frame — tous les `CustomPaint`, tous les enfants `RepaintBoundary`, et tout le reste du sous-arbre.

C'est une limitation connue et ancienne du framework Flutter (issues [#78543](https://github.com/flutter/flutter/issues/78543), [#72066](https://github.com/flutter/flutter/issues/72066), [#118434](https://github.com/flutter/flutter/issues/118434), [#129150](https://github.com/flutter/flutter/issues/129150), [#60550](https://github.com/flutter/flutter/issues/60550)). Ça n'a jamais été corrigé upstream parce que le fix est architectural — le widget devrait être restructuré pour éviter `setState`.

## Le fix

Le fork remplace uniquement la méthode `_handleTransformation`. Au lieu d'appeler `setState`, il pousse la nouvelle matrice directement au `RenderTransform` via une `GlobalKey`. Ça déclenche `markNeedsPaint()` seulement — le widget tree n'est jamais reconstruit pendant une interaction.

```
InteractiveViewer standard :   changement matrice -> setState -> build() tout le sous-arbre -> layout/paint
InteractiveViewerVector :       changement matrice -> RenderTransform.transform = m -> markNeedsPaint seulement
```

L'API, le comportement des gestures et les paramètres du constructeur sont inchangés.

## Résultat réel

Validé sur un Oppo Find X2 avec un canvas mindmap complexe : 60fps stable pendant le pan et le zoom, au niveau de Mindmeister. Le mitigation LOD (Level of Detail) qui était utilisée pour cacher le jank a été supprimée après que ce fork l'ait rendue inutile.

## Suppression du code de rotation

Le SDK standard contient un support de gesture de rotation inachevé : un `_rotateEnabled = false` hardcodé, une méthode `_matrixRotate`, un clamping de boundary tenant compte de la rotation, une valeur d'enum `_GestureType.rotate`, et deux TODOs référençant [flutter/flutter#57698](https://github.com/flutter/flutter/issues/57698) (ouvert depuis 2020). C'était conçu pour des cas d'usage de cartes géographiques. Ça n'a jamais été terminé upstream et c'est irrelevant pour les cas d'usage de ce package (mindmaps, canvas, visionneuses d'images). Tout ce code mort a été retiré du fork pour simplifier la codebase.

## Plateformes

Natif uniquement — le rendu CanvasKit/HTML sur le web a ses propres caractéristiques de performance et annule le bénéfice.

| Plateforme | Statut de test |
| --- | --- |
| Android | Validé manuellement |
| Linux | Validé manuellement |
| Windows | Validé manuellement |
| iOS | Légèrement remanié & recompilé par la CI |
| macOS | Légèrement remanié & recompilé par la CI |

Je ne teste moi-même que sur **Android, Linux et Windows** — c'est le matos que j'ai sous la main. iOS et macOS sont maintenus fonctionnels au mieux : leurs configs de build ont été légèrement remaniées, ils compilent proprement à chaque run CI, mais je n'ai pas de hardware physique pour faire des smoke tests runtime. Ils passent la gate, je ne peux juste pas certificer personnellement le ressenti des gestures.

Si vous ciblez iOS ou macOS, un test rapide de votre côté suivi d'une [GitHub Issue](https://github.com/Sebastien-VZN/flutter_interactive_viewer_vector/issues) — même une seule ligne « ça marche chez moi » — aiderait à consolider la matrice de support. Contributions bienvenues.

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

Les transformations programmatiques (ex. bouton reset) fonctionnent comme d'habitude :

```dart
_controller.value = Matrix4.identity();
```

Toutes les variantes du constructeur sont supportées : `InteractiveViewerVector(...)`, `InteractiveViewerVector.builder(...)`, `panEnabled`, `scaleEnabled`, `panAxis`, `trackpadScrollCausesScale`, `scaleFactor`, `alignment`, `clipBehavior`, etc.

## Tests

Les tests widget du package assertent qu'un widget enfant avec un compteur de builds est construit **exactement une fois** sur 10 updates de transformation consécutives (pan et scale). Avec le widget standard, chaque update déclenche un build. Ce test est la preuve que le fork fonctionne.

```bash
flutter test                              # tests unit + widget
cd example && flutter test integration_test  # intégration (device requis)
```

L'app `example/` affiche un compteur live "canvas builds" dans son app bar : il reste plat pendant que vous pansez/zoomez.

### Tests de performance sur appareil réel

Les tests automatisés prouvent la garantie zéro-rebuild (le compteur de builds reste à zéro), mais ils ne mesurent pas le timing réel des frames. Pour mesurer les performances réelles :

**Toujours tester sur un appareil physique en mode profile — jamais sur un émulateur.**

```bash
cd example
flutter run --profile -d <device-id>
```

Pourquoi c'est important :

- **Les émulateurs Android** (x64) tournent sans vrais pilotes GPU et avec un overhead d'interop sur chaque appel natif — les événements pointeur arrivent à des cadences irréalistes, les appels `Stopwatch` dominent le profil CPU (jusqu'à 58% du temps échantillonné), et les budgets de frame n'ont aucun sens. Vous verrez du jank fantôme qui n'existe pas sur du vrai matériel.
- **Le mode debug** a un problème différent : avec DevTools attaché, la pression GC des cycles constants `setState`/rebuild du `InteractiveViewer` standard _masque_ le jank en coalesçant les rebuilds. L'ancien chemin `setState` paraît acceptable en debug parce que la planification de build du framework absorbe le churn. Le mode profile retire ce filet de sécurité — compilation AOT, pas de hooks debug, vrais patterns d'allocation — et le coût réel du rebuild du sous-arbre à chaque frame devient visible. C'est appuyé par des tests de perf mesurés : le même geste qui paraît fluide en debug montre des frames dropped en profile.
- **Le mode profile** tourne avec une compilation proche de la release (AOT, pas d'overhead debug) tout en gardant DevTools attaché. C'est le seul mode qui donne des temps de frame réels.
- **Les appareils physiques** ont de vraies fréquences d'échantillonnage tactile, de vrais débits de remplissage GPU, et de vraies contraintes thermiques — ce que vous mesurez est ce que les utilisateurs vivent.

Protocole :

1. Connecter un appareil physique : `flutter devices`
2. Lancer en mode profile : `flutter run --profile -d <device-id>`
3. Ouvrir Flutter DevTools → onglet Performance
4. Enregistrer 3-5 secondes de pan/zoom continu
5. Vérifier : temps de frame p50/p95, % de frames > 16,6 ms (budget 60fps), FPS pendant le drag

La valeur du fork est visible ici : pendant le pan/zoom, le thread UI reste silencieux (pas de `build()`, pas de `scheduleBuildFor`), et seul le thread raster repeint le contenu transformé.

## Maintenance & contribution

Je ne suis pas un mainteneur à temps plein. J'ai construit ce fork pour mon propre projet ([Axomind](https://github.com/Sebastien-VZN)), où il pilote un canvas mindmap lourd, et je le publie au cas où ça serait utile à d'autres travaillant sur des canvas interactifs similaires.

Ce que ça signifie en pratique :

- **Bug reports** — bienvenus. Ouvrez une [GitHub Issue](https://github.com/Sebastien-VZN/flutter_interactive_viewer_vector/issues) avec un repro et je regarderai. Les bugs qui cassent le comportement core pan/zoom ou régressent la garantie no-rebuild sont la priorité.
- **Feature requests** — je les considérerai seulement quand elles sont pertinentes pour mon propre cas d'usage : mindmaps, canvas, et contenu interactif de ce type. Si une feature demandée correspond à ce périmètre, je suis heureux d'en discuter.
- **Features hors périmètre** — si vous avez besoin d'un comportement visant un autre type d'app (cartes géographiques, visionneuses de documents, modes de gesture exotiques, etc.), le chemin le plus propre est de forker le projet. La codebase est petite et le changement comportemental unique du fork est isolé, donc l'adapter à vos besoins devrait être direct.

Ce n'est pas un produit open-source poli avec une roadmap et une équipe derrière — c'est un fix ciblé que j'utilise en production, partagé publiquement. Des attentes claires des deux côtés gardent ça durable.

## Origine & licence

Forké du SDK Flutter (`packages/flutter/lib/src/widgets/interactive_viewer.dart`, 1300+ lignes) avec un seul changement comportemental dans `_handleTransformation`. Licence BSD 3-Clause, notice de copyright des The Flutter Authors préservée dans [LICENSE](LICENSE).
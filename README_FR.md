# interactive_viewer_vector

Un remplaçant direct du `InteractiveViewer` de Flutter qui supprime les reconstructions de widgets pendant le déplacement et le zoom — zéro `setState`, zéro reconstruction, juste le paint.

- **pub.dev :** https://pub.dev/packages/interactive_viewer_vector
- **Dépôt :** https://github.com/Sebastien-VZN/flutter_interactive_viewer_vector

## Le problème

Lorsque vous déplacez ou zoomez un `InteractiveViewer` standard, Flutter reconstruit **l'intégralité du sous-arbre de widgets à chaque frame** du geste. Chaque `CustomPaint`, chaque `RepaintBoundary`, chaque enfant — tout est reconstruit et re-layouté des dizaines de fois par seconde. Sur une toile lourde (une carte mentale avec des centaines de nœuds, un éditeur complexe, un dashboard peint) cette tempête de reconstructions se manifeste par des **saccades visibles et des pertes de frames sur mobile**.

C'est une limitation connue et ancienne du framework Flutter ([#78543](https://github.com/flutter/flutter/issues/78543), [#72066](https://github.com/flutter/flutter/issues/72066), [#118434](https://github.com/flutter/flutter/issues/118434), [#129150](https://github.com/flutter/flutter/issues/129150), [#60550](https://github.com/flutter/flutter/issues/60550)). Le `InteractiveViewer` du SDK s'abonne à son `TransformationController` et appelle `setState` à chaque changement de transformation. Ce n'est pas corrigé en amont car la correction est architecturale.

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
| ![Démo Android](https://raw.githubusercontent.com/Sebastien-VZN/flutter_interactive_viewer_vector/main/doc/screen_android.jpg) | ![Démo Bureau](https://raw.githubusercontent.com/Sebastien-VZN/flutter_interactive_viewer_vector/main/doc/screen_desktop.jpg) |

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

Les tests widget vérifient qu'un enfant avec un compteur de builds est construit **exactement une fois** sur 10 mises à jour de transformation consécutives. Avec le widget standard, chaque mise à jour déclenche une reconstruction.

```bash
flutter test                              # tests unit + widget
cd example && flutter test integration_test  # intégration (appareil requis)
```

Pour le protocole de test de performance sur appareil réel (profilage DevTools, timing des frames), voir [README_GH_FR.md](README_GH_FR.md).

## Plateformes

Natif uniquement — le rendu CanvasKit/HTML sur le web a ses propres caractéristiques de performance et annule le bénéfice.

| Plateforme | Statut |
|---|---|
| Android | Validé manuellement |
| Linux | Validé manuellement |
| Windows | Validé manuellement |
| iOS | Compilé par CI, pas de tests runtime |
| macOS | Compilé par CI, pas de tests runtime |

## Origine & licence

Forké du SDK Flutter (`packages/flutter/lib/src/widgets/interactive_viewer.dart`, 1300+ lignes) avec un seul changement comportemental dans `_handleTransformation`. Licence BSD 3-Clause, notice de copyright des The Flutter Authors préservée dans [LICENSE](LICENSE).

---

Pour les notes techniques détaillées, les guidelines de contribution et le protocole de test de performance, voir [README_GH_FR.md](README_GH_FR.md).

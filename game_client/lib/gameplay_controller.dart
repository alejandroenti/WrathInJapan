abstract class GameplayController {
  void handleInput();

  void fixedUpdate(double dtSeconds);

  String? animationOverrideForSprite(int spriteIndex);

  bool hasCameraTarget();

  double getCameraTargetX();

  double getCameraTargetY();
}

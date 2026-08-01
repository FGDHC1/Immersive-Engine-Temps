module ImmersiveEngineTemps

public class EngineTempSystem extends ScriptableSystem {
  private let hud: ref<EngineHUD>;

  private func EnsureHUD() -> Bool {
    if IsDefined(this.hud) { return true; }

    let inkSys = GameInstance.GetInkSystem();
    if !IsDefined(inkSys) { return false; }

    let layer = inkSys.GetLayer(n"inkHUDLayer");
    if !IsDefined(layer) { return false; }

    this.hud = EngineHUD.Create(layer.GetVirtualWindow());
    LogChannel(n"DEBUG", "[ImmersiveEngineTemps] HUD created");
    return true;
  }

  public func PushValues(rpm: Int32, coolant: Float, oil: Float) -> Void {
    if !this.EnsureHUD() { return; }
    this.hud.SetHUDVisible(true);
    this.hud.UpdateValues(rpm, coolant, oil);
  }

  public func HideHUD() -> Void {
    if IsDefined(this.hud) {
      this.hud.SetHUDVisible(false);
    }
  }
}

public class EngineHUD extends IScriptable {
  private let root: wref<inkCanvas>;
  private let rpmText: wref<inkText>;
  private let coolantText: wref<inkText>;
  private let oilText: wref<inkText>;
  private let dial: wref<inkCanvas>;
  private let needle: wref<inkImage>;
  private let coolSegs: array<wref<inkImage>>;
  private let oilSegs: array<wref<inkImage>>;

  public func SetHUDVisible(visible: Bool) -> Void {
    if IsDefined(this.root) {
      this.root.SetVisible(visible);
    }
  }

  private func Polar(r: Float, deg: Float) -> Vector2 {
    let rad: Float = deg * 0.0174533;
    return Vector2(r * CosF(rad), -r * SinF(rad));
  }

  private func ColorForTemp(temp: Float) -> HDRColor {
    if temp >= 115.0 { return HDRColor(1.0, 0.15, 0.1, 1.0); }
    if temp >= 100.0 { return HDRColor(1.0, 0.75, 0.1, 1.0); }
    return HDRColor(0.3, 0.9, 0.95, 1.0);
  }

  private func UpdateArc(segs: array<wref<inkImage>>, temp: Float) -> Void {
    let frac: Float = (temp - 20.0) / 100.0;
    if frac < 0.0 { frac = 0.0; }
    if frac > 1.0 { frac = 1.0; }

    let lit: Int32 = Cast<Int32>(frac * Cast<Float>(ArraySize(segs)));
    let col: HDRColor = this.ColorForTemp(temp);

    let i: Int32 = 0;
    while i < ArraySize(segs) {
      segs[i].SetTintColor(col);
      if i < lit { segs[i].SetOpacity(1.0); } else { segs[i].SetOpacity(0.18); }
      i += 1;
    }
  }

  public static func Create(vwin: ref<inkCompoundWidget>) -> ref<EngineHUD> {
    let self = new EngineHUD();

    let root: ref<inkCanvas> = new inkCanvas();
    root.Reparent(vwin, -1);
    root.SetAnchor(inkEAnchor.BottomLeft);
    root.SetAnchorPoint(Vector2(0.0, 1.0));
    root.SetMargin(inkMargin(40.0, 0.0, 0.0, 190.0));
    root.SetSize(Vector2(600.0, 400.0));
    root.SetVisible(true);
    root.SetOpacity(1.0);
    self.root = root;

    let dial: ref<inkCanvas> = new inkCanvas();
    dial.SetName(n"dial");
    dial.SetSize(Vector2(400.0, 400.0));
    dial.SetAnchor(inkEAnchor.Centered);
    dial.SetAnchorPoint(Vector2(0.5, 0.5));
    dial.SetRenderTransformPivot(Vector2(0.5, 0.5));
    dial.SetScale(Vector2(0.6, 0.6));
    dial.Reparent(root);
    self.dial = dial;

    let face = new inkImage();
    face.SetName(n"gaugeFace");
    face.SetAtlasResource(r"immersiveenginetemps\\immersive_engine_temps_icons.inkatlas");
    face.SetTexturePart(n"ziffernblatt");
    face.SetSize(Vector2(400.0, 400.0));
    face.SetAnchor(inkEAnchor.Centered);
    face.SetAnchorPoint(Vector2(0.5, 0.5));
    face.Reparent(dial);

    let segCount: Int32 = 16;
    let segRadius: Float = 235.0;

    let i: Int32 = 0;
    while i < segCount {
      let t: Float = Cast<Float>(i) / Cast<Float>(segCount - 1);
      let arcOffset: Float = 55.0;
      let angC: Float = 270.0 - arcOffset - t * 70.0;
      let segC = new inkImage();
      segC.SetAtlasResource(r"immersiveenginetemps\\immersive_engine_temps_icons.inkatlas");
      segC.SetTexturePart(n"zacke");
      segC.SetSize(Vector2(40.0, 12.0));
      segC.SetAnchor(inkEAnchor.Centered);
      segC.SetAnchorPoint(Vector2(0.5, 0.5));
      segC.SetRenderTransformPivot(Vector2(0.5, 0.5));
      segC.SetRotation(-angC);
      segC.SetTranslation(self.Polar(segRadius, angC));
      segC.Reparent(dial);
      ArrayPush(self.coolSegs, segC);

      let angO: Float = -90.0 + arcOffset + t * 70.0;
      let segO = new inkImage();
      segO.SetAtlasResource(r"immersiveenginetemps\\immersive_engine_temps_icons.inkatlas");
      segO.SetTexturePart(n"zacke");
      segO.SetSize(Vector2(40.0, 12.0));
      segO.SetAnchor(inkEAnchor.Centered);
      segO.SetAnchorPoint(Vector2(0.5, 0.5));
      segO.SetRenderTransformPivot(Vector2(0.5, 0.5));
      segO.SetRotation(-angO);
      segO.SetTranslation(self.Polar(segRadius, angO));
      segO.Reparent(dial);
      ArrayPush(self.oilSegs, segO);

      i += 1;
    }

    let needle = new inkImage();
    needle.SetName(n"needle");
    needle.SetAtlasResource(r"immersiveenginetemps\\immersive_engine_temps_icons.inkatlas");
    needle.SetTexturePart(n"zeiger");
    needle.SetSize(Vector2(24.0, 190.0));
    needle.SetAnchor(inkEAnchor.Centered);
    needle.SetAnchorPoint(Vector2(0.5, 0.98));
    needle.SetRenderTransformPivot(Vector2(0.5, 0.98));
    needle.Reparent(dial);
    self.needle = needle;

    let rpmText: ref<inkText> = new inkText();
    rpmText.Reparent(dial, -1);
    rpmText.SetAnchor(inkEAnchor.Centered);
    rpmText.SetAnchorPoint(Vector2(0.5, 0.5));
    rpmText.SetTranslation(Vector2(0.0, 180.0));
    rpmText.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    rpmText.SetFontSize(30);
    rpmText.SetTintColor(HDRColor(0.3, 0.9, 0.95, 1.0));
    rpmText.SetText("RPM: 0");
    rpmText.SetVisible(true);
    rpmText.SetOpacity(1.0);
    self.rpmText = rpmText;

    let coolantText: ref<inkText> = new inkText();
    coolantText.Reparent(dial, -1);
    coolantText.SetAnchor(inkEAnchor.Centered);
    coolantText.SetAnchorPoint(Vector2(0.5, 0.5));
    coolantText.SetTranslation(Vector2(-50.0, 90.0));
    coolantText.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    coolantText.SetFontSize(26);
    coolantText.SetMargin(inkMargin(0.0, 34.0, 0.0, 0.0));
    coolantText.SetTintColor(HDRColor(0.3, 0.9, 0.95, 1.0));
    coolantText.SetText("Cool: 0°");
    coolantText.SetVisible(true);
    coolantText.SetOpacity(1.0);
    self.coolantText = coolantText;

    let oilText: ref<inkText> = new inkText();
    oilText.Reparent(dial, -1);
    oilText.SetAnchor(inkEAnchor.Centered);
    oilText.SetAnchorPoint(Vector2(0.5, 0.5));
    oilText.SetTranslation(Vector2(50.0, 90.0));
    oilText.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    oilText.SetFontSize(26);
    oilText.SetMargin(inkMargin(0.0, 34.0, 0.0, 0.0));
    oilText.SetTintColor(HDRColor(0.3, 0.9, 0.95, 1.0));
    oilText.SetText("Oil: 0°");
    oilText.SetVisible(true);
    oilText.SetOpacity(1.0);
    self.oilText = oilText;

    return self;
}

  public func UpdateValues(rpm: Int32, coolant: Float, oil: Float) -> Void {
    this.rpmText.SetText("RPM: " + IntToString(rpm));
    this.coolantText.SetText("Cool: " + FloatToStringPrec(coolant, 0) + "°");
    this.oilText.SetText("Oil: " + FloatToStringPrec(oil, 0) + "°");

    let frac: Float = Cast<Float>(rpm) / 8000.0;
    if frac > 1.0 { frac = 1.0; }
    this.needle.SetRotation(-135.0 + frac * 270.0);

    this.UpdateArc(this.coolSegs, coolant);
    this.UpdateArc(this.oilSegs, oil);
  }
}
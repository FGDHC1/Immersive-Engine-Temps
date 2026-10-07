module ImmersiveEngineTemps

public class EngineTempSystem extends ScriptableSystem {
    private let hud: ref<EngineHUD>;
    private let hud3d: ref<EngineTemp3DPair>;
    private let cfgX: Float = 0.0;
    private let cfgY: Float = 0.0;
    private let cfgScale: Float = 1.0;
    private let cfgOpacity: Float = 1.0;

    private func EnsureHUD() -> Bool {
        if IsDefined(this.hud) {
            return true;
        }

        let inkSys = GameInstance.GetInkSystem();
        if !IsDefined(inkSys) {
            return false;
        }

        let layer = inkSys.GetLayer(n"inkHUDLayer");
        if !IsDefined(layer) {
            return false;
        }

        this.hud = EngineHUD.Create(layer.GetVirtualWindow());
        LogChannel(n"DEBUG", "[ImmersiveEngineTemps] HUD created");
        return true;
    }

    public func PushValues(rpm: Int32, coolant: Float, oil: Float) -> Void {
        if !this.EnsureHUD() {
            return;
        }
        this.hud.SetHUDVisible(true);
        this.hud.UpdateValues(rpm, coolant, oil);
    }

    public func HideHUD() -> Void {
        if IsDefined(this.hud) {
            this.hud.SetHUDVisible(false);
        }
    }

    private let cfgUnitF: Bool = false;

    public func PushConfig(x: Float, y: Float, scale: Float, opacity: Float, unitF: Bool) -> Void {
        this.cfgX = x;
        this.cfgY = y;
        this.cfgScale = scale;
        this.cfgOpacity = opacity;
        this.cfgUnitF = unitF;
        if this.EnsureHUD() {
            this.hud.ApplyConfig(x, y, scale, opacity, unitF);
        }
    }

    private func Ensure3D() -> Void {
        if !IsDefined(this.hud3d) { 
            this.hud3d = new EngineTemp3DPair(); 
        }
    }

    public func Update3D(coolant: Float, oil: Float, coolOn: Bool, oilOn: Bool) -> Void {
        this.Ensure3D();
        this.hud3d.Update(GetPlayer(GetGameInstance()).GetMountedVehicle(), coolant, oil, coolOn, oilOn);
    }


    public func Hide3D() -> Void {
        if IsDefined(this.hud3d) {
            this.hud3d.Release();
        }
    }

    public func Place3D(gauge: Int32, x: Float, y: Float, z: Float, pitch: Float, yaw: Float, roll: Float, scale: Float) -> Void {
        this.Ensure3D();
        this.hud3d.SetPlacement(gauge, x, y, z, pitch, yaw, roll, scale);
    }

    public func TuneNeedle(px: Float, py: Float, start: Float, sweep: Float, len: Float, thick: Float) -> Void {
        this.Ensure3D();
        this.hud3d.TuneNeedle(px, py, start, sweep, len, thick);
    }
}


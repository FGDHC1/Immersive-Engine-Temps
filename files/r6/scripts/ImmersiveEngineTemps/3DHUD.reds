module ImmersiveEngineTemps

public class EngineTemp3DHud extends IScriptable {
    private let hostID: EntityID;
    private let carID: EntityID;
    private let bound: Bool;
    private let x: Float;
    private let y: Float;
    private let z: Float;
    private let pitch: Float;
    private let yaw: Float;
    private let roll: Float;
    private let scale: Float = 0.1;
    private let placementDirty: Bool;
    
    public func Update(car: wref<VehicleObject>) -> Void {
        if !IsDefined(car) { return; }
        if EntityID.IsDefined(this.hostID) && !Equals(car.GetEntityID(), this.carID) {
            this.Release();
        }
        if !EntityID.IsDefined(this.hostID) {
            this.Spawn(car);
            return;
        }
        if !this.bound {
            this.TryBind(car);
        }
        if this.bound {
            this.ApplyPlacement();
        }
    }

    public func SetPlacement(x: Float, y: Float, z: Float, pitch: Float, yaw: Float, roll: Float, scale: Float) -> Void {
        this.x = x;
        this.y = y;
        this.z = z;
        this.pitch = pitch;
        this.yaw = yaw;
        this.roll = roll;
        this.scale = scale;
        this.placementDirty = true;
    }

    private func Spawn(car: wref<VehicleObject>) -> Void {
        let depot = GameInstance.GetResourceDepot();
        if !depot.ResourceExists(r"immersiveenginetemps\\hud3d\\host.ent") {
            LogChannel(n"DEBUG", "[ImmersiveEngineTemps] host.ent NOT FOUND");
            return;
        }
        let spec = new StaticEntitySpec();

        spec.templatePath = r"immersiveenginetemps\\hud3d\\host.ent";
        spec.position = car.GetWorldPosition();
        spec.orientation = car.GetWorldOrientation();
        spec.attached = true;

        this.hostID = GameInstance.GetStaticEntitySystem().SpawnEntity(spec);
        this.carID = car.GetEntityID();
        this.bound = false;
        this.placementDirty = true;

        if EntityID.IsDefined(this.hostID) {
            LogChannel(n"DEBUG", "[ImmersiveEngineTemps] 3D host spawned");
        } else {
            LogChannel(n"DEBUG", "[ImmersiveEngineTemps] SpawnEntity returned empty ID");
        }
    }

    private func TryBind(car: wref<VehicleObject>) -> Void {
        let host = GameInstance.FindEntityByID(GetGameInstance(), this.hostID);
        if !IsDefined(host) || !host.IsAttached() { return; }
        
        let chassis = car.FindComponentByType(n"vehicleChassisComponent") as IPlacedComponent;
        if !IsDefined(chassis) { return; }

        EntityGameInterface.BindToComponent(host.GetEntity(), car.GetEntity(), chassis.name, n"", true);
        this.bound = true;
        LogChannel(n"DEBUG", "[ImmersiveEngineTemps] 3D host bound to chassis");
    }

    private func ApplyPlacement() -> Void {
        let host = GameInstance.FindEntityByID(GetGameInstance(), this.hostID);
        if !IsDefined(host) { return; }
        let plate = host.FindComponentByName(n"iet_plate") as MeshComponent;
        if !IsDefined(plate) { return; }
        let rot: EulerAngles;
        rot.Pitch = this.pitch;
        rot.Yaw = this.yaw;
        rot.Roll = this.roll;

        plate.SetLocalTransform(Vector4(this.x, this.y, this.z, 1.0), EulerAngles.ToQuat(rot));
        plate.visualScale = Vector3(this.scale, this.scale, this.scale);
        this.placementDirty = false;
    }

    public func Release() -> Void {
        if EntityID.IsDefined(this.hostID) {
            GameInstance.GetStaticEntitySystem().DespawnEntity(this.hostID);
            LogChannel(n"DEBUG", "[ImmersiveEngineTemps] 3D host released");
        }
        let empty: EntityID;
        this.hostID = empty;
        this.carID = empty;
        this.bound = false;
    }
}

public class EngineTemp3DService extends ScriptableService {
    private cb func OnLoad() {
        GameInstance.GetCallbackSystem()
            .RegisterCallback(n"Entity/Assemble", this, n"OnHostAssemble", true)
            .AddTarget(EntityTarget.Template(r"immersiveenginetemps\\hud3d\\host.ent"));
    }
    private cb func OnHostAssemble(event: ref<EntityLifecycleEvent>) {
        let host = event.GetEntity();

        let plate = new MeshComponent();
        plate.name = n"iet_plate";
        plate.mesh *= r"ep1\\environment\\architecture\\watson\\kabuki\\wat_kab_building_f_window_w300_aa_window_plane.mesh";
        plate.meshAppearance = n"default";
        plate.visualScale = Vector3(0.1, 0.1, 0.1);
        plate.castShadows = shadowsShadowCastingMode.Never;

        host.AddComponent(plate);
        LogChannel(n"DEBUG", "[ImmersiveEngineTemps] 3D plate added");
    }
}
module ImmersiveEngineTemps

public class IETScreenComponent extends worlduiWidgetComponent {}

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
    private let gaugeStage: Int32;
    
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
            this.TryBuildGauge();
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
        this.gauge = null;
        this.gaugeStage = 0;
    }

    private let gauge: wref<inkImage>;

    private func TryBuildGauge() -> Void {
        if IsDefined(this.gauge) { return; }
        
        let host = GameInstance.FindEntityByID(GetGameInstance(), this.hostID);
        if !IsDefined(host) { return; }

        let screen = host.FindComponentByName(n"iet_screen") as worlduiWidgetComponent;
        if !IsDefined(screen) { this.Stage(1, "no screen component"); return; }

        let ctrl = screen.GetGameController();
        if !IsDefined(ctrl) { this.Stage(2, "no game controller"); return; }

        let root = ctrl.GetRootCompoundWidget();
        if !IsDefined(root) { this.Stage(3, "no root widget"); return; }

        root.RemoveAllChildren();

        root.SetVisible(true);
        root.SetOpacity(1.0);

        let img = new inkImage();
        img.SetAtlasResource(r"immersiveenginetemps\\immersive_engine_temps_icons.inkatlas");
        img.SetTexturePart(n"ziffernblatt");
        img.SetAnchor(inkEAnchor.Fill);
        img.SetTintColor(HDRColor(0.3, 2.0, 2.4, 1.0));
        img.Reparent(root);

        this.gauge = img;
        LogChannel(n"DEBUG", "[ImmersiveEngineTemps] Gauge Created");
    }
    private func Stage(stage: Int32, msg: String) -> Void {
        if this.gaugeStage != stage {
            this.gaugeStage = stage;
            LogChannel(n"DEBUG", "[ImmersiveEngineTemps] gauge stage " + IntToString(stage) + ": " + msg);

        }
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
        plate.mesh *= r"immersiveenginetemps\\hud3d\\iet_plate.mesh";
        plate.meshAppearance = n"default";
        plate.visualScale = Vector3(0.1, 0.1, 0.1);
        plate.castShadows = shadowsShadowCastingMode.Never;
        plate.renderingPlane = ERenderingPlane.RPl_Scene;
        plate.objectTypeID = ERenderObjectType.ROT_Vehicle;

        host.AddComponent(plate);

        let screen = new IETScreenComponent();
        screen.name = n"iet_screen";
        
        screen.widgetResource *= r"base\\gameplay\\vehicles\\visual_customization\\vvc_car_appearance_widget.inkwidget";
        screen.meshTargetBinding = new worlduiMeshTargetBinding();
        screen.meshTargetBinding.bindName = n"iet_plate";

        screen.limitedSpawnDistanceFromVehicle = false;
        screen.sceneWidgetProperties.isAlwaysVisible = true;
        screen.sceneWidgetProperties.renderingPlane = ERenderingPlane.RPl_Scene;
        screen.sceneWidgetProperties.projectionPlaneSize.X = 1.0;
        screen.sceneWidgetProperties.projectionPlaneSize.Y = 1.0;
        
        host.AddComponent(screen);

        LogChannel(n"DEBUG", "[ImmersiveEngineTemps] 3D plate added");
    }
}
package AGVSystem {
    import ISQ::*;
    
    value type Length :> Real { unit 'm'; }
    value type Speed :> Real { unit 'm/s'; }
    value type Mass :> Real { unit 'kg'; }
    value type BatteryLevel :> Real { unit '%'; min 0; max 100; }
    value type Power :> Real { unit 'W'; }
    
    item def Payload {
        attribute weight : Mass;
    }
    
    item def MissionCommand {
        attribute pickupLocation : String;
        attribute deliveryLocation : String;
    }
    
    item def PositionData {
        attribute x : Length;
        attribute y : Length;
        attribute orientation : Real;
    }
    
    item def ObstacleData {
        attribute distance : Length;
        attribute isObstructed : Boolean;
    }
    
    item def DriveCommand {
        attribute leftWheelSpeed : Speed;
        attribute rightWheelSpeed : Speed;
    }
    
    item def LoadingCommand {
        attribute action : String;
    }
    
    port def CommandPort {
        out mission : MissionCommand;
    }
    
    port def TelemetryPort {
        in position : PositionData;
        in battery : BatteryLevel;
    }
    
    port def PowerPort {
        out power : Power;
    }
    
    port def SensorDataPort {
        out data : ObstacleData;
    }
    
    port def DriveCommandPort {
        out cmd : DriveCommand;
    }
    
    port def LoadingCommandPort {
        out cmd : LoadingCommand;
    }
    
    port def PositionPort {
        out pos : PositionData;
    }
    
    port def BatteryLevelPort {
        out level : BatteryLevel;
    }
    
    part def Wheel {
        port driveIn : DriveCommandPort;
        attribute speed : Speed;
    }
    
    part def DifferentialDrive {
        part leftWheel : Wheel;
        part rightWheel : Wheel;
        port driveIn : DriveCommandPort;
        flow driveIn.cmd to leftWheel.driveIn.cmd;
        flow driveIn.cmd to rightWheel.driveIn.cmd;
    }
    
    part def LoadingMechanism {
        port cmdIn : LoadingCommandPort;
        attribute payload : Payload;
    }
    
    part def BatteryPack {
        port powerOut : PowerPort;
        port levelOut : BatteryLevelPort;
        port chargeIn : PowerPort;
        attribute level : BatteryLevel;
    }
    
    part def ObstacleSensor {
        port dataOut : SensorDataPort;
    }
    
    part def PositioningSensor {
        port posOut : PositionPort;
    }
    
    part def SafetySystem {
        port obstacleIn : SensorDataPort;
        port emergencyStopOut : CommandPort;
    }
    
    part def VehicleController {
        port cmdIn : CommandPort;
        port telemetryOut : TelemetryPort;
        port obstacleIn : SensorDataPort;
        port posIn : PositionPort;
        port driveCmdOut : DriveCommandPort;
        port loadingCmdOut : LoadingCommandPort;
        port batteryIn : BatteryLevelPort;
        
        attribute currentMission : MissionCommand;
    }
    
    part def AGV {
        port cmdIn : CommandPort;
        port telemetryOut : TelemetryPort;
        port chargePort : PowerPort;
        
        attribute missionReceived : Boolean;
        attribute arrivedAtPickup : Boolean;
        attribute payloadLoaded : Boolean;
        attribute arrivedAtDelivery : Boolean;
        attribute payloadUnloaded : Boolean;
        attribute arrivedAtCharger : Boolean;
        attribute batteryLow : Boolean;
        attribute batteryFull : Boolean;
        
        part controller : VehicleController;
        part drive : DifferentialDrive;
        part loader : LoadingMechanism;
        part battery : BatteryPack;
        part obstacleSensor : ObstacleSensor;
        part positioningSensor : PositioningSensor;
        part safetySystem : SafetySystem;
        
        connection def CmdConn : CommandPort ~> CommandPort;
        connection def TelemetryConn : TelemetryPort ~> TelemetryPort;
        connection def DriveConn : DriveCommandPort ~> DriveCommandPort;
        connection def LoadingConn : LoadingCommandPort ~> LoadingCommandPort;
        connection def ObstacleConn : SensorDataPort ~> SensorDataPort;
        connection def PosConn : PositionPort ~> PositionPort;
        connection def BatteryConn : BatteryLevelPort ~> BatteryLevelPort;
        connection def PowerConn : PowerPort ~> PowerPort;
        
        connection cmdIn to controller.cmdIn;
        connection controller.telemetryOut to telemetryOut;
        
        connection controller.driveCmdOut to drive.driveIn;
        connection controller.loadingCmdOut to loader.cmdIn;
        
        connection obstacleSensor.dataOut to controller.obstacleIn;
        connection positioningSensor.posOut to controller.posIn;
        connection battery.levelOut to controller.batteryIn;
        
        connection chargePort to battery.chargeIn;
        
        state def AGVBehavior {
            entry;
            state idle;
            state navigatingToPickup;
            state loadingPayload;
            state navigatingToDelivery;
            state unloadingPayload;
            state navigatingToCharger;
            state charging;
            
            transition idle to navigatingToPickup when missionReceived;
            transition navigatingToPickup to loadingPayload when arrivedAtPickup;
            transition loadingPayload to navigatingToDelivery when payloadLoaded;
            transition navigatingToDelivery to unloadingPayload when arrivedAtDelivery;
            transition unloadingPayload to idle when payloadUnloaded;
            transition idle to navigatingToCharger when batteryLow;
            transition navigatingToCharger to charging when arrivedAtCharger;
            transition charging to idle when batteryFull;
        }
    }
    
    part def FleetController {
        port cmdOut : CommandPort;
        port telemetryIn : TelemetryPort;
        attribute missionQueue : MissionCommand[0..*];
    }
    
    part def ChargingStation {
        port powerOut : PowerPort;
    }
    
    part def LoadingDock {
        attribute location : String;
    }
    
    part def UnloadingDock {
        attribute location : String;
    }
    
    part def AGVSystem {
        part fleetController : FleetController;
        part agvs : AGV[1..*];
        part chargingStations : ChargingStation[1..*];
        part loadingDocks : LoadingDock[1..*];
        part unloadingDocks : UnloadingDock[1..*];
        
        connection fleetController.cmdOut to agvs.cmdIn;
        connection agvs.telemetryOut to fleetController.telemetryIn;
        connection chargingStations.powerOut to agvs.chargePort;
    }
    
    requirement def SafeOperation {
        subject agv : AGV;
        objective {
            doc "The AGV must avoid collisions and trigger emergency stops when obstacles are detected."
        }
    }
    
    requirement def AutonomousTransport {
        subject agv : AGV;
        objective {
            doc "The AGV must autonomously navigate to pickup, load, navigate to delivery, and unload."
        }
    }
    
    requirement def BatteryManagement {
        subject agv : AGV;
        objective {
            doc "The AGV must autonomously navigate to a charging station when battery drops below 20%."
        }
    }
}

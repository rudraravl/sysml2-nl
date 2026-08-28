package AGV_System {
    private import ScalarValues::*;
    private import ISQ::*;

    item def Payload {
        attribute id : String;
        attribute mass : ISQ::MassValue;
    }

    item def Mission {
        attribute id : String;
        ref pickup : LoadingDock;
        ref delivery : UnloadingDock;
        ref payload : Payload;
    }

    attribute def TransportCommand {
        ref mission : Mission;
    }
    attribute def LowBatterySignal;
    attribute def PickupArrivedSignal;
    attribute def PayloadLoadedSignal;
    attribute def DeliveryArrivedSignal;
    attribute def PayloadUnloadedSignal;
    attribute def ArrivedAtChargerSignal;
    attribute def ChargingCompleteSignal;
    attribute def EmergencyStopSignal;
    attribute def ResumeSignal;

    port def CommandPort {
        out attribute command : TransportCommand;
    }
    port def TelemetryPort {
        out attribute positionX : ISQ::LengthValue;
        out attribute positionY : ISQ::LengthValue;
        out attribute heading : Real;
        out attribute batteryLevel : Real;
        out attribute status : String;
    }
    port def ChargePort {
        out attribute power : ISQ::PowerValue;
    }
    port def DriveControlPort {
        out attribute leftSpeed : ISQ::SpeedValue;
        out attribute rightSpeed : ISQ::SpeedValue;
    }
    port def LoaderControlPort {
        out attribute liftCommand : Boolean;
        out attribute clampCommand : Boolean;
        out attribute releaseCommand : Boolean;
    }
    port def ObstacleDataPort {
        out attribute obstacleDistance : ISQ::LengthValue;
    }
    port def PositionDataPort {
        out attribute positionX : ISQ::LengthValue;
        out attribute positionY : ISQ::LengthValue;
        out attribute heading : Real;
    }
    port def BatteryStatusPort {
        out attribute currentLevel : Real;
        out attribute lowWarning : Boolean;
    }
    port def SafetySignalPort {
        out attribute emergencyStop : Boolean;
    }

    action def ProcessCommand {
        in attribute command : TransportCommand;
    }
    action def CalculatePath {
        in targetX : ISQ::LengthValue;
        in targetY : ISQ::LengthValue;
    }
    action def DriveWheels {
        in leftSpeed : ISQ::SpeedValue;
        in rightSpeed : ISQ::SpeedValue;
    }
    action def LiftPayload;
    action def ClampPayload;
    action def ReleasePayload;
    action def LoadPayload {
        first start;
        then action lift : LiftPayload;
        then action clamp : ClampPayload;
        then done;
    }
    action def UnloadPayload {
        first start;
        then action release : ReleasePayload;
        then done;
    }
    action def ScanObstacles {
        out distance : ISQ::LengthValue;
    }
    action def TrackPosition {
        out x : ISQ::LengthValue;
        out y : ISQ::LengthValue;
        out heading : Real;
    }
    action def MonitorSafety {
        in obstacleDistance : ISQ::LengthValue;
        out emergency : Boolean;
    }
    action def DischargeBattery;
    action def ChargeBattery;
    action def DispatchMissions;
    action def MonitorFleet;
    action def ProvideCharge;

    state def AGVStates {
        entry; then idle;

        state idle;
        transition idle_to_navigateToPickup
            first idle
            accept TransportCommand
            then navigateToPickup;
        transition idle_to_navigateToCharging
            first idle
            accept LowBatterySignal
            then navigateToCharging;

        state navigateToPickup;
        transition navigateToPickup_to_loading
            first navigateToPickup
            accept PickupArrivedSignal
            then loading;
        transition navigateToPickup_to_emergencyStop
            first navigateToPickup
            accept EmergencyStopSignal
            then emergencyStop;

        state loading;
        transition loading_to_transporting
            first loading
            accept PayloadLoadedSignal
            then transporting;
        transition loading_to_emergencyStop
            first loading
            accept EmergencyStopSignal
            then emergencyStop;

        state transporting;
        transition transporting_to_unloading
            first transporting
            accept DeliveryArrivedSignal
            then unloading;
        transition transporting_to_navigateToCharging
            first transporting
            accept LowBatterySignal
            then navigateToCharging;
        transition transporting_to_emergencyStop
            first transporting
            accept EmergencyStopSignal
            then emergencyStop;

        state unloading;
        transition unloading_to_idle
            first unloading
            accept PayloadUnloadedSignal
            then idle;
        transition unloading_to_emergencyStop
            first unloading
            accept EmergencyStopSignal
            then emergencyStop;

        state navigateToCharging;
        transition navigateToCharging_to_charging
            first navigateToCharging
            accept ArrivedAtChargerSignal
            then charging;
        transition navigateToCharging_to_emergencyStop
            first navigateToCharging
            accept EmergencyStopSignal
            then emergencyStop;

        state charging;
        transition charging_to_idle
            first charging
            accept ChargingCompleteSignal
            then idle;

        state emergencyStop;
        transition emergencyStop_to_idle
            first emergencyStop
            accept ResumeSignal
            then idle;
    }

    part def Wheel {
        attribute radius : ISQ::LengthValue;
        attribute speed : ISQ::SpeedValue;
        perform action rotate : DriveWheels;
    }

    part def Actuator {
        attribute maxForce : ISQ::ForceValue;
        perform action actuate;
    }

    part def DifferentialDrive {
        port driveCtrlIn : DriveControlPort;
        part leftWheel : Wheel;
        part rightWheel : Wheel;
        perform action drive : DriveWheels;
    }

    part def LoadingMechanism {
        port loaderCtrlIn : LoaderControlPort;
        part liftActuator : Actuator;
        part clampActuator : Actuator;
        perform action loadPayload : LoadPayload;
        perform action unloadPayload : UnloadPayload;
    }

    part def BatteryPack {
        attribute capacity : ISQ::EnergyValue;
        attribute currentLevel : Real;
        attribute lowThreshold : Real = 20;
        port chargePort : ChargePort;
        port statusOut : BatteryStatusPort;
        perform action discharge : DischargeBattery;
        perform action charge : ChargeBattery;
    }

    part def ObstacleSensor {
        port dataOut : ObstacleDataPort;
        perform action scan : ScanObstacles;
    }

    part def PositioningSensor {
        port dataOut : PositionDataPort;
        perform action track : TrackPosition;
    }

    part def SafetySystem {
        port obstacleIn : ObstacleDataPort;
        port interlockOut : SafetySignalPort;
        perform action monitor : MonitorSafety;
    }

    part def VehicleController {
        port cmdIn : CommandPort;
        port telemetryOut : TelemetryPort;
        port driveCtrlOut : DriveControlPort;
        port loaderCtrlOut : LoaderControlPort;
        port obstacleDataIn : ObstacleDataPort;
        port positionDataIn : PositionDataPort;
        port batteryStatusIn : BatteryStatusPort;
        port safetySignalIn : SafetySignalPort;
        perform action processCommands : ProcessCommand;
        perform action calculatePath : CalculatePath;
    }

    part def AGV {
        attribute id : String;
        attribute mass : ISQ::MassValue;
        attribute positionX : ISQ::LengthValue;
        attribute positionY : ISQ::LengthValue;
        attribute heading : Real;

        port fleetCmdPort : CommandPort;
        port fleetTelemetryPort : TelemetryPort;
        port chargePort : ChargePort;

        part controller : VehicleController;
        part drive : DifferentialDrive;
        part loader : LoadingMechanism;
        part battery : BatteryPack;
        part obstacleSensor : ObstacleSensor;
        part positioningSensor : PositioningSensor;
        part safetySystem : SafetySystem;

        exhibit state agvStates : AGVStates;

        connect fleetCmdPort to controller.cmdIn;
        connect controller.telemetryOut to fleetTelemetryPort;
        connect chargePort to battery.chargePort;
        connect controller.driveCtrlOut to drive.driveCtrlIn;
        connect controller.loaderCtrlOut to loader.loaderCtrlIn;
        connect battery.statusOut to controller.batteryStatusIn;
        connect obstacleSensor.dataOut to controller.obstacleDataIn;
        connect positioningSensor.dataOut to controller.positionDataIn;
        connect obstacleSensor.dataOut to safetySystem.obstacleIn;
        connect safetySystem.interlockOut to controller.safetySignalIn;
    }

    part def FleetController {
        attribute missionQueue : Mission[0..*];
        port agvCmdPorts : CommandPort[1..*];
        port agvTelemetryPorts : TelemetryPort[1..*];
        perform action dispatchMissions : DispatchMissions;
        perform action monitorFleet : MonitorFleet;
    }

    part def ChargingStation {
        attribute id : String;
        attribute locationX : ISQ::LengthValue;
        attribute locationY : ISQ::LengthValue;
        port agvChargePort : ChargePort;
        perform action provideCharge : ProvideCharge;
    }

    part def LoadingDock {
        attribute id : String;
        attribute locationX : ISQ::LengthValue;
        attribute locationY : ISQ::LengthValue;
        item payloads : Payload[0..*];
    }

    part def UnloadingDock {
        attribute id : String;
        attribute locationX : ISQ::LengthValue;
        attribute locationY : ISQ::LengthValue;
        item payloads : Payload[0..*];
    }

    part def Facility {
        part fleetController : FleetController;
        part chargingStations : ChargingStation[1..*];
        part loadingDocks : LoadingDock[1..*];
        part unloadingDocks : UnloadingDock[1..*];
        part agvs : AGV[1..*];

        connect fleetController.agvCmdPorts to agvs.fleetCmdPort;
        connect agvs.fleetTelemetryPort to fleetController.agvTelemetryPorts;
        connect chargingStations.agvChargePort to agvs.chargePort;
    }

    part facility : Facility;

    requirement def AGVSystemRequirements {
        subject system : Facility;

        requirement AutonomousTransport {
            subject system;
            doc /* The system shall autonomously transport payloads from loading docks to unloading docks. */
        }
        requirement SafeOperation {
            subject system;
            doc /* The system shall detect obstacles and trigger emergency stops to avoid collisions. */
        }
        requirement ReliableCharging {
            subject system;
            doc /* The system shall autonomously navigate to charging stations when battery level is low. */
        }
        requirement EfficientMaterialHandling {
            subject system;
            doc /* The system shall efficiently, reliably, and safely automate material handling tasks in industrial settings. */
        }
    }
}

package AutonomousVacuumSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    def Percent :> Real { }
    def PowerLevel :> Real { }
    def DistanceValue :> Real { }
    def VelocityValue :> Real { }
    def RotationRate :> Real { }
    def ChargeLevel :> Real { }
    def FillLevel :> Real { }
    def SuctionPower :> Real { }

    // ===== Enums =====
    enum OperatingMode { standby; activeCleaning; returningToBase; dockedCharging; error; }
    enum CleaningMode { normal; intensive; edge; }
    enum FloorType { hardwood; carpet; tile; }
    enum MissionStatus { inProgress; complete; aborted; }
    enum FaultType { none; stuck; wheelJam; brushJam; lowBattery; binFull; criticalFault; }
    enum DockingStatus { notDocked; searchingBeacon; approaching; docked; failed; }

    // ===== Item Types =====
    item def Debris;
    item def Dust :> Debris;
    item def Dirt :> Debris;
    item def PetHair :> Debris;

    item def InfraredSignal;
    item def BeaconSignal :> InfraredSignal;
    item def ObstacleDetectionSignal :> InfraredSignal;

    item def PowerFlow;
    item def ChargingCurrent :> PowerFlow;

    item def NavigationData {
        attribute position : DistanceValue;
        attribute heading : Real;
        attribute mapId : String;
    }

    item def SensorReading {
        attribute detected : Boolean;
        attribute distance : DistanceValue;
    }

    item def DriveCommand {
        attribute leftWheelSpeed : VelocityValue;
        attribute rightWheelSpeed : VelocityValue;
    }

    item def CleaningCommand {
        attribute mainBrushOn : Boolean;
        attribute sideBrushOn : Boolean;
        attribute suctionLevel : SuctionPower;
        attribute mode : CleaningMode;
    }

    item def SystemStatus {
        attribute batteryCharge : ChargeLevel;
        attribute binFill : FillLevel;
        attribute currentMode : OperatingMode;
        attribute currentCleaningMode : CleaningMode;
        attribute missionStatus : MissionStatus;
        attribute fault : FaultType;
    }

    // ===== Port Definitions =====
    port def PowerPort {
        out power : PowerFlow;
    }

    port def ChargingPort {
        in current : ChargingCurrent;
    }

    port def InfraredPort {
        out tx : InfraredSignal;
        in rx : InfraredSignal;
    }

    port def BeaconPort {
        out beacon : BeaconSignal;
    }

    port def DriveControlPort {
        in command : DriveCommand;
    }

    port def CleaningControlPort {
        in command : CleaningCommand;
    }

    port def StatusPort {
        out status : SystemStatus;
    }

    port def SensorDataPort {
        out reading : SensorReading;
    }

    port def NavigationDataPort {
        out navData : NavigationData;
    }

    port def DockingPort {
        out dockStatus : DockingStatus;
    }

    // ===== Requirements =====
    requirement def CleaningMissionRequirement {
        doc << "The robot vacuum shall autonomously navigate and clean designated floor areas.">>
        attribute coverageArea : DistanceValue;
        subject robot : RobotVacuum;
        require { robot.missionStatus == MissionStatus::complete }
    }

    requirement def AutoReturnRequirement {
        doc << "The robot shall return to its charging station when battery is low, bin is full, or mission is complete.">>
        subject robot : RobotVacuum;
        require {
            (robot.battery.chargeLevel < 20.0 or
             robot.dustContainer.fillLevel > 95.0 or
             robot.missionStatus == MissionStatus::complete)
            implies robot.operatingMode == OperatingMode::returningToBase
        }
    }

    requirement def DockingRequirement {
        doc << "The robot shall autonomously dock with the charging station using the infrared beacon.">>
        subject robot : RobotVacuum;
        subject station : ChargingStation;
        require { robot.dockingStatus == DockingStatus::docked }
    }

    requirement def SafetyRequirement {
        doc << "The robot shall avoid falling down stairs using cliff sensors and avoid collisions using bump and infrared sensors.">>
        subject robot : RobotVacuum;
        require { robot.faultType != FaultType::stuck }
    }

    requirement def AdaptiveCleaningRequirement {
        doc << "The robot shall adapt cleaning intensity based on detected floor type.">>
        subject robot : RobotVacuum;
        require {
            robot.cleaningMechanism.floorType == FloorType::carpet
            implies robot.cleaningMechanism.suctionLevel > 50.0
        }
    }

    // ===== Part Definitions =====

    part def BatteryModule {
        attribute chargeLevel : ChargeLevel = 100.0;
        attribute maxCapacity : ChargeLevel = 100.0;
        attribute lowThreshold : ChargeLevel = 20.0;
        port chargingIn : ChargingPort;
        port statusOut : StatusPort;

        action def Discharge :> Action {
            in amount : ChargeLevel;
            then UpdateCharge;
        }
        action def UpdateCharge :> Action {
            then Done;
        }
        action def Charge :> Action {
            in current : ChargingCurrent;
            then UpdateCharge;
        }
        action def Done :> Action;

        state def BatteryStates {
            entry; then Normal;
            state Normal;
            transition Normal to LowBattery
                when chargeLevel < lowThreshold;
            state LowBattery;
            transition LowBattery to Charging
                when chargingIn.current != null;
            state Charging;
            transition Charging to Normal
                when chargeLevel >= maxCapacity;
        }
    }

    part def DustContainer {
        attribute fillLevel : FillLevel = 0.0;
        attribute maxFill : FillLevel = 100.0;
        attribute fullThreshold : FillLevel = 95.0;
        port statusOut : StatusPort;

        action def CollectDebris :> Action {
            in debris : Debris;
            then UpdateFill;
        }
        action def UpdateFill :> Action {
            then CheckFull;
        }
        action def CheckFull :> Action {
            if fillLevel >= fullThreshold { then NotifyFull; }
            else { then Done; }
        }
        action def NotifyFull :> Action;
        action def Done :> Action;
        action def Empty :> Action {
            then ResetFill;
        }
        action def ResetFill :> Action;
    }

    part def InfraredSensor {
        attribute sensorId : String;
        attribute range : DistanceValue;
        port dataOut : SensorDataPort;
        action def Detect :> Action {
            out reading : SensorReading;
        }
    }

    part def BumpSensor {
        attribute triggered : Boolean = false;
        port dataOut : SensorDataPort;
        action def RegisterContact :> Action {
            then EmitReading;
        }
        action def EmitReading :> Action;
    }

    part def CliffSensor {
        attribute detected : Boolean = false;
        port dataOut : SensorDataPort;
        action def DetectEdge :> Action {
            then EmitReading;
        }
        action def EmitReading :> Action;
    }

    part def SensorSuite {
        part infraredSensors : InfraredSensor[4];
        part bumpSensors : BumpSensor[2];
        part cliffSensors : CliffSensor[3];
        port sensorDataOut : SensorDataPort;
        action def AggregateReadings :> Action {
            in irReadings : SensorReading[4];
            in bumpReadings : SensorReading[2];
            in cliffReadings : SensorReading[3];
            then OutputData;
        }
        action def OutputData :> Action;
    }

    part def NavigationSystem {
        attribute currentMap : String;
        attribute position : DistanceValue;
        attribute heading : Real;
        port sensorDataIn : SensorDataPort;
        port beaconDataIn : InfraredPort;
        port navDataOut : NavigationDataPort;
        part sensors : SensorSuite;

        action def ProcessSensorData :> Action {
            in readings : SensorReading;
            then UpdateMap;
        }
        action def UpdateMap :> Action {
            then PlanPath;
        }
        action def PlanPath :> Action {
            then OutputNavigation;
        }
        action def OutputNavigation :> Action {
            out navData : NavigationData;
        }
        action def LocateBeacon :> Action {
            in beacon : BeaconSignal;
            then ComputeDockingPath;
        }
        action def ComputeDockingPath :> Action;
    }

    part def DriveWheel {
        attribute wheelId : String;
        attribute speed : VelocityValue = 0.0;
        attribute direction : Real = 0.0;
        port controlIn : DriveControlPort;
        action def Rotate :> Action {
            in speed : VelocityValue;
        }
        action def Stop :> Action;
    }

    part def CasterWheel {
        attribute orientation : Real;
        action def Pivot :> Action;
    }

    part def DriveSystem {
        part leftWheel : DriveWheel { :>> wheelId = "left"; }
        part rightWheel : DriveWheel { :>> wheelId = "right"; }
        part frontCaster : CasterWheel;
        port controlIn : DriveControlPort;
        port navDataIn : NavigationDataPort;

        action def MoveForward :> Action {
            in speed : VelocityValue;
            then DriveWheels;
        }
        action def Turn :> Action {
            in angle : Real;
            then DriveWheels;
        }
        action def DriveWheels :> Action {
            send leftWheel.Rotate(leftWheel.speed);
            send rightWheel.Rotate(rightWheel.speed);
        }
        action def Stop :> Action {
            send leftWheel.Stop();
            send rightWheel.Stop();
        }
    }

    part def MainBrush {
        attribute rotationRate : RotationRate = 0.0;
        attribute active : Boolean = false;
        port controlIn : CleaningControlPort;
        action def Rotate :> Action {
            in rate : RotationRate;
        }
        action def Stop :> Action;
    }

    part def SideBrush {
        attribute side : String;
        attribute rotationRate : RotationRate = 0.0;
        attribute active : Boolean = false;
        action def Rotate :> Action {
            in rate : RotationRate;
        }
        action def Stop :> Action;
    }

    part def VacuumMotor {
        attribute suctionLevel : SuctionPower = 0.0;
        attribute active : Boolean = false;
        action def Activate :> Action {
            in power : SuctionPower;
        }
        action def Deactivate :> Action;
    }

    part def CleaningMechanism {
        attribute floorType : FloorType = FloorType::hardwood;
        attribute suctionLevel : SuctionPower = 30.0;
        attribute currentMode : CleaningMode = CleaningMode::normal;
        port controlIn : CleaningControlPort;
        part mainBrush : MainBrush;
        part leftSideBrush : SideBrush { :>> side = "left"; }
        part rightSideBrush : SideBrush { :>> side = "right"; }
        part vacuum : VacuumMotor;
        port debrisOut;

        action def Clean :> Action {
            in mode : CleaningMode;
            then SelectIntensity;
        }
        action def SelectIntensity :> Action {
            if mode == CleaningMode::intensive {
                then SetIntensive;
            } else if mode == CleaningMode::edge {
                then SetEdge;
            } else {
                then SetNormal;
            }
        }
        action def SetIntensive :> Action {
            :>> suctionLevel = 80.0;
            then ActivateComponents;
        }
        action def SetEdge :> Action {
            :>> suctionLevel = 40.0;
            then ActivateComponents;
        }
        action def SetNormal :> Action {
            :>> suctionLevel = 50.0;
            then ActivateComponents;
        }
        action def ActivateComponents :> Action {
            send mainBrush.Rotate(mainBrush.rotationRate);
            send leftSideBrush.Rotate(leftSideBrush.rotationRate);
            send rightSideBrush.Rotate(rightSideBrush.rotationRate);
            send vacuum.Activate(suctionLevel);
        }
        action def StopCleaning :> Action {
            send mainBrush.Stop();
            send leftSideBrush.Stop();
            send rightSideBrush.Stop();
            send vacuum.Deactivate();
        }
        action def DetectFloorType :> Action {
            then AdaptIntensity;
        }
        action def AdaptIntensity :> Action {
            if floorType == FloorType::carpet {
                then SetIntensive;
            }
        }
    }

    part def ControlProcessor {
        attribute operatingMode : OperatingMode = OperatingMode::standby;
        attribute currentCleaningMode : CleaningMode = CleaningMode::normal;
        attribute missionStatus : MissionStatus = MissionStatus::inProgress;
        attribute faultType : FaultType = FaultType::none;
        port navDataIn : NavigationDataPort;
        port driveControlOut : DriveControlPort;
        port cleaningControlOut : CleaningControlPort;
        port statusOut : StatusPort;
        port batteryStatusIn : StatusPort;
        port binStatusIn : StatusPort;
        port dockingStatusIn : DockingPort;

        action def DecideMode :> Action {
            if faultType != FaultType::none {
                then EnterError;
            } else if missionStatus == MissionStatus::complete {
                then ReturnToBase;
            } else if batteryStatusIn.status.batteryCharge < 20.0 {
                then ReturnToBase;
            } else if binStatusIn.status.binFill > 95.0 {
                then ReturnToBase;
            } else if operatingMode == OperatingMode::activeCleaning {
                then ContinueCleaning;
            } else {
                then Idle;
            }
        }
        action def EnterError :> Action {
            :>> operatingMode = OperatingMode::error;
        }
        action def ReturnToBase :> Action {
            :>> operatingMode = OperatingMode::returningToBase;
            then IssueDriveCommand;
        }
        action def ContinueCleaning :> Action {
            then SelectCleaningMode;
        }
        action def SelectCleaningMode :> Action {
            then IssueCleaningCommand;
        }
        action def IssueDriveCommand :> Action {
            out cmd : DriveCommand;
        }
        action def IssueCleaningCommand :> Action {
            out cmd : CleaningCommand;
        }
        action def Idle :> Action;

        state def ControlStates {
            entry; then Standby;
            state Standby {
                entry { operatingMode = OperatingMode::standby; }
            }
            transition Standby to ActiveCleaning
                when missionStatus == MissionStatus::inProgress;
            state ActiveCleaning {
                entry { operatingMode = OperatingMode::activeCleaning; }
            }
            transition ActiveCleaning to ReturningToBase
                when batteryStatusIn.status.batteryCharge < 20.0
                or binStatusIn.status.binFill > 95.0
                or missionStatus == MissionStatus::complete;
            transition ActiveCleaning to ErrorState
                when faultType != FaultType::none;
            state ReturningToBase {
                entry { operatingMode = OperatingMode::returningToBase; }
            }
            transition ReturningToBase to DockedCharging
                when dockingStatusIn.dockStatus == DockingStatus::docked;
            transition ReturningToBase to ErrorState
                when faultType != FaultType::none;
            state DockedCharging {
                entry { operatingMode = OperatingMode::dockedCharging; }
            }
            transition DockedCharging to Standby
                when batteryStatusIn.status.batteryCharge >= 100.0
                and missionStatus == MissionStatus::complete;
            transition DockedCharging to ActiveCleaning
                when batteryStatusIn.status.batteryCharge >= 100.0
                and missionStatus == MissionStatus::inProgress;
            state ErrorState {
                entry { operatingMode = OperatingMode::error; }
            }
            transition ErrorState to Standby
                when faultType == FaultType::none;
        }
    }

    part def ChargingStation {
        attribute stationId : String = "base-01";
        attribute outputPower : PowerLevel = 20.0;
        attribute beaconActive : Boolean = true;
        port powerOut : PowerPort;
        port beaconOut : BeaconPort;

        action def EmitBeacon :> Action {
            out signal : BeaconSignal;
        }
        action def ChargeRobot :> Action {
            in docked : Boolean;
            then SupplyCurrent;
        }
        action def SupplyCurrent :> Action {
            out current : ChargingCurrent;
        }
        action def Idle :> Action;

        state def StationStates {
            entry; then BeaconOn;
            state BeaconOn {
                entry { beaconActive = true; }
            }
            transition BeaconOn to Charging
                when powerOut.power != null;
            state Charging {
                entry { beaconActive = true; }
            }
            transition Charging to BeaconOn
                when powerOut.power == null;
        }
    }

    part def RobotVacuum {
        attribute robotId : String = "vacuum-01";
        attribute operatingMode : OperatingMode = OperatingMode::standby;
        attribute missionStatus : MissionStatus = MissionStatus::inProgress;
        attribute faultType : FaultType = FaultType::none;
        attribute dockingStatus : DockingStatus = DockingStatus::notDocked;

        port chargingIn : ChargingPort;
        port beaconIn : InfraredPort;
        port statusOut : StatusPort;

        part control : ControlProcessor;
        part navigation : NavigationSystem;
        part drive : DriveSystem;
        part cleaning : CleaningMechanism;
        part dustContainer : DustContainer;
        part battery : BatteryModule;

        connection control.navDataIn connect navigation.navDataOut;
        connection control.driveControlOut connect drive.controlIn;
        connection control.cleaningControlOut connect cleaning.controlIn;
        connection control.batteryStatusIn connect battery.statusOut;
        connection control.binStatusIn connect dustContainer.statusOut;
        connection navigation.sensorDataIn connect navigation.sensors.sensorDataOut;
        connection drive.navDataIn connect navigation.navDataOut;
        connection chargingIn connect battery.chargingIn;
        connection beaconIn connect navigation.beaconDataIn;

        action def StartMission :> Action {
            then LeaveDock;
        }
        action def LeaveDock :> Action {
            :>> operatingMode = OperatingMode::activeCleaning;
            :>> missionStatus = MissionStatus::inProgress;
            then NavigateArea;
        }
        action def NavigateArea :> Action {
            then CleanArea;
        }
        action def CleanArea :> Action {
            then CheckConditions;
        }
        action def CheckConditions :> Action {
            if battery.chargeLevel < 20.0 or dustContainer.fillLevel > 95.0 or missionStatus == MissionStatus::complete {
                then ReturnToDock;
            } else {
                then CleanArea;
            }
        }
        action def ReturnToDock :> Action {
            :>> operatingMode = OperatingMode::returningToBase;
            then LocateStation;
        }
        action def LocateStation :> Action {
            then ApproachDock;
        }
        action def ApproachDock :> Action {
            then Dock;
        }
        action def Dock :> Action {
            :>> dockingStatus = DockingStatus::docked;
            then ChargeBattery;
        }
        action def ChargeBattery :> Action {
            :>> operatingMode = OperatingMode::dockedCharging;
            then CheckChargeComplete;
        }
        action def CheckChargeComplete :> Action {
            if battery.chargeLevel >= 100.0 {
                then MissionComplete;
            } else {
                then ChargeBattery;
            }
        }
        action def MissionComplete :> Action {
            :>> operatingMode = OperatingMode::standby;
        }
        action def HandleError :> Action {
            :>> operatingMode = OperatingMode::error;
            then StopAll;
        }
        action def StopAll :> Action {
            send drive.Stop();
            send cleaning.StopCleaning();
        }

        state def RobotOperationStates {
            entry; then Docked;
            state Docked {
                entry { operatingMode = OperatingMode::dockedCharging; }
            }
            transition Docked to Cleaning
                when battery.chargeLevel >= 100.0
                and missionStatus == MissionStatus::inProgress;
            state Cleaning {
                entry { operatingMode = OperatingMode::activeCleaning; }
            }
            transition Cleaning to Returning
                when battery.chargeLevel < 20.0
                or dustContainer.fillLevel > 95.0
                or missionStatus == MissionStatus::complete;
            transition Cleaning to Error
                when faultType != FaultType::none;
            state Returning {
                entry { operatingMode = OperatingMode::returningToBase; }
            }
            transition Returning to Docked
                when dockingStatus == DockingStatus::docked;
            transition Returning to Error
                when faultType != FaultType::none;
            state Error {
                entry { operatingMode = OperatingMode::error; }
            }
            transition Error to Docked
                when faultType == FaultType::none
                and dockingStatus == DockingStatus::docked;
            transition Error to Standby
                when faultType == FaultType::none
                and dockingStatus == DockingStatus::notDocked;
            state Standby {
                entry { operatingMode = OperatingMode::standby; }
            }
            transition Standby to Cleaning
                when missionStatus == MissionStatus::inProgress;
        }
    }

    // ===== Top-level System =====
    part def VacuumSystem {
        part robot : RobotVacuum;
        part station : ChargingStation;

        connection station.powerOut connect robot.chargingIn;
        connection station.beaconOut connect robot.beaconIn;

        satisfy CleaningMissionRequirement by robot;
        satisfy AutoReturnRequirement by robot;
        satisfy DockingRequirement by robot, station;
        satisfy SafetyRequirement by robot;
        satisfy AdaptiveCleaningRequirement by robot;
    }

}

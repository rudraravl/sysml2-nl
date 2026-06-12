package RoboticLawnMowerSpecification {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    value type Length :> ISQ::length {
        unit = SI::metre;
    }

    value type Area :> ISQ::area {
        unit = SI::squareMetre;
    }

    value type Speed :> ISQ::speed {
        unit = SI::metrePerSecond;
    }

    value type Power :> ISQ::power {
        unit = SI::watt;
    }

    value type Energy :> ISQ::energy {
        unit = SI::joule;
    }

    value type Voltage :> ISQ::electricPotential {
        unit = SI::volt;
    }

    value type Current :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    value type Time :> ISQ::time {
        unit = SI::second;
    }

    value type Angle :> ISQ::planeAngle {
        unit = SI::degree;
    }

    enum def MowerOperatingMode {
        enum idle;
        enum mowing;
        enum returningToDock;
        enum charging;
        enum fault;
        enum paused;
    }

    enum def TerrainCondition {
        enum dryGrass;
        enum wetGrass;
        enum unevenGround;
        enum obstacleDense;
    }

    item def GrassCuttingCommand {
        attribute targetCutHeight : Length;
        attribute mowingArea : Area;
        attribute scheduledStartTime : Time;
        attribute scheduledDuration : Time;
    }

    item def NavigationCommand {
        attribute targetPositionX : Length;
        attribute targetPositionY : Length;
        attribute desiredSpeed : Speed;
        attribute desiredHeading : Angle;
    }

    item def BatteryStatus {
        attribute stateOfCharge : Real;
        attribute packVoltage : Voltage;
        attribute packCurrent : Current;
        attribute availableEnergy : Energy;
        attribute estimatedRuntime : Time;
    }

    item def ObstacleReport {
        attribute obstacleDistance : Length;
        attribute obstacleBearing : Angle;
        attribute collisionRisk : Boolean;
    }

    item def LawnBoundarySignal {
        attribute boundaryDetected : Boolean;
        attribute distanceToBoundary : Length;
        attribute signalStrength : Real;
    }

    item def CutGrassFlow {
        attribute grassBladeHeightBeforeCut : Length;
        attribute grassBladeHeightAfterCut : Length;
        attribute cutWidth : Length;
    }

    item def UserControlMessage {
        attribute startRequested : Boolean;
        attribute stopRequested : Boolean;
        attribute pauseRequested : Boolean;
        attribute returnToDockRequested : Boolean;
        attribute requestedCutHeight : Length;
    }

    port def ElectricalPowerPort {
        out item powerOutput : Power;
        out item voltageOutput : Voltage;
        out item currentOutput : Current;
    }

    port def ChargingPort {
        in item chargingVoltage : Voltage;
        in item chargingCurrent : Current;
        out item batteryStatus : BatteryStatus;
    }

    port def MotionCommandPort {
        in item command : NavigationCommand;
    }

    port def SensorDataPort {
        out item obstacleReport : ObstacleReport;
        out item boundarySignal : LawnBoundarySignal;
    }

    port def CuttingCommandPort {
        in item cuttingCommand : GrassCuttingCommand;
    }

    port def UserInterfacePort {
        in item userMessage : UserControlMessage;
        out item operatingMode : MowerOperatingMode;
        out item batteryStatus : BatteryStatus;
    }

    part def BatteryPack {
        attribute nominalVoltage : Voltage = 36 [SI::volt];
        attribute capacityEnergy : Energy = 540000 [SI::joule];
        attribute minimumSafeStateOfCharge : Real = 0.15;
        attribute currentStateOfCharge : Real;
        attribute maximumDischargePower : Power = 600 [SI::watt];

        port powerPort : ElectricalPowerPort;
        port chargePort : ChargingPort;

        action def ProvideElectricalPower {
            in requestedPower : Power;
            out suppliedPower : Power;
            out status : BatteryStatus;

            assert constraint {
                suppliedPower <= maximumDischargePower
            }
        }

        action def AcceptCharge {
            in chargingPower : Power;
            out updatedStatus : BatteryStatus;
        }
    }

    part def DriveSubsystem {
        attribute maximumForwardSpeed : Speed = 0.7 [SI::metrePerSecond];
        attribute nominalMowingSpeed : Speed = 0.35 [SI::metrePerSecond];
        attribute maximumSlopeAngle : Angle = 20 [SI::degree];
        attribute wheelTrackWidth : Length = 0.42 [SI::metre];

        port motionInput : MotionCommandPort;
        port powerInput : ElectricalPowerPort;

        part leftWheelMotor;
        part rightWheelMotor;
        part tractionController;

        action def ExecuteMotion {
            in command : NavigationCommand;
            out actualSpeed : Speed;
            out actualHeading : Angle;

            assert constraint {
                actualSpeed <= maximumForwardSpeed
            }
        }
    }

    part def CuttingSubsystem {
        attribute adjustableCutHeightMinimum : Length = 0.025 [SI::metre];
        attribute adjustableCutHeightMaximum : Length = 0.075 [SI::metre];
        attribute selectedCutHeight : Length = 0.04 [SI::metre];
        attribute cuttingDeckWidth : Length = 0.24 [SI::metre];
        attribute bladeMotorPower : Power = 120 [SI::watt];

        port cuttingInput : CuttingCommandPort;
        port powerInput : ElectricalPowerPort;

        part rotatingBlade;
        part bladeMotor;
        part deckHeightActuator;

        action def CutGrass {
            in command : GrassCuttingCommand;
            in mowerSpeed : Speed;
            out cutGrass : CutGrassFlow;

            assert constraint {
                command.targetCutHeight >= adjustableCutHeightMinimum and
                command.targetCutHeight <= adjustableCutHeightMaximum
            }
        }

        action def StopBlade {
            out bladeStopped : Boolean;
        }
    }

    part def SensorSubsystem {
        attribute obstacleDetectionRange : Length = 2.0 [SI::metre];
        attribute boundaryDetectionRange : Length = 0.5 [SI::metre];
        attribute liftDetected : Boolean;
        attribute tiltAngle : Angle;

        port sensorOutput : SensorDataPort;

        part ultrasonicObstacleSensors;
        part bumperSwitches;
        part liftSensor;
        part tiltSensor;
        part rainSensor;
        part boundaryWireReceiver;

        action def DetectObstacle {
            out report : ObstacleReport;
        }

        action def DetectBoundary {
            out signal : LawnBoundarySignal;
        }

        action def DetectUnsafeCondition {
            out unsafe : Boolean;
        }
    }

    part def NavigationController {
        attribute plannedCoverageArea : Area;
        attribute completedCoverageArea : Area;
        attribute currentPositionX : Length;
        attribute currentPositionY : Length;
        attribute currentHeading : Angle;
        attribute laneSpacing : Length = 0.20 [SI::metre];

        port sensorInput : SensorDataPort;
        port motionOutput : MotionCommandPort;

        action def PlanCoveragePath {
            in mowingArea : Area;
            out nextCommand : NavigationCommand;
        }

        action def AvoidObstacle {
            in report : ObstacleReport;
            out avoidanceCommand : NavigationCommand;
        }

        action def ReturnToDock {
            out dockCommand : NavigationCommand;
        }
    }

    part def SupervisoryController {
        attribute mode : MowerOperatingMode = MowerOperatingMode::idle;
        attribute requestedCutHeight : Length = 0.04 [SI::metre];
        attribute lowBatteryThreshold : Real = 0.20;
        attribute criticalBatteryThreshold : Real = 0.08;

        port userInterface : UserInterfacePort;
        port sensorInput : SensorDataPort;
        port cuttingOutput : CuttingCommandPort;
        port motionOutput : MotionCommandPort;

        action def StartMowingMission {
            in command : GrassCuttingCommand;
            out accepted : Boolean;
        }

        action def PauseMission {
            out bladeStopCommandIssued : Boolean;
            out motionStopCommandIssued : Boolean;
        }

        action def HandleFault {
            in unsafeCondition : Boolean;
            out systemStopped : Boolean;
        }

        state def OperatingStateMachine {
            state idle;
            state mowing;
            state avoidingObstacle;
            state returningToDock;
            state charging;
            state paused;
            state fault;

            entry action idle {
                mode = MowerOperatingMode::idle;
            }

            transition first idle;

            transition idle_to_mowing
                first idle
                then mowing
                if userInterface.userMessage.startRequested;

            transition mowing_to_avoidingObstacle
                first mowing
                then avoidingObstacle
                if sensorInput.obstacleReport.collisionRisk;

            transition avoidingObstacle_to_mowing
                first avoidingObstacle
                then mowing
                if not sensorInput.obstacleReport.collisionRisk;

            transition mowing_to_returningToDock
                first mowing
                then returningToDock
                if userInterface.userMessage.returnToDockRequested;

            transition mowing_to_paused
                first mowing
                then paused
                if userInterface.userMessage.pauseRequested;

            transition paused_to_mowing
                first paused
                then mowing
                if userInterface.userMessage.startRequested;

            transition returningToDock_to_charging
                first returningToDock
                then charging;

            transition charging_to_idle
                first charging
                then idle;

            transition any_to_fault
                first mowing
                then fault
                if sensorInput.obstacleReport.collisionRisk and sensorInput.boundarySignal.boundaryDetected;
        }
    }

    part def DockingStation {
        attribute chargingPower : Power = 150 [SI::watt];
        attribute dockPositionX : Length = 0 [SI::metre];
        attribute dockPositionY : Length = 0 [SI::metre];

        port chargingOutput : ChargingPort;
    }

    part def RoboticLawnMower {
        attribute mowerMass : Real = 12.5;
        attribute maximumMowingAreaPerCharge : Area = 600 [SI::squareMetre];
        attribute nominalCoverageRate : Real = 75.0;
        attribute weatherProtected : Boolean = true;

        port userPort : UserInterfacePort;
        port dockChargePort : ChargingPort;

        part battery : BatteryPack;
        part drive : DriveSubsystem;
        part cutter : CuttingSubsystem;
        part sensors : SensorSubsystem;
        part navigation : NavigationController;
        part supervisor : SupervisoryController;

        connect battery.powerPort to drive.powerInput;
        connect battery.powerPort to cutter.powerInput;
        connect sensors.sensorOutput to navigation.sensorInput;
        connect sensors.sensorOutput to supervisor.sensorInput;
        connect navigation.motionOutput to drive.motionInput;
        connect supervisor.motionOutput to drive.motionInput;
        connect supervisor.cuttingOutput to cutter.cuttingInput;
        connect supervisor.userInterface to userPort;
        connect battery.chargePort to dockChargePort;

        action def PerformPrimaryFunction {
            in missionCommand : GrassCuttingCommand;
            out completedArea : Area;
            out finalBatteryStatus : BatteryStatus;

            first startMission : supervisor.StartMowingMission {
                in command = missionCommand;
            }

            then planPath : navigation.PlanCoveragePath {
                in mowingArea = missionCommand.mowingArea;
            }

            then move : drive.ExecuteMotion {
                in command = planPath.nextCommand;
            }

            then cut : cutter.CutGrass {
                in command = missionCommand;
                in mowerSpeed = move.actualSpeed;
            }

            then reportStatus : battery.ProvideElectricalPower {
                in requestedPower = 250 [SI::watt];
            }

            bind finalBatteryStatus = reportStatus.status;
        }
    }

    part def LawnMowingSystem {
        part mower : RoboticLawnMower;
        part dock : DockingStation;

        connect dock.chargingOutput to mower.dockChargePort;
    }

    requirement def PrimaryFunctionRequirement {
        subject mower : RoboticLawnMower;

        require constraint {
            mower.maximumMowingAreaPerCharge >= 400 [SI::squareMetre]
        }

        doc /* The robotic lawn mower shall autonomously cut grass within a defined lawn boundary by planning and following a coverage path, propelling itself across the lawn, maintaining the commanded grass cut height, avoiding obstacles, monitoring battery energy, and returning to the docking station when mowing is complete or energy is low. */
    }

    requirement def SafetyObstacleRequirement {
        subject mower : RoboticLawnMower;

        require constraint {
            mower.sensors.obstacleDetectionRange >= 1.0 [SI::metre]
        }

        doc /* The mower shall detect obstacles in its travel path and command avoidance or stop motion before collision risk becomes unacceptable. */
    }

    requirement def BoundaryContainmentRequirement {
        subject mower : RoboticLawnMower;

        require constraint {
            mower.sensors.boundaryDetectionRange >= 0.25 [SI::metre]
        }

        doc /* The mower shall remain inside the assigned lawn boundary during autonomous mowing operation. */
    }

    requirement def CuttingHeightRequirement {
        subject mower : RoboticLawnMower;

        require constraint {
            mower.cutter.selectedCutHeight >= mower.cutter.adjustableCutHeightMinimum and
            mower.cutter.selectedCutHeight <= mower.cutter.adjustableCutHeightMaximum
        }

        doc /* The mower shall cut grass at a user-selected height within the supported cutting height range. */
    }

    requirement def EnergyManagementRequirement {
        subject mower : RoboticLawnMower;

        require constraint {
            mower.battery.minimumSafeStateOfCharge >= 0.10
        }

        doc /* The mower shall monitor battery state of charge and return to the docking station before reaching the minimum safe battery threshold. */
    }

    satisfy PrimaryFunctionRequirement by RoboticLawnMower::PerformPrimaryFunction;
    satisfy SafetyObstacleRequirement by SensorSubsystem::DetectObstacle;
    satisfy BoundaryContainmentRequirement by SensorSubsystem::DetectBoundary;
    satisfy CuttingHeightRequirement by CuttingSubsystem::CutGrass;
    satisfy EnergyManagementRequirement by BatteryPack::ProvideElectricalPower;
}
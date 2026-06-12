package IndustrialRoboticPrimaryTaskSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent :> Real {
        doc "Percentage value from 0 to 100.";
    }

    attribute def Millimeter :> LengthValue;
    attribute def MeterPerSecond :> SpeedValue;
    attribute def MillimeterPerSecond :> SpeedValue;
    attribute def Kilogram :> MassValue;
    attribute def Newton :> ForceValue;
    attribute def NewtonMeter :> TorqueValue;
    attribute def Degree :> PlaneAngleValue;
    attribute def Second :> TimeValue;
    attribute def Volt :> ElectricPotentialValue;
    attribute def Ampere :> ElectricCurrentValue;
    attribute def Watt :> PowerValue;
    attribute def Celsius :> TemperatureValue;

    item def Workpiece {
        attribute id : String;
        attribute mass : Kilogram;
        attribute length : Millimeter;
        attribute width : Millimeter;
        attribute height : Millimeter;
        attribute material : String;
        attribute isProcessed : Boolean;
        attribute qualityStatus : QualityStatusKind;
    }

    item def ToolCommand {
        attribute enable : Boolean;
        attribute targetForce : Newton;
        attribute targetSpeed : MillimeterPerSecond;
        attribute processMode : ProcessModeKind;
    }

    item def MotionCommand {
        attribute targetPoseX : Millimeter;
        attribute targetPoseY : Millimeter;
        attribute targetPoseZ : Millimeter;
        attribute targetRoll : Degree;
        attribute targetPitch : Degree;
        attribute targetYaw : Degree;
        attribute linearSpeed : MillimeterPerSecond;
        attribute blendRadius : Millimeter;
    }

    item def RobotStatus {
        attribute robotMode : RobotModeKind;
        attribute currentPoseX : Millimeter;
        attribute currentPoseY : Millimeter;
        attribute currentPoseZ : Millimeter;
        attribute payloadMass : Kilogram;
        attribute emergencyStopActive : Boolean;
        attribute protectiveStopActive : Boolean;
        attribute cycleComplete : Boolean;
    }

    item def SafetySignal {
        attribute safetyOk : Boolean;
        attribute guardDoorClosed : Boolean;
        attribute lightCurtainClear : Boolean;
        attribute emergencyStopReset : Boolean;
        attribute enablingDeviceActive : Boolean;
    }

    item def ProcessResult {
        attribute workpieceId : String;
        attribute success : Boolean;
        attribute measuredForcePeak : Newton;
        attribute measuredCycleTime : Second;
        attribute qualityStatus : QualityStatusKind;
        attribute rejectReason : String;
    }

    item def ElectricalPower {
        attribute voltage : Volt;
        attribute current : Ampere;
        attribute power : Watt;
    }

    enum def RobotModeKind {
        enum idle;
        enum homing;
        enum automatic;
        enum manual;
        enum faulted;
        enum stopped;
    }

    enum def ProcessModeKind {
        enum pick;
        enum place;
        enum weld;
        enum deburr;
        enum inspect;
        enum standby;
    }

    enum def QualityStatusKind {
        enum unknown;
        enum pass;
        enum fail;
        enum rework;
    }

    enum def CellStateKind {
        enum poweredOff;
        enum initializing;
        enum ready;
        enum loading;
        enum processing;
        enum unloading;
        enum complete;
        enum safeStopped;
        enum faulted;
    }

    port def WorkpieceInputPort {
        in item workpieceIn : Workpiece;
    }

    port def WorkpieceOutputPort {
        out item workpieceOut : Workpiece;
    }

    port def MotionCommandPort {
        out item motionCommand : MotionCommand;
    }

    port def ToolCommandPort {
        out item toolCommand : ToolCommand;
    }

    port def RobotStatusPort {
        in item robotStatus : RobotStatus;
    }

    port def SafetySignalPort {
        in item safetySignal : SafetySignal;
    }

    port def ProcessResultPort {
        out item processResult : ProcessResult;
    }

    port def ElectricalPowerPort {
        in item powerIn : ElectricalPower;
    }

    port def ControlNetworkPort {
        inout item motionCommand : MotionCommand;
        inout item robotStatus : RobotStatus;
        inout item toolCommand : ToolCommand;
        inout item processResult : ProcessResult;
    }

    interface def ControlNetworkInterface {
        end controllerPort : ControlNetworkPort;
        end robotPort : ControlNetworkPort;
    }

    interface def SafetyInterface {
        end safetyControllerPort : SafetySignalPort;
        end robotSafetyPort : SafetySignalPort;
    }

    interface def WorkpieceTransferInterface {
        end sourcePort : WorkpieceOutputPort;
        end destinationPort : WorkpieceInputPort;
    }

    part def IndustrialRobot {
        attribute manufacturer : String;
        attribute model : String;
        attribute degreesOfFreedom : Integer;
        attribute maximumReach : Millimeter;
        attribute ratedPayload : Kilogram;
        attribute repeatability : Millimeter;
        attribute maximumTcpSpeed : MeterPerSecond;
        attribute baseMass : Kilogram;
        attribute installedPower : Watt;
        attribute currentMode : RobotModeKind;

        port controlPort : ControlNetworkPort;
        port safetyPort : SafetySignalPort;
        port powerPort : ElectricalPowerPort;

        part axis1 {
            attribute jointLimitMin : Degree = -170 [SI::degree];
            attribute jointLimitMax : Degree = 170 [SI::degree];
            attribute maxTorque : NewtonMeter = 1200 [SI::newton * SI::meter];
            attribute currentAngle : Degree;
        }

        part axis2 {
            attribute jointLimitMin : Degree = -120 [SI::degree];
            attribute jointLimitMax : Degree = 145 [SI::degree];
            attribute maxTorque : NewtonMeter = 1000 [SI::newton * SI::meter];
            attribute currentAngle : Degree;
        }

        part axis3 {
            attribute jointLimitMin : Degree = -150 [SI::degree];
            attribute jointLimitMax : Degree = 150 [SI::degree];
            attribute maxTorque : NewtonMeter = 820 [SI::newton * SI::meter];
            attribute currentAngle : Degree;
        }

        part axis4 {
            attribute jointLimitMin : Degree = -185 [SI::degree];
            attribute jointLimitMax : Degree = 185 [SI::degree];
            attribute maxTorque : NewtonMeter = 260 [SI::newton * SI::meter];
            attribute currentAngle : Degree;
        }

        part axis5 {
            attribute jointLimitMin : Degree = -120 [SI::degree];
            attribute jointLimitMax : Degree = 120 [SI::degree];
            attribute maxTorque : NewtonMeter = 210 [SI::newton * SI::meter];
            attribute currentAngle : Degree;
        }

        part axis6 {
            attribute jointLimitMin : Degree = -360 [SI::degree];
            attribute jointLimitMax : Degree = 360 [SI::degree];
            attribute maxTorque : NewtonMeter = 120 [SI::newton * SI::meter];
            attribute currentAngle : Degree;
        }

        part flange {
            attribute isoPattern : String = "ISO 9409-1-80-6-M8";
            attribute toolMassLimit : Kilogram = 12 [SI::kilogram];
        }

        action homeRobot {
            in item safety : SafetySignal;
            out item status : RobotStatus;
        }

        action executeMotion {
            in item command : MotionCommand;
            out item status : RobotStatus;
        }

        action stopRobot {
            in item safety : SafetySignal;
            out item status : RobotStatus;
        }

        state def RobotOperation {
            entry; then idle;

            state idle;
            state homing;
            state automatic;
            state protectiveStopped;
            state emergencyStopped;
            state faulted;

            transition idle_to_homing
                first idle
                accept MotionCommand
                if safetySignal.safetyOk
                then homing;

            transition homing_to_auto
                first homing
                if robotStatus.robotMode == RobotModeKind::automatic
                then automatic;

            transition auto_to_protective_stop
                first automatic
                if safetySignal.lightCurtainClear == false or safetySignal.guardDoorClosed == false
                then protectiveStopped;

            transition any_to_emergency_stop
                first idle, homing, automatic, protectiveStopped
                if safetySignal.emergencyStopReset == false
                then emergencyStopped;

            transition protective_stop_to_idle
                first protectiveStopped
                if safetySignal.safetyOk
                then idle;

            transition emergency_stop_to_idle
                first emergencyStopped
                if safetySignal.emergencyStopReset and safetySignal.guardDoorClosed and safetySignal.lightCurtainClear
                then idle;

            transition any_to_fault
                first idle, homing, automatic, protectiveStopped
                if robotStatus.protectiveStopActive and robotStatus.emergencyStopActive
                then faulted;
        }
    }

    part def EndEffector {
        attribute toolType : String;
        attribute mass : Kilogram;
        attribute maximumGripForce : Newton;
        attribute minimumGripForce : Newton;
        attribute toolCenterPointOffsetX : Millimeter;
        attribute toolCenterPointOffsetY : Millimeter;
        attribute toolCenterPointOffsetZ : Millimeter;
        attribute processTemperatureLimit : Celsius;

        port controlPort : ControlNetworkPort;
        port powerPort : ElectricalPowerPort;

        action grip {
            in item workpiece : Workpiece;
            in item command : ToolCommand;
            out item grippedWorkpiece : Workpiece;
        }

        action release {
            in item workpiece : Workpiece;
            out item releasedWorkpiece : Workpiece;
        }

        action performPrimaryProcess {
            in item workpiece : Workpiece;
            in item command : ToolCommand;
            out item result : ProcessResult;
        }
    }

    part def RobotController {
        attribute controllerModel : String;
        attribute servoUpdatePeriod : Second;
        attribute programName : String;
        attribute cycleCounter : Integer;
        attribute targetCycleTime : Second;
        attribute currentCellState : CellStateKind;

        port networkPort : ControlNetworkPort;
        port safetyPort : SafetySignalPort;
        port powerPort : ElectricalPowerPort;

        action planCycle {
            in item workpiece : Workpiece;
            out item pickMotion : MotionCommand;
            out item processMotion : MotionCommand;
            out item placeMotion : MotionCommand;
            out item toolCommand : ToolCommand;
        }

        action evaluateResult {
            in item result : ProcessResult;
            out item acceptedWorkpiece : Workpiece;
            out item rejectedWorkpiece : Workpiece;
        }

        state def CellControlStateMachine {
            entry; then poweredOff;

            state poweredOff;
            state initializing;
            state ready;
            state loading;
            state processing;
            state unloading;
            state complete;
            state safeStopped;
            state faulted;

            transition power_on
                first poweredOff
                accept ElectricalPower
                then initializing;

            transition initialization_complete
                first initializing
                if safetySignal.safetyOk
                then ready;

            transition ready_to_loading
                first ready
                accept Workpiece
                then loading;

            transition loading_to_processing
                first loading
                if robotStatus.robotMode == RobotModeKind::automatic
                then processing;

            transition processing_to_unloading
                first processing
                if robotStatus.cycleComplete
                then unloading;

            transition unloading_to_complete
                first unloading
                accept ProcessResult
                then complete;

            transition complete_to_ready
                first complete
                then ready;

            transition any_to_safe_stopped
                first initializing, ready, loading, processing, unloading, complete
                if safetySignal.safetyOk == false
                then safeStopped;

            transition safe_stopped_to_ready
                first safeStopped
                if safetySignal.safetyOk
                then ready;

            transition any_to_faulted
                first initializing, ready, loading, processing, unloading, complete, safeStopped
                if robotStatus.emergencyStopActive and robotStatus.protectiveStopActive
                then faulted;
        }
    }

    part def SafetyController {
        attribute safetyIntegrityLevel : String = "SIL 2";
        attribute performanceLevel : String = "PL d";
        attribute stopCategory : Integer = 1;
        attribute resetRequired : Boolean = true;

        port robotSafetyPort : SafetySignalPort;
        port controllerSafetyPort : SafetySignalPort;
        port powerPort : ElectricalPowerPort;

        part emergencyStopButton {
            attribute pressed : Boolean;
            attribute resettable : Boolean = true;
        }

        part lightCurtain {
            attribute clear : Boolean;
            attribute protectedHeight : Millimeter = 1200 [SI::milli * SI::meter];
            attribute responseTime : Second = 0.020 [SI::second];
        }

        part guardDoorSwitch {
            attribute closed : Boolean;
            attribute locked : Boolean;
        }

        action computeSafetyPermission {
            in attribute emergencyStopReset : Boolean;
            in attribute lightCurtainClear : Boolean;
            in attribute guardDoorClosed : Boolean;
            out item signal : SafetySignal;
        }
    }

    part def WorkpieceFeeder {
        attribute bufferCapacity : Integer;
        attribute currentCount : Integer;
        attribute feedRate : MillimeterPerSecond;
        attribute locatorRepeatability : Millimeter;

        port workpieceOutPort : WorkpieceOutputPort;
        port powerPort : ElectricalPowerPort;

        action indexNextWorkpiece {
            out item nextWorkpiece : Workpiece;
        }
    }

    part def Fixture {
        attribute clampForce : Newton;
        attribute locationRepeatability : Millimeter;
        attribute occupied : Boolean;

        port workpieceInPort : WorkpieceInputPort;
        port workpieceOutPort : WorkpieceOutputPort;
        port powerPort : ElectricalPowerPort;

        action clampWorkpiece {
            in item workpiece : Workpiece;
            out item clampedWorkpiece : Workpiece;
        }

        action releaseWorkpiece {
            in item workpiece : Workpiece;
            out item releasedWorkpiece : Workpiece;
        }
    }

    part def ProcessStation {
        attribute stationName : String;
        attribute processForceNominal : Newton;
        attribute processForceMaximum : Newton;
        attribute processSpeedNominal : MillimeterPerSecond;
        attribute allowedPositionTolerance : Millimeter;

        port workpieceInPort : WorkpieceInputPort;
        port workpieceOutPort : WorkpieceOutputPort;
        port resultPort : ProcessResultPort;
        port powerPort : ElectricalPowerPort;

        part fixture : Fixture;

        action processWorkpiece {
            in item workpiece : Workpiece;
            in item toolCommand : ToolCommand;
            out item processedWorkpiece : Workpiece;
            out item result : ProcessResult;
        }
    }

    part def VisionInspectionSystem {
        attribute cameraResolutionX : Integer;
        attribute cameraResolutionY : Integer;
        attribute fieldOfViewX : Millimeter;
        attribute fieldOfViewY : Millimeter;
        attribute measurementAccuracy : Millimeter;
        attribute inspectionTime : Second;

        port networkPort : ControlNetworkPort;
        port powerPort : ElectricalPowerPort;

        action inspect {
            in item workpiece : Workpiece;
            out item result : ProcessResult;
        }
    }

    part def OutputConveyor {
        attribute conveyorSpeed : MillimeterPerSecond;
        attribute acceptedLaneCapacity : Integer;
        attribute rejectedLaneCapacity : Integer;
        attribute currentAcceptedCount : Integer;
        attribute currentRejectedCount : Integer;

        port workpieceInPort : WorkpieceInputPort;
        port powerPort : ElectricalPowerPort;

        action routeAccepted {
            in item workpiece : Workpiece;
        }

        action routeRejected {
            in item workpiece : Workpiece;
        }
    }

    part def PowerDistributionUnit {
        attribute inputVoltage : Volt;
        attribute maximumCurrent : Ampere;
        attribute maximumPower : Watt;

        port robotPowerPort : ElectricalPowerPort;
        port controllerPowerPort : ElectricalPowerPort;
        port toolPowerPort : ElectricalPowerPort;
        port safetyPowerPort : ElectricalPowerPort;
        port stationPowerPort : ElectricalPowerPort;
        port feederPowerPort : ElectricalPowerPort;
        port conveyorPowerPort : ElectricalPowerPort;
        port visionPowerPort : ElectricalPowerPort;
    }

    part def RoboticIndustrialCell {
        attribute cellId : String = "RIC-001";
        attribute nominalCycleTime : Second = 18 [SI::second];
        attribute maximumCycleTime : Second = 24 [SI::second];
        attribute availabilityTarget : Percent = 96.0;
        attribute currentState : CellStateKind;

        part powerDistribution : PowerDistributionUnit {
            attribute inputVoltage = 480 [SI::volt];
            attribute maximumCurrent = 80 [SI::ampere];
            attribute maximumPower = 38000 [SI::watt];
        }

        part controller : RobotController {
            attribute controllerModel = "IRC5-class industrial robot controller";
            attribute servoUpdatePeriod = 0.004 [SI::second];
            attribute programName = "PrimaryTaskCycle";
            attribute targetCycleTime = 18 [SI::second];
        }

        part robot : IndustrialRobot {
            attribute manufacturer = "Generic Industrial Robotics";
            attribute model = "IR-6Axis-20kg-1800";
            attribute degreesOfFreedom = 6;
            attribute maximumReach = 1800 [SI::milli * SI::meter];
            attribute ratedPayload = 20 [SI::kilogram];
            attribute repeatability = 0.05 [SI::milli * SI::meter];
            attribute maximumTcpSpeed = 2.5 [SI::meter / SI::second];
            attribute baseMass = 280 [SI::kilogram];
            attribute installedPower = 5500 [SI::watt];
        }

        part endEffector : EndEffector {
            attribute toolType = "servo gripper with process spindle";
            attribute mass = 8 [SI::kilogram];
            attribute maximumGripForce = 900 [SI::newton];
            attribute minimumGripForce = 150 [SI::newton];
            attribute toolCenterPointOffsetX = 0 [SI::milli * SI::meter];
            attribute toolCenterPointOffsetY = 0 [SI::milli * SI::meter];
            attribute toolCenterPointOffsetZ = 220 [SI::milli * SI::meter];
            attribute processTemperatureLimit = 55 [SI::degreeCelsius];
        }

        part safetyController : SafetyController;

        part feeder : WorkpieceFeeder {
            attribute bufferCapacity = 40;
            attribute currentCount = 24;
            attribute feedRate = 250 [SI::milli * SI::meter / SI::second];
            attribute locatorRepeatability = 0.15 [SI::milli * SI::meter];
        }

        part station : ProcessStation {
            attribute stationName = "Primary Processing Station";
            attribute processForceNominal = 320 [SI::newton];
            attribute processForceMaximum = 500 [SI::newton];
            attribute processSpeedNominal = 65 [SI::milli * SI::meter / SI::second];
            attribute allowedPositionTolerance = 0.25 [SI::milli * SI::meter];
        }

        part vision : VisionInspectionSystem {
            attribute cameraResolutionX = 2448;
            attribute cameraResolutionY = 2048;
            attribute fieldOfViewX = 160 [SI::milli * SI::meter];
            attribute fieldOfViewY = 120 [SI::milli * SI::meter];
            attribute measurementAccuracy = 0.08 [SI::milli * SI::meter];
            attribute inspectionTime = 2.0 [SI::second];
        }

        part outputConveyor : OutputConveyor {
            attribute conveyorSpeed = 180 [SI::milli * SI::meter / SI::second];
            attribute acceptedLaneCapacity = 60;
            attribute rejectedLaneCapacity = 20;
        }

        interface controlNetwork : ControlNetworkInterface
            connect controller.networkPort to robot.controlPort;

        interface toolNetwork : ControlNetworkInterface
            connect controller.networkPort to endEffector.controlPort;

        interface visionNetwork : ControlNetworkInterface
            connect controller.networkPort to vision.networkPort;

        interface robotSafety : SafetyInterface
            connect safetyController.robotSafetyPort to robot.safetyPort;

        interface controllerSafety : SafetyInterface
            connect safetyController.controllerSafetyPort to controller.safetyPort;

        interface feederToStation : WorkpieceTransferInterface
            connect feeder.workpieceOutPort to station.workpieceInPort;

        interface stationToConveyor : WorkpieceTransferInterface
            connect station.workpieceOutPort to outputConveyor.workpieceInPort;

        connect powerDistribution.robotPowerPort to robot.powerPort;
        connect powerDistribution.controllerPowerPort to controller.powerPort;
        connect powerDistribution.toolPowerPort to endEffector.powerPort;
        connect powerDistribution.safetyPowerPort to safetyController.powerPort;
        connect powerDistribution.stationPowerPort to station.powerPort;
        connect powerDistribution.feederPowerPort to feeder.powerPort;
        connect powerDistribution.conveyorPowerPort to outputConveyor.powerPort;
        connect powerDistribution.visionPowerPort to vision.powerPort;

        action primaryCycle {
            in item rawWorkpiece : Workpiece;
            out item finishedWorkpiece : Workpiece;
            out item cycleResult : ProcessResult;

            first start;
            then feed = feeder.indexNextWorkpiece;
            then plan = controller.planCycle;
            then moveToPick = robot.executeMotion;
            then gripPart = endEffector.grip;
            then moveToStation = robot.executeMotion;
            then clamp = station.fixture.clampWorkpiece;
            then process = station.processWorkpiece;
            then inspect = vision.inspect;
            then releaseClamp = station.fixture.releaseWorkpiece;
            then moveToPlace = robot.executeMotion;
            then releasePart = endEffector.release;
            then evaluate = controller.evaluateResult;
            then done;
        }
    }

    requirement def PrimaryTaskPerformanceRequirement {
        subject cell : RoboticIndustrialCell;

        require constraint {
            cell.nominalCycleTime <= 18 [SI::second]
        }

        require constraint {
            cell.maximumCycleTime <= 24 [SI::second]
        }

        require constraint {
            cell.robot.ratedPayload >= cell.endEffector.mass + 6 [SI::kilogram]
        }
    }

    requirement def RobotReachRequirement {
        subject cell : RoboticIndustrialCell;

        require constraint {
            cell.robot.maximumReach >= 1600 [SI::milli * SI::meter]
        }
    }

    requirement def PositionAccuracyRequirement {
        subject cell : RoboticIndustrialCell;

        require constraint {
            cell.robot.repeatability <= 0.08 [SI::milli * SI::meter]
        }

        require constraint {
            cell.station.allowedPositionTolerance <= 0.25 [SI::milli * SI::meter]
        }
    }

    requirement def SafetyRequirement {
        subject cell : RoboticIndustrialCell;

        require constraint {
            cell.safetyController.stopCategory == 1
        }

        require constraint {
            cell.safetyController.lightCurtain.responseTime <= 0.020 [SI::second]
        }
    }

    requirement def QualityInspectionRequirement {
        subject cell : RoboticIndustrialCell;

        require constraint {
            cell.vision.measurementAccuracy <= 0.10 [SI::milli * SI::meter]
        }

        require constraint {
            cell.vision.inspectionTime <= 2.5 [SI::second]
        }
    }

    requirement def PowerCapacityRequirement {
        subject cell : RoboticIndustrialCell;

        require constraint {
            cell.powerDistribution.maximumPower >=
                cell.robot.installedPower + 2500 [SI::watt] + 1200 [SI::watt] + 800 [SI::watt]
        }
    }

    satisfy PrimaryTaskPerformanceRequirement by RoboticIndustrialCell;
    satisfy RobotReachRequirement by RoboticIndustrialCell::robot;
    satisfy PositionAccuracyRequirement by RoboticIndustrialCell;
    satisfy SafetyRequirement by RoboticIndustrialCell::safetyController;
    satisfy QualityInspectionRequirement by RoboticIndustrialCell::vision;
    satisfy PowerCapacityRequirement by RoboticIndustrialCell::powerDistribution;
}
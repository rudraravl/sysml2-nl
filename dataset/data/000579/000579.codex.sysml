package CryolatheSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Temperature :> ISQ::temperature {
        unit = SI::kelvin;
    }

    attribute def Pressure :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def RotationalSpeed :> ISQ::frequency {
        unit = SI::hertz;
    }

    attribute def LinearSpeed :> ISQ::speed {
        unit = SI::metrePerSecond;
    }

    attribute def Length :> ISQ::length {
        unit = SI::metre;
    }

    attribute def Force :> ISQ::force {
        unit = SI::newton;
    }

    attribute def Power :> ISQ::power {
        unit = SI::watt;
    }

    attribute def Time :> ISQ::duration {
        unit = SI::second;
    }

    item def CryogenicFluid {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute massFlowRate : Real;
    }

    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
        attribute availablePower : Power;
    }

    item def ControlSignal {
        attribute commandId : String;
        attribute setpoint : Real;
        attribute issuedTime : Time;
    }

    item def TelemetryData {
        attribute spindleSpeed : RotationalSpeed;
        attribute toolPositionX : Length;
        attribute toolPositionZ : Length;
        attribute workpieceTemperature : Temperature;
        attribute chamberPressure : Pressure;
        attribute vibrationLevel : Real;
        attribute faultCode : String;
    }

    item def RawBlank {
        attribute outsideDiameter : Length;
        attribute length : Length;
        attribute initialTemperature : Temperature;
        attribute materialName : String;
    }

    item def FinishedCryoTurnedPart {
        attribute finalDiameter : Length;
        attribute finalLength : Length;
        attribute surfaceRoughnessRa : Length;
        attribute dimensionalTolerance : Length;
        attribute exitTemperature : Temperature;
    }

    port def ElectricalPowerIn {
        in item power : ElectricalPower;
    }

    port def CryogenicFluidIn {
        in item coolant : CryogenicFluid;
    }

    port def ExhaustOut {
        out item ventedFluid : CryogenicFluid;
    }

    port def WorkpieceIn {
        in item blank : RawBlank;
    }

    port def WorkpieceOut {
        out item part : FinishedCryoTurnedPart;
    }

    port def ControlIn {
        in item command : ControlSignal;
    }

    port def TelemetryOut {
        out item telemetry : TelemetryData;
    }

    part def CryolatheSystem {
        attribute primaryFunction : String = "Precisely machine thermally sensitive or hard-to-cut rotating workpieces while maintaining a controlled cryogenic cutting zone to reduce heat damage, improve dimensional stability, and extend tool life.";

        attribute maximumWorkpieceDiameter : Length = 0.25 [SI::metre];
        attribute maximumWorkpieceLength : Length = 0.75 [SI::metre];
        attribute minimumCuttingZoneTemperature : Temperature = 77.0 [SI::kelvin];
        attribute maximumSpindleSpeed : RotationalSpeed = 100.0 [SI::hertz];
        attribute positioningAccuracy : Length = 0.000005 [SI::metre];

        port electricalInput : ElectricalPowerIn;
        port cryogenInput : CryogenicFluidIn;
        port exhaustOutput : ExhaustOut;
        port rawWorkpieceInput : WorkpieceIn;
        port finishedPartOutput : WorkpieceOut;
        port operatorControlInput : ControlIn;
        port systemTelemetryOutput : TelemetryOut;

        part machineFrame : MachineFrame;
        part spindleDrive : SpindleDrive;
        part chuckAssembly : ChuckAssembly;
        part slideCarriage : PrecisionSlideCarriage;
        part cuttingToolAssembly : CuttingToolAssembly;
        part cryogenicCoolingSubsystem : CryogenicCoolingSubsystem;
        part sealedMachiningChamber : SealedMachiningChamber;
        part sensorSuite : SensorSuite;
        part controller : CryolatheController;
        part safetySubsystem : SafetySubsystem;
        part chipAndCondensateManagement : ChipAndCondensateManagement;

        connect electricalInput.power to controller.powerInput.power;
        connect electricalInput.power to spindleDrive.powerInput.power;
        connect electricalInput.power to slideCarriage.powerInput.power;
        connect cryogenInput.coolant to cryogenicCoolingSubsystem.cryogenSupply.coolant;
        connect cryogenicCoolingSubsystem.nozzleOutlet.coolant to sealedMachiningChamber.coolantIn.coolant;
        connect sealedMachiningChamber.exhaustOut.ventedFluid to exhaustOutput.ventedFluid;
        connect rawWorkpieceInput.blank to chuckAssembly.workpieceReceiver.blank;
        connect chuckAssembly.finishedPartOutlet.part to finishedPartOutput.part;
        connect operatorControlInput.command to controller.operatorCommand.command;
        connect sensorSuite.telemetryOutput.telemetry to controller.telemetryInput.telemetry;
        connect controller.telemetryOutput.telemetry to systemTelemetryOutput.telemetry;
        connect controller.spindleCommand.command to spindleDrive.controlInput.command;
        connect controller.slideCommand.command to slideCarriage.controlInput.command;
        connect controller.coolingCommand.command to cryogenicCoolingSubsystem.controlInput.command;
        connect controller.toolCommand.command to cuttingToolAssembly.controlInput.command;
        connect controller.safetyCommand.command to safetySubsystem.controlInput.command;
        connect safetySubsystem.interlockCommand.command to controller.safetyInput.command;
    }

    part def MachineFrame {
        attribute stiffness : Real = 1.2e8;
        attribute thermalExpansionCoefficient : Real = 0.000010;
        attribute vibrationDampingRatio : Real = 0.18;
    }

    part def SpindleDrive {
        attribute commandedSpeed : RotationalSpeed;
        attribute measuredSpeed : RotationalSpeed;
        attribute maximumTorque : Real = 120.0;
        attribute runout : Length = 0.000002 [SI::metre];

        port powerInput : ElectricalPowerIn;
        port controlInput : ControlIn;
        port speedTelemetry : TelemetryOut;

        action spinWorkpiece {
            in targetSpeed : RotationalSpeed;
            out achievedSpeed : RotationalSpeed;
        }
    }

    part def ChuckAssembly {
        attribute clampForce : Force = 6000.0 [SI::newton];
        attribute jawTemperature : Temperature;
        attribute workpieceLoaded : Boolean;

        port workpieceReceiver : WorkpieceIn;
        port finishedPartOutlet : WorkpieceOut;

        action clampBlank {
            in blank : RawBlank;
            out secure : Boolean;
        }

        action releaseFinishedPart {
            in part : FinishedCryoTurnedPart;
            out released : Boolean;
        }
    }

    part def PrecisionSlideCarriage {
        attribute xPosition : Length;
        attribute zPosition : Length;
        attribute xFeedRate : LinearSpeed;
        attribute zFeedRate : LinearSpeed;
        attribute maximumFeedForce : Force = 2500.0 [SI::newton];

        port powerInput : ElectricalPowerIn;
        port controlInput : ControlIn;
        port positionTelemetry : TelemetryOut;

        part xAxis : LinearAxis;
        part zAxis : LinearAxis;

        action executeToolPath {
            in targetX : Length;
            in targetZ : Length;
            in feedRate : LinearSpeed;
            out finalX : Length;
            out finalZ : Length;
        }
    }

    part def LinearAxis {
        attribute position : Length;
        attribute velocity : LinearSpeed;
        attribute positioningError : Length;
        attribute encoderResolution : Length = 0.000001 [SI::metre];
    }

    part def CuttingToolAssembly {
        attribute insertMaterial : String = "polycrystalline cubic boron nitride";
        attribute toolTipRadius : Length = 0.0004 [SI::metre];
        attribute toolWearLandWidth : Length;
        attribute toolHolderTemperature : Temperature;

        port controlInput : ControlIn;

        action engageCut {
            in depthOfCut : Length;
            in feedRate : LinearSpeed;
            out cuttingForce : Force;
        }

        action retractTool {
            out retracted : Boolean;
        }
    }

    part def CryogenicCoolingSubsystem {
        attribute supplyPressure : Pressure = 700000.0 [SI::pascal];
        attribute nozzleTemperature : Temperature = 90.0 [SI::kelvin];
        attribute coolantFlowRate : Real;
        attribute cooldownTimeLimit : Time = 120.0 [SI::second];

        port cryogenSupply : CryogenicFluidIn;
        port nozzleOutlet : CryogenicFluidIn;
        port controlInput : ControlIn;

        part insulatedTransferLine : InsulatedTransferLine;
        part proportionalValve : CryogenicValve;
        part cuttingZoneNozzle : CryogenicNozzle;
        part returnVent : VentLine;

        action preCoolCuttingZone {
            in targetTemperature : Temperature;
            out achievedTemperature : Temperature;
        }

        action regulateCryogenFlow {
            in targetFlowRate : Real;
            out actualFlowRate : Real;
        }

        action purgeLine {
            out lineClear : Boolean;
        }
    }

    part def InsulatedTransferLine {
        attribute heatLeak : Power = 12.0 [SI::watt];
        attribute internalPressure : Pressure;
    }

    part def CryogenicValve {
        attribute openingFraction : Real;
        attribute responseTime : Time = 0.15 [SI::second];
    }

    part def CryogenicNozzle {
        attribute sprayAngle : Real = 28.0;
        attribute standoffDistance : Length = 0.018 [SI::metre];
        attribute outletDiameter : Length = 0.0015 [SI::metre];
    }

    part def VentLine {
        attribute ventPressure : Pressure;
        attribute oxygenDisplacementRisk : Boolean;
    }

    part def SealedMachiningChamber {
        attribute chamberPressure : Pressure;
        attribute doorClosed : Boolean;
        attribute visibilityWindowTemperature : Temperature;
        attribute internalOxygenConcentration : Real;

        port coolantIn : CryogenicFluidIn;
        port exhaustOut : ExhaustOut;

        action containMachiningProcess {
            in doorClosed : Boolean;
            out containmentActive : Boolean;
        }

        action evacuateCryogenicVapor {
            in vapor : CryogenicFluid;
            out vented : CryogenicFluid;
        }
    }

    part def SensorSuite {
        attribute sampledSpindleSpeed : RotationalSpeed;
        attribute sampledWorkpieceTemperature : Temperature;
        attribute sampledChamberPressure : Pressure;
        attribute sampledOxygenConcentration : Real;
        attribute sampledToolWear : Length;

        port telemetryOutput : TelemetryOut;

        part spindleEncoder : SpindleEncoder;
        part infraredPyrometer : InfraredPyrometer;
        part pressureTransducer : PressureTransducer;
        part oxygenSensor : OxygenSensor;
        part vibrationSensor : VibrationSensor;
        part toolWearSensor : ToolWearSensor;

        action sampleProcessState {
            out telemetry : TelemetryData;
        }
    }

    part def SpindleEncoder {
        attribute resolution : Real = 4096.0;
    }

    part def InfraredPyrometer {
        attribute measurementRangeLow : Temperature = 70.0 [SI::kelvin];
        attribute measurementRangeHigh : Temperature = 500.0 [SI::kelvin];
        attribute accuracy : Temperature = 2.0 [SI::kelvin];
    }

    part def PressureTransducer {
        attribute pressureRangeHigh : Pressure = 1000000.0 [SI::pascal];
    }

    part def OxygenSensor {
        attribute alarmThreshold : Real = 19.5;
    }

    part def VibrationSensor {
        attribute maximumAllowedVibration : Real = 4.5;
    }

    part def ToolWearSensor {
        attribute wearAlarmLimit : Length = 0.00025 [SI::metre];
    }

    part def CryolatheController {
        attribute currentMode : String;
        attribute targetSpindleSpeed : RotationalSpeed;
        attribute targetCuttingZoneTemperature : Temperature = 110.0 [SI::kelvin];
        attribute commandedFeedRate : LinearSpeed;
        attribute emergencyStopActive : Boolean;

        port powerInput : ElectricalPowerIn;
        port operatorCommand : ControlIn;
        port telemetryInput : TelemetryOut;
        port telemetryOutput : TelemetryOut;
        port spindleCommand : ControlIn;
        port slideCommand : ControlIn;
        port coolingCommand : ControlIn;
        port toolCommand : ControlIn;
        port safetyCommand : ControlIn;
        port safetyInput : ControlIn;

        action planCryogenicTurningCycle {
            in blank : RawBlank;
            in requestedFinalDiameter : Length;
            in requestedFinalLength : Length;
            out targetSpeed : RotationalSpeed;
            out targetFeedRate : LinearSpeed;
            out targetTemperature : Temperature;
        }

        action commandMachiningCycle {
            in targetSpeed : RotationalSpeed;
            in targetFeedRate : LinearSpeed;
            in targetTemperature : Temperature;
            out cycleStarted : Boolean;
        }

        action evaluateFaults {
            in telemetry : TelemetryData;
            out shutdownRequired : Boolean;
            out faultCode : String;
        }

        state def OperatingStateMachine {
            state off;
            state initializing;
            state ready;
            state loadingWorkpiece;
            state preCooling;
            state machining;
            state finishingPass;
            state warmingAndPurge;
            state unloading;
            state faulted;
            state emergencyStopped;

            transition first off then initializing;
            transition initializing then ready
                if initializationComplete;
            transition ready then loadingWorkpiece
                accept startLoadCommand;
            transition loadingWorkpiece then preCooling
                if workpieceClamped and doorClosed;
            transition preCooling then machining
                if cuttingZoneTemperature <= targetCuttingZoneTemperature;
            transition machining then finishingPass
                if roughingPathComplete;
            transition finishingPass then warmingAndPurge
                if finalDimensionReached;
            transition warmingAndPurge then unloading
                if chamberSafeForOpening;
            transition unloading then ready
                if finishedPartRemoved;
            transition ready then emergencyStopped
                accept emergencyStopCommand;
            transition loadingWorkpiece then emergencyStopped
                accept emergencyStopCommand;
            transition preCooling then emergencyStopped
                accept emergencyStopCommand;
            transition machining then emergencyStopped
                accept emergencyStopCommand;
            transition finishingPass then emergencyStopped
                accept emergencyStopCommand;
            transition warmingAndPurge then emergencyStopped
                accept emergencyStopCommand;
            transition initializing then faulted
                if initializationFaultDetected;
            transition preCooling then faulted
                if cryogenPressureLow or oxygenConcentrationLow;
            transition machining then faulted
                if excessiveVibration or toolWearExceeded or temperatureOutOfRange;
            transition faulted then ready
                accept faultResetCommand
                if faultCleared;
            transition emergencyStopped then ready
                accept resetCommand
                if emergencyStopReleased and chamberSafeForOpening;
        }

        exhibit stateMachine : OperatingStateMachine;
    }

    part def SafetySubsystem {
        attribute guardDoorLocked : Boolean;
        attribute oxygenSafe : Boolean;
        attribute overPressureSafe : Boolean;
        attribute emergencyStopHealthy : Boolean;
        attribute safeToMachine : Boolean;

        port controlInput : ControlIn;
        port interlockCommand : ControlIn;

        action enforceInterlocks {
            in doorClosed : Boolean;
            in oxygenConcentration : Real;
            in chamberPressure : Pressure;
            in emergencyStopActive : Boolean;
            out machiningPermitted : Boolean;
        }

        action executeEmergencyStop {
            out spindlePowerRemoved : Boolean;
            out cryogenValveClosed : Boolean;
            out slideMotionStopped : Boolean;
        }
    }

    part def ChipAndCondensateManagement {
        attribute chipBinFillLevel : Real;
        attribute condensateDrainTemperature : Temperature;
        attribute frostAccumulation : Length;

        action collectCryogenicChips {
            out collectionStable : Boolean;
        }

        action drainCondensate {
            out drainClear : Boolean;
        }
    }

    action def CryogenicTurningProcess {
        in blank : RawBlank;
        in finalDiameter : Length;
        in finalLength : Length;
        out finishedPart : FinishedCryoTurnedPart;

        first start;
        then loadAndClamp;
        then closeAndVerifyChamber;
        then preCoolWorkpieceAndTool;
        then spinWorkpiece;
        then roughTurn;
        then finishTurn;
        then stopSpindle;
        then purgeAndWarmChamber;
        then releasePart;
        then done;

        action start;
        action loadAndClamp;
        action closeAndVerifyChamber;
        action preCoolWorkpieceAndTool;
        action spinWorkpiece;
        action roughTurn;
        action finishTurn;
        action stopSpindle;
        action purgeAndWarmChamber;
        action releasePart;
        action done;
    }

    requirement def PrimaryFunctionRequirement {
        subject cryolathe : CryolatheSystem;
        doc /* The Cryolathe System shall perform precision turning of rotating workpieces while applying controlled cryogenic cooling at the cutting zone to maintain part integrity, reduce thermal distortion, and produce a finished part within commanded dimensional tolerance. */
        require constraint {
            cryolathe.minimumCuttingZoneTemperature <= 120.0 [SI::kelvin]
        }
    }

    requirement def WorkpieceCapacityRequirement {
        subject cryolathe : CryolatheSystem;
        doc /* The Cryolathe System shall accept cylindrical raw blanks up to 0.25 m diameter and 0.75 m length. */
        require constraint {
            cryolathe.maximumWorkpieceDiameter >= 0.25 [SI::metre] and
            cryolathe.maximumWorkpieceLength >= 0.75 [SI::metre]
        }
    }

    requirement def CryogenicControlRequirement {
        subject cooling : CryogenicCoolingSubsystem;
        doc /* The cooling subsystem shall regulate cryogenic fluid delivery to achieve the commanded cutting zone temperature before machining begins and maintain it during cutting. */
        require constraint {
            cooling.nozzleTemperature <= 110.0 [SI::kelvin] and
            cooling.supplyPressure >= 500000.0 [SI::pascal]
        }
    }

    requirement def PrecisionRequirement {
        subject cryolathe : CryolatheSystem;
        doc /* The Cryolathe System shall position the cutting tool with accuracy sufficient to produce finished parts within a 10 micrometre dimensional tolerance. */
        require constraint {
            cryolathe.positioningAccuracy <= 0.000005 [SI::metre]
        }
    }

    requirement def SafetyRequirement {
        subject safety : SafetySubsystem;
        doc /* The Cryolathe System shall prevent spindle rotation and slide motion unless the chamber is closed, oxygen concentration is safe, chamber pressure is within limit, and emergency stop is released. */
        require constraint {
            safety.safeToMachine == safety.guardDoorLocked and safety.oxygenSafe and safety.overPressureSafe and safety.emergencyStopHealthy
        }
    }

    requirement def TelemetryRequirement {
        subject sensors : SensorSuite;
        doc /* The Cryolathe System shall provide telemetry for spindle speed, tool position, chamber pressure, workpiece temperature, vibration level, and fault status during all active operating states. */
    }

    requirement def EmergencyStopRequirement {
        subject safety : SafetySubsystem;
        doc /* Upon emergency stop activation, the Cryolathe System shall remove spindle drive power, stop slide motion, and close the cryogenic supply valve. */
    }

    satisfy PrimaryFunctionRequirement by CryolatheSystem;
    satisfy WorkpieceCapacityRequirement by CryolatheSystem;
    satisfy CryogenicControlRequirement by CryogenicCoolingSubsystem;
    satisfy PrecisionRequirement by CryolatheSystem;
    satisfy SafetyRequirement by SafetySubsystem;
    satisfy TelemetryRequirement by SensorSuite;
    satisfy EmergencyStopRequirement by SafetySubsystem;

    part cryolathe : CryolatheSystem;

    perform action CryogenicTurningProcess by cryolathe;

}
package DrumPumpSubsystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure :> scalarValues::Real {
        unit = "Pa";
    }

    attribute def FlowRate :> scalarValues::Real {
        unit = "m^3/s";
    }

    attribute def Volume :> scalarValues::Real {
        unit = "m^3";
    }

    attribute def Temperature :> scalarValues::Real {
        unit = "K";
    }

    attribute def RotationalSpeed :> scalarValues::Real {
        unit = "rpm";
    }

    attribute def Voltage :> scalarValues::Real {
        unit = "V";
    }

    attribute def Current :> scalarValues::Real {
        unit = "A";
    }

    attribute def Power :> scalarValues::Real {
        unit = "W";
    }

    attribute def Length :> scalarValues::Real {
        unit = "m";
    }

    attribute def Efficiency :> scalarValues::Real {
        unit = "1";
    }

    attribute def TimeDuration :> scalarValues::Real {
        unit = "s";
    }

    attribute def Concentration :> scalarValues::Real {
        unit = "kg/m^3";
    }

    enum def PumpOperatingMode {
        enum idle;
        enum priming;
        enum pumping;
        enum draining;
        enum faulted;
        enum maintenance;
    }

    enum def FluidKind {
        enum water;
        enum detergent;
        enum glycolSolution;
        enum lightOil;
        enum processChemical;
    }

    enum def ValvePosition {
        enum closed;
        enum open;
        enum throttled;
    }

    enum def FaultKind {
        enum noFault;
        enum lowDrumLevel;
        enum dryRunDetected;
        enum blockedDischarge;
        enum motorOvercurrent;
        enum leakDetected;
        enum emergencyStop;
        enum thermalTrip;
    }

    item def Fluid {
        attribute kind : FluidKind;
        attribute density : Concentration;
        attribute dynamicViscosity : scalarValues::Real {
            unit = "Pa*s";
        }
        attribute temperature : Temperature;
        attribute vaporPressure : Pressure;
        attribute contaminationLimit : Concentration;
    }

    item def ElectricalEnergy {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
        attribute frequency : scalarValues::Real {
            unit = "Hz";
        }
    }

    item def ControlSignal {
        attribute commandStart : Boolean;
        attribute commandStop : Boolean;
        attribute commandPrime : Boolean;
        attribute commandDrain : Boolean;
        attribute emergencyStop : Boolean;
        attribute targetFlowRate : FlowRate;
    }

    item def StatusSignal {
        attribute mode : PumpOperatingMode;
        attribute activeFault : FaultKind;
        attribute measuredFlowRate : FlowRate;
        attribute suctionPressure : Pressure;
        attribute dischargePressure : Pressure;
        attribute drumLevel : Volume;
        attribute motorCurrent : Current;
        attribute leakPresent : Boolean;
        attribute ready : Boolean;
    }

    port def FluidInletPort {
        in item incomingFluid : Fluid;
        attribute staticPressure : Pressure;
        attribute availableFlowRate : FlowRate;
    }

    port def FluidOutletPort {
        out item outgoingFluid : Fluid;
        attribute staticPressure : Pressure;
        attribute deliveredFlowRate : FlowRate;
    }

    port def ElectricalPowerPort {
        in item supply : ElectricalEnergy;
    }

    port def ControlInputPort {
        in item control : ControlSignal;
    }

    port def StatusOutputPort {
        out item status : StatusSignal;
    }

    port def DrainPort {
        out item drainedFluid : Fluid;
        attribute drainedFlowRate : FlowRate;
    }

    interface def FluidTransferInterface {
        end source : FluidOutletPort;
        end sink : FluidInletPort;
        flow item transferredFluid : Fluid from source to sink;
    }

    interface def PowerSupplyInterface {
        end supplySide : ElectricalPowerPort;
        end loadSide : ElectricalPowerPort;
        flow item suppliedPower : ElectricalEnergy from supplySide to loadSide;
    }

    interface def ControlInterface {
        end controllerSide : ControlInputPort;
        end equipmentSide : ControlInputPort;
        flow item command : ControlSignal from controllerSide to equipmentSide;
    }

    interface def StatusInterface {
        end equipmentSide : StatusOutputPort;
        end controllerSide : StatusOutputPort;
        flow item telemetry : StatusSignal from equipmentSide to controllerSide;
    }

    part def Drum {
        attribute totalCapacity : Volume = 0.208;
        attribute usableVolume : Volume = 0.200;
        attribute currentVolume : Volume;
        attribute minimumSafeVolume : Volume = 0.010;
        attribute vented : Boolean = true;
        attribute compatibleFluidKind : FluidKind = FluidKind::processChemical;

        port outlet : FluidOutletPort;
    }

    part def DrumPump {
        attribute mode : PumpOperatingMode = PumpOperatingMode::idle;
        attribute maximumFlowRate : FlowRate = 0.0012;
        attribute minimumContinuousFlowRate : FlowRate = 0.00015;
        attribute nominalFlowRate : FlowRate = 0.00075;
        attribute maximumDischargePressure : Pressure = 350000.0;
        attribute minimumNpshRequired : Pressure = 12000.0;
        attribute suctionTubeLength : Length = 1.05;
        attribute impellerSpeed : RotationalSpeed;
        attribute hydraulicEfficiency : Efficiency = 0.58;
        attribute dryRunTimeout : TimeDuration = 4.0;
        attribute primingTimeout : TimeDuration = 15.0;
        attribute sealLeakRateLimit : FlowRate = 0.000001;
        attribute activeFault : FaultKind = FaultKind::noFault;

        port suction : FluidInletPort;
        port discharge : FluidOutletPort;
        port power : ElectricalPowerPort;
        port control : ControlInputPort;
        port status : StatusOutputPort;
        port drain : DrainPort;

        part motor {
            attribute ratedVoltage : Voltage = 120.0;
            attribute ratedCurrent : Current = 6.5;
            attribute ratedPower : Power = 560.0;
            attribute measuredCurrent : Current;
            attribute windingTemperature : Temperature;
            attribute thermalTripTemperature : Temperature = 393.15;
            attribute running : Boolean = false;
        }

        part pumpTube {
            attribute immersedLength : Length = 0.98;
            attribute internalDiameter : Length = 0.032;
            attribute materialCompatible : Boolean = true;
        }

        part impeller {
            attribute commandedSpeed : RotationalSpeed;
            attribute actualSpeed : RotationalSpeed;
            attribute diameter : Length = 0.045;
        }

        part sealAssembly {
            attribute leakageDetected : Boolean = false;
            attribute measuredLeakRate : FlowRate;
        }

        action def PrimePump {
            in item fluidAtSuction : Fluid;
            out item primedFluid : Fluid;
            attribute elapsedTime : TimeDuration;
            attribute successful : Boolean;

            first startPriming;
            then fillPumpTube;
            then verifyContinuousFlow;
            then done;

            action startPriming;
            action fillPumpTube;
            action verifyContinuousFlow;
            action done;
        }

        action def TransferFluid {
            in item inletFluid : Fluid;
            out item outletFluid : Fluid;
            attribute requestedFlowRate : FlowRate;
            attribute actualFlowRate : FlowRate;
            attribute pressureRise : Pressure;

            first accelerateMotor;
            then establishFlow;
            then regulateFlow;
            then dischargeFluid;

            action accelerateMotor;
            action establishFlow;
            action regulateFlow;
            action dischargeFluid;
        }

        action def StopPump {
            first rampDown;
            then closeDischarge;
            then publishStoppedStatus;

            action rampDown;
            action closeDischarge;
            action publishStoppedStatus;
        }

        action def DetectFaults {
            in item telemetry : StatusSignal;
            out attribute detectedFault : FaultKind;

            first readSensors;
            then evaluateDryRun;
            then evaluateBlockage;
            then evaluateElectricalTrip;
            then evaluateLeak;
            then reportFault;

            action readSensors;
            action evaluateDryRun;
            action evaluateBlockage;
            action evaluateElectricalTrip;
            action evaluateLeak;
            action reportFault;
        }

        state def DrumPumpStateMachine {
            state idle;
            state priming;
            state pumping;
            state draining;
            state faulted;
            state maintenance;

            initial then idle;

            transition idle_to_priming
                first idle
                accept ControlSignal
                if control.commandPrime and not control.emergencyStop
                then priming;

            transition idle_to_pumping
                first idle
                accept ControlSignal
                if control.commandStart and not control.emergencyStop
                then pumping;

            transition priming_to_pumping
                first priming
                if status.status.measuredFlowRate >= minimumContinuousFlowRate
                then pumping;

            transition priming_to_faulted
                first priming
                if activeFault == FaultKind::dryRunDetected or activeFault == FaultKind::lowDrumLevel
                then faulted;

            transition pumping_to_idle
                first pumping
                accept ControlSignal
                if control.commandStop
                then idle;

            transition pumping_to_draining
                first pumping
                accept ControlSignal
                if control.commandDrain
                then draining;

            transition pumping_to_faulted
                first pumping
                if activeFault != FaultKind::noFault
                then faulted;

            transition draining_to_idle
                first draining
                if status.status.measuredFlowRate < minimumContinuousFlowRate
                then idle;

            transition any_to_faulted
                first idle
                accept ControlSignal
                if control.emergencyStop
                then faulted;

            transition faulted_to_maintenance
                first faulted
                if activeFault != FaultKind::emergencyStop
                then maintenance;

            transition maintenance_to_idle
                first maintenance
                if activeFault == FaultKind::noFault
                then idle;
        }

        perform action prime : PrimePump;
        perform action transfer : TransferFluid;
        perform action stop : StopPump;
        perform action faultDetection : DetectFaults;
        exhibit state machine : DrumPumpStateMachine;
    }

    part def SuctionStrainer {
        attribute meshOpening : Length = 0.0015;
        attribute cleanPressureDrop : Pressure = 1500.0;
        attribute cloggedPressureDropLimit : Pressure = 10000.0;
        attribute clogged : Boolean = false;

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
    }

    part def DischargeHose {
        attribute length : Length = 3.0;
        attribute innerDiameter : Length = 0.025;
        attribute maximumWorkingPressure : Pressure = 500000.0;
        attribute burstPressure : Pressure = 1500000.0;
        attribute groundedForStatic : Boolean = true;

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
    }

    part def CheckValve {
        attribute crackingPressure : Pressure = 5000.0;
        attribute position : ValvePosition = ValvePosition::closed;
        attribute backflowPrevented : Boolean = true;

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
    }

    part def IsolationValve {
        attribute position : ValvePosition = ValvePosition::open;
        attribute maximumWorkingPressure : Pressure = 600000.0;

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
    }

    part def FlowMeter {
        attribute measuredFlowRate : FlowRate;
        attribute accuracyPercent : scalarValues::Real = 1.5;
        attribute minimumReadableFlowRate : FlowRate = 0.00005;
        attribute maximumReadableFlowRate : FlowRate = 0.0015;

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        port status : StatusOutputPort;
    }

    part def PressureSensor {
        attribute measuredPressure : Pressure;
        attribute rangeMinimum : Pressure = 0.0;
        attribute rangeMaximum : Pressure = 600000.0;
        attribute accuracyPercentFullScale : scalarValues::Real = 1.0;

        port process : FluidInletPort;
        port status : StatusOutputPort;
    }

    part def LevelSensor {
        attribute measuredVolume : Volume;
        attribute lowLevelAlarmSetpoint : Volume = 0.015;
        attribute emptyShutdownSetpoint : Volume = 0.008;

        port status : StatusOutputPort;
    }

    part def LeakSensor {
        attribute leakDetected : Boolean = false;
        attribute responseTime : TimeDuration = 2.0;

        port status : StatusOutputPort;
    }

    part def LocalController {
        attribute commandedFlowRate : FlowRate = 0.00075;
        attribute startPermitted : Boolean;
        attribute stopRequested : Boolean;
        attribute faultResetRequested : Boolean;

        port commandOut : ControlInputPort;
        port pumpStatusIn : StatusOutputPort;
        port flowStatusIn : StatusOutputPort;
        port pressureStatusIn : StatusOutputPort;
        port levelStatusIn : StatusOutputPort;
        port leakStatusIn : StatusOutputPort;
        port systemStatusOut : StatusOutputPort;

        action def RegulatePump {
            in item pumpTelemetry : StatusSignal;
            out item command : ControlSignal;
            attribute flowError : FlowRate;

            first sampleTelemetry;
            then calculateFlowError;
            then issueCommand;

            action sampleTelemetry;
            action calculateFlowError;
            action issueCommand;
        }

        action def InterlockEvaluation {
            in item pumpTelemetry : StatusSignal;
            out attribute permitted : Boolean;

            first checkLevel;
            then checkPressure;
            then checkLeak;
            then checkEmergencyStop;
            then setPermit;

            action checkLevel;
            action checkPressure;
            action checkLeak;
            action checkEmergencyStop;
            action setPermit;
        }

        perform action regulate : RegulatePump;
        perform action interlocks : InterlockEvaluation;
    }

    part def PowerSupply {
        attribute nominalVoltage : Voltage = 120.0;
        attribute maximumCurrent : Current = 10.0;
        attribute groundFaultProtected : Boolean = true;
        attribute disconnectAvailable : Boolean = true;

        port output : ElectricalPowerPort;
    }

    part def ReceivingTank {
        attribute capacity : Volume = 1.0;
        attribute currentVolume : Volume;
        attribute maximumFillVolume : Volume = 0.95;
        attribute vented : Boolean = true;

        port inlet : FluidInletPort;
    }

    part def PumpingSubsystem {
        attribute designFlowRate : FlowRate = 0.00075;
        attribute maximumAllowedDischargePressure : Pressure = 350000.0;
        attribute minimumDrumOperatingVolume : Volume = 0.010;
        attribute normalFluidKind : FluidKind = FluidKind::processChemical;

        part sourceDrum : Drum {
            attribute currentVolume = 0.160;
        }

        part suctionStrainer : SuctionStrainer;
        part drumPump : DrumPump;
        part checkValve : CheckValve;
        part isolationValve : IsolationValve;
        part dischargeHose : DischargeHose;
        part receivingTank : ReceivingTank;
        part flowMeter : FlowMeter;
        part suctionPressureSensor : PressureSensor;
        part dischargePressureSensor : PressureSensor;
        part levelSensor : LevelSensor;
        part leakSensor : LeakSensor;
        part controller : LocalController;
        part powerSupply : PowerSupply;

        connect sourceDrum.outlet to suctionStrainer.inlet;
        connect suctionStrainer.outlet to drumPump.suction;
        connect drumPump.discharge to checkValve.inlet;
        connect checkValve.outlet to isolationValve.inlet;
        connect isolationValve.outlet to flowMeter.inlet;
        connect flowMeter.outlet to dischargeHose.inlet;
        connect dischargeHose.outlet to receivingTank.inlet;

        connect powerSupply.output to drumPump.power;
        connect controller.commandOut to drumPump.control;
        connect drumPump.status to controller.pumpStatusIn;
        connect flowMeter.status to controller.flowStatusIn;
        connect suctionPressureSensor.status to controller.pressureStatusIn;
        connect dischargePressureSensor.status to controller.pressureStatusIn;
        connect levelSensor.status to controller.levelStatusIn;
        connect leakSensor.status to controller.leakStatusIn;

        connect suctionPressureSensor.process to drumPump.suction;
        connect dischargePressureSensor.process to drumPump.discharge;

        constraint flowCapacityConstraint {
            designFlowRate <= drumPump.maximumFlowRate;
            designFlowRate >= drumPump.minimumContinuousFlowRate;
        }

        constraint pressureProtectionConstraint {
            drumPump.maximumDischargePressure <= maximumAllowedDischargePressure;
            dischargeHose.maximumWorkingPressure > maximumAllowedDischargePressure;
            isolationValve.maximumWorkingPressure > maximumAllowedDischargePressure;
        }

        constraint levelProtectionConstraint {
            sourceDrum.currentVolume >= minimumDrumOperatingVolume implies controller.startPermitted == true;
            sourceDrum.currentVolume < minimumDrumOperatingVolume implies drumPump.activeFault == FaultKind::lowDrumLevel;
        }

        constraint compatibilityConstraint {
            sourceDrum.compatibleFluidKind == normalFluidKind;
            drumPump.pumpTube.materialCompatible == true;
        }

        action def StartTransferSequence {
            first verifyPowerAvailable;
            then verifyDischargePathOpen;
            then verifyDrumLevel;
            then primePump;
            then rampToDesignFlow;
            then monitorTransfer;

            action verifyPowerAvailable;
            action verifyDischargePathOpen;
            action verifyDrumLevel;
            action primePump;
            action rampToDesignFlow;
            action monitorTransfer;
        }

        action def NormalShutdownSequence {
            first commandStop;
            then confirmNoFlow;
            then isolateDischarge;
            then reportBatchComplete;

            action commandStop;
            action confirmNoFlow;
            action isolateDischarge;
            action reportBatchComplete;
        }

        action def EmergencyShutdownSequence {
            first removeMotorPower;
            then closeIsolationValve;
            then latchFault;
            then notifyOperator;

            action removeMotorPower;
            action closeIsolationValve;
            action latchFault;
            action notifyOperator;
        }

        perform action startTransfer : StartTransferSequence;
        perform action normalShutdown : NormalShutdownSequence;
        perform action emergencyShutdown : EmergencyShutdownSequence;
    }

    requirement def MoveFluidUsingDrumPumpRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.drumPump.maximumFlowRate >= subsystem.designFlowRate;
        }

        require constraint {
            subsystem.sourceDrum.currentVolume >= subsystem.minimumDrumOperatingVolume;
        }

        require constraint {
            subsystem.drumPump.maximumDischargePressure <= subsystem.maximumAllowedDischargePressure;
        }
    }

    requirement def DryRunProtectionRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.drumPump.activeFault == FaultKind::dryRunDetected implies subsystem.drumPump.motor.running == false;
        }

        require constraint {
            subsystem.levelSensor.emptyShutdownSetpoint < subsystem.levelSensor.lowLevelAlarmSetpoint;
        }
    }

    requirement def BackflowPreventionRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.checkValve.backflowPrevented == true;
        }
    }

    requirement def LeakDetectionRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.leakSensor.responseTime <= 2.0;
        }

        require constraint {
            subsystem.leakSensor.leakDetected == true implies subsystem.drumPump.activeFault == FaultKind::leakDetected;
        }
    }

    requirement def ElectricalSafetyRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.powerSupply.groundFaultProtected == true;
        }

        require constraint {
            subsystem.powerSupply.maximumCurrent >= subsystem.drumPump.motor.ratedCurrent;
        }
    }

    requirement def HosePressureRatingRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.dischargeHose.maximumWorkingPressure >= 1.25 * subsystem.maximumAllowedDischargePressure;
        }
    }

    requirement def OperatorControlRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.controller.commandedFlowRate <= subsystem.drumPump.maximumFlowRate;
        }

        require constraint {
            subsystem.controller.commandedFlowRate >= subsystem.drumPump.minimumContinuousFlowRate;
        }
    }

    part pumpingSubsystem : PumpingSubsystem;

    satisfy MoveFluidUsingDrumPumpRequirement by pumpingSubsystem;
    satisfy DryRunProtectionRequirement by pumpingSubsystem;
    satisfy BackflowPreventionRequirement by pumpingSubsystem;
    satisfy LeakDetectionRequirement by pumpingSubsystem;
    satisfy ElectricalSafetyRequirement by pumpingSubsystem;
    satisfy HosePressureRatingRequirement by pumpingSubsystem;
    satisfy OperatorControlRequirement by pumpingSubsystem;
}
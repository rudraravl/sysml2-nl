package MedradContrastInjectionSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====
    value type PressureValue :> Real { attribute unit : String = "psi"; }
    value type FlowRateValue :> Real { attribute unit : String = "mL/s"; }
    value type VolumeValue :> Real { attribute unit : String = "mL"; }
    value type DurationValue :> Real { attribute unit : String = "s"; }
    value type RotationalSpeedValue :> Real { attribute unit : String = "rev/s"; }
    value type ForceValue :> Real { attribute unit : String = "N"; }
    value type MassFractionValue :> Real { attribute unit : String = "1"; }
    value type TemperatureValue :> Real { attribute unit : String = "degC"; }
    value type VoltageValue :> Real { attribute unit : String = "V"; }
    value type CurrentValue :> Real { attribute unit : String = "A"; }

    // ===== Items =====
    item def ContrastMedia {
        attribute concentration : MassFractionValue;
        attribute viscosity : Real;
        attribute iodineContent : MassFractionValue;
    }
    item def Saline {
        attribute concentration : MassFractionValue = 0.009;
    }
    item def Fluid :> Choice[ContrastMedia, Saline];
    item def Air;

    item def CommandSignal {
        attribute commandType : String;
        attribute value : Real;
    }
    item def FeedbackSignal {
        attribute feedbackType : String;
        attribute value : Real;
    }
    item def AlarmSignal {
        attribute severity : String;
        attribute reason : String;
    }
    item def EmergencyStopSignal {
        attribute reason : String;
        attribute timestamp : DurationValue;
    }
    item def ProtocolData {
        attribute phases : Integer;
        attribute totalVolume : VolumeValue;
    }
    item def ProtocolPhase {
        attribute flowRate : FlowRateValue;
        attribute volume : VolumeValue;
        attribute duration : DurationValue;
        attribute fluidType : String;
    }
    item def TelemetryData {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute volumeDelivered : VolumeValue;
        attribute elapsed : DurationValue;
        attribute phaseNumber : Integer;
    }
    item def SensorReading {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute volumeDelivered : VolumeValue;
        attribute timestamp : DurationValue;
    }
    item def InjectionLog {
        attribute protocol : ProtocolData;
        attribute deliveredVolumes : VolumeValue[*];
        attribute peakPressure : PressureValue;
        attribute averageFlowRate : FlowRateValue;
        attribute totalDuration : DurationValue;
        attribute patientId : String;
        attribute operatorId : String;
        attribute startTime : String;
        attribute endTime : String;
    }

    // ===== Attributes =====
    attribute def SafetyLimits {
        attribute maxPressure : PressureValue;
        attribute maxFlowRate : FlowRateValue;
        attribute maxVolume : VolumeValue;
        attribute minPressure : PressureValue;
    }

    attribute def AlarmStatus {
        attribute active : Boolean;
        attribute severity : String;
        attribute reason : String;
    }

    // ===== Ports =====
    port def FluidOutPort {
        out item fluid : Fluid;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }
    port def FluidInPort {
        in item fluid : Fluid;
        attribute pressure : PressureValue;
    }
    port def CommandPort {
        in command : CommandSignal;
        out feedback : FeedbackSignal;
    }
    port def TelemetryPort {
        out telemetry : TelemetryData;
        in limits : SafetyLimits;
    }
    port def SafetyPort {
        in readings : SensorReading;
        in limits : SafetyLimits;
        out alarm : AlarmSignal;
        out emergencyStop : EmergencyStopSignal;
        out haltCommand : CommandSignal;
    }
    port def PatientPort {
        out item fluid : Fluid;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute volumeDelivered : VolumeValue;
    }
    port def PowerPort {
        in voltage : VoltageValue;
        in current : CurrentValue;
    }

    // ===== Events =====
    event def PowerOn;
    event def PowerOff;
    event def LoadSyringes;
    event def StartPriming;
    event def PrimingComplete;
    event def ArmSystem;
    event def StartInjection;
    event def PauseInjection;
    event def ResumeInjection;
    event def ProtocolComplete;
    event def FaultDetected;
    event def EmergencyStopTriggered;
    event def FaultCleared;
    event def SystemReset;
    event def ResetCommand;

    // ===== Requirements =====
    requirement def DualHeadInjectionRequirement {
        doc { The system shall use a dual-head configuration with one syringe for contrast media and one for saline. }
        attribute requiredHeads : Integer = 2;
    }

    requirement def FlowControlRequirement {
        doc { Each injector head shall precisely control plunger movement to deliver exact flow rates and volumes. }
        attribute flowRateAccuracy : Real = 0.02;
        attribute volumeAccuracy : Real = 0.02;
        attribute maxFlowRate : FlowRateValue = 10 [mL/s];
    }

    requirement def PressureJacketRequirement {
        doc { Each syringe shall be housed in a reinforced pressure jacket rated for the maximum injection pressure. }
        attribute minJacketRating : PressureValue = 1200 [psi];
    }

    requirement def ProtocolProgrammingRequirement {
        doc { The operator console shall allow programming of multi-phase injection protocols with specified flow rates, volumes, and durations. }
        attribute minPhases : Integer = 1;
        attribute maxPhases : Integer = 16;
    }

    requirement def RealTimeDisplayRequirement {
        doc { The console shall provide real-time display of pressure, flow rate, and delivered volume. }
        attribute refreshInterval : DurationValue = 0.1 [s];
    }

    requirement def SensorMonitoringRequirement {
        doc { Integrated sensors shall continuously monitor fluid pressure, flow rate, and injected volume. }
        attribute sampleRate : DurationValue = 0.01 [s];
    }

    requirement def SafetyInterlockRequirement {
        doc { The safety interlock system shall compare real-time sensor values against pre-set limits and trigger alarm, pause, or emergency stop. }
        attribute maxResponseTime : DurationValue = 0.2 [s];
    }

    requirement def PrimingRequirement {
        doc { The system shall perform a priming sequence to purge all air from fluid lines before injection. }
    }

    requirement def EmergencyStopRequirement {
        doc { The system shall support emergency stop conditions with predictable behavior ensuring patient safety. }
    }

    requirement def LoggingRequirement {
        doc { The system shall log all injection data upon successful completion of the protocol. }
    }

    requirement def StateBehaviorRequirement {
        doc { The system shall operate through the states: powerOff, idle, loading, priming, armed, injecting, paused, completed, fault, and emergencyStop. }
    }

    // ===== Constraints =====
    constraint def WithinPressureLimit {
        in pressure : PressureValue;
        in limit : PressureValue;
        constraint pressure <= limit;
    }

    constraint def WithinFlowRateLimit {
        in flow : FlowRateValue;
        in limit : FlowRateValue;
        constraint flow <= limit;
    }

    constraint def WithinVolumeLimit {
        in volume : VolumeValue;
        in limit : VolumeValue;
        constraint volume <= limit;
    }

    constraint def PositiveFlow {
        in flow : FlowRateValue;
        constraint flow >= 0;
    }

    // ===== Action Definitions =====
    action def ExecuteProtocol {
        in protocol : ProtocolData;
        in phases : ProtocolPhase[*];
        out deliveredVolume : VolumeValue;
        out log : InjectionLog;
        perform action executePhase : ExecutePhase {
            in phase : ProtocolPhase;
            out delivered : VolumeValue;
        } *;
    }

    action def ExecutePhase {
        in phase : ProtocolPhase;
        out delivered : VolumeValue;
        attribute currentFlow : FlowRateValue;
        attribute currentVolume : VolumeValue;
        attribute elapsed : DurationValue;
    }

    action def PrimeFluidLine {
        in contrastLine : Fluid;
        in salineLine : Fluid;
        out purgedAir : Air;
        attribute purgeVolume : VolumeValue = 5 [mL];
    }

    action def PerformSafetyCheck {
        in limits : SafetyLimits;
        in readings : SensorReading;
        out pass : Boolean;
    }

    action def LogInjection {
        in protocol : ProtocolData;
        in telemetry : TelemetryData;
        out log : InjectionLog;
    }

    action def HaltInjection {
        out command : CommandSignal;
    }

    // ===== Component Parts =====
    part def System {
        satisfies DualHeadInjectionRequirement;
        satisfies FlowControlRequirement;
        satisfies StateBehaviorRequirement;
        satisfies EmergencyStopRequirement;

        port commandPort : CommandPort;
        port patientPort : PatientPort;
        port powerPort : PowerPort;
        port telemetryPort : TelemetryPort;

        attribute limits : SafetyLimits {
            maxPressure = 300 [psi];
            maxFlowRate = 10 [mL/s];
            maxVolume = 400 [mL];
            minPressure = 0 [psi];
        }

        attribute armed : Boolean;
        attribute currentProtocol : ProtocolData;
        attribute currentPhases : ProtocolPhase[*];
        attribute currentPhaseIndex : Integer;
        attribute deliveredVolume : VolumeValue;

        part dualHead : DualHeadInjector;
        part console : OperatorConsole;
        part sensorSuite : SensorSuite;
        part safetyInterlock : SafetyInterlock;
        part alarm : AlarmUnit;
        part powerSupply : PowerSupply;
        part fluidPath : FluidPath;
        part patientLine : PatientLine;
        part logger : Logger;

        behavior injectionStateMachine : InjectionStateMachine {
            attribute startTime : DurationValue;
        }
    }

    part def DualHeadInjector {
        satisfies DualHeadInjectionRequirement;
        satisfies PressureJacketRequirement;

        part contrastHead : InjectorHead {
            attribute targetFluid : String = "contrast";
        }
        part salineHead : InjectorHead {
            attribute targetFluid : String = "saline";
        }
        part contrastSyringe : Syringe {
            attribute capacity : VolumeValue = 200 [mL];
            item contents : ContrastMedia;
        }
        part salineSyringe : Syringe {
            attribute capacity : VolumeValue = 200 [mL];
            item contents : Saline;
        }
        part contrastJacket : PressureJacket {
            attribute rating : PressureValue = 1200 [psi];
        }
        part salineJacket : PressureJacket {
            attribute rating : PressureValue = 1200 [psi];
        }

        connection contrastHead.plungerConnection to contrastSyringe.plungerInterface;
        connection salineHead.plungerConnection to salineSyringe.plungerInterface;
        binding contrastSyringe.housingPort = contrastJacket.syringePort;
        binding salineSyringe.housingPort = salineJacket.syringePort;
    }

    part def InjectorHead {
        satisfies FlowControlRequirement;

        port controlPort : CommandPort;
        port motorPort : PowerPort;

        part motor : Motor;
        part plunger : Plunger;
        part encoder : Encoder;

        attribute commandedFlowRate : FlowRateValue;
        attribute commandedVolume : VolumeValue;
        attribute currentSpeed : RotationalSpeedValue;
        attribute torque : Real;

        attribute plungerConnection : PlungerInterface;
    }

    part def Motor {
        port powerIn : PowerPort;
        attribute speed : RotationalSpeedValue;
        attribute torque : Real;
        attribute maxTorque : Real = 50;
    }

    part def Encoder {
        attribute pulsesPerRev : Integer = 1024;
        attribute currentPosition : VolumeValue;
    }

    part def Plunger {
        attribute position : VolumeValue;
        attribute force : ForceValue;
        attribute maxForce : ForceValue = 800 [N];
    }

    attribute def PlungerInterface {
        attribute engaged : Boolean;
    }

    part def Syringe {
        attribute capacity : VolumeValue;
        item contents : Fluid;
        attribute currentVolume : VolumeValue;
        port outlet : FluidOutPort;
        attribute plungerInterface : PlungerInterface;
        attribute housingPort : PlungerInterface;
    }

    part def PressureJacket {
        attribute rating : PressureValue;
        attribute syringePort : PlungerInterface;
        attribute material : String = "stainless steel";
        attribute wallThickness : Real;
    }

    part def OperatorConsole {
        satisfies ProtocolProgrammingRequirement;
        satisfies RealTimeDisplayRequirement;

        port operatorPort : CommandPort;
        port systemPort : CommandPort;
        port displayPort : TelemetryPort;

        part display : Display;
        part inputPanel : InputPanel;
        part protocolEngine : ProtocolEngine;

        attribute programmedProtocol : ProtocolData;
        attribute programmedPhases : ProtocolPhase[*];
        attribute statusDisplay : TelemetryData;
        attribute operatorId : String;
    }

    part def Display {
        attribute pressureReading : PressureValue;
        attribute flowReading : FlowRateValue;
        attribute volumeDelivered : VolumeValue;
        attribute elapsed : DurationValue;
        attribute phase : Integer;
        attribute refreshInterval : DurationValue = 0.1 [s];
    }

    part def InputPanel {
        attribute touchEnabled : Boolean = true;
        attribute physicalButtons : String[*];
        attribute emergencyButton : Boolean = true;
    }

    part def ProtocolEngine {
        attribute activeProtocol : ProtocolData;
        attribute phases : ProtocolPhase[*];
        attribute currentPhase : Integer;
    }

    part def SensorSuite {
        satisfies SensorMonitoringRequirement;

        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part volumeSensor : VolumeSensor;

        port readingsPort : SafetyPort;
        port consolePort : TelemetryPort;
        port console2Port : CommandPort;

        out readings : SensorReading;
        out telemetry : TelemetryData;
        attribute sampleInterval : DurationValue = 0.01 [s];
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        attribute range : PressureValue = 1200 [psi];
        attribute accuracy : Real = 0.01;
    }

    part def FlowSensor {
        attribute measuredFlowRate : FlowRateValue;
        attribute range : FlowRateValue = 20 [mL/s];
        attribute accuracy : Real = 0.01;
    }

    part def VolumeSensor {
        attribute measuredVolume : VolumeValue;
        attribute accuracy : Real = 0.005;
    }

    part def SafetyInterlock {
        satisfies SafetyInterlockRequirement;

        port inputPort : SafetyPort;
        port consolePort : CommandPort;
        port alarmPort : SafetyPort;
        port emergencyPort : SafetyPort;

        attribute currentLimits : SafetyLimits;
        attribute monitoringActive : Boolean;
        attribute lastReading : SensorReading;
        attribute maxResponseTime : DurationValue = 0.2 [s];
        attribute alarmStatus : AlarmStatus;
    }

    part def AlarmUnit {
        port alarmIn : SafetyPort;
        attribute audible : Boolean;
        attribute visual : Boolean;
        attribute message : String;
        attribute acknowledged : Boolean;
    }

    part def PowerSupply {
        port output : PowerPort;
        attribute outputVoltage : VoltageValue = 24 [V];
        attribute outputCurrent : CurrentValue = 15 [A];
        attribute backup : Boolean = true;
    }

    part def FluidPath {
        port contrastInlet : FluidInPort;
        port salineInlet : FluidInPort;
        port outlet : FluidOutPort;

        part contrastLine : FluidLine {
            attribute innerDiameter : Real = 4.0;
            attribute length : Real = 1500;
        }
        part salineLine : FluidLine {
            attribute innerDiameter : Real = 4.0;
            attribute length : Real = 1500;
        }
        part manifold : Manifold;
        part checkValve : CheckValve;
    }

    part def FluidLine {
        attribute innerDiameter : Real;
        attribute length : Real;
        attribute material : String = "medical grade tubing";
    }

    part def Manifold {
        attribute mixingRatio : Real;
    }

    part def CheckValve {
        attribute crackingPressure : PressureValue = 0.5 [psi];
    }

    part def PatientLine {
        port inlet : FluidInPort;
        port patientOutput : PatientPort;
        attribute length : Real = 2000;
    }

    part def Logger {
        satisfies LoggingRequirement;
        in injectionData : InjectionLog;
        attribute storageSize : Integer;
        attribute entries : InjectionLog[*];
    }

    // ===== State Machine =====
    state def InjectionStateMachine {
        satisfies StateBehaviorRequirement;

        entry action initialize : System.initializeSystem;
        exit action finalize : System.finalizeSystem;

        state powerOff {
            entry action : System.onPowerOffEntry;
            attribute powerState : Boolean = false;
        }
        state idle {
            entry action : System.onIdleEntry;
            attribute ready : Boolean;
        }
        state loading {
            entry action : System.onLoadingEntry;
            attribute loadedContrast : Boolean;
            attribute loadedSaline : Boolean;
        }
        state priming {
            entry action : System.startPriming;
            do action : System.performPriming;
            exit action : System.completePriming;
        }
        state armed {
            entry action : System.armSystem;
            do action : System.runSafetyChecks;
        }
        state injecting {
            entry action : System.startInjectionPhase;
            do action : System.executeCurrentPhase;
            exit action : System.endInjectionPhase;
        }
        state paused {
            entry action : System.pauseFlow;
        }
        state completed {
            entry action : System.logCompletion;
            attribute injectionLog : InjectionLog;
        }
        state fault {
            entry action : System.handleFault;
            attribute faultType : String;
            attribute faultTime : DurationValue;
        }
        state emergencyStop {
            entry action : System.emergencyHalt;
            do action : System.secureSystem;
            attribute stopReason : String;
        }

        transition powerOff -> idle when PowerOn;
        transition idle -> powerOff when PowerOff;
        transition idle -> loading when LoadSyringes;
        transition loading -> idle when ResetCommand;
        transition loading -> priming when StartPriming;
        transition priming -> priming when StartPriming;
        transition priming -> armed when PrimingComplete;
        transition armed -> idle when ResetCommand;
        transition armed -> injecting when StartInjection;
        transition injecting -> paused when PauseInjection;
        transition paused -> injecting when ResumeInjection;
        transition paused -> idle when ResetCommand;
        transition injecting -> completed when ProtocolComplete;
        transition completed -> idle when ResetCommand;
        transition completed -> powerOff when PowerOff;
        transition * -> fault when FaultDetected;
        transition * -> emergencyStop when EmergencyStopTriggered;
        transition fault -> idle when FaultCleared;
        transition emergencyStop -> powerOff when SystemReset;
    }

    // ===== Behavior: perform actions =====
    action def System.initializeSystem { out initialized : Boolean; }
    action def System.finalizeSystem { }
    action def System.onPowerOffEntry { }
    action def System.onIdleEntry { }
    action def System.onLoadingEntry {
        attribute contrastLoaded : Boolean;
        attribute salineLoaded : Boolean;
    }
    action def System.startPriming { out started : Boolean; }
    action def System.performPriming {
        in contrastFluid : Fluid;
        in salineFluid : Fluid;
        out purgedAir : Air;
    }
    action def System.completePriming { out status : String; }
    action def System.armSystem { out armed : Boolean; }
    action def System.runSafetyChecks {
        in limits : SafetyLimits;
        in readings : SensorReading;
        out pass : Boolean;
    }
    action def System.startInjectionPhase { out phaseStart : Integer; }
    action def System.executeCurrentPhase {
        in phase : ProtocolPhase;
        out delivered : VolumeValue;
    }
    action def System.endInjectionPhase { }
    action def System.pauseFlow { out paused : Boolean; }
    action def System.logCompletion {
        in telemetry : TelemetryData;
        in protocol : ProtocolData;
        out log : InjectionLog;
    }
    action def System.handleFault {
        in faultType : String;
        out faultLogged : Boolean;
    }
    action def System.secureSystem { out secured : Boolean; }
    action def System.emergencyHalt {
        out command : CommandSignal;
        out alarm : AlarmSignal;
    }

    // ===== Internal Connections =====
    part def System {
        connection dualHead.contrastHead.controlPort to console.systemPort;
        connection dualHead.salineHead.controlPort to console.systemPort;
        connection dualHead.contrastSyringe.outlet to fluidPath.contrastInlet;
        connection dualHead.salineSyringe.outlet to fluidPath.salineInlet;
        connection fluidPath.outlet to patientLine.inlet;
        connection patientLine.patientOutput to patientPort;
        connection sensorSuite.readingsPort to safetyInterlock.inputPort;
        connection safetyInterlock.alarmPort to alarm.alarmIn;
        connection safetyInterlock.emergencyPort to dualHead.contrastHead.controlPort;
        connection safetyInterlock.emergencyPort to dualHead.salineHead.controlPort;
        connection console.systemPort to dualHead.contrastHead.controlPort;
        connection console.systemPort to dualHead.salineHead.controlPort;
        connection console.displayPort to sensorSuite.consolePort;
        connection powerSupply.output to dualHead.contrastHead.motorPort;
        connection powerSupply.output to dualHead.salineHead.motorPort;
        flow contrast from dualHead.contrastSyringe.outlet.fluid to fluidPath.contrastInlet.fluid;
        flow saline from dualHead.salineSyringe.outlet.fluid to fluidPath.salineInlet.fluid;
        flow from fluidPath.outlet.fluid to patientLine.inlet.fluid;
        flow from patientLine.patientOutput.fluid to patientPort.fluid;
    }
}

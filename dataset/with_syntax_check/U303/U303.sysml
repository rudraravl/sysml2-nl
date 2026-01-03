package 'Medrad Contrast Injection System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def InjectionProtocol {
        attribute flowRate : VolumeFlowRateValue;
        attribute totalVolume : VolumeValue;
        attribute maxPressure : PressureValue;
        attribute phaseCount : Integer;
    }
    
    attribute def InjectionPhase {
        attribute phaseVolume : VolumeValue;
        attribute phaseFlowRate : VolumeFlowRateValue;
        attribute phaseDuration : TimeValue;
    }
    
    attribute def ContrastAgent {
        attribute concentration : Real;
        attribute viscosity : Real;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute iodineMgPerMl : Real;
    }
    
    attribute def SafetyLimits {
        attribute maxPressure : PressureValue;
        attribute maxFlowRate : VolumeFlowRateValue;
        attribute maxTotalVolume : VolumeValue;
        attribute minFlowRate : VolumeFlowRateValue;
    }
    
    enum def SystemStateKind {
        enum powerOff;
        enum idle;
        enum loading;
        enum primed;
        enum armed;
        enum injecting;
        enum paused;
        enum completed;
        enum fault;
        enum emergency;
    }
    
    enum def AlarmSeverityKind {
        enum info;
        enum warning;
        enum critical;
    }
    
    item def ContrastMedia;
    item def Saline;
    item def ElectricalPower;
    
    attribute def StartInjection;
    attribute def StopInjection;
    attribute def PauseInjection;
    attribute def ResumeInjection;
    attribute def ArmSystem;
    attribute def DisarmSystem;
    attribute def PrimeSystem;
    attribute def EmergencyStop;
    attribute def PressureAlarm;
    attribute def VolumeAlarm;
    
    port def FluidPort {
        attribute pressure : PressureValue;
        attribute flowRate : VolumeFlowRateValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }
    
    port def ElectricalPort {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
        attribute power : PowerValue;
    }
    
    port def ControlPort {
        in command : InjectionCommand;
        out status : SystemStatus;
        out alarms : AlarmMessage[*];
    }
    
    port def DataPort {
        out injectionData : InjectionRecord;
        out diagnosticData : DiagnosticInfo;
    }
    
    attribute def InjectionCommand;
    attribute def SystemStatus;
    attribute def AlarmMessage {
        attribute severity : AlarmSeverityKind;
        attribute code : String;
        attribute timestamp : TimeValue;
    }
    attribute def InjectionRecord;
    attribute def DiagnosticInfo;
    
    part def ContrastSyringe {
        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute plungerPosition : LengthValue;
        port fluidOut : FluidPort;
        port mechanicalInterface;
    }
    
    part def SalineSyringe {
        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute plungerPosition : LengthValue;
        port fluidOut : FluidPort;
        port mechanicalInterface;
    }
    
    part def PressureJacket {
        attribute maxRatedPressure : PressureValue;
        attribute currentPressure : PressureValue;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port airPressureIn;
    }
    
    part def InjectorHead {
        attribute position : LengthValue;
        attribute velocity : SpeedValue;
        attribute force : ForceValue;
        attribute maxForce : ForceValue;
        port driveMotor;
        port encoderFeedback;
        port syringeInterface;
    }
    
    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        attribute accuracy : Real;
        attribute range : PressureValue;
        port sensorPort;
        port signalOut;
    }
    
    part def FlowRateSensor {
        attribute measuredFlowRate : VolumeFlowRateValue;
        attribute accuracy : Real;
        port sensorPort;
        port signalOut;
    }
    
    part def VolumeSensor {
        attribute measuredVolume : VolumeValue;
        attribute accuracy : Real;
        port sensorPort;
        port signalOut;
    }
    
    part def FlowRateController {
        in attribute targetFlowRate : VolumeFlowRateValue;
        in attribute measuredFlowRate : VolumeFlowRateValue;
        out attribute controlSignal : Real;
        attribute pidGains : Real[3];
    }
    
    part def SafetyInterlock {
        in attribute currentPressure : PressureValue;
        in attribute currentFlowRate : VolumeFlowRateValue;
        in attribute deliveredVolume : VolumeValue;
        in attribute safetyLimits : SafetyLimits;
        out attribute interlockActive : Boolean;
        out attribute alarmTriggered : Boolean;
    }
    
    part def OperatorConsole {
        port controlInterface : ControlPort;
        port displayInterface;
        port touchscreenInput;
        attribute displayedProtocol : InjectionProtocol;
        attribute displayedStatus : SystemStateKind;
        attribute displayedPressure : PressureValue;
        attribute displayedFlowRate : VolumeFlowRateValue;
        attribute displayedVolume : VolumeValue;
    }
    
    part def PatientInterface {
        port fluidDelivery : FluidPort;
        attribute catheterConnected : Boolean;
        attribute catheterType : String;
        attribute catheterGauge : Integer;
    }
    
    part def PowerSupply {
        port acInput : ElectricalPort;
        port dcOutput : ElectricalPort;
        attribute inputVoltage : ElectricPotentialValue;
        attribute outputVoltage : ElectricPotentialValue;
        attribute maxPower : PowerValue;
    }
    
    part def MotorController {
        port powerIn : ElectricalPort;
        port motorOut;
        port controlIn;
        attribute maxCurrent : ElectricCurrentValue;
        attribute pwmFrequency : FrequencyValue;
    }
    
    part def DataLogger {
        port dataIn : DataPort;
        port storageInterface;
        attribute recordingActive : Boolean;
        attribute storageCapacity : Real;
    }
    
    action def LoadSyringe {
        in syringeType : String;
        in contrastAgent : ContrastAgent;
        in targetVolume : VolumeValue;
        out syringeLoaded : Boolean;
        out loadedVolume : VolumeValue;
    }
    
    action def PrimeFluidPath {
        in primeVolume : VolumeValue;
        in primeFlowRate : VolumeFlowRateValue;
        out systemPrimed : Boolean;
        out wasteVolume : VolumeValue;
    }
    
    action def MonitorPressure {
        in currentPressure : PressureValue;
        in maxAllowedPressure : PressureValue;
        out pressureOK : Boolean;
        out pressureAlarm : Boolean;
    }
    
    action def MonitorVolume {
        in deliveredVolume : VolumeValue;
        in targetVolume : VolumeValue;
        out volumeRemaining : VolumeValue;
        out targetReached : Boolean;
    }
    
    action def ControlInjectionFlow {
        in protocol : InjectionProtocol;
        in safetyLimits : SafetyLimits;
        in currentPhase : Integer;
        out actualFlowRate : VolumeFlowRateValue;
        out actualPressure : PressureValue;
        out deliveredVolume : VolumeValue;
        out phaseComplete : Boolean;
    }
    
    action def ExecuteMultiPhaseInjection {
        in protocol : InjectionProtocol;
        in safetyLimits : SafetyLimits;
        out totalDelivered : VolumeValue;
        out peakPressure : PressureValue;
        out injectionComplete : Boolean;
        
        private attribute currentPhase : Integer := 1;
        private attribute cumulativeVolume : VolumeValue := 0.0 [SI::mL];
        private attribute maxPressureObserved : PressureValue := 0.0 [SI::Pa];
        
        first start;
        then merge phaseLoop;
        
        action executePhase : ControlInjectionFlow {
            in protocol = ExecuteMultiPhaseInjection::protocol;
            in safetyLimits = ExecuteMultiPhaseInjection::safetyLimits;
            in currentPhase = ExecuteMultiPhaseInjection::currentPhase;
            out actualFlowRate;
            out actualPressure;
            out deliveredVolume;
            out phaseComplete;
        }
        then action updateMetrics {
            assign ExecuteMultiPhaseInjection::cumulativeVolume := 
                ExecuteMultiPhaseInjection::cumulativeVolume + executePhase.deliveredVolume;
            assign ExecuteMultiPhaseInjection::maxPressureObserved := 
                (executePhase.actualPressure > ExecuteMultiPhaseInjection::maxPressureObserved ? 
                 executePhase.actualPressure : ExecuteMultiPhaseInjection::maxPressureObserved);
        }
        then action monitorPhase : MonitorPressure {
            in currentPressure = executePhase.actualPressure;
            in maxAllowedPressure = ExecuteMultiPhaseInjection::safetyLimits.maxPressure;
            out pressureOK;
            out pressureAlarm;
        }
        then decide;
            if monitorPhase.pressureAlarm then emergencyStop;
            if executePhase.phaseComplete and ExecuteMultiPhaseInjection::currentPhase < ExecuteMultiPhaseInjection::protocol.phaseCount then nextPhase;
            if executePhase.phaseComplete and ExecuteMultiPhaseInjection::currentPhase >= ExecuteMultiPhaseInjection::protocol.phaseCount then complete;
            else phaseLoop;
        
        action nextPhase {
            assign ExecuteMultiPhaseInjection::currentPhase := ExecuteMultiPhaseInjection::currentPhase + 1;
        }
        then phaseLoop;
        
        action emergencyStop {
            action haltMotor;
            action activateAlarm;
            action logEvent;
        }
        then abort;
        
        action complete {
            assign totalDelivered := ExecuteMultiPhaseInjection::cumulativeVolume;
            assign peakPressure := ExecuteMultiPhaseInjection::maxPressureObserved;
            assign injectionComplete := true;
        }
        then done;
        
        action abort {
            assign totalDelivered := ExecuteMultiPhaseInjection::cumulativeVolume;
            assign peakPressure := ExecuteMultiPhaseInjection::maxPressureObserved;
            assign injectionComplete := false;
        }
        then done;
    }
    
    action def InjectionSequence {
        in protocol : InjectionProtocol;
        in safetyLimits : SafetyLimits;
        out finalStatus : SystemStateKind;
        out deliveredVolume : VolumeValue;
        out peakPressure : PressureValue;
        
        first start;
        then action loadContrast : LoadSyringe {
            in syringeType = "200mL";
            in targetVolume = InjectionSequence::protocol.totalVolume;
            out syringeLoaded;
            out loadedVolume;
        }
        then action loadSaline : LoadSyringe {
            in syringeType = "60mL";
            in targetVolume = 60.0 [SI::mL];
            out syringeLoaded;
            out loadedVolume;
        }
        then action primeLines : PrimeFluidPath {
            in primeVolume = 5.0 [SI::mL];
            in primeFlowRate = 2.0 [SI::mL];
            out systemPrimed;
            out wasteVolume;
        }
        then merge waitForArm;
        then accept armCmd : ArmSystem;
        then action performSafetyChecks {
            action verifyCatheter;
            action verifyProtocol;
            action verifyPressureLimits;
            action verifyFluidLevels;
        }
        then decide;
            if performSafetyChecks.verifyPressureLimits then proceedToInject;
            else abortSequence;
        
        action proceedToInject {
            accept startCmd : StartInjection;
            then action performInjection : ExecuteMultiPhaseInjection {
                in protocol = InjectionSequence::protocol;
                in safetyLimits = InjectionSequence::safetyLimits;
                out totalDelivered;
                out peakPressure;
                out injectionComplete;
            }
            then decide;
                if performInjection.injectionComplete then completeInjection;
                else handleFault;
        }
        
        action completeInjection {
            assign finalStatus := SystemStateKind::completed;
            assign deliveredVolume := proceedToInject.performInjection.totalDelivered;
            assign peakPressure := proceedToInject.performInjection.peakPressure;
        }
        then done;
        
        action handleFault {
            assign finalStatus := SystemStateKind::fault;
            assign deliveredVolume := proceedToInject.performInjection.totalDelivered;
            assign peakPressure := proceedToInject.performInjection.peakPressure;
        }
        then done;
        
        action abortSequence {
            assign finalStatus := SystemStateKind::fault;
            assign deliveredVolume := 0.0 [SI::mL];
            assign peakPressure := 0.0 [SI::Pa];
        }
        then done;
    }
    
    state def InjectorSystemStates {
        entry; then powerOff;
        
        state powerOff;
        transition powerOff_to_idle
            first powerOff
            accept powerOn
            then idle;
        
        state idle;
        transition idle_to_loading
            first idle
            accept loadCommand
            then loading;
        
        state loading {
            do action loadSyringes;
        }
        transition loading_to_primed
            first loading
            if loadSyringes
            then primed;
        
        state primed {
            do action maintainReadiness;
        }
        transition primed_to_armed
            first primed
            accept armCmd : ArmSystem
            then armed;
        
        state armed {
            do action monitorReadiness;
        }
        transition armed_to_injecting
            first armed
            accept startCmd : StartInjection
            then injecting;
        transition armed_to_primed
            first armed
            accept disarmCmd : DisarmSystem
            then primed;
        
        state injecting {
            do action deliverContrast : ExecuteMultiPhaseInjection;
        }
        transition injecting_to_paused
            first injecting
            accept pauseCmd : PauseInjection
            then paused;
        transition injecting_to_completed
            first injecting
            then completed;
        transition injecting_to_emergency
            first injecting
            accept emergencyCmd : EmergencyStop
            then emergency;
        transition injecting_to_fault
            first injecting
            then fault;
        
        state paused {
            do action holdState;
        }
        transition paused_to_injecting
            first paused
            accept resumeCmd : ResumeInjection
            then injecting;
        transition paused_to_completed
            first paused
            accept stopCmd : StopInjection
            then completed;
        
        state completed {
            do action finalizeRecord;
        }
        transition completed_to_idle
            first completed
            accept resetCmd
            then idle;
        
        state fault {
            do action handleFaultCondition;
        }
        transition fault_to_idle
            first fault
            accept clearFaultCmd
            then idle;
        
        state emergency {
            do action emergencyShutdown;
        }
        transition emergency_to_idle
            first emergency
            accept resetCmd
            then idle;
    }
    
    part def ContrastInjectionSystem {
        attribute operatingProtocol : InjectionProtocol {
            attribute :>> flowRate = 5.0 [SI::mL];
            attribute :>> totalVolume = 100.0 [SI::mL];
            attribute :>> maxPressure = 300.0 [SI::Pa];
            attribute :>> phaseCount = 2;
        }
        
        attribute patientSafetyLimits : SafetyLimits {
            attribute :>> maxPressure = 325.0 [SI::Pa];
            attribute :>> maxFlowRate = 10.0 [SI::mL];
            attribute :>> maxTotalVolume = 200.0 [SI::mL];
            attribute :>> minFlowRate = 0.1 [SI::mL];
        }
        
        attribute currentState : SystemStateKind;
        
        part contrastSyringe : ContrastSyringe {
            attribute :>> capacity = 200.0 [SI::mL];
            attribute :>> currentVolume = 150.0 [SI::mL];
        }
        
        part salineSyringe : SalineSyringe {
            attribute :>> capacity = 60.0 [SI::mL];
            attribute :>> currentVolume = 60.0 [SI::mL];
        }
        
        part contrastJacket : PressureJacket {
            attribute :>> maxRatedPressure = 1200.0 [SI::Pa];
        }
        
        part salineJacket : PressureJacket {
            attribute :>> maxRatedPressure = 1200.0 [SI::Pa];
        }
        
        part contrastHead : InjectorHead {
            attribute :>> maxForce = 500.0 [SI::N];
        }
        
        part salineHead : InjectorHead {
            attribute :>> maxForce = 500.0 [SI::N];
        }
        
        part pressureSensor : PressureSensor {
            attribute :>> range = 500.0 [SI::Pa];
            attribute :>> accuracy = 0.02;
        }
        
        part flowSensor : FlowRateSensor {
            attribute :>> accuracy = 0.05;
        }
        
        part volumeSensor : VolumeSensor {
            attribute :>> accuracy = 0.01;
        }
        
        part flowController : FlowRateController {
            attribute :>> pidGains = (1.0, 0.1, 0.01);
        }
        
        part safetySystem : SafetyInterlock;
        
        part console : OperatorConsole;
        
        part patientLine : PatientInterface;
        
        part powerSupply : PowerSupply {
            attribute :>> inputVoltage = 120.0 [SI::V];
            attribute :>> outputVoltage = 24.0 [SI::V];
            attribute :>> maxPower = 500.0 [SI::W];
        }
        
        part contrastMotorController : MotorController {
            attribute :>> maxCurrent = 10.0 [SI::A];
        }
        
        part salineMotorController : MotorController {
            attribute :>> maxCurrent = 10.0 [SI::A];
        }
        
        part dataLogger : DataLogger {
            attribute :>> storageCapacity = 10000.0;
        }
        
        connect contrastSyringe.fluidOut to contrastJacket.fluidIn;
        connect salineSyringe.fluidOut to salineJacket.fluidIn;
        connect contrastJacket.fluidOut to patientLine.fluidDelivery;
        connect pressureSensor.sensorPort to contrastJacket.fluidOut;
        connect flowSensor.sensorPort to patientLine.fluidDelivery;
        connect powerSupply.dcOutput to contrastMotorController.powerIn;
        connect powerSupply.dcOutput to salineMotorController.powerIn;
        connect contrastMotorController.motorOut to contrastHead.driveMotor;
        connect salineMotorController.motorOut to salineHead.driveMotor;
        connect contrastHead.syringeInterface to contrastSyringe.mechanicalInterface;
        connect salineHead.syringeInterface to salineSyringe.mechanicalInterface;
        
        perform action injectionSequence : InjectionSequence {
            in protocol = operatingProtocol;
            in safetyLimits = patientSafetyLimits;
            out finalStatus;
            out deliveredVolume;
            out peakPressure;
        }
        
        exhibit state systemBehavior : InjectorSystemStates;
    }
    
    part contrastInjectionSystem : ContrastInjectionSystem;
    
    requirement <'MED-REQ-001'> systemPrimaryFunction {
        doc /* 
        The Medrad contrast injection system shall deliver radiographic contrast media 
        to patients during diagnostic imaging procedures (CT, angiography, MRI) with 
        precise control of flow rate, volume, and pressure to enable optimal image 
        quality while maintaining patient safety through continuous monitoring and 
        automated safety interlocks.
        */
        
        subject contrastInjectionSystem;
        
        require deliveryPrecision;
        require safetyCompliance;
        require operatorControl;
        require systemReliability;
    }
    
    requirement <'MED-REQ-002'> deliveryPrecision {
        doc /* 
        The system shall deliver contrast media with flow rate accuracy within ±5% 
        of programmed value, volume accuracy within ±2% of programmed value, and 
        pressure measurement accuracy within ±2% of reading across the operating range.
        */
        
        assume constraint sensorCalibration {
            contrastInjectionSystem.pressureSensor.accuracy <= 0.02 and
            contrastInjectionSystem.flowSensor.accuracy <= 0.05 and
            contrastInjectionSystem.volumeSensor.accuracy <= 0.02
        }
    }
    
    requirement <'MED-REQ-003'> safetyCompliance {
        doc /* 
        The system shall continuously monitor injection pressure and automatically 
        terminate injection if pressure exceeds programmed maximum by more than 25 psi, 
        or if any safety interlock condition is detected, with alarm notification to 
        operator within 100 milliseconds.
        */
        
        assume constraint pressureSensorReliability {
            contrastInjectionSystem.pressureSensor.measuredPressure >= 0.0 [SI::Pa] and
            contrastInjectionSystem.pressureSensor.measuredPressure <= 500.0 [SI::Pa]
        }
        
        require constraint pressureLimitEnforcement {
            contrastInjectionSystem.safetySystem.interlockActive == true implies
            contrastInjectionSystem.currentState == SystemStateKind::fault or
            contrastInjectionSystem.currentState == SystemStateKind::emergency
        }
    }
    
    requirement <'MED-REQ-004'> operatorControl {
        doc /* 
        The system shall provide operator interface for programming multi-phase injection 
        protocols, initiating and controlling injections, and monitoring system status, 
        pressure, flow rate, and delivered volume in real-time with update rate of at 
        least 10 Hz.
        */
    }
    
    requirement <'MED-REQ-005'> systemReliability {
        doc /* 
        The system shall maintain operational availability of 99.5% during normal use, 
        with mean time between failures (MTBF) of at least 5000 injection cycles, and 
        shall log all injection parameters and events for quality assurance and 
        regulatory compliance.
        */
        
        require constraint dataLogging {
            contrastInjectionSystem.dataLogger.recordingActive == true
        }
    }
    
    requirement <'MED-REQ-006'> multiPhaseCapability {
        doc /* 
        The system shall support multi-phase injection protocols with up to 8 distinct 
        phases, each with independently programmable flow rate, volume, and duration, 
        with seamless transitions between phases maintaining pressure stability within 
        ±10% during phase changes.
        */
        
        assume constraint protocolValidity {
            contrastInjectionSystem.operatingProtocol.phaseCount >= 1 and
            contrastInjectionSystem.operatingProtocol.phaseCount <= 8
        }
    }
}

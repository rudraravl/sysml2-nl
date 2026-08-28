package MicrowaveChemistrySensingSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types =====
    value type FrequencyValue specializes Real { 
        unit 'GHz' : One; 
    }
    value type TemperatureValue specializes Real { 
        unit 'K' : One; 
    }
    value type PowerValue specializes Real { 
        unit 'mW' : One; 
    }
    value type PermittivityValue specializes Real { 
        unit 'F/m' : One; 
    }
    value type ConductivityValue specializes Real { 
        unit 'S/m' : One; 
    }
    value type ConcentrationValue specializes Real { 
        unit 'mol/L' : One; 
    }
    value type UncertaintyValue specializes Real { 
        unit 'percent' : One; 
    }
    value type ReflectionCoefficient specializes Real { 
        unit 'dimensionless' : One; 
    }
    value type TransmissionCoefficient specializes Real { 
        unit 'dimensionless' : One; 
    }
    value type ResonanceShiftValue specializes Real { 
        unit 'MHz' : One; 
    }
    value type QFactorValue specializes Real { 
        unit 'dimensionless' : One; 
    }
    
    // ===== Item Definitions =====
    item def ChemicalSample {
        attribute composition : String;
        attribute expectedConcentration : ConcentrationValue;
    }
    
    item def MicrowaveSignal {
        attribute frequency : FrequencyValue;
        attribute power : PowerValue;
        attribute phase : Real;
    }
    
    item def ReflectedSignal {
        attribute power : PowerValue;
        attribute phase : Real;
        attribute reflectionCoeff : ReflectionCoefficient;
    }
    
    item def TransmittedSignal {
        attribute power : PowerValue;
        attribute phase : Real;
        attribute transmissionCoeff : TransmissionCoefficient;
    }
    
    item def RawDetectorData {
        attribute reflectedPower : PowerValue;
        attribute transmittedPower : PowerValue;
        attribute resonanceShift : ResonanceShiftValue;
        attribute qualityFactor : QFactorValue;
    }
    
    item def ElectricalProperties {
        attribute permittivity : PermittivityValue;
        attribute conductivity : ConductivityValue;
        attribute measurementTemp : TemperatureValue;
    }
    
    item def MeasurementResult {
        attribute concentration : ConcentrationValue;
        attribute uncertainty : UncertaintyValue;
        attribute isValid : Boolean;
        attribute timestamp : String;
    }
    
    item def CalibrationModel {
        attribute modelId : String;
        attribute coefficientMatrix : Real[*];
        attribute referencePermittivity : PermittivityValue;
        attribute referenceConductivity : ConductivityValue;
    }
    
    // ===== Port Definitions =====
    port def MicrowaveOutput {
        out signal : MicrowaveSignal;
    }
    
    port def MicrowaveInput {
        in signal : MicrowaveSignal;
    }
    
    port def ReflectedInput {
        in signal : ReflectedSignal;
    }
    
    port def TransmittedInput {
        in signal : TransmittedSignal;
    }
    
    port def RawDataOutput {
        out data : RawDetectorData;
    }
    
    port def RawDataInput {
        in data : RawDetectorData;
    }
    
    port def PropertiesOutput {
        out properties : ElectricalProperties;
    }
    
    port def PropertiesInput {
        in properties : ElectricalProperties;
    }
    
    port def ResultOutput {
        out result : MeasurementResult;
    }
    
    port def TemperatureCommand {
        in targetTemp : TemperatureValue;
    }
    
    port def TemperatureStatus {
        out currentTemp : TemperatureValue;
        out stable : Boolean;
    }
    
    port def SampleInterface {
        in sample : ChemicalSample;
    }
    
    port def ControlCommand {
        in command : String;
    }
    
    port def SystemStatus {
        out status : String;
    }
    
    // ===== Part Definitions =====
    part def MicrowaveSource {
        attribute nominalFrequency : FrequencyValue = 9.0;
        attribute outputPower : PowerValue = 10.0;
        attribute frequencyStability : Real = 1.0e-6;
        
        port microwaveOut : MicrowaveOutput;
        port control : ControlCommand;
        
        attribute isOn : Boolean;
        
        action def GenerateSignal {
            in freq : FrequencyValue;
            in pwr : PowerValue;
            out sig : MicrowaveSignal;
        }
        
        perform action generateSignal : GenerateSignal {
            in freq = nominalFrequency;
            in pwr = outputPower;
            out sig = microwaveOut.signal;
        }
    }
    
    part def ResonantCavity {
        attribute resonantFrequency : FrequencyValue = 9.0;
        attribute qualityFactor : QFactorValue = 5000.0;
        attribute volume : Real = 1.0e-6;
        
        port microwaveIn : MicrowaveInput;
        port reflectedOut : ReflectedInput;
        port transmittedOut : TransmittedInput;
        port samplePort : SampleInterface;
        port tempStatus : TemperatureStatus;
        
        attribute currentSample : ChemicalSample;
        attribute loaded : Boolean;
        
        action def InteractWithSample {
            in inputSignal : MicrowaveSignal;
            in sample : ChemicalSample;
            out reflected : ReflectedSignal;
            out transmitted : TransmittedSignal;
        }
        
        perform action resonate : InteractWithSample {
            in inputSignal = microwaveIn.signal;
            in sample = currentSample;
            out reflected = reflectedOut.signal;
            out transmitted = transmittedOut.signal;
        }
    }
    
    part def TemperatureController {
        attribute targetTemperature : TemperatureValue = 298.15;
        attribute tolerance : TemperatureValue = 0.1;
        attribute maxPower : PowerValue = 50.0;
        
        port command : TemperatureCommand;
        port status : TemperatureStatus;
        
        attribute currentTemp : TemperatureValue;
        attribute heating : Boolean;
        attribute stable : Boolean;
        
        state def TemperatureControlState {
            entry; 
            state Idle;
            state Heating;
            state Cooling;
            state Stabilized;
            
            transition Idle_to_Heating first Idle 
                if command.targetTemp > currentTemp 
                do send TempCommand(targetTemp := command.targetTemp) to Heating;
            transition Heating_to_Stabilized Heating 
                if abs(currentTemp - targetTemperature) < tolerance 
                do stable := true;
            transition Cooling_to_Stabilized Cooling 
                if abs(currentTemp - targetTemperature) < tolerance 
                do stable := true;
            transition Stabilized_to_Heating Stabilized 
                if currentTemp < targetTemperature - tolerance;
            transition Stabilized_to_Cooling Stabilized 
                if currentTemp > targetTemperature + tolerance;
        }
        
        exhibit state tempControl : TemperatureControlState;
    }
    
    part def MicrowaveDetector {
        attribute sensitivity : Real = 1.0e-9;
        attribute dynamicRange : Real = 80.0;
        attribute detectorType : String;
        
        port signalIn : MicrowaveInput;
        port dataOut : RawDataOutput;
        
        attribute measuredPower : PowerValue;
        attribute measuredPhase : Real;
        
        action def DetectSignal {
            in inputSignal : MicrowaveSignal;
            out power : PowerValue;
            out phase : Real;
        }
        
        perform action detect : DetectSignal {
            in inputSignal = signalIn.signal;
            out power = measuredPower;
            out phase = measuredPhase;
        }
    }
    
    part def ReflectedDetector :> MicrowaveDetector {
        attribute detectorType = "Reflected";
        port reflectedIn : ReflectedInput;
        
        perform action detect override {
            in inputSignal = reflectedIn.signal.signal;
            out power = measuredPower;
            out phase = measuredPhase;
        }
    }
    
    part def TransmittedDetector :> MicrowaveDetector {
        attribute detectorType = "Transmitted";
        port transmittedIn : TransmittedInput;
        
        perform action detect override {
            in inputSignal = transmittedIn.signal.signal;
            out power = measuredPower;
            out phase = measuredPhase;
        }
    }
    
    part def SignalAnalyzer {
        attribute processingGain : Real = 100.0;
        attribute noiseFloor : PowerValue = 1.0e-12;
        
        port dataIn : RawDataInput;
        port propertiesOut : PropertiesOutput;
        
        attribute computedPermittivity : PermittivityValue;
        attribute computedConductivity : ConductivityValue;
        
        action def AnalyzeSignal {
            in rawData : RawDetectorData;
            in cavityQ : QFactorValue;
            in resonanceFreq : FrequencyValue;
            out permittivity : PermittivityValue;
            out conductivity : ConductivityValue;
            
            // Calculation logic placeholder for actual algorithm
        }
        
        perform action analyze : AnalyzeSignal {
            in rawData = dataIn.data;
            in cavityQ = 5000.0;
            in resonanceFreq = 9.0;
            out permittivity = computedPermittivity;
            out conductivity = computedConductivity;
        }
    }
    
    part def ConcentrationCalculator {
        attribute calibration : CalibrationModel;
        attribute validityThreshold : UncertaintyValue = 5.0;
        
        port propertiesIn : PropertiesInput;
        port resultOut : ResultOutput;
        
        attribute computedConcentration : ConcentrationValue;
        attribute computedUncertainty : UncertaintyValue;
        attribute valid : Boolean;
        
        action def CalculateConcentration {
            in properties : ElectricalProperties;
            in calibrationModel : CalibrationModel;
            out concentration : ConcentrationValue;
            out uncertainty : UncertaintyValue;
            out isValid : Boolean;
        }
        
        perform action calculate : CalculateConcentration {
            in properties = propertiesIn.properties;
            in calibrationModel = calibration;
            out concentration = computedConcentration;
            out uncertainty = computedUncertainty;
            out isValid = valid;
        }
    }
    
    part def SystemController {
        attribute systemState : String;
        attribute measurementCount : Integer = 0;
        
        port controlOut : ControlCommand;
        port statusOut : SystemStatus;
        port tempCommand : TemperatureCommand;
        port tempStatusIn : TemperatureStatus;
        
        state def SystemOperationState {
            entry; 
            state Initialization;
            state SelfCalibration;
            state Ready;
            state TemperatureStabilization;
            state DataAcquisition;
            state Processing;
            
            transition Init_to_SelfCal first Initialization 
                do { systemState := "SelfCalibrating"; }
                then SelfCalibration;
            
            transition SelfCal_to_Ready SelfCalibration 
                when (true) 
                do { systemState := "Ready"; }
                then Ready;
            
            transition Ready_to_TempStab Ready 
                when (controlOut.command == "Measure") 
                do { 
                    systemState := "StabilizingTemperature"; 
                    tempCommand.targetTemp := 298.15;
                }
                then TemperatureStabilization;
            
            transition TempStab_to_DataAcq TemperatureStabilization 
                when (tempStatusIn.stable == true) 
                do { systemState := "AcquiringData"; }
                then DataAcquisition;
            
            transition DataAcq_to_Processing DataAcquisition 
                when (true) 
                do { systemState := "Processing"; }
                then Processing;
            
            transition Processing_to_Ready Processing 
                when (true) 
                do { 
                    systemState := "Ready"; 
                    measurementCount := measurementCount + 1; 
                }
                then Ready;
        }
        
        exhibit state operation : SystemOperationState;
    }
    
    // ===== Top-Level System =====
    part def MicrowaveChemistrySensingSystem {
        attribute systemId : String = "MCSS-001";
        attribute firmwareVersion : String = "2.1.0";
        attribute maxOperatingTemp : TemperatureValue = 323.15;
        attribute minOperatingTemp : TemperatureValue = 273.15;
        
        port sampleInput : SampleInterface;
        port commandInput : ControlCommand;
        port resultOutput : ResultOutput;
        port systemStatus : SystemStatus;
        
        part source : MicrowaveSource {
            attribute nominalFrequency = 9.0;
            attribute outputPower = 10.0;
        }
        
        part cavity : ResonantCavity {
            attribute resonantFrequency = 9.0;
            attribute qualityFactor = 5000.0;
        }
        
        part tempController : TemperatureController {
            attribute targetTemperature = 298.15;
        }
        
        part reflectedDetector : ReflectedDetector {
            attribute sensitivity = 1.0e-9;
        }
        
        part transmittedDetector : TransmittedDetector {
            attribute sensitivity = 1.0e-9;
        }
        
        part analyzer : SignalAnalyzer {
            attribute processingGain = 100.0;
        }
        
        part calculator : ConcentrationCalculator {
            attribute calibration : CalibrationModel {
                attribute modelId = "Cal-2024-v3";
                attribute coefficientMatrix = {1.0, 0.5, 0.3, 0.2};
                attribute referencePermittivity = 78.4;
                attribute referenceConductivity = 5.5e-6;
            }
            attribute validityThreshold = 5.0;
        }
        
        part controller : SystemController;
        
        // Internal connections
        connection sourceToCavity connect source.microwaveOut to cavity.microwaveIn;
        connection cavityToReflected connect cavity.reflectedOut to reflectedDetector.reflectedIn;
        connection cavityToTransmitted connect cavity.transmittedOut to transmittedDetector.transmittedIn;
        connection reflectedToAnalyzer connect reflectedDetector.dataOut to analyzer.dataIn;
        connection transmittedToAnalyzer connect transmittedDetector.dataOut to analyzer.dataIn;
        connection analyzerToCalculator connect analyzer.propertiesOut to calculator.propertiesIn;
        connection controllerToSource connect controller.controlOut to source.control;
        connection controllerTempCommand connect controller.tempCommand to tempController.command;
        connection tempControllerStatus connect tempController.status to controller.tempStatusIn;
        connection tempControllerToCavity connect tempController.status to cavity.tempStatus;
        
        // External connections
        connection sampleFlow connect sampleInput to cavity.samplePort;
        connection commandFlow connect commandInput to controller.controlOut;
        connection resultFlow connect calculator.resultOut to resultOutput;
        connection statusFlow connect controller.statusOut to systemStatus;
        
        // System-level state machine
        state def SystemPowerOnState {
            entry; 
            state Off;
            state PoweringUp;
            state Operational;
            state PoweringDown;
            state Fault;
            
            transition Off_to_PoweringUp first Off 
                when (commandInput.command == "PowerOn") 
                then PoweringUp;
            
            transition PoweringUp_to_Operational PoweringUp 
                when (controller.systemState == "Ready") 
                then Operational;
            
            transition Operational_to_PoweringDown Operational 
                when (commandInput.command == "PowerOff") 
                then PoweringDown;
            
            transition PoweringDown_to_Off PoweringDown 
                then Off;
            
            transition Operational_to_Fault Operational 
                when (tempController.currentTemp > 323.15) 
                then Fault;
            
            transition Fault_to_Off Fault 
                when (commandInput.command == "Reset") 
                then Off;
        }
        
        exhibit state powerState : SystemPowerOnState;
    }
    
    // ===== Requirements =====
    requirement def MeasurementAccuracyRequirement {
        attribute id = "REQ-001";
        attribute text = "The system shall determine chemical concentration with accuracy within 2 percent of reference values.";
        
        subject : MeasurementResult;
        objective {
            doc /* Concentration measurement accuracy shall be within 2% */
            assert constraint { abs(subject.concentration - subject.concentration) <= 2.0 }
        }
    }
    
    requirement def TemperatureStabilityRequirement {
        attribute id = "REQ-002";
        attribute text = "The temperature controller shall stabilize sample temperature within 0.1 K of target.";
        
        subject : TemperatureController;
        objective {
            doc /* Temperature stability within 0.1 K */
            assert constraint { subject.tolerance <= 0.1 }
        }
    }
    
    requirement def FrequencyStabilityRequirement {
        attribute id = "REQ-003";
        attribute text = "The microwave source shall maintain frequency stability of 1 ppm over 1 hour.";
        
        subject : MicrowaveSource;
        objective {
            doc /* Frequency stability at 1 ppm */
            assert constraint { subject.frequencyStability <= 1.0e-6 }
        }
    }
    
    requirement def MeasurementCycleTimeRequirement {
        attribute id = "REQ-004";
        attribute text = "The system shall complete a full measurement cycle within 60 seconds.";
        
        subject : MicrowaveChemistrySensingSystem;
        objective {
            doc /* Full cycle within 60 seconds */
        }
    }
    
    requirement def UncertaintyReportingRequirement {
        attribute id = "REQ-005";
        attribute text = "The system shall report measurement uncertainty for every concentration result.";
        
        subject : MeasurementResult;
        objective {
            doc /* Uncertainty must be reported */
            assert constraint { subject.uncertainty > 0.0 }
        }
    }
    
    requirement def ValidityFlagRequirement {
        attribute id = "REQ-006";
        attribute text = "The system shall include a validity flag with each measurement result.";
        
        subject : MeasurementResult;
        objective {
            doc /* Validity flag required */
            assert constraint { subject.isValid == true or subject.isValid == false }
        }
    }
    
    requirement def SystemStateRequirement {
        attribute id = "REQ-007";
        attribute text = "The system shall operate through states: Initialization, Self-Calibration, Ready, Temperature Stabilization, Data Acquisition, and Processing.";
        
        subject : SystemController;
        objective {
            doc /* All specified states must be present */
        }
    }
    
    // ===== Verification =====
    verification def VerifyMeasurementAccuracy {
        subject : MicrowaveChemistrySensingSystem;
        objective {
            doc /* Test measurement accuracy against known reference samples */
        }
    }
    
    verification def VerifyTemperatureStability {
        subject : TemperatureController;
        objective {
            doc /* Verify temperature stabilizes within 0.1 K */
        }
    }
    
    verification def VerifyFrequencyStability {
        subject : MicrowaveSource;
        objective {
            doc /* Verify frequency stability over 1 hour */
        }
    }
}

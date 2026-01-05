package TrimprobSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ScanCommand;
    attribute def ScanComplete;
    attribute def PowerOn;
    attribute def PowerOff;
    attribute def CalibrationCommand;
    
    item def ElectromagneticSignal {
        attribute frequency : FrequencyValue;
        attribute power : PowerValue;
        attribute phase : Real;
    }
    
    item def TissueResponse {
        attribute impedance : Real;
        attribute resonanceFrequency : FrequencyValue;
        attribute amplitude : Real;
    }
    
    item def DiagnosticResult {
        attribute anomalyScore : Real;
        attribute confidence : Real;
        attribute tissueCharacterization : String;
    }
    
    port def SignalEmissionPort {
        out signal : ElectromagneticSignal;
    }
    
    port def ResponseReceptionPort {
        in response : TissueResponse;
    }
    
    port def DataPort {
        out data : TissueResponse;
    }
    
    port def ControlPort {
        in command : ScanCommand;
        out status : String;
    }
    
    port def PowerPort {
        out voltage : Real;
        out current : ElectricCurrentValue;
    }
    
    port def DisplayPort {
        in result : DiagnosticResult;
    }
    
    part def ProbeHead {
        doc /* Electromagnetic probe that emits low-power signals and detects tissue resonance responses. */
        
        attribute emissionFrequencyRange : FrequencyValue[2];
        attribute maxEmissionPower : PowerValue;
        attribute sensitivity : Real;
        
        port emissionPort : SignalEmissionPort;
        port receptionPort : ResponseReceptionPort;
        port powerIn : PowerPort;
    }
    
    part def SignalGenerator {
        doc /* Generates controlled electromagnetic signals at specified frequencies. */
        
        attribute baseFrequency : FrequencyValue;
        attribute frequencyStep : FrequencyValue;
        attribute outputPower : PowerValue;
        
        port controlIn;
        port signalOut : SignalEmissionPort;
        port powerIn : PowerPort;
    }
    
    part def ResponseAnalyzer {
        doc /* Analyzes tissue response patterns to identify electromagnetic anomalies. */
        
        attribute samplingRate : FrequencyValue;
        attribute analysisAlgorithm : String;
        attribute baselineThreshold : Real;
        
        port dataIn : DataPort;
        port resultOut;
        port powerIn : PowerPort;
    }
    
    part def ControlProcessor {
        doc /* Coordinates scan sequences and manages system operation. */
        
        attribute processingSpeed : FrequencyValue;
        attribute memoryCapacity : Real;
        
        port commandIn : ControlPort;
        port probeControl;
        port analyzerControl;
        port powerIn : PowerPort;
    }
    
    part def DisplayInterface {
        doc /* Presents diagnostic results to the operator. */
        
        attribute screenResolution : String;
        attribute updateRate : FrequencyValue;
        
        port dataIn : DisplayPort;
        port powerIn : PowerPort;
    }
    
    part def BatteryPack {
        doc /* Provides portable power for the device. */
        
        attribute capacity : Real;
        attribute voltage : Real;
        attribute chargeLevel : Real;
        
        port powerOut1 : PowerPort;
        port powerOut2 : PowerPort;
        port powerOut3 : PowerPort;
        port powerOut4 : PowerPort;
        port powerOut5 : PowerPort;
    }
    
    part def TrimprobDevice {
        doc /* A non-invasive medical diagnostic device that detects electromagnetic 
               anomalies in biological tissue by emitting low-power electromagnetic signals 
               and analyzing resonance patterns to identify potential pathological conditions. */
        
        attribute deviceId : String;
        attribute calibrationDate : String;
        attribute operatingMode : String;
        
        part probe : ProbeHead {
            attribute emissionFrequencyRange = (10.0[Hz], 500000.0[Hz]);
            attribute maxEmissionPower = 0.001[W];
            attribute sensitivity = 0.95;
        }
        
        part generator : SignalGenerator {
            attribute baseFrequency = 10000.0[Hz];
            attribute frequencyStep = 5000.0[Hz];
            attribute outputPower = 0.0008[W];
        }
        
        part analyzer : ResponseAnalyzer {
            attribute samplingRate = 1000.0[Hz];
            attribute analysisAlgorithm = "Resonance Pattern Recognition";
            attribute baselineThreshold = 0.75;
        }
        
        part controller : ControlProcessor {
            attribute processingSpeed = 100000000.0[Hz];
            attribute memoryCapacity = 512.0;
        }
        
        part display : DisplayInterface {
            attribute screenResolution = "800x600";
            attribute updateRate = 30.0[Hz];
        }
        
        part battery : BatteryPack {
            attribute capacity = 3000.0;
            attribute voltage = 12.0;
            attribute chargeLevel = 100.0;
        }
        
        port operatorInterface : ControlPort;
        
        connection generatorToProbe connect generator.signalOut to probe.emissionPort;
        connection probeToAnalyzer connect probe.receptionPort to analyzer.dataIn;
        connection controllerToGenerator connect controller.probeControl to generator.controlIn;
        connection controllerToAnalyzer connect controller.analyzerControl to analyzer.resultOut;
        connection analyzerToDisplay connect analyzer.resultOut to display.dataIn;
        connection operatorToController connect operatorInterface to controller.commandIn;
        
        connection powerToProbe connect battery.powerOut1 to probe.powerIn;
        connection powerToGenerator connect battery.powerOut2 to generator.powerIn;
        connection powerToAnalyzer connect battery.powerOut3 to analyzer.powerIn;
        connection powerToController connect battery.powerOut4 to controller.powerIn;
        connection powerToDisplay connect battery.powerOut5 to display.powerIn;
    }
    
    action def CalibrateDevice {
        in referenceSignal : ElectromagneticSignal;
        out calibrationData : Real;
    }
    
    action def EmitSignal {
        in frequency : FrequencyValue;
        in power : PowerValue;
        out emittedSignal : ElectromagneticSignal;
    }
    
    action def MeasureResponse {
        in duration : TimeValue;
        out tissueResponse : TissueResponse;
    }
    
    action def AnalyzePattern {
        in responses : TissueResponse[*];
        out diagnosticResult : DiagnosticResult;
    }
    
    action def DisplayResult {
        in result : DiagnosticResult;
    }
    
    action def PerformDiagnosticScan {
        in startFrequency : FrequencyValue;
        in endFrequency : FrequencyValue;
        in frequencyStep : FrequencyValue;
        in emissionPower : PowerValue;
        in measurementDuration : TimeValue;
        out finalResult : DiagnosticResult;
        
        private attribute currentFrequency : FrequencyValue := startFrequency;
        private attribute collectedResponses : TissueResponse[*] := ();
        
        first start;
        
        then action calibrate : CalibrateDevice {
            out calibrationData;
        }
        
        then merge scanLoop;
        
        action scanLoop {
            decide;
                if currentFrequency <= endFrequency then emitAndMeasure;
                if currentFrequency > endFrequency then analyzeResults;
        }
        
        action emitAndMeasure {
            action emit : EmitSignal {
                in frequency = currentFrequency;
                in power = emissionPower;
                out emittedSignal;
            }
            
            then action measure : MeasureResponse {
                in duration = measurementDuration;
                out tissueResponse;
            }
            
            then assign collectedResponses := collectedResponses;
            then assign currentFrequency := currentFrequency + frequencyStep;
        }
        then scanLoop;
        
        action analyzeResults : AnalyzePattern {
            in responses = collectedResponses;
            out diagnosticResult;
        }
        
        then action displayResults : DisplayResult {
            in result = analyzeResults.diagnosticResult;
        }
        
        then assign finalResult := analyzeResults.diagnosticResult;
        then done;
    }
    
    state def DeviceOperationalStates {
        entry; then off;
        
        state off;
        
        transition off_to_initializing
            first off
            accept powerOn : PowerOn
            then initializing;
        
        state initializing {
            do action initialize {
                action selfTest;
                then action loadCalibration;
            }
        }
        
        transition initializing_to_ready
            first initializing
            then ready;
        
        state ready;
        
        transition ready_to_calibrating
            first ready
            accept calibrationCmd : CalibrationCommand
            then calibrating;
        
        state calibrating {
            do action performCalibration : CalibrateDevice;
        }
        
        transition calibrating_to_ready
            first calibrating
            then ready;
        
        transition ready_to_scanning
            first ready
            accept scanCmd : ScanCommand
            then scanning;
        
        state scanning {
            do action executeScan : PerformDiagnosticScan {
                in startFrequency = 10000.0[Hz];
                in endFrequency = 500000.0[Hz];
                in frequencyStep = 5000.0[Hz];
                in emissionPower = 0.0008[W];
                in measurementDuration = 0.1[s];
            }
        }
        
        transition scanning_to_resultsReady
            first scanning
            accept scanComplete : ScanComplete
            then resultsReady;
        
        state resultsReady;
        
        transition resultsReady_to_ready
            first resultsReady
            accept acknowledge
            then ready;
        
        transition ready_to_off
            first ready
            accept powerOff : PowerOff
            then off;
    }
    
    part trimprobSystem : TrimprobDevice {
        perform action diagnosticOperation : PerformDiagnosticScan;
        exhibit state operationalBehavior : DeviceOperationalStates;
    }
    
    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;
    requirement def AccuracyRequirement;
    requirement def UsabilityRequirement;
    
    requirement <'TRIM-REQ-001'> emissionPowerLimit : SafetyRequirement {
        doc /* The device shall not emit electromagnetic power exceeding 1 milliwatt 
               to ensure patient safety during diagnostic procedures. */
        
        subject device : TrimprobDevice;
        
        require constraint {
            device.probe.maxEmissionPower <= 0.001[W]
        }
    }
    
    requirement <'TRIM-REQ-002'> scanDuration : PerformanceRequirement {
        doc /* A complete diagnostic scan shall be completed within 120 seconds 
               from initiation to result display. */
        
        subject device : TrimprobDevice;
    }
    
    requirement <'TRIM-REQ-003'> frequencyRange : PerformanceRequirement {
        doc /* The device shall scan electromagnetic frequencies from 10 kHz to 500 kHz 
               to detect tissue resonance patterns. */
        
        subject device : TrimprobDevice;
        
        require constraint {
            device.probe.emissionFrequencyRange[1] == 10000.0[Hz] and
            device.probe.emissionFrequencyRange[2] == 500000.0[Hz]
        }
    }
    
    requirement <'TRIM-REQ-004'> detectionAccuracy : AccuracyRequirement {
        doc /* The device shall achieve a minimum sensitivity of 95% in detecting 
               electromagnetic anomalies in biological tissue. */
        
        subject device : TrimprobDevice;
        
        require constraint {
            device.probe.sensitivity >= 0.95
        }
    }
    
    requirement <'TRIM-REQ-005'> batteryLife : PerformanceRequirement {
        doc /* The device shall operate for a minimum of 4 hours of continuous scanning 
               on a fully charged battery. */
        
        subject device : TrimprobDevice;
        
        require constraint {
            device.battery.capacity >= 3000.0
        }
    }
    
    requirement <'TRIM-REQ-006'> displayUpdate : UsabilityRequirement {
        doc /* The display shall update diagnostic results at a minimum rate of 30 Hz 
               to provide real-time feedback to the operator. */
        
        subject device : TrimprobDevice;
        
        require constraint {
            device.display.updateRate >= 30.0[Hz]
        }
    }
    
    requirement <'TRIM-SYS-001'> trimprobSystemRequirement {
        doc /* The Trimprob system shall provide non-invasive electromagnetic diagnostic 
               capability for detecting tissue anomalies through resonance pattern analysis, 
               operating safely within specified power limits while delivering accurate 
               results with real-time display feedback. */
        
        subject system : TrimprobDevice;
        
        require emissionPowerLimit;
        require scanDuration;
        require frequencyRange;
        require detectionAccuracy;
        require batteryLife;
        require displayUpdate;
    }
}

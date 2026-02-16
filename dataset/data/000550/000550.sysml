package BiothesiometrySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VibrationAmplitude :> ISQ::LengthValue {
        doc /* Displacement amplitude of vibration stimulus in micrometers */
    }
    
    attribute def VibrationFrequency :> ISQ::FrequencyValue {
        doc /* Frequency of vibration stimulus, typically 120 Hz */
    }
    
    attribute def PerceptionThreshold :> VibrationAmplitude {
        doc /* Minimum vibration amplitude detected by patient */
    }
    
    attribute def VoltageLevel :> ISQ::PowerValue {
        doc /* Control voltage proportional to vibration amplitude */
    }
    
    attribute def TestDuration :> ISQ::TimeValue {
        doc /* Duration of individual stimulus application */
    }
    
    attribute def PatientResponse :> Boolean {
        doc /* Patient indication of vibration perception */
    }
    
    attribute def NeuropathyScore :> Real {
        doc /* Quantitative assessment of peripheral nerve function */
    }
    
    item def TestProtocol {
        attribute initialAmplitude : VibrationAmplitude;
        attribute amplitudeStep : VibrationAmplitude;
        attribute maximumAmplitude : VibrationAmplitude;
        attribute operatingFrequency : VibrationFrequency;
        attribute stimulusDuration : TestDuration;
        attribute numberOfTrials : Integer;
    }
    
    item def TestResult {
        attribute thresholdAmplitude : PerceptionThreshold;
        attribute thresholdVoltage : VoltageLevel;
        attribute neuropathyScore : NeuropathyScore;
        attribute testLocation : String;
        attribute timestamp : ISQ::TimeValue;
    }
    
    port def VibrationOutputPort {
        out vibrationAmplitude : VibrationAmplitude;
        out vibrationFrequency : VibrationFrequency;
    }
    
    port def ControlInputPort {
        in amplitudeCommand : VibrationAmplitude;
        in frequencyCommand : VibrationFrequency;
        out statusFeedback : Boolean;
    }
    
    port def ResponseInputPort {
        in patientResponse : PatientResponse;
    }
    
    port def DisplayOutputPort {
        out currentAmplitude : VibrationAmplitude;
        out currentVoltage : VoltageLevel;
        out thresholdResult : PerceptionThreshold;
        out scoreResult : NeuropathyScore;
    }
    
    port def PowerPort {
        in powerSupply : VoltageLevel;
    }
    
    action def GenerateVibration {
        in frequency : VibrationFrequency;
        in amplitude : VibrationAmplitude;
        in duration : TestDuration;
        out vibrationOutput : VibrationAmplitude;
    }
    
    action def MonitorPatientResponse {
        in responseButton : PatientResponse;
        in timeWindow : TestDuration;
        out responseDetected : Boolean;
        out responseTime : ISQ::TimeValue;
    }
    
    action def IncrementAmplitude {
        in currentAmplitude : VibrationAmplitude;
        in stepSize : VibrationAmplitude;
        in maximumLimit : VibrationAmplitude;
        out newAmplitude : VibrationAmplitude;
        out limitReached : Boolean;
    }
    
    action def CalculateThreshold {
        in responseHistory : PatientResponse[*];
        in amplitudeHistory : VibrationAmplitude[*];
        in protocol : TestProtocol;
        out threshold : PerceptionThreshold;
        out confidence : Real;
    }
    
    action def AssessNeuropathy {
        in threshold : PerceptionThreshold;
        in normalThreshold : PerceptionThreshold;
        in patientAge : Real;
        in testLocation : String;
        out score : NeuropathyScore;
        out interpretation : String;
    }
    
    action def ConvertAmplitudeToVoltage {
        in amplitude : VibrationAmplitude;
        out voltage : VoltageLevel;
    }
    
    action def PerformThresholdTest {
        in protocol : TestProtocol;
        in testLocation : String;
        in normalReference : PerceptionThreshold;
        out result : TestResult;
        
        private attribute currentAmplitude : VibrationAmplitude := protocol.initialAmplitude;
        private attribute responseHistory : PatientResponse[*] := ();
        private attribute amplitudeHistory : VibrationAmplitude[*] := ();
        private attribute trialCount : Integer := 0;
        private attribute thresholdDetected : Boolean := false;
        private attribute safetyLimitReached : Boolean := false;
        
        first start;
        then merge beginNextTrial;
        
        action evaluateConditions {
            decide;
                if thresholdDetected or safetyLimitReached or trialCount >= protocol.numberOfTrials then finalizeTest;
                if not thresholdDetected and not safetyLimitReached and trialCount < protocol.numberOfTrials then deliverStimulus;
        }
        
        action deliverStimulus : GenerateVibration {
            in frequency = protocol.operatingFrequency;
            in amplitude = currentAmplitude;
            in duration = protocol.stimulusDuration;
            out vibrationOutput;
        }
        
        then action captureResponse : MonitorPatientResponse {
            in responseButton;
            in timeWindow = protocol.stimulusDuration;
            out responseDetected;
            out responseTime;
        }
        
        then action recordData {
            then assign responseHistory := responseHistory->including(captureResponse.responseDetected);
            then assign amplitudeHistory := amplitudeHistory->including(currentAmplitude);
            then assign trialCount := trialCount + 1;
        }
        
        then action updateAmplitude : IncrementAmplitude {
            in currentAmplitude = currentAmplitude;
            in stepSize = protocol.amplitudeStep;
            in maximumLimit = protocol.maximumAmplitude;
            out newAmplitude;
            out limitReached;
        }
        
        then action processUpdate {
            then assign currentAmplitude := updateAmplitude.newAmplitude;
            then assign safetyLimitReached := updateAmplitude.limitReached;
            decide;
                if captureResponse.responseDetected then markThreshold;
                if not captureResponse.responseDetected then beginNextTrial;
        }
        
        action markThreshold {
            then assign thresholdDetected := true;
        }
        then beginNextTrial;
        
        action finalizeTest {
            action computeThreshold : CalculateThreshold {
                in responseHistory = responseHistory;
                in amplitudeHistory = amplitudeHistory;
                in protocol = protocol;
                out threshold;
                out confidence;
            }
            
            then action convertToVoltage : ConvertAmplitudeToVoltage {
                in amplitude = computeThreshold.threshold;
                out voltage;
            }
            
            then action evaluateNeuropathy : AssessNeuropathy {
                in threshold = computeThreshold.threshold;
                in normalThreshold = normalReference;
                in patientAge;
                in testLocation = testLocation;
                out score;
                out interpretation;
            }
            
            then action assembleResult {
                then assign result := TestResult {
                    :>> thresholdAmplitude = computeThreshold.threshold;
                    :>> thresholdVoltage = convertToVoltage.voltage;
                    :>> neuropathyScore = evaluateNeuropathy.score;
                    :>> testLocation = testLocation;
                };
            }
        }
        
        then done;
    }
    
    part def VibrationGenerator {
        doc /* Electromagnetic transducer generating controlled vibration */
        
        port controlInput : ControlInputPort;
        port vibrationOutput : VibrationOutputPort;
        port power : PowerPort;
        
        attribute operatingFrequency : VibrationFrequency;
        attribute currentAmplitude : VibrationAmplitude;
        attribute maxAmplitude : VibrationAmplitude;
    }
    
    part def VibratingProbe {
        doc /* Handheld probe with vibrating tip for patient contact */
        
        port vibrationInput : VibrationOutputPort;
        
        attribute probeWeight : ISQ::MassValue;
        attribute contactArea : ISQ::AreaValue;
        attribute tipMaterial : String;
    }
    
    part def ControlModule {
        doc /* Electronic control unit managing test protocol and data */
        
        port generatorControl : ControlInputPort;
        port responseInput : ResponseInputPort;
        port displayOutput : DisplayOutputPort;
        port power : PowerPort;
        
        attribute activeProtocol : TestProtocol;
        attribute testResults : TestResult[*];
        
        perform action executeTest : PerformThresholdTest;
    }
    
    part def ResponseButton {
        doc /* Patient-operated button for indicating vibration perception */
        
        port responseOutput : ResponseInputPort;
        
        attribute buttonState : PatientResponse;
        attribute pressureThreshold : ISQ::ForceValue;
    }
    
    part def DisplayPanel {
        doc /* Visual display showing test parameters and results */
        
        port dataInput : DisplayOutputPort;
        
        attribute screenType : String;
        attribute displayResolution : String;
        attribute backlightEnabled : Boolean;
    }
    
    part def PowerSupply {
        doc /* Electrical power source for device operation */
        
        port powerOutput : PowerPort;
        
        attribute inputVoltage : VoltageLevel;
        attribute outputVoltage : VoltageLevel;
        attribute batteryCapacity : ISQ::EnergyValue;
    }
    
    part def BiothesiometerDevice {
        doc /* Complete biothesiometry device for measuring vibration perception threshold */
        
        part generator : VibrationGenerator {
            attribute :>> operatingFrequency = 120.0 [SI::Hz];
            attribute :>> maxAmplitude = 50.0 [SI::m];
        }
        
        part probe : VibratingProbe {
            attribute :>> probeWeight = 200.0 [SI::g];
            attribute :>> contactArea = 1.0 [SI::m2];
            attribute :>> tipMaterial = "rubber";
        }
        
        part controller : ControlModule {
            attribute :>> activeProtocol : TestProtocol {
                :>> initialAmplitude = 0.0 [SI::m];
                :>> amplitudeStep = 0.5 [SI::m];
                :>> maximumAmplitude = 50.0 [SI::m];
                :>> operatingFrequency = 120.0 [SI::Hz];
                :>> stimulusDuration = 2.0 [SI::s];
                :>> numberOfTrials = 15;
            }
        }
        
        part responseButton : ResponseButton {
            attribute :>> pressureThreshold = 2.0 [SI::N];
        }
        
        part display : DisplayPanel {
            attribute :>> screenType = "LCD";
            attribute :>> displayResolution = "128x64";
            attribute :>> backlightEnabled = true;
        }
        
        part powerSupply : PowerSupply {
            attribute :>> batteryCapacity = 2000.0 [SI::J];
        }
        
        connection controlToGenerator connect controller.generatorControl to generator.controlInput;
        connection generatorToProbe connect generator.vibrationOutput to probe.vibrationInput;
        connection buttonToController connect responseButton.responseOutput to controller.responseInput;
        connection controllerToDisplay connect controller.displayOutput to display.dataInput;
        connection powerToGenerator connect powerSupply.powerOutput to generator.power;
        connection powerToController connect powerSupply.powerOutput to controller.power;
    }
    
    part biothesiometer : BiothesiometerDevice {
        doc /* Biothesiometry system for quantitative assessment of peripheral nerve function 
               by measuring vibration perception threshold */
        
        perform action conductAssessment : PerformThresholdTest {
            in protocol = controller.activeProtocol;
            in testLocation = "great toe";
            in normalReference = 15.0 [SI::m];
            out result;
        }
        
        part controller : ControlModule {
            perform conductAssessment;
        }
        
        part generator : VibrationGenerator {
            perform conductAssessment.deliverStimulus;
        }
        
        part responseButton : ResponseButton {
            perform conductAssessment.captureResponse;
        }
    }
    
    requirement def AccuracyRequirement {
        doc /* Requirement for measurement accuracy and precision */
        subject device : BiothesiometerDevice;
        require constraint {
            doc /* Vibration amplitude accuracy shall be within ±5% of commanded value */
        }
    }
    
    requirement def FrequencyStabilityRequirement {
        doc /* Requirement for vibration frequency stability */
        subject device : BiothesiometerDevice;
        require constraint {
            doc /* Operating frequency shall be 120 Hz ± 2 Hz throughout test */
        }
    }
    
    requirement def SafetyRequirement {
        doc /* Patient safety requirement for maximum vibration exposure */
        subject device : BiothesiometerDevice;
        require constraint {
            doc /* Maximum vibration amplitude shall not exceed 50 micrometers */
        }
    }
    
    requirement def RepeatabilityRequirement {
        doc /* Requirement for test-retest repeatability */
        subject device : BiothesiometerDevice;
        require constraint {
            doc /* Coefficient of variation for repeated measurements shall be less than 10% */
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* Requirement for patient response detection timing */
        subject device : BiothesiometerDevice;
        require constraint {
            doc /* System shall detect patient response within 100 milliseconds of button press */
        }
    }
    
    requirement <'BIO-SYS-001'> biothesiometerSystemRequirement {
        doc /* The biothesiometer system shall measure vibration perception threshold 
               to quantitatively assess peripheral nerve function by applying controlled 
               vibration stimuli of incrementally increasing amplitude until patient 
               perception is detected, thereby enabling early detection and monitoring 
               of peripheral neuropathy */
        
        subject biothesiometerSystem : BiothesiometerDevice;
        
        require measurementAccuracy : AccuracyRequirement;
        require frequencyStability : FrequencyStabilityRequirement;
        require patientSafety : SafetyRequirement;
        require testRepeatability : RepeatabilityRequirement;
        require responseDetection : ResponseTimeRequirement;
    }
}

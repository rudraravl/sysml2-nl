package PulsoconSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PulseFrequency :> FrequencyValue {
        doc /* Frequency of pulse generation in Hz */
    }
    
    attribute def PulseAmplitude :> ISQ::VoltageValue {
        doc /* Amplitude of generated pulses */
    }
    
    attribute def PulseDuration :> DurationValue {
        doc /* Duration of individual pulses */
    }
    
    attribute def SignalQuality :> Real {
        doc /* Quality metric of output signal, 0.0 to 1.0 */
    }
    
    attribute def OperatingMode {
        doc /* Current operating mode of the system */
    }
    
    attribute def SystemReady;
    attribute def StartCommand;
    attribute def StopCommand;
    attribute def ResetCommand;
    attribute def ShutdownCommand;
    attribute def FaultDetected;
    
    item def PulseWaveform {
        attribute frequency : PulseFrequency;
        attribute amplitude : PulseAmplitude;
        attribute duration : PulseDuration;
        attribute timestamp : TimeValue;
    }
    
    item def ControlParameters {
        attribute mode : OperatingMode;
        attribute targetFrequency : PulseFrequency;
        attribute targetAmplitude : PulseAmplitude;
        attribute targetDuration : PulseDuration;
    }
    
    item def FeedbackData {
        attribute measuredFrequency : PulseFrequency;
        attribute measuredAmplitude : PulseAmplitude;
        attribute signalQuality : SignalQuality;
        attribute errorCode : Integer;
    }
    
    port def PulseOutputPort {
        out waveform : PulseWaveform;
    }
    
    port def ControlInputPort {
        in parameters : ControlParameters;
    }
    
    port def FeedbackOutputPort {
        out feedback : FeedbackData;
    }
    
    port def PowerInputPort {
        in voltage : ISQ::VoltageValue;
        in current : ElectricCurrentValue;
    }
    
    part def WaveformGenerator {
        attribute currentFrequency : PulseFrequency;
        attribute currentAmplitude : PulseAmplitude;
        attribute currentDuration : PulseDuration;
        
        port output : PulseOutputPort;
        port powerIn : PowerInputPort;
        
        perform action generateWaveform {
            in freq : PulseFrequency;
            in amp : PulseAmplitude;
            in dur : PulseDuration;
            out waveform : PulseWaveform;
        }
    }
    
    part def ControlProcessor {
        attribute activeMode : OperatingMode;
        attribute setpointFrequency : PulseFrequency;
        attribute setpointAmplitude : PulseAmplitude;
        
        port controlOut : ~ControlInputPort;
        port feedbackIn : ~FeedbackOutputPort;
        
        perform action processControlLoop {
            in feedback : FeedbackData;
            in mode : OperatingMode;
            out control : ControlParameters;
        }
    }
    
    part def SignalAnalyzer {
        attribute qualityThreshold : SignalQuality;
        attribute frequencyTolerance : PulseFrequency;
        attribute currentQuality : SignalQuality;
        
        port feedbackOut : FeedbackOutputPort;
        
        perform action analyzeSignal {
            in waveform : PulseWaveform;
            out feedback : FeedbackData;
        }
    }
    
    part def PowerManagement {
        attribute inputVoltage : ISQ::VoltageValue;
        attribute inputCurrent : ElectricCurrentValue;
        attribute outputPower : PowerValue;
        attribute efficiency : Real;
        
        port powerOut : ~PowerInputPort;
        
        perform action regulatePower {
            in demand : PowerValue;
            out voltage : ISQ::VoltageValue;
            out current : ElectricCurrentValue;
        }
    }
    
    part def SafetyMonitor {
        attribute maxTemperature : TemperatureValue;
        attribute maxCurrent : ElectricCurrentValue;
        attribute faultDetected : Boolean;
        
        perform action monitorSafety {
            in temperature : TemperatureValue;
            in current : ElectricCurrentValue;
            out shutdownRequired : Boolean;
        }
    }
    
    state def PulsoconOperatingStates {
        entry; then initialization;
        
        state initialization {
            entry action performSelfTest;
            do action calibrateSensors;
        }
        
        transition init_to_standby
            first initialization
            accept sysReady : SystemReady
            then standby;
        
        state standby {
            entry action enterLowPowerMode;
        }
        
        transition standby_to_active
            first standby
            accept startCmd : StartCommand
            then active;
        
        state active {
            entry action activateGeneration;
            
            state normalOperation {
                do action continuousGeneration {
                    action generatePulses;
                    then action measureOutput;
                    then action adjustParameters;
                }
            }
            
            state adaptiveMode {
                do action adaptiveGeneration {
                    action monitorFeedback;
                    then action optimizeWaveform;
                    then action updateGeneration;
                }
            }
            
            state synchronizedMode {
                do action synchronizedGeneration {
                    action waitForTrigger;
                    then action generateSyncPulse;
                    then action verifyTiming;
                }
            }
        }
        
        state monitoring {
            do action diagnosticCheck {
                action checkWaveformQuality;
                then action checkPowerLevels;
                then action checkTiming;
            }
            
            action correctiveAction {
                action adjustAmplitude;
                then action adjustFrequency;
                then action verifyCorrection;
            }
        }
        
        transition monitoring_to_active
            first monitoring
            then active;
        
        transition to_fault
            first active
            accept faultEvt : FaultDetected
            then fault;
        
        state fault {
            entry action logFault;
            do action isolateIssue;
        }
        
        transition fault_to_standby
            first fault
            accept resetCmd : ResetCommand
            then standby;
        
        transition active_to_standby
            first active
            accept stopCmd : StopCommand
            then standby;
        
        state shutdown {
            entry action safeShutdown;
        }
        
        transition standby_to_shutdown
            first standby
            accept shutdownCmd : ShutdownCommand
            then shutdown;
        
        transition active_to_shutdown
            first active
            accept shutdownCmd : ShutdownCommand
            then shutdown;
        
        transition monitoring_to_shutdown
            first monitoring
            accept shutdownCmd : ShutdownCommand
            then shutdown;
        
        transition fault_to_shutdown
            first fault
            accept shutdownCmd : ShutdownCommand
            then shutdown;
    }
    
    action def PerformSelfTest {
        out testResult : Boolean;
        out diagnosticData : String;
    }
    
    action def CalibrateSensors {
        out calibrationComplete : Boolean;
    }
    
    action def GeneratePulses {
        in parameters : ControlParameters;
        out pulseSequence : PulseWaveform[*];
    }
    
    action def MeasureOutput {
        in waveform : PulseWaveform;
        out measurements : FeedbackData;
    }
    
    action def AdjustParameters {
        in feedback : FeedbackData;
        in target : ControlParameters;
        out adjusted : ControlParameters;
    }
    
    action def OptimizeWaveform {
        in currentWaveform : PulseWaveform;
        in targetQuality : SignalQuality;
        out optimizedParameters : ControlParameters;
    }
    
    requirement def PulsoconFunctionalRequirements {
        doc /* Functional requirements for the Pulsocon system */
        
        requirement <'FR-1'> pulseGenerationRequirement {
            doc /* The system shall generate precise pulse waveforms at specified frequencies */
            subject pulsocon : Pulsocon;
            require constraint {
                pulsocon.generator.currentFrequency >= 1.0[SI::Hz] and
                pulsocon.generator.currentFrequency <= 10000.0[SI::Hz]
            }
        }
        
        requirement <'FR-2'> amplitudeControlRequirement {
            doc /* The system shall control pulse amplitude within specified range */
            subject pulsocon : Pulsocon;
            require constraint {
                pulsocon.generator.currentAmplitude >= 0.1[SI::V] and
                pulsocon.generator.currentAmplitude <= 50.0[SI::V]
            }
        }
        
        requirement <'FR-3'> feedbackResponseRequirement {
            doc /* The system shall respond to feedback within 5 milliseconds */
            subject pulsocon : Pulsocon;
        }
        
        requirement <'FR-4'> signalQualityRequirement {
            doc /* The system shall maintain signal quality above 0.95 */
            subject pulsocon : Pulsocon;
            require constraint {
                pulsocon.analyzer.qualityThreshold >= 0.95
            }
        }
    }
    
    requirement def PulsoconPerformanceRequirements {
        doc /* Performance requirements for the Pulsocon system */
        
        requirement <'PR-1'> frequencyAccuracyRequirement {
            doc /* Frequency accuracy shall be within 0.1% of target */
        }
        
        requirement <'PR-2'> amplitudeStabilityRequirement {
            doc /* Amplitude stability shall be within 1% over operating range */
        }
        
        requirement <'PR-3'> powerEfficiencyRequirement {
            doc /* Power conversion efficiency shall exceed 85% */
        }
    }
    
    requirement def PulsoconSafetyRequirements {
        doc /* Safety requirements for the Pulsocon system */
        
        requirement <'SR-1'> overCurrentProtectionRequirement {
            doc /* System shall shut down if current exceeds safe limits */
        }
        
        requirement <'SR-2'> thermalProtectionRequirement {
            doc /* System shall shut down if temperature exceeds 85 degrees Celsius */
        }
    }
    
    part def Pulsocon {
        part generator : WaveformGenerator;
        part controller : ControlProcessor;
        part analyzer : SignalAnalyzer;
        part powerMgmt : PowerManagement;
        part safety : SafetyMonitor;
    }
    
    part pulsocon : Pulsocon {
        doc /* 
            The Pulsocon is a precision pulse waveform generation and control system.
            
            Its primary function is to generate highly accurate and stable pulse waveforms
            with programmable frequency, amplitude, and duration characteristics. The system
            continuously monitors the generated output through an integrated feedback loop,
            automatically adjusting generation parameters to maintain precise waveform
            characteristics and optimal signal quality.
            
            The Pulsocon accepts control parameters that specify the desired operating mode,
            target pulse frequency, amplitude, and duration. Based on these inputs and
            real-time feedback from signal analysis, the control processor dynamically
            adjusts the waveform generator to ensure stable, accurate pulse generation
            across varying operating conditions.
            
            The system operates through multiple states including initialization, standby,
            active generation, monitoring, and fault handling, ensuring reliable operation
            and safe shutdown in case of detected anomalies.
        */
        
        part redefines generator {
            attribute :>> currentFrequency = 1000.0[SI::Hz];
            attribute :>> currentAmplitude = 5.0[SI::V];
            attribute :>> currentDuration = 0.5[SI::ms];
        }
        
        part redefines controller {
            attribute :>> setpointFrequency = 1000.0[SI::Hz];
            attribute :>> setpointAmplitude = 5.0[SI::V];
        }
        
        part redefines analyzer {
            attribute :>> qualityThreshold = 0.95;
            attribute :>> frequencyTolerance = 1.0[SI::Hz];
            attribute :>> currentQuality = 0.98;
        }
        
        part redefines powerMgmt {
            attribute :>> inputVoltage = 24.0[SI::V];
            attribute :>> inputCurrent = 5.0[SI::A];
            attribute :>> outputPower = 100.0[SI::W];
            attribute :>> efficiency = 0.90;
        }
        
        part redefines safety {
            attribute :>> maxTemperature = 85.0[SI::'°C'];
            attribute :>> maxCurrent = 10.0[SI::A];
            attribute :>> faultDetected = false;
        }
        
        connect controller.controlOut to generator.~controlIn;
        connect analyzer.feedbackOut to controller.feedbackIn;
        connect powerMgmt.powerOut to generator.powerIn;
        
        perform action operatePulsocon {
            first start;
            then action initialize : PerformSelfTest {
                out testResult;
                out diagnosticData;
            }
            then decide;
                if initialize.testResult == true then calibrate;
                if initialize.testResult == false then fault;
            
            action calibrate : CalibrateSensors {
                out calibrationComplete;
            }
            then mainLoop;
            
            merge mainLoop;
            action mainLoop {
                action receiveControl {
                    out controlParams : ControlParameters;
                }
                
                flow receiveControl.controlParams to generateOutput.parameters;
                
                action generateOutput : GeneratePulses {
                    in parameters : ControlParameters;
                    out pulseSequence : PulseWaveform[*];
                }
                
                flow generateOutput.pulseSequence[1] to measureSignal.waveform;
                
                action measureSignal : MeasureOutput {
                    in waveform : PulseWaveform;
                    out measurements : FeedbackData;
                }
                
                flow measureSignal.measurements to adjustControl.feedback;
                flow receiveControl.controlParams to adjustControl.target;
                
                action adjustControl : AdjustParameters {
                    in feedback : FeedbackData;
                    in target : ControlParameters;
                    out adjusted : ControlParameters;
                }
                
                then decide;
                    if adjustControl.feedback.signalQuality >= 0.95 then mainLoop;
                    if adjustControl.feedback.signalQuality < 0.95 then optimize;
            }
            
            action optimize : OptimizeWaveform {
                in currentWaveform : PulseWaveform;
                in targetQuality : SignalQuality;
                out optimizedParameters : ControlParameters;
            }
            then mainLoop;
            
            action fault {
                doc /* Handle fault condition and prepare for recovery */
            }
            then done;
        }
        
        exhibit state operatingState : PulsoconOperatingStates;
        
        satisfy pulsoconSystemRequirements;
    }
    
    requirement pulsoconSystemRequirements : PulsoconFunctionalRequirements {
        assume constraint adequatePower {
            doc /* Adequate power supply is available for operation */
            pulsocon.powerMgmt.inputVoltage >= 20.0[SI::V] and
            pulsocon.powerMgmt.inputCurrent >= 3.0[SI::A]
        }
        
        assume constraint operatingTemperature {
            doc /* Operating temperature is within acceptable range */
            pulsocon.safety.maxTemperature <= 85.0[SI::'°C']
        }
        
        require pulseGenerationRequirement;
        require amplitudeControlRequirement;
        require feedbackResponseRequirement;
        require signalQualityRequirement;
    }
}

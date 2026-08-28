package Pulsocon {
    private import ScalarValues::*;
    
    attribute def FrequencyValue :> Real;
    attribute def AmplitudeValue :> Real;
    attribute def DurationValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def CurrentValue :> Real;
    attribute def QualityValue :> Real;
    
    item def StartCommand;
    item def StopCommand;
    item def ResetCommand;
    item def ExternalTrigger;
    item def AdaptiveModeCommand;
    item def ContinuousModeCommand;
    item def SynchronizedModeCommand;
    item def QualityAlert;
    item def OverCurrentAlert;
    item def OverTempAlert;
    
    item def TargetParameters {
        attribute targetFrequency : FrequencyValue;
        attribute targetAmplitude : AmplitudeValue;
        attribute targetDuration : DurationValue;
    }
    
    item def WaveformSettings {
        attribute frequency : FrequencyValue;
        attribute amplitude : AmplitudeValue;
        attribute duration : DurationValue;
    }
    
    item def MeasurementFeedback {
        attribute measuredFrequency : FrequencyValue;
        attribute measuredAmplitude : AmplitudeValue;
        attribute signalQuality : QualityValue;
    }
    
    item def FaultRecord {
        attribute description : String;
    }
    
    port def CommandPort;
    port def TriggerPort;
    port def SettingsPort;
    port def FeedbackPort;
    port def PulseOutputPort;
    port def AlertPort;
    port def PowerPort;
    
    action def GeneratePulse;
    action def MeasureSignal {
        out feedback : MeasurementFeedback;
    }
    action def AdjustSettings;
    action def OptimizeWaveform;
    action def PerformSelfTest;
    action def CalibrateSensors;
    action def LogFault;
    action def ShutdownSequence;
    
    action def AdaptiveOperation {
        action optimize : OptimizeWaveform;
        action generate : GeneratePulse;
    }
    
    action def InitializeSystem {
        action selfTest : PerformSelfTest;
        then action calibrate : CalibrateSensors;
    }
    
    part def WaveformGenerator {
        port settingsIn : SettingsPort;
        port pulseOut : PulseOutputPort;
        port powerIn : PowerPort;
        attribute currentFrequency : FrequencyValue;
        attribute currentAmplitude : AmplitudeValue;
        attribute currentDuration : DurationValue;
        action generate : GeneratePulse;
    }
    
    part def ControlProcessor {
        port commandIn : CommandPort;
        port settingsOut : SettingsPort;
        port feedbackIn : FeedbackPort;
        port alertIn : AlertPort;
        attribute targetFrequency : FrequencyValue;
        attribute targetAmplitude : AmplitudeValue;
        attribute targetDuration : DurationValue;
        action adjust : AdjustSettings;
    }
    
    part def SignalAnalyzer {
        port pulseIn : PulseOutputPort;
        port feedbackOut : FeedbackPort;
        action measure : MeasureSignal;
    }
    
    part def PowerManagement {
        port powerOut : PowerPort;
        attribute outputVoltage : AmplitudeValue;
        attribute outputCurrent : CurrentValue;
    }
    
    part def SafetyMonitor {
        port alertOut : AlertPort;
        attribute temperature : TemperatureValue;
        attribute current : CurrentValue;
        attribute maxTemperature : TemperatureValue = 85;
        attribute maxCurrent : CurrentValue = 10;
    }
    
    part def Pulsocon {
        part waveformGenerator : WaveformGenerator;
        part controlProcessor : ControlProcessor;
        part signalAnalyzer : SignalAnalyzer;
        part powerManagement : PowerManagement;
        part safetyMonitor : SafetyMonitor;
        
        port commandPort : CommandPort;
        port triggerPort : TriggerPort;
        port outputPort : PulseOutputPort;
        
        connect commandPort to controlProcessor.commandIn;
        connect controlProcessor.settingsOut to waveformGenerator.settingsIn;
        connect waveformGenerator.pulseOut to signalAnalyzer.pulseIn;
        connect signalAnalyzer.feedbackOut to controlProcessor.feedbackIn;
        connect powerManagement.powerOut to waveformGenerator.powerIn;
        connect safetyMonitor.alertOut to controlProcessor.alertIn;
        connect waveformGenerator.pulseOut to outputPort;
        
        action initialize : InitializeSystem;
        action generatePulse : GeneratePulse;
        action measureSignal : MeasureSignal;
        action adjustSettings : AdjustSettings;
        action optimizeWaveform : OptimizeWaveform;
        action adaptiveOperation : AdaptiveOperation;
        action logFault : LogFault;
        action shutdownSequence : ShutdownSequence;
        
        state lifecycle {
            entry; then off;
            
            state off;
            accept StartCommand via commandPort
                then standby;
            
            state standby {
                entry initialize;
            }
            accept StartCommand via commandPort
                then active;
            accept StopCommand via commandPort
                then off;
            
            state active parallel {
                state operationalModes {
                    entry; then continuous;
                    
                    state continuous {
                        do generatePulse;
                    }
                    accept AdaptiveModeCommand via commandPort
                        then adaptive;
                    
                    state adaptive {
                        do adaptiveOperation;
                    }
                    accept ContinuousModeCommand via commandPort
                        then continuous;
                    accept SynchronizedModeCommand via commandPort
                        then synchronized;
                    
                    state synchronized;
                    accept ExternalTrigger via triggerPort
                        do generatePulse
                        then synchronized;
                    accept ContinuousModeCommand via commandPort
                        then continuous;
                }
                
                state healthMonitoring {
                    entry; then monitoring;
                    do measureSignal { out feedback; }
                    state monitoring;
                    accept when measureSignal.feedback.signalQuality < 95
                        do send new QualityAlert() to controlProcessor
                        then monitoring;
                }
            }
            
            accept StopCommand via commandPort
                then standby;
            accept when safetyMonitor.temperature > safetyMonitor.maxTemperature
                then fault;
            accept when safetyMonitor.current > safetyMonitor.maxCurrent
                then fault;
            
            state fault {
                entry logFault;
            }
            accept ResetCommand via commandPort
                then standby;
            accept StopCommand via commandPort
                then off;
        }
    }
    
    requirement def SignalQualityRequirement {
        doc /* The system shall maintain a signal quality of over 95 percent during active operation. */
    }
    
    requirement def TemperatureSafetyRequirement {
        doc /* The system shall enter a fault state if the internal temperature exceeds 85 degrees Celsius. */
    }
    
    requirement def PrecisionRequirement {
        doc /* The system shall generate pulses with precisely controlled frequency, amplitude, and duration based on target parameters. */
    }
    
    requirement def ClosedLoopRequirement {
        doc /* The system shall use feedback from the Signal Analyzer to make real-time micro-adjustments to maintain signal quality. */
    }
    
    requirement def InitializationRequirement {
        doc /* The system shall perform self-tests and sensor calibration before entering standby mode. */
    }
    
    requirement signalQualityReq : SignalQualityRequirement;
    requirement temperatureSafetyReq : TemperatureSafetyRequirement;
    requirement precisionReq : PrecisionRequirement;
    requirement closedLoopReq : ClosedLoopRequirement;
    requirement initializationReq : InitializationRequirement;
}

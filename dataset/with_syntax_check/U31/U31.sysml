package AcceleromyographSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TOFRatio :> Real;
    attribute def StimulusIntensity :> Real;
    
    item def StimulusPattern {
        attribute current : ElectricCurrentValue;
        attribute pulseWidth : TimeValue;
        attribute frequency : FrequencyValue;
        attribute trainCount : Integer;
    }
    
    item def MuscleResponse {
        attribute peakAcceleration : AccelerationValue;
        attribute responseTime : TimeValue;
        attribute twitchAmplitude : AccelerationValue;
    }
    
    item def BlockadeAssessment {
        attribute tofRatio : TOFRatio;
        attribute blockadeDepth : Real;
        attribute recoveryTrend : Real;
    }
    
    item def PowerOnSignal;
    item def StartMonitoringSignal;
    item def AcknowledgeAlarmSignal;
    item def PauseMonitoringSignal;
    item def ResumeMonitoringSignal;
    item def StopMonitoringSignal;
    item def PowerOffSignal;
    
    port def StimulusOutputPort {
        out item stimulusSignal : StimulusPattern;
    }
    
    port def AccelerationInputPort {
        in item accelerationData : MuscleResponse;
    }
    
    port def DataOutputPort {
        out item assessment : BlockadeAssessment;
    }
    
    port def UserInterfacePort {
        in item command : String;
        out item displayData : BlockadeAssessment;
    }
    
    part def NerveStimulator {
        port stimOutput : StimulusOutputPort;
        
        attribute maxCurrent : ElectricCurrentValue;
        attribute pulseGenerator : Boolean;
        
        perform action generateTrainOfFour {
            out pattern : StimulusPattern;
        }
    }
    
    part def AccelerometerSensor {
        port accelInput : AccelerationInputPort;
        
        attribute sensitivity : Real;
        attribute measurementRange : AccelerationValue;
        attribute samplingRate : FrequencyValue;
        
        perform action captureAcceleration {
            out response : MuscleResponse;
        }
    }
    
    part def AnalysisUnit {
        port responseInput : AccelerationInputPort;
        port assessmentOutput : DataOutputPort;
        
        attribute baselineResponse : MuscleResponse;
        attribute calibrationFactor : Real;
        
        perform action calculateTOF {
            in responses : MuscleResponse[4];
            out tofValue : TOFRatio;
        }
        
        perform action assessBlockade {
            in currentTOF : TOFRatio;
            out assessment : BlockadeAssessment;
        }
    }
    
    part def DisplayController {
        port uiPort : UserInterfacePort;
        port dataInput : DataOutputPort;
        
        perform action updateDisplay {
            in assessmentData : BlockadeAssessment;
        }
        
        perform action processUserCommand {
            in userCommand : String;
        }
    }
    
    part def PatientNerveMuscleUnit {
        port nerveStimInput;
        port muscleResponseOutput;
        
        attribute neuromuscularJunctionState : Real;
        attribute muscleContractility : Real;
        
        perform action respondToStimulation {
            in stimulus : StimulusPattern;
            out contraction : MuscleResponse;
        }
    }
    
    action def MonitorNeuromuscularBlockade {
        first start;
        then merge monitoringCycle;
        
        then action initiateStimulation {
            out stimPattern : StimulusPattern;
        }
        
        then action deliverStimulus {
            in pattern : StimulusPattern = initiateStimulation.stimPattern;
        }
        
        then action measureMuscleResponse {
            out responseData : MuscleResponse[4];
        }
        
        then action computeTOFRatio {
            in responses : MuscleResponse[4] = measureMuscleResponse.responseData;
            out tofResult : TOFRatio;
        }
        
        then action evaluateBlockade {
            in tof : TOFRatio = computeTOFRatio.tofResult;
            out blockadeData : BlockadeAssessment;
        }
        
        then action presentResults {
            in assessment : BlockadeAssessment = evaluateBlockade.blockadeData;
        }
        
        then decide;
            if evaluateBlockade.blockadeData.blockadeDepth > 0.9 then alertDeepBlock;
            if evaluateBlockade.blockadeData.blockadeDepth <= 0.9 then monitoringCycle;
        
        action alertDeepBlock {
            in criticalAssessment : BlockadeAssessment = evaluateBlockade.blockadeData;
        }
        then monitoringCycle;
    }
    
    state def NeuromuscularMonitoringStates {
        entry; then powerOff;
        
        state powerOff;
        transition powerOff_to_initialization
            first powerOff
            accept PowerOnSignal
            then initialization;
        
        state initialization {
            entry action systemSelfTest;
            entry action calibrateSensors {
                out complete : Boolean;
            }
        }
        transition initialization_to_ready
            first initialization
            then ready;
        
        state ready;
        transition ready_to_monitoring
            first ready
            accept StartMonitoringSignal
            then monitoring;
        
        state monitoring {
            entry action beginContinuousMonitoring;
            do action activeMonitoring : MonitorNeuromuscularBlockade;
        }
        
        transition monitoring_to_alarm
            first monitoring
            then alarm;
        
        state alarm {
            entry action triggerAlarm;
            do action maintainAlarmState;
        }
        transition alarm_to_monitoring
            first alarm
            accept AcknowledgeAlarmSignal
            then monitoring;
        
        transition monitoring_to_paused
            first monitoring
            accept PauseMonitoringSignal
            then paused;
        
        state paused;
        transition paused_to_monitoring
            first paused
            accept ResumeMonitoringSignal
            then monitoring;
        
        transition paused_to_ready
            first paused
            accept StopMonitoringSignal
            then ready;
        
        transition ready_to_powerOff
            first ready
            accept PowerOffSignal
            then powerOff;
    }
    
    part acceleromyograph {
        doc /*
            An acceleromyograph is a neuromuscular monitoring device used during anesthesia
            to quantitatively assess the degree of neuromuscular blockade. It delivers
            electrical stimuli to a peripheral nerve and measures the acceleration of the
            resulting muscle contraction using an accelerometer. The device calculates the
            Train-of-Four (TOF) ratio by comparing the amplitude of the fourth twitch to
            the first twitch in a series of four stimuli, providing clinicians with
            objective data to guide neuromuscular blocking agent administration and
            ensure adequate reversal before extubation.
        */
        
        perform action continuousMonitoring[*] ordered
            references monitoringOperation;
        
        part stimulator : NerveStimulator {
            perform continuousMonitoring.initiateStimulation;
            perform continuousMonitoring.deliverStimulus;
        }
        
        part sensor : AccelerometerSensor {
            perform continuousMonitoring.measureMuscleResponse;
        }
        
        part analyzer : AnalysisUnit {
            perform continuousMonitoring.computeTOFRatio;
            perform continuousMonitoring.evaluateBlockade;
        }
        
        part display : DisplayController {
            perform continuousMonitoring.presentResults;
        }
        
        state deviceLifecycle : NeuromuscularMonitoringStates;
        
        connection stimulusDelivery
            connect stimulator.stimOutput to patient.nerveStimInput;
        
        connection responseCapture
            connect patient.muscleResponseOutput to sensor.accelInput;
        
        connection dataProcessing
            connect sensor.accelInput to analyzer.responseInput;
        
        connection resultDisplay
            connect analyzer.assessmentOutput to display.dataInput;
    }
    
    part patient : PatientNerveMuscleUnit;
    
    action monitoringOperation : MonitorNeuromuscularBlockade;
    
    requirement def MeasurementPrecisionRequirement {
        doc /*
            The acceleromyograph shall measure TOF ratio with precision of ±0.05
            across the clinical range of 0.0 to 1.0.
        */
        
        subject device : acceleromyograph;
        
        require constraint precisionBound {
            device.analyzer.calculateTOF.tofValue >= 0.0 and
            device.analyzer.calculateTOF.tofValue <= 1.0
        }
    }
    
    requirement def StimulusOutputRequirement {
        doc /*
            The nerve stimulator shall deliver supramaximal stimulation with
            current range of 10-80 mA and pulse width of 0.1-0.3 ms.
        */
        
        subject stim : NerveStimulator;
    }
    
    requirement def ResponseTimeRequirement {
        doc /*
            The system shall complete a full TOF measurement cycle and update
            the display within 15 seconds of stimulus initiation.
        */
        
        subject device : acceleromyograph;
    }
    
    requirement def AlarmRequirement {
        doc /*
            The system shall activate an alarm when TOF ratio falls below 0.25
            indicating deep neuromuscular blockade.
        */
        
        subject device : acceleromyograph;
        
        require constraint deepBlockadeDetection {
            device.continuousMonitoring.evaluateBlockade.blockadeData.tofRatio < 0.25
        }
    }
    
    requirement <'AMG-SYS-001'> primaryFunctionRequirement {
        doc /*
            The acceleromyograph system shall continuously monitor neuromuscular
            function by delivering Train-of-Four electrical stimulation to a
            peripheral nerve, measuring the acceleration of the resulting muscle
            contractions via an accelerometer, calculating the TOF ratio, and
            displaying quantitative assessment of neuromuscular blockade depth
            to guide anesthetic management and ensure patient safety during
            procedures requiring neuromuscular blocking agents.
        */
        
        subject system : acceleromyograph;
        
        require precision : MeasurementPrecisionRequirement;
        require stimulusOutput : StimulusOutputRequirement;
        require responseTime : ResponseTimeRequirement;
        require alarmFunction : AlarmRequirement;
    }
}

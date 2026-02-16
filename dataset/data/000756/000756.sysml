package 'Scrambler Therapy System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PainIntensity :> Real;
    attribute def SignalPattern;
    attribute def ElectrodeConfiguration;
    attribute def TherapyDuration :> TimeValue;
    attribute def StimulationAmplitude :> ElectricPotentialValue;
    attribute def StimulationFrequency :> FrequencyValue;
    
    item def PainSignal {
        attribute intensity : PainIntensity;
        attribute frequency : FrequencyValue;
        attribute pathway : String;
    }
    
    item def ScramblerSignal {
        attribute amplitude : StimulationAmplitude;
        attribute frequency : StimulationFrequency;
        attribute pattern : SignalPattern;
        attribute waveform : String;
    }
    
    item def PatientFeedback {
        attribute reportedPain : PainIntensity;
        attribute timestamp : TimeValue;
        attribute location : String;
    }
    
    port def StimulationOutputPort {
        out signal : ScramblerSignal;
    }
    
    port def NeuralInterfacePort {
        in painInput : PainSignal;
        out modifiedSignal : ScramblerSignal;
    }
    
    port def ControlInterfacePort {
        in feedback : PatientFeedback;
        out parameters : ScramblerSignal;
    }
    
    port def ElectrodePort {
        in therapeuticSignal : ScramblerSignal;
    }
    
    part def SignalProcessingUnit {
        port controlInterface : ControlInterfacePort;
        port signalOutput : StimulationOutputPort;
        
        attribute currentAmplitude : StimulationAmplitude;
        attribute currentFrequency : StimulationFrequency;
        attribute maxAmplitude : StimulationAmplitude;
        attribute minAmplitude : StimulationAmplitude;
        
        perform action processAndGenerate;
    }
    
    part def SurfaceElectrodeArray {
        port neuralInterface : NeuralInterfacePort;
        port electrodeInput : ElectrodePort;
        
        attribute numberOfElectrodes : Integer;
        attribute configuration : ElectrodeConfiguration;
        attribute skinImpedance : Real;
        
        perform action deliverStimulation;
    }
    
    part def SafetyMonitoringUnit {
        attribute maxCurrentLimit : ElectricCurrentValue;
        attribute maxVoltageLimit : ElectricPotentialValue;
        attribute impedanceThreshold : Real;
        
        perform action monitorSafety;
    }
    
    part def ControlPanel {
        port userInterface : ControlInterfacePort;
        
        attribute sessionDuration : TherapyDuration;
        attribute intensityLevel : Integer;
        
        perform action collectFeedback;
    }
    
    part def PowerManagementUnit {
        attribute batteryLevel : Real;
        attribute outputVoltage : ElectricPotentialValue;
        attribute isActive : Boolean;
    }
    
    action def AssessInitialPain {
        in patientInput : PatientFeedback;
        out baselinePain : PainIntensity;
    }
    
    action def GenerateScramblerWaveform {
        in targetAmplitude : StimulationAmplitude;
        in targetFrequency : StimulationFrequency;
        in painPattern : PainSignal;
        out therapeuticSignal : ScramblerSignal;
    }
    
    action def DeliverNeuralStimulation {
        in signal : ScramblerSignal;
        in electrodeConfig : ElectrodeConfiguration;
        out deliveredSignal : ScramblerSignal;
    }
    
    action def MonitorPatientResponse {
        in currentStimulation : ScramblerSignal;
        out response : PatientFeedback;
    }
    
    action def AdjustTherapyParameters {
        in feedback : PatientFeedback;
        in currentAmplitude : StimulationAmplitude;
        in currentFrequency : StimulationFrequency;
        out newAmplitude : StimulationAmplitude;
        out newFrequency : StimulationFrequency;
    }
    
    action def VerifySafetyLimits {
        in signal : ScramblerSignal;
        in impedance : Real;
        out isSafe : Boolean;
    }
    
    action def ExecuteScramblerTherapy {
        in sessionDuration : TherapyDuration;
        in initialAmplitude : StimulationAmplitude;
        in initialFrequency : StimulationFrequency;
        in maxAmplitude : StimulationAmplitude;
        out finalPainLevel : PainIntensity;
        out treatmentHistory : PatientFeedback[*] := ( );
        
        private attribute currentAmplitude := initialAmplitude;
        private attribute currentFrequency := initialFrequency;
        private attribute elapsedTime : TimeValue := 0[s];
        private attribute cycleInterval : TimeValue := 30[s];
        
        first start;
        
        then action assessBaseline : AssessInitialPain {
            in patientInput;
            out baselinePain;
        }
        
        then merge treatmentCycle;
        
        then decide;
            if elapsedTime < sessionDuration then continueTherapy;
            if elapsedTime >= sessionDuration then completeTherapy;
        
        action continueTherapy {
            first action generateWaveform : GenerateScramblerWaveform {
                in targetAmplitude = currentAmplitude;
                in targetFrequency = currentFrequency;
                in painPattern;
                out therapeuticSignal;
            }
            
            then action verifySafety : VerifySafetyLimits {
                in signal = generateWaveform.therapeuticSignal;
                in impedance;
                out isSafe;
            }
            
            then decide;
                if verifySafety.isSafe then deliverStimulation;
                if not verifySafety.isSafe then haltDelivery;
            
            action deliverStimulation : DeliverNeuralStimulation {
                in signal = generateWaveform.therapeuticSignal;
                in electrodeConfig;
                out deliveredSignal;
            }
            
            then action monitorResponse : MonitorPatientResponse {
                in currentStimulation = deliverStimulation.deliveredSignal;
                out response;
            }
            
            then action adjustParams : AdjustTherapyParameters {
                in feedback = monitorResponse.response;
                in currentAmplitude = currentAmplitude;
                in currentFrequency = currentFrequency;
                out newAmplitude;
                out newFrequency;
            }
            
            then assign currentAmplitude := adjustParams.newAmplitude;
            then assign currentFrequency := adjustParams.newFrequency;
            then assign elapsedTime := elapsedTime + cycleInterval;
            then treatmentCycle;
            
            action haltDelivery;
            then treatmentCycle;
        }
        
        action completeTherapy {
            first action finalAssessment : AssessInitialPain {
                in patientInput;
                out baselinePain;
            }
            
            then assign finalPainLevel := finalAssessment.baselinePain;
        }
        
        then done;
    }
    
    state def TherapySessionState {
        entry; then idle;
        
        state idle;
        state configuring;
        state active {
            entry; then delivering;
            state delivering;
            state monitoring;
            state adjusting;
        }
        state paused;
        state completed;
        state emergency;
        
        transition powerOn first idle then configuring;
        transition startTherapy first configuring then active;
        transition cycleDelivery first active.delivering then active.monitoring;
        transition cycleMonitor first active.monitoring then active.adjusting;
        transition cycleAdjust first active.adjusting then active.delivering;
        transition pauseSession first active then paused;
        transition resumeSession first paused then active;
        transition completeSession first active then completed;
        transition emergencyStop first any then emergency;
        transition reset first emergency then idle;
    }
    
    part def ScramblerTherapySystem {
        doc /*
            The Scrambler Therapy System is a non-invasive neuromodulation medical device 
            designed to treat chronic neuropathic and cancer pain. Its primary function is 
            to intercept pain signals traveling through peripheral nerves and replace them 
            with artificial "non-pain" information using surface electrodes placed on the skin.
            
            The system generates complex, variable electrical waveforms that mimic natural 
            nerve signals but encode non-pain sensory information. By delivering these signals 
            through cutaneous pathways, the device aims to retrain the nervous system's pain 
            processing, providing relief without pharmaceutical intervention.
            
            The therapy operates through continuous monitoring and adaptive adjustment, 
            modulating stimulation parameters based on real-time patient feedback to optimize 
            therapeutic effectiveness while maintaining safety limits.
        */
        
        part signalProcessor : SignalProcessingUnit {
            perform therapySession.continueTherapy.generateWaveform;
            perform therapySession.continueTherapy.adjustParams;
        }
        
        part electrodes : SurfaceElectrodeArray {
            perform therapySession.continueTherapy.deliverStimulation;
        }
        
        part safetyMonitor : SafetyMonitoringUnit {
            perform therapySession.continueTherapy.verifySafety;
        }
        
        part controlPanel : ControlPanel {
            perform therapySession.assessBaseline;
            perform therapySession.continueTherapy.monitorResponse;
            perform therapySession.completeTherapy.finalAssessment;
        }
        
        part powerUnit : PowerManagementUnit;
        
        connection signalFlow connect 
            signalProcessor.signalOutput to electrodes.electrodeInput;
        
        connection feedbackFlow connect 
            controlPanel.userInterface to signalProcessor.controlInterface;
        
        connection neuralConnection connect 
            electrodes.neuralInterface to signalProcessor.signalOutput;
        
        perform action therapySession : ExecuteScramblerTherapy {
            in sessionDuration;
            in initialAmplitude;
            in initialFrequency;
            in maxAmplitude;
            out finalPainLevel;
            out treatmentHistory;
        }
        
        exhibit state sessionState : TherapySessionState;
    }
    
    requirement def PrimaryTherapeuticFunction {
        doc /*
            The Scrambler Therapy System shall deliver non-invasive electrical stimulation 
            to peripheral nerves via surface electrodes to modulate chronic pain by replacing 
            pain signals with synthetic non-pain information.
        */
        
        subject system : ScramblerTherapySystem;
    }
    
    requirement def PainReductionEffectiveness {
        doc /*
            The system shall achieve a clinically significant reduction in patient-reported 
            pain intensity, defined as a decrease of at least 30% from baseline pain levels 
            by the end of a standard therapy session.
        */
        
        subject session : ExecuteScramblerTherapy;
        
        require constraint {
            session.finalPainLevel <= 0.7 * session.assessBaseline.baselinePain
        }
    }
    
    requirement def ElectricalSafetyCompliance {
        doc /*
            The system shall limit electrical stimulation parameters to safe levels for 
            transcutaneous application, with maximum amplitude not exceeding 50 millivolts 
            and maximum current density within IEC 60601-2-10 standards.
        */
        
        subject processor : SignalProcessingUnit;
        
        require constraint {
            processor.maxAmplitude <= 50.0[mV]
        }
    }
    
    requirement def AdaptiveParameterAdjustment {
        doc /*
            The system shall continuously monitor patient feedback and automatically adjust 
            stimulation parameters at intervals not exceeding 30 seconds to optimize 
            therapeutic response while maintaining patient comfort.
        */
        
        subject therapy : ExecuteScramblerTherapy;
        
        require constraint {
            therapy.cycleInterval <= 30[s]
        }
    }
    
    requirement def SessionDurationSpecification {
        doc /*
            Each therapy session shall have a configurable duration between 30 and 60 minutes 
            to ensure adequate neural pathway modulation and sustained therapeutic effect.
        */
        
        subject session : ExecuteScramblerTherapy;
        
        require constraint {
            session.sessionDuration >= 30[min] and 
            session.sessionDuration <= 60[min]
        }
    }
    
    requirement def ImpedanceMonitoring {
        doc /*
            The system shall continuously monitor skin-electrode impedance and halt stimulation 
            if impedance exceeds safe thresholds, indicating poor electrode contact or potential 
            safety hazard.
        */
        
        subject safety : SafetyMonitoringUnit;
    }
    
    requirement systemRequirements {
        doc /*
            Comprehensive requirements for the Scrambler Therapy System to ensure safe, 
            effective, and adaptive delivery of pain-modulating neuromodulation therapy.
        */
        
        require primaryFunction : PrimaryTherapeuticFunction;
        require effectiveness : PainReductionEffectiveness;
        require electricalSafety : ElectricalSafetyCompliance;
        require adaptiveControl : AdaptiveParameterAdjustment;
        require sessionDuration : SessionDurationSpecification;
        require impedanceCheck : ImpedanceMonitoring;
    }
    
    part scramblerSystem : ScramblerTherapySystem {
        satisfy systemRequirements;
    }
}

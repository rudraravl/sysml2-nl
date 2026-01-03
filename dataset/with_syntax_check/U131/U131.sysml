package TrigeminalNerveStimulationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def StimulationAmplitude :> ISQ::ElectricCurrentValue;
    attribute def StimulationFrequency :> ISQ::FrequencyValue;
    attribute def PulseWidth :> ISQ::TimeValue;
    attribute def ImpedanceValue :> ISQ::PowerValue;
    attribute def VoltageValue :> ISQ::ElectricPotentialValue;
    
    item def StimulationParameters {
        attribute amplitude : StimulationAmplitude;
        attribute frequency : StimulationFrequency;
        attribute pulseWidth : PulseWidth;
        attribute burstMode : Boolean;
    }
    
    item def NeuralResponse {
        attribute impedance : ImpedanceValue;
        attribute evokedPotential : VoltageValue;
        attribute responseQuality : Real;
    }
    
    item def TherapySession {
        attribute sessionDuration : ISQ::TimeValue;
        attribute parameters : StimulationParameters;
        attribute targetBranch : String;
    }
    
    enum def StimulationMode {
        continuous;
        burst;
        modulated;
    }
    
    enum def SystemState {
        off;
        standby;
        calibrating;
        treating;
        monitoring;
        fault;
    }
    
    port def StimulationDeliveryPort {
        out item stimParams : StimulationParameters;
        in item neuralFeedback : NeuralResponse;
    }
    
    port def PowerSupplyPort {
        in attribute voltage : VoltageValue;
        in attribute current : ISQ::ElectricCurrentValue;
    }
    
    port def UserInterfacePort {
        in item sessionConfig : TherapySession;
        out attribute systemStatus : SystemState;
    }
    
    part def PowerModule {
        port powerOut : PowerSupplyPort;
        attribute batteryCapacity : ISQ::EnergyValue;
        attribute outputVoltage : VoltageValue := 9.0[SI::V];
        attribute maxCurrent : ISQ::ElectricCurrentValue := 0.02[SI::A];
    }
    
    part def ControlProcessor {
        port userInterface : UserInterfacePort;
        port powerIn : PowerSupplyPort;
        
        attribute currentState : SystemState;
        attribute safetyLimits : StimulationParameters;
        attribute calibrationData : NeuralResponse;
        
        action def ValidateParameters {
            in requested : StimulationParameters;
            in limits : StimulationParameters;
            out validated : StimulationParameters;
            out isValid : Boolean;
        }
        
        action def MonitorSafety {
            in feedback : NeuralResponse;
            in maxImpedance : ImpedanceValue;
            out isSafe : Boolean;
        }
    }
    
    part def SignalGenerator {
        port controlInput;
        port stimOutput : StimulationDeliveryPort;
        
        attribute waveformType : String;
        attribute outputCompliance : VoltageValue;
        
        action def GeneratePulse {
            in params : StimulationParameters;
            out pulseSignal : StimulationParameters;
        }
        
        action def ModulateSignal {
            in baseParams : StimulationParameters;
            in modulationDepth : Real;
            out modulatedSignal : StimulationParameters;
        }
    }
    
    part def ElectrodeArray {
        port stimulationInput : StimulationDeliveryPort;
        port tissueInterface;
        
        attribute numberOfContacts : Integer := 4;
        attribute contactImpedance : ImpedanceValue;
        attribute placement : String;
        
        action def DeliverStimulation {
            in signal : StimulationParameters;
            out deliveredEnergy : ISQ::EnergyValue;
        }
        
        action def MeasureImpedance {
            out impedance : ImpedanceValue;
        }
    }
    
    part def TrigeminalNerveTissue {
        port electrodeContact;
        
        attribute branchType : String;
        attribute baselineImpedance : ImpedanceValue := 1200.0[SI::W];
        attribute excitabilityThreshold : StimulationAmplitude;
        
        action def RespondToStimulation {
            in stimulation : StimulationParameters;
            out response : NeuralResponse;
        }
        
        action def GenerateFeedback {
            in appliedCurrent : StimulationAmplitude;
            out impedance : ImpedanceValue;
            out potential : VoltageValue;
        }
    }
    
    part def FeedbackSensor {
        port senseInput;
        port dataOutput;
        
        attribute samplingRate : ISQ::FrequencyValue := 1000.0[SI::Hz];
        attribute resolution : Real;
        
        action def AcquireResponse {
            in tissueResponse : NeuralResponse;
            out measuredResponse : NeuralResponse;
        }
    }
    
    part def TrigeminalStimulationDevice;
    
    state def TherapyControlStateMachine {
        in attribute sessionRequest : TherapySession;
        in attribute safetyStatus : Boolean;
        out attribute currentMode : SystemState;
        
        initial state PowerOff;
        
        state Standby {
            entry action initializeSystem;
        }
        
        state Calibration {
            entry action startCalibration;
            do action measureBaselineImpedance;
            exit action storeCalibrationData;
        }
        
        state ActiveTreatment {
            entry action beginStimulation;
            do action deliverTherapy;
            exit action stopStimulation;
        }
        
        state ContinuousMonitoring {
            do action monitorNeuralResponse;
            do action adjustParameters;
        }
        
        state FaultCondition {
            entry action emergencyShutdown;
            do action logFaultData;
        }
        
        accept powerOn;
        transition PowerOff_to_Standby
            first PowerOff
            accept powerOn
            then Standby;
        
        accept startCalibration;
        transition Standby_to_Calibration
            first Standby
            accept startCalibration
            then Calibration;
        
        transition Calibration_to_ActiveTreatment
            first Calibration
            if calibrationComplete
            then ActiveTreatment;
        
        transition ActiveTreatment_to_Monitoring
            first ActiveTreatment
            then ContinuousMonitoring;
        
        transition Monitoring_to_ActiveTreatment
            first ContinuousMonitoring
            if parametersAdjusted
            then ActiveTreatment;
        
        accept sessionComplete;
        transition Monitoring_to_Standby
            first ContinuousMonitoring
            accept sessionComplete
            then Standby;
        
        transition any_to_Fault
            first ActiveTreatment
            if not safetyStatus
            then FaultCondition;
        
        accept faultCleared;
        transition Fault_to_Standby
            first FaultCondition
            accept faultCleared
            then Standby;
    }
    
    action def TherapeuticStimulationProcess {
        in sessionConfig : TherapySession;
        in safetyLimits : StimulationParameters;
        out deliveredTherapy : Boolean;
        out sessionData : NeuralResponse[*];
        
        first start;
        
        then action validateSession {
            in config : TherapySession = sessionConfig;
            in limits : StimulationParameters = safetyLimits;
            out isValid : Boolean;
            out validatedParams : StimulationParameters;
        }
        
        then decide;
            if validateSession.isValid then proceedToCalibration;
            if not validateSession.isValid then abortSession;
        
        action proceedToCalibration;
        
        then action performCalibration {
            out baselineImpedance : ImpedanceValue;
            out thresholdAmplitude : StimulationAmplitude;
        }
        
        then merge treatmentLoop;
        
        then action generateStimulus {
            in params : StimulationParameters = validateSession.validatedParams;
            out stimulus : StimulationParameters;
        }
        
        then action deliverToNerve {
            in signal : StimulationParameters = generateStimulus.stimulus;
            out delivered : Boolean;
        }
        
        then action acquireFeedback {
            out response : NeuralResponse;
        }
        
        then action evaluateSafety {
            in feedback : NeuralResponse = acquireFeedback.response;
            in maxImpedance : ImpedanceValue := 5000.0[SI::W];
            out isSafe : Boolean;
            out needsAdjustment : Boolean;
        }
        
        then assign sessionData := sessionData->including(acquireFeedback.response);
        
        then decide;
            if evaluateSafety.isSafe and not evaluateSafety.needsAdjustment then continueTherapy;
            if evaluateSafety.isSafe and evaluateSafety.needsAdjustment then adjustTherapy;
            if not evaluateSafety.isSafe then terminateTherapy;
        
        action continueTherapy;
        then treatmentLoop;
        
        action adjustTherapy {
            in currentResponse : NeuralResponse = acquireFeedback.response;
            out adjustedParams : StimulationParameters;
        }
        then treatmentLoop;
        
        action terminateTherapy {
            out reason : String;
        }
        then assign deliveredTherapy := true;
        then done;
        
        action abortSession {
            out errorCode : String;
        }
        then assign deliveredTherapy := false;
        then done;
    }
    
    part tnsSystem : TrigeminalStimulationDevice {
        part power : PowerModule;
        part controller : ControlProcessor;
        part generator : SignalGenerator;
        part electrodes : ElectrodeArray;
        part sensor : FeedbackSensor;
        part nerve : TrigeminalNerveTissue;
        
        connect power.powerOut to controller.powerIn;
        connect controller to generator.controlInput;
        connect generator.stimOutput to electrodes.stimulationInput;
        connect electrodes.tissueInterface to nerve.electrodeContact;
        connect nerve.electrodeContact to sensor.senseInput;
        connect sensor.dataOutput to generator.stimOutput;
        
        perform action therapeuticOperation : TherapeuticStimulationProcess[*] ordered;
        
        state operationControl : TherapyControlStateMachine;
    }
    
    requirement def TherapeuticEfficacy {
        doc /* The system shall deliver controlled electrical stimulation to modulate 
               trigeminal nerve activity for therapeutic pain management. */
        
        require constraint amplitudeControl {
            doc /* Stimulation amplitude shall be adjustable between 0.5 mA and 20 mA. */
        }
        
        require constraint frequencyControl {
            doc /* Stimulation frequency shall be adjustable between 5 Hz and 250 Hz. */
        }
        
        require constraint pulseWidthControl {
            doc /* Pulse width shall be adjustable between 50 microseconds and 1000 microseconds. */
        }
    }
    
    requirement def PatientSafety {
        doc /* The system shall continuously monitor tissue response and prevent 
               unsafe stimulation conditions. */
        
        require constraint impedanceMonitoring {
            doc /* Tissue impedance shall be monitored continuously during stimulation. */
        }
        
        require constraint automaticShutoff {
            doc /* System shall automatically cease stimulation if impedance exceeds 5000 ohms 
                   or falls below 200 ohms. */
        }
        
        require constraint currentLimiting {
            doc /* Maximum deliverable current shall not exceed 20 mA under any condition. */
        }
    }
    
    requirement def SystemReliability {
        doc /* The system shall operate reliably throughout therapy sessions. */
        
        require constraint batteryLife {
            doc /* Battery shall support minimum 8 hours of continuous operation. */
        }
        
        require constraint calibrationAccuracy {
            doc /* System shall calibrate to within 5% of actual tissue impedance. */
        }
    }
    
    requirement primaryMissionRequirement {
        doc /* The Trigeminal Nerve Stimulation System shall deliver precisely controlled, 
               safe, and effective electrical stimulation to the trigeminal nerve branches 
               to modulate neural activity for therapeutic management of chronic facial pain, 
               migraine, and cluster headaches. The system shall continuously monitor tissue 
               response, automatically adjust stimulation parameters within safe limits, and 
               provide reliable therapy delivery through a closed-loop feedback mechanism. */
        
        subject tnsSystem;
        
        require therapeuticReq : TherapeuticEfficacy;
        require safetyReq : PatientSafety;
        require reliabilityReq : SystemReliability;
        
        assume constraint nerveAccessibility {
            doc /* The target trigeminal nerve branch is accessible for electrode placement. */
        }
        
        assume constraint tissueHealth {
            doc /* Patient tissue is healthy enough to support electrical stimulation. */
        }
    }
}

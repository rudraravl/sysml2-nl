package NeurostimulationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def StimulationParameters {
        attribute amplitude : ElectricCurrentValue;
        attribute pulseWidth : DurationValue;
        attribute frequency : FrequencyValue;
        attribute burstPattern : Integer;
    }
    
    attribute def NeuralSignal {
        attribute voltage : ElectricPotentialValue;
        attribute frequency : FrequencyValue;
        attribute noiseLevel : Real;
    }
    
    attribute def TherapyConfiguration {
        attribute targetSymptomReduction : Real;
        attribute maxCurrentLimit : ElectricCurrentValue;
        attribute minCurrentLimit : ElectricCurrentValue;
        attribute sessionDuration : DurationValue;
    }
    
    attribute def PatientCondition {
        attribute symptomSeverity : Real;
        attribute neuralActivity : NeuralSignal;
        attribute tissueImpedance : ElectricResistanceValue;
        attribute responseLatency : DurationValue;
    }
    
    attribute def SystemDiagnostics {
        attribute batteryLevel : Real;
        attribute leadIntegrity : Boolean;
        attribute impedanceStatus : ElectricResistanceValue;
        attribute operationalState : Integer;
    }
    
    port def NeuralInterfacePort {
        out stimulationSignal : ElectricCurrentValue;
        in recordedActivity : NeuralSignal;
    }
    
    port def PowerPort {
        in powerInput : PowerValue;
        out powerStatus : Real;
    }
    
    port def TelemetryPort {
        in programmingData : TherapyConfiguration;
        out diagnosticData : SystemDiagnostics;
    }
    
    part def SensingSubsystem {
        port neuralInput : ~NeuralInterfacePort;
        attribute currentReading : NeuralSignal;
        attribute filterSettings : FrequencyValue;
        
        action performSensing : AcquireNeuralSignals {
            in rawInput : NeuralSignal;
            out filteredSignal : NeuralSignal;
        }
    }
    
    part def StimulationSubsystem {
        port neuralOutput : NeuralInterfacePort;
        attribute activeParameters : StimulationParameters;
        attribute outputCurrent : ElectricCurrentValue;
        
        action performStimulation : DeliverTherapeuticPulses {
            in parameters : StimulationParameters;
            out pulseOutput : ElectricCurrentValue;
        }
    }
    
    part def ControlSubsystem {
        port telemetryInterface : ~TelemetryPort;
        attribute therapySettings : TherapyConfiguration;
        attribute patientState : PatientCondition;
        attribute controlAlgorithm : Integer;
        
        action executeControl : ManageTherapyDelivery;
    }
    
    part def PowerSubsystem {
        port powerInterface : ~PowerPort;
        attribute batteryCapacity : EnergyValue;
        attribute currentDraw : ElectricCurrentValue;
        attribute remainingCharge : Real;
        
        action regulatePower : DistributePower {
            in loadDemand : PowerValue;
            out suppliedPower : PowerValue;
        }
    }
    
    part def SafetySubsystem {
        attribute safetyState : Boolean;
        attribute impedanceMeasurement : ElectricResistanceValue;
        attribute faultDetected : Boolean;
        
        action monitorSafety : VerifyOperationalSafety {
            in deliveredCurrent : ElectricCurrentValue;
            in measuredImpedance : ElectricResistanceValue;
            out safetyStatus : Boolean;
        }
    }
    
    part def LeadAssembly {
        port neuralContact : ~NeuralInterfacePort;
        attribute electrodeCount : Integer;
        attribute leadImpedance : ElectricResistanceValue;
        attribute contactArea : AreaValue;
    }
    
    action def AcquireNeuralSignals {
        in rawInput : NeuralSignal;
        out filteredSignal : NeuralSignal;
    }
    
    action def DeliverTherapeuticPulses {
        in parameters : StimulationParameters;
        out pulseOutput : ElectricCurrentValue;
    }
    
    action def AssessPatientState {
        in neuralData : NeuralSignal;
        in therapyConfig : TherapyConfiguration;
        out symptomLevel : Real;
        out responseQuality : Real;
    }
    
    action def OptimizeStimulation {
        in currentSymptomLevel : Real;
        in targetLevel : Real;
        in activeParameters : StimulationParameters;
        out optimizedParameters : StimulationParameters;
    }
    
    action def VerifyOperationalSafety {
        in deliveredCurrent : ElectricCurrentValue;
        in measuredImpedance : ElectricResistanceValue;
        out safetyStatus : Boolean;
    }
    
    action def DistributePower {
        in loadDemand : PowerValue;
        out suppliedPower : PowerValue;
    }
    
    action def ManageTherapyDelivery {
        first start;
        then merge therapyControlLoop;
        
        action acquireSignals : AcquireNeuralSignals {
            in rawInput;
            out filteredSignal;
        }
        
        then action assessState : AssessPatientState {
            in neuralData = acquireSignals.filteredSignal;
            in therapyConfig;
            out symptomLevel;
            out responseQuality;
        }
        
        then action verifySafety : VerifyOperationalSafety {
            in deliveredCurrent;
            in measuredImpedance;
            out safetyStatus;
        }
        
        then decide;
            if verifySafety.safetyStatus and assessState.symptomLevel > 0.2 then optimizeTherapy;
            if not verifySafety.safetyStatus then suspendTherapy;
            if verifySafety.safetyStatus and assessState.symptomLevel <= 0.2 then maintainTherapy;
        
        action optimizeTherapy : OptimizeStimulation {
            in currentSymptomLevel = assessState.symptomLevel;
            in targetLevel;
            in activeParameters;
            out optimizedParameters;
        }
        then deliverPulses;
        
        action maintainTherapy {
            out steadyParameters : StimulationParameters;
        }
        then deliverPulses;
        
        action suspendTherapy {
            out zeroParameters : StimulationParameters;
        }
        then done;
        
        action deliverPulses : DeliverTherapeuticPulses {
            in parameters;
            out pulseOutput;
        }
        then therapyControlLoop;
    }
    
    action def ProvideNeurostimulationTherapy {
        in therapyConfig : TherapyConfiguration;
        out clinicalOutcome : Real;
        
        first start;
        then merge continuousTherapy;
        
        action initializeTherapy {
            in configuration : TherapyConfiguration;
            out initialParameters : StimulationParameters;
        }
        
        then action senseActivity : AcquireNeuralSignals {
            in rawInput;
            out filteredSignal;
        }
        
        then action evaluateCondition : AssessPatientState {
            in neuralData = senseActivity.filteredSignal;
            in therapyConfig = therapyConfig;
            out symptomLevel;
            out responseQuality;
        }
        
        then action checkSafety : VerifyOperationalSafety {
            in deliveredCurrent;
            in measuredImpedance;
            out safetyStatus;
        }
        
        then decide;
            if checkSafety.safetyStatus then proceedWithTherapy;
            if not checkSafety.safetyStatus then terminateTherapy;
        
        action proceedWithTherapy {
            action adjustParameters : OptimizeStimulation {
                in currentSymptomLevel = evaluateCondition.symptomLevel;
                in targetLevel = therapyConfig.targetSymptomReduction;
                in activeParameters;
                out optimizedParameters;
            }
            
            then action applyStimulation : DeliverTherapeuticPulses {
                in parameters = adjustParameters.optimizedParameters;
                out pulseOutput;
            }
        }
        then continuousTherapy;
        
        action terminateTherapy;
        then done;
    }
    
    state def TherapyStateMachine {
        entry; then Standby;
        
        state Standby {
            doc /* Device is powered but not delivering therapy. */
        }
        
        accept ProgrammingComplete;
        accept SymptomChangeDetected;
        accept SafetyViolation;
        accept ParametersOptimized;
        accept SystemReset;
        
        transition StandbyToInitializing
            first Standby
            accept ProgrammingComplete
            then Initializing;
        
        state Initializing {
            doc /* System is configuring therapy parameters and performing self-checks. */
        }
        
        transition InitializingToActive
            first Initializing
            then ActiveTherapy;
        
        state ActiveTherapy {
            doc /* System is actively delivering neurostimulation therapy. */
        }
        
        transition ActiveToAdjusting
            first ActiveTherapy
            accept SymptomChangeDetected
            then Adjusting;
        
        transition ActiveToFault
            first ActiveTherapy
            accept SafetyViolation
            then Fault;
        
        state Adjusting {
            doc /* System is optimizing stimulation parameters based on patient response. */
        }
        
        transition AdjustingToActive
            first Adjusting
            accept ParametersOptimized
            then ActiveTherapy;
        
        state Fault {
            doc /* System has detected a fault condition and halted therapy. */
        }
        
        transition FaultToStandby
            first Fault
            accept SystemReset
            then Standby;
    }
    
    part def ImplantablePulseGenerator {
        attribute deviceIdentifier : String;
        attribute firmwareVersion : String;
        
        perform action deliverTherapy : ProvideNeurostimulationTherapy;
        exhibit state therapyControl : TherapyStateMachine;
        
        part sensing : SensingSubsystem {
            perform deliverTherapy.senseActivity;
        }
        
        part stimulation : StimulationSubsystem {
            perform deliverTherapy.proceedWithTherapy.applyStimulation;
        }
        
        part control : ControlSubsystem {
            perform deliverTherapy.evaluateCondition;
            perform deliverTherapy.proceedWithTherapy.adjustParameters;
        }
        
        part safety : SafetySubsystem {
            perform deliverTherapy.checkSafety;
        }
        
        part power : PowerSubsystem {
            attribute batteryCapacity = 15000[J];
        }
        
        connection sensingToControl connect sensing to control;
        connection controlToStimulation connect control to stimulation;
        connection safetyToControl connect safety to control;
        connection powerToSensing connect power.powerInterface to sensing;
        connection powerToStimulation connect power.powerInterface to stimulation;
    }
    
    part neurostimulationDevice : ImplantablePulseGenerator {
        attribute deviceIdentifier = "IPG-2024-001";
        attribute firmwareVersion = "v3.2.1";
        
        part sensing {
            attribute filterSettings = 250[Hz];
        }
        
        part stimulation {
            attribute activeParameters {
                attribute amplitude = 3.5[mA];
                attribute pulseWidth = 200[us];
                attribute frequency = 130[Hz];
                attribute burstPattern = 5;
            }
        }
        
        part control {
            attribute therapySettings {
                attribute targetSymptomReduction = 0.7;
                attribute maxCurrentLimit = 10.0[mA];
                attribute minCurrentLimit = 0.5[mA];
                attribute sessionDuration = 3600[s];
            }
        }
        
        part lead : LeadAssembly {
            attribute electrodeCount = 8;
            attribute leadImpedance = 500[ohm];
            attribute contactArea = 6[mm^2];
        }
        
        connection deviceToLead connect stimulation.neuralOutput to lead.neuralContact;
        connection leadToSensing connect lead.neuralContact to sensing.neuralInput;
    }
    
    requirement <'NS-REQ-001'> primaryTherapyRequirement {
        doc /* The neurostimulation system shall continuously monitor neural activity 
                and deliver adaptive electrical stimulation to modulate neural circuits, 
                thereby reducing symptom severity to target therapeutic levels while 
                maintaining patient safety throughout the therapy session. */
        
        subject neurostimulationDevice;
        
        require constraint continuousMonitoring {
            doc /* The system shall acquire neural signals at minimum 1 kHz sampling rate. */
        }
        
        require constraint adaptiveStimulation {
            doc /* Stimulation parameters shall be adjusted within 100 ms of detecting 
                    symptom level changes exceeding 10% threshold. */
        }
        
        require constraint safetyEnforcement {
            doc /* Delivered current shall never exceed maximum safety limit under any 
                    operational condition. */
            neurostimulationDevice.control.therapySettings.maxCurrentLimit <= 10.0[mA]
        }
    }
    
    requirement <'NS-REQ-002'> therapeuticEfficacyRequirement {
        doc /* The system shall achieve target symptom reduction within 30 minutes 
                of therapy initiation for at least 85% of treatment sessions. */
        
        subject neurostimulationDevice;
        
        assume constraint patientResponsiveness {
            doc /* Patient neural tissue exhibits measurable response to electrical 
                    stimulation within therapeutic range. */
        }
        
        require primaryTherapyRequirement;
    }
    
    requirement <'NS-REQ-003'> deviceLongevityRequirement {
        doc /* The implantable pulse generator shall maintain operational capability 
                for minimum 5 years under nominal therapy usage patterns. */
        
        subject neurostimulationDevice;
        
        require constraint batteryLife {
            doc /* Battery capacity shall support 8 hours daily therapy for 5 years. */
            neurostimulationDevice.power.batteryCapacity >= 15000[J]
        }
        
        require constraint componentReliability {
            doc /* All electronic components shall meet medical-grade reliability standards. */
        }
    }
}

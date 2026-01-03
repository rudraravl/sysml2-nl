package SubcutaneousImplantableDefibrillatorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def RhythmClassification {
        attribute isNormalSinus : Boolean;
        attribute isVentricularTachycardia : Boolean;
        attribute isVentricularFibrillation : Boolean;
        attribute isSupraventricularTachycardia : Boolean;
    }
    
    attribute def ShockEnergy :> ISQ::energy;
    attribute def HeartRate :> ISQ::frequency;
    attribute def SignalAmplitude :> ISQ::voltage;
    
    item def CardiacSignal {
        attribute amplitude : SignalAmplitude;
        attribute frequency : HeartRate;
        attribute morphology : String;
        attribute timestamp : ISQ::DurationValue;
    }
    
    item def TherapyPulse {
        attribute energy : ShockEnergy;
        attribute waveform : String;
        attribute deliveryTime : ISQ::DurationValue;
    }
    
    item def DiagnosticReport {
        attribute rhythmType : RhythmClassification;
        attribute confidence : Real;
        attribute heartRate : HeartRate;
        attribute requiresIntervention : Boolean;
    }
    
    item def SystemConfiguration {
        attribute detectionSensitivity : Real;
        attribute therapyEnabled : Boolean;
        attribute shockEnergyLevel : ShockEnergy;
    }
    
    port def CardiacSensingPort {
        in item signal : CardiacSignal;
    }
    
    port def TherapyDeliveryPort {
        out item pulse : TherapyPulse;
    }
    
    port def DiagnosticPort {
        out item report : DiagnosticReport;
    }
    
    port def ConfigurationPort {
        in item config : SystemConfiguration;
    }
    
    part def SensingElectrode {
        doc /* Subcutaneous electrode positioned to detect cardiac electrical activity. */
        
        port sensingInterface : ~CardiacSensingPort;
        
        action def AcquireCardiacSignal {
            out detectedSignal : CardiacSignal;
        }
        
        perform action continuousSensing : AcquireCardiacSignal[*] ordered;
    }
    
    part def DefibrillationElectrode {
        doc /* Subcutaneous electrode positioned to deliver therapeutic shocks. */
        
        port therapyInterface : ~TherapyDeliveryPort;
        
        action def ApplyElectricalShock {
            in therapyCommand : TherapyPulse;
            out shockApplied : Boolean;
        }
        
        perform action shockDelivery : ApplyElectricalShock[*] ordered;
    }
    
    part def SignalProcessingUnit {
        doc /* Processes raw cardiac signals and filters noise. */
        
        port signalInput : CardiacSensingPort;
        port processedOutput : ~CardiacSensingPort;
        
        action def FilterSignal {
            in rawSignal : CardiacSignal;
            out filteredSignal : CardiacSignal;
        }
        
        action def AmplifySignal {
            in inputSignal : CardiacSignal;
            out amplifiedSignal : CardiacSignal;
        }
        
        perform action signalProcessing : FilterSignal[*] ordered;
    }
    
    part def ArrhythmiaDetectionUnit {
        doc /* Analyzes cardiac signals to detect life-threatening arrhythmias. */
        
        port diagnosticInput : CardiacSensingPort;
        port diagnosticOutput : DiagnosticPort;
        
        action def AnalyzeRhythm {
            in cardiacData : CardiacSignal;
            out diagnosis : DiagnosticReport;
        }
        
        action def ClassifyArrhythmia {
            in signalPattern : CardiacSignal;
            in heartRate : HeartRate;
            out classification : RhythmClassification;
            out shockable : Boolean;
        }
        
        action def ConfirmDetection {
            in initialDiagnosis : DiagnosticReport;
            out confirmed : Boolean;
        }
        
        perform action rhythmAnalysis : AnalyzeRhythm[*] ordered;
    }
    
    part def TherapyDecisionUnit {
        doc /* Determines appropriate therapy based on detected arrhythmia. */
        
        port diagnosisInput : ~DiagnosticPort;
        port configInput : ConfigurationPort;
        
        action def DetermineTherapy {
            in diagnosis : DiagnosticReport;
            in configuration : SystemConfiguration;
            out therapyRequired : Boolean;
            out therapyParameters : TherapyPulse;
        }
        
        action def CalculateShockEnergy {
            in arrhythmiaType : RhythmClassification;
            out energyLevel : ShockEnergy;
        }
        
        perform action therapyDecision : DetermineTherapy[*] ordered;
    }
    
    part def HighVoltageCapacitor {
        doc /* Stores energy for defibrillation shock delivery. */
        
        attribute storedEnergy : ShockEnergy;
        attribute maxCapacity : ShockEnergy;
        attribute chargeVoltage : SignalAmplitude;
        
        action def ChargeCapacitor {
            in targetEnergy : ShockEnergy;
            out fullyCharged : Boolean;
        }
        
        action def DischargeForTherapy {
            in dischargeEnergy : ShockEnergy;
            out discharged : Boolean;
        }
    }
    
    part def BatteryPack {
        doc /* Primary power source for the implantable device. */
        
        attribute totalCapacity : ISQ::energy;
        attribute remainingCapacity : ISQ::energy;
        attribute voltage : SignalAmplitude;
        
        action def ProvidePower {
            in powerDemand : ISQ::power;
            out powerSupplied : ISQ::power;
        }
    }
    
    part def ControlProcessor {
        doc /* Central microprocessor coordinating all device functions. */
        
        action def CoordinateMonitoring {
            out monitoringActive : Boolean;
        }
        
        action def InitiateTherapySequence {
            in therapyCommand : TherapyPulse;
            out sequenceStarted : Boolean;
        }
        
        action def LogEvent {
            in eventData : DiagnosticReport;
            out eventLogged : Boolean;
        }
    }
    
    part def SubcutaneousICD {
        doc /* Complete subcutaneous implantable cardioverter-defibrillator system. */
        
        part sensingLead : SensingElectrode;
        part shockLead : DefibrillationElectrode;
        part signalProcessor : SignalProcessingUnit;
        part arrhythmiaDetector : ArrhythmiaDetectionUnit;
        part therapyController : TherapyDecisionUnit;
        part capacitor : HighVoltageCapacitor;
        part battery : BatteryPack;
        part processor : ControlProcessor;
        
        connect sensingLead.sensingInterface to signalProcessor.signalInput;
        connect signalProcessor.processedOutput to arrhythmiaDetector.diagnosticInput;
        connect arrhythmiaDetector.diagnosticOutput to therapyController.diagnosisInput;
        
        perform action primaryFunction : ProtectFromSuddenCardiacDeath[*] ordered;
    }
    
    action def ProtectFromSuddenCardiacDeath {
        doc /* Primary function: continuously monitor heart rhythm and deliver life-saving therapy when needed. */
        
        first start;
        then merge continuousMonitoring;
        
        action monitorCardiacActivity {
            out rawSignal : CardiacSignal;
        }
        
        then action processSignal {
            in signal : CardiacSignal = monitorCardiacActivity.rawSignal;
            out cleanSignal : CardiacSignal;
        }
        
        then action detectArrhythmia {
            in cardiacSignal : CardiacSignal = processSignal.cleanSignal;
            out detectionResult : DiagnosticReport;
        }
        
        then action confirmArrhythmia {
            in initialDetection : DiagnosticReport = detectArrhythmia.detectionResult;
            out confirmed : Boolean;
            out arrhythmiaType : RhythmClassification;
        }
        
        then decide;
            if confirmArrhythmia.confirmed then prepareTherapy;
            if not confirmArrhythmia.confirmed then continuousMonitoring;
        
        action prepareTherapy {
            action determineShockEnergy {
                in rhythmType : RhythmClassification = confirmArrhythmia.arrhythmiaType;
                out shockEnergy : ShockEnergy;
            }
            
            then action chargeCapacitors {
                in requiredEnergy : ShockEnergy = determineShockEnergy.shockEnergy;
                out capacitorsReady : Boolean;
            }
            
            then action deliverDefibrillation {
                in therapyEnergy : ShockEnergy = determineShockEnergy.shockEnergy;
                out shockDelivered : Boolean;
            }
            
            then action assessResponse {
                out rhythmRestored : Boolean;
            }
            
            then decide;
                if assessResponse.rhythmRestored then continuousMonitoring;
                if not assessResponse.rhythmRestored then determineShockEnergy;
        }
        
        then continuousMonitoring;
    }
    
    state def DeviceOperationalStates {
        entry; then PowerOn;
        
        state PowerOn;
        then transition to Monitoring;
        
        state Monitoring {
            doc /* Continuous cardiac rhythm surveillance state. */
        }
        
        transition monitoringToDetection
            first Monitoring
            accept arrhythmiaDetected
            then Detection;
        
        state Detection {
            doc /* Arrhythmia analysis and confirmation state. */
        }
        
        transition detectionToCharging
            first Detection
            accept shockableRhythmConfirmed
            then Charging;
        
        transition detectionToMonitoring
            first Detection
            accept nonShockableRhythm
            then Monitoring;
        
        state Charging {
            doc /* High-voltage capacitor charging state. */
        }
        
        transition chargingToTherapy
            first Charging
            accept capacitorCharged
            then TherapyDelivery;
        
        state TherapyDelivery {
            doc /* Defibrillation shock delivery state. */
        }
        
        transition therapyToPostShock
            first TherapyDelivery
            accept shockCompleted
            then PostShockAssessment;
        
        state PostShockAssessment {
            doc /* Post-therapy rhythm evaluation state. */
        }
        
        transition postShockToMonitoring
            first PostShockAssessment
            accept rhythmRestored
            then Monitoring;
        
        transition postShockToCharging
            first PostShockAssessment
            accept rhythmPersists
            then Charging;
    }
    
    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;
    requirement def ReliabilityRequirement;
    requirement def EffectivenessRequirement;
    
    requirement <'SICD-REQ-001'> detectVentricularArrhythmias : PerformanceRequirement {
        doc /* The S-ICD shall detect ventricular fibrillation and sustained ventricular tachycardia 
                with sensitivity ≥98% and specificity ≥95% within 10 seconds of arrhythmia onset. */
        
        subject device : SubcutaneousICD;
        
        require constraint {
            device.arrhythmiaDetector.rhythmAnalysis.diagnosis.confidence >= 0.98
        }
    }
    
    requirement <'SICD-REQ-002'> deliverEffectiveTherapy : EffectivenessRequirement {
        doc /* The S-ICD shall deliver defibrillation therapy with energy between 50 and 80 joules
                to achieve first-shock efficacy ≥95% for ventricular fibrillation termination. */
        
        subject device : SubcutaneousICD;
    }
    
    requirement <'SICD-REQ-003'> minimizeInappropriateShocks : SafetyRequirement {
        doc /* The S-ICD shall maintain inappropriate shock rate below 5% annually by accurately
                discriminating supraventricular tachycardia from ventricular arrhythmias. */
        
        subject device : SubcutaneousICD;
    }
    
    requirement <'SICD-REQ-004'> ensureBatteryLongevity : ReliabilityRequirement {
        doc /* The S-ICD battery shall provide operational power for minimum 7 years under
                normal usage including continuous monitoring and up to 10 therapy deliveries. */
        
        subject device : SubcutaneousICD;
    }
    
    requirement <'SICD-REQ-005'> continuousRhythmMonitoring : PerformanceRequirement {
        doc /* The S-ICD shall continuously monitor cardiac electrical activity with signal
                sampling rate ≥256 Hz and maintain monitoring 24 hours per day, 7 days per week. */
        
        subject device : SubcutaneousICD;
    }
    
    requirement <'SICD-REQ-006'> rapidTherapyDelivery : PerformanceRequirement {
        doc /* Upon confirmed detection of shockable rhythm, the S-ICD shall deliver therapy
                within 15 seconds from initial detection to shock delivery. */
        
        subject device : SubcutaneousICD;
    }
    
    requirement primaryMission {
        doc /* The subcutaneous implantable cardioverter-defibrillator shall protect patients at risk
                of sudden cardiac death by continuously monitoring cardiac rhythm and automatically
                delivering life-saving defibrillation therapy upon detection of life-threatening
                ventricular arrhythmias, without requiring transvenous leads. */
        
        assume constraint patientIndication {
            doc /* Patient has documented risk of sudden cardiac death due to ventricular arrhythmias
                    and meets clinical criteria for ICD implantation. */
        }
        
        require detectVentricularArrhythmias;
        require deliverEffectiveTherapy;
        require minimizeInappropriateShocks;
        require ensureBatteryLongevity;
        require continuousRhythmMonitoring;
        require rapidTherapyDelivery;
    }
    
    part implantedDevice : SubcutaneousICD {
        satisfy primaryMission;
    }
}

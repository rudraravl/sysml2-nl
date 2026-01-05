package ImplantableCardioverterDefibrillatorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ArrhythmiaType {
        attribute name : String;
        attribute severity : Integer;
    }
    
    item def ECGSignal {
        attribute voltage : ElectricPotentialValue;
        attribute frequency : FrequencyValue;
        attribute timestamp : TimeValue;
    }
    
    item def ShockCommand {
        attribute energy : EnergyValue;
        attribute waveform : String;
        attribute duration : TimeValue;
    }
    
    item def PacingPulse {
        attribute amplitude : ElectricPotentialValue;
        attribute width : TimeValue;
        attribute rate : FrequencyValue;
    }
    
    item def DiagnosticData {
        attribute eventType : String;
        attribute timestamp : TimeValue;
        attribute parameters : String;
    }
    
    attribute def BatteryCapacity :> EnergyValue;
    attribute def HeartRateValue :> FrequencyValue;
    
    port def SensingPort {
        in item ecgSignal : ECGSignal;
    }
    
    port def TherapyDeliveryPort {
        out item shockCmd : ShockCommand;
        out item pacingPulse : PacingPulse;
    }
    
    port def PowerPort {
        in attribute voltage : ElectricPotentialValue;
        out attribute currentDraw : ElectricCurrentValue;
    }
    
    port def TelemetryPort {
        out item diagnostics : DiagnosticData;
        in item programmingData : String;
    }
    
    part def Heart {
        attribute currentRate : HeartRateValue;
        port atrialSensing : SensingPort;
        port ventricularSensing : SensingPort;
        port therapyInput : TherapyDeliveryPort;
    }
    
    part def LeadSystem {
        part def AtrialLead {
            port heartConnection : ~SensingPort;
            port deviceConnection : SensingPort;
        }
        part def VentricularLead {
            port heartConnection : ~SensingPort;
            port deviceConnection : SensingPort;
        }
        part def ShockLead {
            port heartConnection : ~TherapyDeliveryPort;
            port deviceConnection : TherapyDeliveryPort;
        }
        
        part atrialLead : AtrialLead;
        part ventricularLead : VentricularLead;
        part shockLead : ShockLead;
    }
    
    part def BatteryModule {
        attribute capacity : BatteryCapacity;
        attribute remainingCharge : BatteryCapacity;
        attribute outputVoltage : ElectricPotentialValue;
        port powerOut : PowerPort;
    }
    
    part def SensingCircuit {
        port atrialInput : SensingPort;
        port ventricularInput : SensingPort;
        attribute processedOutput : ECGSignal;
        
        action def FilterAndAmplify {
            in rawSignal : ECGSignal;
            out filteredSignal : ECGSignal;
        }
        
        perform action processSignals : FilterAndAmplify {
            in rawSignal;
            out filteredSignal;
        }
    }
    
    part def ArrhythmiaDetector {
        attribute ecgInput : ECGSignal;
        attribute detectedArrhythmia : ArrhythmiaType;
        
        action def AnalyzeRhythm {
            in ecgData : ECGSignal;
            out isVentricularFibrillation : Boolean;
            out isVentricularTachycardia : Boolean;
            out isBradycardia : Boolean;
            out isNormalSinus : Boolean;
            out heartRate : HeartRateValue;
        }
        
        perform action continuousAnalysis : AnalyzeRhythm {
            in ecgData;
            out isVentricularFibrillation;
            out isVentricularTachycardia;
            out isBradycardia;
            out isNormalSinus;
            out heartRate;
        }
    }
    
    part def TherapyController {
        attribute therapyMode : String;
        
        action def DetermineTherapy {
            in isVF : Boolean;
            in isVT : Boolean;
            in isBrady : Boolean;
            in heartRate : HeartRateValue;
            out deliverShock : Boolean;
            out shockEnergy : EnergyValue;
            out deliverPacing : Boolean;
            out pacingRate : FrequencyValue;
        }
        
        perform action selectTherapy : DetermineTherapy {
            in isVF;
            in isVT;
            in isBrady;
            in heartRate;
            out deliverShock;
            out shockEnergy;
            out deliverPacing;
            out pacingRate;
        }
    }
    
    part def HighVoltageTherapyUnit {
        attribute chargedEnergy : EnergyValue;
        port therapyOut : TherapyDeliveryPort;
        port powerIn : PowerPort;
        
        action def ChargeCapacitor {
            in targetEnergy : EnergyValue;
            in powerSupply : ElectricPotentialValue;
            out storedEnergy : EnergyValue;
        }
        
        action def DeliverShock {
            in energy : EnergyValue;
            out shock : ShockCommand;
        }
        
        action def DeliverPacing {
            in rate : FrequencyValue;
            out pulse : PacingPulse;
        }
    }
    
    part def TelemetryUnit {
        port telemetryInterface : TelemetryPort;
        
        action def TransmitDiagnostics {
            in eventData : DiagnosticData;
            out transmission : String;
        }
        
        action def ReceiveProgramming {
            in programmingCmd : String;
            out updatedSettings : String;
        }
    }
    
    part def ImplantableCardioverterDefibrillator {
        part battery : BatteryModule {
            attribute :>> capacity = 50000.0[J];
            attribute :>> remainingCharge = 45000.0[J];
            attribute :>> outputVoltage = 3.0[V];
        }
        
        part sensing : SensingCircuit;
        part detector : ArrhythmiaDetector;
        part controller : TherapyController;
        part therapyUnit : HighVoltageTherapyUnit;
        part telemetry : TelemetryUnit;
        
        port atrialSense : SensingPort;
        port ventricularSense : SensingPort;
        port therapyDelivery : TherapyDeliveryPort;
        port externalComm : TelemetryPort;
        
        connection atrialSensing connect atrialSense to sensing.atrialInput;
        connection ventricularSensing connect ventricularSense to sensing.ventricularInput;
        connection powerSupply connect battery.powerOut to therapyUnit.powerIn;
        connection therapyOutput connect therapyUnit.therapyOut to therapyDelivery;
        connection telemetryLink connect telemetry.telemetryInterface to externalComm;
        
        perform action operateICD {
            first start;
            then merge monitoringLoop;
            
            action senseCardiacActivity {
                out atrialSignal : ECGSignal;
                out ventricularSignal : ECGSignal;
            }
            then senseCardiacActivity;
            
            action detectArrhythmia : detector.continuousAnalysis {
                in ecgData = senseCardiacActivity.ventricularSignal;
                out isVentricularFibrillation;
                out isVentricularTachycardia;
                out isBradycardia;
                out isNormalSinus;
                out heartRate;
            }
            then detectArrhythmia;
            
            then decide;
                if detectArrhythmia.isVentricularFibrillation or detectArrhythmia.isVentricularTachycardia then initiateShockTherapy;
                if detectArrhythmia.isBradycardia then initiatePacingTherapy;
                if detectArrhythmia.isNormalSinus then monitoringLoop;
            
            action initiateShockTherapy {
                first start;
                
                action determineShockParameters : controller.selectTherapy {
                    in isVF = detectArrhythmia.isVentricularFibrillation;
                    in isVT = detectArrhythmia.isVentricularTachycardia;
                    in isBrady = false;
                    in heartRate = detectArrhythmia.heartRate;
                    out deliverShock;
                    out shockEnergy;
                }
                then determineShockParameters;
                
                action chargeSystem : therapyUnit.ChargeCapacitor {
                    in targetEnergy = determineShockParameters.shockEnergy;
                    in powerSupply = battery.outputVoltage;
                    out storedEnergy;
                }
                then chargeSystem;
                
                action applyShock : therapyUnit.DeliverShock {
                    in energy = chargeSystem.storedEnergy;
                    out shock;
                }
                then applyShock;
                
                action logShockEvent {
                    in shockData : ShockCommand = applyShock.shock;
                    out eventRecord : DiagnosticData;
                }
                then logShockEvent;
                
                action verifyRhythmRestoration {
                    in postTherapyECG : ECGSignal;
                    out rhythmRestored : Boolean;
                }
                then verifyRhythmRestoration;
            }
            then monitoringLoop;
            
            action initiatePacingTherapy {
                first start;
                
                action determinePacingParameters : controller.selectTherapy {
                    in isVF = false;
                    in isVT = false;
                    in isBrady = detectArrhythmia.isBradycardia;
                    in heartRate = detectArrhythmia.heartRate;
                    out deliverPacing;
                    out pacingRate;
                }
                then determinePacingParameters;
                
                action applyPacing : therapyUnit.DeliverPacing {
                    in rate = determinePacingParameters.pacingRate;
                    out pulse;
                }
                then applyPacing;
                
                action logPacingEvent {
                    in pacingData : PacingPulse = applyPacing.pulse;
                    out eventRecord : DiagnosticData;
                }
                then logPacingEvent;
            }
            then monitoringLoop;
        }
    }
    
    state def ICDOperationalStates {
        entry; then monitoring;
        
        state monitoring {
            entry action performContinuousSensing;
        }
        
        transition monitorToDetection
            first monitoring
            accept rhythmAbnormalityDetected
            then detecting;
        
        state detecting {
            entry action analyzeCardiacRhythm;
        }
        
        transition detectionToCharging
            first detecting
            if lethalArrhythmiaConfirmed
            then charging;
        
        transition detectionToPacing
            first detecting
            if bradycardiaConfirmed
            then pacing;
        
        transition detectionToMonitoring
            first detecting
            if normalRhythmConfirmed
            then monitoring;
        
        state charging {
            entry action chargeHighVoltageCapacitors;
        }
        
        transition chargingToShock
            first charging
            accept capacitorsFullyCharged
            then shocking;
        
        state shocking {
            entry action deliverDefibrillationShock;
        }
        
        transition shockToPostTherapy
            first shocking
            accept shockDelivered
            then postTherapyAssessment;
        
        state pacing {
            entry action deliverBradycardiaPacing;
        }
        
        transition pacingToMonitoring
            first pacing
            accept adequateRateAchieved
            then monitoring;
        
        state postTherapyAssessment {
            entry action evaluateTherapyEffectiveness;
        }
        
        transition assessmentToMonitoring
            first postTherapyAssessment
            if rhythmSuccessfullyRestored
            then monitoring;
        
        transition assessmentToCharging
            first postTherapyAssessment
            if rhythmNotRestored
            then charging;
    }
    
    requirement def FunctionalRequirement;
    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;
    requirement def ReliabilityRequirement;
    
    requirement <'ICD-REQ-001'> primaryICDFunction : FunctionalRequirement {
        doc /* The ICD shall continuously monitor cardiac rhythm and automatically detect life-threatening arrhythmias including ventricular fibrillation and ventricular tachycardia. */
        
        subject icd : ImplantableCardioverterDefibrillator;
    }
    
    requirement <'ICD-REQ-002'> rapidArrhythmiaDetection : PerformanceRequirement {
        doc /* The ICD shall detect ventricular fibrillation within 8 seconds of onset with sensitivity greater than 98%. */
        
        subject detector : ArrhythmiaDetector;
    }
    
    requirement <'ICD-REQ-003'> appropriateTherapyDelivery : SafetyRequirement {
        doc /* The ICD shall deliver defibrillation therapy within 12 seconds of detecting a shockable rhythm with energy between 5 and 40 joules. */
        
        subject icd : ImplantableCardioverterDefibrillator;
    }
    
    requirement <'ICD-REQ-004'> bradycardiaPacingSupport : FunctionalRequirement {
        doc /* The ICD shall provide backup pacing therapy at programmable rates between 40 and 100 beats per minute when bradycardia is detected. */
        
        subject icd : ImplantableCardioverterDefibrillator;
    }
    
    requirement <'ICD-REQ-005'> batteryLongevity : ReliabilityRequirement {
        doc /* The ICD battery shall maintain sufficient capacity to deliver at least 6 full-energy shocks and support continuous monitoring for a minimum of 5 years. */
        
        subject battery : BatteryModule;
    }
    
    requirement <'ICD-REQ-006'> continuousOperation : SafetyRequirement {
        doc /* The ICD shall operate continuously 24 hours per day, 7 days per week, monitoring cardiac activity without interruption. */
        
        subject icd : ImplantableCardioverterDefibrillator;
    }
    
    requirement <'ICD-REQ-007'> diagnosticDataLogging : FunctionalRequirement {
        doc /* The ICD shall log all detected arrhythmias and delivered therapies with timestamps for physician review via telemetry. */
        
        subject telemetry : TelemetryUnit;
    }
    
    requirement icdSystemMission {
        doc /* The ICD system shall protect patients from sudden cardiac death by detecting and treating life-threatening ventricular arrhythmias through automated defibrillation and pacing therapies. */
        
        subject system : ImplantableCardioverterDefibrillator;
        
        require primaryICDFunction;
        require rapidArrhythmiaDetection;
        require appropriateTherapyDelivery;
        require bradycardiaPacingSupport;
        require batteryLongevity;
        require continuousOperation;
        require diagnosticDataLogging;
    }
    
    part icdDeployment {
        part patient {
            part heart : Heart {
                attribute :>> currentRate = 75.0[Hz];
            }
        }
        
        part leadSystem : LeadSystem;
        
        part icdDevice : ImplantableCardioverterDefibrillator {
            satisfy icdSystemMission by self;
        }
        
        connection atrialLeadToHeart connect leadSystem.atrialLead.heartConnection to patient.heart.atrialSensing;
        connection ventricularLeadToHeart connect leadSystem.ventricularLead.heartConnection to patient.heart.ventricularSensing;
        connection shockLeadToHeart connect leadSystem.shockLead.heartConnection to patient.heart.therapyInput;
        
        connection atrialLeadToDevice connect leadSystem.atrialLead.deviceConnection to icdDevice.atrialSense;
        connection ventricularLeadToDevice connect leadSystem.ventricularLead.deviceConnection to icdDevice.ventricularSense;
        connection shockLeadToDevice connect leadSystem.shockLead.deviceConnection to icdDevice.therapyDelivery;
    }
}

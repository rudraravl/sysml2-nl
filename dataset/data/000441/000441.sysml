package DefibrillationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def RhythmAnalysisResult;
    attribute def ShockCommand;
    attribute def SafetyCheckResult;
    attribute def DeviceReadySignal;
    
    enum def CardiacRhythmType {
        ventricularFibrillation;
        ventricularTachycardia;
        normalSinus;
        asystole;
        pulselessElectricalActivity;
    }
    
    enum def ShockAdvice {
        shockAdvised;
        noShockAdvised;
        checkElectrodes;
    }
    
    enum def SystemState {
        standby;
        monitoring;
        analyzing;
        charging;
        armed;
        delivering;
        postShock;
        fault;
    }
    
    attribute def ShockEnergyValue :> ISQ::energy;
    attribute def ImpedanceValue :> ISQ::electricResistance;
    attribute def ECGAmplitudeValue :> ISQ::voltage;
    attribute def ChargeDurationValue :> ISQ::time;
    
    item def ECGWaveform {
        attribute amplitude : ECGAmplitudeValue;
        attribute frequency : ISQ::frequency;
        attribute morphology : String;
    }
    
    item def TherapyPulse {
        attribute energy : ShockEnergyValue;
        attribute peakVoltage : ISQ::voltage;
        attribute pulseDuration : ISQ::time;
        attribute waveformType : String;
    }
    
    port def ECGInputPort {
        in ecgSignal : ECGWaveform;
        in electrodeImpedance : ImpedanceValue;
    }
    
    port def TherapyOutputPort {
        out shockPulse : TherapyPulse;
        in deliveryConfirmation : Boolean;
    }
    
    port def PowerSupplyPort {
        in voltage : ISQ::voltage;
        in current : ISQ::electricCurrent;
    }
    
    port def UserInterfacePort {
        out statusDisplay : SystemState;
        out audioPrompt : String;
        in userCommand : ShockCommand;
    }
    
    part def ElectrodePads {
        port ecgOutput : ~ECGInputPort;
        port therapyInput : ~TherapyOutputPort;
        
        attribute contactImpedance : ImpedanceValue;
        attribute placementVerified : Boolean;
        
        action senseECG {
            out waveform : ECGWaveform;
            out impedance : ImpedanceValue;
        }
        
        action conductShock {
            in pulse : TherapyPulse;
            out delivered : Boolean;
        }
    }
    
    part def ECGAnalysisModule {
        port ecgInput : ECGInputPort;
        
        attribute analysisAlgorithmVersion : String;
        attribute sensitivityLevel : Real;
        
        action analyzeRhythm {
            in ecgData : ECGWaveform;
            in impedance : ImpedanceValue;
            out rhythmType : CardiacRhythmType;
            out shockAdvice : ShockAdvice;
            out confidence : Real;
        }
        
        action filterSignal {
            in rawECG : ECGWaveform;
            out filteredECG : ECGWaveform;
        }
    }
    
    part def EnergyStorageUnit {
        port powerInput : PowerSupplyPort;
        
        attribute capacitance : Real;
        attribute maxStoredEnergy : ShockEnergyValue;
        attribute currentCharge : ShockEnergyValue;
        attribute voltageLevel : ISQ::voltage;
        
        action chargeCapacitor {
            in targetEnergy : ShockEnergyValue;
            out chargeDuration : ChargeDurationValue;
            out finalEnergy : ShockEnergyValue;
        }
        
        action dischargeCapacitor {
            in requestedEnergy : ShockEnergyValue;
            out pulse : TherapyPulse;
        }
        
        action safeDischarge {
            out energyDissipated : ShockEnergyValue;
        }
    }
    
    part def ShockDeliveryCircuit {
        attribute waveformShape : String;
        attribute compensationEnabled : Boolean;
        
        action generateBiphasicPulse {
            in energy : ShockEnergyValue;
            in patientImpedance : ImpedanceValue;
            out pulse : TherapyPulse;
        }
        
        action measureDeliveredEnergy {
            in pulse : TherapyPulse;
            out actualEnergy : ShockEnergyValue;
        }
    }
    
    part def SafetyInterlockSystem {
        attribute electrodeConnectionOK : Boolean;
        attribute impedanceInRange : Boolean;
        attribute chargeComplete : Boolean;
        attribute userConfirmed : Boolean;
        
        action performSafetyChecks {
            in impedance : ImpedanceValue;
            in chargeLevel : ShockEnergyValue;
            in userReady : Boolean;
            out safeToShock : Boolean;
        }
        
        action monitorDelivery {
            in shockInProgress : Boolean;
            out abortSignal : Boolean;
        }
    }
    
    part def ControlProcessor {
        attribute currentState : SystemState;
        attribute selectedEnergy : ShockEnergyValue;
        attribute shockCount : Integer;
        
        action coordinateTherapy;
        
        action updateSystemState {
            in event : String;
            out newState : SystemState;
        }
        
        action selectEnergyLevel {
            in rhythmType : CardiacRhythmType;
            in priorShocks : Integer;
            out energy : ShockEnergyValue;
        }
    }
    
    part def OperatorInterface {
        port uiPort : UserInterfacePort;
        
        attribute displayActive : Boolean;
        attribute audioEnabled : Boolean;
        
        action displayStatus {
            in state : SystemState;
            in advice : ShockAdvice;
        }
        
        action provideGuidance {
            in instruction : String;
            out audioMessage : String;
        }
        
        action acceptShockButton {
            out commandIssued : ShockCommand;
        }
    }
    
    part def BatteryPack {
        port powerOutput : PowerSupplyPort;
        
        attribute capacity : ShockEnergyValue;
        attribute remainingCharge : ShockEnergyValue;
        attribute voltage : ISQ::voltage;
        
        action supplyPower {
            in requiredCurrent : ISQ::electricCurrent;
            out availablePower : Boolean;
        }
    }
    
    action def MonitorCardiacRhythm {
        in ecgWaveform : ECGWaveform;
        in electrodeImpedance : ImpedanceValue;
        out rhythmClassification : CardiacRhythmType;
        out therapyRecommendation : ShockAdvice;
    }
    
    action def PrepareDefibrillator {
        in targetEnergy : ShockEnergyValue;
        out readyToDeliver : DeviceReadySignal;
        out chargeTime : ChargeDurationValue;
    }
    
    action def DeliverDefibrillationShock {
        in shockEnergy : ShockEnergyValue;
        in patientImpedance : ImpedanceValue;
        in safetyConfirmed : Boolean;
        out therapyDelivered : Boolean;
        out deliveredEnergy : ShockEnergyValue;
    }
    
    action def ProvideOperatorGuidance {
        in systemStatus : SystemState;
        in therapyAdvice : ShockAdvice;
        out voicePrompt : String;
        out visualIndication : String;
    }
    
    part def AutomatedExternalDefibrillator {
        part electrodes : ElectrodePads;
        part ecgAnalyzer : ECGAnalysisModule;
        part energyStorage : EnergyStorageUnit;
        part shockCircuit : ShockDeliveryCircuit;
        part safetySystem : SafetyInterlockSystem;
        part controller : ControlProcessor;
        part userInterface : OperatorInterface;
        part battery : BatteryPack;
        
        connect electrodes.ecgOutput to ecgAnalyzer.ecgInput;
        connect battery.powerOutput to energyStorage.powerInput;
        
        perform action executeDefibrillationProtocol {
            first start;
            
            then action initializeSystem {
                first action powerOn;
                then action selfTest;
                then action promptElectrodePlacement;
            }
            
            then merge continuousMonitoring;
            
            action monitorPatient : MonitorCardiacRhythm {
                in ecgWaveform : ECGWaveform;
                in electrodeImpedance : ImpedanceValue;
                out rhythmClassification : CardiacRhythmType;
                out therapyRecommendation : ShockAdvice;
            }
            
            then action provideGuidance : ProvideOperatorGuidance {
                in systemStatus : SystemState;
                in therapyAdvice : ShockAdvice;
                out voicePrompt : String;
                out visualIndication : String;
            }
            
            then decide shockDecision;
                if provideGuidance.therapyAdvice == ShockAdvice::shockAdvised 
                    then prepareTherapy;
                if provideGuidance.therapyAdvice == ShockAdvice::noShockAdvised 
                    then continuousMonitoring;
                if provideGuidance.therapyAdvice == ShockAdvice::checkElectrodes 
                    then troubleshoot;
            
            action prepareTherapy {
                first action announceCharging {
                    action guidance : ProvideOperatorGuidance {
                        in systemStatus : SystemState;
                        in therapyAdvice : ShockAdvice;
                        out voicePrompt : String;
                        out visualIndication : String;
                    }
                }
                
                then action chargeDevice : PrepareDefibrillator {
                    in targetEnergy : ShockEnergyValue;
                    out readyToDeliver : DeviceReadySignal;
                    out chargeTime : ChargeDurationValue;
                }
                
                then action announceReady {
                    action guidance : ProvideOperatorGuidance {
                        in systemStatus : SystemState;
                        in therapyAdvice : ShockAdvice;
                        out voicePrompt : String;
                        out visualIndication : String;
                    }
                }
                
                then action waitForCommand {
                    accept shockButton : ShockCommand;
                }
                
                then action performSafetyCheck {
                    action verify {
                        in impedance : ImpedanceValue;
                        in chargeLevel : ShockEnergyValue;
                        in userReady : Boolean;
                        out safeToShock : Boolean;
                    }
                }
                
                then decide safetyDecision;
                    if performSafetyCheck.verify.safeToShock == true 
                        then deliverTherapy;
                    else abortShock;
                
                action deliverTherapy : DeliverDefibrillationShock {
                    in shockEnergy : ShockEnergyValue;
                    in patientImpedance : ImpedanceValue;
                    in safetyConfirmed : Boolean;
                    out therapyDelivered : Boolean;
                    out deliveredEnergy : ShockEnergyValue;
                }
                
                then action postShockPause {
                    first action wait;
                    then action announcePostShock {
                        action guidance : ProvideOperatorGuidance {
                            in systemStatus : SystemState;
                            in therapyAdvice : ShockAdvice;
                            out voicePrompt : String;
                            out visualIndication : String;
                        }
                    }
                }
                
                then continuousMonitoring;
                
                action abortShock {
                    first action safeDischarge {
                        out energyDissipated : ShockEnergyValue;
                    }
                    then action announceAbort {
                        action guidance : ProvideOperatorGuidance {
                            in systemStatus : SystemState;
                            in therapyAdvice : ShockAdvice;
                            out voicePrompt : String;
                            out visualIndication : String;
                        }
                    }
                }
                then continuousMonitoring;
            }
            
            action troubleshoot {
                action guidance : ProvideOperatorGuidance {
                    in systemStatus : SystemState;
                    in therapyAdvice : ShockAdvice;
                    out voicePrompt : String;
                    out visualIndication : String;
                }
            }
            then continuousMonitoring;
            
            then continuousMonitoring;
        }
    }
    
    requirement def DefibrillationCapability {
        doc /* The system shall detect life-threatening cardiac arrhythmias and deliver 
                controlled electrical therapy to restore normal heart rhythm. */
        
        subject aed : AutomatedExternalDefibrillator;
        
        require constraint rhythmDetection {
            doc /* The system shall accurately identify shockable cardiac rhythms including 
                    ventricular fibrillation and pulseless ventricular tachycardia. */
        }
        
        require constraint energyDelivery {
            doc /* The system shall deliver biphasic defibrillation shocks with controlled 
                    energy levels appropriate to patient impedance. */
        }
        
        require constraint operatorSafety {
            doc /* The system shall prevent shock delivery unless operator confirmation 
                    is received and safety interlocks are satisfied. */
        }
    }
    
    requirement <'DEF-REQ-001'> primaryDefibrillationFunction : DefibrillationCapability {
        doc /* Primary Function: The automated external defibrillator shall continuously monitor 
                a patient's cardiac electrical activity through adhesive chest electrodes, automatically 
                analyze the heart rhythm using advanced signal processing algorithms to distinguish 
                shockable arrhythmias (ventricular fibrillation and pulseless ventricular tachycardia) 
                from non-shockable rhythms, and upon detection of a life-threatening shockable rhythm, 
                charge an internal capacitor to a therapeutically appropriate energy level (typically 
                150-200 joules), provide clear audio and visual guidance to the operator to ensure 
                scene safety, and deliver a controlled biphasic electrical shock through the chest 
                electrodes to depolarize a critical mass of myocardium simultaneously, thereby 
                terminating the chaotic electrical activity and allowing the heart's natural pacemaker 
                to re-establish an organized, perfusing rhythm. */
        
        assume constraint electrodeContact {
            doc /* Electrodes are properly placed on bare chest with adequate skin contact 
                    providing impedance between 25-175 ohms. */
        }
        
        assume constraint powerAvailability {
            doc /* Battery has sufficient charge to complete at least one full therapy cycle 
                    including analysis, charging, and shock delivery. */
        }
        
        require constraint <'DEF-REQ-001.1'> rhythmAnalysisAccuracy {
            doc /* Rhythm analysis shall achieve minimum 90% sensitivity for ventricular 
                    fibrillation and 95% specificity for non-shockable rhythms per AHA guidelines. */
        }
        
        require constraint <'DEF-REQ-001.2'> shockEnergyPrecision {
            doc /* Delivered shock energy shall be within ±15% of selected energy level 
                    across patient impedance range of 25-175 ohms. */
        }
        
        require constraint <'DEF-REQ-001.3'> chargeTimePerformance {
            doc /* System shall charge from zero to maximum energy (200J) in less than 
                    10 seconds at room temperature with new battery. */
        }
        
        require constraint <'DEF-REQ-001.4'> safetyInterlocks {
            doc /* System shall implement multiple safety interlocks preventing accidental 
                    discharge including electrode connection verification, impedance range check, 
                    and explicit operator confirmation. */
        }
        
        require constraint <'DEF-REQ-001.5'> operatorGuidance {
            doc /* System shall provide clear, step-by-step audio and visual prompts 
                    throughout the entire resuscitation sequence. */
        }
    }
    
    requirement <'DEF-REQ-002'> continuousOperationCycle {
        doc /* The system shall operate in a continuous analyze-advise-shock cycle, 
                automatically re-analyzing rhythm after each therapy delivery or at regular 
                intervals during ongoing resuscitation. */
        
        subject aed : AutomatedExternalDefibrillator;
    }
    
    requirement <'DEF-REQ-003'> biphasicWaveform {
        doc /* The system shall deliver therapy using a biphasic truncated exponential 
                waveform optimized for efficacy and reduced myocardial damage. */
        
        subject aed : AutomatedExternalDefibrillator;
    }
}

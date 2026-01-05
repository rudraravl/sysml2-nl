package DefibrillatorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def HeartRhythmType;
    attribute def DeviceMode;
    attribute def AlarmLevel;
    
    attribute def ShockEnergyValue :> ISQ::EnergyValue;
    attribute def ElectricalVoltageValue :> ISQ::VoltageValue;
    attribute def ElectricalCurrentValue :> ISQ::ElectricCurrentValue;
    attribute def PatientImpedanceValue :> ISQ::ResistanceValue;
    
    attribute def ECGSignal {
        attribute amplitude : ElectricalVoltageValue;
        attribute frequency : ISQ::FrequencyValue;
        attribute rhythmType : HeartRhythmType;
    }
    
    attribute def PatientCondition {
        attribute heartRate : Real;
        attribute rhythm : HeartRhythmType;
        attribute isShockable : Boolean;
        attribute impedance : PatientImpedanceValue;
    }
    
    attribute def SystemState {
        attribute mode : DeviceMode;
        attribute batteryLevel : Real;
        attribute capacitorCharge : Real;
        attribute electrodesAttached : Boolean;
        attribute readyToShock : Boolean;
    }
    
    port def ECGMonitorPort {
        out ecgSignal : ECGSignal;
        out patientCondition : PatientCondition;
    }
    
    port def TherapyPort {
        in shockVoltage : ElectricalVoltageValue;
        in shockCurrent : ElectricalCurrentValue;
        out impedanceMeasurement : PatientImpedanceValue;
    }
    
    port def PowerSupplyPort {
        out batteryPower : ISQ::PowerValue;
        out chargedEnergy : ShockEnergyValue;
    }
    
    port def UserInterfacePort {
        in operatorCommand : String;
        out displayMessage : String;
        out audioAlert : String;
        out visualIndicator : AlarmLevel;
    }
    
    port def ControlSignalPort {
        in analysisResult : Boolean;
        in chargeCommand : Boolean;
        in shockCommand : Boolean;
        out systemStatus : SystemState;
    }
    
    part def ECGAnalysisModule {
        port ecgInput : ECGMonitorPort;
        port controlOutput : ControlSignalPort;
        
        attribute analysisAlgorithm : String;
        attribute detectionSensitivity : Real;
        attribute detectionSpecificity : Real;
        
        perform action analyzeCardiacRhythm {
            in ecgData : ECGSignal;
            out rhythmClassification : HeartRhythmType;
            out shockAdvised : Boolean;
            out confidence : Real;
        }
    }
    
    part def HighVoltageCapacitor {
        port powerInput : PowerSupplyPort;
        
        attribute capacitance : Real;
        attribute maxVoltage : ElectricalVoltageValue;
        attribute storedEnergy : ShockEnergyValue;
        attribute chargeTime : ISQ::TimeValue;
        
        perform action chargeToLevel {
            in targetEnergy : ShockEnergyValue;
            in inputPower : ISQ::PowerValue;
            out chargeLevel : Real;
            out timeElapsed : ISQ::TimeValue;
        }
        
        perform action dischargeEnergy {
            in requestedEnergy : ShockEnergyValue;
            in loadImpedance : PatientImpedanceValue;
            out deliveredVoltage : ElectricalVoltageValue;
            out deliveredCurrent : ElectricalCurrentValue;
            out actualEnergy : ShockEnergyValue;
        }
    }
    
    part def TherapyDeliveryCircuit {
        port therapyOutput : TherapyPort;
        port capacitorInput : PowerSupplyPort;
        
        attribute waveformType : String;
        attribute pulseDuration : ISQ::TimeValue;
        attribute biphasicRatio : Real;
        
        perform action deliverBiphasicShock {
            in energy : ShockEnergyValue;
            in patientImpedance : PatientImpedanceValue;
            out phase1Voltage : ElectricalVoltageValue;
            out phase2Voltage : ElectricalVoltageValue;
            out shockSuccess : Boolean;
        }
        
        perform action measurePatientImpedance {
            out impedance : PatientImpedanceValue;
            out contactQuality : Real;
        }
    }
    
    part def MicrocontrollerUnit {
        port uiConnection : UserInterfacePort;
        port controlBus : ControlSignalPort;
        
        attribute operatingMode : DeviceMode;
        attribute safetyInterlocks : Boolean;
        attribute eventLog : String;
        
        perform action orchestrateTherapy {
            in rhythmAnalysis : Boolean;
            in operatorApproval : Boolean;
            in safetyChecks : Boolean;
            out chargeInitiate : Boolean;
            out shockAuthorize : Boolean;
            out abortTherapy : Boolean;
        }
        
        perform action performSelfTest {
            in deviceComponents : SystemState;
            out testPassed : Boolean;
            out faultCodes : String;
        }
    }
    
    part def DefibrillationElectrodes {
        port patientContact : TherapyPort;
        
        attribute electrodeType : String;
        attribute placementLocation : String;
        attribute contactArea : Real;
        attribute gelConductivity : Real;
        attribute skinImpedance : PatientImpedanceValue;
        
        perform action establishContact {
            out contactEstablished : Boolean;
            out impedance : PatientImpedanceValue;
        }
        
        perform action transmitShock {
            in voltage : ElectricalVoltageValue;
            in current : ElectricalCurrentValue;
            out energyDelivered : ShockEnergyValue;
        }
    }
    
    part def BatteryModule {
        port powerOutput : PowerSupplyPort;
        
        attribute batteryType : String;
        attribute nominalVoltage : ElectricalVoltageValue;
        attribute capacity : Real;
        attribute remainingCharge : Real;
        attribute cycleCount : Integer;
        
        perform action providePower {
            in powerDemand : ISQ::PowerValue;
            out availablePower : ISQ::PowerValue;
            out batteryStatus : Real;
        }
    }
    
    part def OperatorInterface {
        port userConnection : UserInterfacePort;
        
        attribute displayType : String;
        attribute audioVolume : Real;
        attribute buttonLayout : String;
        
        perform action displayInstructions {
            in message : String;
            in urgency : AlarmLevel;
            out acknowledged : Boolean;
        }
        
        perform action captureUserInput {
            out commandIssued : String;
            out timestamp : ISQ::TimeValue;
        }
    }
    
    action def AnalyzeHeartRhythm {
        in ecgSignal : ECGSignal;
        in analysisWindow : ISQ::TimeValue;
        out rhythmType : HeartRhythmType;
        out shockable : Boolean;
        out analysisConfidence : Real;
    }
    
    action def ChargeCapacitorBank {
        in targetEnergy : ShockEnergyValue;
        in batteryPower : ISQ::PowerValue;
        in currentCharge : Real;
        out chargeComplete : Boolean;
        out finalEnergy : ShockEnergyValue;
        out chargeDuration : ISQ::TimeValue;
    }
    
    action def DeliverDefibrillationShock {
        in shockEnergy : ShockEnergyValue;
        in patientImpedance : PatientImpedanceValue;
        in waveformParameters : String;
        out therapyDelivered : Boolean;
        out deliveredEnergy : ShockEnergyValue;
        out postShockRhythm : HeartRhythmType;
    }
    
    action def PerformSystemSafetyCheck {
        in deviceStatus : SystemState;
        in patientStatus : PatientCondition;
        in environmentalFactors : String;
        out safeToOperate : Boolean;
        out warningMessages : String;
    }
    
    action def MonitorPostShockResponse {
        in preShockRhythm : HeartRhythmType;
        in deliveredEnergy : ShockEnergyValue;
        out postShockRhythm : HeartRhythmType;
        out rhythmRestored : Boolean;
        out additionalTherapyNeeded : Boolean;
    }
    
    part def AutomatedExternalDefibrillator {
        part ecgAnalyzer : ECGAnalysisModule;
        part energyStorage : HighVoltageCapacitor;
        part therapyCircuit : TherapyDeliveryCircuit;
        part controller : MicrocontrollerUnit;
        part electrodes : DefibrillationElectrodes;
        part battery : BatteryModule;
        part userInterface : OperatorInterface;
        
        attribute systemState : SystemState;
        
        connect battery.powerOutput to energyStorage.powerInput;
        connect energyStorage.powerInput to therapyCircuit.capacitorInput;
        connect therapyCircuit.therapyOutput to electrodes.patientContact;
        connect ecgAnalyzer.controlOutput to controller.controlBus;
        connect controller.uiConnection to userInterface.userConnection;
    }
    
    part automatedExternalDefibrillator : AutomatedExternalDefibrillator {
        perform action executeDefibrillationProtocol {
            first start;
            then action powerOnSequence;
            then action selfTest : PerformSystemSafetyCheck {
                in deviceStatus : SystemState;
                in patientStatus : PatientCondition;
                in environmentalFactors : String;
                out safeToOperate : Boolean;
                out warningMessages : String;
            }
            then decide;
                if selfTest.safeToOperate then proceedToMonitoring;
                if not selfTest.safeToOperate then shutdownSafely;
            
            action proceedToMonitoring {
                first merge continuousMonitoring;
                then action attachElectrodes;
                then action analyzeRhythm : AnalyzeHeartRhythm {
                    in ecgSignal : ECGSignal;
                    in analysisWindow : ISQ::TimeValue;
                    out rhythmType : HeartRhythmType;
                    out shockable : Boolean;
                    out analysisConfidence : Real;
                }
                then decide;
                    if analyzeRhythm.shockable then initiateTherapySequence;
                    if not analyzeRhythm.shockable then continuousMonitoring;
                
                action initiateTherapySequence {
                    first action announceShockAdvised;
                    then action chargeCapacitor : ChargeCapacitorBank {
                        in targetEnergy : ShockEnergyValue;
                        in batteryPower : ISQ::PowerValue;
                        in currentCharge : Real;
                        out chargeComplete : Boolean;
                        out finalEnergy : ShockEnergyValue;
                        out chargeDuration : ISQ::TimeValue;
                    }
                    then action announceReadyToShock;
                    then action waitForOperatorCommand;
                    then action deliverShock : DeliverDefibrillationShock {
                        in shockEnergy = chargeCapacitor.finalEnergy;
                        in patientImpedance : PatientImpedanceValue;
                        in waveformParameters : String;
                        out therapyDelivered : Boolean;
                        out deliveredEnergy : ShockEnergyValue;
                        out postShockRhythm : HeartRhythmType;
                    }
                    then action assessResponse : MonitorPostShockResponse {
                        in preShockRhythm = analyzeRhythm.rhythmType;
                        in deliveredEnergy = deliverShock.deliveredEnergy;
                        out postShockRhythm : HeartRhythmType;
                        out rhythmRestored : Boolean;
                        out additionalTherapyNeeded : Boolean;
                    }
                    then decide;
                        if assessResponse.rhythmRestored then continuousMonitoring;
                        if assessResponse.additionalTherapyNeeded then initiateTherapySequence;
                }
            }
            action shutdownSafely;
            then done;
        }
    }
    
    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;
    requirement def ReliabilityRequirement;
    requirement def UsabilityRequirement;
    
    requirement <'AED-REQ-001'> shockEnergyDelivery : PerformanceRequirement {
        doc /* The defibrillator shall deliver a biphasic truncated exponential 
             waveform shock with selectable energy levels from 50 to 360 joules 
             with accuracy within ±15% of the selected energy into a 50 ohm load. */
        
        subject automatedExternalDefibrillator.energyStorage;
    }
    
    requirement <'AED-REQ-002'> rhythmDetectionAccuracy : PerformanceRequirement {
        doc /* The ECG analysis algorithm shall detect ventricular fibrillation 
             and ventricular tachycardia with sensitivity greater than 90% and 
             specificity greater than 95% within 15 seconds of rhythm acquisition. */
        
        subject automatedExternalDefibrillator.ecgAnalyzer;
        
        require constraint {
            automatedExternalDefibrillator.ecgAnalyzer.detectionSensitivity > 0.90 and
            automatedExternalDefibrillator.ecgAnalyzer.detectionSpecificity > 0.95
        }
    }
    
    requirement <'AED-REQ-003'> batteryCapacity : ReliabilityRequirement {
        doc /* The battery shall provide sufficient capacity for a minimum of 
             200 shocks at maximum energy or 8 hours of continuous monitoring 
             at 25 degrees Celsius ambient temperature. */
        
        subject automatedExternalDefibrillator.battery;
        
        require constraint {
            automatedExternalDefibrillator.battery.remainingCharge >= 0.15
        }
    }
    
    requirement <'AED-REQ-004'> impedanceCompensation : SafetyRequirement {
        doc /* The system shall measure patient transthoracic impedance between 
             25 and 175 ohms and automatically adjust shock waveform parameters 
             to compensate for measured impedance variations. */
        
        subject automatedExternalDefibrillator.therapyCircuit;
    }
    
    requirement <'AED-REQ-005'> electrodeContactVerification : SafetyRequirement {
        doc /* The device shall verify proper electrode contact with the patient 
             and prevent shock delivery if contact impedance exceeds safe limits 
             or electrodes are not properly attached. */
        
        subject automatedExternalDefibrillator.electrodes;
        
        assume constraint {
            automatedExternalDefibrillator.controller.safetyInterlocks == true
        }
        
        require constraint {
            automatedExternalDefibrillator.systemState.electrodesAttached == true
        }
    }
    
    requirement <'AED-REQ-006'> chargeTime : PerformanceRequirement {
        doc /* The capacitor shall charge to maximum energy level within 10 seconds 
             from a fully charged battery at 20 degrees Celsius. */
        
        subject automatedExternalDefibrillator.energyStorage;
    }
    
    requirement <'AED-REQ-007'> userGuidance : UsabilityRequirement {
        doc /* The device shall provide clear voice prompts and visual indicators 
             to guide untrained operators through the complete defibrillation 
             sequence including electrode placement, rhythm analysis, and shock delivery. */
        
        subject automatedExternalDefibrillator.userInterface;
    }
    
    requirement <'AED-REQ-008'> postShockAnalysis : PerformanceRequirement {
        doc /* The system shall automatically re-analyze cardiac rhythm within 
             5 seconds following shock delivery to determine therapy effectiveness 
             and need for additional intervention. */
        
        subject automatedExternalDefibrillator.ecgAnalyzer;
    }
    
    requirement <'AED-MISSION'> primaryMissionRequirement {
        doc /* The Automated External Defibrillator system shall restore normal 
             cardiac rhythm in patients experiencing sudden cardiac arrest due to 
             ventricular fibrillation or pulseless ventricular tachycardia by 
             automatically analyzing heart rhythm and delivering controlled electrical 
             therapy when medically appropriate, while ensuring operator and patient 
             safety throughout the intervention. */
        
        subject automatedExternalDefibrillator;
        
        require shockEnergyDelivery;
        require rhythmDetectionAccuracy;
        require batteryCapacity;
        require impedanceCompensation;
        require electrodeContactVerification;
        require chargeTime;
        require userGuidance;
        require postShockAnalysis;
    }
}

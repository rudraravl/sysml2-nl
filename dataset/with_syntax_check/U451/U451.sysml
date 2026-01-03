package WearableCardioverterDefibrillatorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def HeartRateValue :> FrequencyValue;
    attribute def ShockEnergyValue :> EnergyValue;
    attribute def VoltageValue :> ElectricPotentialValue;
    attribute def CurrentValue :> ElectricCurrentValue;

    enum def CardiacRhythmType {
        normalSinusRhythm;
        ventricularTachycardia;
        ventricularFibrillation;
        asystole;
        supraventricularTachycardia;
    }

    enum def SystemStateType {
        monitoring;
        analyzing;
        alerting;
        charging;
        delivering;
        postTherapy;
    }

    enum def PatientResponseType {
        responsive;
        unresponsive;
        noResponse;
    }

    item def ECGSignalData {
        attribute amplitude : VoltageValue;
        attribute heartRate : HeartRateValue;
        attribute rhythmType : CardiacRhythmType;
        attribute signalQuality : Real;
    }

    item def TherapyCommand {
        attribute shockEnergy : ShockEnergyValue;
        attribute deliveryAuthorized : Boolean;
    }

    item def AlertSignal {
        attribute alertType : String;
        attribute duration : DurationValue;
    }

    port def ECGSensingPort {
        out item ecgData : ECGSignalData;
    }

    port def TherapyDeliveryPort {
        in item therapyCmd : TherapyCommand;
    }

    port def PatientAlertPort {
        out item alert : AlertSignal;
    }

    port def ResponseInputPort {
        in item response : PatientResponseType;
    }

    part def ECGElectrodeArray {
        attribute :>> mass : MassValue;
        attribute numberOfElectrodes : Integer = 4;
        attribute skinContactQuality : Real;
        port sensingOutput : ECGSensingPort;

        perform action acquireECG {
            out ecgSignal : ECGSignalData;
        }
    }

    part def RhythmAnalysisProcessor {
        attribute processingRate : FrequencyValue;
        attribute detectionSensitivity : Real;
        port ecgInput : ~ECGSensingPort;
        port analysisOutput {
            out rhythmClassification : CardiacRhythmType;
            out shockableRhythm : Boolean;
        }

        perform action analyzeCardiacRhythm {
            in ecgData : ECGSignalData;
            out detectedRhythm : CardiacRhythmType;
            out requiresTherapy : Boolean;
        }
    }

    part def PatientAlertModule {
        attribute vibrationIntensity : Real;
        attribute audioVolume : Real;
        attribute alertDuration : DurationValue;
        port alertOutput : PatientAlertPort;
        port responseInput : ResponseInputPort;

        perform action issuePatientWarning {
            first start;
            then action activateVibration;
            then action soundAudibleAlarm {
                doc /* Emit loud audible warning to alert patient and bystanders */
            }
            then action waitForPatientResponse {
                out patientResponded : Boolean;
            }
            then done;
        }
    }

    part def HighVoltageCapacitor {
        attribute maxStoredEnergy : ShockEnergyValue;
        attribute currentCharge : ShockEnergyValue;
        attribute chargingTime : DurationValue;
        attribute voltage : VoltageValue;

        port chargeControl {
            in startCharge : Boolean;
            out chargeReady : Boolean;
        }

        perform action chargeToTherapyLevel {
            in targetEnergy : ShockEnergyValue;
            out energyStored : ShockEnergyValue;
            out readyToDeliver : Boolean;
        }
    }

    part def TherapyElectrodes {
        attribute :>> mass : MassValue;
        attribute electrodeArea : AreaValue;
        attribute impedance : Real;
        port therapyInput : TherapyDeliveryPort;

        perform action deliverDefibrillationShock {
            in shockEnergy : ShockEnergyValue;
            out shockDelivered : Boolean;
        }
    }

    part def PowerManagementUnit {
        attribute batteryCapacity : Real;
        attribute batteryVoltage : VoltageValue;
        attribute remainingCapacity : Real;
        attribute estimatedOperatingTime : DurationValue;

        port powerOutput {
            out powerAvailable : Boolean;
            out batteryLevel : Real;
        }

        perform action managePowerDistribution {
            out sufficientPower : Boolean;
        }
    }

    part def CentralControlUnit {
        attribute firmwareVersion : String;
        attribute operationalState : SystemStateType;

        port ecgDataInput : ~ECGSensingPort;
        port rhythmAnalysisInput {
            in rhythmType : CardiacRhythmType;
            in shockable : Boolean;
        }
        port patientResponseInput : ResponseInputPort;
        port alertControl : ~PatientAlertPort;
        port capacitorControl {
            out initiateCharge : Boolean;
            in chargeStatus : Boolean;
        }
        port therapyControl : ~TherapyDeliveryPort;

        perform action executeWCDProtocol {
            first start;
            then merge continuousMonitoring;

            then action monitorHeartRhythm {
                in ecgInput : ECGSignalData;
                out currentRhythm : CardiacRhythmType;
            }

            then decide;
                if monitorHeartRhythm.currentRhythm == CardiacRhythmType::ventricularFibrillation 
                    or monitorHeartRhythm.currentRhythm == CardiacRhythmType::ventricularTachycardia
                    then initiateAlertSequence;
                if monitorHeartRhythm.currentRhythm == CardiacRhythmType::normalSinusRhythm
                    or monitorHeartRhythm.currentRhythm == CardiacRhythmType::supraventricularTachycardia
                    then continuousMonitoring;

            action initiateAlertSequence {
                then action alertPatient;
                then action checkPatientResponse {
                    out patientResponse : PatientResponseType;
                }
            }

            then decide;
                if initiateAlertSequence.checkPatientResponse.patientResponse == PatientResponseType::responsive
                    then continuousMonitoring;
                if initiateAlertSequence.checkPatientResponse.patientResponse == PatientResponseType::unresponsive
                    or initiateAlertSequence.checkPatientResponse.patientResponse == PatientResponseType::noResponse
                    then initiateTherapySequence;

            action initiateTherapySequence {
                then action chargeCapacitors {
                    out capacitorReady : Boolean;
                }
                then action deliverShock {
                    in energy : ShockEnergyValue;
                }
                then action assessPostShock {
                    out rhythmConverted : Boolean;
                }
            }

            then decide;
                if initiateTherapySequence.assessPostShock.rhythmConverted then continuousMonitoring;
                if not initiateTherapySequence.assessPostShock.rhythmConverted then initiateAlertSequence;

            then done;
        }
    }

    part def WearableGarment {
        attribute :>> mass : MassValue;
        attribute garmentSize : String;
        attribute material : String;

        part electrodeHolders[4];
        part sensorPockets[4];
        part devicePouch;
    }

    part def WearableCardioverterDefibrillator {
        doc /* A wearable cardioverter defibrillator (WCD) is a life-saving medical device 
             * that continuously monitors a patient's heart rhythm and automatically delivers 
             * electrical therapy to restore normal cardiac rhythm when life-threatening 
             * ventricular arrhythmias are detected. The system provides protection against 
             * sudden cardiac arrest for patients at temporary high risk. */

        attribute :>> mass : MassValue;
        attribute deviceIdentifier : String;

        part garment : WearableGarment {
            attribute :>> mass = 600 [SI::g];
            attribute :>> garmentSize = "Medium";
            attribute :>> material = "Breathable fabric";
        }

        part ecgElectrodes : ECGElectrodeArray {
            attribute :>> mass = 80 [SI::g];
            attribute :>> numberOfElectrodes = 4;
            attribute :>> skinContactQuality = 0.95;
        }

        part rhythmProcessor : RhythmAnalysisProcessor {
            attribute :>> processingRate = 250 [Hz];
            attribute :>> detectionSensitivity = 0.98;
        }

        part alertModule : PatientAlertModule {
            attribute :>> vibrationIntensity = 0.8;
            attribute :>> audioVolume = 85;
            attribute :>> alertDuration = 30 [s];
        }

        part capacitor : HighVoltageCapacitor {
            attribute :>> maxStoredEnergy = 150 [J];
            attribute :>> chargingTime = 12 [s];
            attribute :>> voltage = 1800 [V];
        }

        part therapyElectrodes : TherapyElectrodes {
            attribute :>> mass = 120 [SI::g];
            attribute :>> electrodeArea = 80 [cm^2];
            attribute :>> impedance = 50;
        }

        part powerUnit : PowerManagementUnit {
            attribute :>> batteryCapacity = 6000;
            attribute :>> batteryVoltage = 14.4 [V];
            attribute :>> remainingCapacity = 5400;
            attribute :>> estimatedOperatingTime = 24 [h];
        }

        part controller : CentralControlUnit {
            attribute :>> firmwareVersion = "v3.2.1";
            attribute :>> operationalState = SystemStateType::monitoring;
        }

        connection ecgToProcessor connect ecgElectrodes.sensingOutput to rhythmProcessor.ecgInput;
        connection ecgToController connect ecgElectrodes.sensingOutput to controller.ecgDataInput;
        connection processorToController connect rhythmProcessor.analysisOutput to controller.rhythmAnalysisInput;
        connection controllerToAlert connect controller.alertControl to alertModule.alertOutput;
        connection alertToController connect alertModule.responseInput to controller.patientResponseInput;
        connection controllerToCapacitor connect controller.capacitorControl to capacitor.chargeControl;
        connection controllerToTherapy connect controller.therapyControl to therapyElectrodes.therapyInput;
        connection powerToSystem connect powerUnit.powerOutput to controller;

        perform action automaticArrhythmiaManagement references controller.executeWCDProtocol;

        assert constraint deviceMassLimit {
            mass <= 2500 [SI::g]
        }

        assert constraint batteryLifeRequirement {
            powerUnit.estimatedOperatingTime >= 20 [h]
        }
    }

    package StakeholderRequirements {
        requirement <'SR-001'> protectAgainstSuddenCardiacArrest {
            doc /* The WCD system shall protect patients at risk of sudden cardiac arrest 
                 * by continuously monitoring cardiac rhythm and delivering life-saving therapy 
                 * when life-threatening arrhythmias are detected. */
            subject wcd : WearableCardioverterDefibrillator;
        }

        requirement <'SR-002'> continuousRhythmMonitoring {
            doc /* The WCD shall provide continuous, uninterrupted monitoring of the patient's 
                 * cardiac rhythm throughout the wearing period. */
            subject wcd : WearableCardioverterDefibrillator;
        }

        requirement <'SR-003'> automaticTherapyDelivery {
            doc /* The WCD shall automatically deliver defibrillation therapy when ventricular 
                 * fibrillation or ventricular tachycardia is detected, without requiring 
                 * manual intervention. */
            subject wcd : WearableCardioverterDefibrillator;
        }

        requirement <'SR-004'> patientWarningSystem {
            doc /* The WCD shall provide adequate warning to conscious patients before 
                 * delivering therapy, allowing them to prevent unnecessary shocks. */
            subject wcd : WearableCardioverterDefibrillator;
        }

        requirement <'SR-005'> wearableComfort {
            doc /* The WCD shall be designed for continuous wear with minimal impact 
                 * on patient mobility and daily activities. */
            subject wcd : WearableCardioverterDefibrillator;
        }
    }

    package SystemRequirements {
        requirement <'SYS-001'> arrhythmiaDetectionAccuracy {
            subject processor :>> WearableCardioverterDefibrillator::rhythmProcessor;
            doc /* The rhythm analysis processor shall detect ventricular fibrillation 
                 * and ventricular tachycardia with sensitivity >= 98%. */
            assert constraint {
                processor.detectionSensitivity >= 0.98
            }
        }

        requirement <'SYS-002'> therapyEnergyRange {
            subject capacitor :>> WearableCardioverterDefibrillator::capacitor;
            doc /* The capacitor shall deliver defibrillation energy between 75 and 150 joules. */
            assert constraint {
                capacitor.maxStoredEnergy >= 75 [J] and capacitor.maxStoredEnergy <= 150 [J]
            }
        }

        requirement <'SYS-003'> alertDurationCompliance {
            subject alert :>> WearableCardioverterDefibrillator::alertModule;
            doc /* Patient alert duration shall be between 25 and 60 seconds to allow 
                 * adequate response time. */
            assert constraint {
                alert.alertDuration >= 25 [s] and alert.alertDuration <= 60 [s]
            }
        }

        requirement <'SYS-004'> capacitorChargeTime {
            subject capacitor :>> WearableCardioverterDefibrillator::capacitor;
            doc /* Capacitor charging time shall not exceed 15 seconds to ensure 
                 * rapid therapy delivery. */
            assert constraint {
                capacitor.chargingTime <= 15 [s]
            }
        }

        requirement <'SYS-005'> deviceWeight {
            subject wcd :>> WearableCardioverterDefibrillator;
            doc /* Total device weight shall not exceed 2.5 kg for patient comfort 
                 * during extended wear. */
            assert constraint {
                wcd.mass <= 2500 [SI::g]
            }
        }

        requirement <'SYS-006'> batteryOperatingDuration {
            subject power :>> WearableCardioverterDefibrillator::powerUnit;
            doc /* Battery shall provide minimum 20 hours of continuous operation 
                 * with monitoring and therapy capability. */
            assert constraint {
                power.estimatedOperatingTime >= 20 [h]
            }
        }

        requirement <'SYS-007'> ecgSamplingRate {
            subject processor :>> WearableCardioverterDefibrillator::rhythmProcessor;
            doc /* ECG signal processing shall occur at minimum 250 Hz sampling rate 
                 * for accurate rhythm analysis. */
            assert constraint {
                processor.processingRate >= 250 [Hz]
            }
        }
    }

    part wcdInstance : WearableCardioverterDefibrillator {
        attribute :>> mass = 2200 [SI::g];
        attribute :>> deviceIdentifier = "WCD-2024-001";

        part :>> capacitor {
            attribute :>> currentCharge = 0 [J];
        }

        part :>> powerUnit {
            attribute :>> remainingCapacity = 5800;
        }
    }

    satisfy StakeholderRequirements::protectAgainstSuddenCardiacArrest by wcdInstance;
    satisfy StakeholderRequirements::continuousRhythmMonitoring by wcdInstance;
    satisfy StakeholderRequirements::automaticTherapyDelivery by wcdInstance;
    satisfy StakeholderRequirements::patientWarningSystem by wcdInstance;
    satisfy StakeholderRequirements::wearableComfort by wcdInstance;
}

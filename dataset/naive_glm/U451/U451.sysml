package WCD {
    public import ScalarValues::*;

    // ===== Units =====
    unit def s;
    unit def J;
    unit def V;
    unit def A;
    unit def h;
    unit def bpm;
    unit def ohm;
    unit def pct;
    unit def dB;
    unit def W;
    unit def g;
    unit def cm2;

    // ===== Value Types =====
    value def Voltage :> Real { unit = V; }
    value def Energy :> Real { unit = J; }
    value def Current :> Real { unit = A; }
    value def TimeDuration :> Real { unit = s; }
    value def HeartRateValue :> Real { unit = bpm; }
    value def Impedance :> Real { unit = ohm; }
    value def BatteryLevel :> Real { unit = pct; }
    value def SoundLevel :> Real { unit = dB; }
    value def PowerValue :> Real { unit = W; }
    value def Mass :> Real { unit = g; }
    value def Area :> Real { unit = cm2; }

    // ===== Enumerations =====
    enum def RhythmType {
        literal normal;
        literal sinusTachycardia;
        literal ventricularTachycardia;
        literal ventricularFibrillation;
        literal asystole;
    }

    enum def OperationalState {
        literal monitoring;
        literal alerting;
        literal charging;
        literal delivering;
        literal postShockMonitoring;
    }

    // ===== Item Types =====
    item def ECGSample {
        attribute timestamp : TimeDuration;
        attribute lead1 : Real;
        attribute lead2 : Real;
        attribute lead3 : Real;
        attribute lead4 : Real;
        attribute signalValid : Boolean;
    }

    item def RhythmClassification {
        attribute rhythmType : RhythmType;
        attribute confidence : Real;
        attribute timestamp : TimeDuration;
    }

    item def AlertCommand {
        attribute activate : Boolean;
        attribute vibrationIntensity : Real;
        attribute alarmVolume : SoundLevel;
    }

    item def ChargeCommand {
        attribute activate : Boolean;
        attribute targetEnergy : Energy;
    }

    item def ShockCommand {
        attribute deliver : Boolean;
        attribute energy : Energy;
    }

    item def CancelSignal {
        attribute pressed : Boolean;
        attribute timestamp : TimeDuration;
    }

    item def BatteryStatus {
        attribute chargeLevel : BatteryLevel;
        attribute estimatedRemaining : TimeDuration;
        attribute lowBattery : Boolean;
    }

    item def PowerSupply {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def CapacitorStatus {
        attribute isCharged : Boolean;
        attribute shockDelivered : Boolean;
        attribute currentEnergy : Energy;
    }

    // ===== Port Definitions =====
    port def ECGOutputPort {
        out ecgSamples : ECGSample;
    }

    port def ECGInputPort {
        in ecgSamples : ECGSample;
    }

    port def RhythmOutputPort {
        out rhythmClassification : RhythmClassification;
    }

    port def RhythmInputPort {
        in rhythmClassification : RhythmClassification;
    }

    port def AlertControlPort {
        in alertCommand : AlertCommand;
    }

    port def CancelOutputPort {
        out cancelSignal : CancelSignal;
    }

    port def CancelInputPort {
        in cancelSignal : CancelSignal;
    }

    port def ChargeControlPort {
        in chargeCommand : ChargeCommand;
    }

    port def ShockControlPort {
        in shockCommand : ShockCommand;
    }

    port def CapacitorStatusOutputPort {
        out status : CapacitorStatus;
    }

    port def CapacitorStatusInputPort {
        in status : CapacitorStatus;
    }

    port def TherapyDeliveryPort {
        out shockEnergy : Energy;
    }

    port def TherapyReceivePort {
        in shockEnergy : Energy;
    }

    port def PowerOutputPort {
        out powerSupply : PowerSupply;
    }

    port def PowerInputPort {
        in powerSupply : PowerSupply;
    }

    port def BatteryStatusOutputPort {
        out batteryStatus : BatteryStatus;
    }

    port def BatteryStatusInputPort {
        in batteryStatus : BatteryStatus;
    }

    // ===== Requirements =====
    requirement def ContinuousMonitoringRequirement {
        doc /* The WCD shall continuously monitor the patient's ECG at all times during operation. */
        subject wcd : WCDSystem;
    }

    requirement def ArrhythmiaDetectionRequirement {
        doc /* The rhythm analysis processor shall detect ventricular tachycardia and ventricular fibrillation within maxDetectionTime seconds. */
        subject processor : RhythmAnalysisProcessor;
        attribute maxDetectionTime : TimeDuration = 10 [s];
    }

    requirement def PatientAlertRequirement {
        doc /* The patient alert module shall produce vibration and audible alarm for at least alertDuration before delivering therapy. */
        subject alertModule : PatientAlertModule;
        attribute alertDuration : TimeDuration = 20 [s];
        attribute minAlarmVolume : SoundLevel = 85 [dB];
    }

    requirement def ShockCancellationRequirement {
        doc /* A conscious patient shall be able to cancel an imminent shock by pressing the cancel button during the alert period. */
        subject wcd : WCDSystem;
    }

    requirement def DefibrillationEnergyRequirement {
        doc /* The high-voltage capacitor shall charge to between minEnergy and maxEnergy within chargeTime seconds. */
        subject capacitor : HighVoltageCapacitor;
        attribute minEnergy : Energy = 75 [J];
        attribute maxEnergy : Energy = 150 [J];
        attribute chargeTime : TimeDuration = 10 [s];
    }

    requirement def BatteryLifeRequirement {
        doc /* The battery pack shall provide at least minOperatingTime hours of continuous operation on a single charge. */
        subject battery : BatteryPack;
        attribute minOperatingTime : TimeDuration = 20 [h];
    }

    requirement def PostShockMonitoringRequirement {
        doc /* Following therapy delivery, the WCD shall resume ECG monitoring within postShockMonitoringDelay seconds. */
        subject wcd : WCDSystem;
        attribute postShockMonitoringDelay : TimeDuration = 30 [s];
    }

    requirement def GarmentComfortRequirement {
        doc /* The garment shall be comfortable and breathable for continuous wear with a maximum weight of maxWeight grams. */
        subject garment : Garment;
        attribute maxWeight : Mass = 500 [g];
    }

    // ===== Part Definitions =====

    part def ECGElectrode {
        port ecgOut : ECGOutputPort;
        attribute electrodeId : String;
        attribute contactImpedance : Impedance = 500 [ohm];
        attribute samplingRate : Real = 250;
        attribute isActive : Boolean = true;

        action def SenseECGActivity {
            in skinContact : Boolean;
            out sample : ECGSample;
        }

        perform action sense : SenseECGActivity {
            out sample = ecgOut.ecgSamples;
        }
    }

    part def TherapyElectrode {
        port therapyIn : TherapyReceivePort;
        attribute electrodeId : String;
        attribute contactImpedance : Impedance = 75 [ohm];
        attribute surfaceArea : Area = 50 [cm2];

        action def DeliverTherapy {
            in energy : Energy;
            out deliveredEnergy : Energy;
        }

        perform action deliver : DeliverTherapy {
            in energy = therapyIn.shockEnergy;
        }
    }

    part def RhythmAnalysisProcessor {
        port ecgIn : ECGInputPort;
        port rhythmOut : RhythmOutputPort;
        port powerIn : PowerInputPort;

        attribute samplingRate : Real = 250;
        attribute analysisWindow : TimeDuration = 8 [s];
        attribute vtHeartRateThreshold : HeartRateValue = 180 [bpm];
        attribute vfDetectionSensitivity : Real = 0.90;
        attribute vfDetectionSpecificity : Real = 0.95;
        attribute processingDelay : TimeDuration = 2 [s];

        action def AnalyzeRhythm {
            in samples : ECGSample;
            out classification : RhythmClassification;
        }

        perform action analyze : AnalyzeRhythm {
            in samples = ecgIn.ecgSamples;
            out classification = rhythmOut.rhythmClassification;
        }
    }

    part def PatientAlertModule {
        port alertIn : AlertControlPort;
        port cancelOut : CancelOutputPort;
        port powerIn : PowerInputPort;

        attribute vibrationMotorEnabled : Boolean = false;
        attribute alarmEnabled : Boolean = false;
        attribute alarmVolume : SoundLevel = 90 [dB];
        attribute vibrationIntensity : Real = 2.0;
        attribute alertDuration : TimeDuration = 20 [s];
        attribute cancelButtonPressed : Boolean = false;

        action def ActivateAlert {
            in command : AlertCommand;
            out vibrationActive : Boolean;
            out alarmActive : Boolean;
        }

        action def MonitorCancelButton {
            out pressed : Boolean;
        }

        perform action activate : ActivateAlert {
            in command = alertIn.alertCommand;
        }

        perform action monitorCancel : MonitorCancelButton {
            out pressed = cancelOut.cancelSignal.pressed;
        }
    }

    part def HighVoltageCapacitor {
        port chargeIn : ChargeControlPort;
        port shockIn : ShockControlPort;
        port statusOut : CapacitorStatusOutputPort;
        port therapyOut : TherapyDeliveryPort;
        port powerIn : PowerInputPort;

        attribute maxEnergy : Energy = 150 [J];
        attribute currentEnergy : Energy = 0 [J];
        attribute chargeTime : TimeDuration = 10 [s];
        attribute maxVoltage : Voltage = 2000 [V];
        attribute currentVoltage : Voltage = 0 [V];
        attribute isCharged : Boolean = false;
        attribute shockDelivered : Boolean = false;

        action def ChargeCapacitor {
            in targetEnergy : Energy;
            out charged : Boolean;
        }

        action def DischargeCapacitor {
            in deliver : Boolean;
            out energyDelivered : Energy;
        }

        perform action charge : ChargeCapacitor {
            in targetEnergy = chargeIn.chargeCommand.targetEnergy;
            out charged = statusOut.status.isCharged;
        }

        perform action discharge : DischargeCapacitor {
            in deliver = shockIn.shockCommand.deliver;
            out energyDelivered = therapyOut.shockEnergy;
        }
    }

    part def BatteryPack {
        port powerOut : PowerOutputPort;
        port statusOut : BatteryStatusOutputPort;

        attribute capacity : Real = 5000;
        attribute nominalVoltage : Voltage = 3.7 [V];
        attribute currentCharge : BatteryLevel = 100 [pct];
        attribute estimatedRuntime : TimeDuration = 24 [h];
        attribute lowBatteryThreshold : BatteryLevel = 20 [pct];
        attribute isRechargeable : Boolean = true;

        action def SupplyPower {
            out supply : PowerSupply;
            out status : BatteryStatus;
        }

        perform action supply : SupplyPower {
            out supply = powerOut.powerSupply;
            out status = statusOut.batteryStatus;
        }
    }

    part def CentralControlUnit {
        port ecgDataIn : ECGInputPort;
        port ecgDataOut : ECGOutputPort;
        port rhythmDataIn : RhythmInputPort;
        port alertControlOut : AlertControlPort;
        port chargeControlOut : ChargeControlPort;
        port shockControlOut : ShockControlPort;
        port capacitorStatusIn : CapacitorStatusInputPort;
        port cancelIn : CancelInputPort;
        port powerIn : PowerInputPort;
        port batteryStatusIn : BatteryStatusInputPort;

        attribute shockEnergy : Energy = 150 [J];
        attribute maxAlertWaitTime : TimeDuration = 20 [s];
        attribute maxPostShockMonitorTime : TimeDuration = 30 [s];
        attribute maxChargeTime : TimeDuration = 10 [s];
        attribute currentState : OperationalState = OperationalState::monitoring;

        action def ProcessECGData {
            in ecgSamples : ECGSample;
            out forwardedSamples : ECGSample;
        }

        perform action processECG : ProcessECGData {
            in ecgSamples = ecgDataIn.ecgSamples;
            out forwardedSamples = ecgDataOut.ecgSamples;
        }

        state machine ControlBehavior {
            entry; then Monitoring;

            state Monitoring {
                doc /* Continuous ECG monitoring state. */
                entry {
                    currentState = OperationalState::monitoring;
                }
                do {
                    /* Continuously receive ECG data and forward to rhythm processor for analysis. */
                }
                transition monitoringToAlert
                    first Monitoring
                    if rhythmDataIn.rhythmClassification.rhythmType == RhythmType::ventricularTachycardia
                       or rhythmDataIn.rhythmClassification.rhythmType == RhythmType::ventricularFibrillation
                    then PatientAlert;
            }

            state PatientAlert {
                doc /* Alert patient with vibration and audible alarm before potential shock delivery. */
                entry {
                    currentState = OperationalState::alerting;
                    alertControlOut.alertCommand.activate = true;
                    alertControlOut.alertCommand.vibrationIntensity = 2.0;
                    alertControlOut.alertCommand.alarmVolume = 90 [dB];
                }
                do {
                    /* Wait for patient cancel response or alert timeout. */
                }
                transition alertToCharging
                    first PatientAlert
                    if cancelIn.cancelSignal.pressed == false
                    then Charging;
                transition alertToMonitoring
                    first PatientAlert
                    if cancelIn.cancelSignal.pressed == true
                    then Monitoring;
            }

            state Charging {
                doc /* Charge high-voltage capacitor to target energy level. */
                entry {
                    currentState = OperationalState::charging;
                    chargeControlOut.chargeCommand.activate = true;
                    chargeControlOut.chargeCommand.targetEnergy = shockEnergy;
                }
                do {
                    /* Monitor capacitor charging progress. */
                }
                transition chargingToShock
                    first Charging
                    if capacitorStatusIn.status.isCharged == true
                    then ShockDelivery;
            }

            state ShockDelivery {
                doc /* Deliver controlled defibrillation shock through therapy electrodes. */
                entry {
                    currentState = OperationalState::delivering;
                    shockControlOut.shockCommand.deliver = true;
                    shockControlOut.shockCommand.energy = shockEnergy;
                }
                transition shockToPostTherapy
                    first ShockDelivery
                    if capacitorStatusIn.status.shockDelivered == true
                    then PostShockMonitoring;
            }

            state PostShockMonitoring {
                doc /* Resume ECG monitoring to assess shock effectiveness. */
                entry {
                    currentState = OperationalState::postShockMonitoring;
                }
                do {
                    /* Monitor heart rhythm to determine if shock was successful in restoring normal rhythm. */
                }
                transition postTherapyToMonitoring
                    first PostShockMonitoring
                    if rhythmDataIn.rhythmClassification.rhythmType == RhythmType::normal
                    then Monitoring;
                transition postTherapyToAlert
                    first PostShockMonitoring
                    if rhythmDataIn.rhythmClassification.rhythmType == RhythmType::ventricularTachycardia
                       or rhythmDataIn.rhythmClassification.rhythmType == RhythmType::ventricularFibrillation
                    then PatientAlert;
            }
        }
    }

    part def Garment {
        attribute material : String = "breathable fabric";
        attribute size : String;
        attribute maxWeight : Mass = 500 [g];

        part ecgElectrodes : ECGElectrode[4] {
            attribute electrodeId = ("ECG1", "ECG2", "ECG3", "ECG4");
        }

        part therapyElectrodes : TherapyElectrode[2] {
            attribute electrodeId = ("TherapyAnterior", "TherapyPosterior");
        }
    }

    part def WCDSystem {
        attribute deviceId : String;
        attribute patientId : String;
        attribute isOperational : Boolean = true;

        part garment : Garment;
        part controlUnit : CentralControlUnit;
        part rhythmProcessor : RhythmAnalysisProcessor;
        part alertModule : PatientAlertModule;
        part capacitor : HighVoltageCapacitor;
        part battery : BatteryPack;

        // ECG electrode data to control unit
        connection ecgToController connect garment.ecgElectrodes.ecgOut to controlUnit.ecgDataIn;

        // Control unit forwards ECG data to rhythm processor
        connection ecgToProcessor connect controlUnit.ecgDataOut to rhythmProcessor.ecgIn;

        // Rhythm processor sends classification to control unit
        connection rhythmToController connect rhythmProcessor.rhythmOut to controlUnit.rhythmDataIn;

        // Control unit commands alert module
        connection controllerToAlert connect controlUnit.alertControlOut to alertModule.alertIn;

        // Alert module cancel signal to control unit
        connection alertCancelToController connect alertModule.cancelOut to controlUnit.cancelIn;

        // Control unit charge command to capacitor
        connection controllerToCapacitorCharge connect controlUnit.chargeControlOut to capacitor.chargeIn;

        // Control unit shock command to capacitor
        connection controllerToCapacitorShock connect controlUnit.shockControlOut to capacitor.shockIn;

        // Capacitor status feedback to control unit
        connection capacitorStatusToController connect capacitor.statusOut to controlUnit.capacitorStatusIn;

        // Capacitor delivers energy to therapy electrodes
        connection capacitorToTherapy connect capacitor.therapyOut to garment.therapyElectrodes.therapyIn;

        // Battery power distribution
        connection batteryToController connect battery.powerOut to controlUnit.powerIn;
        connection batteryToProcessor connect battery.powerOut to rhythmProcessor.powerIn;
        connection batteryToAlert connect battery.powerOut to alertModule.powerIn;
        connection batteryToCapacitor connect battery.powerOut to capacitor.powerIn;

        // Battery status to control unit
        connection batteryStatusToController connect battery.statusOut to controlUnit.batteryStatusIn;

        // Requirements satisfaction
        requirement reqContinuousMonitoring : ContinuousMonitoringRequirement;
        requirement reqArrhythmiaDetection : ArrhythmiaDetectionRequirement;
        requirement reqPatientAlert : PatientAlertRequirement;
        requirement reqShockCancellation : ShockCancellationRequirement;
        requirement reqDefibrillationEnergy : DefibrillationEnergyRequirement;
        requirement reqBatteryLife : BatteryLifeRequirement;
        requirement reqPostShockMonitoring : PostShockMonitoringRequirement;
        requirement reqGarmentComfort : GarmentComfortRequirement;

        satisfy reqContinuousMonitoring by controlUnit;
        satisfy reqArrhythmiaDetection by rhythmProcessor;
        satisfy reqPatientAlert by alertModule;
        satisfy reqShockCancellation by controlUnit;
        satisfy reqDefibrillationEnergy by capacitor;
        satisfy reqBatteryLife by battery;
        satisfy reqPostShockMonitoring by controlUnit;
        satisfy reqGarmentComfort by garment;
    }
}

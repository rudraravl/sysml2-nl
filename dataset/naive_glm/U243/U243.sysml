package RespiratoryTherapySystem {

    // ===== Unit Definitions =====
    unit def PercentUnit { shortName "%"; }
    unit def BeatsPerMinuteUnit { shortName "bpm"; }
    unit def BreathsPerMinuteUnit { shortName "brpm"; }
    unit def CelsiusUnit { shortName "degC"; }
    unit def LitersPerMinuteUnit { shortName "L/min"; }
    unit def HourUnit { shortName "h"; }
    unit def WattUnit { shortName "W"; }
    unit def VoltUnit { shortName "V"; }

    // ===== Quantity Definitions =====
    quantity def Percent { unit : PercentUnit; }
    quantity def HeartRateQ { unit : BeatsPerMinuteUnit; }
    quantity def RespiratoryRateQ { unit : BreathsPerMinuteUnit; }
    quantity def TemperatureQ { unit : CelsiusUnit; }
    quantity def OxygenFlowQ { unit : LitersPerMinuteUnit; }
    quantity def DurationQ { unit : HourUnit; }
    quantity def PowerQ { unit : WattUnit; }
    quantity def VoltageQ { unit : VoltUnit; }

    // ===== Value Type Definitions =====
    attribute def SpO2Value :> Real { quantity : Percent; }
    attribute def HeartRateValue :> Real { quantity : HeartRateQ; }
    attribute def RespiratoryRateValue :> Real { quantity : RespiratoryRateQ; }
    attribute def TemperatureValue :> Real { quantity : TemperatureQ; }
    attribute def OxygenFlowValue :> Real { quantity : OxygenFlowQ; }
    attribute def DurationValue :> Real { quantity : DurationQ; }
    attribute def PowerValue :> Real { quantity : PowerQ; }
    attribute def VoltageValue :> Real { quantity : VoltageQ; }

    // ===== Enumeration Definitions =====
    enum def AlertSeverity { low; medium; high; critical; }
    enum def PowerSource { acPower; batteryBackup; }
    enum def ConcentratorStatus { idle; delivering; error; }

    // ===== Item Definitions =====
    item def VitalSigns {
        attribute spo2 : SpO2Value;
        attribute heartRate : HeartRateValue;
        attribute respiratoryRate : RespiratoryRateValue;
        attribute bodyTemperature : TemperatureValue;
    }

    item def OxygenTherapyCommand {
        attribute flowRate : OxygenFlowValue;
        attribute durationMinutes : Real;
    }

    item def AlertMessage {
        attribute severity : AlertSeverity;
        attribute description : String;
        attribute timestamp : String;
    }

    item def RemoteDataPacket {
        attribute patientId : String;
        attribute vitals : VitalSigns;
        attribute alert : AlertMessage;
        attribute encrypted : Boolean;
    }

    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute power : PowerValue;
        attribute source : PowerSource;
    }

    // ===== Port Definitions =====
    port def VitalSignsOutPort {
        out vitals : VitalSigns;
    }

    port def VitalSignsInPort {
        in vitals : VitalSigns;
    }

    port def TherapyCommandOutPort {
        out command : OxygenTherapyCommand;
    }

    port def TherapyCommandInPort {
        in command : OxygenTherapyCommand;
    }

    port def DisplayDataOutPort {
        out vitals : VitalSigns;
        out alert : AlertMessage;
    }

    port def DisplayDataInPort {
        in vitals : VitalSigns;
        in alert : AlertMessage;
    }

    port def RemoteDataOutPort {
        out packet : RemoteDataPacket;
    }

    port def RemoteDataInPort {
        in packet : RemoteDataPacket;
    }

    port def PowerOutPort {
        out power : ElectricalPower;
    }

    port def PowerInPort {
        in power : ElectricalPower;
    }

    // ===== Action Definitions =====
    action def MeasureVitals {
        out measuredVitals : VitalSigns;
    }

    action def AnalyzeVitals {
        in currentVitals : VitalSigns;
        out isAbnormal : Boolean;
        out severity : AlertSeverity;
    }

    action def CalculateTherapy {
        in currentVitals : VitalSigns;
        out therapyCommand : OxygenTherapyCommand;
    }

    action def DeliverOxygen {
        in command : OxygenTherapyCommand;
    }

    action def ShowVitals {
        in vitals : VitalSigns;
    }

    action def ShowAlert {
        in alert : AlertMessage;
    }

    action def EncryptData {
        in packet : RemoteDataPacket;
        out encryptedPacket : RemoteDataPacket;
    }

    action def TransmitData {
        in packet : RemoteDataPacket;
    }

    // ===== Part Definitions =====

    part def BiometricSensor {
        port vitalsOut : VitalSignsOutPort;
        port powerIn : PowerInPort;

        attribute samplingRateHz : Real := 1.0;
        attribute isWorn : Boolean := false;

        action measureVitals : MeasureVitals;

        state def SensorStateMachine {
            state inactive {
                entry action { /* sensor not worn or powered off */ }
            }
            state active {
                entry action { /* begin continuous vital signs measurement */ }
                do action { /* sample SpO2, heart rate, respiratory rate, temperature */ }
            }
            state lowBattery {
                entry action { /* reduce sampling rate and send low battery indication */ }
            }
            transition from inactive to active if (isWorn == true);
            transition from active to inactive if (isWorn == false);
            transition from active to lowBattery if (powerIn.power.source == PowerSource::batteryBackup);
            transition from lowBattery to active if (powerIn.power.source == PowerSource::acPower);
        }
    }

    part def ControlProcessor {
        port vitalsIn : VitalSignsInPort;
        port therapyCmdOut : TherapyCommandOutPort;
        port displayDataOut : DisplayDataOutPort;
        port remoteDataOut : RemoteDataOutPort;
        port powerIn : PowerInPort;

        attribute spo2LowThreshold : SpO2Value := 92.0;
        attribute spo2CriticalThreshold : SpO2Value := 88.0;
        attribute hrLowThreshold : HeartRateValue := 50.0;
        attribute hrHighThreshold : HeartRateValue := 120.0;
        attribute rrLowThreshold : RespiratoryRateValue := 8.0;
        attribute rrHighThreshold : RespiratoryRateValue := 25.0;
        attribute tempHighThreshold : TemperatureValue := 38.5;
        attribute patientId : String;

        action analyzeVitals : AnalyzeVitals;
        action calculateTherapy : CalculateTherapy;

        state def ProcessorStateMachine {
            state standby {
                entry action { /* initialize subsystems and wait for sensor data */ }
            }

            state monitoring {
                entry action { /* begin real-time vital signs analysis */ }
                do action { /* continuously evaluate thresholds and update display data */ }
            }

            state therapyActive {
                entry action { /* calculate oxygen flow rate and send therapy command */ }
                do action { /* continuously monitor while therapy is being delivered */ }
            }

            state alarm {
                entry action { /* generate critical alert, update display, and trigger remote notification */ }
                do action { /* maintain alarm state until condition stabilizes */ }
            }

            state fault {
                entry action { /* log fault, attempt recovery, and notify user */ }
            }

            transition from standby to monitoring if (vitalsIn.vitals != null);
            transition from monitoring to therapyActive if (vitalsIn.vitals.spo2 < spo2LowThreshold);
            transition from monitoring to alarm if (vitalsIn.vitals.heartRate < hrLowThreshold or vitalsIn.vitals.heartRate > hrHighThreshold);
            transition from monitoring to alarm if (vitalsIn.vitals.respiratoryRate < rrLowThreshold or vitalsIn.vitals.respiratoryRate > rrHighThreshold);
            transition from monitoring to alarm if (vitalsIn.vitals.bodyTemperature > tempHighThreshold);
            transition from therapyActive to alarm if (vitalsIn.vitals.spo2 < spo2CriticalThreshold);
            transition from therapyActive to monitoring if (vitalsIn.vitals.spo2 >= spo2LowThreshold);
            transition from alarm to therapyActive if (vitalsIn.vitals.spo2 >= spo2CriticalThreshold and vitalsIn.vitals.spo2 < spo2LowThreshold);
            transition from alarm to monitoring if (vitalsIn.vitals.spo2 >= spo2LowThreshold and vitalsIn.vitals.heartRate >= hrLowThreshold and vitalsIn.vitals.heartRate <= hrHighThreshold);
        }
    }

    part def OxygenConcentrator {
        port therapyCmdIn : TherapyCommandInPort;
        port powerIn : PowerInPort;

        attribute maxFlowRate : OxygenFlowValue := 5.0;
        attribute currentFlowRate : OxygenFlowValue := 0.0;
        attribute status : ConcentratorStatus := ConcentratorStatus::idle;
        attribute oxygenPurityPercent : Real := 93.0;

        action deliverOxygen : DeliverOxygen;

        state def ConcentratorStateMachine {
            state idle {
                entry action { /* no oxygen delivery, concentrator in standby */ }
            }

            state delivering {
                entry action { /* parse command and begin oxygen delivery at commanded flow rate */ }
                do action { /* maintain steady oxygen flow and monitor purity */ }
            }

            state error {
                entry action { /* log error, stop delivery, and signal fault to processor */ }
            }

            transition from idle to delivering if (therapyCmdIn.command != null);
            transition from delivering to idle if (therapyCmdIn.command == null);
            transition from delivering to error if (currentFlowRate > maxFlowRate);
            transition from error to idle if (currentFlowRate <= maxFlowRate);
        }
    }

    part def MonitoringDisplay {
        port displayDataIn : DisplayDataInPort;
        port powerIn : PowerInPort;

        attribute displayActive : Boolean := false;
        attribute backlightLevel : Real := 0.5;
        attribute currentSeverity : AlertSeverity;

        action showVitals : ShowVitals;
        action showAlert : ShowAlert;

        state def DisplayStateMachine {
            state screenOff {
                entry action { /* display powered down */ }
            }
            state normalView {
                entry action { /* show current vital signs in standard layout */ }
                do action { /* refresh vital signs display at regular intervals */ }
            }
            state alertView {
                entry action { /* highlight alert severity and show alert description */ }
                do action { /* flash alert indicator until acknowledged */ }
            }
            transition from screenOff to normalView if (displayActive == true);
            transition from normalView to screenOff if (displayActive == false);
            transition from normalView to alertView if (displayDataIn.alert != null);
            transition from alertView to normalView if (displayDataIn.alert == null);
        }
    }

    part def CommunicationHub {
        port remoteDataIn : RemoteDataInPort;
        port powerIn : PowerInPort;

        attribute encryptionEnabled : Boolean := true;
        attribute serverUrl : String;
        attribute connectionStatus : Boolean := false;
        attribute transmissionComplete : Boolean := false;

        action encryptData : EncryptData;
        action transmitData : TransmitData;

        state def HubStateMachine {
            state disconnected {
                entry action { /* attempt to establish secure connection to healthcare provider server */ }
                do action { /* retry connection at regular intervals */ }
            }
            state connected {
                entry action { /* secure connection established */ }
                do action { /* listen for incoming data packets */ }
            }
            state encrypting {
                entry action { /* encrypt patient data and alert payload */ }
            }
            state transmitting {
                entry action { /* transmit encrypted packet to healthcare provider */ }
                do action { /* wait for server acknowledgment */ }
            }
            transition from disconnected to connected if (connectionStatus == true);
            transition from connected to encrypting if (remoteDataIn.packet != null);
            transition from encrypting to transmitting if (encryptionEnabled == true);
            transition from transmitting to connected if (transmissionComplete == true);
            transition from connected to disconnected if (connectionStatus == false);
        }
    }

    part def PowerManagement {
        port powerOut : PowerOutPort;

        attribute acConnected : Boolean := true;
        attribute batteryCapacityHours : DurationValue := 8.0;
        attribute batteryRemainingHours : DurationValue := 8.0;
        attribute currentSource : PowerSource := PowerSource::acPower;
        attribute outputVoltage : VoltageValue := 12.0;
        attribute maxOutputPower : PowerValue := 150.0;
        attribute batteryCharging : Boolean := false;

        state def PowerStateMachine {
            state acMode {
                entry action { /* draw power from AC mains and charge battery if needed */ }
                do action { /* continuously charge battery and supply regulated power */ }
            }
            state batteryMode {
                entry action { /* switch to battery backup and notify processor of power source change */ }
                do action { /* monitor battery level and estimate remaining runtime */ }
            }
            state lowBattery {
                entry action { /* alert user that battery is below 20 percent */ }
                do action { /* continue supplying power at reduced output */ }
            }
            state powerOff {
                entry action { /* initiate safe shutdown of all system components */ }
            }
            transition from acMode to batteryMode if (acConnected == false);
            transition from batteryMode to acMode if (acConnected == true);
            transition from batteryMode to lowBattery if (batteryRemainingHours < 1.6);
            transition from lowBattery to acMode if (acConnected == true);
            transition from lowBattery to powerOff if (batteryRemainingHours <= 0.0);
        }
    }

    // ===== Top-Level System Part Definition =====

    part def HomeRespiratoryTherapySystem {
        part biometricSensor : BiometricSensor;
        part controlProcessor : ControlProcessor;
        part oxygenConcentrator : OxygenConcentrator;
        part monitoringDisplay : MonitoringDisplay;
        part communicationHub : CommunicationHub;
        part powerManagement : PowerManagement;

        // Data and command connections
        connection vitalsDataLink connect biometricSensor.vitalsOut to controlProcessor.vitalsIn;
        connection therapyCommandLink connect controlProcessor.therapyCmdOut to oxygenConcentrator.therapyCmdIn;
        connection displayDataLink connect controlProcessor.displayDataOut to monitoringDisplay.displayDataIn;
        connection remoteDataLink connect controlProcessor.remoteDataOut to communicationHub.remoteDataIn;

        // Power distribution connections
        connection powerToSensor connect powerManagement.powerOut to biometricSensor.powerIn;
        connection powerToProcessor connect powerManagement.powerOut to controlProcessor.powerIn;
        connection powerToConcentrator connect powerManagement.powerOut to oxygenConcentrator.powerIn;
        connection powerToDisplay connect powerManagement.powerOut to monitoringDisplay.powerIn;
        connection powerToHub connect powerManagement.powerOut to communicationHub.powerIn;

        // ===== Requirement Usages =====

        requirement vitalSignsMonitoringReq {
            doc /* The system shall continuously monitor the patient's oxygen saturation, heart rate, respiratory rate, and body temperature via a wearable biometric sensor. */
        }

        requirement realTimeAnalysisReq {
            doc /* The control processor shall analyze incoming vital signs in real time and detect abnormal readings including drops in blood oxygen levels. */
        }

        requirement automatedTherapyReq {
            doc /* The system shall automatically calculate the appropriate oxygen therapy and send a command to the oxygen concentrator when an abnormal reading is detected. */
        }

        requirement preciseOxygenDeliveryReq {
            doc /* The oxygen concentrator shall deliver a precise flow of oxygen to the patient as commanded by the control processor. */
        }

        requirement alertDisplayReq {
            doc /* The monitoring display shall show current vital signs and the severity of any alert to the patient or caregiver. */
        }

        requirement remoteCommunicationReq {
            doc /* The communication hub shall securely encrypt and transmit patient data and alerts to the healthcare provider. */
        }

        requirement batteryBackupReq {
            doc /* The power management unit shall include a battery backup capable of running the system for at least 8 hours during a power outage. */
        }

        requirement continuousOperationReq {
            doc /* The system shall function as a smart automated assistant providing continuous respiratory therapy and vigilant monitoring. */
        }

        // ===== Requirement Satisfaction =====

        satisfy vitalSignsMonitoringReq by biometricSensor;
        satisfy realTimeAnalysisReq by controlProcessor;
        satisfy automatedTherapyReq by controlProcessor;
        satisfy preciseOxygenDeliveryReq by oxygenConcentrator;
        satisfy alertDisplayReq by monitoringDisplay;
        satisfy remoteCommunicationReq by communicationHub;
        satisfy batteryBackupReq by powerManagement;
        satisfy continuousOperationReq by HomeRespiratoryTherapySystem;
    }
}

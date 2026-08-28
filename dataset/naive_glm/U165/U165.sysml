package BiophoneSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ===== Value Types =====
    value type HeartRateValue :> Real {
        :>> unit = "beats/min";
    }
    value type TemperatureValue :> Real {
        :>> unit = "degC";
    }
    value type PressureValue :> Real {
        :>> unit = "mmHg";
    }
    value type SpO2Value :> Real {
        :>> unit = "%";
    }
    value type BatteryLevel :> Real {
        :>> unit = "%";
    }
    value type SignalStrength :> Real {
        :>> unit = "dBm";
    }
    value type DataRate :> Real {
        :>> unit = "kb/s";
    }

    // ===== Item Definitions =====
    item def VitalSigns {
        attribute heartRate : HeartRateValue;
        attribute bodyTemp : TemperatureValue;
        attribute systolicBP : PressureValue;
        attribute diastolicBP : PressureValue;
        attribute spo2 : SpO2Value;
        attribute timestamp : DateTime;
    }

    item def ProcessedVitals {
        attribute heartRate : HeartRateValue;
        attribute bodyTemp : TemperatureValue;
        attribute systolicBP : PressureValue;
        attribute diastolicBP : PressureValue;
        attribute spo2 : SpO2Value;
        attribute qualityIndex : Real;
        attribute timestamp : DateTime;
    }

    item def AudioStream {
        attribute direction : String;
        attribute sampleRate : Integer;
        attribute encoding : String;
    }

    item def AlertMessage {
        attribute alertType : String;
        attribute severity : Integer;
        attribute vitalData : ProcessedVitals;
        attribute timestamp : DateTime;
    }

    item def StatusUpdate {
        attribute batteryLevel : BatteryLevel;
        attribute connectionState : String;
        attribute operationalMode : String;
    }

    item def ControlCommand {
        attribute commandType : String;
        attribute parameter : String;
    }

    // ===== Port Definitions =====
    port def VitalDataOut {
        out vitals : VitalSigns;
    }
    port def VitalDataIn {
        in vitals : VitalSigns;
    }
    port def ProcessedVitalsOut {
        out processed : ProcessedVitals;
    }
    port def ProcessedVitalsIn {
        in processed : ProcessedVitals;
    }
    port def AudioPort {
        in incomingAudio : AudioStream;
        out outgoingAudio : AudioStream;
    }
    port def WirelessDataPort {
        in downlink : ControlCommand;
        out uplinkVitals : ProcessedVitals;
        out uplinkAlert : AlertMessage;
        in incomingCallAudio : AudioStream;
        out outgoingCallAudio : AudioStream;
    }
    port def PowerPort {
        out voltage : Real;
        out batteryLevel : BatteryLevel;
        in chargeCurrent : Real;
    }
    port def ControlInterfacePort {
        out status : StatusUpdate;
        in command : ControlCommand;
        out alertNotification : AlertMessage;
        out speakerAudio : AudioStream;
        in microphoneAudio : AudioStream;
    }

    // ===== Requirements =====
    requirement def BiophoneRequirements {
        subject biophone : Biophone;

        requirement VitalSignsMonitoring {
            doc /* The Biophone shall continuously monitor heart rate, body temperature, blood pressure, and blood oxygen saturation. */
        }
        requirement WirelessTransmission {
            doc /* The Biophone shall transmit processed vital signs wirelessly to a remote monitoring station. */
        }
        requirement TwoWayAudio {
            doc /* The Biophone shall support bidirectional voice communication between patient and healthcare provider. */
        }
        requirement BatteryLife {
            doc /* The Biophone shall support at least 24 hours of continuous operation on a single charge. */
            attribute minHours : Integer = 24;
        }
        requirement AbnormalVitalAlert {
            doc /* The Biophone shall automatically enter an alerting state when abnormal vital signs are detected. */
        }
        requirement LowPowerMode {
            doc /* The Biophone shall enter a low power mode when battery level is critically low. */
        }
        requirement RealTimeProcessing {
            doc /* The signal processing unit shall filter and analyze vital signs in real time. */
        }
    }

    // ===== Part Definitions =====
    part def Biophone {
        satisfy BiophoneRequirements by biophone;

        port controlInterface : ControlInterfacePort;
        port wirelessLink : WirelessDataPort;

        part sensorArray : BiomedicalSensorArray;
        part processingUnit : SignalProcessingUnit;
        part commModule : WirelessCommunicationModule;
        part battery : RechargeableBattery;
        part userInterface : UserControlInterface;

        connection sensorToProcessor connect sensorArray.vitalOut to processingUnit.vitalIn;
        connection processorToComm connect processingUnit.vitalsOut to commModule.vitalsIn;
        connection processorToUI connect processingUnit.vitalsOut to userInterface.vitalsIn;
        connection commAudioToUI connect commModule.audioInterface to userInterface.audioPort;
        connection uiAudioToComm connect userInterface.audioPort to commModule.audioInterface;
        connection batteryPower connect battery.powerOutput to processingUnit.powerIn;
        connection batteryPower2 connect battery.powerOutput to sensorArray.powerIn;
        connection batteryPower3 connect battery.powerOutput to commModule.powerIn;
        connection batteryPower4 connect battery.powerOutput to userInterface.powerIn;
        connection uiControl connect userInterface.commandOut to processingUnit.commandIn;
        connection alertFlow connect processingUnit.alertOut to commModule.alertIn;
        connection alertToUI connect processingUnit.alertOut to userInterface.alertIn;

        exhibit state BiophoneStateMachine {
            entry action { send StatusUpdate(batteryLevel: 100, connectionState: "connected", operationalMode: "idle") to controlInterface; }

            state idle;
            state monitoring;
            state transmitting;
            state communicating;
            state alerting;
            state lowPower;

            transition init to idle
                first;

            transition idle_to_monitoring
                from idle to monitoring
                when sensorArray.vitalsAvailable
                do action { send ControlCommand(commandType: "startMonitoring", parameter: "") to processingUnit.commandIn; };

            transition monitoring_to_transmitting
                from monitoring to transmitting
                when processingUnit.vitalsReady
                do action { send ProcessedVitals to commModule.vitalsIn; };

            transition transmitting_to_monitoring
                from transmitting to monitoring
                when commModule.transmissionComplete;

            transition monitoring_to_alerting
                from monitoring to alerting
                when processingUnit.abnormalDetected
                do action {
                    send AlertMessage to commModule.alertIn;
                    send AlertMessage to userInterface.alertIn;
                };

            transition transmitting_to_alerting
                from transmitting to alerting
                when processingUnit.abnormalDetected
                do action {
                    send AlertMessage to commModule.alertIn;
                    send AlertMessage to userInterface.alertIn;
                };

            transition alerting_to_communicating
                from alerting to communicating
                when commModule.callEstablished;

            transition communicating_to_monitoring
                from communicating to monitoring
                when commModule.callTerminated;

            transition any_to_lowPower
                from monitoring to lowPower
                when battery.batteryLevel < 15
                do action { send ControlCommand(commandType: "enterLowPower", parameter: "") to processingUnit.commandIn; };

            transition lowPower_to_idle
                from lowPower to idle
                when battery.batteryLevel > 30;

            transition lowPower_to_alerting
                from lowPower to alerting
                when processingUnit.abnormalDetected
                do action {
                    send AlertMessage to commModule.alertIn;
                    send AlertMessage to userInterface.alertIn;
                };
        }
    }

    part def BiomedicalSensorArray {
        port vitalOut : VitalDataOut;
        port powerIn : PowerPort;

        attribute vitalsAvailable : Boolean;

        part heartRateSensor {
            attribute samplingRate : Integer = 250;
            action def measureHeartRate {
                out value : HeartRateValue;
            }
        }
        part temperatureSensor {
            attribute samplingRate : Integer = 1;
            action def measureTemperature {
                out value : TemperatureValue;
            }
        }
        part bloodPressureSensor {
            attribute samplingRate : Integer = 1;
            action def measureBloodPressure {
                out systolic : PressureValue;
                out diastolic : PressureValue;
            }
        }
        part spo2Sensor {
            attribute samplingRate : Integer = 100;
            action def measureSpO2 {
                out value : SpO2Value;
            }
        }

        action def gatherVitals {
            in hr : HeartRateValue;
            in temp : TemperatureValue;
            in sys : PressureValue;
            in dia : PressureValue;
            in spo2 : SpO2Value;
            out vitals : VitalSigns;
            do action {
                vitals := VitalSigns(heartRate: hr, bodyTemp: temp, systolicBP: sys, diastolicBP: dia, spo2: spo2, timestamp: now);
            }
        }

        exhibit action SensorReadout {
            perform measureHeartRate;
            perform measureTemperature;
            perform measureBloodPressure;
            perform measureSpO2;
            perform gatherVitals;
        }
    }

    part def SignalProcessingUnit {
        port vitalIn : VitalDataIn;
        port vitalsOut : ProcessedVitalsOut;
        port powerIn : PowerPort;
        port commandIn : ControlInterfacePort;
        port alertOut : ~ControlInterfacePort;

        attribute vitalsReady : Boolean;
        attribute abnormalDetected : Boolean;

        attribute heartRateThresholdLow : HeartRateValue = 40;
        attribute heartRateThresholdHigh : HeartRateValue = 180;
        attribute tempThresholdHigh : TemperatureValue = 39.0;
        attribute spo2ThresholdLow : SpO2Value = 90.0;
        attribute systolicThresholdHigh : PressureValue = 180.0;
        attribute diastolicThresholdHigh : PressureValue = 120.0;

        action def filterSignal {
            in raw : VitalSigns;
            out filtered : VitalSigns;
            do action {
                filtered := raw;
            }
        }

        action def analyzeVitals {
            in data : VitalSigns;
            out processed : ProcessedVitals;
            out abnormal : Boolean;
            do action {
                processed := ProcessedVitals(
                    heartRate: data.heartRate,
                    bodyTemp: data.bodyTemp,
                    systolicBP: data.systolicBP,
                    diastolicBP: data.diastolicBP,
                    spo2: data.spo2,
                    qualityIndex: 0.95,
                    timestamp: data.timestamp
                );
                abnormal := (data.heartRate < heartRateThresholdLow) or
                            (data.heartRate > heartRateThresholdHigh) or
                            (data.bodyTemp > tempThresholdHigh) or
                            (data.spo2 < spo2ThresholdLow) or
                            (data.systolicBP > systolicThresholdHigh) or
                            (data.diastolicBP > diastolicThresholdHigh);
            }
        }

        exhibit action ProcessingPipeline {
            perform filterSignal;
            perform analyzeVitals;
        }
    }

    part def WirelessCommunicationModule {
        port vitalsIn : ProcessedVitalsIn;
        port alertIn : ~ControlInterfacePort;
        port audioInterface : AudioPort;
        port powerIn : PowerPort;

        attribute transmissionComplete : Boolean;
        attribute callEstablished : Boolean;
        attribute callTerminated : Boolean;
        attribute carrierFrequency : Real = 2400.0;
        attribute maxDataRate : DataRate = 250.0;
        attribute signalStrength : SignalStrength;

        action def transmitVitals {
            in data : ProcessedVitals;
            do action {
                transmissionComplete := true;
            }
        }

        action def transmitAlert {
            in alert : AlertMessage;
            do action {
                send alert to wirelessLink;
            }
        }

        action def establishCall {
            in incoming : AudioStream;
            out outgoing : AudioStream;
            do action {
                callEstablished := true;
                callTerminated := false;
            }
        }

        action def terminateCall {
            do action {
                callEstablished := false;
                callTerminated := true;
            }
        }

        exhibit action CommunicationLoop {
            perform transmitVitals;
            perform transmitAlert;
            perform establishCall;
            perform terminateCall;
        }
    }

    part def RechargeableBattery {
        port powerOutput : PowerPort;

        attribute batteryLevel : BatteryLevel = 100.0;
        attribute capacity_mAh : Integer = 3000;
        attribute nominalVoltage : Real = 3.7;
        attribute chargeCycles : Integer = 0;
        attribute maxChargeCycles : Integer = 500;

        action def discharge {
            in rate : Real;
            do action {
                batteryLevel := batteryLevel - rate;
            }
        }

        action def charge {
            in current : Real;
            do action {
                batteryLevel := batteryLevel + current;
            }
        }

        exhibit action PowerManagement {
            perform discharge;
            perform charge;
        }
    }

    part def UserControlInterface {
        port vitalsIn : ProcessedVitalsIn;
        port audioPort : AudioPort;
        port powerIn : PowerPort;
        port commandOut : ControlInterfacePort;
        port alertIn : ~ControlInterfacePort;

        part display {
            attribute type : String = "OLED";
            attribute resolution : String = "128x64";
            action def showStatus {
                in status : StatusUpdate;
            }
            action def showVitals {
                in vitals : ProcessedVitals;
            }
        }

        part speaker {
            attribute maxVolume : Real = 85.0;
            action def playAudio {
                in audio : AudioStream;
            }
        }

        part microphone {
            attribute sensitivity : Real = -40.0;
            action def captureAudio {
                out audio : AudioStream;
            }
        }

        part buttons {
            attribute count : Integer = 4;
            action def handlePress {
                in buttonId : Integer;
                out command : ControlCommand;
            }
        }

        part alertIndicator {
            attribute ledColor : String = "red";
            action def triggerAlert {
                in alert : AlertMessage;
                do action {
                    send alert to commandOut;
                }
            }
        }

        exhibit action UserInterfaceLoop {
            perform showStatus;
            perform showVitals;
            perform playAudio;
            perform captureAudio;
            perform handlePress;
            perform triggerAlert;
        }
    }

    // ===== Remote Monitoring Station (external context) =====
    part def RemoteMonitoringStation {
        port biophoneLink : WirelessDataPort;

        attribute stationId : String;
        attribute location : String;

        action def receiveVitals {
            in data : ProcessedVitals;
        }

        action def receiveAlert {
            in alert : AlertMessage;
            do action {
                // initiate medical response
            }
        }

        action def initiateCall {
            out audio : AudioStream;
        }

        exhibit action MonitoringLoop {
            perform receiveVitals;
            perform receiveAlert;
            perform initiateCall;
        }
    }

    // ===== System Context =====
    part def BiophoneSystemContext {
        part theBiophone : Biophone;
        part theStation : RemoteMonitoringStation;

        connection wirelessConnection connect theBiophone.wirelessLink to theStation.biophoneLink;
    }
}

package SM4All {
    private import ISQ::DurationValue;
    private import SI::s;
    private import SI::h;
    private import ScalarValues::Boolean;
    private import ScalarValues::String;
    private import ScalarValues::Real;
    private import Time::TimeInstantValue;

    package Definitions {
        attribute def Temperature :> Real;
        attribute def Humidity :> Real;
        attribute def LightLevel :> Real;
        attribute def HeartRate :> Real;
        attribute def ActivityLevel :> Real;

        enum def HVACMode { cool; heat; off; }

        item def SensorData {
            attribute temperature : Temperature;
            attribute humidity : Humidity;
            attribute lightLevel : LightLevel;
            attribute motion : Boolean;
        }

        item def VitalSigns {
            attribute heartRate : HeartRate;
            attribute activityLevel : ActivityLevel;
            attribute fallDetected : Boolean;
        }

        item def AlertNotification {
            attribute location : String;
            attribute eventType : String;
            attribute timestamp : TimeInstantValue;
        }

        item def HVACCommand {
            attribute targetTemperature : Temperature;
            attribute mode : HVACMode;
        }

        item def LightingCommand {
            attribute brightness : Real;
            attribute on : Boolean;
        }

        item def BlindsCommand {
            attribute openPosition : Real;
        }

        port def SensorDataPort {
            out data : SensorData;
        }

        port def WearableDataPort {
            out data : VitalSigns;
        }

        port def CommandPort {
            in hvacCmd : HVACCommand;
            in lightingCmd : LightingCommand;
            in blindsCmd : BlindsCommand;
        }

        port def AlertPort {
            out alert : AlertNotification;
        }

        part def EnvironmentalSensor {
            port dataPort : SensorDataPort;
        }

        part def WearableDevice {
            port dataPort : WearableDataPort;
        }

        action learnPatterns;
        action monitorAndAnalyze { out fallDetected : Boolean; out anomalyDetected : Boolean; }
        action evaluateAnomaly { out critical : Boolean; }
        action adjustClimate;
        action adjustLighting;

        part def ContextProcessor {
            port sensorIn : ~SensorDataPort;
            port wearableIn : ~WearableDataPort;
            port cmdOut : ~CommandPort;
            port alertOut : AlertPort;
        }

        state processorBehavior {
            in processor : ContextProcessor;
            entry; then learning;

            state learning;
            do learnPatterns;
            accept after 720 [h]
                then normal;

            state normal;
            do monitorAndAnalyze;
            accept when monitorAndAnalyze.fallDetected
                then emergency;
            accept when monitorAndAnalyze.anomalyDetected
                then anomaly;
            accept after 600 [s]
                then comfortAdjust;

            state comfortAdjust;
            do adjustClimate;
            do adjustLighting;
            accept after 300 [s]
                then normal;

            state anomaly;
            do evaluateAnomaly;
            accept when evaluateAnomaly.critical
                then emergency;
            accept when not evaluateAnomaly.critical
                then normal;

            state emergency {
                entry send new AlertNotification() to processor;
            }
            accept after 30 [s]
                then normal;
        }

        part def CommunicationGateway {
            port alertIn : ~AlertPort;
            port alertOut : AlertPort;
        }

        part def SmartActuator {
            port cmdIn : CommandPort;
        }

        part def HVACSystem :> SmartActuator;
        part def LightingSystem :> SmartActuator;
        part def WindowBlindsSystem :> SmartActuator;

        part def Resident;

        part def Caregiver {
            port alertIn : ~AlertPort;
        }

        metadata def Encrypted;
        metadata def LocalProcessing;
    }

    package Requirements {
        private import Definitions::*;

        requirement def EmergencyResponseRequirement {
            doc "The system must send an alert notification to a caregiver within 30 seconds of detecting a critical event.";
            attribute responseTime : DurationValue;
            require responseTime <= 30 [s];
        }

        requirement def PrivacyRequirement {
            doc "All sensitive data shall be processed locally and communications encrypted.";
        }

        requirement def ContinuousMonitoringRequirement {
            doc "The system shall continuously monitor environmental conditions and resident vital signs.";
        }
    }

    package Usages {
        private import Definitions::*;
        private import Requirements::*;

        part sm4AllSystem {
            part resident : Resident;

            part tempSensor : EnvironmentalSensor;
            part humiditySensor : EnvironmentalSensor;
            part lightSensor : EnvironmentalSensor;
            part motionSensor1 : EnvironmentalSensor;
            part motionSensor2 : EnvironmentalSensor;

            part wearable : WearableDevice;

            part processor : ContextProcessor {
                metadata LocalProcessing;
            }

            part gateway : CommunicationGateway {
                metadata Encrypted;
            }

            part hvac : HVACSystem;
            part lighting : LightingSystem;
            part blinds : WindowBlindsSystem;

            part caregiver : Caregiver;

            connect tempSensor.dataPort to processor.sensorIn;
            connect humiditySensor.dataPort to processor.sensorIn;
            connect lightSensor.dataPort to processor.sensorIn;
            connect motionSensor1.dataPort to processor.sensorIn;
            connect motionSensor2.dataPort to processor.sensorIn;
            connect wearable.dataPort to processor.wearableIn;
            connect processor.cmdOut to hvac.cmdIn;
            connect processor.cmdOut to lighting.cmdIn;
            connect processor.cmdOut to blinds.cmdIn;
            connect processor.alertOut to gateway.alertIn;
            connect gateway.alertOut to caregiver.alertIn;

            satisfy EmergencyResponseRequirement by gateway;
            satisfy PrivacyRequirement by processor;
            satisfy ContinuousMonitoringRequirement by tempSensor, humiditySensor, lightSensor, motionSensor1, motionSensor2, wearable;
        }
    }
}

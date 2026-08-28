package WatsonCapsuleModel {
    import ScalarValues::*;
    import SI::*;

    // ---- Value types with units ----
    value type pHValue :> Real {
        attribute unit : String = "pH";
    }
    value type TemperatureValue :> Real {
        attribute unit : String = "degC";
    }
    value type ConcentrationValue :> Real {
        attribute unit : String = "mg/dL";
    }
    value type PercentValue :> Real {
        attribute unit : String = "%";
    }
    value type ChargeValue :> Real {
        attribute unit : String = "mAh";
    }
    value type DurationHours :> Real {
        attribute unit : String = "h";
    }
    value type FrequencyHz :> Real {
        attribute unit : String = "Hz";
    }

    // ---- Item definitions ----
    item def Biomarker {
        attribute name : String;
        attribute concentration : ConcentrationValue;
    }

    item def SensorData {
        attribute pH : pHValue;
        attribute temperature : TemperatureValue;
        attribute biomarkers : Biomarker[0..*];
        attribute timestamp : Time;
        attribute sampleId : String;
    }

    item def Diagnosis {
        attribute finding : String;
        attribute confidence : PercentValue;
        attribute recommendation : String;
        attribute timestamp : Time;
        attribute diagnosisId : String;
    }

    item def ElectricalEnergy {
        attribute charge : ChargeValue;
        attribute voltage : Real;
    }

    item def TransmissionAck {
        attribute success : Boolean;
        attribute timestamp : Time;
    }

    // ---- Port definitions ----
    port def SensorDataOutPort {
        out item sensorData : SensorData;
    }

    port def SensorDataInPort {
        in item sensorData : SensorData;
    }

    port def DiagnosisOutPort {
        out item diagnosis : Diagnosis;
    }

    port def DiagnosisInPort {
        in item diagnosis : Diagnosis;
    }

    port def PowerOutPort {
        out item energy : ElectricalEnergy;
    }

    port def PowerInPort {
        in item energy : ElectricalEnergy;
    }

    port def WirelessOutPort {
        out item diagnosis : Diagnosis;
        in item ack : TransmissionAck;
    }

    // ---- Requirements ----
    requirement def BiocompatibilityRequirement {
        doc "The capsule shall be constructed from a biocompatible medical-grade polymer safe for human ingestion."
        attribute material : String = "biocompatible medical-grade polymer";
    }

    requirement def OperatingDurationRequirement {
        doc "The capsule shall operate autonomously for 24 to 72 hours through the digestive tract."
        attribute minDuration : DurationHours = 24;
        attribute maxDuration : DurationHours = 72;
    }

    requirement def AutonomousDiagnosticRequirement {
        doc "The capsule shall autonomously sample, analyze, and report a diagnosis without external intervention."
    }

    requirement def WirelessTransmissionRequirement {
        doc "The capsule shall transmit diagnostic results via a low-energy wireless protocol."
        attribute protocol : String = "Bluetooth Low Energy";
        attribute maxRange : Real = 3.0;
    }

    requirement def AIModelRequirement {
        doc "The analytics engine shall run the Watson-AI-v3.2 model to interpret sensor data."
        attribute modelName : String = "Watson-AI-v3.2";
    }

    requirement def SamplingRequirement {
        doc "The sensor array shall measure pH, temperature, and biomarker concentrations."
        attribute samplingInterval : DurationHours = 0.25;
    }

    // ---- Parts ----
    part def SensorArray {
        port powerIn : PowerInPort;
        port dataOut : SensorDataOutPort;

        attribute samplingInterval : DurationHours = 0.25;
        attribute pHRangeMin : pHValue = 1.0;
        attribute pHRangeMax : pHValue = 9.0;
        attribute tempRangeMin : TemperatureValue = 30.0;
        attribute tempRangeMax : TemperatureValue = 42.0;

        action collectSample : SensorData {
            in energy : ElectricalEnergy;
            out data : SensorData;
        }

        action measurepH {
            out value : pHValue;
        }

        action measureTemperature {
            out value : TemperatureValue;
        }

        action measureBiomarkers {
            out biomarkers : Biomarker[0..*];
        }

        satisfy SamplingRequirement by samplingInterval;
    }

    part def AnalyticsEngine {
        port powerIn : PowerInPort;
        port dataIn : SensorDataInPort;
        port diagnosisOut : DiagnosisOutPort;

        attribute aiModel : String = "Watson-AI-v3.2";
        attribute minConfidenceThreshold : PercentValue = 60.0;

        action analyze {
            in sensorData : SensorData;
            in energy : ElectricalEnergy;
            return diagnosis : Diagnosis;
        }

        action runInference {
            in data : SensorData;
            out finding : String;
            out confidence : PercentValue;
        }

        action generateRecommendation {
            in finding : String;
            out recommendation : String;
        }

        satisfy AIModelRequirement by aiModel;
    }

    part def CommunicationModule {
        port powerIn : PowerInPort;
        port diagnosisIn : DiagnosisInPort;
        port wirelessOut : WirelessOutPort;

        attribute protocol : String = "Bluetooth Low Energy";
        attribute transmissionPower : Real = 0.01;
        attribute retryLimit : Integer = 3;

        action transmit {
            in diagnosis : Diagnosis;
            in energy : ElectricalEnergy;
            out ack : TransmissionAck;
        }

        action encodePayload {
            in diagnosis : Diagnosis;
            out payload : String;
        }

        action sendPacket {
            in payload : String;
            out ack : TransmissionAck;
        }

        satisfy WirelessTransmissionRequirement by protocol;
    }

    part def PowerManagement {
        port powerOut : PowerOutPort;

        attribute batteryCapacity : ChargeValue = 120.0;
        attribute remainingCharge : ChargeValue = 120.0;
        attribute nominalVoltage : Real = 3.0;
        attribute powerBudget : Real = 0.5;

        action distributePower {
            out energy : ElectricalEnergy;
        }

        action monitorCharge {
            out remaining : ChargeValue;
        }
    }

    // ---- Top-level capsule ----
    part def WatsonCapsule {
        attribute material : String = "biocompatible medical-grade polymer";
        attribute capsuleLength : Real = 26.0;
        attribute capsuleDiameter : Real = 11.0;
        attribute weight : Real = 4.0;

        part sensorArray : SensorArray {
            part pHSensor;
            part temperatureSensor;
            part biomarkerSensor;
        }

        part analyticsEngine : AnalyticsEngine;

        part communicationModule : CommunicationModule;

        part powerManagement : PowerManagement;

        // ---- Connections ----
        connection powerToSensor from powerManagement.powerOut to sensorArray.powerIn;
        connection powerToAnalytics from powerManagement.powerOut to analyticsEngine.powerIn;
        connection powerToComm from powerManagement.powerOut to communicationModule.powerIn;

        flow from sensorArray.dataOut to analyticsEngine.dataIn;
        flow from analyticsEngine.diagnosisOut to communicationModule.diagnosisIn;

        // ---- State machine ----
        state def CapsuleLifecycle {
            entry action initializeCapsule;
            exit action shutdownCapsule;

            state Ingested {
                entry action activateSystems;
            }

            state Sampling {
                entry action startSampling;
                do collectSample;
                exit action finalizeSample;
            }

            state Analyzing {
                entry action runAIInference;
                do analyze;
                exit action packageDiagnosis;
            }

            state Transmitting {
                entry action openConnection;
                do transmit;
                exit action closeConnection;
            }

            state LowPower {
                entry action reduceSamplingRate;
            }

            state Excreted {
                entry action finalShutdown;
            }

            transition initial to Ingested;
            transition Ingested to Sampling when sensorArray detects environment;
            transition Sampling to Analyzing when sensorArray.dataOut sends SensorData;
            transition Analyzing to Transmitting when analyticsEngine.diagnosisOut sends Diagnosis;
            transition Transmitting to Sampling 
                when communicationModule.wirelessOut receives TransmissionAck 
                and powerManagement.remainingCharge > 10.0;
            transition Transmitting to LowPower 
                when powerManagement.remainingCharge <= 10.0;
            transition LowPower to Sampling 
                when powerManagement.remainingCharge > 5.0;
            transition LowPower to Excreted 
                when capsule exits body;
            transition Transmitting to Excreted 
                when capsule exits body;
        }

        // ---- Requirements satisfaction ----
        satisfy BiocompatibilityRequirement by material;
        satisfy OperatingDurationRequirement by powerManagement.batteryCapacity;
        satisfy AutonomousDiagnosticRequirement by CapsuleLifecycle;
    }

    // ---- External system ----
    part def ExternalReceiver {
        port wirelessIn : ~WirelessOutPort;

        attribute deviceType : String = "wearable or clinical receiver";

        action receiveDiagnosis {
            in diagnosis : Diagnosis;
            out ack : TransmissionAck;
        }

        action storeRecord {
            in diagnosis : Diagnosis;
        }
    }

    part def Patient {
        part gastrointestinalTract;
        part wearableReceiver : ExternalReceiver;

        flow from WatsonCapsule.communicationModule.wirelessOut to wearableReceiver.wirelessIn;
    }
}

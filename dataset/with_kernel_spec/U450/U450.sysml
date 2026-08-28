package WatsonCapsuleSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def pHValue :> Real;
    attribute def BiomarkerConcentration :> Real;
    attribute def TemperatureValue :> ISQ::temperature;
    attribute def ConfidenceLevel :> Real;

    item def BiologicalSample {
        attribute pH : pHValue;
        attribute biomarker : BiomarkerConcentration;
        attribute temp : TemperatureValue;
    }

    item def DiagnosisResult {
        attribute diagnosis : String;
        attribute confidence : ConfidenceLevel;
        attribute recommendations : String;
    }

    item def Power {
        attribute voltage : ISQ::voltage;
        attribute current : ISQ::current;
    }

    part def SensorArray {
        port sensorOut {
            out item sample : BiologicalSample;
        }
        port powerIn {
            in item power : Power;
        }
        action def CollectSample {
            out item sample : BiologicalSample;
        }
        perform action collectSample : CollectSample;
    }

    part def AnalyticsEngine {
        port dataIn {
            in item sample : BiologicalSample;
        }
        port diagnosisOut {
            out item diagnosis : DiagnosisResult;
        }
        port powerIn {
            in item power : Power;
        }
        attribute aiModel : String = "Watson-AI-v3.2";
        action def Analyze {
            in item sample : BiologicalSample;
            out item diagnosis : DiagnosisResult;
        }
        perform action analyze : Analyze;
    }

    part def CommunicationModule {
        port dataIn {
            in item diagnosis : DiagnosisResult;
        }
        port wirelessOut {
            out item diagnosis : DiagnosisResult;
        }
        port powerIn {
            in item power : Power;
        }
        attribute protocol : String = "Bluetooth";
        action def Transmit {
            in item diagnosis : DiagnosisResult;
        }
        perform action transmit : Transmit;
    }

    part def PowerManagement {
        port powerOut {
            out item power : Power;
        }
        attribute batteryLife :> ISQ::time = 48 [h];
        action def RegulatePower {
            out item power : Power;
        }
        perform action regulatePower : RegulatePower;
    }

    part def WatsonCapsule {
        attribute shellMaterial : String = "biocompatible medical-grade polymer";
        
        part sensorArray : SensorArray;
        part analyticsEngine : AnalyticsEngine;
        part communicationModule : CommunicationModule;
        part powerManagement : PowerManagement;

        connect powerManagement.powerOut to sensorArray.powerIn;
        connect powerManagement.powerOut to analyticsEngine.powerIn;
        connect powerManagement.powerOut to communicationModule.powerIn;

        connect sensorArray.sensorOut to analyticsEngine.dataIn;
        connect analyticsEngine.diagnosisOut to communicationModule.dataIn;

        state machine def CapsuleOperation {
            state Idle;
            state Sampling {
                entry action collectSample : sensorArray.CollectSample;
            }
            state Analyzing {
                entry action analyze : analyticsEngine.Analyze;
            }
            state Transmitting {
                entry action transmit : communicationModule.Transmit;
            }
            transition initial to Idle;
            transition Idle to Sampling;
            transition Sampling to Analyzing;
            transition Analyzing to Transmitting;
            transition Transmitting to Idle;
        }
        state machine operation : CapsuleOperation;
    }

    part def MonitoringSystem {
        port wirelessIn {
            in item diagnosis : DiagnosisResult;
        }
    }

    part capsule : WatsonCapsule;
    part monitor : MonitoringSystem;

    connect capsule.communicationModule.wirelessOut to monitor.wirelessIn;

    requirement def BiocompatibilityRequirement {
        doc "The capsule shall be made of biocompatible medical-grade polymer.";
    }
    requirement def BatteryLifeRequirement {
        doc "The capsule shall operate for 24 to 72 hours.";
        attribute duration :> ISQ::time;
        constraint { duration >= 24 [h] and duration <= 72 [h] }
    }
    requirement def AIModelRequirement {
        doc "The analytics engine shall run Watson-AI-v3.2.";
    }
    requirement def CommunicationRequirement {
        doc "The capsule shall transmit data via Bluetooth.";
    }
    requirement def AutonomousWorkflowRequirement {
        doc "The capsule shall autonomously perform sampling, analysis, and data transmission.";
    }

    requirement biocompatibilityReq : BiocompatibilityRequirement;
    requirement batteryLifeReq : BatteryLifeRequirement;
    requirement aiModelReq : AIModelRequirement;
    requirement communicationReq : CommunicationRequirement;
    requirement autonomousWorkflowReq : AutonomousWorkflowRequirement;

    satisfy biocompatibilityReq by capsule.shellMaterial;
    satisfy batteryLifeReq by capsule.powerManagement.batteryLife;
    satisfy aiModelReq by capsule.analyticsEngine.aiModel;
    satisfy communicationReq by capsule.communicationModule.protocol;
    satisfy autonomousWorkflowReq by capsule.operation;
}

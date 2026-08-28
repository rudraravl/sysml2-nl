package 'Anne Chamney System' {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        private import ScalarValues::*;
        private import ISQ::*;

        attribute def HeartRateValue :> Real;
        attribute def PressureValue :> Real;
        attribute def SaturationValue :> Real;
        attribute def TemperatureValue :> Real;
        attribute def RiskScoreValue :> Real;

        item def VitalSigns {
            attribute patientId : String;
            attribute timestamp : String;
            attribute heartRate : HeartRateValue;
            attribute systolicBP : PressureValue;
            attribute diastolicBP : PressureValue;
            attribute oxygenSaturation : SaturationValue;
            attribute bodyTemperature : TemperatureValue;
        }

        item def ClinicalAlert {
            attribute patientId : String;
            attribute vitalSignOfConcern : String;
            attribute severityLevel : SeverityLevel;
            attribute timestamp : String;
            attribute riskScore : RiskScoreValue;
        }

        enumeration def SeverityLevel {
            STABLE;
            ATTENTION;
            CRITICAL;
        }

        item def InterventionCommand {
            attribute patientId : String;
            attribute commandType : CommandType;
            attribute medicationDose : Real;
            attribute timestamp : String;
        }

        enumeration def CommandType {
            ADMINISTER_MEDICATION;
            ADJUST_LIFE_SUPPORT;
            NO_INTERVENTION;
        }

        item def ArchivedRecord {
            attribute patientId : String;
            attribute timestamp : String;
            attribute vitals : VitalSigns;
            attribute alert : ClinicalAlert;
        }

        item def ValidationComplete;
        item def ExecutionComplete;

        port def VitalSignsOutPort { out vitals : VitalSigns; }
        port def VitalSignsInPort { in vitals : VitalSigns; }
        port def AlertOutPort { out alert : ClinicalAlert; }
        port def AlertInPort { in alert : ClinicalAlert; }
        port def CommandOutPort { out command : InterventionCommand; }
        port def CommandInPort { in command : InterventionCommand; }
        port def ArchiveOutPort { out record : ArchivedRecord; }
        port def ArchiveInPort { in record : ArchivedRecord; }

        action def MeasureVitalSigns { out vitals : VitalSigns; }
        action def AnalyzeVitals {
            in vitals : VitalSigns;
            out riskScore : RiskScoreValue;
            out conditionState : SeverityLevel;
        }
        action def GenerateAlert {
            in vitals : VitalSigns;
            in riskScore : RiskScoreValue;
            in conditionState : SeverityLevel;
            out alert : ClinicalAlert;
        }
        action def AssessAlert {
            in alert : ClinicalAlert;
            out command : InterventionCommand;
        }
        action def ExecuteIntervention {
            in command : InterventionCommand;
        }
        action def ArchiveData {
            in vitals : VitalSigns;
            in alert : ClinicalAlert;
            out record : ArchivedRecord;
        }
        action def ValidateCommand;
        action def ExecuteCommand;

        action validateCommand : ValidateCommand;
        action executeCommand : ExecuteCommand;

        state def InterventionStates {
            entry; then standby;
            state standby;
            accept command : InterventionCommand
                if command.commandType != CommandType::NO_INTERVENTION
                then preparing;
            state preparing {
                entry;
                do validateCommand;
            }
            accept ValidationComplete
                then executing;
            state executing {
                entry;
                do executeCommand;
            }
            accept ExecutionComplete
                then standby;
        }

        part def Patient {
            attribute patientId : String;
            attribute name : String;
            port vitalsPort { out vitals : VitalSigns; }
        }

        part def BiomedicalSensorArray {
            port vitalsInPort { in patientSignal : VitalSigns; }
            port vitalsOutPort : VitalSignsOutPort;
            perform action measure : MeasureVitalSigns { out vitals; }
        }

        part def ClinicalAnalysisProcessor {
            port vitalsInPort : VitalSignsInPort;
            port alertOutPort : AlertOutPort;
            port archiveOutPort : ArchiveOutPort;
            attribute hrThresholdHigh : HeartRateValue = 120;
            attribute hrThresholdLow : HeartRateValue = 40;
            attribute systolicBPThresholdHigh : PressureValue = 180;
            attribute systolicBPThresholdLow : PressureValue = 90;
            attribute spo2ThresholdLow : SaturationValue = 90;
            attribute tempThresholdHigh : TemperatureValue = 39.0;
            perform action analyze : AnalyzeVitals;
            perform action generateAlert : GenerateAlert;
        }

        part def ClinicalResponseTeam {
            port alertInPort : AlertInPort;
            port commandOutPort : CommandOutPort;
            port archiveQueryPort { in record : ArchivedRecord; }
            perform action assess : AssessAlert;
        }

        part def InterventionController {
            port commandInPort : CommandInPort;
            exhibit state interventionStates : InterventionStates;
        }

        part def DataArchiveSystem {
            port archiveInPort : ArchiveInPort;
            port archiveQueryOutPort { out record : ArchivedRecord; }
            perform action archive : ArchiveData;
        }

        part def AnneChamneySystem {
            attribute systemId : String = "ACS-001";
            part patient : Patient;
            part sensorArray : BiomedicalSensorArray;
            part analysisProcessor : ClinicalAnalysisProcessor;
            part responseTeam : ClinicalResponseTeam;
            part interventionController : InterventionController;
            part dataArchive : DataArchiveSystem;
        }
    }

    package Usages {
        private import Definitions::*;

        part anneChamneySystem : AnneChamneySystem {
            part :>> patient : Patient {
                attribute patientId = "P-1001";
                attribute name = "Patient 1001";
            }

            flow patientVitalsFlow of VitalSigns
                from patient.vitalsPort.vitals to sensorArray.vitalsInPort.patientSignal;

            flow vitalsFlow of VitalSigns
                from sensorArray.vitalsOutPort.vitals to analysisProcessor.vitalsInPort.vitals;

            flow alertFlow of ClinicalAlert
                from analysisProcessor.alertOutPort.alert to responseTeam.alertInPort.alert;

            flow commandFlow of InterventionCommand
                from responseTeam.commandOutPort.command to interventionController.commandInPort.command;

            flow archiveFlow of ArchivedRecord
                from analysisProcessor.archiveOutPort.record to dataArchive.archiveInPort.record;

            flow queryFlow of ArchivedRecord
                from dataArchive.archiveQueryOutPort.record to responseTeam.archiveQueryPort.record;
        }
    }

    package Requirements {
        private import Definitions::*;
        private import Usages::*;

        requirement def MonitoringRequirement {
            doc /* The system shall continuously monitor patient vital signs including heart rate, blood pressure, oxygen saturation, and body temperature. */
        }

        requirement def AlertingRequirement {
            doc /* The system shall generate a clinical alert when vitals breach safety thresholds. */
        }

        requirement def InterventionRequirement {
            doc /* The intervention controller shall execute validated treatment commands. */
        }

        requirement def ArchiveRequirement {
            doc /* The system shall archive all vital signs and alerts with timestamps. */
        }

        requirement monitoringReq : MonitoringRequirement;
        requirement alertingReq : AlertingRequirement;
        requirement interventionReq : InterventionRequirement;
        requirement archiveReq : ArchiveRequirement;

        satisfy monitoringReq by anneChamneySystem.sensorArray;
        satisfy alertingReq by anneChamneySystem.analysisProcessor;
        satisfy interventionReq by anneChamneySystem.interventionController;
        satisfy archiveReq by anneChamneySystem.dataArchive;
    }
}

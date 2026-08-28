package IntegratedMedicalDevice {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        attribute def HeartRateValue :> ScalarValues::Real;
        attribute def PressureValue :> ScalarValues::Real;
        attribute def SaturationValue :> ScalarValues::Real;
        attribute def RespiratoryRateValue :> ScalarValues::Real;
        attribute def FlowRateValue :> ScalarValues::Real;
        attribute def DosageValue :> ScalarValues::Real;
        attribute def DurationValue :> ScalarValues::Real;
        attribute def MassValue :> ScalarValues::Real;

        item def VitalSigns {
            attribute heartRate : HeartRateValue;
            attribute bloodPressure : PressureValue;
            attribute oxygenSaturation : SaturationValue;
            attribute respiratoryRate : RespiratoryRateValue;
            attribute isEncrypted : Boolean = false;
        }

        item def TherapyCommand {
            attribute drugDosage : DosageValue;
            attribute flowRate : FlowRateValue;
        }

        attribute def AlarmMessage {
            attribute severity : String;
        }

        attribute def PowerOnSignal;
        attribute def PowerOffSignal;
        attribute def TherapyNeededSignal;
        attribute def TherapyCompleteSignal;
        attribute def CriticalVitalsSignal;
        attribute def AcknowledgeSignal;

        port def VitalSignsOutPort {
            out vitalSigns : VitalSigns;
        }
        port def VitalSignsInPort {
            in vitalSigns : VitalSigns;
        }
        port def TherapyCommandOutPort {
            out therapyCommand : TherapyCommand;
        }
        port def TherapyCommandInPort {
            in therapyCommand : TherapyCommand;
        }
        port def AlarmOutPort {
            out alarm : AlarmMessage;
        }
        port def PowerOutPort {
            out powerOn : Boolean;
        }
        port def EncryptedDataOutPort {
            out encryptedData : VitalSigns;
        }
        port def ComplianceOutPort {
            out complianceVerified : Boolean;
        }

        part def VitalSignsMonitor {
            port vitalSignsOut : VitalSignsOutPort;
        }

        part def ClinicalDecisionEngine {
            port vitalSignsIn : VitalSignsInPort;
            port therapyCommandOut : TherapyCommandOutPort;
            port alarmOut : AlarmOutPort;
            exhibit state engineStates : EngineStates;
        }

        part def InfusionPump {
            port therapyCommandIn : TherapyCommandInPort;
        }

        part def PowerSupply {
            port powerOut : PowerOutPort;
            attribute batteryBackupDuration : DurationValue = 6;
        }

        part def DataSecurityModule {
            port rawDataIn : VitalSignsInPort;
            port encryptedDataOut : EncryptedDataOutPort;
        }

        part def RegulatoryComplianceMonitor {
            port complianceOut : ComplianceOutPort;
        }

        part def MedicalDevice {
            attribute totalWeight : MassValue = 5;
            part vitalMonitor : VitalSignsMonitor;
            part decisionEngine : ClinicalDecisionEngine;
            part infusionPump : InfusionPump;
            part powerSupply : PowerSupply;
            part securityModule : DataSecurityModule;
            part complianceMonitor : RegulatoryComplianceMonitor;

            exhibit state deviceStates : DeviceStates;
        }

        state def DeviceStates;
        state def EngineStates;

        action def MonitorVitals;
        action def DeliverTherapy;
        action def CheckCompliance;
        action def TriggerAlarm;
    }

    package Usages {
        private import Definitions::*;

        part medicalDevice : MedicalDevice {
            connect vitalMonitor.vitalSignsOut.vitalSigns to decisionEngine.vitalSignsIn.vitalSigns;
            connect decisionEngine.therapyCommandOut.therapyCommand to infusionPump.therapyCommandIn.therapyCommand;
            connect vitalMonitor.vitalSignsOut.vitalSigns to securityModule.rawDataIn.vitalSigns;
        }

        action monitorVitalsAction : MonitorVitals;
        action deliverTherapyAction : DeliverTherapy;
        action triggerAlarmAction : TriggerAlarm;

        state deviceStates : DeviceStates {
            entry; then standby;
            state standby;
            accept PowerOnSignal then activeMonitoring;
            state activeMonitoring {
                do monitorVitalsAction;
            }
            accept TherapyNeededSignal then therapyDelivery;
            state therapyDelivery {
                do deliverTherapyAction;
            }
            accept TherapyCompleteSignal then activeMonitoring;
            accept PowerOffSignal then standby;
        }

        state engineStates : EngineStates {
            entry; then analyzing;
            state analyzing;
            accept CriticalVitalsSignal
                do triggerAlarmAction
                then alerting;
            state alerting;
            accept AcknowledgeSignal then analyzing;
        }

        requirement def WeightRequirement {
            doc /* The device shall weigh under 5 kg. */
        }
        requirement def BatteryBackupRequirement {
            doc /* The power supply shall sustain operation for up to six hours during a power outage. */
        }
        requirement def GDPRComplianceRequirement {
            doc /* All patient data shall be encrypted to GDPR standards before transmission. */
        }
        requirement def RegulatoryComplianceRequirement {
            doc /* The device shall comply with European Medical Device Regulations (MDR) and ISO 13485 quality standards. */
        }

        satisfy WeightRequirement by medicalDevice.totalWeight;
        satisfy BatteryBackupRequirement by medicalDevice.powerSupply.batteryBackupDuration;
        satisfy GDPRComplianceRequirement by medicalDevice.securityModule;
        satisfy RegulatoryComplianceRequirement by medicalDevice.complianceMonitor;
    }
}

package BiotraumaSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value Types ----
    value type PressureValue :> Real {
        unit 'Pa';
    }
    value type HeartRateValue :> Real {
        unit 'bpm';
    }
    value type TemperatureValue :> Real {
        unit 'K';
    }
    value type VolumeValue :> Real {
        unit 'm^3';
    }
    value type FlowRateValue :> Real {
        unit 'm^3/s';
    }
    value type DurationValue :> Real {
        unit 's';
    }
    value type SeverityLevel :> Integer;
    value type DrugDoseValue :> Real {
        unit 'mg';
    }

    // ---- Item Types ----
    item def PhysiologicalSignal;
    item def VitalSigns {
        :>> heartRate : HeartRateValue;
        :>> bloodPressure : PressureValue;
        :>> bodyTemperature : TemperatureValue;
        :>> respirationRate : HeartRateValue;
    }
    item def TraumaEvent {
        :>> severity : SeverityLevel;
        :>> location : String;
        :>> timestamp : String;
    }
    item def TreatmentPlan {
        :>> drugName : String;
        :>> dose : DrugDoseValue;
        :>> interval : DurationValue;
    }
    item def AlertMessage {
        :>> priority : SeverityLevel;
        :>> description : String;
    }
    item def FluidBag {
        :>> volume : VolumeValue;
        :>> type : String;
    }

    // ---- Port Definitions ----
    port def SensorPort {
        out vitalSigns : VitalSigns;
        out signal : PhysiologicalSignal;
    }
    port def TreatmentPort {
        in treatmentPlan : TreatmentPlan;
        out administeredDose : DrugDoseValue;
    }
    port def CommunicationPort {
        in alertIn : AlertMessage;
        out alertOut : AlertMessage;
        out traumaEvent : TraumaEvent;
    }
    port def FluidPort {
        in flowCommand : FlowRateValue;
        out fluidDelivered : VolumeValue;
    }

    // ---- Requirements ----
    requirement def BiotraumaResponseRequirement {
        doc /* The system shall detect, assess, and respond to biotrauma events. */
        subject biotraumaSystem : BiotraumaSystem::BiotraumaResponseSystem;
        objective {
            doc /* Minimize patient mortality by providing rapid automated trauma response. */
        }
    }

    requirement def MonitoringRequirement {
        doc /* The system shall continuously monitor patient vital signs. */
        subject monitor : BiotraumaSystem::PatientMonitor;
        attribute samplingInterval : DurationValue = 1 [s];
        satisfy BiotraumaResponseRequirement;
    }

    requirement def TreatmentRequirement {
        doc /* The system shall administer treatment based on detected trauma severity. */
        subject treatmentUnit : BiotraumaSystem::TreatmentUnit;
        attribute maxResponseTime : DurationValue = 30 [s];
        satisfy BiotraumaResponseRequirement;
    }

    requirement def AlertRequirement {
        doc /* The system shall alert medical personnel within 5 seconds of trauma detection. */
        subject alertSystem : BiotraumaSystem::AlertCoordinator;
        attribute alertLatency : DurationValue = 5 [s];
        satisfy BiotraumaResponseRequirement;
    }

    // ---- Parts ----
    part def PatientMonitor {
        port sensorOut : SensorPort;
        port commOut : CommunicationPort;

        attribute patientId : String;
        attribute monitoringActive : Boolean = false;

        action def monitorPatient {
            in signal : PhysiologicalSignal;
            out vitals : VitalSigns;
        }

        action def detectTrauma {
            in vitals : VitalSigns;
            out event : TraumaEvent;
        }

        state def MonitorBehavior {
            entry; then Idle;
            state Idle;
            transition from Idle to Monitoring
                when sensorOut.signal->notEmpty()
                do { monitoringActive = true; };
            state Monitoring {
                entry { send sensorOut.vitalSigns; }
                do monitorPatient;
            }
            transition from Monitoring to Alerting
                when detectTrauma().event.severity > 5
                do { send commOut.alertOut; };
            state Alerting {
                entry { send commOut.traumaEvent; }
            }
            transition from Alerting to Monitoring
                when sensorOut.vitalSigns.heartRate < 120 [bpm];
        }
    }

    part def TreatmentUnit {
        port treatmentIn : TreatmentPort;
        port fluidIn : FluidPort;
        port commIn : CommunicationPort;

        attribute availableDrugs : String[0..*];
        attribute currentPlan : TreatmentPlan;

        action def administerTreatment {
            in plan : TreatmentPlan;
            out dose : DrugDoseValue;
        }

        action def regulateFluids {
            in command : FlowRateValue;
            out delivered : VolumeValue;
        }

        state def TreatmentBehavior {
            entry; then Standby;
            state Standby;
            transition from Standby to Active
                when treatmentIn.treatmentPlan->notEmpty()
                do { currentPlan = treatmentIn.treatmentPlan; };
            state Active {
                do administerTreatment;
                do regulateFluids;
            }
            transition from Active to Standby
                when currentPlan.dose <= 0 [mg];
        }
    }

    part def AlertCoordinator {
        port commIn : CommunicationPort;
        port commOut : CommunicationPort;

        attribute alertQueue : AlertMessage[0..*];
        attribute personnelNotified : Boolean = false;

        action def processAlert {
            in alert : AlertMessage;
            out forwarded : AlertMessage;
        }

        action def notifyPersonnel {
            in alert : AlertMessage;
        }

        state def AlertBehavior {
            entry; then Waiting;
            state Waiting;
            transition from Waiting to Processing
                when commIn.alertIn->notEmpty();
            state Processing {
                entry { personnelNotified = true; }
                do processAlert;
                do notifyPersonnel;
            }
            transition from Processing to Waiting
                when personnelNotified == true;
        }
    }

    part def DiagnosticController {
        port sensorIn : SensorPort;
        port treatmentOut : TreatmentPort;
        port commOut : CommunicationPort;

        attribute traumaHistory : TraumaEvent[0..*];
        attribute currentSeverity : SeverityLevel = 0;

        action def assessTrauma {
            in vitals : VitalSigns;
            out severity : SeverityLevel;
        }

        action def generatePlan {
            in severity : SeverityLevel;
            out plan : TreatmentPlan;
        }

        state def ControllerBehavior {
            entry; then Evaluating;
            state Evaluating {
                do assessTrauma;
            }
            transition from Evaluating to Planning
                when currentSeverity > 3;
            state Planning {
                do generatePlan;
                entry { send treatmentOut.treatmentPlan; }
                entry { send commOut.alertOut; }
            }
            transition from Planning to Evaluating
                when sensorIn.vitalSigns.heartRate < 100 [bpm];
        }
    }

    part def FluidReservoir {
        port fluidOut : FluidPort;
        attribute capacity : VolumeValue = 0.5 [m^3];
        attribute currentVolume : VolumeValue = 0.5 [m^3];
        attribute fluidType : String = "Saline";

        action def deliverFluid {
            in rate : FlowRateValue;
            out volume : VolumeValue;
        }
    }

    part def BiotraumaResponseSystem {
        doc /* A system that monitors, detects, and responds to biotrauma events by coordinating patient monitoring, diagnostic assessment, treatment administration, and alert notification. */

        part patientMonitor : PatientMonitor {
            :>> patientId = "PT-001";
        }
        part diagnosticController : DiagnosticController;
        part treatmentUnit : TreatmentUnit {
            :>> availableDrugs = ("Epinephrine", "Morphine", "Saline");
        }
        part alertCoordinator : AlertCoordinator;
        part fluidReservoir : FluidReservoir;

        connection patientMonitorToController connect patientMonitor.sensorOut to diagnosticController.sensorIn;
        connection controllerToTreatment connect diagnosticController.treatmentOut to treatmentUnit.treatmentIn;
        connection controllerToAlert connect diagnosticController.commOut to alertCoordinator.commIn;
        connection monitorToAlert connect patientMonitor.commOut to alertCoordinator.commIn;
        connection reservoirToTreatment connect fluidReservoir.fluidOut to treatmentUnit.fluidIn;

        satisfy BiotraumaResponseRequirement;
        satisfy MonitoringRequirement by patientMonitor;
        satisfy TreatmentRequirement by treatmentUnit;
        satisfy AlertRequirement by alertCoordinator;

        action def primaryFunction {
            doc /* High-level primary function: Detect biotrauma events from patient physiological signals, assess severity, generate and administer a treatment plan, regulate fluid delivery, and alert medical personnel. */
            in physiologicalInput : PhysiologicalSignal;
            out treatmentResponse : DrugDoseValue;
            out alertResponse : AlertMessage;

            flow :>> physiologicalInput to patientMonitor.sensorOut.signal;
            flow patientMonitor.sensorOut.vitalSigns to diagnosticController.sensorIn.vitalSigns;
            flow diagnosticController.treatmentOut.treatmentPlan to treatmentUnit.treatmentIn.treatmentPlan;
            flow diagnosticController.commOut.alertOut to alertCoordinator.commIn.alertIn;
            flow treatmentUnit.treatmentIn.administeredDose to treatmentResponse;
            flow alertCoordinator.commOut.alertOut to alertResponse;
        }
    }
}

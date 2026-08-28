package IntegratedOncologyInstrumentSystem {
    private import ScalarValues::*;

    package Definitions {
        attribute def Dose :> Real;
        attribute def DoseRate :> Real;
        attribute def Energy :> Real;
        attribute def Angle :> Real;
        attribute def VolumeFlowRate :> Real;
        attribute def HeartRate :> Real;
        attribute def Pressure :> Real;
        attribute def Length :> Real;
        attribute def Time :> Real;

        item def CTImage {
            attribute tumorLocation : Length[3];
            attribute tumorSize : Length;
            attribute scanResolution : Length;
        }

        item def TreatmentPlan {
            attribute radiationDose : Dose;
            attribute beamAngles : Angle[2];
            attribute beamEnergy : Energy;
            attribute chemoFlowRate : VolumeFlowRate;
            attribute chemoDrugName : String;
        }

        item def RadiationBeam {
            attribute doseRate : DoseRate;
            attribute energy : Energy;
        }

        item def ChemoMedication {
            attribute flowRate : VolumeFlowRate;
            attribute drugName : String;
        }

        item def VitalSigns {
            attribute heartRate : HeartRate;
            attribute systolicBP : Pressure;
            attribute diastolicBP : Pressure;
            attribute oxygenSaturation : Real;
        }

        item def DoseMeasurement {
            attribute deliveredDose : Dose;
            attribute measurementTime : Time;
        }

        attribute def StartSession;
        attribute def ScanComplete;
        attribute def PlanComplete;
        attribute def SetupComplete;
        attribute def TherapyComplete;
        attribute def VerificationComplete;
        attribute def ResetSystem;

        port def ImageOutPort { out item image : CTImage; }
        port def ImageInPort { in item image : CTImage; }
        port def PlanOutPort { out item plan : TreatmentPlan; }
        port def PlanInPort { in item plan : TreatmentPlan; }
        port def BeamOutPort { out item beam : RadiationBeam; }
        port def BeamInPort { in item beam : RadiationBeam; }
        port def MedicationOutPort { out item medication : ChemoMedication; }
        port def MedicationInPort { in item medication : ChemoMedication; }
        port def VitalsInPort { in item vitals : VitalSigns; }
        port def VitalsOutPort { out item vitals : VitalSigns; }
        port def DoseOutPort { out item dose : DoseMeasurement; }
        port def DoseInPort { in item dose : DoseMeasurement; }

        action def PerformScan { out item image : CTImage; }
        action def CreatePlan { in item image : CTImage; out item plan : TreatmentPlan; }
        action def SetupPatient;
        action def DeliverRadiation { in item plan : TreatmentPlan; out item beam : RadiationBeam; }
        action def DeliverChemo { in item plan : TreatmentPlan; out item medication : ChemoMedication; }
        action def MonitorVitals { out item vitals : VitalSigns; }
        action def MeasureDose { in item beam : RadiationBeam; out item dose : DoseMeasurement; }
        action def VerifyDose { in item plannedDose : Dose; in item measuredDose : DoseMeasurement; out item verified : Boolean; }

        state def TreatmentSessionStateMachine {
            entry; then Idle;
            state Idle;
            accept StartSession then Imaging;
            state Imaging {
                do action performScan : PerformScan;
            }
            accept ScanComplete then Planning;
            state Planning {
                do action createPlan : CreatePlan;
            }
            accept PlanComplete then PatientSetup;
            state PatientSetup {
                do action setupPatient : SetupPatient;
            }
            accept SetupComplete then TherapyDelivery;
            state TherapyDelivery parallel {
                state RadiationDelivery {
                    do action deliverRadiation : DeliverRadiation;
                }
                state ChemoDelivery {
                    do action deliverChemo : DeliverChemo;
                }
                state Monitoring {
                    do action monitorVitals : MonitorVitals;
                }
                state Dosimetry {
                    do action measureDose : MeasureDose;
                }
            }
            accept TherapyComplete then Verification;
            state Verification {
                do action verifyDose : VerifyDose;
            }
            accept VerificationComplete then SessionComplete;
            state SessionComplete;
            accept ResetSystem then Idle;
        }
    }

    package Components {
        private import Definitions::*;

        part def Patient {
            port beamIn : BeamInPort;
            port medIn : MedicationInPort;
            port vitalsOut : VitalsOutPort;
        }

        part def CTScanner {
            port imageOut : ImageOutPort;
            action performScan : PerformScan;
        }

        part def TreatmentPlanningWorkstation {
            port imageIn : ImageInPort;
            port planOut : PlanOutPort;
            action createPlan : CreatePlan;
        }

        part def LinearAccelerator {
            port planIn : PlanInPort;
            port beamOut : BeamOutPort;
            action deliverRadiation : DeliverRadiation;
        }

        part def ChemotherapyInfusionPump {
            port planIn : PlanInPort;
            port medOut : MedicationOutPort;
            action deliverChemo : DeliverChemo;
        }

        part def PatientMonitor {
            port vitalsIn : VitalsInPort;
            action monitorVitals : MonitorVitals;
        }

        part def DosimeterSystem {
            port beamIn : BeamInPort;
            port doseOut : DoseOutPort;
            action measureDose : MeasureDose;
        }
    }

    package Requirements {
        private import Definitions::*;

        requirement def TreatmentAccuracyRequirement {
            doc /* The delivered radiation dose must match the planned dose within a 5% tolerance. */
            attribute plannedDose : Dose;
            attribute deliveredDose : Dose;
            constraint { deliveredDose <= plannedDose * 1.05 and deliveredDose >= plannedDose * 0.95 }
        }

        requirement def PatientSafetyRequirement {
            doc /* Patient vital signs must be continuously monitored during treatment delivery. */
        }

        requirement def ConcurrentTherapyRequirement {
            doc /* Radiation therapy and chemotherapy must be deliverable concurrently under system control. */
        }

        requirement def RealTimeDoseVerificationRequirement {
            doc /* The dosimeter system shall provide real-time dose measurements during therapy delivery. */
        }

        requirement def IntegratedWorkflowRequirement {
            doc /* The system shall support a seamless workflow from imaging through treatment delivery to verification. */
        }

        requirement treatmentAccuracy : TreatmentAccuracyRequirement;
        requirement patientSafety : PatientSafetyRequirement;
        requirement concurrentTherapy : ConcurrentTherapyRequirement;
        requirement realTimeDoseVerification : RealTimeDoseVerificationRequirement;
        requirement integratedWorkflow : IntegratedWorkflowRequirement;
    }

    package System {
        private import Definitions::*;
        private import Components::*;
        private import Requirements::*;

        part def OncologySystem {
            part ctScanner : CTScanner;
            part planningWorkstation : TreatmentPlanningWorkstation;
            part linac : LinearAccelerator;
            part chemoPump : ChemotherapyInfusionPump;
            part patientMonitor : PatientMonitor;
            part dosimeter : DosimeterSystem;
            part patient : Patient;

            connect ctScanner.imageOut to planningWorkstation.imageIn;
            connect planningWorkstation.planOut to linac.planIn;
            connect planningWorkstation.planOut to chemoPump.planIn;
            connect linac.beamOut to patient.beamIn;
            connect chemoPump.medOut to patient.medIn;
            connect patient.vitalsOut to patientMonitor.vitalsIn;
            connect linac.beamOut to dosimeter.beamIn;

            attribute currentImage : CTImage;
            attribute currentPlan : TreatmentPlan;
            attribute currentVitals : VitalSigns;
            attribute currentDose : DoseMeasurement;
            attribute doseVerified : Boolean;

            exhibit state sessionStateMachine : TreatmentSessionStateMachine;

            satisfy treatmentAccuracy;
            satisfy patientSafety;
            satisfy concurrentTherapy;
            satisfy realTimeDoseVerification;
            satisfy integratedWorkflow;
        }
    }
}

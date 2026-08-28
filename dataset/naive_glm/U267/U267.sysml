package OncologyTreatmentSystem {

    package ValueTypes {
        value type DoseValue :> Real { unit 'Gy'; }
        value type DoseRateValue :> Real { unit 'Gy/min'; }
        value type EnergyValue :> Real { unit 'MeV'; }
        value type AngleValue :> Real { unit 'deg'; }
        value type FlowRateValue :> Real { unit 'mL/h'; }
        value type VolumeValue :> Real { unit 'mL'; }
        value type HeartRateValue :> Real { unit 'bpm'; }
        value type PressureValue :> Real { unit 'mmHg'; }
        value type SaturationValue :> Real { unit '%'; }
        value type DistanceValue :> Real { unit 'mm'; }
        value type DurationValue :> Real { unit 'min'; }
        value type ResolutionValue :> Real { unit 'mm'; }
    }

    package Items {
        item def CTImage {
            attribute resolution : ResolutionValue;
            attribute sliceCount : Integer;
            attribute tumorLocation : DistanceValue[3];
            attribute tumorVolume : VolumeValue;
        }

        item def TreatmentPlan {
            attribute targetDose : DoseValue;
            attribute beamAngles : AngleValue[*];
            attribute beamEnergy : EnergyValue;
            attribute fractionCount : Integer;
            attribute chemoVolume : VolumeValue;
            attribute chemoFlowRate : FlowRateValue;
        }

        item def VitalSigns {
            attribute heartRate : HeartRateValue;
            attribute bloodPressureSystolic : PressureValue;
            attribute bloodPressureDiastolic : PressureValue;
            attribute oxygenSaturation : SaturationValue;
        }

        item def DoseMeasurement {
            attribute deliveredDose : DoseValue;
            attribute measuredDoseRate : DoseRateValue;
            attribute timestamp : DurationValue;
        }

        item def PlanVerification {
            attribute plannedDose : DoseValue;
            attribute deliveredDose : DoseValue;
            attribute deviation : DoseValue;
            attribute verified : Boolean;
        }

        item def ControlCommand {
            attribute commandKind : String;
            attribute parameter : Real;
        }

        item def PatientData {
            attribute patientId : String;
            attribute sessionDate : String;
        }
    }

    package Ports {
        port def ImagePort {
            out image : CTImage;
        }

        port def PlanPort {
            in planRequest : CTImage;
            out plan : TreatmentPlan;
        }

        port def BeamControlPort {
            in command : ControlCommand;
            out status : String;
        }

        port def PumpControlPort {
            in command : ControlCommand;
            out status : String;
        }

        port def VitalSignsPort {
            out vitals : VitalSigns;
        }

        port def DoseFeedbackPort {
            out measurement : DoseMeasurement;
        }

        port def VerificationPort {
            in plan : TreatmentPlan;
            in measurement : DoseMeasurement;
            out verification : PlanVerification;
        }

        port def SystemControlPort {
            in command : ControlCommand;
            out status : String;
        }
    }

    package Components {

        part def CTScanner {
            attribute scanResolution : ResolutionValue = 0.5;
            port imageOut : ImagePort;
            attribute scanDuration : DurationValue = 5.0;

            action def PerformScan {
                in patientPosition : DistanceValue[3];
                out image : CTImage;
            }

            perform performScan : PerformScan {
                out image = imageOut.image;
            }
        }

        part def TreatmentPlanningWorkstation {
            port planIn : PlanPort;
            port planOut : PlanPort;
            attribute computationTime : DurationValue = 2.0;

            action def GeneratePlan {
                in image : CTImage;
                out plan : TreatmentPlan;
            }

            perform generatePlan : GeneratePlan {
                in image = planIn.planRequest;
                out plan = planOut.plan;
            }
        }

        part def LinearAccelerator {
            attribute maxEnergy : EnergyValue = 20.0;
            attribute positionalAccuracy : DistanceValue = 0.1;
            port beamControl : BeamControlPort;
            port doseFeedback : DoseFeedbackPort;

            action def DeliverRadiation {
                in plan : TreatmentPlan;
                in duration : DurationValue;
                out measurement : DoseMeasurement;
            }

            perform deliverRadiation : DeliverRadiation {
                out measurement = doseFeedback.measurement;
            }
        }

        part def ChemotherapyInfusionPump {
            attribute maxFlowRate : FlowRateValue = 500.0;
            port pumpControl : PumpControlPort;

            action def AdministerMedication {
                in volume : VolumeValue;
                in flowRate : FlowRateValue;
            }

            perform administerMedication : AdministerMedication;
        }

        part def PatientMonitor {
            port vitalsOut : VitalSignsPort;
            attribute samplingInterval : DurationValue = 0.5;

            action def MonitorVitals {
                out vitals : VitalSigns;
            }

            perform monitorVitals : MonitorVitals {
                out vitals = vitalsOut.vitals;
            }
        }

        part def DosimeterSystem {
            attribute sensorCount : Integer = 16;
            port doseOut : DoseFeedbackPort;

            action def MeasureDose {
                out measurement : DoseMeasurement;
            }

            perform measureDose : MeasureDose {
                out measurement = doseOut.measurement;
            }
        }

        part def VerificationController {
            port verifyIn : VerificationPort;

            action def VerifyDelivery {
                in plan : TreatmentPlan;
                in measurement : DoseMeasurement;
                out verification : PlanVerification;
            }

            perform verifyDelivery : VerifyDelivery {
                in plan = verifyIn.plan;
                in measurement = verifyIn.measurement;
                out verification = verifyIn.verification;
            }
        }
    }

    package System {

        part def IntegratedOncologySystem {

            part ctScanner : Components::CTScanner;
            part planningWorkstation : Components::TreatmentPlanningWorkstation;
            part linac : Components::LinearAccelerator;
            part infusionPump : Components::ChemotherapyInfusionPump;
            part patientMonitor : Components::PatientMonitor;
            part dosimeter : Components::DosimeterSystem;
            part verificationController : Components::VerificationController;

            port systemControl : SystemControlPort;

            connection ctScanner.imageOut to planningWorkstation.planIn {
                image to planRequest;
            }

            connection planningWorkstation.planOut to linac.beamControl {
                plan to command;
            }

            connection planningWorkstation.planOut to infusionPump.pumpControl {
                plan to command;
            }

            connection linac.doseFeedback to verificationController.verifyIn {
                measurement to measurement;
            }

            connection dosimeter.doseOut to verificationController.verifyIn {
                measurement to measurement;
            }

            connection planningWorkstation.planOut to verificationController.verifyIn {
                plan to plan;
            }

            connection patientMonitor.vitalsOut to systemControl {
                vitals to status;
            }

            state machine def TreatmentSessionWorkflow {

                entry action initializeSession {
                    attribute sessionActive : Boolean = true;
                }

                state Imaging {
                    entry ctScanner.performScan;
                    transition to Planning
                        when ctScanner.imageOut.image.tumorVolume > 0;
                }

                state Planning {
                    entry planningWorkstation.generatePlan;
                    transition to PatientSetup
                        when planningWorkstation.planOut.plan.targetDose > 0;
                }

                state PatientSetup {
                    entry action alignPatient {
                        attribute patientAligned : Boolean = true;
                    }
                    transition to ConcurrentTherapy
                        when patientAligned;
                }

                state ConcurrentTherapy {
                    parallel RadiationDelivery {
                        entry linac.deliverRadiation;
                    }
                    parallel ChemotherapyDelivery {
                        entry infusionPump.administerMedication;
                    }
                    parallel Monitoring {
                        entry patientMonitor.monitorVitals;
                        entry dosimeter.measureDose;
                    }
                    transition to FinalVerification
                        when linac.doseFeedback.measurement.deliveredDose >=
                            planningWorkstation.planOut.plan.targetDose;
                }

                state FinalVerification {
                    entry verificationController.verifyDelivery;
                    transition to SessionComplete
                        when verificationController.verifyIn.verification.verified;
                }

                state SessionComplete {
                    entry action concludeSession {
                        attribute sessionActive = false;
                    }
                }

                transition SessionComplete to Imaging
                    when systemControl.command.commandKind == 'startNewSession';
            }

            perform treatmentWorkflow : TreatmentSessionWorkflow;
        }
    }

    package Requirements {

        requirement def ImagingRequirement {
            subject ctScanner : Components::CTScanner;
            attribute requiredResolution : ResolutionValue = 1.0;
            require ctScanner.scanResolution <= requiredResolution;
        }

        requirement def PlanningRequirement {
            subject workstation : Components::TreatmentPlanningWorkstation;
            require workstation.generatePlan.out.plan.targetDose > 0;
            require workstation.generatePlan.out.plan.beamAngles->size() > 0;
        }

        requirement def RadiationDeliveryRequirement {
            subject linac : Components::LinearAccelerator;
            attribute requiredAccuracy : DistanceValue = 0.5;
            require linac.positionalAccuracy <= requiredAccuracy;
            require linac.maxEnergy >= 6.0;
        }

        requirement def ChemotherapyRequirement {
            subject pump : Components::ChemotherapyInfusionPump;
            require pump.maxFlowRate >= 100.0;
        }

        requirement def MonitoringRequirement {
            subject monitor : Components::PatientMonitor;
            attribute maxSamplingInterval : DurationValue = 1.0;
            require monitor.samplingInterval <= maxSamplingInterval;
        }

        requirement def DosimetryRequirement {
            subject dosimeter : Components::DosimeterSystem;
            require dosimeter.sensorCount >= 8;
            require dosimeter.measureDose.out.measurement.deliveredDose >= 0;
        }

        requirement def VerificationRequirement {
            subject controller : Components::VerificationController;
            attribute maxDeviation : DoseValue = 0.5;
            require controller.verifyDelivery.out.verification.deviation <= maxDeviation;
        }

        requirement def WorkflowRequirement {
            subject system : System::IntegratedOncologySystem;
            require system.treatmentWorkflow.Imaging.isReached before
                system.treatmentWorkflow.Planning.isReached;
            require system.treatmentWorkflow.ConcurrentTherapy.RadiationDelivery.isActive implies
                system.treatmentWorkflow.ConcurrentTherapy.ChemotherapyDelivery.isActive;
            require system.treatmentWorkflow.SessionComplete.isReached implies
                system.treatmentWorkflow.FinalVerification.verification.verified;
        }

        requirement IntegratedSystemRequirement {
            subject oncologySystem : System::IntegratedOncologySystem;
            satisfy ImagingRequirement by oncologySystem.ctScanner;
            satisfy PlanningRequirement by oncologySystem.planningWorkstation;
            satisfy RadiationDeliveryRequirement by oncologySystem.linac;
            satisfy ChemotherapyRequirement by oncologySystem.infusionPump;
            satisfy MonitoringRequirement by oncologySystem.patientMonitor;
            satisfy DosimetryRequirement by oncologySystem.dosimeter;
            satisfy VerificationRequirement by oncologySystem.verificationController;
            satisfy WorkflowRequirement by oncologySystem;
        }
    }
}

package 'OncologyInstrumentSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def RadiationDoseValue :> Real;
	attribute def EnergyValue :> Real;
	attribute def TemperatureValue :> Real;
	attribute def FlowRateValue :> Real;
	attribute def ConcentrationValue :> Real;

	item def ImagingData {
		attribute tumorLocation : Real[3];
		attribute tumorVolume : Real;
		attribute imageResolution : Real;
		attribute acquisitionTime : Real;
	}

	item def TreatmentPlan {
		attribute targetDose : RadiationDoseValue;
		attribute beamEnergy : EnergyValue;
		attribute fractionCount : Integer;
		attribute gantryAngles : Real[*];
		attribute sessionDuration : Real;
	}

	item def DoseReading {
		attribute measuredDose : RadiationDoseValue;
		attribute position : Real[3];
		attribute timestamp : Real;
	}

	item def ChemotherapyDrug {
		attribute drugName : String;
		attribute concentration : ConcentrationValue;
		attribute volume : Real;
	}

	item def VitalSigns {
		attribute heartRate : Real;
		attribute bloodPressure : Real[2];
		attribute oxygenSaturation : Real;
		attribute bodyTemperature : TemperatureValue;
	}

	port def ImagingDataPort {
		out imagingData : ImagingData;
	}

	port def TreatmentPlanPort {
		in treatmentPlan : TreatmentPlan;
		out planStatus : String;
	}

	port def DoseMonitorPort {
		out doseReading : DoseReading;
	}

	port def InfusionControlPort {
		in drugCommand : ChemotherapyDrug;
		out infusionRate : FlowRateValue;
	}

	port def VitalSignsPort {
		out vitalSigns : VitalSigns;
	}

	part def CTScanner {
		attribute scannerType : String;
		attribute maxResolution : Real;
		attribute scanSpeed : Real;

		port imagingOutput : ImagingDataPort;

		perform action acquireImage {
			out imageData : ImagingData;
		}
	}

	part def LinearAccelerator {
		attribute maxBeamEnergy : EnergyValue;
		attribute doseRate : RadiationDoseValue;
		attribute positionAccuracy : Real;

		port treatmentInput : TreatmentPlanPort;
		port doseOutput : DoseMonitorPort;

		perform action deliverRadiation {
			in plan : TreatmentPlan;
			out doseDelivered : DoseReading;
		}
	}

	part def ChemotherapyInfusionPump {
		attribute maxFlowRate : FlowRateValue;
		attribute volumeCapacity : Real;
		attribute accuracy : Real;

		port infusionControl : InfusionControlPort;

		perform action administerDrug {
			in drug : ChemotherapyDrug;
			out actualFlowRate : FlowRateValue;
		}
	}

	part def DosimeterSystem {
		attribute sensorCount : Integer;
		attribute measurementRange : RadiationDoseValue;
		attribute sensitivity : Real;

		port doseMonitor : DoseMonitorPort;

		perform action measureDose {
			in location : Real[3];
			out reading : DoseReading;
		}
	}

	part def PatientMonitor {
		attribute monitoringFrequency : Real;
		attribute alertThresholds : Real[*];

		port vitalsOutput : VitalSignsPort;

		perform action monitorVitals {
			out vitals : VitalSigns;
		}
	}

	part def TreatmentPlanningWorkstation {
		attribute computePower : Real;
		attribute optimizationAlgorithm : String;

		perform action createTreatmentPlan {
			in imagingData : ImagingData;
			in prescribedDose : RadiationDoseValue;
			out plan : TreatmentPlan;
		}
	}

	action def AcquireTumorImaging {
		out tumorImage : ImagingData;
	}

	action def GenerateTreatmentPlan {
		in imagingInput : ImagingData;
		in dosePrescription : RadiationDoseValue;
		out treatmentPlan : TreatmentPlan;
	}

	action def DeliverRadiationTherapy {
		in plan : TreatmentPlan;
		out dosimetryResult : DoseReading;
	}

	action def AdministerChemotherapy {
		in drug : ChemotherapyDrug;
		out infusionStatus : FlowRateValue;
	}

	action def MonitorPatient {
		out patientVitals : VitalSigns;
	}

	action def VerifyDoseDelivery {
		in plannedDose : RadiationDoseValue;
		in measuredDose : DoseReading;
		out isVerified : Boolean;
	}

	state def TreatmentSessionStateMachine {
		attribute sessionPhase : String;
		
		entry; then idle;

		state idle {
			entry assign sessionPhase := "Idle";
		}
		
		transition first idle
			accept event StartSession
			then imaging;

		state imaging {
			entry assign sessionPhase := "Acquiring Imaging";
			do action performImaging : AcquireTumorImaging;
		}
		
		transition first imaging
			accept event ImagingComplete
			then planning;

		state planning {
			entry assign sessionPhase := "Treatment Planning";
			do action performPlanning : GenerateTreatmentPlan;
		}
		
		transition first planning
			accept event PlanApproved
			then patientSetup;

		state patientSetup {
			entry assign sessionPhase := "Patient Positioning";
		}
		
		transition first patientSetup
			accept event SetupComplete
			then therapyDelivery;

		state therapyDelivery {
			entry assign sessionPhase := "Delivering Therapy";
			state radiationDelivery {
				do action deliverRadiation : DeliverRadiationTherapy;
			}
			state chemotherapyDelivery {
				do action deliverChemo : AdministerChemotherapy;
			}
			state continuousMonitoring {
				do action monitor : MonitorPatient;
			}
		}
		
		transition first therapyDelivery
			accept event TherapyComplete
			then verification;

		state verification {
			entry assign sessionPhase := "Verifying Dose";
			do action verify : VerifyDoseDelivery;
		}
		
		transition first verification
			accept event VerificationPassed
			then sessionComplete;
			
		transition first verification
			accept event VerificationFailed
			then therapyDelivery;

		state sessionComplete {
			entry assign sessionPhase := "Session Complete";
		}
		
		transition first sessionComplete
			accept event EndSession
			then idle;
	}

	part oncologyInstrumentSystem {
		doc /* 
			Integrated oncology instrument system for comprehensive cancer treatment
			combining diagnostic imaging, radiation therapy, chemotherapy delivery,
			and continuous patient monitoring capabilities.
		*/

		part ctScanner : CTScanner {
			attribute scannerType = "Helical CT";
			attribute maxResolution = 0.5;
			attribute scanSpeed = 15.0;
		}

		part linac : LinearAccelerator {
			attribute maxBeamEnergy = 18.0;
			attribute doseRate = 6.0;
			attribute positionAccuracy = 0.1;
		}

		part infusionPump : ChemotherapyInfusionPump {
			attribute maxFlowRate = 1200.0;
			attribute volumeCapacity = 500.0;
			attribute accuracy = 0.98;
		}

		part dosimeterArray : DosimeterSystem {
			attribute sensorCount = 2048;
			attribute measurementRange = 20.0;
			attribute sensitivity = 0.99;
		}

		part patientMonitor : PatientMonitor {
			attribute monitoringFrequency = 1.0;
		}

		part planningWorkstation : TreatmentPlanningWorkstation {
			attribute computePower = 128.0;
			attribute optimizationAlgorithm = "Inverse Monte Carlo";
		}

		connection imagingToPlanning connect ctScanner.imagingOutput to planningWorkstation;
		connection planningToLinac connect planningWorkstation to linac.treatmentInput;
		connection dosimetryFeedback connect dosimeterArray.doseMonitor to linac.doseOutput;
		connection vitalMonitoring connect patientMonitor.vitalsOutput to linac;

		perform action executeTreatmentWorkflow {
			first start;

			then action acquireImaging : AcquireTumorImaging {
				out tumorImage : ImagingData;
			}

			then action planTreatment : GenerateTreatmentPlan {
				in imagingInput = acquireImaging.tumorImage;
				in dosePrescription : RadiationDoseValue {
					attribute value = 2.0;
				}
				out treatmentPlan : TreatmentPlan;
			}

			then merge therapyLoop;

			then action deliverRadiation : DeliverRadiationTherapy {
				in plan = planTreatment.treatmentPlan;
				out dosimetryResult : DoseReading;
			}

			then action administerChemo : AdministerChemotherapy {
				in drug : ChemotherapyDrug {
					attribute drugName = "Cisplatin";
					attribute concentration = 1.0;
					attribute volume = 100.0;
				}
				out infusionStatus : FlowRateValue;
			}

			then action monitorPatient : MonitorPatient {
				out patientVitals : VitalSigns;
			}

			then action verifyDose : VerifyDoseDelivery {
				in plannedDose = planTreatment.treatmentPlan.targetDose;
				in measuredDose = deliverRadiation.dosimetryResult;
				out isVerified : Boolean;
			}

			then decide;
				if verifyDose.isVerified then completeSession;
				if !verifyDose.isVerified then therapyLoop;

			action completeSession;
			then done;
		}

		exhibit state treatmentSession : TreatmentSessionStateMachine;
	}

	requirement def SafetyRequirement {
		doc /* 
			Ensure patient safety during all phases of cancer treatment
			by maintaining strict tolerances and monitoring thresholds.
		*/

		subject system : oncologyInstrumentSystem;

		require constraint positioningAccuracy {
			system.linac.positionAccuracy <= 1.0
		}

		require constraint doseAccuracy {
			system.dosimeterArray.sensitivity >= 0.95
		}

		require constraint monitoringContinuity {
			system.patientMonitor.monitoringFrequency >= 0.5
		}
	}

	requirement def TreatmentEffectivenessRequirement {
		doc /* 
			Ensure effective cancer treatment through accurate dose delivery
			and optimal treatment planning.
		*/

		subject system : oncologyInstrumentSystem;

		require constraint imagingResolution {
			system.ctScanner.maxResolution <= 1.0
		}

		require constraint doseRateCapability {
			system.linac.doseRate >= 2.0
		}

		require constraint planningAccuracy {
			system.planningWorkstation.computePower >= 64.0
		}
	}

	requirement def PrimaryFunctionRequirement {
		doc /* 
			The oncology instrument system shall provide comprehensive cancer treatment
			by integrating advanced diagnostic imaging, precision radiation therapy,
			controlled chemotherapy delivery, and continuous patient monitoring to
			deliver targeted treatment to cancerous tissue while minimizing harm to
			healthy tissue and ensuring patient safety throughout the treatment process.
		*/

		subject system : oncologyInstrumentSystem;

		require safetyReq : SafetyRequirement;
		require effectivenessReq : TreatmentEffectivenessRequirement;

		require constraint workflowCompleteness {
			system.executeTreatmentWorkflow.acquireImaging.tumorImage.imageResolution <= 1.0
		}

		require constraint doseVerification {
			system.executeTreatmentWorkflow.verifyDose.isVerified == true
		}
	}
}

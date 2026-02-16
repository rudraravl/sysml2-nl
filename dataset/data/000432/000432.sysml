package 'Anne Chamney Medical Monitoring System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PatientIdentifier;
	attribute def TimestampValue;
	attribute def AlertSeverityLevel;
	
	attribute def HeartRateValue :> ISQ::FrequencyValue;
	attribute def BloodPressureValue :> ISQ::PressureValue;
	attribute def OxygenSaturationValue :> Real;
	attribute def BodyTemperatureValue :> ISQ::ThermodynamicTemperatureValue;
	
	item def VitalSignsReading {
		attribute heartRate : HeartRateValue;
		attribute systolicBP : BloodPressureValue;
		attribute diastolicBP : BloodPressureValue;
		attribute oxygenSaturation : OxygenSaturationValue;
		attribute bodyTemperature : BodyTemperatureValue;
		attribute timestamp : TimestampValue;
	}
	
	item def PatientData {
		attribute patientID : PatientIdentifier;
		attribute currentVitals : VitalSignsReading;
		attribute baselineVitals : VitalSignsReading;
	}
	
	item def ClinicalAlert {
		attribute severity : AlertSeverityLevel;
		attribute patientID : PatientIdentifier;
		attribute affectedParameter : String;
		attribute measuredValue : Real;
		attribute thresholdValue : Real;
		attribute timestamp : TimestampValue;
	}
	
	item def TreatmentCommand {
		attribute patientID : PatientIdentifier;
		attribute actionType : String;
		attribute parameters : String;
	}
	
	port def VitalSignsOutputPort {
		out item vitals : VitalSignsReading;
	}
	
	port def VitalSignsInputPort {
		in item vitals : VitalSignsReading;
	}
	
	port def AlertOutputPort {
		out item alert : ClinicalAlert;
	}
	
	port def AlertInputPort {
		in item alert : ClinicalAlert;
	}
	
	port def TreatmentCommandPort {
		in item command : TreatmentCommand;
	}
	
	part def BiomedicalSensorArray {
		port vitalsOut : VitalSignsOutputPort;
		
		action def MeasureVitalSigns {
			out heartRate : HeartRateValue;
			out systolicBP : BloodPressureValue;
			out diastolicBP : BloodPressureValue;
			out oxygenSaturation : OxygenSaturationValue;
			out bodyTemperature : BodyTemperatureValue;
		}
		
		perform action continuousMeasurement : MeasureVitalSigns[*] ordered;
	}
	
	part def ClinicalAnalysisProcessor {
		port vitalsIn : VitalSignsInputPort;
		port alertOut : AlertOutputPort;
		
		attribute heartRateThresholdLow : HeartRateValue;
		attribute heartRateThresholdHigh : HeartRateValue;
		attribute systolicBPThresholdLow : BloodPressureValue;
		attribute systolicBPThresholdHigh : BloodPressureValue;
		attribute oxygenSaturationThresholdLow : OxygenSaturationValue;
		attribute temperatureThresholdLow : BodyTemperatureValue;
		attribute temperatureThresholdHigh : BodyTemperatureValue;
		
		action def EvaluateVitalSigns {
			in reading : VitalSignsReading;
			out riskScore : Real;
			out criticalFlag : Boolean;
		}
		
		action def DetermineAlertLevel {
			in riskScore : Real;
			in criticalFlag : Boolean;
			out severity : AlertSeverityLevel;
		}
		
		action def GenerateClinicalAlert {
			in severity : AlertSeverityLevel;
			in reading : VitalSignsReading;
			out alert : ClinicalAlert;
		}
		
		action def AnalysisWorkflow {
			first start;
			then merge continuousAnalysis;
			
			action evaluate : EvaluateVitalSigns;
			
			then decide;
				if evaluate.riskScore > 0.8 then criticalPath;
				if evaluate.riskScore > 0.5 and evaluate.riskScore <= 0.8 then warningPath;
				if evaluate.riskScore <= 0.5 then normalPath;
			
			action criticalPath {
				action determineCritical : DetermineAlertLevel {
					in riskScore = evaluate.riskScore;
					in criticalFlag = true;
				}
				then action generateCritical : GenerateClinicalAlert {
					in severity = determineCritical.severity;
				}
			}
			then continuousAnalysis;
			
			action warningPath {
				action determineWarning : DetermineAlertLevel {
					in riskScore = evaluate.riskScore;
					in criticalFlag = false;
				}
				then action generateWarning : GenerateClinicalAlert {
					in severity = determineWarning.severity;
				}
			}
			then continuousAnalysis;
			
			action normalPath;
			then continuousAnalysis;
		}
	}
	
	part def InterventionController {
		port commandIn : TreatmentCommandPort;
		
		action def LogIntervention;
		action def ExecuteIntervention;
		action def ConfirmCompletion;
		action def MonitorStatus;
		action def ValidateCommand;
		action def DeliverTreatment;
		
		state controllerStates {
			entry logEntry : LogIntervention;
			do executeMain : ExecuteIntervention;
			exit confirmExit : ConfirmCompletion;
			
			state standby {
				entry monitorEntry : MonitorStatus;
			}
			
			accept commandReceived;
			transition standby_to_preparing first standby then preparing;
			
			state preparing {
				entry validateEntry : ValidateCommand;
			}
			
			accept validationComplete;
			transition preparing_to_executing first preparing then executing;
			
			state executing {
				do deliverAction : DeliverTreatment;
			}
			
			accept treatmentComplete;
			transition executing_to_standby first executing then standby;
		}
	}
	
	part def ClinicalResponseTeam {
		port alertIn : AlertInputPort;
		
		action def AssessAlert {
			in alert : ClinicalAlert;
			out urgencyLevel : Real;
			out responseRequired : Boolean;
		}
		
		action def FormulateResponse {
			in urgencyLevel : Real;
			out treatmentPlan : TreatmentCommand;
		}
		
		action def InitiateIntervention {
			in treatmentPlan : TreatmentCommand;
			out interventionStatus : String;
		}
		
		action def ResponseProtocol {
			first start;
			
			action assess : AssessAlert;
			
			then decide;
				if assess.responseRequired then respondPath;
				if not assess.responseRequired then monitorPath;
			
			action respondPath {
				action formulate : FormulateResponse {
					in urgencyLevel = assess.urgencyLevel;
				}
				then action initiate : InitiateIntervention {
					in treatmentPlan = formulate.treatmentPlan;
				}
			}
			then done;
			
			action monitorPath {
				action documentAlert;
			}
			then done;
		}
	}
	
	part def DataArchiveSystem {
		action def StoreVitalSigns {
			in reading : VitalSignsReading;
			out recordID : String;
		}
		
		action def StoreAlert {
			in alert : ClinicalAlert;
			out recordID : String;
		}
		
		action def RetrievePatientHistory {
			in patientID : PatientIdentifier;
			out historicalData : VitalSignsReading[*];
		}
	}
	
	part def AnneChamneySystem {
		doc /*
		The Anne Chamney System is an advanced integrated medical monitoring and response platform
		designed to provide comprehensive, continuous patient care through intelligent surveillance
		and coordinated clinical intervention.
		
		The system's primary function is to safeguard patient health by maintaining constant vigilance
		over critical physiological parameters and orchestrating rapid, evidence-based responses to
		emerging medical conditions. It operates as a closed-loop care delivery system that bridges
		the gap between passive monitoring and active clinical intervention.
		
		The operational workflow begins with continuous acquisition of vital signs through a sophisticated
		biomedical sensor array. This array captures essential physiological data including heart rate,
		blood pressure (both systolic and diastolic), oxygen saturation levels, and core body temperature.
		These measurements are collected at high frequency to ensure no critical changes go undetected.
		
		The captured vital signs flow into a clinical analysis processor that employs advanced algorithms
		to evaluate patient status against established medical thresholds and baseline parameters. The
		processor calculates a comprehensive risk score by analyzing patterns, trends, and absolute values
		across all monitored parameters. When concerning patterns emerge, the system automatically
		categorizes the severity level and generates prioritized clinical alerts.
		
		Critical alerts immediately notify the clinical response team, who assess the situation using
		both real-time data and historical patient records retrieved from the integrated data archive.
		Based on this assessment, the team formulates appropriate treatment plans and initiates
		interventions through the intervention controller, which manages the safe execution of medical
		procedures and medication administration.
		
		Throughout this process, all vital signs, alerts, and interventions are systematically archived,
		creating a comprehensive medical record that supports both immediate clinical decisions and
		long-term care optimization. This integrated approach ensures that patients receive timely,
		appropriate care while maintaining complete documentation for quality assurance and regulatory
		compliance.
		*/
		
		part sensorArray : BiomedicalSensorArray;
		
		part analysisProcessor : ClinicalAnalysisProcessor {
			attribute heartRateThresholdLow = 60.0;
			attribute heartRateThresholdHigh = 100.0;
			attribute systolicBPThresholdLow = 90.0;
			attribute systolicBPThresholdHigh = 140.0;
			attribute oxygenSaturationThresholdLow = 95.0;
			attribute temperatureThresholdLow = 36.1;
			attribute temperatureThresholdHigh = 37.8;
		}
		
		part interventionController : InterventionController;
		part responseTeam : ClinicalResponseTeam;
		part dataArchive : DataArchiveSystem;
		
		connection vitalDataFlow connect sensorArray.vitalsOut to analysisProcessor.vitalsIn;
		connection alertNotification connect analysisProcessor.alertOut to responseTeam.alertIn;
		
		perform action operateMonitoringSystem {
			first start;
			then merge operationalLoop;
			
			action acquireVitals {
				perform sensorArray.continuousMeasurement;
			}
			
			then action analyzeData {
				perform analysisProcessor.AnalysisWorkflow;
			}
			
			then action archiveData {
				perform dataArchive.StoreVitalSigns;
			}
			
			then decide;
				if analyzeData.AnalysisWorkflow.evaluate.criticalFlag then alertResponse;
				if not analyzeData.AnalysisWorkflow.evaluate.criticalFlag then operationalLoop;
			
			action alertResponse {
				action notifyTeam {
					perform responseTeam.ResponseProtocol;
				}
				then action archiveAlert {
					perform dataArchive.StoreAlert;
				}
			}
			then operationalLoop;
		}
	}
	
	requirement def SafetyRequirement;
	requirement def PerformanceRequirement;
	requirement def ReliabilityRequirement;
	requirement def DataIntegrityRequirement;
	
	requirement <'AC-REQ-001'> continuousMonitoringRequirement : PerformanceRequirement {
		doc /*
		The Anne Chamney System shall continuously monitor patient vital signs with a minimum
		sampling frequency of 1 Hz for all physiological parameters to ensure timely detection
		of adverse events.
		*/
		
		subject system : AnneChamneySystem;
		
		require constraint {
			system.sensorArray.continuousMeasurement.heartRate != null and
			system.sensorArray.continuousMeasurement.systolicBP != null and
			system.sensorArray.continuousMeasurement.diastolicBP != null and
			system.sensorArray.continuousMeasurement.oxygenSaturation != null and
			system.sensorArray.continuousMeasurement.bodyTemperature != null
		}
	}
	
	requirement <'AC-REQ-002'> criticalAlertResponseRequirement : SafetyRequirement {
		doc /*
		The system shall generate and transmit critical alerts to the clinical response team
		within 3 seconds of detecting vital signs that exceed safety thresholds, ensuring
		immediate awareness of life-threatening conditions.
		*/
		
		subject system : AnneChamneySystem;
		
		require constraint {
			system.analysisProcessor.AnalysisWorkflow.evaluate.criticalFlag = true implies
			system.analysisProcessor.AnalysisWorkflow.criticalPath.generateCritical.alert != null
		}
	}
	
	requirement <'AC-REQ-003'> systemAvailabilityRequirement : ReliabilityRequirement {
		doc /*
		The Anne Chamney System shall maintain 99.95% uptime to ensure uninterrupted patient
		monitoring and support continuous care delivery in critical care environments.
		*/
		
		subject system : AnneChamneySystem;
	}
	
	requirement <'AC-REQ-004'> dataArchivalRequirement : DataIntegrityRequirement {
		doc /*
		The system shall archive all vital signs readings, generated alerts, and clinical
		interventions with complete timestamp information to support medical record keeping,
		audit trails, and retrospective analysis.
		*/
		
		subject system : AnneChamneySystem;
		
		require constraint {
			system.dataArchive.StoreVitalSigns != null and
			system.dataArchive.StoreAlert != null
		}
	}
	
	requirement <'AC-REQ-005'> integratedCareDeliveryRequirement {
		doc /*
		The system shall integrate monitoring, analysis, alerting, clinical response, and
		intervention control functions into a unified care delivery platform that supports
		evidence-based decision making and coordinated patient care.
		*/
		
		subject system : AnneChamneySystem;
		
		require continuousMonitoringRequirement;
		require criticalAlertResponseRequirement;
		require systemAvailabilityRequirement;
		require dataArchivalRequirement;
		
		require constraint {
			system.sensorArray != null and
			system.analysisProcessor != null and
			system.interventionController != null and
			system.responseTeam != null and
			system.dataArchive != null
		}
	}
	
	requirement <'AC-REQ-006'> accuracyRequirement : PerformanceRequirement {
		doc /*
		The clinical analysis processor shall evaluate vital signs against configured thresholds
		with 100% accuracy to prevent false negatives that could delay critical interventions.
		*/
		
		subject system : AnneChamneySystem;
		
		require constraint {
			system.analysisProcessor.heartRateThresholdLow != null and
			system.analysisProcessor.heartRateThresholdHigh != null and
			system.analysisProcessor.systolicBPThresholdLow != null and
			system.analysisProcessor.systolicBPThresholdHigh != null and
			system.analysisProcessor.oxygenSaturationThresholdLow != null and
			system.analysisProcessor.temperatureThresholdLow != null and
			system.analysisProcessor.temperatureThresholdHigh != null
		}
	}
}

package 'Cardiology Instruments System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def HeartRateValue :> Real {
		attribute unit : String = "bpm";
	}

	attribute def PressureValue :> Real {
		attribute unit : String = "mmHg";
	}

	attribute def VoltageValue :> Real {
		attribute unit : String = "mV";
	}

	attribute def OxygenSaturationValue :> Real {
		attribute unit : String = "%";
	}

	attribute def EnergyValue :> Real {
		attribute unit : String = "J";
	}

	item def ECGWaveform {
		attribute timestamp : ISQ::TimeValue;
		attribute leadData : VoltageValue[12];
		attribute samplingRate : Real = 500.0;
	}

	item def VitalSignsData {
		attribute heartRate : HeartRateValue;
		attribute systolicPressure : PressureValue;
		attribute diastolicPressure : PressureValue;
		attribute oxygenSaturation : OxygenSaturationValue;
		attribute timestamp : ISQ::TimeValue;
	}

	item def DiagnosticResult {
		attribute patientId : String;
		attribute arrhythmiaDetected : Boolean;
		attribute stSegmentElevation : Boolean;
		attribute abnormalPressure : Boolean;
		attribute lowOxygenation : Boolean;
		attribute recommendedAction : String;
	}

	item def TherapyCommand {
		attribute shockEnergy : EnergyValue;
		attribute deliveryAuthorized : Boolean;
	}

	port def SensorDataPort {
		out item sensorOutput : VitalSignsData;
	}

	port def ECGDataPort {
		out item ecgOutput : ECGWaveform;
	}

	port def TherapyPort {
		in item therapyInput : TherapyCommand;
	}

	port def DisplayDataPort {
		in item displayInput : VitalSignsData;
		in item waveformInput : ECGWaveform;
	}

	port def AnalysisDataPort {
		in item analysisInput : VitalSignsData;
		in item ecgInput : ECGWaveform;
		out item diagnosticOutput : DiagnosticResult;
	}

	part def ECGMonitor {
		port ecgDataOut : ECGDataPort;

		attribute numberOfLeads : Integer = 12;
		attribute samplingFrequency : Real = 500.0;
		attribute amplifierGain : Real = 1000.0;

		action acquireECGSignal {
			out waveform : ECGWaveform;

			first start;
			then action captureLeadData {
				out rawData : VoltageValue[12];
			}
			then action filterSignal {
				in rawData : VoltageValue[12] = captureLeadData.rawData;
				out filteredData : VoltageValue[12];
			}
			then action assembleWaveform {
				in leadData : VoltageValue[12] = filterSignal.filteredData;
				out ecgWaveform : ECGWaveform;
			}
			then assign waveform := assembleWaveform.ecgWaveform;
			then done;
		}
	}

	part def VitalSignsMonitor {
		port vitalsOut : SensorDataPort;

		attribute measurementInterval : ISQ::TimeValue;

		action measureVitalSigns {
			out vitals : VitalSignsData;

			first start;
			then action measureHeartRate {
				out hr : HeartRateValue;
			}
			then action measureBloodPressure {
				out systolic : PressureValue;
				out diastolic : PressureValue;
			}
			then action measureOxygenSaturation {
				out spo2 : OxygenSaturationValue;
			}
			then action compileVitals {
				in heartRate : HeartRateValue = measureHeartRate.hr;
				in systolic : PressureValue = measureBloodPressure.systolic;
				in diastolic : PressureValue = measureBloodPressure.diastolic;
				in oxygenSat : OxygenSaturationValue = measureOxygenSaturation.spo2;
				out vitalSigns : VitalSignsData;
			}
			then assign vitals := compileVitals.vitalSigns;
			then done;
		}
	}

	part def DiagnosticProcessor {
		port analysisPort : AnalysisDataPort;

		action analyzePatientData {
			in vitals : VitalSignsData;
			in ecgData : ECGWaveform;
			out diagnosis : DiagnosticResult;

			first start;
			then action detectArrhythmia {
				in ecg : ECGWaveform = ecgData;
				out arrhythmia : Boolean;
			}
			then action analyzeSTSegment {
				in ecg : ECGWaveform = ecgData;
				out stElevation : Boolean;
			}
			then action evaluatePressure {
				in systolic : PressureValue = vitals.systolicPressure;
				in diastolic : PressureValue = vitals.diastolicPressure;
				out abnormal : Boolean;
			}
			then action evaluateOxygenation {
				in spo2 : OxygenSaturationValue = vitals.oxygenSaturation;
				out lowOxygen : Boolean;
			}
			then action generateDiagnosticReport {
				in arrhythmiaFlag : Boolean = detectArrhythmia.arrhythmia;
				in stFlag : Boolean = analyzeSTSegment.stElevation;
				in pressureFlag : Boolean = evaluatePressure.abnormal;
				in oxygenFlag : Boolean = evaluateOxygenation.lowOxygen;
				out report : DiagnosticResult;
			}
			then assign diagnosis := generateDiagnosticReport.report;
			then done;
		}
	}

	part def Defibrillator {
		port therapyIn : TherapyPort;

		attribute maxEnergy : EnergyValue;
		attribute chargeTime : ISQ::TimeValue;

		state defibrillatorState {
			entry action initializeDevice;

			state idle {
				entry action dischargeCapacitor;
			}

			state charging {
				entry action beginCharging;
				do action monitorChargeLevel;
			}

			state ready {
				entry action signalReadyStatus;
			}

			state delivering {
				entry action deliverShock;
				do action monitorDelivery;
				exit action resetDevice;
			}

			transition idleToCharging
				first idle
				accept at chargeCommand
				then charging;

			transition chargingToReady
				first charging
				accept when capacitorFull
				then ready;

			transition readyToDelivering
				first ready
				accept at shockAuthorized
				then delivering;

			transition deliveringToIdle
				first delivering
				accept when shockComplete
				then idle;
		}

		action chargeCommand;
		action capacitorFull;
		action shockAuthorized;
		action shockComplete;
		action initializeDevice;
		action dischargeCapacitor;
		action beginCharging;
		action monitorChargeLevel;
		action signalReadyStatus;
		action deliverShock;
		action monitorDelivery;
		action resetDevice;
	}

	part def DisplayConsole {
		port displayPort : DisplayDataPort;

		attribute screenResolution : String = "1920x1080";
		attribute refreshRate : Real = 60.0;

		action displayPatientData {
			in vitals : VitalSignsData;
			in waveform : ECGWaveform;

			first start;
			then action renderVitalSigns {
				in vitalData : VitalSignsData = vitals;
			}
			then action renderECGWaveform {
				in ecgData : ECGWaveform = waveform;
			}
			then action updateDisplay;
			then done;
		}
	}

	part def AlarmModule {
		attribute alarmActive : Boolean = false;

		state alarmState {
			state silent {
				entry action deactivateAlarm;
			}

			state alerting {
				entry action activateAlarm;
				do action soundAlarm;
			}

			state critical {
				entry action activateCriticalAlarm;
				do action soundCriticalAlarm;
			}

			transition silentToAlerting
				first silent
				accept at abnormalCondition
				then alerting;

			transition alertingToCritical
				first alerting
				accept at criticalCondition
				then critical;

			transition alertingToSilent
				first alerting
				accept at conditionResolved
				then silent;

			transition criticalToSilent
				first critical
				accept at emergencyResolved
				then silent;
		}

		action abnormalCondition;
		action criticalCondition;
		action conditionResolved;
		action emergencyResolved;
		action deactivateAlarm;
		action activateAlarm;
		action soundAlarm;
		action activateCriticalAlarm;
		action soundCriticalAlarm;
	}

	part def CardiologyInstrumentSystem {
		part ecgMonitor : ECGMonitor;
		part vitalsMonitor : VitalSignsMonitor;
		part diagnosticProcessor : DiagnosticProcessor;
		part defibrillator : Defibrillator;
		part displayConsole : DisplayConsole;
		part alarmModule : AlarmModule;

		connection ecgToProcessor connect ecgMonitor.ecgDataOut to diagnosticProcessor.analysisPort;
		connection vitalsToProcessor connect vitalsMonitor.vitalsOut to diagnosticProcessor.analysisPort;
		connection vitalsToDisplay connect vitalsMonitor.vitalsOut to displayConsole.displayPort;
		connection ecgToDisplay connect ecgMonitor.ecgDataOut to displayConsole.displayPort;
		connection processorToDefibrillator connect diagnosticProcessor.analysisPort to defibrillator.therapyIn;

		perform action performCardiacMonitoring {
			first start;
			then merge continuousMonitoring;
			then action acquireECG references ecgMonitor.acquireECGSignal;
			then action acquireVitals references vitalsMonitor.measureVitalSigns;
			then action analyzeData : diagnosticProcessor.analyzePatientData {
				in vitals = acquireVitals.vitals;
				in ecgData = acquireECG.waveform;
				out diagnosis;
			}
			then action updateDisplay : displayConsole.displayPatientData {
				in vitals = acquireVitals.vitals;
				in waveform = acquireECG.waveform;
			}
			then decide;
				if analyzeData.diagnosis.arrhythmiaDetected then triggerAlarm;
				if analyzeData.diagnosis.stSegmentElevation then triggerCriticalAlarm;
				else continuousMonitoring;
			action triggerAlarm references alarmModule.activateAlarm;
			then continuousMonitoring;
			action triggerCriticalAlarm references alarmModule.activateCriticalAlarm;
			then evaluateTherapy;
			action evaluateTherapy {
				in diagnosisInput : DiagnosticResult = analyzeData.diagnosis;
				out shouldDefibrillate : Boolean;
			}
			then decide;
				if evaluateTherapy.shouldDefibrillate then initiateDefibrillation;
				else continuousMonitoring;
			action initiateDefibrillation references defibrillator.chargeCommand;
			then continuousMonitoring;
		}
	}

	requirement def ContinuousMonitoringRequirement {
		doc /* The system shall continuously monitor patient cardiac activity and vital signs in real-time. */
		subject system : CardiologyInstrumentSystem;

		requirement ecgMonitoring {
			doc /* ECG signals shall be acquired at a minimum sampling rate of 500 Hz across 12 leads. */
		}

		requirement vitalSignsMonitoring {
			doc /* Vital signs including heart rate, blood pressure, and oxygen saturation shall be measured at regular intervals. */
		}
	}

	requirement def DiagnosticCapabilityRequirement {
		doc /* The system shall analyze acquired data to detect cardiac abnormalities and provide diagnostic information. */
		subject system : CardiologyInstrumentSystem;

		requirement arrhythmiaDetection {
			doc /* The system shall detect cardiac arrhythmias from ECG waveform analysis. */
		}

		requirement ischemiaDetection {
			doc /* The system shall detect ST-segment elevation indicative of myocardial ischemia. */
		}

		requirement abnormalVitalsDetection {
			doc /* The system shall identify abnormal blood pressure and oxygen saturation levels. */
		}
	}

	requirement def TherapeuticInterventionRequirement {
		doc /* The system shall provide therapeutic intervention capabilities for life-threatening cardiac conditions. */
		subject system : CardiologyInstrumentSystem;

		requirement defibrillationCapability {
			doc /* The system shall deliver controlled electrical shocks for defibrillation when authorized. */
		}

		requirement energyControl {
			doc /* Defibrillation energy shall be controllable and delivered safely to the patient. */
		}
	}

	requirement def AlertingRequirement {
		doc /* The system shall alert medical personnel of abnormal and critical cardiac conditions. */
		subject system : CardiologyInstrumentSystem;

		requirement abnormalAlerts {
			doc /* The system shall activate audible and visual alarms for detected abnormalities. */
		}

		requirement criticalAlerts {
			doc /* The system shall escalate alarms for life-threatening conditions requiring immediate intervention. */
		}
	}

	requirement def DisplayRequirement {
		doc /* The system shall display real-time patient data in a clear and accessible format. */
		subject system : CardiologyInstrumentSystem;

		requirement waveformDisplay {
			doc /* ECG waveforms shall be displayed continuously with appropriate scaling and resolution. */
		}

		requirement vitalsDisplay {
			doc /* Vital signs shall be displayed numerically with trend information. */
		}
	}

	requirement systemPrimaryFunction {
		doc /*
		The Cardiology Instrument System provides comprehensive cardiac monitoring, diagnosis, and therapeutic intervention capabilities for clinical patient care. The primary function is to continuously acquire and analyze electrocardiogram signals and vital signs, detect life-threatening cardiac abnormalities such as arrhythmias and myocardial ischemia, alert medical personnel through graduated alarm systems, and deliver controlled defibrillation therapy when necessary. The system integrates multiple specialized instruments including ECG monitors, vital signs monitors, diagnostic processors, defibrillators, display consoles, and alarm modules to enable real-time assessment and treatment of cardiac patients in critical care environments.
		*/
		
		subject system : CardiologyInstrumentSystem;
		
		require continuousMonitoring : ContinuousMonitoringRequirement;
		require diagnosticCapability : DiagnosticCapabilityRequirement;
		require therapeuticIntervention : TherapeuticInterventionRequirement;
		require alerting : AlertingRequirement;
		require display : DisplayRequirement;
	}

	part cardiologySystem : CardiologyInstrumentSystem {
		satisfy systemPrimaryFunction;
	}
}

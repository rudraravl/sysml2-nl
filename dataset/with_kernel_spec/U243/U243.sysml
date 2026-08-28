package 'Home Respiratory Therapy System' {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def OxygenSaturationValue :> ScalarValues::Real;
	attribute def HeartRateValue :> ScalarValues::Integer;
	attribute def RespRateValue :> ScalarValues::Integer;
	attribute def TemperatureValue :> ScalarValues::Real;
	attribute def FlowRateValue :> ScalarValues::Real;
	attribute def BatteryDurationValue :> ScalarValues::Real;

	item def VitalSigns {
		attribute oxygenSaturation : OxygenSaturationValue;
		attribute heartRate : HeartRateValue;
		attribute respiratoryRate : RespRateValue;
		attribute bodyTemperature : TemperatureValue;
	}

	item def OxygenCommand {
		attribute flowRate : FlowRateValue;
	}

	item def Alert {
		attribute severity : String;
		attribute alertMessage : String;
	}

	item def EncryptedData {
		attribute payload : String;
	}

	item def Power;

	action def SenseVitals {
		out vitals : VitalSigns;
	}

	action def AnalyzeVitals {
		in vitals : VitalSigns;
		out oxygenCmd : OxygenCommand;
		out alert : Alert;
	}

	action def DeliverOxygen {
		in cmd : OxygenCommand;
	}

	action def DisplayInfo {
		in vitals : VitalSigns;
		in alert : Alert;
	}

	action def EncryptAndTransmit {
		in vitals : VitalSigns;
		in alert : Alert;
		out data : EncryptedData;
	}

	part def Patient {
		port oxygenInPort {
			in oxygenFlow : OxygenCommand;
		}
	}

	part def BiometricSensor {
		port sensedOutPort {
			out sensedVitals : VitalSigns;
		}
		port powerInPort {
			in power : Power;
		}
		perform action senseVitals : SenseVitals;
		exhibit state sensorStates {
			state idle;
			state active;
			transition startSensing first idle then active;
			transition stopSensing first active then idle;
		}
	}

	part def ControlProcessor {
		port vitalsInPort {
			in vitals : VitalSigns;
		}
		port oxygenCmdPort {
			out oxygenCmd : OxygenCommand;
		}
		port alertOutPort {
			out alert : Alert;
		}
		port displayVitalsPort {
			out displayVitals : VitalSigns;
		}
		port commVitalsPort {
			out commVitals : VitalSigns;
		}
		port commAlertPort {
			out commAlert : Alert;
		}
		port powerInPort {
			in power : Power;
		}
		perform action analyzeVitals : AnalyzeVitals;
		exhibit state processorStates {
			state monitoring;
			state analyzing;
			state alerting;
			transition monitorToAnalyze first monitoring then analyzing;
			transition analyzeToAlert first analyzing then alerting;
			transition analyzeToMonitor first analyzing then monitoring;
			transition alertToMonitor first alerting then monitoring;
		}
	}

	part def OxygenConcentrator {
		port oxygenCmdInPort {
			in oxygenCmd : OxygenCommand;
		}
		port oxygenOutPort {
			out oxygenDelivered : OxygenCommand;
		}
		port powerInPort {
			in power : Power;
		}
		perform action deliverOxygen : DeliverOxygen;
		exhibit state concentratorStates {
			state idle;
			state delivering;
			transition startDelivery first idle then delivering;
			transition stopDelivery first delivering then idle;
		}
	}

	part def MonitoringDisplay {
		port alertInPort {
			in alert : Alert;
		}
		port vitalsInPort {
			in vitals : VitalSigns;
		}
		port powerInPort {
			in power : Power;
		}
		perform action displayInfo : DisplayInfo;
	}

	part def CommunicationHub {
		port dataInPort {
			in vitals : VitalSigns;
			in alert : Alert;
		}
		port encryptedOutPort {
			out encryptedData : EncryptedData;
		}
		port powerInPort {
			in power : Power;
		}
		perform action encryptAndTransmit : EncryptAndTransmit;
	}

	part def HealthcareProvider {
		port encryptedInPort {
			in encryptedData : EncryptedData;
		}
	}

	part def PowerManagement {
		port acPowerPort {
			in acPower : Power;
		}
		port dcPowerOutPort {
			out dcPower : Power;
		}
		attribute batteryDuration : BatteryDurationValue = 8;
		constraint batteryBackupConstraint {
			batteryDuration >= 8
		}
		exhibit state powerStates {
			state onAC;
			state onBattery;
			transition acToBattery first onAC then onBattery;
			transition batteryToAC first onBattery then onAC;
		}
	}

	requirement def MonitorVitalSigns {
		doc /* The system shall continuously monitor the patient's vital signs including oxygen saturation, heart rate, respiratory rate, and body temperature. */
	}

	requirement def AutomatedOxygenTherapy {
		doc /* The system shall automatically calculate and deliver supplemental oxygen therapy when abnormal vital signs are detected. */
	}

	requirement def UserAlerting {
		doc /* The system shall generate and display alerts to the patient or caregiver indicating the nature and severity of abnormal vital signs. */
	}

	requirement def RemoteCommunication {
		doc /* The system shall securely encrypt and transmit patient data and alerts to the assigned healthcare provider. */
	}

	requirement def PowerBackupDuration {
		doc /* The system shall include a battery backup capable of sustaining operation for at least 8 hours during AC power loss. */
	}

	requirement monitorVitalSigns : MonitorVitalSigns;
	requirement automatedOxygenTherapy : AutomatedOxygenTherapy;
	requirement userAlerting : UserAlerting;
	requirement remoteCommunication : RemoteCommunication;
	requirement powerBackupDuration : PowerBackupDuration;

	part def HomeRespiratoryTherapySystem {
		part patient : Patient;
		part biometricSensor : BiometricSensor;
		part controlProcessor : ControlProcessor;
		part oxygenConcentrator : OxygenConcentrator;
		part monitoringDisplay : MonitoringDisplay;
		part communicationHub : CommunicationHub;
		part powerManagement : PowerManagement;
		part provider : HealthcareProvider;

		flow sensorToProcessorFlow of VitalSigns
			from biometricSensor.sensedOutPort.sensedVitals
			to controlProcessor.vitalsInPort.vitals;

		flow therapyCmdFlow of OxygenCommand
			from controlProcessor.oxygenCmdPort.oxygenCmd
			to oxygenConcentrator.oxygenCmdInPort.oxygenCmd;

		flow oxygenDeliveryFlow of OxygenCommand
			from oxygenConcentrator.oxygenOutPort.oxygenDelivered
			to patient.oxygenInPort.oxygenFlow;

		flow displayAlertFlow of Alert
			from controlProcessor.alertOutPort.alert
			to monitoringDisplay.alertInPort.alert;

		flow displayVitalsFlow of VitalSigns
			from controlProcessor.displayVitalsPort.displayVitals
			to monitoringDisplay.vitalsInPort.vitals;

		flow hubVitalsFlow of VitalSigns
			from controlProcessor.commVitalsPort.commVitals
			to communicationHub.dataInPort.vitals;

		flow hubAlertFlow of Alert
			from controlProcessor.commAlertPort.commAlert
			to communicationHub.dataInPort.alert;

		flow remoteDataFlow of EncryptedData
			from communicationHub.encryptedOutPort.encryptedData
			to provider.encryptedInPort.encryptedData;

		flow powerToSensorFlow of Power
			from powerManagement.dcPowerOutPort.dcPower
			to biometricSensor.powerInPort.power;

		flow powerToProcessorFlow of Power
			from powerManagement.dcPowerOutPort.dcPower
			to controlProcessor.powerInPort.power;

		flow powerToConcentratorFlow of Power
			from powerManagement.dcPowerOutPort.dcPower
			to oxygenConcentrator.powerInPort.power;

		flow powerToDisplayFlow of Power
			from powerManagement.dcPowerOutPort.dcPower
			to monitoringDisplay.powerInPort.power;

		flow powerToHubFlow of Power
			from powerManagement.dcPowerOutPort.dcPower
			to communicationHub.powerInPort.power;

		satisfy monitorVitalSigns by biometricSensor;
		satisfy automatedOxygenTherapy by controlProcessor;
		satisfy automatedOxygenTherapy by oxygenConcentrator;
		satisfy userAlerting by controlProcessor;
		satisfy userAlerting by monitoringDisplay;
		satisfy remoteCommunication by communicationHub;
		satisfy powerBackupDuration by powerManagement;
	}

	part respiratoryTherapySystem : HomeRespiratoryTherapySystem;
}

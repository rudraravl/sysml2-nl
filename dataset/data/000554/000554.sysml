package BodyKomSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def DeviceID;
	attribute def TransmissionStatus;
	
	item def BiometricDataPacket {
		attribute heartRate : Real;
		attribute bodyTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute bloodOxygenLevel : Real;
		attribute activityIndex : Real;
		attribute timestamp : ISQ::TimeValue;
		attribute deviceID : DeviceID;
	}
	
	item def WirelessMessage {
		attribute signalStrength : ISQ::PowerValue;
		attribute frequency : ISQ::FrequencyValue;
		attribute payload : BiometricDataPacket;
	}
	
	item def AlertMessage {
		attribute alertType : String;
		attribute severity : Real;
		attribute biometricData : BiometricDataPacket;
	}
	
	port def BiometricSensorPort {
		out item sensorData : BiometricDataPacket;
	}
	
	port def WirelessPort {
		in item receivedSignal : WirelessMessage;
		out item transmittedSignal : WirelessMessage;
	}
	
	port def PowerPort {
		out item powerSupply : ISQ::PowerValue;
	}
	
	port def DisplayPort {
		in item displayData : BiometricDataPacket;
	}
	
	part def HeartRateSensor {
		port sensorOutput : BiometricSensorPort;
		
		action def MeasureHeartRate {
			out heartRateData : Real;
		}
		
		perform action measureContinuously : MeasureHeartRate;
	}
	
	part def TemperatureSensor {
		port sensorOutput : BiometricSensorPort;
		
		action def MeasureTemperature {
			out temperatureData : ISQ::ThermodynamicTemperatureValue;
		}
		
		perform action measureContinuously : MeasureTemperature;
	}
	
	part def OxygenSensor {
		port sensorOutput : BiometricSensorPort;
		
		action def MeasureOxygen {
			out oxygenData : Real;
		}
		
		perform action measureContinuously : MeasureOxygen;
	}
	
	part def ActivityMonitor {
		port sensorOutput : BiometricSensorPort;
		
		action def MeasureActivity {
			out activityData : Real;
		}
		
		perform action measureContinuously : MeasureActivity;
	}
	
	part def DataProcessor {
		in attribute rawHeartRate : Real;
		in attribute rawTemperature : ISQ::ThermodynamicTemperatureValue;
		in attribute rawOxygen : Real;
		in attribute rawActivity : Real;
		out attribute processedPacket : BiometricDataPacket;
		
		action def AggregateData {
			in hr : Real;
			in temp : ISQ::ThermodynamicTemperatureValue;
			in oxy : Real;
			in act : Real;
			out dataPacket : BiometricDataPacket;
		}
		
		action def AnalyzeData {
			in dataPacket : BiometricDataPacket;
			out anomalyDetected : Boolean;
			out alert : AlertMessage;
		}
		
		perform action processData : AggregateData;
		perform action analyzeData : AnalyzeData;
	}
	
	part def WirelessTransceiver {
		port commPort : WirelessPort;
		attribute transmissionPower : ISQ::PowerValue;
		attribute operatingFrequency : ISQ::FrequencyValue;
		
		action def TransmitData {
			in dataPacket : BiometricDataPacket;
			out message : WirelessMessage;
			out status : TransmissionStatus;
		}
		
		action def ReceiveData {
			in message : WirelessMessage;
			out dataPacket : BiometricDataPacket;
		}
		
		perform action transmit : TransmitData;
		perform action receive : ReceiveData;
	}
	
	part def BatteryPack {
		port powerOutput : PowerPort;
		attribute chargeLevel : Real;
		attribute capacity : ISQ::EnergyValue;
		
		action def SupplyPower {
			out power : ISQ::PowerValue;
		}
		
		action def MonitorCharge {
			out currentCharge : Real;
		}
		
		perform action supplyPower : SupplyPower;
		perform action monitorCharge : MonitorCharge;
	}
	
	part def UserDisplay {
		port displayInput : DisplayPort;
		
		action def ShowBiometrics {
			in data : BiometricDataPacket;
		}
		
		action def ShowAlert {
			in alert : AlertMessage;
		}
		
		perform action displayBiometrics : ShowBiometrics;
		perform action displayAlert : ShowAlert;
	}
	
	state def BodyKomOperationalStates {
		entry; then initialization;
		
		state initialization;
		
		transition init_to_monitoring
			first initialization
			accept at systemReady
			then monitoring;
		
		state monitoring;
		
		transition monitoring_to_processing
			first monitoring
			accept at dataCollected
			then processing;
		
		state processing;
		
		transition processing_to_transmitting
			first processing
			accept at dataProcessed
			then transmitting;
		
		state transmitting;
		
		transition transmitting_to_monitoring
			first transmitting
			accept at transmissionComplete
			then monitoring;
		
		transition transmitting_to_error
			first transmitting
			accept at transmissionFailed
			then error;
		
		state error;
		
		transition error_to_monitoring
			first error
			accept at errorRecovered
			then monitoring;
		
		transition monitoring_to_lowPower
			first monitoring
			accept at batteryLow
			then lowPower;
		
		state lowPower;
		
		transition lowPower_to_shutdown
			first lowPower
			accept at batteryCritical
			then shutdown;
		
		state shutdown;
	}
	
	action def ContinuousBiometricMonitoring {
		first start;
		then merge monitoringLoop;
		
		action collectSensorData {
			out heartRate : Real;
			out temperature : ISQ::ThermodynamicTemperatureValue;
			out oxygenLevel : Real;
			out activityLevel : Real;
		}
		
		then action aggregateData {
			in hr : Real = collectSensorData.heartRate;
			in temp : ISQ::ThermodynamicTemperatureValue = collectSensorData.temperature;
			in oxy : Real = collectSensorData.oxygenLevel;
			in act : Real = collectSensorData.activityLevel;
			out combinedData : BiometricDataPacket;
		}
		
		then action analyzeForAnomalies {
			in data : BiometricDataPacket = aggregateData.combinedData;
			out requiresAlert : Boolean;
			out alertMsg : AlertMessage;
		}
		
		then decide;
			if analyzeForAnomalies.requiresAlert then transmitWithAlert;
			if not analyzeForAnomalies.requiresAlert then transmitNormal;
		
		action transmitWithAlert {
			first action sendAlert {
				in alert : AlertMessage = analyzeForAnomalies.alertMsg;
			}
			then action sendData {
				in data : BiometricDataPacket = aggregateData.combinedData;
				out txStatus : TransmissionStatus;
			}
		}
		
		action transmitNormal {
			in data : BiometricDataPacket = aggregateData.combinedData;
			out txStatus : TransmissionStatus;
		}
		
		then monitoringLoop;
	}
	
	part def BodyKom {
		attribute deviceIdentifier : DeviceID;
		attribute operationalMode : String;
		attribute powerMode : String;
		
		part hrSensor : HeartRateSensor {
			port :>> sensorOutput;
		}
		
		part tempSensor : TemperatureSensor {
			port :>> sensorOutput;
		}
		
		part o2Sensor : OxygenSensor {
			port :>> sensorOutput;
		}
		
		part activitySensor : ActivityMonitor {
			port :>> sensorOutput;
		}
		
		part dataProc : DataProcessor;
		
		part radio : WirelessTransceiver {
			port :>> commPort;
			attribute :>> transmissionPower;
			attribute :>> operatingFrequency;
		}
		
		part battery : BatteryPack {
			port :>> powerOutput;
			attribute :>> chargeLevel = 100.0;
		}
		
		part display : UserDisplay {
			port :>> displayInput;
		}
		
		exhibit state operatingStates : BodyKomOperationalStates;
		
		perform action primaryFunction[*] ordered references ContinuousBiometricMonitoring {
			perform collectSensorData by hrSensor, tempSensor, o2Sensor, activitySensor;
			perform aggregateData by dataProc;
			perform analyzeForAnomalies by dataProc;
			perform transmitWithAlert.sendAlert by display;
			perform transmitWithAlert.sendData by radio;
			perform transmitNormal by radio;
		}
		
		connection hrConnection connect hrSensor.sensorOutput to dataProc;
		connection tempConnection connect tempSensor.sensorOutput to dataProc;
		connection o2Connection connect o2Sensor.sensorOutput to dataProc;
		connection activityConnection connect activitySensor.sensorOutput to dataProc;
		connection processorToRadio connect dataProc to radio.commPort;
		connection processorToDisplay connect dataProc to display.displayInput;
		connection batteryToSensors connect battery.powerOutput to hrSensor;
		connection batteryToProcessor connect battery.powerOutput to dataProc;
		connection batteryToRadio connect battery.powerOutput to radio;
	}
	
	part def MonitoringHub {
		port hubCommPort : WirelessPort;
		
		part hubRadio : WirelessTransceiver {
			port :>> commPort;
		}
		
		part dataArchive {
			in attribute storedBiometrics : BiometricDataPacket[*];
			in attribute storedAlerts : AlertMessage[*];
		}
		
		part hubDisplay {
			in attribute currentData : BiometricDataPacket;
			in attribute currentAlerts : AlertMessage[*];
		}
		
		action def ReceiveAndArchive {
			in message : WirelessMessage;
			out archivedData : BiometricDataPacket;
		}
		
		action def ProcessAlerts {
			in alert : AlertMessage;
			out notificationSent : Boolean;
		}
		
		perform action receiveData : ReceiveAndArchive;
		perform action handleAlerts : ProcessAlerts;
		
		connection hubRadioConnection connect hubRadio.commPort to hubCommPort;
	}
	
	part bodyKomSystem {
		part wearableDevice : BodyKom {
			attribute :>> deviceIdentifier;
			perform primaryFunction;
		}
		
		part centralHub : MonitoringHub {
			perform receiveData;
			perform handleAlerts;
		}
		
		connection wirelessCommunication connect 
			wearableDevice.radio.commPort to centralHub.hubCommPort;
	}
	
	requirement def BiometricAccuracyRequirement {
		doc /* All biometric sensors shall provide measurements within specified accuracy tolerances. */
		
		subject device : BodyKom;
		
		require constraint heartRateAccuracy {
			doc /* Heart rate measurements shall be accurate within ±3 bpm. */
		}
		
		require constraint temperatureAccuracy {
			doc /* Temperature measurements shall be accurate within ±0.2°C. */
		}
		
		require constraint oxygenAccuracy {
			doc /* Blood oxygen measurements shall be accurate within ±2%. */
		}
	}
	
	requirement def WirelessCommunicationRequirement {
		doc /* Wireless communication shall maintain reliable connection within operational range. */
		
		subject transceiver : WirelessTransceiver;
		
		require constraint communicationRange {
			doc /* Device shall maintain connection up to 15 meters in open space. */
		}
		
		require constraint dataIntegrity {
			doc /* Transmitted data packets shall have error rate less than 0.1%. */
		}
	}
	
	requirement def PowerManagementRequirement {
		doc /* Device shall operate continuously for minimum specified duration on single charge. */
		
		subject power : BatteryPack;
		
		require constraint batteryLife {
			doc /* Device shall operate for minimum 48 hours under normal usage. */
		}
		
		require constraint lowPowerMode {
			doc /* Device shall enter low power mode when battery drops below 15%. */
		}
	}
	
	requirement def RealTimeMonitoringRequirement {
		doc /* System shall provide continuous real-time monitoring with minimal latency. */
		
		subject monitoring : ContinuousBiometricMonitoring;
		
		require constraint samplingRate {
			doc /* Biometric data shall be sampled at minimum 1 Hz frequency. */
		}
		
		require constraint transmissionLatency {
			doc /* End-to-end latency from sensing to hub reception shall not exceed 3 seconds. */
		}
	}
	
	requirement def AlertingRequirement {
		doc /* System shall detect and alert on abnormal biometric conditions. */
		
		subject analysis : DataProcessor;
		
		require constraint anomalyDetection {
			doc /* System shall detect heart rate outside 40-180 bpm range. */
		}
		
		require constraint alertLatency {
			doc /* Alerts shall be generated within 2 seconds of anomaly detection. */
		}
	}
	
	requirement <'BODYKOM-SYS-001'> systemPrimaryRequirement {
		doc /* The BodyKom system shall continuously monitor vital biometric parameters from a wearable device and wirelessly transmit data to a central monitoring hub for real-time health assessment and alerting. */
		
		subject bodyKomSystem;
		
		assume constraint operationalEnvironment {
			doc /* System operates in typical indoor and outdoor environments with temperature range -10°C to 50°C. */
		}
		
		assume constraint userCompliance {
			doc /* Device is worn correctly and maintained according to specifications. */
		}
		
		require BiometricAccuracyRequirement;
		require WirelessCommunicationRequirement;
		require PowerManagementRequirement;
		require RealTimeMonitoringRequirement;
		require AlertingRequirement;
	}
}

package 'Unattended Ground Sensor System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	doc /* This model describes an Unattended Ground Sensor (UGS) system designed for 
	     autonomous perimeter surveillance and intrusion detection. The system detects, 
	     classifies, and reports ground-based intrusions using multi-modal sensing. */
	
	attribute def SensorID :> String;
	attribute def TargetClassification :> String;
	attribute def ConfidenceLevel :> Real;
	attribute def BatteryStateOfCharge :> Real;
	
	enum def OperationalMode {
		enum standby;
		enum active;
		enum lowPower;
		enum maintenance;
	}
	
	enum def TargetCategory {
		enum personnel;
		enum lightVehicle;
		enum heavyVehicle;
		enum animal;
		enum unknown;
	}
	
	enum def AlertSeverity {
		enum low;
		enum medium;
		enum high;
		enum critical;
	}
	
	item def DetectionEvent {
		attribute timestamp : ISQ::TimeValue;
		attribute location : ISQ::LengthValue[3];
		attribute targetType : TargetCategory;
		attribute confidence : ConfidenceLevel;
		attribute severity : AlertSeverity;
	}
	
	item def SensorReading {
		attribute timestamp : ISQ::TimeValue;
		attribute value : Real;
		attribute sensorType : String;
	}
	
	port def SensorDataPort {
		out reading : SensorReading;
	}
	
	port def CommunicationPort {
		out alert : DetectionEvent;
		in command : OperationalMode;
	}
	
	port def PowerPort {
		in supply : ISQ::PowerValue;
		out demand : ISQ::PowerValue;
	}
	
	part def SeismicSensor {
		doc /* Detects ground vibrations from footsteps and vehicles. */
		attribute sensitivity : Real;
		attribute detectionRange : ISQ::LengthValue;
		port dataOut : SensorDataPort;
		
		action detectVibration {
			in groundMotion : ISQ::AccelerationValue;
			out vibrationReading : SensorReading;
			out detectionFlag : Boolean;
		}
	}
	
	part def AcousticSensor {
		doc /* Detects sound signatures from targets. */
		attribute frequencyRange : ISQ::FrequencyValue[2];
		attribute noiseThreshold : Real;
		port dataOut : SensorDataPort;
		
		action detectSound {
			in soundPressure : ISQ::PressureValue;
			out acousticReading : SensorReading;
			out detectionFlag : Boolean;
		}
	}
	
	part def PassiveInfraredSensor {
		doc /* Detects thermal signatures from moving targets. */
		attribute fieldOfView : Real;
		attribute detectionRange : ISQ::LengthValue;
		port dataOut : SensorDataPort;
		
		action detectHeat {
			in thermalSignature : ISQ::ThermodynamicTemperatureValue;
			out irReading : SensorReading;
			out detectionFlag : Boolean;
		}
	}
	
	part def MagneticSensor {
		doc /* Detects ferrous metal signatures from vehicles. */
		attribute sensitivity : Real;
		attribute detectionRange : ISQ::LengthValue;
		port dataOut : SensorDataPort;
		
		action detectMagnetic {
			in magneticField : ISQ::MagneticFluxDensityValue;
			out magneticReading : SensorReading;
			out detectionFlag : Boolean;
		}
	}
	
	part def SignalProcessor {
		doc /* Fuses multi-sensor data and classifies targets. */
		attribute processingCapacity : Real;
		
		action fuseSensorData {
			in seismicData : SensorReading;
			in acousticData : SensorReading;
			in irData : SensorReading;
			in magneticData : SensorReading;
			out fusedSignature : Real[*];
		}
		
		action classifyTarget {
			in signature : Real[*];
			out targetType : TargetCategory;
			out confidence : ConfidenceLevel;
		}
		
		action assessThreat {
			in targetType : TargetCategory;
			in confidence : ConfidenceLevel;
			out severity : AlertSeverity;
		}
	}
	
	part def CommunicationModule {
		doc /* Transmits alerts and receives commands via RF mesh network. */
		attribute transmitPower : ISQ::PowerValue;
		attribute frequency : ISQ::FrequencyValue;
		attribute range : ISQ::LengthValue;
		port commPort : CommunicationPort;
		
		action transmitAlert {
			in event : DetectionEvent;
			out transmissionSuccess : Boolean;
		}
		
		action receiveCommand {
			out modeCommand : OperationalMode;
		}
	}
	
	part def PowerManagementUnit {
		doc /* Manages battery and solar power to maximize operational lifetime. */
		attribute batteryCapacity : ISQ::EnergyValue;
		attribute currentCharge : BatteryStateOfCharge;
		attribute solarPanelOutput : ISQ::PowerValue;
		port powerPort : PowerPort;
		
		action managePower {
			in powerDemand : ISQ::PowerValue;
			in solarInput : ISQ::PowerValue;
			out availablePower : ISQ::PowerValue;
			out batteryStatus : BatteryStateOfCharge;
		}
		
		action selectPowerMode {
			in batteryLevel : BatteryStateOfCharge;
			in activityLevel : Real;
			out recommendedMode : OperationalMode;
		}
	}
	
	part def DataLogger {
		doc /* Stores detection events locally for later retrieval. */
		attribute storageCapacity : Real;
		attribute retentionPeriod : ISQ::TimeValue;
		
		action logEvent {
			in event : DetectionEvent;
			out storageSuccess : Boolean;
		}
		
		action retrieveHistory {
			in timeRange : ISQ::TimeValue[2];
			out historicalEvents : DetectionEvent[*];
		}
	}
	
	part def UGSSensorNode {
		doc /* A single autonomous sensor node capable of detecting and reporting intrusions. */
		attribute nodeID : SensorID;
		attribute deploymentLocation : ISQ::LengthValue[3];
		attribute currentMode : OperationalMode;
		
		part seismicSensor : SeismicSensor;
		part acousticSensor : AcousticSensor;
		part pirSensor : PassiveInfraredSensor;
		part magneticSensor : MagneticSensor;
		part processor : SignalProcessor;
		part comms : CommunicationModule;
		part powerMgmt : PowerManagementUnit;
		part logger : DataLogger;
		
		perform action surveillanceOperation;
	}
	
	action def MonitorEnvironment {
		out seismicReading : SensorReading;
		out acousticReading : SensorReading;
		out irReading : SensorReading;
		out magneticReading : SensorReading;
		out detectionOccurred : Boolean;
	}
	
	action def ProcessDetection {
		in seismicData : SensorReading;
		in acousticData : SensorReading;
		in irData : SensorReading;
		in magneticData : SensorReading;
		out targetType : TargetCategory;
		out confidence : ConfidenceLevel;
		out severity : AlertSeverity;
	}
	
	action def GenerateAlert {
		in targetType : TargetCategory;
		in confidence : ConfidenceLevel;
		in severity : AlertSeverity;
		in location : ISQ::LengthValue[3];
		out event : DetectionEvent;
	}
	
	action def TransmitReport {
		in event : DetectionEvent;
		out transmissionComplete : Boolean;
	}
	
	action surveillanceOperation {
		doc /* Primary surveillance function: continuously monitor area, detect intrusions, 
		     classify targets, and transmit alerts to command center. */
		
		first start;
		then merge continuousMonitoring;
		
		then action monitor : MonitorEnvironment {
			out seismicReading : SensorReading;
			out acousticReading : SensorReading;
			out irReading : SensorReading;
			out magneticReading : SensorReading;
			out detectionOccurred : Boolean;
		}
		
		then decide;
			if monitor.detectionOccurred then processDetection;
			if not monitor.detectionOccurred then continuousMonitoring;
		
		action processDetection : ProcessDetection {
			in seismicData = monitor.seismicReading;
			in acousticData = monitor.acousticReading;
			in irData = monitor.irReading;
			in magneticData = monitor.magneticReading;
			out targetType : TargetCategory;
			out confidence : ConfidenceLevel;
			out severity : AlertSeverity;
		}
		
		then decide;
			if processDetection.confidence >= 0.7 then generateAlert;
			if processDetection.confidence < 0.7 then continuousMonitoring;
		
		action generateAlert : GenerateAlert {
			in targetType = processDetection.targetType;
			in confidence = processDetection.confidence;
			in severity = processDetection.severity;
			in location : ISQ::LengthValue[3];
			out event : DetectionEvent;
		}
		
		then action transmit : TransmitReport {
			in event = generateAlert.event;
			out transmissionComplete : Boolean;
		}
		
		then continuousMonitoring;
	}
	
	part def CommandCenter {
		doc /* Central monitoring station that receives and displays alerts from sensor nodes. */
		attribute stationID : String;
		
		part receiver : CommunicationModule;
		attribute alertLog : DetectionEvent[*];
		
		action processIncomingAlerts {
			in alert : DetectionEvent;
			out displayUpdate : Boolean;
		}
	}
	
	part def UGSNetwork {
		doc /* Complete surveillance system comprising multiple sensor nodes and command center. */
		
		part sensorNodes[1..*] : UGSSensorNode {
			perform surveillanceOperation;
		}
		part commandCenter : CommandCenter;
		
		item flow of DetectionEvent from sensorNodes.comms.commPort to commandCenter.receiver.commPort;
	}
	
	requirement def MissionRequirement;
	requirement missionRequirements : MissionRequirement[*] nonunique;
	
	requirement <'UGS-REQ-001'> primaryMissionRequirement {
		doc /* The UGS system shall autonomously detect, classify, and report ground-based 
		     intrusions within its designated surveillance area without human intervention. */
		
		subject ugsNetwork : UGSNetwork;
		
		require detectionCapability;
		require classificationCapability;
		require communicationCapability;
		require autonomousOperation;
		require powerEndurance;
	}
	
	requirement detectionCapability {
		doc /* The system shall detect personnel at ranges up to 50 meters and vehicles 
		     at ranges up to 150 meters with probability of detection >= 0.90. */
	}
	
	requirement classificationCapability {
		doc /* The system shall classify detected targets into personnel, light vehicle, 
		     heavy vehicle, or animal categories with accuracy >= 0.85. */
	}
	
	requirement communicationCapability {
		doc /* The system shall transmit detection alerts to the command center within 
		     5 seconds of target classification with reliability >= 0.95. */
	}
	
	requirement autonomousOperation {
		doc /* The system shall operate continuously without maintenance or operator 
		     intervention for the duration of its power supply. */
	}
	
	requirement powerEndurance {
		doc /* Each sensor node shall operate autonomously for at least 90 days on 
		     battery power with solar recharge capability. */
	}
	
	requirement <'UGS-REQ-002'> environmentalRequirement {
		doc /* The system shall operate in temperature ranges from -40°C to +60°C and 
		     withstand exposure to rain, dust, and humidity per MIL-STD-810. */
	}
	
	requirement <'UGS-REQ-003'> falseAlarmRequirement {
		doc /* The system shall maintain a false alarm rate of less than 2 per 24-hour 
		     period per sensor node under normal environmental conditions. */
	}
	
	requirement <'UGS-REQ-004'> securityRequirement {
		doc /* All communications shall be encrypted and authenticated to prevent 
		     spoofing and eavesdropping. */
	}
}

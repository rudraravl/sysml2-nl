package UnattendedGroundSensorsModel {
	import ScalarValues::*;
	import ISQ::*;
	import SI::*;

	doc /* An unattended ground sensor system is a deployable, battery powered sensing network that monitors a local ground area without continuous human presence. Its primary function is to detect, classify, localize, and report target activity such as personnel or vehicles to a remote operator station. */

	attribute def Identifier :> String;
	attribute def Confidence :> Real;
	attribute def FalseAlarmRate :> Real;
	attribute def MessageRate :> ISQ::frequency;

	enum def TargetClass {
		enum unknown;
		enum person;
		enum wheeledVehicle;
		enum trackedVehicle;
		enum animal;
		enum environmentalNoise;
	}

	enum def NodeHealthState {
		enum healthy;
		enum degraded;
		enum failed;
		enum lowEnergy;
		enum tamperSuspected;
	}

	enum def ReportPriority {
		enum routine;
		enum alert;
		enum urgent;
	}

	item def GeoLocation {
		attribute latitude : Real;
		attribute longitude : Real;
		attribute altitude : ISQ::length;
	}

	item def TimeStampedTargetSignature {
		attribute eventTime : ISQ::time;
		attribute seismicPeakAcceleration : ISQ::acceleration;
		attribute acousticDominantFrequency : ISQ::frequency;
		attribute magneticDisturbance : Real;
		attribute estimatedRange : ISQ::length;
		attribute estimatedBearing : ISQ::angle;
	}

	item def SeismicSample {
		attribute sampleTime : ISQ::time;
		attribute peakAcceleration : ISQ::acceleration;
		attribute dominantFrequency : ISQ::frequency;
		attribute signalToNoiseRatio : Real;
	}

	item def AcousticSample {
		attribute sampleTime : ISQ::time;
		attribute soundPressureMetric : Real;
		attribute dominantFrequency : ISQ::frequency;
		attribute signalToNoiseRatio : Real;
	}

	item def MagneticSample {
		attribute sampleTime : ISQ::time;
		attribute magneticDisturbance : Real;
		attribute signalToNoiseRatio : Real;
	}

	item def ElectricalPower {
		attribute voltage : ISQ::electricPotential;
		attribute current : ISQ::electricCurrent;
		attribute power : ISQ::power;
	}

	item def CommandMessage {
		attribute commandId : Identifier;
		attribute destinationNodeId : Identifier;
		attribute commandText : String;
		attribute requestedMode : String;
		attribute issuedTime : ISQ::time;
	}

	item def StatusMessage {
		attribute nodeId : Identifier;
		attribute health : NodeHealthState;
		attribute remainingEnergy : ISQ::energy;
		attribute batteryVoltage : ISQ::electricPotential;
		attribute internalTemperature : ISQ::thermodynamicTemperature;
		attribute lastReportTime : ISQ::time;
	}

	item def DetectionReport {
		attribute reportId : Identifier;
		attribute reportingNodeId : Identifier;
		attribute targetClass : TargetClass;
		attribute confidence : Confidence;
		attribute priority : ReportPriority;
		attribute targetLocation : GeoLocation;
		attribute estimatedRange : ISQ::length;
		attribute estimatedBearing : ISQ::angle;
		attribute eventTime : ISQ::time;
		attribute reportLatency : ISQ::time;
	}

	item def NetworkMessage {
		attribute sourceId : Identifier;
		attribute destinationId : Identifier;
		attribute messageTime : ISQ::time;
	}

	item def EnvironmentalCondition {
		attribute ambientTemperature : ISQ::thermodynamicTemperature;
		attribute windSpeed : ISQ::speed;
		attribute precipitationRate : Real;
		attribute backgroundVibration : ISQ::acceleration;
	}

	port def PowerPort {
		inout item power : ElectricalPower;
	}

	port def CommandPort {
		inout item command : CommandMessage;
	}

	port def StatusPort {
		inout item status : StatusMessage;
	}

	port def DetectionReportPort {
		inout item report : DetectionReport;
	}

	port def NetworkPort {
		inout item networkMessage : NetworkMessage;
		inout item command : CommandMessage;
		inout item status : StatusMessage;
		inout item report : DetectionReport;
	}

	port def SeismicSensingPort {
		inout item signature : TimeStampedTargetSignature;
		inout item sample : SeismicSample;
	}

	port def AcousticSensingPort {
		inout item signature : TimeStampedTargetSignature;
		inout item sample : AcousticSample;
	}

	port def MagneticSensingPort {
		inout item signature : TimeStampedTargetSignature;
		inout item sample : MagneticSample;
	}

	port def EnvironmentalPort {
		inout item condition : EnvironmentalCondition;
		inout item signature : TimeStampedTargetSignature;
	}

	action def AcquireSeismicEvidence {
		in item groundSignature : TimeStampedTargetSignature;
		out item seismicSample : SeismicSample;
	}

	action def AcquireAcousticEvidence {
		in item acousticSignature : TimeStampedTargetSignature;
		out item acousticSample : AcousticSample;
	}

	action def AcquireMagneticEvidence {
		in item magneticSignature : TimeStampedTargetSignature;
		out item magneticSample : MagneticSample;
	}

	action def FuseSensorEvidence {
		in item seismicSample : SeismicSample;
		in item acousticSample : AcousticSample;
		in item magneticSample : MagneticSample;
		out item fusedSignature : TimeStampedTargetSignature;
	}

	action def ClassifyTarget {
		in item fusedSignature : TimeStampedTargetSignature;
		out item targetClass : TargetClass;
		out item confidence : Confidence;
	}

	action def LocalizeTarget {
		in item fusedSignature : TimeStampedTargetSignature;
		in item nodeLocation : GeoLocation;
		out item targetLocation : GeoLocation;
		out item estimatedRange : ISQ::length;
		out item estimatedBearing : ISQ::angle;
	}

	action def EmitDetectionReport {
		in item targetClass : TargetClass;
		in item confidence : Confidence;
		in item targetLocation : GeoLocation;
		out item detectionReport : DetectionReport;
	}

	action def SenseClassifyLocalizeAndReport {
		doc /* Primary high-level UGS function: observe the local environment, extract seismic/acoustic/magnetic evidence, classify a target, estimate its location, and transmit a detection report to a remote user. */

		in item environmentalSignature : TimeStampedTargetSignature;
		in item nodeLocation : GeoLocation;
		out item detectionReport : DetectionReport;

		attribute classificationThreshold : Confidence = 0.75;
		attribute maximumReportLatency : ISQ::time = 10 [s];

		action acquireSeismic : AcquireSeismicEvidence;
		action acquireAcoustic : AcquireAcousticEvidence;
		action acquireMagnetic : AcquireMagneticEvidence;
		action fuseEvidence : FuseSensorEvidence;
		action classify : ClassifyTarget;
		action localize : LocalizeTarget;
		action report : EmitDetectionReport;
	}

	state def SensorNodeLifeCycle {
		doc /* Sensor node operating modes from deployment through unattended monitoring and reporting. */

		state stored;
		state selfTest;
		state standby;
		state monitoring;
		state eventDetected;
		state reporting;
		state lowPower;
		state fault;

		transition initial first stored;
		transition deploy from stored to selfTest;
		transition selfTestPassed from selfTest to standby;
		transition selfTestFailed from selfTest to fault;
		transition arm from standby to monitoring;
		transition targetEvidenceAvailable from monitoring to eventDetected;
		transition reportNeeded from eventDetected to reporting;
		transition reportComplete from reporting to monitoring;
		transition energyLow from monitoring to lowPower;
		transition wakeForScheduledScan from lowPower to monitoring;
		transition unrecoverableFault from monitoring to fault;
	}

	state def GatewayLifeCycle {
		state off;
		state booting;
		state connected;
		state relaying;
		state degraded;
		state failed;

		transition initial first off;
		transition powerApplied from off to booting;
		transition bootComplete from booting to connected;
		transition messageReceived from connected to relaying;
		transition relayComplete from relaying to connected;
		transition linkWeak from connected to degraded;
		transition linkRestored from degraded to connected;
		transition hardwareFault from connected to failed;
	}

	part def BatteryPack {
		attribute nominalVoltage : ISQ::electricPotential = 12 [V];
		attribute energyCapacity : ISQ::energy = 2592000 [J];
		attribute minimumOperatingVoltage : ISQ::electricPotential = 9 [V];
		attribute maximumDischargePower : ISQ::power = 8 [W];

		port outputPower : PowerPort;
	}

	part def SolarCharger {
		attribute peakChargePower : ISQ::power = 5 [W];
		attribute regulatedVoltage : ISQ::electricPotential = 12 [V];

		port generatedPower : PowerPort;
		port batteryPower : PowerPort;
	}

	part def PowerManager {
		attribute sleepModePower : ISQ::power = 0.05 [W];
		attribute monitoringModePower : ISQ::power = 1.5 [W];
		attribute transmitModePower : ISQ::power = 4 [W];

		port batteryPort : PowerPort;
		port chargerPort : PowerPort;
		port loadPowerPort : PowerPort;
	}

	part def SeismicSensor {
		attribute sampleRate : ISQ::frequency = 200 [Hz];
		attribute minimumDetectableAcceleration : ISQ::acceleration;
		attribute nominalPower : ISQ::power = 0.25 [W];

		port powerPort : PowerPort;
		port environmentPort : SeismicSensingPort;
		port samplePort : SeismicSensingPort;

		action acquire : AcquireSeismicEvidence;
	}

	part def AcousticSensor {
		attribute sampleRate : ISQ::frequency = 8000 [Hz];
		attribute lowFrequencyLimit : ISQ::frequency = 20 [Hz];
		attribute highFrequencyLimit : ISQ::frequency = 4000 [Hz];
		attribute nominalPower : ISQ::power = 0.18 [W];

		port powerPort : PowerPort;
		port environmentPort : AcousticSensingPort;
		port samplePort : AcousticSensingPort;

		action acquire : AcquireAcousticEvidence;
	}

	part def MagneticSensor {
		attribute sampleRate : ISQ::frequency = 100 [Hz];
		attribute nominalPower : ISQ::power = 0.12 [W];

		port powerPort : PowerPort;
		port environmentPort : MagneticSensingPort;
		port samplePort : MagneticSensingPort;

		action acquire : AcquireMagneticEvidence;
	}

	part def TamperSensor {
		attribute tiltThreshold : ISQ::angle = 0.35 [rad];
		attribute nominalPower : ISQ::power = 0.05 [W];

		port powerPort : PowerPort;
		port statusPort : StatusPort;
	}

	part def MissionProcessor {
		attribute processorId : Identifier;
		attribute classificationThreshold : Confidence = 0.75;
		attribute maximumProcessingLatency : ISQ::time = 2 [s];
		attribute nominalPower : ISQ::power = 0.7 [W];

		port powerPort : PowerPort;
		port seismicSamplePort : SeismicSensingPort;
		port acousticSamplePort : AcousticSensingPort;
		port magneticSamplePort : MagneticSensingPort;
		port commandPort : CommandPort;
		port statusPort : StatusPort;
		port reportPort : DetectionReportPort;

		action primaryFunction : SenseClassifyLocalizeAndReport;
		action fuseEvidence : FuseSensorEvidence;
		action classify : ClassifyTarget;
		action localize : LocalizeTarget;
	}

	part def RadioTransceiver {
		attribute operatingFrequency : ISQ::frequency = 915000000 [Hz];
		attribute transmitPower : ISQ::power = 1 [W];
		attribute receivePower : ISQ::power = 0.35 [W];
		attribute nominalLineOfSightRange : ISQ::length = 5000 [m];

		port powerPort : PowerPort;
		port localReportPort : DetectionReportPort;
		port localCommandPort : CommandPort;
		port localStatusPort : StatusPort;
		port networkPort : NetworkPort;
	}

	part def SensorNode {
		doc /* An autonomous field node that senses local ground activity, classifies target evidence, and communicates reports through the UGS network. */

		attribute nodeId : Identifier;
		attribute installedLocation : GeoLocation;
		attribute nominalDetectionRange : ISQ::length = 250 [m];
		attribute missionEndurance : ISQ::time = 2592000 [s];
		attribute probabilityOfDetection : Confidence = 0.90;
		attribute falseAlarmRatePerDay : FalseAlarmRate = 0.05;
		attribute health : NodeHealthState;

		port externalEnvironmentPort : EnvironmentalPort;
		port networkPort : NetworkPort;

		part battery : BatteryPack;
		part solarCharger : SolarCharger;
		part powerManager : PowerManager;
		part seismicSensor : SeismicSensor;
		part acousticSensor : AcousticSensor;
		part magneticSensor : MagneticSensor;
		part tamperSensor : TamperSensor;
		part processor : MissionProcessor;
		part radio : RadioTransceiver;

		state lifeCycle : SensorNodeLifeCycle;

		connection batteryToManager connect battery.outputPower to powerManager.batteryPort;
		connection chargerToManager connect solarCharger.generatedPower to powerManager.chargerPort;
		connection managerToSeismic connect powerManager.loadPowerPort to seismicSensor.powerPort;
		connection managerToAcoustic connect powerManager.loadPowerPort to acousticSensor.powerPort;
		connection managerToMagnetic connect powerManager.loadPowerPort to magneticSensor.powerPort;
		connection managerToTamper connect powerManager.loadPowerPort to tamperSensor.powerPort;
		connection managerToProcessor connect powerManager.loadPowerPort to processor.powerPort;
		connection managerToRadio connect powerManager.loadPowerPort to radio.powerPort;

		connection environmentToSeismic connect externalEnvironmentPort to seismicSensor.environmentPort;
		connection environmentToAcoustic connect externalEnvironmentPort to acousticSensor.environmentPort;
		connection environmentToMagnetic connect externalEnvironmentPort to magneticSensor.environmentPort;

		connection seismicToProcessor connect seismicSensor.samplePort to processor.seismicSamplePort;
		connection acousticToProcessor connect acousticSensor.samplePort to processor.acousticSamplePort;
		connection magneticToProcessor connect magneticSensor.samplePort to processor.magneticSamplePort;

		connection processorReportToRadio connect processor.reportPort to radio.localReportPort;
		connection processorCommandToRadio connect processor.commandPort to radio.localCommandPort;
		connection processorStatusToRadio connect processor.statusPort to radio.localStatusPort;
		connection radioToNetwork connect radio.networkPort to networkPort;
	}

	part def Gateway {
		doc /* A communications aggregation point that relays field sensor reports to an operator station and distributes commands to unattended nodes. */

		attribute gatewayId : Identifier;
		attribute nominalBackhaulRange : ISQ::length = 15000 [m];
		attribute messageThroughput : MessageRate = 20 [Hz];
		attribute maximumRelayLatency : ISQ::time = 3 [s];

		port nodeNetworkPort : NetworkPort;
		port operatorNetworkPort : NetworkPort;
		port powerPort : PowerPort;

		part radio : RadioTransceiver;
		part powerManager : PowerManager;
		part battery : BatteryPack;

		state gatewayState : GatewayLifeCycle;

		connection gatewayBatteryToPower connect battery.outputPower to powerManager.batteryPort;
		connection gatewayPowerToRadio connect powerManager.loadPowerPort to radio.powerPort;
		connection gatewayRadioToNodes connect radio.networkPort to nodeNetworkPort;
		connection gatewayRadioToOperator connect radio.networkPort to operatorNetworkPort;
	}

	part def OperatorStation {
		doc /* Remote user equipment that receives detection reports, displays target activity, and sends mission commands. */

		attribute stationId : Identifier;
		attribute displayRefreshRate : ISQ::frequency = 1 [Hz];
		attribute maximumAcknowledgementTime : ISQ::time = 30 [s];

		port networkPort : NetworkPort;
		port commandPort : CommandPort;
		port reportPort : DetectionReportPort;
		port statusPort : StatusPort;
	}

	part def OperationalEnvironment {
		attribute areaName : String;
		attribute nominalAmbientTemperature : ISQ::thermodynamicTemperature = 293 [K];
		attribute backgroundVibration : ISQ::acceleration;
		attribute backgroundAcousticFrequency : ISQ::frequency = 100 [Hz];
		attribute monitoredAreaRadius : ISQ::length = 1000 [m];

		port environmentPort : EnvironmentalPort;
	}

	part def UnattendedGroundSensorSystem {
		doc /* System-of-interest: an unattended ground sensor network that provides persistent remote surveillance by deploying multiple autonomous sensor nodes, a gateway, and an operator station interface. */

		attribute systemId : Identifier;
		attribute nominalDetectionRange : ISQ::length = 250 [m];
		attribute monitoredAreaRadius : ISQ::length = 1000 [m];
		attribute requiredMissionEndurance : ISQ::time = 2592000 [s];
		attribute requiredDetectionConfidence : Confidence = 0.85;
		attribute maximumAllowedFalseAlarmRatePerDay : FalseAlarmRate = 0.10;
		attribute maximumReportLatency : ISQ::time = 15 [s];

		port externalCommandPort : CommandPort;
		port externalReportPort : DetectionReportPort;
		port externalStatusPort : StatusPort;

		part environment : OperationalEnvironment;
		part northNode : SensorNode;
		part eastNode : SensorNode;
		part southNode : SensorNode;
		part westNode : SensorNode;
		part gateway : Gateway;
		part operatorStation : OperatorStation;

		connection environmentToNorth connect environment.environmentPort to northNode.externalEnvironmentPort;
		connection environmentToEast connect environment.environmentPort to eastNode.externalEnvironmentPort;
		connection environmentToSouth connect environment.environmentPort to southNode.externalEnvironmentPort;
		connection environmentToWest connect environment.environmentPort to westNode.externalEnvironmentPort;

		connection northToGateway connect northNode.networkPort to gateway.nodeNetworkPort;
		connection eastToGateway connect eastNode.networkPort to gateway.nodeNetworkPort;
		connection southToGateway connect southNode.networkPort to gateway.nodeNetworkPort;
		connection westToGateway connect westNode.networkPort to gateway.nodeNetworkPort;

		connection gatewayToOperator connect gateway.operatorNetworkPort to operatorStation.networkPort;
		connection operatorCommands connect operatorStation.commandPort to externalCommandPort;
		connection operatorReports connect operatorStation.reportPort to externalReportPort;
		connection operatorStatus connect operatorStation.statusPort to externalStatusPort;
	}

	requirement def PrimaryFunctionRequirement {
		doc /* The UGS system shall detect, classify, localize, and report ground target activity without continuous human presence. */

		subject system : UnattendedGroundSensorSystem;

		attribute minimumDetectionRange : ISQ::length = 200 [m];
		attribute minimumDetectionConfidence : Confidence = 0.85;
		attribute maximumReportLatency : ISQ::time = 15 [s];

		require constraint {
			system.nominalDetectionRange >= minimumDetectionRange
		}

		require constraint {
			system.requiredDetectionConfidence >= minimumDetectionConfidence
		}

		require constraint {
			system.maximumReportLatency <= maximumReportLatency
		}
	}

	requirement def EnduranceRequirement {
		doc /* The UGS system shall operate unattended for the planned mission duration using internal stored or harvested energy. */

		subject system : UnattendedGroundSensorSystem;

		attribute minimumEndurance : ISQ::time = 2592000 [s];

		require constraint {
			system.requiredMissionEndurance >= minimumEndurance
		}
	}

	requirement def FalseAlarmRequirement {
		doc /* The UGS system shall limit false alerts while maintaining target detection performance. */

		subject system : UnattendedGroundSensorSystem;

		attribute maximumFalseAlarmsPerDay : FalseAlarmRate = 0.10;

		require constraint {
			system.maximumAllowedFalseAlarmRatePerDay <= maximumFalseAlarmsPerDay
		}
	}

	requirement def CoverageRequirement {
		doc /* The deployed UGS network shall monitor the assigned area using multiple distributed sensor nodes. */

		subject system : UnattendedGroundSensorSystem;

		attribute minimumMonitoredAreaRadius : ISQ::length = 1000 [m];

		require constraint {
			system.monitoredAreaRadius >= minimumMonitoredAreaRadius
		}
	}

	part unattendedGroundSensorSystem : UnattendedGroundSensorSystem {
		attribute systemId : Identifier = "UGS-NET-001";
		attribute nominalDetectionRange : ISQ::length = 250 [m];
		attribute monitoredAreaRadius : ISQ::length = 1000 [m];
		attribute requiredMissionEndurance : ISQ::time = 2592000 [s];
		attribute requiredDetectionConfidence : Confidence = 0.90;
		attribute maximumAllowedFalseAlarmRatePerDay : FalseAlarmRate = 0.05;
		attribute maximumReportLatency : ISQ::time = 10 [s];
	}

	requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
		subject system : UnattendedGroundSensorSystem = unattendedGroundSensorSystem;
	}

	requirement enduranceRequirement : EnduranceRequirement {
		subject system : UnattendedGroundSensorSystem = unattendedGroundSensorSystem;
	}

	requirement falseAlarmRequirement : FalseAlarmRequirement {
		subject system : UnattendedGroundSensorSystem = unattendedGroundSensorSystem;
	}

	requirement coverageRequirement : CoverageRequirement {
		subject system : UnattendedGroundSensorSystem = unattendedGroundSensorSystem;
	}

	satisfy primaryFunctionRequirement by unattendedGroundSensorSystem;
	satisfy enduranceRequirement by unattendedGroundSensorSystem;
	satisfy falseAlarmRequirement by unattendedGroundSensorSystem;
	satisfy coverageRequirement by unattendedGroundSensorSystem;
}

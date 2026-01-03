package AutomatedThreatSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ThreatLevel {
		attribute severity : Integer;
		attribute confidence : Real;
		attribute classification : String;
	}
	
	attribute def SensorData {
		attribute timestamp : TimeValue;
		attribute signalStrength : Real;
		attribute anomalyScore : Real;
		attribute sourceDirection : Real;
	}
	
	attribute def TargetTrack {
		attribute position : LengthValue[3];
		attribute velocity : SpeedValue[3];
		attribute acceleration : AccelerationValue[3];
		attribute trackId : String;
	}
	
	item def ThreatAlert {
		attribute level : ThreatLevel;
		attribute location : LengthValue[3];
		attribute detectionTime : TimeValue;
		attribute responseRequired : Boolean;
		attribute targetTrack : TargetTrack;
	}
	
	item def SensorReading {
		attribute data : SensorData;
		attribute sensorId : String;
		attribute sensorType : String;
	}
	
	item def EngagementCommand {
		attribute targetId : String;
		attribute weaponType : String;
		attribute fireAuthorization : Boolean;
		attribute aimPoint : LengthValue[3];
		attribute timeToImpact : TimeValue;
	}
	
	item def SystemStatus {
		attribute operational : Boolean;
		attribute activeThreats : Integer;
		attribute weaponsReady : Integer;
		attribute sensorHealth : Real;
	}
	
	port def SensorPort {
		out item reading : SensorReading;
	}
	
	port def AlertPort {
		out item alert : ThreatAlert;
	}
	
	port def TrackPort {
		in item sensorData : SensorReading;
		out item track : TargetTrack;
	}
	
	port def WeaponPort {
		in item command : EngagementCommand;
		out item status : String;
	}
	
	port def ControlPort {
		out item systemStatus : SystemStatus;
	}
	
	part def RadarSensor {
		port sensorOutput : SensorPort;
		
		attribute scanRate : FrequencyValue;
		attribute detectionRange : LengthValue;
		attribute azimuthCoverage : Real;
		attribute elevationCoverage : Real;
		
		perform action scanEnvironment[*] ordered;
	}
	
	part def InfraredSensor {
		port sensorOutput : SensorPort;
		
		attribute thermalSensitivity : Real;
		attribute detectionRange : LengthValue;
		attribute fieldOfView : Real;
		
		perform action detectThermalSignatures[*] ordered;
	}
	
	part def TrackingProcessor {
		port dataInput : ~SensorPort;
		port trackOutput : TrackPort;
		
		attribute trackingAccuracy : Real;
		attribute maxTrackedTargets : Integer;
		attribute updateRate : FrequencyValue;
		
		perform action processTrackData[*] ordered;
	}
	
	part def ThreatAssessmentEngine {
		port trackInput : ~TrackPort;
		port alertOutput : AlertPort;
		
		attribute threatThreshold : Real;
		attribute assessmentLatency : TimeValue;
		attribute rulesetVersion : String;
		
		perform action assessThreat[*] ordered;
	}
	
	part def WeaponController {
		port alertInput : ~AlertPort;
		port weaponOutput : WeaponPort;
		
		attribute maxEngagements : Integer;
		attribute safetyOverride : Boolean;
		attribute engagementRange : LengthValue;
		
		perform action controlWeapon[*] ordered;
	}
	
	part def MissileSystem {
		port commandInput : ~WeaponPort;
		
		attribute missileCount : Integer;
		attribute launchReady : Boolean;
		attribute interceptRange : LengthValue;
		attribute interceptSpeed : SpeedValue;
		
		perform action engageTarget[*] ordered;
	}
	
	action def ScanEnvironment {
		in scanParameters : SensorData;
		out detectedSignals : SensorReading[*];
	}
	
	action def ProcessTrackData {
		in rawSensorData : SensorReading[*];
		out targetTracks : TargetTrack[*];
		out trackQuality : Real;
	}
	
	action def AssessThreat {
		in targetTrack : TargetTrack;
		out threatLevel : ThreatLevel;
		out isHostile : Boolean;
	}
	
	action def GenerateThreatAlert {
		in assessment : ThreatLevel;
		in track : TargetTrack;
		out alert : ThreatAlert;
	}
	
	action def DetermineEngagement {
		in alert : ThreatAlert;
		out shouldEngage : Boolean;
		out engagementPriority : Integer;
	}
	
	action def IssueEngagementCommand {
		in alert : ThreatAlert;
		out command : EngagementCommand;
	}
	
	action def ExecuteIntercept {
		in command : EngagementCommand;
		out interceptSuccess : Boolean;
		out impactTime : TimeValue;
	}
	
	state def ThreatEngagementStates {
		entry; then monitoring;
		
		state monitoring;
		
		transition monitoring_to_tracking
			first monitoring
			accept SensorReading
			then tracking;
		
		state tracking {
			do action track : ProcessTrackData;
		}
		
		transition tracking_to_assessing
			first tracking
			if track.trackQuality > 0.7
			then assessing;
		
		transition tracking_to_monitoring
			first tracking
			if track.trackQuality <= 0.7
			then monitoring;
		
		state assessing {
			do action assess : AssessThreat;
		}
		
		transition assessing_to_engaging
			first assessing
			if assess.isHostile and assess.threatLevel.severity >= 7
			then engaging;
		
		transition assessing_to_monitoring
			first assessing
			if not assess.isHostile or assess.threatLevel.severity < 7
			then monitoring;
		
		state engaging {
			do action engage : IssueEngagementCommand;
			do action intercept : ExecuteIntercept;
		}
		
		transition engaging_to_monitoring
			first engaging
			if intercept.interceptSuccess
			then monitoring;
		
		transition engaging_to_engaging
			first engaging
			if not intercept.interceptSuccess
			then engaging;
	}
	
	part automatedThreatSystem : AutomatedThreatSystem {
		part radarSensor : RadarSensor {
			attribute :>> scanRate = 10.0 [Hz];
			attribute :>> detectionRange = 50000.0 [m];
			attribute :>> azimuthCoverage = 360.0;
			attribute :>> elevationCoverage = 90.0;
			perform action continuousScan[*] ordered references scanEnvironment;
		}
		
		part irSensor : InfraredSensor {
			attribute :>> thermalSensitivity = 0.05;
			attribute :>> detectionRange = 30000.0 [m];
			attribute :>> fieldOfView = 120.0;
			perform action thermalScan[*] ordered references scanEnvironment;
		}
		
		part trackingProcessor : TrackingProcessor {
			attribute :>> trackingAccuracy = 0.95;
			attribute :>> maxTrackedTargets = 50;
			attribute :>> updateRate = 20.0 [Hz];
			perform action trackTargets[*] ordered references processTrackData;
		}
		
		part threatEngine : ThreatAssessmentEngine {
			attribute :>> threatThreshold = 0.8;
			attribute :>> assessmentLatency = 0.2 [s];
			attribute :>> rulesetVersion = "v3.2.1";
			perform action evaluateThreats[*] ordered references assessThreat;
		}
		
		part weaponController : WeaponController {
			attribute :>> maxEngagements = 10;
			attribute :>> safetyOverride = false;
			attribute :>> engagementRange = 40000.0 [m];
			perform action manageWeapons[*] ordered references controlWeapon;
		}
		
		part missile1 : MissileSystem {
			attribute :>> missileCount = 8;
			attribute :>> launchReady = true;
			attribute :>> interceptRange = 45000.0 [m];
			attribute :>> interceptSpeed = 1500.0 [m/s];
			perform action launchMissile[*] ordered references engageTarget;
		}
		
		part missile2 : MissileSystem {
			attribute :>> missileCount = 8;
			attribute :>> launchReady = true;
			attribute :>> interceptRange = 45000.0 [m];
			attribute :>> interceptSpeed = 1500.0 [m/s];
			perform action launchMissile[*] ordered references engageTarget;
		}
		
		connection radarToTracking connect radarSensor.sensorOutput to trackingProcessor.dataInput;
		connection irToTracking connect irSensor.sensorOutput to trackingProcessor.dataInput;
		connection trackingToThreat connect trackingProcessor.trackOutput to threatEngine.trackInput;
		connection threatToWeapon connect threatEngine.alertOutput to weaponController.alertInput;
		connection weaponToMissile1 connect weaponController.weaponOutput to missile1.commandInput;
		connection weaponToMissile2 connect weaponController.weaponOutput to missile2.commandInput;
	}
	
	action def AutomatedThreatResponse {
		first start;
		then merge continuousOperation;
		
		action scanForThreats : ScanEnvironment {
			in scanParameters;
			out detectedSignals : SensorReading[*];
		}
		then continuousOperation;
		
		then action processDetections : ProcessTrackData {
			in rawSensorData = scanForThreats.detectedSignals;
			out targetTracks : TargetTrack[*];
			out trackQuality : Real;
		}
		
		then decide trackQualityCheck;
			if processDetections.trackQuality > 0.7 then assessThreats;
			if processDetections.trackQuality <= 0.7 then continuousOperation;
		
		action assessThreats : AssessThreat {
			in targetTrack = processDetections.targetTracks->first();
			out threatLevel : ThreatLevel;
			out isHostile : Boolean;
		}
		
		then decide threatDecision;
			if assessThreats.isHostile and assessThreats.threatLevel.severity >= 7 then generateAlert;
			if assessThreats.isHostile and assessThreats.threatLevel.severity < 7 then logThreat;
			if not assessThreats.isHostile then continuousOperation;
		
		action generateAlert : GenerateThreatAlert {
			in assessment = assessThreats.threatLevel;
			in track = processDetections.targetTracks->first();
			out alert : ThreatAlert;
		}
		
		then action determineResponse : DetermineEngagement {
			in alert = generateAlert.alert;
			out shouldEngage : Boolean;
			out engagementPriority : Integer;
		}
		
		then decide engagementDecision;
			if determineResponse.shouldEngage then issueCommand;
			if not determineResponse.shouldEngage then continuousOperation;
		
		action issueCommand : IssueEngagementCommand {
			in alert = generateAlert.alert;
			out command : EngagementCommand;
		}
		
		then action executeIntercept : ExecuteIntercept {
			in command = issueCommand.command;
			out interceptSuccess : Boolean;
			out impactTime : TimeValue;
		}
		
		then merge postEngagement;
		
		action logThreat {
			in level = assessThreats.threatLevel;
		}
		then continuousOperation;
		
		action postEngagement;
		then decide postEngagementCheck;
			if executeIntercept.interceptSuccess then continuousOperation;
			if not executeIntercept.interceptSuccess then generateAlert;
	}
	
	requirement def SystemPerformanceRequirement {
		doc /* The system shall meet specified performance criteria for threat detection and engagement. */
		subject automatedThreatSystem;
	}
	
	requirement def DetectionRequirement {
		doc /* The system shall detect and track threats with high accuracy and minimal latency. */
		subject automatedThreatSystem;
		
		require constraint detectionRange {
			doc /* System shall detect threats at ranges exceeding 50 kilometers. */
		}
		
		require constraint trackingAccuracy {
			doc /* Tracking accuracy shall exceed 95 percent. */
		}
	}
	
	requirement def EngagementRequirement {
		doc /* The system shall engage confirmed threats with appropriate weapons. */
		subject automatedThreatSystem;
		
		require constraint responseTime {
			doc /* Time from detection to engagement shall not exceed 5 seconds. */
		}
		
		require constraint interceptProbability {
			doc /* Probability of successful intercept shall exceed 90 percent. */
		}
	}
	
	requirement <'ATS-R-001'> primaryMissionRequirement : SystemPerformanceRequirement {
		doc /* 
			The Automated Threat System shall continuously monitor the protected airspace,
			automatically detect and track incoming threats using multiple sensor modalities,
			assess threat levels in real-time, and autonomously engage confirmed hostile
			targets with appropriate countermeasures to neutralize threats before they can
			reach protected assets.
		*/
		
		assume constraint operationalEnvironment {
			doc /* System operates in controlled airspace with defined rules of engagement. */
		}
		
		require constraint continuousOperation {
			doc /* System shall maintain 24/7 operational capability with 99.9 percent uptime. */
		}
		
		require constraint multiTargetCapability {
			doc /* System shall simultaneously track and engage up to 50 targets. */
		}
		
		require constraint safetyCompliance {
			doc /* System shall include fail-safe mechanisms to prevent unauthorized engagements. */
		}
	}
	
	requirement <'ATS-R-002'> detectionRequirement : DetectionRequirement;
	requirement <'ATS-R-003'> engagementRequirement : EngagementRequirement;
}

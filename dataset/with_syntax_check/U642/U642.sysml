package 'Curb Feeler System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	
	attribute def ContactState {
		attribute isContacting : Boolean;
		attribute contactForce : ForceValue;
		attribute contactTimestamp : TimeValue;
	}
	
	attribute def ProximityData {
		attribute lateralDistance : LengthValue;
		attribute isWithinThreshold : Boolean;
		attribute detectionConfidence : Real;
	}
	
	attribute def AlertCommand {
		attribute alertActive : Boolean;
		attribute alertIntensity : Real;
		attribute alertType : String;
	}
	
	item def FeelerRod {
		attribute rodLength : LengthValue;
		attribute rodDiameter : LengthValue;
		attribute material : String;
		attribute flexibilityCoefficient : Real;
	}
	
	item def ContactSensor {
		attribute sensitivityThreshold : ForceValue;
		attribute responseTime : TimeValue;
		attribute mountingAngle : Real;
	}
	
	item def AudibleAlertDevice {
		attribute soundFrequency : Real;
		attribute volumeLevel : Real;
		attribute powerConsumption : PowerValue;
	}
	
	port def ContactInputPort {
		in contactData : ContactState;
	}
	
	port def ProximityOutputPort {
		out proximityInfo : ProximityData;
	}
	
	port def AlertOutputPort {
		out alertCmd : AlertCommand;
	}
	
	port def AlertInputPort {
		in alertCmd : AlertCommand;
	}
	
	part def CurbFeelerAssembly {
		attribute extensionDistance : LengthValue;
		attribute detectionThreshold : LengthValue;
		
		part feelerRod : FeelerRod {
			attribute :>> rodLength = 200.0 [SI::mm];
			attribute :>> rodDiameter = 12.0 [SI::mm];
			attribute :>> material = "spring steel";
			attribute :>> flexibilityCoefficient = 0.85;
		}
		
		part contactSensor : ContactSensor {
			attribute :>> sensitivityThreshold = 3.0 [SI::N];
			attribute :>> responseTime = 50.0 [SI::s];
			attribute :>> mountingAngle = 45.0;
		}
		
		port contactInput : ContactInputPort;
		port proximityOutput : ProximityOutputPort;
		
		perform action sensing : MonitorContact {
			in rodLength = feelerRod.rodLength;
			in threshold = detectionThreshold;
			out proximityData;
		}
	}
	
	part def AlertController {
		attribute alertDelayTime : TimeValue;
		attribute minimumAlertDuration : TimeValue;
		
		port proximityInput : ContactInputPort;
		port alertOutput : AlertOutputPort;
		
		perform action control : ProcessProximityAndAlert {
			in proximityData;
			in delayTime = alertDelayTime;
			out alertCommand;
		}
	}
	
	part def DriverAlertInterface {
		part audibleDevice : AudibleAlertDevice {
			attribute :>> soundFrequency = 2000.0;
			attribute :>> volumeLevel = 80.0;
			attribute :>> powerConsumption = 5.0 [SI::W];
		}
		
		port alertInput : AlertInputPort;
		
		perform action notify : ActivateAlert {
			in alertCmd;
		}
	}
	
	part def Vehicle {
		attribute vehicleWidth : LengthValue;
		attribute operatingSpeed : SpeedValue;
		
		part leftCurbFeeler : CurbFeelerAssembly {
			attribute :>> extensionDistance = 200.0 [SI::mm];
			attribute :>> detectionThreshold = 50.0 [SI::mm];
		}
		
		part rightCurbFeeler : CurbFeelerAssembly {
			attribute :>> extensionDistance = 200.0 [SI::mm];
			attribute :>> detectionThreshold = 50.0 [SI::mm];
		}
		
		part leftAlertController : AlertController {
			attribute :>> alertDelayTime = 100.0 [SI::s];
			attribute :>> minimumAlertDuration = 500.0 [SI::s];
		}
		
		part rightAlertController : AlertController {
			attribute :>> alertDelayTime = 100.0 [SI::s];
			attribute :>> minimumAlertDuration = 500.0 [SI::s];
		}
		
		part driverInterface : DriverAlertInterface;
		
		connect leftCurbFeeler.proximityOutput to leftAlertController.proximityInput;
		connect rightCurbFeeler.proximityOutput to rightAlertController.proximityInput;
		connect leftAlertController.alertOutput to driverInterface.alertInput;
		connect rightAlertController.alertOutput to driverInterface.alertInput;
	}
	
	action def MonitorContact {
		in rodLength : LengthValue;
		in threshold : LengthValue;
		out proximityData : ProximityData;
		
		first start;
		then merge continuousMonitoring;
		
		then action detectContact : DetectPhysicalContact {
			in extensionLength = rodLength;
			out contactDetected : Boolean;
			out contactForce : ForceValue;
		}
		
		then action calculateProximity : CalculateDistance {
			in contactForce = detectContact.contactForce;
			in contactDetected = detectContact.contactDetected;
			in rodLength = rodLength;
			out distance : LengthValue;
		}
		
		then action evaluateThreshold : EvaluateProximityThreshold {
			in distance = calculateProximity.distance;
			in threshold = threshold;
			out withinThreshold : Boolean;
			out confidence : Real;
		}
		
		then assign proximityData.lateralDistance := calculateProximity.distance;
		then assign proximityData.isWithinThreshold := evaluateThreshold.withinThreshold;
		then assign proximityData.detectionConfidence := evaluateThreshold.confidence;
		then continuousMonitoring;
	}
	
	action def DetectPhysicalContact {
		in extensionLength : LengthValue;
		out contactDetected : Boolean;
		out contactForce : ForceValue;
	}
	
	action def CalculateDistance {
		in contactForce : ForceValue;
		in contactDetected : Boolean;
		in rodLength : LengthValue;
		out distance : LengthValue;
	}
	
	action def EvaluateProximityThreshold {
		in distance : LengthValue;
		in threshold : LengthValue;
		out withinThreshold : Boolean;
		out confidence : Real;
		
		first start;
		then decide;
			if distance <= threshold then setWithinThreshold;
			if distance > threshold then setOutsideThreshold;
		
		action setWithinThreshold {
			assign withinThreshold := true;
			assign confidence := 0.95;
		}
		
		action setOutsideThreshold {
			assign withinThreshold := false;
			assign confidence := 0.90;
		}
		
		then done;
	}
	
	action def ProcessProximityAndAlert {
		in proximityData : ProximityData;
		in delayTime : TimeValue;
		out alertCommand : AlertCommand;
		
		first start;
		then decide;
			if proximityData.isWithinThreshold then generateAlert;
			if not proximityData.isWithinThreshold then suppressAlert;
		
		action generateAlert {
			assign alertCommand.alertActive := true;
			assign alertCommand.alertIntensity := 1.0;
			assign alertCommand.alertType := "proximity warning";
		}
		
		action suppressAlert {
			assign alertCommand.alertActive := false;
			assign alertCommand.alertIntensity := 0.0;
			assign alertCommand.alertType := "none";
		}
		
		then done;
	}
	
	action def ActivateAlert {
		in alertCmd : AlertCommand;
		
		first start;
		then decide;
			if alertCmd.alertActive then soundAlert;
			if not alertCmd.alertActive then silenceAlert;
		
		action soundAlert;
		action silenceAlert;
		then done;
	}
	
	state def CurbFeelerOperationalStates {
		entry; then inactive;
		
		state inactive;
		
		transition inactive_to_monitoring
			first inactive
			then monitoring;
		
		state monitoring;
		
		transition monitoring_to_proximityDetected
			first monitoring
			then proximityDetected;
		
		state proximityDetected;
		
		transition proximityDetected_to_monitoring
			first proximityDetected
			then monitoring;
		
		transition monitoring_to_inactive
			first monitoring
			then inactive;
	}
	
	part vehicle : Vehicle {
		attribute :>> vehicleWidth = 1850.0 [SI::mm];
		attribute :>> operatingSpeed;
		
		perform action leftFeelerBehavior : MonitorContact {
			in rodLength = leftCurbFeeler.feelerRod.rodLength;
			in threshold = leftCurbFeeler.detectionThreshold;
			out proximityData;
		}
		
		perform action rightFeelerBehavior : MonitorContact {
			in rodLength = rightCurbFeeler.feelerRod.rodLength;
			in threshold = rightCurbFeeler.detectionThreshold;
			out proximityData;
		}
	}
	
	requirement def ProximityDetectionRequirement {
		doc /* The curb feeler system shall detect obstacles within the configured 
		       extension distance and provide timely alerts to prevent vehicle damage. */
		
		subject feelerAssembly : CurbFeelerAssembly;
		
		require constraint {
			feelerAssembly.extensionDistance >= 150.0 [SI::mm] and
			feelerAssembly.detectionThreshold <= 100.0 [SI::mm]
		}
	}
	
	requirement def AlertTimingRequirement {
		doc /* The alert controller shall process proximity data and issue alerts 
		       within the specified delay time to ensure driver awareness. */
		
		subject controller : AlertController;
		
		require constraint {
			controller.alertDelayTime <= 150.0 [SI::s] and
			controller.minimumAlertDuration >= 300.0 [SI::s]
		}
	}
	
	requirement def SystemOperationalRequirement {
		doc /* The curb feeler system shall operate reliably during low-speed 
		       maneuvering and parking operations. */
		
		subject vehicle : Vehicle;
		
		require constraint {
			vehicle.operatingSpeed <= 20.0
		}
	}
	
	requirement <'CFR-PRIMARY'> primaryFunctionRequirement {
		doc /* The curb feeler system shall provide tactile obstacle detection to assist 
		       the driver in avoiding curb contact during parking and low-speed maneuvering. 
		       The system uses spring-mounted feeler rods that extend beyond the vehicle body 
		       to make physical contact with curbs or obstacles before the wheels or body panels, 
		       triggering an immediate audible alert to the driver. This prevents wheel damage, 
		       tire scuffing, and body panel scratches by providing advance warning of proximity 
		       to obstacles that may not be visible to the driver. */
		
		assume constraint vehicleInParkingMode {
			doc /* Vehicle is operating at parking speeds with curb feeler system activated. */
		}
		
		require proximityDetectionReq : ProximityDetectionRequirement;
		require alertTimingReq : AlertTimingRequirement;
		require systemOperationReq : SystemOperationalRequirement;
	}
}

package 'Automated Security System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def 'Arm Command';
	attribute def 'Disarm Command';
	attribute def 'Sensor Trigger';
	attribute def 'Video Frame';
	attribute def 'Alert Notification' {
		attribute recipient : String;
		attribute details : String;
	}
	attribute def 'Authority Alert' {
		attribute jurisdiction : String;
		attribute details : String;
	}
	attribute def 'Siren Activate';
	attribute def 'Lock Engage';
	attribute def 'Record Start';

	item def 'Threat Assessment' {
		attribute severity : Integer;
		attribute confidence : Real;
	}

	action def 'Assess Threat' {
		out assessment : 'Threat Assessment';
	}
	action def 'Log Incident';
	action def 'Record Video';
	action def 'Sound Siren';
	action def 'Engage Locks';
	action def 'Notify Recipients';
	action def 'Notify Authorities';

	action def 'Minor Response' {
		action 'log incident' : 'Log Incident';
		action 'record video' : 'Record Video';
	}
	action def 'Serious Response' {
		action 'sound siren' : 'Sound Siren';
		action 'notify recipients' : 'Notify Recipients';
		action 'record video' : 'Record Video';
	}
	action def 'Critical Response' {
		action 'sound siren' : 'Sound Siren';
		action 'engage locks' : 'Engage Locks';
		action 'record video' : 'Record Video';
		action 'notify authorities' : 'Notify Authorities';
	}

	action 'assess threat' : 'Assess Threat';
	action 'minor response' : 'Minor Response';
	action 'serious response' : 'Serious Response';
	action 'critical response' : 'Critical Response';

	part def 'Motion Detector' {
		attribute sensorId : String;
		attribute location : String;
		port triggerOut : 'Sensor Trigger';
	}

	part def 'Contact Sensor' {
		attribute sensorId : String;
		attribute location : String;
		port triggerOut : 'Sensor Trigger';
	}

	part def Camera {
		attribute cameraId : String;
		attribute location : String;
		port videoOut : 'Video Frame';
	}

	part def 'Control Panel' {
		attribute authorizedUser : Boolean;
		port armOut : 'Arm Command';
		port disarmOut : 'Disarm Command';
	}

	part def Siren {
		attribute sirenId : String;
		port commandIn : 'Siren Activate';
	}

	part def 'Electronic Lock' {
		attribute lockId : String;
		port commandIn : 'Lock Engage';
	}

	part def 'Video Recorder' {
		port commandIn : 'Record Start';
	}

	part def 'Notification Service' {
		port alertIn : 'Alert Notification';
		port authorityIn : 'Authority Alert';
	}

	part def 'Central Controller' {
		port sensorIn : 'Sensor Trigger';
		port videoIn : 'Video Frame';
		port armIn : 'Arm Command';
		port disarmIn : 'Disarm Command';
		port sirenOut : 'Siren Activate';
		port lockOut : 'Lock Engage';
		port recordOut : 'Record Start';
		port alertOut : 'Alert Notification';
		port authorityOut : 'Authority Alert';

		attribute currentAssessment : 'Threat Assessment';
		attribute maxResponseTime : DurationValue = 2 [s];
	}

	part def 'Security System' {
		part controller : 'Central Controller';
		part 'front motion detector' : 'Motion Detector';
		part 'rear motion detector' : 'Motion Detector';
		part 'front door sensor' : 'Contact Sensor';
		part 'rear door sensor' : 'Contact Sensor';
		part 'front window sensor' : 'Contact Sensor';
		part 'rear window sensor' : 'Contact Sensor';
		part 'front camera' : Camera;
		part 'rear camera' : Camera;
		part 'interior camera' : Camera;
		part 'control panel' : 'Control Panel';
		part 'interior siren' : Siren;
		part 'exterior siren' : Siren;
		part 'front lock' : 'Electronic Lock';
		part 'rear lock' : 'Electronic Lock';
		part recorder : 'Video Recorder';
		part 'notification service' : 'Notification Service';

		connect 'front motion detector'.triggerOut to controller.sensorIn;
		connect 'rear motion detector'.triggerOut to controller.sensorIn;
		connect 'front door sensor'.triggerOut to controller.sensorIn;
		connect 'rear door sensor'.triggerOut to controller.sensorIn;
		connect 'front window sensor'.triggerOut to controller.sensorIn;
		connect 'rear window sensor'.triggerOut to controller.sensorIn;
		connect 'front camera'.videoOut to controller.videoIn;
		connect 'rear camera'.videoOut to controller.videoIn;
		connect 'interior camera'.videoOut to controller.videoIn;
		connect 'control panel'.armOut to controller.armIn;
		connect 'control panel'.disarmOut to controller.disarmIn;
		connect controller.sirenOut to 'interior siren'.commandIn;
		connect controller.sirenOut to 'exterior siren'.commandIn;
		connect controller.lockOut to 'front lock'.commandIn;
		connect controller.lockOut to 'rear lock'.commandIn;
		connect controller.recordOut to recorder.commandIn;
		connect controller.alertOut to 'notification service'.alertIn;
		connect controller.authorityOut to 'notification service'.authorityIn;
	}

	state 'controller states' {
		in controller : 'Central Controller';

		entry; then disarmed;

		state disarmed;
		accept 'Arm Command'
			then armed;

		state armed {
			entry; then monitoring;

			state monitoring;
			accept 'Sensor Trigger'
				then alert;

			state alert {
				entry 'assess threat';
				accept when 'assess threat'.assessment.severity == 1
					do 'minor response'
					then monitoring;
				accept when 'assess threat'.assessment.severity == 2
					do 'serious response'
					then monitoring;
				accept when 'assess threat'.assessment.severity == 3
					do 'critical response'
					then monitoring;
			}
		}

		accept 'Disarm Command'
			then disarmed;
	}

	part 'main security system' : 'Security System' {
		exhibit 'controller states' {
			in controller = controller;
		}
	}

	requirement def 'Security System Requirement' {
		doc /* The system must provide comprehensive protection through surveillance, intrusion detection, and a graduated, automated response to threats. */
		subject securitySystem : 'Security System';
	}

	requirement 'rapid response' :> 'Security System Requirement' {
		doc /* The system shall detect, analyze, and respond to a threat within 2 seconds. */
		subject securitySystem : 'Security System';
		attribute maxResponseTime : DurationValue = 2 [s];
	}

	requirement 'graduated response' :> 'Security System Requirement' {
		doc /* The system must tailor its response to the assessed threat level: minor, serious, or critical. */
		subject securitySystem : 'Security System';
	}
}

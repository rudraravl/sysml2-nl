package 'Curb Feeler System' {
	private import ScalarValues::*;

	attribute def Length :> Real;
	attribute def Force :> Real;
	attribute def Frequency :> Real;

	package Definitions {
		attribute def ContactSignal;
		attribute def ContactReleased;
		attribute def AlertCommand;
		attribute def ManeuveringSignal;
		attribute def ParkedSignal;
		attribute def ThresholdExceeded;

		part def SpringSteelRod {
			attribute length : Length = 200;
		}

		part def ContactSensor {
			out contactDetected : ContactSignal;
			out contactReleased : ContactReleased;
			attribute triggerForce : Force;
		}

		part def AlertController {
			in contactInput : ContactSignal;
			in releaseInput : ContactReleased;
			out alertOutput : AlertCommand;
			attribute safetyThreshold : Length = 100;
			exhibit state controllerStates : ControllerStates;
		}

		part def DriverAlertInterface {
			in alertInput : AlertCommand;
			attribute toneFrequency : Frequency = 2000;
		}

		part def CurbFeelerAssembly {
			part rod : SpringSteelRod;
			part sensor : ContactSensor;
			part controller : AlertController;
			connect sensor.contactDetected to controller.contactInput;
			connect sensor.contactReleased to controller.releaseInput;
		}

		part def Vehicle {
			part leftAssembly : CurbFeelerAssembly;
			part rightAssembly : CurbFeelerAssembly;
			part alertInterface : DriverAlertInterface;
			connect leftAssembly.controller.alertOutput to alertInterface.alertInput;
			connect rightAssembly.controller.alertOutput to alertInterface.alertInput;
			exhibit state systemStates : SystemStates;
		}

		state def SystemStates;
		state def ControllerStates;

		action def DetectContact {
			out contact : ContactSignal;
		}
		action def CalculateProximity {
			out proximity : Length;
		}
		action def EvaluateThreshold {
			out isTooClose : Boolean;
		}
		action def ActivateAlarm {
			in frequency : Frequency;
		}
	}

	public import Definitions::*;

	package Requirements {
		private import Definitions::*;

		requirement def 'Obstacle Detection' {
			text = "The system shall detect contact with curbs and low obstacles via the flexible spring-steel rod and force-sensitive contact sensor.";
		}
		requirement def 'Driver Alert' {
			text = "The system shall alert the driver with an audible 2000 Hz tone when an obstacle is within the safety threshold.";
		}
		requirement def 'Damage Prevention' {
			text = "The system shall provide tactile physical warning through the rod before the wheels or body panels contact the obstacle, preventing wheel scuffs, tire damage, and scratches.";
		}
	}

	package Usages {
		private import Definitions::*;
		private import Requirements::*;

		action detectContact : DetectContact;
		action calculateProximity : CalculateProximity;
		action evaluateThreshold : EvaluateThreshold;
		action activateAlarm : ActivateAlarm;

		state systemStates : SystemStates {
			entry; then inactive;
			state inactive;
			accept ManeuveringSignal
				then monitoring;
			state monitoring;
			accept ParkedSignal
				then inactive;
		}

		state controllerStates : ControllerStates {
			entry; then idle;
			state idle;
			accept ContactSignal
				do calculateProximity
				then processing;
			state processing;
			accept ThresholdExceeded
				then alerting;
			state alerting;
			accept ContactReleased
				then idle;
		}

		part vehicle : Vehicle;

		requirement obstacleDetection : 'Obstacle Detection';
		requirement driverAlert : 'Driver Alert';
		requirement damagePrevention : 'Damage Prevention';

		satisfy obstacleDetection by vehicle;
		satisfy driverAlert by vehicle;
		satisfy damagePrevention by vehicle;
	}
}

package 'Michelangelo Hand System' {
	private import ScalarValues::*;

	value type EMGAmplitude :> Real;
	value type GripForce :> Real;
	value type BatteryVoltage :> Real;
	value type BatteryCharge :> Real;
	value type MotorCurrent :> Real;
	value type EMGThreshold :> Real;

	item def EMGSignal {
		attribute amplitude : EMGAmplitude;
	}
	item def ForceReading {
		attribute measuredForce : GripForce;
	}
	item def GripCommand {
		attribute gripType : String;
	}
	item def PowerFlow {
		attribute voltage : BatteryVoltage;
	}

	attribute def CalibrateComplete;
	attribute def GraspComplete;
	attribute def ReleaseCommand;
	attribute def ReleaseComplete;
	attribute def PowerGripSignal;
	attribute def PrecisionGripSignal;
	attribute def LateralGripSignal;
	attribute def TripodGripSignal;
	attribute def OpenHandSignal;
	attribute def OverForceAlert;

	action def CalibrateSensors;
	action def ExecuteGrip;
	action def ExecuteRelease;
	action def AdjustGrip;
	action def SenseEMG {
		out flexorAmplitude : EMGAmplitude;
		out extensorAmplitude : EMGAmplitude;
	}
	action def SenseGripForce {
		out totalForce : GripForce;
	}

	state def HandStates;

	part def Battery {
		attribute capacity : BatteryCharge = 2000;
		attribute currentCharge : BatteryCharge;
		attribute nominalVoltage : BatteryVoltage = 7.4;
		port powerOut {
			out power : PowerFlow;
		}
	}

	part def EMGSensor {
		attribute sensorId : String;
		port emgOut {
			out emg : EMGSignal;
		}
		port powerIn {
			in power : PowerFlow;
		}
	}

	part def ForceSensor {
		attribute maxRange : GripForce = 50.0;
		port forceOut {
			out force : ForceReading;
		}
	}

	part def DCMotor {
		attribute ratedCurrent : MotorCurrent = 500;
		attribute stallTorque : GripForce = 5.0;
	}

	part def Tendon {
		attribute maxTension : GripForce = 60.0;
	}

	part def ControllerBoard {
		port emgIn1 {
			in emg : EMGSignal;
		}
		port emgIn2 {
			in emg : EMGSignal;
		}
		port gripCommandOut {
			out command : GripCommand;
		}
		port forceIn {
			in force : ForceReading;
		}
		port powerIn {
			in power : PowerFlow;
		}
		attribute powerGripThreshold : EMGThreshold = 0.8;
		attribute precisionGripThreshold : EMGThreshold = 0.5;
		attribute lateralGripThreshold : EMGThreshold = 0.6;
		attribute tripodGripThreshold : EMGThreshold = 0.4;
		attribute maxSafeGripForce : GripForce = 30.0;
		attribute targetGripForce : GripForce = 15.0;
	}

	part def Finger {
		attribute fingerName : String;
		part motor : DCMotor;
		part tendon : Tendon;
		part forceSensor : ForceSensor;
		port commandIn {
			in command : GripCommand;
		}
		port forceOutPort {
			out forceReading : ForceReading;
		}
		port powerIn {
			in power : PowerFlow;
		}
		flow internalForceFlow of ForceReading
			from forceSensor.forceOut.force to forceOutPort.forceReading;
	}

	part def MichelangeloHand {
		part controllerBoard : ControllerBoard;
		part flexorSensor : EMGSensor {
			:>> sensorId = "flexor";
		}
		part extensorSensor : EMGSensor {
			:>> sensorId = "extensor";
		}
		part thumb : Finger {
			:>> fingerName = "thumb";
		}
		part indexFinger : Finger {
			:>> fingerName = "index";
		}
		part middleFinger : Finger {
			:>> fingerName = "middle";
		}
		part ringFinger : Finger {
			:>> fingerName = "ring";
		}
		part pinkyFinger : Finger {
			:>> fingerName = "pinky";
		}
		part battery : Battery;

		action calibrateSensors : CalibrateSensors;
		action executeGrip : ExecuteGrip;
		action executeRelease : ExecuteRelease;
		action adjustGrip : AdjustGrip;
		action senseEMG : SenseEMG;
		action senseGripForce : SenseGripForce;

		flow flexorEMGFlow of EMGSignal
			from flexorSensor.emgOut.emg to controllerBoard.emgIn1.emg;
		flow extensorEMGFlow of EMGSignal
			from extensorSensor.emgOut.emg to controllerBoard.emgIn2.emg;

		flow thumbCommandFlow of GripCommand
			from controllerBoard.gripCommandOut.command to thumb.commandIn.command;
		flow indexCommandFlow of GripCommand
			from controllerBoard.gripCommandOut.command to indexFinger.commandIn.command;
		flow middleCommandFlow of GripCommand
			from controllerBoard.gripCommandOut.command to middleFinger.commandIn.command;
		flow ringCommandFlow of GripCommand
			from controllerBoard.gripCommandOut.command to ringFinger.commandIn.command;
		flow pinkyCommandFlow of GripCommand
			from controllerBoard.gripCommandOut.command to pinkyFinger.commandIn.command;

		flow thumbForceFlow of ForceReading
			from thumb.forceOutPort.forceReading to controllerBoard.forceIn.force;
		flow indexForceFlow of ForceReading
			from indexFinger.forceOutPort.forceReading to controllerBoard.forceIn.force;
		flow middleForceFlow of ForceReading
			from middleFinger.forceOutPort.forceReading to controllerBoard.forceIn.force;
		flow ringForceFlow of ForceReading
			from ringFinger.forceOutPort.forceReading to controllerBoard.forceIn.force;
		flow pinkyForceFlow of ForceReading
			from pinkyFinger.forceOutPort.forceReading to controllerBoard.forceIn.force;

		flow controllerPowerFlow of PowerFlow
			from battery.powerOut.power to controllerBoard.powerIn.power;
		flow flexorSensorPowerFlow of PowerFlow
			from battery.powerOut.power to flexorSensor.powerIn.power;
		flow extensorSensorPowerFlow of PowerFlow
			from battery.powerOut.power to extensorSensor.powerIn.power;
		flow thumbPowerFlow of PowerFlow
			from battery.powerOut.power to thumb.powerIn.power;
		flow indexPowerFlow of PowerFlow
			from battery.powerOut.power to indexFinger.powerIn.power;
		flow middlePowerFlow of PowerFlow
			from battery.powerOut.power to middleFinger.powerIn.power;
		flow ringPowerFlow of PowerFlow
			from battery.powerOut.power to ringFinger.powerIn.power;
		flow pinkyPowerFlow of PowerFlow
			from battery.powerOut.power to pinkyFinger.powerIn.power;

		exhibit state handStates : HandStates {
			entry; then calibrating;

			state calibrating {
				entry calibrateSensors;
			}
			accept CalibrateComplete
				then ready;

			state ready {
				do senseEMG { out flexorAmplitude; out extensorAmplitude; }
			}
			accept when senseEMG.flexorAmplitude >= controllerBoard.powerGripThreshold
				do send new PowerGripSignal() to controllerBoard
				then grasping;
			accept when senseEMG.flexorAmplitude >= controllerBoard.precisionGripThreshold
				and senseEMG.flexorAmplitude < controllerBoard.powerGripThreshold
				do send new PrecisionGripSignal() to controllerBoard
				then grasping;
			accept when senseEMG.flexorAmplitude >= controllerBoard.lateralGripThreshold
				and senseEMG.flexorAmplitude < controllerBoard.precisionGripThreshold
				do send new LateralGripSignal() to controllerBoard
				then grasping;
			accept when senseEMG.flexorAmplitude >= controllerBoard.tripodGripThreshold
				and senseEMG.flexorAmplitude < controllerBoard.lateralGripThreshold
				do send new TripodGripSignal() to controllerBoard
				then grasping;
			accept when senseEMG.extensorAmplitude >= controllerBoard.tripodGripThreshold
				do send new OpenHandSignal() to controllerBoard
				then releasing;

			state grasping {
				entry executeGrip;
				do senseGripForce { out totalForce; }
			}
			accept when senseGripForce.totalForce > 0.0
				then holding;

			state holding {
				do senseGripForce { out totalForce; }
				do adjustGrip;
			}
			accept when senseGripForce.totalForce > controllerBoard.maxSafeGripForce
				do send new OverForceAlert() to controllerBoard
				then releasing;
			accept ReleaseCommand
				then releasing;

			state releasing {
				entry executeRelease;
			}
			accept ReleaseComplete
				then ready;
		}
	}

	part michelangeloHand : MichelangeloHand;

	requirement def HandProsthesisRequirement {
		doc /* The Michelangelo Hand shall replace a missing hand and provide the user with the ability to grasp and manipulate objects in a natural and intuitive way. */;
	}

	requirement def DualEMGSensingRequirement {
		doc /* The system shall use two EMG sensors placed over different muscles (flexor and extensor) to detect myoelectric signals from the user's residual limb. */;
	}

	requirement def GripVarietyRequirement {
		doc /* The system shall support at least five pre-defined grip patterns: power, precision, lateral, tripod, and open. */;
	}

	requirement def IndividualFingerActuationRequirement {
		doc /* Each of the five fingers (thumb, index, middle, ring, pinky) shall be individually actuated by its own DC motor driving a tendon for flexion and extension. */;
	}

	requirement def ForceFeedbackRequirement {
		doc /* Each finger shall be equipped with a force sensor that provides grip force feedback to the controller board for closed-loop adjustment, ensuring a firm yet safe grip. */;
	}

	requirement def BatteryLifeRequirement {
		doc /* The rechargeable internal battery shall provide sufficient power for a full day of typical use. */;
	}

	requirement def GripSafetyRequirement {
		doc /* The controller shall automatically reduce grip force or release the object when the measured force exceeds the maximum safe threshold to prevent damage to delicate items. */;
	}

	requirement def CalibrationRequirement {
		doc /* The system shall perform an initial calibration sequence before becoming active and ready to accept grip commands. */;
	}

	requirement def OperationalStateMachineRequirement {
		doc /* The system shall cycle through operational states including calibrating, ready, grasping, holding, and releasing an object. */;
	}
}

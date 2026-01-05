package 'Michelangelo Hand System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def GripForce :> ISQ::ForceValue;
	attribute def FingerPosition :> ISQ::LengthValue;
	attribute def MotorVoltage :> ISQ::ElectricPotentialDifferenceValue;
	attribute def SensorVoltage :> ISQ::ElectricPotentialDifferenceValue;
	attribute def MotorTorque :> ISQ::TorqueValue;
	attribute def BatteryCapacity :> ISQ::ElectricChargeValue;
	
	enum def GripMode {
		enum powerGrip;
		enum precisionGrip;
		enum lateralGrip;
		enum tripodGrip;
		enum openHand;
	}
	
	item def EMGSignal {
		attribute amplitude : SensorVoltage;
		attribute frequency : FrequencyValue;
	}
	
	item def MotorCommand {
		attribute targetVoltage : MotorVoltage;
		attribute targetTorque : MotorTorque;
		attribute fingerID : Integer;
	}
	
	item def ForceFeedback {
		attribute measuredForce : GripForce;
		attribute fingerID : Integer;
	}
	
	port def EMGInputPort {
		in item emgSignal : EMGSignal;
	}
	
	port def MotorControlPort {
		out item motorCmd : MotorCommand;
		in item forceFeedback : ForceFeedback;
	}
	
	port def PowerPort {
		in attribute voltage : ElectricPotentialDifferenceValue;
		in attribute current : ElectricCurrentValue;
	}
	
	port def MechanicalPort {
		out attribute force : ForceValue;
		in attribute displacement : LengthValue;
	}
	
	part def ForceSensor {
		port mechanicalInput : MechanicalPort;
		out attribute sensorOutput : SensorVoltage;
		
		action measureForce {
			in appliedForce : ForceValue;
			out voltage : SensorVoltage;
		}
	}
	
	part def DCMotor {
		port powerInput : PowerPort;
		port mechanicalOutput : MechanicalPort;
		
		attribute maxTorque : MotorTorque;
		attribute currentTorque : MotorTorque;
		
		action actuate {
			in commandVoltage : MotorVoltage;
			out outputTorque : MotorTorque;
		}
	}
	
	part def Tendon {
		attribute length : LengthValue;
		attribute tension : ForceValue;
	}
	
	part def Finger {
		attribute fingerIndex : Integer;
		attribute currentPosition : FingerPosition;
		attribute maxForce : GripForce;
		
		part motor : DCMotor {
			:>> maxTorque = 0.5[N*m];
		}
		part sensor : ForceSensor;
		part tendon : Tendon;
		
		port mechanicalInterface : MechanicalPort;
		
		action flex {
			in targetPosition : FingerPosition;
			out actualPosition : FingerPosition;
			
			first start;
			then action applyMotorTorque {
				in position = targetPosition;
			}
			then action updatePosition {
				out newPosition : FingerPosition;
			}
			then assign actualPosition := updatePosition.newPosition;
			then done;
		}
		
		action extend {
			in targetPosition : FingerPosition;
			out actualPosition : FingerPosition;
		}
	}
	
	part def EMGSensor {
		port emgOutput : EMGInputPort;
		attribute position : String;
		
		action captureSignal {
			out signal : EMGSignal;
		}
	}
	
	part def Battery {
		port powerOutput : PowerPort;
		attribute capacity : BatteryCapacity;
		attribute currentCharge : BatteryCapacity;
		attribute voltage : ElectricPotentialDifferenceValue;
	}
	
	part def ControllerBoard {
		port emgInput : EMGInputPort;
		port motorControl : MotorControlPort;
		port powerSupply : PowerPort;
		
		attribute activeGripMode : GripMode;
		
		action interpretEMG {
			in emgSignal : EMGSignal;
			out desiredGripMode : GripMode;
			out targetForce : GripForce;
			
			first start;
			then decide;
				if emgSignal.amplitude > 0.8[V] then assignPowerGrip;
				if emgSignal.amplitude > 0.5[V] and emgSignal.amplitude <= 0.8[V] then assignPrecisionGrip;
				if emgSignal.amplitude > 0.2[V] and emgSignal.amplitude <= 0.5[V] then assignLateralGrip;
				if emgSignal.amplitude <= 0.2[V] then assignOpenHand;
			
			action assignPowerGrip {
				then assign desiredGripMode := GripMode::powerGrip;
				then assign targetForce := 100[N];
			}
			action assignPrecisionGrip {
				then assign desiredGripMode := GripMode::precisionGrip;
				then assign targetForce := 30[N];
			}
			action assignLateralGrip {
				then assign desiredGripMode := GripMode::lateralGrip;
				then assign targetForce := 50[N];
			}
			action assignOpenHand {
				then assign desiredGripMode := GripMode::openHand;
				then assign targetForce := 0[N];
			}
			then done;
		}
		
		action generateMotorCommands {
			in gripMode : GripMode;
			in targetForce : GripForce;
			in feedbackForce : GripForce;
			out commands : MotorCommand[5];
		}
		
		state machine controlStateMachine {
			entry; then idle;
			
			state idle;
			transition idle_to_calibrating
				first idle
				then calibrating;
			
			state calibrating;
			transition calibrating_to_active
				first calibrating
				then active;
			
			state active;
			transition active_to_grasping
				first active
				then grasping;
			transition active_to_fault
				first active
				then fault;
			
			state grasping;
			transition grasping_to_holding
				first grasping
				then holding;
			
			state holding;
			transition holding_to_releasing
				first holding
				then releasing;
			
			state releasing;
			transition releasing_to_active
				first releasing
				then active;
			
			state fault;
			transition fault_to_calibrating
				first fault
				then calibrating;
		}
		
		action controlLoop {
			first start;
			then merge continuousControl;
			
			then action readEMG {
				out emgData : EMGSignal;
			}
			
			then action interpret : interpretEMG {
				in emgSignal = readEMG.emgData;
				out desiredGripMode;
				out targetForce;
			}
			
			then action readForceSensors {
				out currentForce : GripForce;
			}
			
			then action generateCommands : generateMotorCommands {
				in gripMode = interpret.desiredGripMode;
				in targetForce = interpret.targetForce;
				in feedbackForce = readForceSensors.currentForce;
				out commands;
			}
			
			then action sendCommands {
				in motorCommands = generateCommands.commands;
			}
			
			then decide;
				if readForceSensors.currentForce < interpret.targetForce then continuousControl;
				if readForceSensors.currentForce >= interpret.targetForce then maintainGrip;
			
			action maintainGrip;
			then continuousControl;
		}
	}
	
	part def MichelangeloHand {
		doc /* 
			The Michelangelo Hand is an advanced myoelectric prosthetic hand system 
			that interprets electromyographic signals from the user's residual limb 
			to control five individually actuated fingers with integrated force sensing,
			enabling natural grasping and manipulation of objects through multiple grip patterns.
		*/
		
		part thumb : Finger {
			:>> fingerIndex = 1;
			:>> maxForce = 120[N];
		}
		
		part indexFinger : Finger {
			:>> fingerIndex = 2;
			:>> maxForce = 100[N];
		}
		
		part middleFinger : Finger {
			:>> fingerIndex = 3;
			:>> maxForce = 100[N];
		}
		
		part ringFinger : Finger {
			:>> fingerIndex = 4;
			:>> maxForce = 80[N];
		}
		
		part pinkyFinger : Finger {
			:>> fingerIndex = 5;
			:>> maxForce = 60[N];
		}
		
		part controller : ControllerBoard;
		
		part emgSensors : EMGSensor[2] {
			item flexorSensor : EMGSensor {
				:>> position = "flexor";
			}
			item extensorSensor : EMGSensor {
				:>> position = "extensor";
			}
		}
		
		part battery : Battery {
			:>> capacity = 2000[mA*h];
			:>> voltage = 7.4[V];
		}
		
		port userInterface : EMGInputPort;
		port externalPower : PowerPort;
		
		connection emgConnection1 connect emgSensors.flexorSensor.emgOutput to controller.emgInput;
		connection emgConnection2 connect emgSensors.extensorSensor.emgOutput to controller.emgInput;
		
		connection motorConnection1 connect controller.motorControl to thumb.mechanicalInterface;
		connection motorConnection2 connect controller.motorControl to indexFinger.mechanicalInterface;
		connection motorConnection3 connect controller.motorControl to middleFinger.mechanicalInterface;
		connection motorConnection4 connect controller.motorControl to ringFinger.mechanicalInterface;
		connection motorConnection5 connect controller.motorControl to pinkyFinger.mechanicalInterface;
		
		connection powerConnection connect battery.powerOutput to controller.powerSupply;
		
		perform action executeGrasp[*] ordered;
	}
	
	action def ExecuteGrasp {
		in targetObject;
		in desiredGripMode : GripMode;
		in targetForce : GripForce;
		out graspSuccess : Boolean;
		
		first start;
		
		then action positionFingers {
			in gripMode = desiredGripMode;
			out fingerConfiguration;
		}
		
		then action closeFingers {
			in configuration = positionFingers.fingerConfiguration;
			in force = targetForce;
			out closureComplete : Boolean;
		}
		
		then action applyGripForce {
			in maxForce = targetForce;
			out appliedForce : GripForce;
		}
		
		then action monitorForce {
			in currentForce = applyGripForce.appliedForce;
			out stable : Boolean;
		}
		
		then decide;
			if monitorForce.stable then verifyGrasp;
			if not monitorForce.stable then adjustForce;
		
		action adjustForce {
			in currentForce = applyGripForce.appliedForce;
			out adjustedForce : GripForce;
		}
		then applyGripForce;
		
		action verifyGrasp {
			in force = applyGripForce.appliedForce;
			out success : Boolean;
		}
		
		then assign graspSuccess := verifyGrasp.success;
		then done;
	}
	
	part michelangeloHandSystem : MichelangeloHand {
		perform action executeGrasp : ExecuteGrasp {
			in targetObject;
			in desiredGripMode;
			in targetForce;
			out graspSuccess;
		}
		
		part :>> controller {
			perform executeGrasp.positionFingers;
			perform executeGrasp.monitorForce;
		}
		
		part :>> thumb {
			perform executeGrasp.closeFingers;
			perform executeGrasp.applyGripForce;
		}
		
		part :>> indexFinger {
			perform executeGrasp.closeFingers;
			perform executeGrasp.applyGripForce;
		}
		
		part :>> middleFinger {
			perform executeGrasp.closeFingers;
			perform executeGrasp.applyGripForce;
		}
		
		part :>> ringFinger {
			perform executeGrasp.closeFingers;
		}
		
		part :>> pinkyFinger {
			perform executeGrasp.closeFingers;
		}
	}
	
	requirement <'R1'> emgInterpretationRequirement {
		doc /* The system shall interpret electromyographic signals from the user's residual limb 
		       to determine the desired grip mode and force level. */
		
		subject michelangeloHandSystem.controller;
		
		require constraint {
			michelangeloHandSystem.controller.activeGripMode == GripMode::powerGrip or
			michelangeloHandSystem.controller.activeGripMode == GripMode::precisionGrip or
			michelangeloHandSystem.controller.activeGripMode == GripMode::lateralGrip or
			michelangeloHandSystem.controller.activeGripMode == GripMode::tripodGrip or
			michelangeloHandSystem.controller.activeGripMode == GripMode::openHand
		}
	}
	
	requirement <'R2'> individualFingerControlRequirement {
		doc /* All five fingers shall be independently controllable with individual force sensing 
		       to enable versatile object manipulation. */
		
		subject michelangeloHandSystem;
		
		require constraint {
			michelangeloHandSystem.thumb.motor.currentTorque >= 0[N*m] and
			michelangeloHandSystem.indexFinger.motor.currentTorque >= 0[N*m] and
			michelangeloHandSystem.middleFinger.motor.currentTorque >= 0[N*m] and
			michelangeloHandSystem.ringFinger.motor.currentTorque >= 0[N*m] and
			michelangeloHandSystem.pinkyFinger.motor.currentTorque >= 0[N*m]
		}
	}
	
	requirement <'R3'> forceFeedbackRequirement {
		doc /* Each finger shall provide proportional force feedback to prevent object damage 
		       and enable adaptive grasping. */
		
		subject michelangeloHandSystem;
		
		require constraint {
			michelangeloHandSystem.thumb.sensor.sensorOutput > 0[V] and
			michelangeloHandSystem.indexFinger.sensor.sensorOutput > 0[V] and
			michelangeloHandSystem.middleFinger.sensor.sensorOutput > 0[V] and
			michelangeloHandSystem.ringFinger.sensor.sensorOutput > 0[V] and
			michelangeloHandSystem.pinkyFinger.sensor.sensorOutput > 0[V]
		}
	}
	
	requirement <'R4'> responseTimeRequirement {
		doc /* The system shall respond to EMG signal changes and transition between grip modes 
		       within 300 milliseconds to provide natural user experience. */
		
		subject michelangeloHandSystem.controller;
		
		attribute maxResponseTime : TimeValue = 0.3[s];
	}
	
	requirement <'R5'> batteryLifeRequirement {
		doc /* The system shall operate for a minimum of 8 hours of continuous use 
		       on a single battery charge. */
		
		subject michelangeloHandSystem.battery;
		
		attribute minOperatingTime : TimeValue = 8[h];
		
		require constraint {
			michelangeloHandSystem.battery.currentCharge > 0[mA*h]
		}
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for the Michelangelo Hand prosthetic system 
		       ensuring natural grasping, force control, and user responsiveness. */
		
		require emgInterpretationRequirement;
		require individualFingerControlRequirement;
		require forceFeedbackRequirement;
		require responseTimeRequirement;
		require batteryLifeRequirement;
	}
}

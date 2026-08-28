package HumanoidRobotModel {

	import ScalarValues::*;
	import ScalarFunctions::*;

	// ---------- Value Types with Units ----------
	value type Mass :> Real { unit 'kg'; }
	value type Force :> Real { unit 'N'; }
	value type Distance :> Real { unit 'm'; }
	value type Angle :> Real { unit 'rad'; }
	value type AngularVelocity :> Real { unit 'rad/s'; }
	value type Torque :> Real { unit 'N*m'; }
	value type ElectricCurrent :> Real { unit 'A'; }
	value type Voltage :> Real { unit 'V'; }
	value type Energy :> Real { unit 'J'; }
	value type Power :> Real { unit 'W'; }
	value type Duration :> Real { unit 's'; }
	value type Frequency :> Real { unit 'Hz'; }
	value type SoundPressure :> Real { unit 'dB'; }

	// ---------- Item Types ----------
	item def ElectricalPower {
		attribute voltage : Voltage;
		attribute current : ElectricCurrent;
	}

	item def SensorData;
	item def ImageData :> SensorData {
		attribute width : Integer;
		attribute height : Integer;
	}
	item def RangeData :> SensorData {
		attribute distance : Distance;
	}
	item def AudioData :> SensorData {
		attribute level : SoundPressure;
	}

	item def PerceptionResult {
		attribute detectedObjects : String[0..*];
		attribute obstacleDetected : Boolean;
		attribute mapConfidence : Real;
	}

	item def UserCommand {
		attribute commandText : String;
		attribute priority : Integer;
	}

	item def Plan {
		attribute steps : String[0..*];
		attribute estimatedDuration : Duration;
		attribute involvesNavigation : Boolean;
		attribute involvesManipulation : Boolean;
	}

	item def MotorCommand {
		attribute targetAngle : Angle;
		attribute targetTorque : Torque;
		attribute targetVelocity : AngularVelocity;
	}

	// ---------- Port Definitions ----------
	port def PowerPort {
		out electricalPower : ElectricalPower;
	}

	port def SensorDataPort {
		out sensorData : SensorData;
	}

	port def PerceptionPort {
		out perceptionResult : PerceptionResult;
	}

	port def PlanPort {
		out plan : Plan;
	}

	port def CommandPort {
		out motorCommand : MotorCommand;
	}

	port def UserCommandPort {
		in userCommand : UserCommand;
	}

	// ---------- Joint ----------
	part def Joint {
		attribute name : String;
		attribute currentAngle : Angle;
		attribute targetAngle : Angle;
		attribute maxTorque : Torque;
		attribute maxVelocity : AngularVelocity;
		port powerIn : PowerPort;
		port commandIn : CommandPort;

		action updatePosition {
			in cmd : MotorCommand;
			out newAngle : Angle;
		}
	}

	// ---------- Gripper ----------
	part def Gripper {
		attribute name : String;
		attribute gripForce : Force;
		attribute maxForce : Force = 50.0 [N];
		attribute isClosed : Boolean = false;
		port powerIn : PowerPort;
		port commandIn : CommandPort;

		action grasp {
			in targetForce : Force;
			out achievedForce : Force;
		}

		action release {
			out released : Boolean;
		}
	}

	// ---------- Arm ----------
	part def Arm {
		attribute side : String;
		part shoulder : Joint {
			redefinition name = "shoulder";
			redefinition maxTorque = 80.0 [N*m];
		}
		part elbow : Joint {
			redefinition name = "elbow";
			redefinition maxTorque = 60.0 [N*m];
		}
		part wrist : Joint {
			redefinition name = "wrist";
			redefinition maxTorque = 30.0 [N*m];
		}
		part gripper : Gripper {
			redefinition name = "gripper";
		}
		port powerIn : PowerPort;
		port commandIn : CommandPort;

		connection powerToShoulder connect powerIn to shoulder.powerIn;
		connection powerToElbow connect powerIn to elbow.powerIn;
		connection powerToWrist connect powerIn to wrist.powerIn;
		connection powerToGripper connect powerIn to gripper.powerIn;

		connection cmdToShoulder connect commandIn to shoulder.commandIn;
		connection cmdToElbow connect commandIn to elbow.commandIn;
		connection cmdToWrist connect commandIn to wrist.commandIn;
		connection cmdToGripper connect commandIn to gripper.commandIn;
	}

	// ---------- Leg ----------
	part def Leg {
		attribute side : String;
		part hip : Joint {
			redefinition name = "hip";
			redefinition maxTorque = 120.0 [N*m];
		}
		part knee : Joint {
			redefinition name = "knee";
			redefinition maxTorque = 100.0 [N*m];
		}
		part ankle : Joint {
			redefinition name = "ankle";
			redefinition maxTorque = 70.0 [N*m];
		}
		port powerIn : PowerPort;
		port commandIn : CommandPort;

		connection powerToHip connect powerIn to hip.powerIn;
		connection powerToKnee connect powerIn to knee.powerIn;
		connection powerToAnkle connect powerIn to ankle.powerIn;

		connection cmdToHip connect commandIn to hip.commandIn;
		connection cmdToKnee connect commandIn to knee.commandIn;
		connection cmdToAnkle connect commandIn to ankle.commandIn;

		action maintainBalance {
			out stable : Boolean;
		}
	}

	// ---------- Sensors ----------
	part def VisionSensor {
		attribute resolutionWidth : Integer = 1920;
		attribute resolutionHeight : Integer = 1080;
		attribute frameRate : Frequency = 30.0 [Hz];
		port powerIn : PowerPort;
		port dataOut : SensorDataPort {
			redefinition sensorData : ImageData;
		}

		action captureImage {
			out image : ImageData;
		}
	}

	part def RangeSensor {
		attribute maxRange : Distance = 10.0 [m];
		attribute accuracy : Distance = 0.01 [m];
		port powerIn : PowerPort;
		port dataOut : SensorDataPort {
			redefinition sensorData : RangeData;
		}

		action measureDistance {
			out range : RangeData;
		}
	}

	part def AudioSensor {
		attribute sensitivity : SoundPressure = 30.0 [dB];
		port powerIn : PowerPort;
		port dataOut : SensorDataPort {
			redefinition sensorData : AudioData;
		}

		action captureAudio {
			out audio : AudioData;
		}
	}

	// ---------- Head ----------
	part def Head {
		part neck : Joint {
			redefinition name = "neck";
			redefinition maxTorque = 15.0 [N*m];
		}
		part camera : VisionSensor;
		part rangeSensor : RangeSensor;
		part microphone : AudioSensor;
		port powerIn : PowerPort;
		port commandIn : CommandPort;
		port sensorDataOut : SensorDataPort;

		connection powerToNeck connect powerIn to neck.powerIn;
		connection powerToCamera connect powerIn to camera.powerIn;
		connection powerToRange connect powerIn to rangeSensor.powerIn;
		connection powerToMic connect powerIn to microphone.powerIn;

		connection cmdToNeck connect commandIn to neck.commandIn;

		connection cameraData connect camera.dataOut to sensorDataOut;
		connection rangeData connect rangeSensor.dataOut to sensorDataOut;
		connection audioData connect microphone.dataOut to sensorDataOut;
	}

	// ---------- Torso ----------
	part def Torso {
		attribute mass : Mass = 25.0 [kg];
		port powerIn : PowerPort;
		port commandIn : CommandPort;
	}

	// ---------- Battery & Power Management ----------
	part def Battery {
		attribute capacity : Energy = 3600000.0 [J];
		attribute currentCharge : Energy = 3600000.0 [J];
		attribute nominalVoltage : Voltage = 24.0 [V];
		attribute maxDischargeCurrent : ElectricCurrent = 60.0 [A];
		port powerOut : PowerPort;

		action discharge {
			in demand : Power;
			out supplied : ElectricalPower;
		}
	}

	part def PowerManagement {
		part battery : Battery;
		attribute outputVoltage : Voltage = 12.0 [V];
		attribute maxOutputCurrent : ElectricCurrent = 50.0 [A];
		attribute efficiency : Real = 0.92;
		port powerOut : PowerPort;

		connection batteryToOutput connect battery.powerOut to powerOut;

		action distributePower {
			in demand : Power;
			out distributed : ElectricalPower;
		}
	}

	// ---------- Brain Modules ----------
	part def PerceptionModule {
		port sensorDataIn : SensorDataPort;
		port perceptionOut : PerceptionPort;

		action processSensorData {
			in data : SensorData;
			out result : PerceptionResult;
		}

		action buildMap {
			in images : ImageData[0..*];
			out mapConfidence : Real;
		}

		action detectObstacles {
			in ranges : RangeData[0..*];
			out obstacleDetected : Boolean;
		}
	}

	part def PlanningModule {
		port perceptionIn : PerceptionPort;
		port userCommandIn : UserCommandPort;
		port planOut : PlanPort;

		action generatePlan {
			in perception : PerceptionResult;
			in command : UserCommand;
			out plan : Plan;
		}

		action planNavigation {
			in perception : PerceptionResult;
			out navPlan : Plan;
		}

		action planManipulation {
			in perception : PerceptionResult;
			out manipPlan : Plan;
		}
	}

	part def ControlModule {
		port planIn : PlanPort;
		port commandOut : CommandPort;

		attribute balanceStable : Boolean = true;

		action translatePlan {
			in plan : Plan;
			out commands : MotorCommand[0..*];
		}

		action coordinateLimbs {
			in commands : MotorCommand[0..*];
			out coordinated : MotorCommand[0..*];
		}

		action maintainDynamicBalance {
			out stable : Boolean;
		}
	}

	// ---------- Operating Modes State Machine ----------
	state def OperatingMode;

	state machine OperatingStateMachine {
		state standby : OperatingMode;
		state active : OperatingMode;
		state lowPower : OperatingMode;
		state recovery : OperatingMode;

		transition standby_to_active
			first standby then active
			when userCommandReceived;

		transition active_to_standby
			first active then standby
			when taskCompleted;

		transition active_to_lowPower
			first active then lowPower
			when batteryLow;

		transition lowPower_to_standby
			first lowPower then standby
			when batteryRecharged;

		transition any_to_recovery
			first standby then recovery
			when errorDetected;

		transition active_to_recovery
			first active then recovery
			when errorDetected;

		transition recovery_to_standby
			first recovery then standby
			when errorCleared;

		entry standby {
			action enterStandby { out message : String = "Entering standby"; }
		}

		entry active {
			action enterActive { out message : String = "Entering active mode"; }
		}

		entry lowPower {
			action enterLowPower { out message : String = "Conserving energy"; }
		}

		entry recovery {
			action enterRecovery { out message : String = "Recovering from error"; }
		}
	}

	// ---------- Humanoid Robot ----------
	part def HumanoidRobot {
		attribute name : String = "HumanoidAssistant";
		attribute totalMass : Mass = 70.0 [kg];
		attribute height : Distance = 1.70 [m];
		attribute operatingHours : Duration = 14400.0 [s];

		part head : Head;
		part torso : Torso;
		part leftArm : Arm {
			redefinition side = "left";
		}
		part rightArm : Arm {
			redefinition side = "right";
		}
		part leftLeg : Leg {
			redefinition side = "left";
		}
		part rightLeg : Leg {
			redefinition side = "right";
		}
		part powerSystem : PowerManagement;
		part perception : PerceptionModule;
		part planning : PlanningModule;
		part control : ControlModule;

		port userCommandIn : UserCommandPort;

		// Power distribution
		connection powerToTorso connect powerSystem.powerOut to torso.powerIn;
		connection powerToHead connect powerSystem.powerOut to head.powerIn;
		connection powerToLeftArm connect powerSystem.powerOut to leftArm.powerIn;
		connection powerToRightArm connect powerSystem.powerOut to rightArm.powerIn;
		connection powerToLeftLeg connect powerSystem.powerOut to leftLeg.powerIn;
		connection powerToRightLeg connect powerSystem.powerOut to rightLeg.powerIn;

		// Sensor data flow
		connection headToPerception connect head.sensorDataOut to perception.sensorDataIn;
		connection perceptionToPlanning connect perception.perceptionOut to planning.perceptionIn;
		connection userCmdToPlanning connect userCommandIn to planning.userCommandIn;
		connection planningToControl connect planning.planOut to control.planIn;

		// Command distribution
		connection controlToTorso connect control.commandOut to torso.commandIn;
		connection controlToHead connect control.commandOut to head.commandIn;
		connection controlToLeftArm connect control.commandOut to leftArm.commandIn;
		connection controlToRightArm connect control.commandOut to rightArm.commandIn;
		connection controlToLeftLeg connect control.commandOut to leftLeg.commandIn;
		connection controlToRightLeg connect control.commandOut to rightLeg.commandIn;

		// Operating state machine
		part operatingStateMachine : OperatingStateMachine;

		// Continuous perceive-plan-act cycle
		action perceivePlanAct {
			in command : UserCommand;
			out executed : Boolean;

			perform perception.processSensorData;
			perform planning.generatePlan;
			perform control.translatePlan;
			perform control.coordinateLimbs;
			perform control.maintainDynamicBalance;
		}
	}

	// ---------- Requirements ----------
	requirement def RobotRequirements {
		subject robot : HumanoidRobot;

		requirement totalMassReq {
			subject robot;
			doc /* The robot total mass shall not exceed 80 kg. */
			require constraint { robot.totalMass <= 80.0 [kg] }
		}

		requirement heightReq {
			subject robot;
			doc /* The robot height shall be between 1.5 m and 2.0 m. */
			require constraint { robot.height >= 1.5 [m] and robot.height <= 2.0 [m] }
		}

		requirement operatingDurationReq {
			subject robot;
			doc /* The robot shall sustain at least 4 hours of continuous operation. */
			require constraint { robot.operatingHours >= 14400.0 [s] }
		}

		requirement armArticulationReq {
			subject robot;
			doc /* Each arm shall have shoulder, elbow, and wrist joints plus a gripper. */
			require constraint { robot.leftArm.shoulder.exists and robot.leftArm.elbow.exists and robot.leftArm.wrist.exists and robot.leftArm.gripper.exists }
		}

		requirement legArticulationReq {
			subject robot;
			doc /* Each leg shall have hip, knee, and ankle joints. */
			require constraint { robot.leftLeg.hip.exists and robot.leftLeg.knee.exists and robot.leftLeg.ankle.exists }
		}

		requirement gripperForceReq {
			subject robot;
			doc /* The gripper shall grasp objects with up to 50 N of force. */
			require constraint { robot.leftArm.gripper.maxForce >= 50.0 [N] and robot.rightArm.gripper.maxForce >= 50.0 [N] }
		}

		requirement sensorSuiteReq {
			subject robot;
			doc /* The head shall contain a vision sensor, range sensor, and audio sensor. */
			require constraint { robot.head.camera.exists and robot.head.rangeSensor.exists and robot.head.microphone.exists }
		}

		requirement brainModulesReq {
			subject robot;
			doc /* The robot shall include perception, planning, and control modules. */
			require constraint { robot.perception.exists and robot.planning.exists and robot.control.exists }
		}

		requirement operatingModesReq {
			subject robot;
			doc /* The robot shall support standby, active, low-power, and recovery modes. */
			require constraint { robot.operatingStateMachine.exists }
		}
	}

}

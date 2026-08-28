package HexapodRobot {
	import ScalarValues::*;
	import ISQ::*;
	import ISQSpace::*;
	import ISQTime::*;
	import ISQElectricity::*;
	import ISQEnergy::*;
	import ISQForce::*;

	value type AngleDeg :> Real {
		unit 'deg';
	}
	value type TorqueNm :> Real {
		unit 'N·m';
	}
	value type DistanceMm :> Real {
		unit 'mm';
	}
	value type VoltageV :> Real {
		unit 'V';
	}
	value type CurrentA :> Real {
		unit 'A';
	}
	value type EnergyWh :> Real {
		unit 'Wh';
	}
	value type TimeMin :> Real {
		unit 'min';
	}
	value type PowerW :> Real {
		unit 'W';
	}
	value type SpeedMps :> Real {
		unit 'm/s';
	}

	item def GroundSensorData {
		attribute distance : DistanceMm;
		attribute contact : Boolean;
		attribute timestamp : TimeMin;
	}

	item def JointCommand {
		attribute targetAngle : AngleDeg;
		attribute targetTorque : TorqueNm;
	}

	item def LegCommand {
		attribute legId : Integer;
		attribute coxaCmd : JointCommand;
		attribute femurCmd : JointCommand;
		attribute tibiaCmd : JointCommand;
	}

	item def TerrainEstimate {
		attribute legContacts : Boolean[6];
		attribute legDistances : DistanceMm[6];
		attribute obstacleDetected : Boolean;
		attribute roughnessIndex : Real;
	}

	item def GaitSelection {
		attribute gaitName : String;
		attribute stanceLegs : Integer;
		attribute swingLegs : Integer;
		attribute cyclePeriod : TimeMin;
	}

	item def NavigationCommand {
		attribute desiredHeading : AngleDeg;
		attribute desiredSpeed : SpeedMps;
		attribute stopRequested : Boolean;
	}

	port def GroundSensorOut {
		out data : GroundSensorData;
	}

	port def LegCommandIn {
		in cmd : LegCommand;
	}

	port def JointCommandIn {
		in cmd : JointCommand;
	}

	port def PowerOut {
		out voltage : VoltageV;
		out current : CurrentA;
	}

	port def PowerIn {
		in voltage : VoltageV;
		in current : CurrentA;
	}

	port def NavigationIn {
		in navCmd : NavigationCommand;
	}

	requirement def OperationalRequirements {
		subject : HexapodSystem;
		requirement ContinuousOperation {
			subject : HexapodSystem;
			doc /* The robot shall operate continuously for at least one hour on a full battery charge. */
			requirement constraint { subject.battery.capacity >= 60.0 [Wh]; }
		}
		requirement MinimumStanceLegs {
			subject : HexapodSystem;
			doc /* At least three legs shall remain in contact with the ground at all times during locomotion. */
			requirement constraint { subject.minStanceLegs >= 3; }
		}
		requirement JointCount {
			subject : HexapodSystem;
			doc /* The robot shall have six legs, each with three motorized joints. */
			requirement constraint { subject.legCount == 6; }
			requirement constraint { subject.jointsPerLeg == 3; }
		}
		requirement ObstacleAvoidance {
			subject : HexapodSystem;
			doc /* The robot shall enter an obstacle avoidance mode when an obstacle is detected and resume its path afterward. */
		}
		requirement StandbyMode {
			subject : HexapodSystem;
			doc /* The robot shall support a standby mode while waiting for commands. */
		}
	}

	part def Motor {
		attribute nominalVoltage : VoltageV = 12.0;
		attribute stallTorque : TorqueNm = 2.5;
		attribute maxSpeed : AngleDeg = 360.0;
		attribute currentAngle : AngleDeg;
		attribute currentTorque : TorqueNm;
		port cmdIn : JointCommandIn;
		port pwrIn : PowerIn;
		perform action updateState {
			in cmd : JointCommand;
			out angle : AngleDeg;
			out torque : TorqueNm;
		}
	}

	part def Joint {
		attribute jointName : String;
		attribute jointType : String;
		part motor : Motor;
		port cmdIn : JointCommandIn;
		connection motorCmd : motor.cmdIn <>: cmdIn;
	}

	part def GroundSensor {
		attribute maxRange : DistanceMm = 200.0;
		attribute contactThreshold : DistanceMm = 5.0;
		attribute measuredDistance : DistanceMm;
		attribute contactDetected : Boolean;
		port sensorOut : GroundSensorOut;
		perform action sample {
			out data : GroundSensorData;
		}
	}

	part def Leg {
		attribute legId : Integer;
		part coxa : Joint {
			:>> jointName = "coxa";
			:>> jointType = "yaw";
		}
		part femur : Joint {
			:>> jointName = "femur";
			:>> jointType = "pitch";
		}
		part tibia : Joint {
			:>> jointName = "tibia";
			:>> jointType = "pitch";
		}
		part footSensor : GroundSensor;
		port cmdIn : LegCommandIn;
		port sensorOut : GroundSensorOut;
		connection coxaCmd : coxa.cmdIn <>: cmdIn::coxaCmd;
		connection femurCmd : femur.cmdIn <>: cmdIn::femurCmd;
		connection tibiaCmd : tibia.cmdIn <>: cmdIn::tibiaCmd;
		connection sensorLink : footSensor.sensorOut <>: sensorOut;
	}

	part def BatteryPack {
		attribute capacity : EnergyWh = 75.0;
		attribute nominalVoltage : VoltageV = 12.0;
		attribute maxDischargeCurrent : CurrentA = 10.0;
		attribute remainingEnergy : EnergyWh = 75.0;
		attribute minOperationTime : TimeMin = 60.0;
		port powerOut : PowerOut;
		perform action discharge {
			in load : PowerW;
			out remaining : EnergyWh;
		}
	}

	part def CentralController {
		attribute clockRate : Real = 1.0e9;
		attribute minStanceLegs : Integer = 3;
		attribute currentMode : String = "standby";
		port sensorIn[6] : ~GroundSensorOut;
		port legCmdOut[6] : ~LegCommandIn;
		port navIn : NavigationIn;
		port pwrIn : PowerIn;
		attribute latestTerrain : TerrainEstimate;
		attribute currentGait : GaitSelection;
		attribute pendingNavCmd : NavigationCommand;

		perform action scanEnvironment {
			in sensorData : GroundSensorData[6];
			out terrain : TerrainEstimate;
		}

		perform action selectGait {
			in terrain : TerrainEstimate;
			out gait : GaitSelection;
		}

		perform action generateLegCommands {
			in gait : GaitSelection;
			in terrain : TerrainEstimate;
			out commands : LegCommand[6];
		}

		state machine controllerStates {
			entry standby;
			state standby {
				doc /* Waiting for navigation commands. */
				entry :>> currentMode = "standby";
				perform action waitForCommand;
			}
			state active {
				doc /* Active locomotion mode. */
				entry :>> currentMode = "active";
				do {
					scanEnvironment;
					selectGait;
					generateLegCommands;
				}
			}
			state obstacleAvoidance {
				doc /* Special mode to navigate around detected obstacles. */
				entry :>> currentMode = "obstacleAvoidance";
				do {
					scanEnvironment;
					selectGait;
					generateLegCommands;
				}
			}
			transition standby -> active
				when navIn.navCmd.stopRequested == false
				:>> currentMode = "active";
			transition active -> obstacleAvoidance
				when latestTerrain.obstacleDetected == true;
			transition obstacleAvoidance -> active
				when latestTerrain.obstacleDetected == false;
			transition active -> standby
				when navIn.navCmd.stopRequested == true;
		}
	}

	part def HexapodBody {
		attribute mass : Real = 4.5;
		attribute length : DistanceMm = 300.0;
		attribute width : DistanceMm = 250.0;
		part controller : CentralController;
		part battery : BatteryPack;
		part legs : Leg[6] {
			:>> legId = #[1..6];
		}
		connection batteryToController : battery.powerOut <>: controller.pwrIn;
		connection batteryToLegs : battery.powerOut <>: legs::motor::pwrIn;
		connection sensorToController : legs.sensorOut <>: controller.sensorIn;
		connection controllerToLegs : controller.legCmdOut <>: legs.cmdIn;
	}

	part def HexapodSystem {
		part body : HexapodBody;
		attribute legCount : Integer = 6;
		attribute jointsPerLeg : Integer = 3;
		attribute minStanceLegs : Integer = 3;
		satisfy OperationalRequirements {
			:>> subject = HexapodSystem::this;
		}
	}

	requirement HexapodOperationalRequirements : OperationalRequirements {
		subject : HexapodSystem;
	}

	part hexapodRobot : HexapodSystem {
		:>> body.controller.currentMode = "standby";
		:>> body.battery.remainingEnergy = 75.0;
	}
}

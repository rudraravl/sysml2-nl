package ModularRobotSystem {

	import ScalarValues::*;
	import ISQ::*;

	// ---------- Value Types ----------
	value def PowerUnit > Real { unit 'W'; }
	value def EnergyUnit > Real { unit 'J'; }
	value def VoltageUnit > Real { unit 'V'; }
	value def CurrentUnit > Real { unit 'A'; }
	value def MassUnit > Real { unit 'kg'; }
	value def LengthUnit > Real { unit 'm'; }
	value def SpeedUnit > Real { unit 'm/s'; }
	value def TorqueUnit > Real { unit 'N*m'; }
	value def AngleUnit > Real { unit 'rad'; }
	value def ForceUnit > Real { unit 'N'; }
	value def FrequencyUnit > Real { unit 'Hz'; }
	value def TemperatureUnit > Real { unit 'K'; }
	value def ConfidenceUnit > Real { unit '1'; }

	value def BatteryLevel :> Real { unit '%'; }
	value def DataRate :> Real { unit 'bit/s'; }
	value def ModuleId :> Integer;
	value def PortId :> Integer;

	// ---------- Enumerations ----------
	enum def ModuleKind {
		locomotion = 1;
		manipulation = 2;
		sensing = 3;
		computation = 4;
		power = 5;
	}

	enum def DockingState {
		disconnected = 0;
		aligning = 1;
		locked = 2;
		error = 3;
	}

	enum def RobotMorphology {
		chain = 1;
		platform = 2;
		cluster = 3;
		star = 4;
		custom = 5;
	}

	enum def TaskType {
		navigation = 1;
		manipulation = 2;
		inspection = 3;
		transport = 4;
		unknown = 5;
	}

	enum def SensorKind {
		camera = 1;
		lidar = 2;
		thermal = 3;
		microphone = 4;
		contact = 5;
		imu = 6;
	}

	// ---------- Item Types ----------
	item def PowerFlow {
		value voltage : VoltageUnit;
		value current : CurrentUnit;
	}

	item def DataPacket {
		value sourceId : ModuleId;
		value destinationId : ModuleId;
		value payload : String;
		value timestamp : TimeInstantValue;
	}

	item def CommandMessage {
		value command : String;
		value targetId : ModuleId;
		value priority : Integer;
	}

	item def SensorReading {
		value kind : SensorKind;
		value value : Real;
		value confidence : ConfidenceUnit;
		value timestamp : TimeInstantValue;
	}

	item def EnvironmentMap {
		value resolution : LengthUnit;
		value obstacleCount : Integer;
		value freePathAvailable : Boolean;
	}

	item def ConfigurationPlan {
		value targetMorphology : RobotMorphology;
		value moduleAssignments : String;
		value estimatedPower : PowerUnit;
		value estimatedTime : TimeDurationValue;
	}

	item def TaskDescriptor {
		value type : TaskType;
		value description : String;
		value priority : Integer;
		value deadline : TimeInstantValue;
	}

	item def ModuleStatus {
		value moduleId : ModuleId;
		value kind : ModuleKind;
		value batteryLevel : BatteryLevel;
		value temperature : TemperatureUnit;
		value dockedPorts : Integer;
		value operational : Boolean;
	}

	// ---------- Port Definitions ----------
	port def DockingPort {
		in item powerIn : PowerFlow;
		out item powerOut : PowerFlow;
		in item dataIn : DataPacket;
		out item dataOut : DataPacket;
		attribute portId : PortId;
		attribute state : DockingState;
	}

	port def CommandPort {
		in item command : CommandMessage;
		out item status : ModuleStatus;
	}

	port def SensorPort {
		out item reading : SensorReading;
	}

	port def PowerBusPort {
		in item powerIn : PowerFlow;
		out item powerOut : PowerFlow;
	}

	// ---------- Abstract Module ----------
	part def Module {
		attribute id : ModuleId;
		attribute kind : ModuleKind;
		attribute mass : MassUnit;
		attribute dimensions : LengthUnit[3];
		attribute maxBatteryCapacity : EnergyUnit;
		attribute currentBatteryLevel : BatteryLevel;
		attribute operational : Boolean;

		value selfEnergy : PowerUnit;

		port dockingPort[6] : DockingPort;
		port commandPort : CommandPort;

		item store localStatus : ModuleStatus;

		attribute dockedCount : Integer = 0;

		state def ModuleBehavior {
			entry action { send localStatus to commandPort; }
			state Idle;
			state Active;
			state Reconfiguring;
			state Faulted;

			transition init_to_Idle initial to Idle;
			transition Idle_to_Active
				from Idle to Active
				when commandPort.command::command == "activate";
			transition Active_to_Reconfiguring
				from Active to Reconfiguring
				when commandPort.command::command == "reconfigure";
			transition Reconfiguring_to_Active
				from Reconfiguring to Active
				when commandPort.command::command == "complete";
			transition any_to_Faulted
				from Active to Faulted
				when currentBatteryLevel < 5;
			transition Faulted_to_Idle
				from Faulted to Idle
				when commandPort.command::command == "reset";
		}

		action def selfDiagnostic {
			in ref module : Module;
			out result : Boolean;
		}
	}

	// ---------- Locomotion Module ----------
	part def LocomotionModule :> Module {
		attribute maxSpeed : SpeedUnit;
		attribute tractionForce : ForceUnit;
		attribute wheelCount : Integer;
		attribute legJointCount : Integer;

		value drivePower : PowerUnit;

		action def Move {
			in targetPosition : LengthUnit[3];
			in speed : SpeedUnit;
			out distanceTraveled : LengthUnit;
		}

		action def Stop {
			out deceleration : Real;
		}

		action def Rotate {
			in angle : AngleUnit;
		}

		state locomotionState {
			state Stationary;
			state Moving;
			state Rotating;
			transition from Stationary to Moving when commandPort.command::command == "move";
			transition from Moving to Stationary when commandPort.command::command == "stop";
			transition from Stationary to Rotating when commandPort.command::command == "rotate";
			transition from Rotating to Stationary when commandPort.command::command == "stop";
		}
	}

	// ---------- Manipulation Module ----------
	part def ManipulationModule :> Module {
		attribute jointCount : Integer;
		attribute reach : LengthUnit;
		attribute payloadCapacity : MassUnit;
		attribute gripperForce : ForceUnit;
		attribute maxTorque : TorqueUnit;

		value actuationPower : PowerUnit;

		action def Grasp {
			in objectMass : MassUnit;
			out success : Boolean;
		}

		action def Release {
			out released : Boolean;
		}

		action def MoveArm {
			in jointAngles : AngleUnit[jointCount];
			out endEffectorPosition : LengthUnit[3];
		}

		state manipulationState {
			state ArmIdle;
			state Extending;
			state Grasping;
			state Retracting;
			transition from ArmIdle to Extending when commandPort.command::command == "extend";
			transition from Extending to Grasping when commandPort.command::command == "grasp";
			transition from Grasping to Retracting when commandPort.command::command == "retract";
			transition from Retracting to ArmIdle when commandPort.command::command == "home";
		}
	}

	// ---------- Sensing Module ----------
	part def SensingModule :> Module {
		attribute sensorKinds : SensorKind[1..*];
		attribute scanRange : LengthUnit;
		attribute scanFrequency : FrequencyUnit;
		attribute resolution : LengthUnit;

		value sensingPower : PowerUnit;

		port sensorOut : SensorPort;

		action def ScanEnvironment {
			out readings : SensorReading[1..*];
			out map : EnvironmentMap;
		}

		action def Calibrate {
			out calibrated : Boolean;
		}

		state sensingState {
			state Scanning;
			state Calibrating;
			state Standby;
			transition from Standby to Scanning when commandPort.command::command == "scan";
			transition from Scanning to Standby when commandPort.command::command == "stopScan";
			transition from Standby to Calibrating when commandPort.command::command == "calibrate";
			transition from Calibrating to Standby when commandPort.command::command == "done";
		}
	}

	// ---------- Computation Module ----------
	part def ComputationModule :> Module {
		attribute processingRate : FrequencyUnit;
		attribute memoryCapacity : Integer;
		attribute cores : Integer;

		value computePower : PowerUnit;

		item store taskQueue : TaskDescriptor[0..*];
		item store currentPlan : ConfigurationPlan;

		action def AnalyzeTask {
			in task : TaskDescriptor;
			out plan : ConfigurationPlan;
		}

		action def ProcessSensorData {
			in readings : SensorReading[1..*];
			out map : EnvironmentMap;
		}

		action def PlanConfiguration {
			in task : TaskDescriptor;
			in availableModules : ModuleStatus[1..*];
			out plan : ConfigurationPlan;
		}

		state computationState {
			state Computing;
			state Planning;
			state Idle;
			transition from Idle to Planning when commandPort.command::command == "plan";
			transition from Planning to Computing when commandPort.command::command == "analyze";
			transition from Computing to Idle when commandPort.command::command == "done";
		}
	}

	// ---------- Power Module ----------
	part def PowerModule :> Module {
		attribute energyCapacity : EnergyUnit;
		attribute outputVoltage : VoltageUnit;
		attribute maxOutputCurrent : CurrentUnit;
		attribute distributionEfficiency : Real;

		value distributionPower : PowerUnit;

		port powerBus : PowerBusPort;

		action def DistributePower {
			in targetModules : ModuleId[1..*];
			out powerDelivered : PowerFlow[1..*];
		}

		action def Recharge {
			in sourceVoltage : VoltageUnit;
			out energyStored : EnergyUnit;
		}

		state powerState {
			state Distributing;
			state Recharging;
			state Conserving;
			transition from Conserving to Distributing when commandPort.command::command == "distribute";
			transition from Distributing to Conserving when currentBatteryLevel < 20;
			transition from Conserving to Recharging when commandPort.command::command == "recharge";
			transition from Recharging to Conserving when currentBatteryLevel > 90;
		}
	}

	// ---------- Central Controller ----------
	part def CentralController {
		attribute controllerId : ModuleId;
		attribute decisionCycle : TimeDurationValue;
		attribute reconfigurationThreshold : ConfidenceUnit;

		item store currentTask : TaskDescriptor;
		item store currentMorphology : RobotMorphology;
		item store moduleRegistry : ModuleStatus[1..*];
		item store activePlan : ConfigurationPlan;
		item store environmentModel : EnvironmentMap;

		port commandBus : CommandPort[1..*];
		port sensorBus : SensorPort[1..*];

		action def SensePlanActCycle {
			in task : TaskDescriptor;
			out actions : CommandMessage[1..*];

			perform action sense {
				out readings : SensorReading[1..*];
				out envMap : EnvironmentMap;
			}
			perform action plan {
				in readings : SensorReading[1..*];
				in envMap : EnvironmentMap;
				in task : TaskDescriptor;
				out plan : ConfigurationPlan;
			}
			perform action act {
				in plan : ConfigurationPlan;
				out commands : CommandMessage[1..*];
			}
		}

		action def EvaluateReconfiguration {
			in task : TaskDescriptor;
			in currentForm : RobotMorphology;
			in moduleStatuses : ModuleStatus[1..*];
			out shouldReconfigure : Boolean;
			out newPlan : ConfigurationPlan;
		}

		action def ExecuteReconfiguration {
			in plan : ConfigurationPlan;
			out disconnectCommands : CommandMessage[1..*];
			out moveCommands : CommandMessage[1..*];
			out dockCommands : CommandMessage[1..*];
		}

		state def ControllerStateMachine {
			state Monitoring;
			state Planning;
			state Reconfiguring;
			state Executing;
			state Faulted;

			transition init_to_Monitoring initial to Monitoring;
			transition Monitor_to_Planning
				from Monitoring to Planning
				when currentTask.priority > 0;
			transition Planning_to_Reconfiguring
				from Planning to Reconfiguring
				when activePlan.targetMorphology != currentMorphology;
			transition Planning_to_Executing
				from Planning to Executing
				when activePlan.targetMorphology == currentMorphology;
			transition Reconfiguring_to_Executing
				from Reconfiguring to Executing
				when commandBus.status::operational == true;
			transition Executing_to_Monitoring
				from Executing to Monitoring
				when currentTask.priority == 0;
			transition any_to_Faulted
				from Monitoring to Faulted
				when moduleRegistry::operational == false;
			transition Faulted_to_Monitoring
				from Faulted to Monitoring
				when commandBus.status::operational == true;
		}
	}

	// ---------- Robot System ----------
	part def ModularRobotSystem {
		attribute systemId : String;
		attribute totalModuleCount : Integer;
		attribute currentMorphology : RobotMorphology;
		attribute missionStartTime : TimeInstantValue;
		attribute operationalTime : TimeDurationValue;

		part controller : CentralController;

		part locomotionModules : LocomotionModule[1..*];
		part manipulationModules : ManipulationModule[0..*];
		part sensingModules : SensingModule[1..*];
		part computationModules : ComputationModule[0..*];
		part powerModules : PowerModule[1..*];

		// Connections between controller and modules
		connection controllerToLocomotion : CommandPort
			connect controller.commandBus to locomotionModules.commandPort;

		connection controllerToManipulation : CommandPort
			connect controller.commandBus to manipulationModules.commandPort;

		connection controllerToSensing : CommandPort
			connect controller.commandBus to sensingModules.commandPort;

		connection controllerToComputation : CommandPort
			connect controller.commandBus to computationModules.commandPort;

		connection controllerToPower : CommandPort
			connect controller.commandBus to powerModules.commandPort;

		// Sensor data flow
		connection sensorDataFlow : SensorPort
			connect sensingModules.sensorOut to controller.sensorBus;

		// Inter-module docking connections (power and data sharing)
		connection interModuleDocking : DockingPort
			connect locomotionModules.dockingPort to manipulationModules.dockingPort;

		connection powerDistribution : PowerBusPort
			connect powerModules.powerBus to locomotionModules.dockingPort::powerIn;

		connection powerToManipulation : PowerBusPort
			connect powerModules.powerBus to manipulationModules.dockingPort::powerIn;

		connection powerToSensing : PowerBusPort
			connect powerModules.powerBus to sensingModules.dockingPort::powerIn;

		connection powerToComputation : PowerBusPort
			connect powerModules.powerBus to computationModules.dockingPort::powerIn;

		// Data exchange between computation modules and controller
		connection computationDataLink : DockingPort
			connect computationModules.dockingPort to controller.commandBus;

		action def MissionExecution {
			in missionTask : TaskDescriptor;
			out missionResult : Boolean;

			perform action initialize {
				out ready : Boolean;
			}
			perform action sensePlanAct : SensePlanActCycle {
				in task = missionTask;
				out actions;
			}
			perform action reconfigureIfNeeded : EvaluateReconfiguration {
				in task = missionTask;
				in currentForm = currentMorphology;
				in moduleStatuses = controller.moduleRegistry;
				out shouldReconfigure;
				out newPlan;
			}
			perform action executeReconfiguration : ExecuteReconfiguration {
				in plan = reconfigureIfNeeded.newPlan;
				out disconnectCommands;
				out moveCommands;
				out dockCommands;
			}
			perform action complete {
				out success : Boolean;
			}
		}

		state def SystemOperation {
			state Booting;
			state Ready;
			state OnMission;
			state Reconfiguring;
			state Returning;
			state Shutdown;

			transition init_to_Booting initial to Booting;
			transition Booting_to_Ready from Booting to Ready when controller.moduleRegistry::operational == true;
			transition Ready_to_OnMission from Ready to OnMission when controller.currentTask.priority > 0;
			transition OnMission_to_Reconfiguring from OnMission to Reconfiguring when controller.activePlan.targetMorphology != currentMorphology;
			transition Reconfiguring_to_OnMission from Reconfiguring to OnMission when currentMorphology == controller.activePlan.targetMorphology;
			transition OnMission_to_Returning from OnMission to Returning when controller.currentTask.priority == 0;
			transition Returning_to_Ready from Returning to Ready when controller.moduleRegistry::operational == true;
			transition Ready_to_Shutdown from Ready to Shutdown when controller.currentTask.priority == -1;
		}
	}

	// ---------- Requirements ----------
	requirement def ModularRobotRequirements {

		requirement def SelfReconfigurationCapability {
			doc { The system shall autonomously reconfigure its physical structure to adapt to different tasks. }
			subject : ModularRobotSystem;
			assert {
				subject.controller.activePlan.targetMorphology != subject.currentMorphology
				implies subject.controller::ExecuteReconfiguration::shouldReconfigure == true;
			}
		}

		requirement def ModuleInteroperability {
			doc { All modules shall use standardized docking ports for physical connection, power sharing, and data exchange. }
			subject : Module;
			assert {
				subject.dockingPort::portId >= 0 and subject.dockingPort::portId <= 5;
			}
		}

		requirement def AutonomousOperation {
			doc { The system shall operate autonomously through a continuous sense-plan-act cycle without external intervention. }
			subject : CentralController;
			assert {
				subject.decisionCycle > 0 [s];
			}
		}

		requirement def PowerDistribution {
			doc { Power modules shall distribute energy to connected modules to extend operational time. }
			subject : PowerModule;
			assert {
				subject.energyCapacity > 0 [J]
				and subject.distributionEfficiency > 0.0
				and subject.distributionEfficiency <= 1.0;
			}
		}

		requirement def LocomotionCapability {
			doc { Locomotion modules shall provide movement with a minimum speed capability. }
			subject : LocomotionModule;
			assert {
				subject.maxSpeed > 0 [m/s]
				and subject.tractionForce > 0 [N];
			}
		}

		requirement def ManipulationCapability {
			doc { Manipulation modules shall grasp and move objects within payload capacity. }
			subject : ManipulationModule;
			assert {
				subject.payloadCapacity > 0 [kg]
				and subject.gripperForce > 0 [N]
				and subject.reach > 0 [m];
			}
		}

		requirement def SensingCapability {
			doc { Sensing modules shall scan the environment and provide data for planning. }
			subject : SensingModule;
			assert {
				subject.scanRange > 0 [m]
				and subject.scanFrequency > 0 [Hz];
			}
		}

		requirement def ComputationCapability {
			doc { Computation modules shall analyze tasks and plan new configurations. }
			subject : ComputationModule;
			assert {
				subject.processingRate > 0 [Hz]
				and subject.cores >= 1;
			}
		}

		requirement def BatterySelfSufficiency {
			doc { Each module shall have its own battery for self-contained operation. }
			subject : Module;
			assert {
				subject.maxBatteryCapacity > 0 [J];
			}
		}

		requirement def MorphologyAdaptation {
			doc { The system shall support at least chain and platform morphologies for diverse environments. }
			subject : ModularRobotSystem;
			assert {
				subject.currentMorphology == RobotMorphology::chain
				or subject.currentMorphology == RobotMorphology::platform
				or subject.currentMorphology == RobotMorphology::cluster
				or subject.currentMorphology == RobotMorphology::star
				or subject.currentMorphology == RobotMorphology::custom;
			}
		}

		requirement def Resilience {
			doc { The system shall detect module faults and reconfigure to maintain operational capability. }
			subject : ModularRobotSystem;
			assert {
				subject.controller.moduleRegistry::operational == false
				implies subject.controller::ControllerStateMachine::state == ControllerStateMachine::Faulted;
			}
		}
	}

}

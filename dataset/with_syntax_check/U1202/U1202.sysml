package 'Self-Reconfiguring Modular Robot System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import ISQBase::*;
	private import Measurement::*;
	
	attribute def AngleValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : AngleUnit;
	}
	
	attribute def AngleUnit :> SimpleUnit;
	
	attribute def TorqueValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : TorqueUnit;
	}
	
	attribute def TorqueUnit :> DerivedUnit;
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : VoltageUnit;
	}
	
	attribute def VoltageUnit :> DerivedUnit;
	
	attribute def DataRateValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : DataRateUnit;
	}
	
	attribute def DataRateUnit :> DerivedUnit;
	
	enum def ModuleTypeEnum {
		enum locomotion;
		enum manipulation;
		enum sensing;
		enum computation;
		enum power;
	}
	
	enum def ConnectionStateEnum {
		enum disconnected;
		enum aligning;
		enum locked;
		enum unlocking;
	}
	
	enum def TaskStateEnum {
		enum idle;
		enum analyzing;
		enum reconfiguring;
		enum executing;
		enum completed;
	}
	
	attribute def Position3D {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}
	
	attribute def Orientation3D {
		attribute roll : AngleValue;
		attribute pitch : AngleValue;
		attribute yaw : AngleValue;
	}
	
	attribute def Pose {
		attribute position : Position3D;
		attribute orientation : Orientation3D;
	}
	
	item def TaskCommand {
		attribute taskId : String;
		attribute taskType : String;
		attribute targetLocation : Position3D;
		attribute requiredCapabilities : String[1..*];
		attribute priority : Integer;
		attribute deadline : TimeValue;
	}
	
	item def ConfigurationDescriptor {
		attribute configId : String;
		attribute topology : String;
		attribute moduleCount : Integer;
		attribute modulePoses : Pose[1..*] ordered;
		attribute connectionMap : String[0..*];
		attribute estimatedPerformance : Real;
	}
	
	item def SensorData {
		attribute timestamp : TimeValue;
		attribute sensorId : String;
		attribute dataType : String;
		attribute value : Real;
		attribute quality : Real;
	}
	
	item def PowerStatus {
		attribute voltage : VoltageValue;
		attribute current : Real;
		attribute chargeLevel : Real;
		attribute estimatedRuntime : TimeValue;
	}
	
	port def MechanicalDockingPort {
		attribute portId : Integer;
		attribute connectionState : ConnectionStateEnum;
		attribute lockingForce : TorqueValue;
		attribute alignmentTolerance : LengthValue;
		attribute isOccupied : Boolean;
	}
	
	port def PowerTransferPort {
		inout item powerStatus : PowerStatus;
		attribute maxVoltage : VoltageValue;
		attribute maxCurrent : Real;
		attribute transferEfficiency : Real;
	}
	
	port def DataBusPort {
		inout item data : SensorData;
		inout item commands : TaskCommand;
		attribute dataRate : DataRateValue;
		attribute protocol : String;
		attribute isActive : Boolean;
	}
	
	port def ActuatorControlPort {
		in item controlSignal : Real;
		out item feedback : Real;
		attribute actuatorType : String;
	}
	
	part def ModuleBase {
		attribute moduleId : String;
		attribute moduleType : ModuleTypeEnum;
		attribute currentPose : Pose;
		attribute mass : MassValue;
		attribute isOperational : Boolean;
		attribute batteryLevel : Real;
		
		port dockingPorts : MechanicalDockingPort[4];
		port powerPort : PowerTransferPort;
		port dataBus : DataBusPort;
		
		ref part neighbors : ModuleBase[0..4];
	}
	
	part def LocomotionModule :> ModuleBase {
		attribute :>> moduleType = ModuleTypeEnum::locomotion;
		attribute maxSpeed : Real;
		attribute wheelDiameter : LengthValue;
		
		port motorControl : ActuatorControlPort[4];
		
		action Move {
			in targetPose : Pose;
			in speed : Real;
			out actualPose : Pose;
		}
	}
	
	part def ManipulationModule :> ModuleBase {
		attribute :>> moduleType = ModuleTypeEnum::manipulation;
		attribute reachDistance : LengthValue;
		attribute maxPayload : MassValue;
		attribute gripperForce : TorqueValue;
		
		port armJoints : ActuatorControlPort[6];
		port gripperControl : ActuatorControlPort;
		
		action Grasp {
			in targetObject : String;
			in graspForce : TorqueValue;
			out graspSuccess : Boolean;
		}
		
		action Release {
			out releaseSuccess : Boolean;
		}
	}
	
	part def SensingModule :> ModuleBase {
		attribute :>> moduleType = ModuleTypeEnum::sensing;
		attribute sensorRange : LengthValue;
		attribute resolution : LengthValue;
		attribute fieldOfView : AngleValue;
		
		port sensorOutput : DataBusPort;
		
		action Scan {
			in scanRegion : Position3D;
			out sensorReadings : SensorData[1..*];
		}
	}
	
	part def ComputationModule :> ModuleBase {
		attribute :>> moduleType = ModuleTypeEnum::computation;
		attribute processingPower : Real;
		attribute memoryCapacity : Real;
		attribute activeProcesses : Integer;
		
		action ProcessData {
			in rawData : SensorData[1..*];
			out processedData : SensorData[1..*];
		}
		
		action PlanConfiguration {
			in task : TaskCommand;
			in currentConfig : ConfigurationDescriptor;
			out targetConfig : ConfigurationDescriptor;
		}
	}
	
	part def PowerModule :> ModuleBase {
		attribute :>> moduleType = ModuleTypeEnum::power;
		attribute batteryCapacity : Real;
		attribute outputVoltage : VoltageValue;
		attribute chargingRate : Real;
		
		action DistributePower {
			inout modules : ModuleBase[1..*];
			in powerDemand : Real;
		}
	}
	
	part def ReconfigurationController {
		attribute currentState : TaskStateEnum;
		attribute activeTask : TaskCommand;
		attribute currentConfiguration : ConfigurationDescriptor;
		
		ref part managedModules : ModuleBase[1..*];
		
		port controlBus : DataBusPort;
	}
	
	action def MonitorSystem {
		in modules : ModuleBase[1..*];
		out systemStatus : String;
		out healthMetrics : Real[1..*];
	}
	
	action def EvaluateTask {
		in task : TaskCommand;
		in currentConfig : ConfigurationDescriptor;
		out reconfigRequired : Boolean;
		out optimalConfig : ConfigurationDescriptor;
	}
	
	action def CoordinateReconfiguration {
		inout modules : ModuleBase[1..*];
		in targetConfig : ConfigurationDescriptor;
		out reconfigSuccess : Boolean;
	}
	
	action def AlignModules {
		inout module1 : ModuleBase;
		inout module2 : ModuleBase;
		in port1Index : Integer;
		in port2Index : Integer;
		out alignmentAchieved : Boolean;
	}
	
	action def LockConnection {
		inout module1 : ModuleBase;
		inout module2 : ModuleBase;
		in port1Index : Integer;
		in port2Index : Integer;
		out lockSuccess : Boolean;
	}
	
	action def UnlockConnection {
		inout module1 : ModuleBase;
		inout module2 : ModuleBase;
		in port1Index : Integer;
		in port2Index : Integer;
		out unlockSuccess : Boolean;
	}
	
	action def DisconnectModules {
		inout module1 : ModuleBase;
		inout module2 : ModuleBase;
		
		first start;
		then action unlock : UnlockConnection {
			inout module1;
			inout module2;
			in port1Index = 1;
			in port2Index = 1;
			out unlockSuccess;
		}
		then action separate {
			inout separatingModule1 = module1;
			inout separatingModule2 = module2;
		}
		then done;
	}
	
	action def ConnectModules {
		inout module1 : ModuleBase;
		inout module2 : ModuleBase;
		in targetPort1 : Integer;
		in targetPort2 : Integer;
		
		first start;
		then action align : AlignModules {
			inout module1;
			inout module2;
			in port1Index = targetPort1;
			in port2Index = targetPort2;
			out alignmentAchieved;
		}
		then action lock : LockConnection {
			inout module1;
			inout module2;
			in port1Index = targetPort1;
			in port2Index = targetPort2;
			out lockSuccess;
		}
		then done;
	}
	
	action def ReconfigureSystem {
		inout modules : ModuleBase[1..*];
		in currentConfig : ConfigurationDescriptor;
		in targetConfig : ConfigurationDescriptor;
		
		first start;
		then action disconnectPhase {
			action disconnectAll : DisconnectModules[1..*] {
				inout module1;
				inout module2;
			}
		}
		then action repositionPhase {
			action moveModules {
				inout movingModules = modules;
				in targetPoses = targetConfig.modulePoses;
			}
		}
		then action connectPhase {
			action connectAll : ConnectModules[1..*] {
				inout module1;
				inout module2;
				in targetPort1;
				in targetPort2;
			}
		}
		then action verifyPhase {
			action verifyConfiguration {
				in modules;
				in expectedConfig = targetConfig;
				out verified : Boolean;
			}
		}
		then done;
	}
	
	action def ExecutePrimaryTask {
		in taskCommand : TaskCommand;
		inout controller : ReconfigurationController;
		inout allModules : ModuleBase[1..*];
		
		first start;
		then merge taskLoop;
		
		then action monitor : MonitorSystem {
			in modules = allModules;
			out systemStatus;
			out healthMetrics;
		}
		
		then action evaluate : EvaluateTask {
			in task = taskCommand;
			in currentConfig = controller.currentConfiguration;
			out reconfigRequired;
			out optimalConfig;
		}
		
		then decide;
			if evaluate.reconfigRequired then reconfigure;
			if !evaluate.reconfigRequired then execute;
		
		action reconfigure : ReconfigureSystem {
			inout modules = allModules;
			in currentConfig = controller.currentConfiguration;
			in targetConfig = evaluate.optimalConfig;
		}
		then execute;
		
		action execute {
			first start;
			then merge executeLoop;
			
			then action sense {
				action scanEnvironment {
					in sensors : SensingModule[1..*];
					out environmentData : SensorData[1..*];
				}
			}
			
			then action navigate {
				action moveToTarget {
					in locomotion : LocomotionModule[1..*];
					in targetLocation = taskCommand.targetLocation;
					out navigationComplete : Boolean;
				}
			}
			
			then action manipulate {
				action performManipulation {
					in manipulator : ManipulationModule[1..*];
					in targetObject = taskCommand.taskType;
					out manipulationComplete : Boolean;
				}
			}
			
			then decide;
				if manipulate.performManipulation.manipulationComplete then done;
				if !manipulate.performManipulation.manipulationComplete then executeLoop;
		}
		
		then decide;
			if execute.manipulate.performManipulation.manipulationComplete then done;
			if !execute.manipulate.performManipulation.manipulationComplete then taskLoop;
	}
	
	state def ModuleConnectionState {
		in module : ModuleBase;
		in portIndex : Integer;
		
		entry; then disconnected;
		
		state disconnected;
		
		transition disconnected_to_aligning
			first disconnected
			accept AlignmentRequest
			then aligning;
		
		state aligning;
		
		transition aligning_to_locked
			first aligning
			accept AlignmentComplete
			then locked;
		
		transition aligning_to_disconnected
			first aligning
			accept AlignmentFailed
			then disconnected;
		
		state locked;
		
		transition locked_to_unlocking
			first locked
			accept DisconnectRequest
			then unlocking;
		
		state unlocking;
		
		transition unlocking_to_disconnected
			first unlocking
			accept UnlockComplete
			then disconnected;
	}
	
	requirement def ModularReconfigurationRequirement {
		doc /* The robot system shall be composed of independent modules 
		       that can autonomously connect and disconnect to form 
		       different configurations. */
		
		subject robot : SelfReconfiguringRobot;
	}
	
	requirement def TaskAdaptationRequirement {
		doc /* The robot shall analyze incoming tasks and reconfigure 
		       its structure to optimize task execution. */
		
		subject robot : SelfReconfiguringRobot;
	}
	
	requirement def AutonomousOperationRequirement {
		doc /* The robot shall operate autonomously with minimal external 
		       intervention during reconfiguration and task execution. */
		
		subject robot : SelfReconfiguringRobot;
	}
	
	requirement def CommunicationRequirement {
		doc /* All modules shall maintain continuous communication with 
		       the central controller during operation. */
		
		subject robot : SelfReconfiguringRobot;
	}
	
	requirement def SafetyRequirement {
		doc /* The robot shall ensure safe reconfiguration without 
		       damaging modules or dropping payloads. */
		
		subject robot : SelfReconfiguringRobot;
	}
	
	part def SelfReconfiguringRobot {
		part controller : ReconfigurationController {
			attribute currentState = TaskStateEnum::idle;
			attribute currentConfiguration : ConfigurationDescriptor {
				attribute configId = "CONFIG_001";
				attribute topology = "chain";
				attribute moduleCount = 8;
			}
		}
		
		part modules : ModuleBase[8] {
			part locomotionModules : LocomotionModule[2] {
				attribute moduleId = "LOCO_1";
				attribute isOperational = true;
				attribute batteryLevel = 85.0;
				attribute maxSpeed = 2.5;
			}
			
			part manipulationModules : ManipulationModule[2] {
				attribute moduleId = "MANIP_1";
				attribute isOperational = true;
				attribute batteryLevel = 80.0;
			}
			
			part sensingModules : SensingModule[2] {
				attribute moduleId = "SENSE_1";
				attribute isOperational = true;
				attribute batteryLevel = 90.0;
			}
			
			part computationModule : ComputationModule[1] {
				attribute moduleId = "COMP_1";
				attribute isOperational = true;
				attribute batteryLevel = 75.0;
				attribute processingPower = 3.2;
				attribute memoryCapacity = 16.0;
			}
			
			part powerModule : PowerModule[1] {
				attribute moduleId = "PWR_1";
				attribute isOperational = true;
				attribute batteryLevel = 95.0;
				attribute batteryCapacity = 5000.0;
			}
		}
		
		connection def DataBusConnection {
			end controllerEnd : DataBusPort;
			end moduleEnd : DataBusPort;
		}
		
		connection def PowerDistributionConnection {
			end sourceEnd : PowerTransferPort;
			end sinkEnd : PowerTransferPort;
		}
		
		connection controllerDataBus : DataBusConnection[8]
			connect controller.controlBus to modules.dataBus;
		
		connection powerDistribution : PowerDistributionConnection[7]
			connect modules[1].powerPort to modules[2].powerPort;
		
		perform action primaryMission : ExecutePrimaryTask {
			in taskCommand : TaskCommand {
				attribute taskId = "TASK_001";
				attribute taskType = "object_retrieval";
				attribute priority = 1;
			}
			inout controller = selfReconfiguringRobot.controller;
			inout allModules = selfReconfiguringRobot.modules;
		}
		
		exhibit state moduleConnectionStates : ModuleConnectionState[32] {
			in module = selfReconfiguringRobot.modules[1];
			in portIndex = 1;
		}
	}
	
	part selfReconfiguringRobot : SelfReconfiguringRobot {
		satisfy modularReq : ModularReconfigurationRequirement {
			subject robot = selfReconfiguringRobot;
		}
		
		satisfy adaptationReq : TaskAdaptationRequirement {
			subject robot = selfReconfiguringRobot;
		}
		
		satisfy autonomyReq : AutonomousOperationRequirement {
			subject robot = selfReconfiguringRobot;
		}
		
		satisfy commReq : CommunicationRequirement {
			subject robot = selfReconfiguringRobot;
		}
		
		satisfy safetyReq : SafetyRequirement {
			subject robot = selfReconfiguringRobot;
		}
	}
}

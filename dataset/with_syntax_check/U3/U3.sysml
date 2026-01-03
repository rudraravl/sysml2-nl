package 'Analog Robotic System' {
	private import ScalarValues::*;
	private import SI::*;
	private import ISQ::*;
	
	package ValueTypes {
		attribute def AnalogVoltage :> ISQ::electricPotentialDifference;
		attribute def AnalogCurrent :> ISQ::electricCurrent;
		attribute def PositionError :> ISQ::length;
		attribute def TaskCompletionRate :> Real;
		
		enum def RobotState {
			enum idle;
			enum calibrating;
			enum executing;
			enum completed;
			enum fault;
		}
		
		enum def TaskType {
			enum pickAndPlace;
			enum assembly;
			enum inspection;
		}
	}
	
	package RequirementModel {
		private import ValueTypes::*;
		
		requirement def AnalogRobotRequirements;
		
		requirement taskExecutionRequirement : AnalogRobotRequirements {
			subject robot : LogicalModel::AnalogRobotFunction;
			doc /* The analog robot shall execute its primary task with completion rate > 95%. */
			require constraint {
				robot.executeTask.completionRate > 0.95
			}
		}
		
		requirement analogControlRequirement : AnalogRobotRequirements {
			subject robot : PhysicalModel::AnalogRobot;
			doc /* The analog control voltage shall remain within operational range. */
			require constraint {
				robot.controlCircuit.controlVoltage >= 0.0 [V] and
				robot.controlCircuit.controlVoltage <= 10.0 [V]
			}
		}
		
		requirement positionAccuracyRequirement : AnalogRobotRequirements {
			subject robot : PhysicalModel::AnalogRobot;
			doc /* The robot position error shall be less than 0.5 mm. */
			require constraint {
				robot.positionError < 0.5 [mm]
			}
		}
	}
	
	package LogicalModel {
		private import ValueTypes::*;
		
		item def Workpiece {
			attribute mass : ISQ::mass;
		}
		
		action def CalibrateSystem {
			out calibrated : Boolean;
		}
		
		action def GraspObject {
			in object : Workpiece;
			out grasped : Boolean;
		}
		
		action def MoveToPosition {
			in targetPosition : ISQ::length;
			out currentPosition : ISQ::length;
			out positionError : PositionError;
		}
		
		action def ReleaseObject {
			in object : Workpiece;
			out released : Boolean;
		}
		
		action def MonitorPerformance {
			in state : RobotState;
			out completionRate : TaskCompletionRate;
		}
		
		action def ExecutePrimaryTask {
			in taskType : TaskType;
			in workpiece : Workpiece;
			out completionRate : TaskCompletionRate;
			
			first start;
			then action calibrate : CalibrateSystem;
			then decide;
				if calibrate.calibrated then proceedToTask;
				if not calibrate.calibrated then faultHandler;
			action proceedToTask;
			then action moveToPickup : MoveToPosition {
				in targetPosition = 0.0 [m];
			}
			then action grasp : GraspObject {
				in object = workpiece;
			}
			then action moveToPlace : MoveToPosition {
				in targetPosition = 0.5 [m];
			}
			then action release : ReleaseObject {
				in object = workpiece;
			}
			then action monitor : MonitorPerformance {
				in state = RobotState::executing;
			}
			then decide;
				if monitor.completionRate >= 0.95 then taskSuccess;
				if monitor.completionRate < 0.95 then proceedToTask;
			action taskSuccess;
			then done;
			action faultHandler;
			then done;
		}
		
		part def LogicalElement;
		
		part def AnalogRobotFunction :> LogicalElement {
			perform action executeTask : ExecutePrimaryTask;
		}
		
		part analogRobotFunction : AnalogRobotFunction {
			perform executeTask;
		}
		
		satisfy RequirementModel::taskExecutionRequirement by analogRobotFunction;
	}
	
	package PhysicalModel {
		private import ValueTypes::*;
		private import LogicalModel::*;
		
		port def AnalogControlPort {
			attribute voltage : AnalogVoltage;
			attribute current : AnalogCurrent;
		}
		
		port def MechanicalPort {
			attribute position : ISQ::length;
			attribute force : ISQ::force;
			attribute velocity : ISQ::speed;
		}
		
		port def PowerPort {
			attribute supplyVoltage : ISQ::electricPotentialDifference;
			attribute supplyCurrent : ISQ::electricCurrent;
		}
		
		port def FeedbackPort {
			attribute sensorVoltage : AnalogVoltage;
		}
		
		item def ElectricalPower;
		item def ControlSignal;
		
		part def PhysicalElement;
		
		part def AnalogRobot :> PhysicalElement {
			attribute mass : ISQ::mass;
			attribute positionError : PositionError;
			attribute currentState : RobotState;
			
			port controlInput : AnalogControlPort;
			port mechanicalOutput : MechanicalPort;
			port powerInput : PowerPort;
			port feedbackOutput : FeedbackPort;
			
			part controlCircuit {
				attribute controlVoltage : AnalogVoltage;
				item signal : ControlSignal;
				
				part amplifier {
					attribute gain : Real;
					port input : AnalogControlPort;
					port output : AnalogControlPort;
				}
				
				part signalFilter {
					attribute cutoffFrequency : ISQ::frequency;
					port input : AnalogControlPort;
					port output : AnalogControlPort;
				}
				
				part comparator {
					port referenceInput : AnalogControlPort;
					port feedbackInput : FeedbackPort;
					port errorOutput : AnalogControlPort;
				}
				
				connect comparator.errorOutput to amplifier.input;
				connect amplifier.output to signalFilter.input;
			}
			
			part actuatorAssembly {
				attribute maxForce : ISQ::force;
				attribute maxSpeed : ISQ::speed;
				
				part servoMotor {
					attribute torque : ISQ::torque;
					attribute angularVelocity : ISQ::angularVelocity;
					port motorControl : AnalogControlPort;
					port motorOutput : MechanicalPort;
				}
				
				part gearReduction {
					attribute gearRatio : Real;
					port input : MechanicalPort;
					port output : MechanicalPort;
				}
				
				part gripper {
					attribute grippingForce : ISQ::force;
					attribute openingWidth : ISQ::length;
					port mechanicalInterface : MechanicalPort;
					
					state gripperState {
						entry; then openState;
						state openState;
						state closedState;
						state grippingState;
						
						transition graspTransition
							first openState
							then grippingState;
						
						transition secureTransition
							first grippingState
							then closedState;
						
						transition releaseTransition
							first closedState
							then openState;
					}
				}
				
				connect servoMotor.motorOutput to gearReduction.input;
				connect gearReduction.output to gripper.mechanicalInterface;
			}
			
			part sensorSystem {
				part positionSensor {
					attribute resolution : PositionError;
					attribute range : ISQ::length;
					port sensorOutput : FeedbackPort;
				}
				
				part forceSensor {
					attribute sensitivity : Real;
					attribute maxForce : ISQ::force;
					port sensorOutput : FeedbackPort;
				}
				
				part velocitySensor {
					attribute accuracy : Real;
					port sensorOutput : FeedbackPort;
				}
			}
			
			part powerSupply {
				item power : ElectricalPower;
				attribute outputVoltage : ISQ::electricPotentialDifference;
				attribute outputCurrent : ISQ::electricCurrent;
				attribute efficiency : Real;
			}
			
			state robotOperationalState {
				entry; then idleState;
				state idleState;
				state calibratingState;
				state executingState;
				state completedState;
				state faultState;
				
				transition startCalibrationTransition
					first idleState
					then calibratingState;
				
				transition calibrationCompleteTransition
					first calibratingState
					then executingState;
				
				transition taskCompleteTransition
					first executingState
					then completedState;
				
				transition resetTransition
					first completedState
					then idleState;
				
				transition errorDetectedTransition
					first executingState
					then faultState;
				
				transition faultClearedTransition
					first faultState
					then idleState;
			}
			
			perform LogicalModel::analogRobotFunction.executeTask;
		}
		
		part def ControlStation :> PhysicalElement {
			port commandOutput : AnalogControlPort;
			port monitoringInput : FeedbackPort;
			
			part operatorInterface {
				attribute displayResolution : Real;
				attribute inputChannels : Integer;
			}
			
			part signalGenerator {
				attribute outputRange : AnalogVoltage;
				attribute frequency : ISQ::frequency;
				port generatorOutput : AnalogControlPort;
			}
			
			part dataAcquisition {
				attribute samplingRate : ISQ::frequency;
				attribute resolution : Real;
				port dataInput : FeedbackPort;
			}
			
			perform LogicalModel::analogRobotFunction.executeTask.monitor;
		}
		
		part def WorkCell :> PhysicalElement {
			port mechanicalInterface : MechanicalPort;
			
			part workpiece : Workpiece {
				:>> mass = 0.5 [kg];
			}
			
			part fixture {
				attribute clampingForce : ISQ::force;
				attribute positionAccuracy : PositionError;
			}
			
			part safetyEnclosure {
				attribute height : ISQ::length;
				attribute width : ISQ::length;
			}
		}
		
		part def RoboticSystem :> PhysicalElement {
			attribute taskPerformance {
				attribute taskCompletionRate : TaskCompletionRate;
				attribute cycleTime : ISQ::time;
			}
			
			part analogRobot : AnalogRobot {
				:>> mass = 50.0 [kg];
				:>> positionError = 0.3 [mm];
				:>> currentState = RobotState::idle;
				
				part redefines controlCircuit {
					:>> controlVoltage = 5.0 [V];
					
					part redefines amplifier {
						:>> gain = 15.0;
					}
					
					part redefines signalFilter {
						:>> cutoffFrequency = 1500.0 [Hz];
					}
				}
				
				part redefines actuatorAssembly {
					:>> maxForce = 600.0 [N];
					:>> maxSpeed = 2.5 [m/s];
					
					part redefines servoMotor {
						:>> torque = 12.0 [N*m];
						:>> angularVelocity = 3500.0 [rpm];
					}
					
					part redefines gearReduction {
						:>> gearRatio = 60.0;
					}
					
					part redefines gripper {
						:>> grippingForce = 120.0 [N];
						:>> openingWidth = 80.0 [mm];
					}
				}
				
				part redefines sensorSystem {
					part redefines positionSensor {
						:>> resolution = 0.01 [mm];
						:>> range = 1.0 [m];
					}
					
					part redefines forceSensor {
						:>> sensitivity = 0.05;
						:>> maxForce = 200.0 [N];
					}
					
					part redefines velocitySensor {
						:>> accuracy = 0.02;
					}
				}
				
				part redefines powerSupply {
					:>> outputVoltage = 24.0 [V];
					:>> outputCurrent = 8.0 [A];
					:>> efficiency = 0.92;
				}
			}
			
			part controlStation : ControlStation {
				part redefines operatorInterface {
					:>> displayResolution = 1920.0;
					:>> inputChannels = 8;
				}
				
				part redefines signalGenerator {
					:>> outputRange = 10.0 [V];
					:>> frequency = 100.0 [Hz];
				}
				
				part redefines dataAcquisition {
					:>> samplingRate = 10000.0 [Hz];
					:>> resolution = 16.0;
				}
			}
			
			part workCell : WorkCell {
				part redefines fixture {
					:>> clampingForce = 250.0 [N];
					:>> positionAccuracy = 0.1 [mm];
				}
				
				part redefines safetyEnclosure {
					:>> height = 2.0 [m];
					:>> width = 1.5 [m];
				}
			}
			
			connect controlStation.commandOutput to analogRobot.controlInput;
			connect analogRobot.feedbackOutput to controlStation.monitoringInput;
			connect analogRobot.mechanicalOutput to workCell.mechanicalInterface;
			connect analogRobot.sensorSystem.positionSensor.sensorOutput to analogRobot.controlCircuit.comparator.feedbackInput;
		}
		
		part roboticSystem : RoboticSystem;
		
		satisfy RequirementModel::analogControlRequirement by roboticSystem.analogRobot;
		satisfy RequirementModel::positionAccuracyRequirement by roboticSystem.analogRobot;
	}
	
	allocation def LogicalToPhysical {
		end logical : LogicalModel::LogicalElement;
		end physical : PhysicalModel::PhysicalElement;
	}
	
	allocation robotFunctionAllocation : LogicalToPhysical
		allocate logical ::> LogicalModel::analogRobotFunction 
		to physical ::> PhysicalModel::roboticSystem.analogRobot {
		allocate LogicalModel::analogRobotFunction.executeTask 
			to PhysicalModel::roboticSystem.analogRobot.executeTask;
		allocate LogicalModel::analogRobotFunction.executeTask.calibrate 
			to PhysicalModel::roboticSystem.analogRobot.robotOperationalState;
		allocate LogicalModel::analogRobotFunction.executeTask.grasp 
			to PhysicalModel::roboticSystem.analogRobot.actuatorAssembly.gripper.gripperState;
	}
}

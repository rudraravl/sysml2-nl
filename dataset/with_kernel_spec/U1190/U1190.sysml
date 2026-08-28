package AutonomousRoboticAssemblySystem {
	public import Definitions::*;

	private import ScalarValues::*;
	private import Quantities::*;
	private import MeasurementReferences::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		attribute def ComponentPose {
			attribute xPosition :> ISQ::length;
			attribute yPosition :> ISQ::length;
			attribute zPosition :> ISQ::length;
			attribute roll : Real;
			attribute pitch : Real;
			attribute yaw : Real;
		}

		attribute def PathPlan {
			attribute waypoints : ComponentPose[0..*];
			attribute collisionFree : Boolean;
		}

		attribute def InspectionResult {
			attribute passed : Boolean;
			attribute defectDescription : String;
		}

		attribute def GripperCommand {
			attribute gripForce :> ISQ::force;
			attribute release : Boolean;
		}

		item def Component;
		item def ValidComponent :> Component;
		item def AssembledComponent :> Component;

		attribute def ComponentDetected;
		attribute def ValidComponentFound;
		attribute def ScanError;
		attribute def ComponentAcquired;
		attribute def AcquisitionFailed;
		attribute def AssemblyComplete;
		attribute def AssemblyFailed;
		attribute def InspectionPassed;
		attribute def InspectionFailed;
		attribute def FaultCleared;

		part def RoboticArm {
			attribute maxPayload :> ISQ::mass = 15 [kg];
			attribute maxReach :> ISQ::length = 1.5 [m];
			attribute placementAccuracy :> ISQ::length = 0.05 [mm];
		}

		part def PneumaticGripper {
			attribute maxGripForce :> ISQ::force = 50 [N];
		}

		part def AssemblyController;

		part def ComponentFeeder {
			attribute bufferCapacity : Integer = 50;
			attribute currentBufferCount : Integer;
		}

		part def VisionSystem {
			attribute resolution : Real;
		}

		part def AssemblyStation {
			attribute assembledCount : Integer;
		}

		action def ScanFeeder {
			out detectedPose : ComponentPose;
			out componentValid : Boolean;
		}

		action def PlanPath {
			in targetPose : ComponentPose;
			out pathPlan : PathPlan;
		}

		action def MoveArm {
			in pathPlan : PathPlan;
			out currentPose : ComponentPose;
		}

		action def AcquireComponent {
			in component : Component;
			in gripForce : ISQ::force;
			out gripping : Boolean;
		}

		action def PositionComponent {
			in targetPose : ComponentPose;
			out currentPose : ComponentPose;
		}

		action def SecureComponent {
			in force : ISQ::force;
			out secured : Boolean;
		}

		action def InspectAssembly {
			in component : Component;
			out inspectionResult : InspectionResult;
		}

		action def AssembleCycle {
			in component : Component;
			in assemblyTargetPose : ComponentPose;
			in gripForce : ISQ::force;
			in secureForce : ISQ::force;
			out inspectionResult : InspectionResult;
		}

		state machine def AssemblyStateMachine {
			state idle;
			state scanning;
			state acquiring;
			state assembling;
			state inspecting;
			state fault;
			transition idle to scanning;
			transition scanning to acquiring;
			transition scanning to fault;
			transition acquiring to assembling;
			transition acquiring to fault;
			transition assembling to inspecting;
			transition assembling to fault;
			transition inspecting to idle;
			transition inspecting to fault;
			transition fault to idle;
		}

		requirement def RoboticArmSpec {
			attribute maxPayloadReq :> ISQ::mass = 15 [kg];
			attribute maxReachReq :> ISQ::length = 1.5 [m];
			attribute placementAccuracyReq :> ISQ::length = 0.05 [mm];
			doc /* The robotic arm shall handle components up to 15 kg, reach within 1.5 meters, and place components with 0.05 mm accuracy. */
		}

		requirement def FeederSpec {
			attribute bufferCapacityReq : Integer = 50;
			doc /* The feeder shall hold a buffer of up to 50 parts. */
		}

		requirement def VisionSystemSpec {
			doc /* The vision system shall identify component position and orientation and perform quality inspection during and after assembly. */
		}

		requirement def AutomationSpec {
			doc /* The system shall automate assembly without human intervention and enter a fault state on errors or safety violations. */
		}
	}

	package Usages {
		part assemblySystem {
			part controller : AssemblyController {
				port visionInPort {
					in detectedPose : ComponentPose;
					in componentValid : Boolean;
					in inspectionResult : InspectionResult;
				}
				port armCmdOutPort {
					out pathPlan : PathPlan;
					out gripperCommand : GripperCommand;
				}
				port armStatusInPort {
					in currentPose : ComponentPose;
					in payloadMass :> ISQ::mass;
				}
			}

			part arm : RoboticArm {
				port cmdInPort {
					in pathPlan : PathPlan;
					in gripperCommand : GripperCommand;
				}
				port statusOutPort {
					out currentPose : ComponentPose;
					out payloadMass :> ISQ::mass;
				}
				port gripperCmdOutPort {
					out gripperCommand : GripperCommand;
				}

				part gripper : PneumaticGripper {
					port cmdInPort {
						in gripperCommand : GripperCommand;
					}
					port statusOutPort {
						out gripping : Boolean;
						out appliedForce :> ISQ::force;
					}
				}
			}

			part feeder : ComponentFeeder {
				port componentOutPort {
					out component : Component;
				}
			}

			part visionSystem : VisionSystem {
				port visionOutPort {
					out detectedPose : ComponentPose;
					out componentValid : Boolean;
					out inspectionResult : InspectionResult;
				}
			}

			part station : AssemblyStation {
				port componentInPort {
					in component : Component;
				}
			}

			interface visionToController
				connect visionSystem.visionOutPort to controller.visionInPort {
				flow detectedPoseFlow of ComponentPose
					from visionSystem.visionOutPort.detectedPose to controller.visionInPort.detectedPose;
				flow componentValidFlow of Boolean
					from visionSystem.visionOutPort.componentValid to controller.visionInPort.componentValid;
				flow inspectionResultFlow of InspectionResult
					from visionSystem.visionOutPort.inspectionResult to controller.visionInPort.inspectionResult;
			}

			interface controllerToArm
				connect controller.armCmdOutPort to arm.cmdInPort {
				flow pathPlanFlow of PathPlan
					from controller.armCmdOutPort.pathPlan to arm.cmdInPort.pathPlan;
				flow gripperCommandFlow of GripperCommand
					from controller.armCmdOutPort.gripperCommand to arm.cmdInPort.gripperCommand;
			}

			interface armToController
				connect arm.statusOutPort to controller.armStatusInPort {
				flow currentPoseFlow of ComponentPose
					from arm.statusOutPort.currentPose to controller.armStatusInPort.currentPose;
				flow payloadMassFlow of ISQ::MassValue
					from arm.statusOutPort.payloadMass to controller.armStatusInPort.payloadMass;
			}

			interface armToGripper
				connect arm.gripperCmdOutPort to arm.gripper.cmdInPort {
				flow gripperCmdFlow of GripperCommand
					from arm.gripperCmdOutPort.gripperCommand to arm.gripper.cmdInPort.gripperCommand;
			}

			flow componentFlow of Component
				from feeder.componentOutPort.component to station.componentInPort.component;

			perform action assembleCycle : AssembleCycle {
				in component : Component;
				in assemblyTargetPose : ComponentPose;
				in gripForce : ISQ::force;
				in secureForce : ISQ::force;
				out inspectionResult : InspectionResult;

				action scan : ScanFeeder;
				action planPath : PlanPath;
				action moveArm : MoveArm;
				action acquireComp : AcquireComponent;
				action positionComp : PositionComponent;
				action secureComp : SecureComponent;
				action inspectAssy : InspectAssembly;

				flow scan.detectedPose to planPath.targetPose;
				flow planPath.pathPlan to moveArm.pathPlan;
				flow assembleCycle.component to acquireComp.component;
				flow assembleCycle.gripForce to acquireComp.gripForce;
				flow assembleCycle.assemblyTargetPose to positionComp.targetPose;
				flow assembleCycle.secureForce to secureComp.force;
				flow assembleCycle.component to inspectAssy.component;
				bind inspectAssy.inspectionResult = assembleCycle.inspectionResult;

				first start;
				then scan;
				then planPath;
				then moveArm;
				then acquireComp;
				then positionComp;
				then secureComp;
				then inspectAssy;
				then done;
			}

			state machine assemblyState : AssemblyStateMachine;

			requirement armReq : RoboticArmSpec;
			requirement feederReq : FeederSpec;
			requirement visionReq : VisionSystemSpec;
			requirement automationReq : AutomationSpec;
		}
	}
}

package 'Autonomous Robotic Assembly System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def AssemblyCommand;
	attribute def ComponentIdentified;
	attribute def PositionConfirmed;
	attribute def AssemblyComplete;
	attribute def SystemFault;
	
	item def AssemblyComponent {
		attribute partNumber : String;
		attribute mass :> ISQ::mass;
		attribute dimensions : LengthValue[3];
		attribute currentPosition : LengthValue[3];
		attribute targetPosition : LengthValue[3];
		attribute orientation : AngleValue[3];
	}
	
	item def AssemblyTask {
		attribute taskId : String;
		attribute componentList : AssemblyComponent[*] ordered;
		attribute assemblySequence : Integer[*] ordered;
		attribute qualityThreshold : Real;
	}
	
	attribute def JointConfiguration :> ISQ::AngleValue;
	attribute def GripperState :> ScalarValues::Real;
	attribute def ToolForce :> ISQ::ForceValue;
	attribute def WorkspaceCoordinate :> ISQ::LengthValue;
	
	port def VisionPort {
		out imageData : Real[*];
		out componentLocation : LengthValue[3];
		out componentOrientation : AngleValue[3];
		out qualityMetric : Real;
	}
	
	port def ManipulatorPort {
		in targetJointAngles : JointConfiguration[*];
		in targetEndEffectorPose : LengthValue[3];
		out currentJointAngles : JointConfiguration[*];
		out currentEndEffectorPose : LengthValue[3];
		out jointTorques : TorqueValue[*];
	}
	
	port def ToolPort {
		in toolCommand : Real;
		in targetForce : ForceValue;
		out toolState : GripperState;
		out appliedForce : ForceValue;
	}
	
	port def ConveyorPort {
		in conveyorSpeed : SpeedValue;
		out componentPresent : ScalarValues::Boolean;
		out componentPosition : LengthValue;
	}
	
	part def VisionSystem {
		attribute resolution : Integer[2];
		attribute frameRate : FrequencyValue;
		attribute fieldOfView : AngleValue;
		
		port visionOutput : VisionPort;
		
		action captureImage {
			out rawImage : Real[*];
		}
		
		action processImage {
			in rawImage : Real[*];
			out componentData : AssemblyComponent;
		}
		
		action verifyQuality {
			in componentData : AssemblyComponent;
			out qualityScore : Real;
			out passedInspection : ScalarValues::Boolean;
		}
	}
	
	part def RoboticManipulator {
		attribute numberOfJoints : Integer = 6;
		attribute maxReach :> ISQ::length;
		attribute maxPayload :> ISQ::mass;
		attribute repeatability : LengthValue;
		
		port manipulatorInterface : ManipulatorPort;
		
		part baseJoint {
			attribute currentAngle : JointConfiguration;
			attribute targetAngle : JointConfiguration;
			attribute maxVelocity : AngularVelocityValue;
		}
		
		part shoulderJoint {
			attribute currentAngle : JointConfiguration;
			attribute targetAngle : JointConfiguration;
			attribute maxVelocity : AngularVelocityValue;
		}
		
		part elbowJoint {
			attribute currentAngle : JointConfiguration;
			attribute targetAngle : JointConfiguration;
			attribute maxVelocity : AngularVelocityValue;
		}
		
		part wrist1Joint {
			attribute currentAngle : JointConfiguration;
			attribute targetAngle : JointConfiguration;
			attribute maxVelocity : AngularVelocityValue;
		}
		
		part wrist2Joint {
			attribute currentAngle : JointConfiguration;
			attribute targetAngle : JointConfiguration;
			attribute maxVelocity : AngularVelocityValue;
		}
		
		part wrist3Joint {
			attribute currentAngle : JointConfiguration;
			attribute targetAngle : JointConfiguration;
			attribute maxVelocity : AngularVelocityValue;
		}
	}
	
	part def AssemblyTool {
		attribute toolType : String;
		attribute maxGripForce : ForceValue;
		attribute toolWidth : LengthValue;
		
		port toolInterface : ToolPort;
		
		action activateTool {
			in command : Real;
			out toolActivated : ScalarValues::Boolean;
		}
		
		action applyForce {
			in targetForce : ForceValue;
			out actualForce : ForceValue;
		}
		
		action releaseTool {
			out toolReleased : ScalarValues::Boolean;
		}
	}
	
	part def ComponentFeeder {
		attribute feedRate : FrequencyValue;
		attribute bufferCapacity : Integer;
		
		port conveyorInterface : ConveyorPort;
		
		action loadComponent {
			out componentReady : ScalarValues::Boolean;
		}
		
		action advanceConveyor {
			in speed : SpeedValue;
			out newPosition : LengthValue;
		}
	}
	
	part def AssemblyController {
		attribute controlFrequency : FrequencyValue;
		attribute safetyZone : LengthValue[3];
		
		action computeInverseKinematics {
			in targetPose : LengthValue[3];
			in targetOrientation : AngleValue[3];
			out jointAngles : JointConfiguration[6];
		}
		
		action planTrajectory {
			in startPose : LengthValue[3];
			in endPose : LengthValue[3];
			in maxVelocity : SpeedValue;
			in maxAcceleration : AccelerationValue;
			out trajectoryWaypoints : LengthValue[3][*] ordered;
		}
		
		action executeTrajectory {
			in waypoints : LengthValue[3][*] ordered;
			out trajectoryComplete : ScalarValues::Boolean;
		}
		
		action monitorSafety {
			in currentPose : LengthValue[3];
			in appliedForce : ForceValue;
			out safetyViolation : ScalarValues::Boolean;
		}
	}
	
	action def IdentifyComponent {
		in visionData : Real[*];
		out component : AssemblyComponent;
		out componentValid : ScalarValues::Boolean;
	}
	
	action def PlanAssemblySequence {
		in task : AssemblyTask;
		out assemblySteps : AssemblyComponent[*] ordered;
	}
	
	action def NavigateToComponent {
		in componentLocation : LengthValue[3];
		in componentOrientation : AngleValue[3];
		out navigationSuccess : ScalarValues::Boolean;
	}
	
	action def AcquireComponent {
		in gripForce : ForceValue;
		out componentSecured : ScalarValues::Boolean;
	}
	
	action def PositionComponent {
		in targetLocation : LengthValue[3];
		in targetOrientation : AngleValue[3];
		out positioningSuccess : ScalarValues::Boolean;
	}
	
	action def SecureComponent {
		in assemblyForce : ForceValue;
		out componentAssembled : ScalarValues::Boolean;
	}
	
	action def InspectAssembly {
		out inspectionPassed : ScalarValues::Boolean;
		out qualityScore : Real;
	}
	
	action def AssemblyOperation {
		in assemblyTask : AssemblyTask;
		in pickupZone : LengthValue[3];
		in assemblyZone : LengthValue[3];
		in homePosition : LengthValue[3];
		out operationSuccess : ScalarValues::Boolean;
		
		private attribute currentComponent : AssemblyComponent;
		private attribute stepIndex : Integer := 0;
		private attribute qualityAcceptable : ScalarValues::Boolean := false;
		
		first start;
		then merge beginAssembly;
		
		then action planSequence : PlanAssemblySequence {
			in task = assemblyTask;
			out assemblySteps : AssemblyComponent[*] ordered;
		}
		
		then merge processNextComponent;
		
		then decide;
			if stepIndex < 5 then continueAssembly;
			if stepIndex >= 5 then finalInspection;
		
		action continueAssembly {
			action identifyComponent : IdentifyComponent {
				out component : AssemblyComponent;
				out componentValid : ScalarValues::Boolean;
			}
			
			then decide;
				if identifyComponent.componentValid then proceedToAcquire;
				if !identifyComponent.componentValid then rejectComponent;
			
			action proceedToAcquire {
				action navigateToPickup : NavigateToComponent {
					in componentLocation = pickupZone;
					in componentOrientation = (0.0, 0.0, 0.0) [SI::rad];
					out navigationSuccess : ScalarValues::Boolean;
				}
				
				then action acquireComponent : AcquireComponent {
					in gripForce = 75.0 [SI::N];
					out componentSecured : ScalarValues::Boolean;
				}
				
				then decide;
					if acquireComponent.componentSecured then transportComponent;
					if !acquireComponent.componentSecured then retryAcquisition;
			}
			
			action transportComponent {
				action navigateToAssembly : NavigateToComponent {
					in componentLocation = assemblyZone;
					in componentOrientation = (0.0, 0.0, 0.0) [SI::rad];
					out navigationSuccess : ScalarValues::Boolean;
				}
				
				then action positionComponent : PositionComponent {
					in targetLocation = assemblyZone;
					in targetOrientation = (0.0, 0.0, 0.0) [SI::rad];
					out positioningSuccess : ScalarValues::Boolean;
				}
				
				then action secureComponent : SecureComponent {
					in assemblyForce = 120.0 [SI::N];
					out componentAssembled : ScalarValues::Boolean;
				}
				
				then decide;
					if secureComponent.componentAssembled then verifyPlacement;
					if !secureComponent.componentAssembled then handleAssemblyFailure;
			}
			
			action verifyPlacement {
				action inspectPlacement : InspectAssembly {
					out inspectionPassed : ScalarValues::Boolean;
					out qualityScore : Real;
				}
				
				then decide;
					if inspectPlacement.inspectionPassed then incrementStep;
					if !inspectPlacement.inspectionPassed then handleQualityFailure;
			}
			
			action incrementStep {
				then assign stepIndex := stepIndex + 1;
				then processNextComponent;
			}
			
			action retryAcquisition {
				then processNextComponent;
			}
			
			action handleAssemblyFailure {
				then processNextComponent;
			}
			
			action handleQualityFailure {
				then processNextComponent;
			}
			
			action rejectComponent {
				then processNextComponent;
			}
		}
		
		action finalInspection {
			action performFinalInspection : InspectAssembly {
				out inspectionPassed : ScalarValues::Boolean;
				out qualityScore : Real;
			}
			
			then decide;
				if performFinalInspection.inspectionPassed then returnHome;
				if !performFinalInspection.inspectionPassed then handleFinalFailure;
		}
		
		action returnHome {
			action navigateHome : NavigateToComponent {
				in componentLocation = homePosition;
				in componentOrientation = (0.0, 0.0, 0.0) [SI::rad];
				out navigationSuccess : ScalarValues::Boolean;
			}
			
			then assign operationSuccess := true;
			then done;
		}
		
		action handleFinalFailure {
			then assign operationSuccess := false;
			then done;
		}
	}
	
	part autonomousAssemblySystem {
		attribute workspaceVolume : VolumeValue;
		attribute cycleTime : TimeValue;
		attribute throughput : FrequencyValue;
		
		part visionSystem : VisionSystem {
			attribute resolution = (1920, 1080);
			attribute frameRate = 60.0 [SI::Hz];
			attribute fieldOfView = 45.0 [SI::deg];
			
			perform action identifyComponents : IdentifyComponent;
			perform action inspectQuality : InspectAssembly;
		}
		
		part manipulator : RoboticManipulator {
			attribute maxReach = 1.5 [SI::m];
			attribute maxPayload = 15.0 [SI::kg];
			attribute repeatability = 0.05 [SI::mm];
		}
		
		part assemblyTool : AssemblyTool {
			attribute toolType = "pneumatic_gripper";
			attribute maxGripForce = 150.0 [SI::N];
			attribute toolWidth = 80.0 [SI::mm];
		}
		
		part feeder : ComponentFeeder {
			attribute feedRate = 10.0 [SI::Hz];
			attribute bufferCapacity = 50;
		}
		
		part controller : AssemblyController {
			attribute controlFrequency = 100.0 [SI::Hz];
			attribute safetyZone = (2.0, 2.0, 2.0) [SI::m];
			
			perform action executeAssembly : AssemblyOperation;
		}
		
		connect visionSystem.visionOutput to controller;
		connect controller to manipulator.manipulatorInterface;
		connect manipulator.manipulatorInterface to assemblyTool.toolInterface;
		connect feeder.conveyorInterface to controller;
	}
	
	requirement def FunctionalRequirement;
	requirement def PerformanceRequirement;
	requirement def SafetyRequirement;
	requirement def QualityRequirement;
	
	requirement primaryFunction {
		doc /* The autonomous robotic assembly system shall perform automated assembly operations 
		     by identifying components, acquiring them from a feeder, positioning them precisely, 
		     and securing them to create complete assemblies without human intervention. */
		subject autonomousAssemblySystem;
	}
	
	requirement cycleTimeRequirement {
		doc /* The system shall complete a full assembly cycle within 8 seconds from component 
		     identification to final placement and inspection. */
		subject autonomousAssemblySystem.controller.executeAssembly;
	}
	
	requirement throughputRequirement {
		doc /* The system shall achieve a minimum throughput of 400 assemblies per hour 
		     during continuous operation. */
		subject autonomousAssemblySystem;
	}
	
	requirement positioningAccuracy {
		doc /* The manipulator shall position components with an accuracy of ±0.1mm 
		     in all three spatial dimensions. */
		subject autonomousAssemblySystem.manipulator;
	}
	
	requirement forceLimit {
		doc /* The assembly tool shall not apply forces exceeding 150N to prevent 
		     component damage and ensure operator safety. */
		subject autonomousAssemblySystem.assemblyTool;
	}
	
	requirement emergencyStop {
		doc /* The system shall halt all motion within 50ms upon detection of a safety 
		     violation or emergency stop signal. */
		subject autonomousAssemblySystem.controller;
	}
	
	requirement inspectionRequirement {
		doc /* Every assembled component shall undergo automated vision inspection with 
		     a minimum quality score of 95% before proceeding to the next assembly step. */
		subject autonomousAssemblySystem.visionSystem;
	}
	
	requirement assemblyQuality {
		doc /* The system shall achieve a first-pass assembly success rate of at least 98% 
		     for all component types within specification. */
		subject autonomousAssemblySystem;
	}
	
	requirement <'ARAS-001'> systemRequirement {
		doc /* The autonomous robotic assembly system shall reliably perform high-precision 
		     assembly operations with minimal human intervention, meeting all functional, 
		     performance, safety, and quality requirements. */
		
		subject autonomousAssemblySystem;
		
		assume constraint workspaceConstraint {
			doc /* All components are presented within the reachable workspace of the manipulator. */
		}
		
		assume constraint componentConstraint {
			doc /* Component mass does not exceed the maximum payload capacity of the manipulator. */
		}
		
		assume constraint environmentConstraint {
			doc /* The operating environment maintains stable lighting and temperature conditions. */
		}
		
		require primaryFunction;
		require cycleTimeRequirement;
		require throughputRequirement;
		require positioningAccuracy;
		require forceLimit;
		require emergencyStop;
		require inspectionRequirement;
		require assemblyQuality;
	}
	
	state def AssemblySystemStates {
		entry; then idle;
		
		state idle {
			entry assign systemStatus = "System Ready";
		}
		accept AssemblyCommand
		then initializing;
		
		state initializing {
			entry assign systemStatus = "Initializing Assembly";
		}
		then scanning;
		
		state scanning {
			entry assign systemStatus = "Scanning for Components";
			do action scanWorkspace : IdentifyComponent;
		}
		accept ComponentIdentified
		then planning;
		
		state planning {
			entry assign systemStatus = "Planning Assembly Sequence";
			do action planSequence : PlanAssemblySequence;
		}
		then acquiring;
		
		state acquiring {
			entry assign systemStatus = "Acquiring Component";
			do action acquireAction : AcquireComponent;
		}
		then transporting;
		
		state transporting {
			entry assign systemStatus = "Transporting Component";
			do action transportAction : NavigateToComponent;
		}
		accept PositionConfirmed
		then assembling;
		
		state assembling {
			entry assign systemStatus = "Assembling Component";
			do action assembleAction : SecureComponent;
		}
		then inspecting;
		
		state inspecting {
			entry assign systemStatus = "Inspecting Assembly";
			do action inspectAction : InspectAssembly;
		}
		accept AssemblyComplete
		then decide;
			if moreComponentsToAssemble then scanning;
			if allComponentsAssembled then completing;
		
		state completing {
			entry assign systemStatus = "Completing Assembly";
		}
		then idle;
		
		accept SystemFault
		then fault;
		
		state fault {
			entry assign systemStatus = "System Fault - Intervention Required";
		}
		then idle;
		
		attribute systemStatus : String;
		attribute moreComponentsToAssemble : ScalarValues::Boolean;
		attribute allComponentsAssembled : ScalarValues::Boolean;
	}
}

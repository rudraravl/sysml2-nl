package MobileServicingSystem {
    attribute def deployCommand;
    attribute def positionReached;
    attribute def repositionCommand;
    attribute def moveCommand;
    attribute def targetReached;
    attribute def graspConfirmed;
    attribute def destinationReached;
    attribute def releaseComplete;
    attribute def faultCleared;
    attribute def latchCommand;
    attribute def contactDetected;
    attribute def releaseCommand;
    attribute def fullyOpen;
    attribute def missionCommandReceived;
    attribute def basePositioned;
    attribute def targetAcquired;
    attribute def serviceComplete;
    attribute def homeReached;
    attribute def emergencyStop;
    attribute def systemReset;

	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def OperationalMode;
	attribute def SystemHealth;
	
	attribute def Position3D {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}
	
	attribute def Orientation {
		attribute roll : ISQ::AngleValue;
		attribute pitch : ISQ::AngleValue;
		attribute yaw : ISQ::AngleValue;
	}
	
	attribute def Pose {
		attribute position : Position3D;
		attribute orientation : Orientation;
	}
	
	item def PowerSupply {
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute current : ISQ::ElectricCurrentValue;
		attribute power : ISQ::PowerValue;
	}
	
	item def CommandMessage {
		attribute targetPose : Pose;
		attribute operationMode : String;
		attribute priority : Integer;
	}
	
	item def TelemetryMessage {
		attribute currentPose : Pose;
		attribute jointAngles : ISQ::AngleValue[7];
		attribute systemStatus : String;
		attribute healthMetric : Real;
	}
	
	item def PayloadData {
		attribute mass : ISQ::MassValue;
		attribute dimensions : ISQ::LengthValue[3];
		attribute graspForce : ISQ::ForceValue;
	}
	
	port def PowerPort {
		in item powerIn : PowerSupply;
	}
	
	port def CommandPort {
		in item cmdIn : CommandMessage;
		out item telemetryOut : TelemetryMessage;
	}
	
	port def MechanicalInterface {
		out item appliedForce : ISQ::force;
		in item reactionForce : ISQ::force;
	}
	
	part def MobileBase {
		attribute maxTranslationSpeed : ISQ::SpeedValue;
		attribute maxRotationSpeed : ISQ::AngularSpeedValue;
		attribute currentPosition : Position3D;
		
		port basePower : PowerPort;
		port baseControl : CommandPort;
		port baseMount : MechanicalInterface;
		
		perform action translateBase {
			in targetPosition : Position3D;
			out finalPosition : Position3D;
		}
		
		state def BaseStateMachine {
			entry; then stowed;
			
			state stowed;
			state translating;
			state stationary;
			
			transition stowed_to_translating
				first stowed
				accept deployCommand
				then translating;
			
			transition translating_to_stationary
				first translating
				accept positionReached
				then stationary;
			
			transition stationary_to_translating
				first stationary
				accept repositionCommand
				then translating;
		}
		
		exhibit state baseStateBehavior : BaseStateMachine;
	}
	
	part def ManipulatorArm {
		attribute numberOfJoints : Integer;
		attribute maxReach : ISQ::LengthValue;
		attribute maxPayloadMass : ISQ::MassValue;
		attribute endEffectorPose : Pose;
		
		port armPower : PowerPort;
		port armControl : CommandPort;
		port endEffectorInterface : MechanicalInterface;
		
		perform action moveToTarget {
			in targetPose : Pose;
			out achievedPose : Pose;
			out positionError : ISQ::LengthValue;
		}
		
		perform action applyForce {
			in desiredForce : ISQ::ForceValue;
			out actualForce : ISQ::ForceValue;
		}
		
		state def ArmStateMachine {
			entry; then idle;
			
			state idle;
			state positioning;
			state grasping;
			state transferring;
			state releasing;
			state fault;
			
			transition idle_to_positioning
				first idle
				accept moveCommand
				then positioning;
			
			transition positioning_to_grasping
				first positioning
				accept targetReached
				then grasping;
			
			transition grasping_to_transferring
				first grasping
				accept graspConfirmed
				then transferring;
			
			transition transferring_to_releasing
				first transferring
				accept destinationReached
				then releasing;
			
			transition releasing_to_idle
				first releasing
				accept releaseComplete
				then idle;
			
			transition any_to_fault
				first idle, positioning, grasping, transferring, releasing
				accept errorDetected
				then fault;
			
			transition fault_to_idle
				first fault
				accept faultCleared
				then idle;
		}
		
		exhibit state armStateBehavior : ArmStateMachine;
	}
	
	part def VisionSensor {
		attribute resolution : Integer[2];
		attribute frameRate : ISQ::FrequencyValue;
		attribute fieldOfView : ISQ::AngleValue;
		
		port sensorPower : PowerPort;
		port sensorControl : CommandPort;
		
		perform action captureImage {
			out imageData : String;
			out timestamp : ISQ::TimeValue;
		}
		
		perform action detectTarget {
			out targetDetected : Boolean;
			out targetPose : Pose;
			out confidence : Real;
		}
		
		perform action trackObject {
			in objectPose : Pose;
			out trackingActive : Boolean;
			out updatedPose : Pose;
		}
	}
	
	part def LatchingEndEffector {
		attribute maxGraspForce : ISQ::ForceValue;
		attribute graspDiameter : ISQ::LengthValue[2];
		attribute isLatched : Boolean;
		
		port effectorPower : PowerPort;
		port effectorControl : CommandPort;
		port graspInterface : MechanicalInterface;
		
		perform action latch {
			in targetObject : PayloadData;
			out latchSuccess : Boolean;
			out appliedForce : ISQ::ForceValue;
		}
		
		perform action release {
			out releaseSuccess : Boolean;
		}
		
		state def LatchStateMachine {
			entry; then open;
			
			state open;
			state closing;
			state latched;
			state opening;
			
			transition open_to_closing
				first open
				accept latchCommand
				then closing;
			
			transition closing_to_latched
				first closing
				accept contactDetected
				then latched;
			
			transition latched_to_opening
				first latched
				accept releaseCommand
				then opening;
			
			transition opening_to_open
				first opening
				accept fullyOpen
				then open;
		}
		
		exhibit state latchStateBehavior : LatchStateMachine;
	}
	
	part def ControlComputer {
		attribute processingCapacity : ISQ::FrequencyValue;
		attribute memorySize : Real;
		
		port computerPower : PowerPort;
		port systemCommand : CommandPort;
		
		perform action planTrajectory {
			in startPose : Pose;
			in endPose : Pose;
			out waypoints : Pose[*];
			out trajectoryValid : Boolean;
		}
		
		perform action coordinateSubsystems {
			in visionData : Pose;
			in armStatus : TelemetryMessage;
			out baseCommand : CommandMessage;
			out armCommand : CommandMessage;
		}
		
		perform action monitorHealth {
			in subsystemTelemetry : TelemetryMessage[*];
			out overallHealth : Real;
			out faultDetected : Boolean;
		}
	}
	
	part def PowerDistributionUnit {
		attribute inputVoltage : ISQ::ElectricPotentialValue;
		attribute totalCapacity : ISQ::PowerValue;
		attribute currentLoad : ISQ::PowerValue;
		attribute efficiency : Real;
		
		port primaryPower : PowerPort;
		port basePowerOut : PowerPort;
		port armPowerOut : PowerPort;
		port visionPowerOut : PowerPort;
		port computerPowerOut : PowerPort;
		port effectorPowerOut : PowerPort;
		
		perform action distributePower {
			in totalDemand : ISQ::PowerValue;
			out powerAvailable : Boolean;
			out allocatedPower : ISQ::PowerValue[5];
		}
		
		perform action regulateVoltage {
			in inputVoltage : ISQ::ElectricPotentialValue;
			out outputVoltage : ISQ::ElectricPotentialValue[5];
		}
	}
	
	action def PerformServiceMission {
		in missionCommand : CommandMessage;
		out missionStatus : TelemetryMessage;
		
		first start;
		then action receiveCommand {
			in command : CommandMessage;
			out validatedCommand : CommandMessage;
		}
		then action planMission {
			in command : CommandMessage = receiveCommand.validatedCommand;
			out baseTarget : Position3D;
			out armTarget : Pose;
		}
		then merge executeMission;
		then action positionBase {
			in targetPosition : Position3D = planMission.baseTarget;
			out basePositioned : Boolean;
		}
		then action acquireTarget {
			out targetFound : Boolean;
			out targetPose : Pose;
		}
		then decide;
			if acquireTarget.targetFound then proceedToGrasp;
			if not acquireTarget.targetFound then searchAgain;
		action searchAgain {
			out searchComplete : Boolean;
		}
		then executeMission;
		action proceedToGrasp {
			in targetPose : Pose = acquireTarget.targetPose;
			out armMoved : Boolean;
		}
		then action graspPayload {
			in armReady : Boolean = proceedToGrasp.armMoved;
			out graspSuccessful : Boolean;
		}
		then decide;
			if graspPayload.graspSuccessful then transferPayload;
			if not graspPayload.graspSuccessful then retryGrasp;
		action retryGrasp {
			out retryInitiated : Boolean;
		}
		then executeMission;
		action transferPayload {
			in payloadGrasped : Boolean = graspPayload.graspSuccessful;
			out transferComplete : Boolean;
		}
		then action releasePayload {
			in transferDone : Boolean = transferPayload.transferComplete;
			out releaseSuccessful : Boolean;
		}
		then action returnToHome {
			out homeReached : Boolean;
		}
		then action reportStatus {
			out status : TelemetryMessage;
		}
		then done;
	}
	
	state def MSSOperationalStates {
		entry; then standby;
		
		state standby {
			entry assign mode = "Standby";
		}
		
		transition standby_to_active
			first standby
			accept missionCommandReceived
			then active;
		
		state active {
			entry assign mode = "Active";
			
			state positioning;
			state acquiring;
			state servicing;
			state returning;
			
			transition start_positioning
				first active
				then positioning;
			
			transition positioning_to_acquiring
				first positioning
				accept basePositioned
				then acquiring;
			
			transition acquiring_to_servicing
				first acquiring
				accept targetAcquired
				then servicing;
			
			transition servicing_to_returning
				first servicing
				accept serviceComplete
				then returning;
			
			transition returning_to_standby
				first returning
				accept homeReached
				then standby;
		}
		
		transition active_to_safing
			first active
			accept emergencyStop
			then safing;
		
		state safing {
			entry assign mode = "Safing";
		}
		
		transition safing_to_standby
			first safing
			accept systemReset
			then standby;
	}
	
	part def MobileServicingSystem {
		attribute systemMode : String;
		attribute missionCount : Integer;
		
		port externalPower : PowerPort;
		port groundCommand : CommandPort;
		
		part base : MobileBase;
		part arm : ManipulatorArm;
		part vision : VisionSensor;
		part endEffector : LatchingEndEffector;
		part controller : ControlComputer;
		part powerDistribution : PowerDistributionUnit;
		
		connection externalPowerConnection connect 
			externalPower to powerDistribution.primaryPower;
		
		connection basePowerConnection connect 
			powerDistribution.basePowerOut to base.basePower;
		
		connection armPowerConnection connect 
			powerDistribution.armPowerOut to arm.armPower;
		
		connection visionPowerConnection connect 
			powerDistribution.visionPowerOut to vision.sensorPower;
		
		connection effectorPowerConnection connect 
			powerDistribution.effectorPowerOut to endEffector.effectorPower;
		
		connection computerPowerConnection connect 
			powerDistribution.computerPowerOut to controller.computerPower;
		
		connection commandConnection connect 
			groundCommand to controller.systemCommand;
		
		connection armEndEffectorConnection connect 
			arm.endEffectorInterface to endEffector.graspInterface;
		
		connection baseMountConnection connect 
			base.baseMount to arm.endEffectorInterface;
		
		perform action serviceMission[*] ordered references PerformServiceMission {
			in missionCommand;
			out missionStatus;
		}
		
		exhibit state operationalBehavior : MSSOperationalStates;
	}
	
	part mobileServicingSystem : MobileServicingSystem {
		attribute :>> systemMode = "Standby";
		attribute :>> missionCount = 0;
		
		part base {
			attribute :>> maxTranslationSpeed = 0.5 [m/s];
			attribute :>> maxRotationSpeed = 0.2 [rad/s];
		}
		
		part arm {
			attribute :>> numberOfJoints = 7;
			attribute :>> maxReach = 17.6 [m];
			attribute :>> maxPayloadMass = 116000.0 [kg];
		}
		
		part vision {
			attribute :>> resolution = (1920, 1080);
			attribute :>> frameRate = 30.0 [Hz];
			attribute :>> fieldOfView = 75.0 [deg];
		}
		
		part endEffector {
			attribute :>> maxGraspForce = 15000.0 [N];
			attribute :>> graspDiameter = (0.05, 0.30) [m];
		}
		
		part controller {
			attribute :>> processingCapacity = 2.5e9 [Hz];
			attribute :>> memorySize = 128.0;
		}
		
		part powerDistribution {
			attribute :>> inputVoltage = 120.0 [V];
			attribute :>> totalCapacity = 2500.0 [W];
			attribute :>> efficiency = 0.94;
		}
	}
	
	requirement <'MSS-REQ-001'> primaryFunctionRequirement {
		doc /* The Mobile Servicing System shall autonomously position itself and manipulate 
		     payloads to perform servicing, maintenance, and assembly operations in space 
		     environments using vision-guided robotic manipulation. */
		
		subject mobileServicingSystem;
		
		require constraint mobilityCapability {
			mobileServicingSystem.base.maxTranslationSpeed >= 0.3 [m/s]
		}
		
		require constraint manipulationReach {
			mobileServicingSystem.arm.maxReach >= 15.0 [m]
		}
		
		require constraint payloadCapacity {
			mobileServicingSystem.arm.maxPayloadMass >= 100000.0 [kg]
		}
		
		require constraint visionGuidance {
			mobileServicingSystem.vision.fieldOfView >= 60.0 [deg]
		}
	}
	
	requirement <'MSS-REQ-002'> autonomousOperationRequirement {
		doc /* The system shall execute complete service missions autonomously from command 
		     receipt through task completion and return to home position. */
		
		subject mobileServicingSystem.serviceMission;
		
		assume constraint commandAvailable {
			mobileServicingSystem.serviceMission.missionCommand != null
		}
		
		require constraint missionCompletion {
			mobileServicingSystem.serviceMission.missionStatus.systemStatus == "Complete"
		}
	}
	
	requirement <'MSS-REQ-003'> powerManagementRequirement {
		doc /* The power distribution unit shall supply power to all subsystems with 
		     minimum 90% efficiency and maintain voltage regulation within 5% tolerance. */
		
		subject mobileServicingSystem.powerDistribution;
		
		require constraint efficiencyTarget {
			mobileServicingSystem.powerDistribution.efficiency >= 0.90
		}
		
		require constraint capacityLimit {
			mobileServicingSystem.powerDistribution.currentLoad <= 
			mobileServicingSystem.powerDistribution.totalCapacity
		}
	}
	
	requirement <'MSS-REQ-004'> coordinatedControlRequirement {
		doc /* The control computer shall coordinate all subsystems to achieve integrated 
		     mission execution with real-time trajectory planning and health monitoring. */
		
		subject mobileServicingSystem.controller;
		
		require constraint trajectoryPlanning {
			mobileServicingSystem.controller.planTrajectory != null
		}
		
		require constraint healthMonitoring {
			mobileServicingSystem.controller.monitorHealth != null
		}
		
		require constraint subsystemCoordination {
			mobileServicingSystem.controller.coordinateSubsystems != null
		}
	}
	
	requirement <'MSS-REQ-005'> graspingCapabilityRequirement {
		doc /* The latching end effector shall securely grasp and release payloads with 
		     controlled force application and positive latch confirmation. */
		
		subject mobileServicingSystem.endEffector;
		
		require constraint graspForce {
			mobileServicingSystem.endEffector.maxGraspForce >= 10000.0 [N]
		}
		
		require constraint graspRange {
			mobileServicingSystem.endEffector.graspDiameter[1] >= 0.05 [m] and
			mobileServicingSystem.endEffector.graspDiameter[2] <= 0.35 [m]
		}
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import MobileServicingSystem::*;

    part testSubject : MobileBase {
        exhibit state baseStateBehavior : BaseStateMachine;
    }

    action orchestrator {
        item testMissionCommand : CommandMessage {
            attribute targetPose : Pose {
                attribute position : Position3D {
                    attribute x : LengthValue;
                    attribute y : LengthValue;
                    attribute z : LengthValue;
                }
                attribute orientation : Orientation {
                    attribute roll : ISQ::AngleValue;
                    attribute pitch : ISQ::AngleValue;
                    attribute yaw : ISQ::AngleValue;
                }
            }
            attribute operationMode = "";
            attribute priority = 0;
        }
        item testCommand : CommandMessage {
            attribute targetPose : Pose {
                attribute position : Position3D {
                    attribute x : LengthValue;
                    attribute y : LengthValue;
                    attribute z : LengthValue;
                }
                attribute orientation : Orientation {
                    attribute roll : ISQ::AngleValue;
                    attribute pitch : ISQ::AngleValue;
                    attribute yaw : ISQ::AngleValue;
                }
            }
            attribute operationMode = "";
            attribute priority = 0;
        }
        attribute testTargetPosition : Position3D {
            attribute x : LengthValue;
            attribute y : LengthValue;
            attribute z : LengthValue;
        }
        attribute testTargetPose : Pose {
            attribute position : Position3D {
                attribute x : LengthValue;
                attribute y : LengthValue;
                attribute z : LengthValue;
            }
            attribute orientation : Orientation {
                attribute roll : ISQ::AngleValue;
                attribute pitch : ISQ::AngleValue;
                attribute yaw : ISQ::AngleValue;
            }
        }
        action actionProbe : PerformServiceMission {
            in missionCommand = testMissionCommand;
            in command = testCommand;
            in command = testCommand;
            in targetPosition = testTargetPosition;
            in targetPose = testTargetPose;
            in armReady = false;
            in payloadGrasped = false;
            in transferDone = false;
        }
        attribute testDeployCommand : deployCommand;
        attribute testPositionReached : positionReached;
        attribute testRepositionCommand : repositionCommand;
        action triggerdeployCommand send testDeployCommand to testSubject.baseStateBehavior;
        action triggerpositionReached send testPositionReached to testSubject.baseStateBehavior;
        action triggerrepositionCommand send testRepositionCommand to testSubject.baseStateBehavior;
        first actionProbe;
        then triggerdeployCommand;
        then triggerpositionReached;
        then triggerrepositionCommand;
    }
}

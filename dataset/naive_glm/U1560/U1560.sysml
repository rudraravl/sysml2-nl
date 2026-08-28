package MSS {
    import ScalarValues::*;

    // ===== Unit Definitions =====
    unit m;
    unit t;
    unit N;
    unit Nm;
    unit V;
    unit A;
    unit W;
    unit rad;
    unit Hz;

    // ===== Value Type Definitions =====
    value def ReachDistance :> Real { unit = m; }
    value def PayloadMass :> Real { unit = t; }
    value def JointTorque :> Real { unit = Nm; }
    value def LatchForce :> Real { unit = N; }
    value def Voltage :> Real { unit = V; }
    value def Current :> Real { unit = A; }
    value def Power :> Real { unit = W; }
    value def AngularPosition :> Real { unit = rad; }
    value def LinearPosition :> Real { unit = m; }
    value def Frequency :> Real { unit = Hz; }

    // ===== Item Definitions =====
    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def MissionCommand {
        attribute commandId : String;
        attribute sourceLocation : String;
        attribute destinationLocation : String;
        attribute payloadId : String;
        attribute taskType : String;
    }

    item def TelemetryData {
        attribute timestamp : String;
        attribute healthStatus : String;
        attribute basePosition : LinearPosition;
        attribute armConfiguration : String;
    }

    item def ImageData {
        attribute resolution : String;
        attribute frameRate : Frequency;
        attribute timestamp : String;
    }

    item def TargetPose {
        attribute positionX : LinearPosition;
        attribute positionY : LinearPosition;
        attribute positionZ : LinearPosition;
        attribute orientationRoll : AngularPosition;
        attribute orientationPitch : AngularPosition;
        attribute orientationYaw : AngularPosition;
        attribute confidence : Real;
    }

    item def TrajectoryPlan {
        attribute planId : String;
        attribute basePath : String;
        attribute armJointPath : String;
        attribute estimatedDuration : Real;
    }

    item def HealthStatus {
        attribute componentId : String;
        attribute status : String;
        attribute temperature : Real;
        attribute powerConsumption : Power;
    }

    // ===== Port Definitions =====
    port def PowerPort {
        inout power : ElectricalPower;
    }

    port def CommandPort {
        in command : MissionCommand;
        out telemetry : TelemetryData;
    }

    port def ImagePort {
        inout image : ImageData;
    }

    port def ControlPort {
        inout trajectory : TrajectoryPlan;
        inout feedback : TelemetryData;
    }

    // ===== Connection Definitions =====
    connection def PowerConnection {
        end supplier : PowerPort;
        end consumer : PowerPort;
    }

    connection def DataConnection {
        end source : Port;
        end destination : Port;
    }

    // ===== Requirement Definitions =====
    requirement def ReachRequirement {
        attribute minReach : ReachDistance = 17.0;
        subject arm : ManipulatorArm;
        require arm.maxReach >= minReach;
    }

    requirement def PayloadCapacityRequirement {
        attribute minPayload : PayloadMass = 100.0;
        subject arm : ManipulatorArm;
        require arm.maxPayload >= minPayload;
    }

    requirement def JointCountRequirement {
        attribute requiredJoints : Integer = 7;
        subject arm : ManipulatorArm;
        require arm.jointCount == requiredJoints;
    }

    requirement def LatchForceRequirement {
        attribute minLatchForce : LatchForce = 5000.0;
        subject effector : LatchingEndEffector;
        require effector.maxLatchForce >= minLatchForce;
    }

    requirement def PowerStabilityRequirement {
        attribute nominalVoltage : Voltage = 120.0;
        subject pdu : PowerDistributionUnit;
        require pdu.outputVoltage == nominalVoltage;
    }

    requirement def VisionResolutionRequirement {
        attribute minResolution : String = "3840x2160";
        subject sensor : VisionSensor;
        require sensor.resolution == minResolution;
    }

    requirement def MissionSequenceRequirement {
        subject system : MobileServicingSystem;
        require system.operationalStates.Standby.oclIsKindOf(State) and
               system.operationalStates.Active.oclIsKindOf(State) and
               system.operationalStates.Safing.oclIsKindOf(State);
    }

    // ===== Sub-Component Part Definitions =====
    part def Joint {
        attribute jointId : Integer;
        attribute currentPosition : AngularPosition = 0.0;
        attribute maxTorque : JointTorque = 5000.0;
        attribute maxSpeed : AngularPosition = 0.5;

        port powerIn : PowerPort;
        port controlIn : ControlPort;

        action rotate {
            in targetPosition : AngularPosition;
            in maxVelocity : AngularPosition;
            out positionReached : Boolean;
        }

        action hold {
            out holdStatus : String;
        }
    }

    part def CameraUnit {
        attribute sensorType : String = "CMOS";
        attribute resolution : String = "4096x2160";
        attribute frameRate : Frequency = 30.0;

        port powerIn : PowerPort;
        port imageOut : ImagePort;

        action captureFrame {
            out image : ImageData;
        }
    }

    part def ImageProcessor {
        attribute processorType : String = "FPGA";
        attribute processingSpeed : Frequency = 500.0;

        port powerIn : PowerPort;
        port imageIn : ImagePort;
        port controlIn : ControlPort;

        action processImage {
            in image : ImageData;
            out processedData : ImageData;
        }
    }

    part def LatchMechanism {
        attribute mechanismType : String = "snare_cable";
        attribute maxForce : LatchForce = 8000.0;
        attribute isEngaged : Boolean = false;

        port powerIn : PowerPort;
        port controlIn : ControlPort;

        action engage {
            in requiredForce : LatchForce;
            out engageStatus : String;
        }

        action release {
            out releaseStatus : String;
        }
    }

    part def BrakeAssembly {
        attribute brakeType : String = "electromechanical";
        attribute maxHoldForce : LatchForce = 15000.0;
        attribute isEngaged : Boolean = true;

        port powerIn : PowerPort;
        port controlIn : ControlPort;

        action engage {
            out engageStatus : String;
        }

        action release {
            out releaseStatus : String;
        }
    }

    // ===== Component Part Definitions =====
    part def MobileBase {
        attribute maxSpeed : Real = 0.5;
        attribute currentPosition : LinearPosition = 0.0;
        attribute holdForce : LatchForce = 10000.0;
        attribute isSecured : Boolean = false;
        attribute trackLength : ReachDistance = 3.0;

        port powerIn : PowerPort;
        port controlIn : ControlPort;

        part brakeAssembly : BrakeAssembly;

        action moveToWorksite {
            in targetLocation : LinearPosition;
            in trajectory : TrajectoryPlan;
            out arrivalStatus : String;
        }

        action holdPosition {
            out holdStatus : String;
        }

        action engageBrakes {
            out brakeStatus : String;
        }

        action releaseBrakes {
            out releaseStatus : String;
        }
    }

    part def ManipulatorArm {
        attribute jointCount : Integer = 7;
        attribute maxReach : ReachDistance = 18.0;
        attribute maxPayload : PayloadMass = 120.0;
        attribute maxJointTorque : JointTorque = 5000.0;
        attribute jointPositions : AngularPosition[7] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

        port powerIn : PowerPort;
        port controlIn : ControlPort;

        part joints : Joint[7] {
            attribute jointId = 1;
        }

        action moveJoints {
            in targetPositions : AngularPosition[7];
            in trajectory : TrajectoryPlan;
            out positionReached : Boolean;
        }

        action holdPayload {
            in payloadMass : PayloadMass;
            out holdStatus : String;
        }

        action returnToHome {
            out homeStatus : String;
        }

        action computeForwardKinematics {
            in jointPositions : AngularPosition[7];
            out endEffectorPose : TargetPose;
        }
    }

    part def LatchingEndEffector {
        attribute maxLatchForce : LatchForce = 8000.0;
        attribute isLatched : Boolean = false;
        attribute latchDiameter : Real = 0.15;

        port powerIn : PowerPort;
        port controlIn : ControlPort;

        part latchMechanism : LatchMechanism;

        action latch {
            in targetPose : TargetPose;
            in requiredForce : LatchForce;
            out latchStatus : String;
        }

        action unlatch {
            out unlatchStatus : String;
        }

        action applyForce {
            in force : LatchForce;
            out forceStatus : String;
        }

        action verifyLatch {
            out verificationStatus : String;
        }
    }

    part def VisionSensor {
        attribute resolution : String = "4096x2160";
        attribute frameRate : Frequency = 30.0;
        attribute fieldOfView : AngularPosition = 1.5;
        attribute detectionRange : ReachDistance = 10.0;

        port powerIn : PowerPort;
        port imageOut : ImagePort;
        port controlIn : ControlPort;

        part camera : CameraUnit;
        part processor : ImageProcessor;

        action captureImage {
            out image : ImageData;
        }

        action detectTarget {
            in image : ImageData;
            out targetPose : TargetPose;
        }

        action trackTarget {
            in image : ImageData;
            out trackedPose : TargetPose;
        }

        action identifyObject {
            in image : ImageData;
            out objectId : String;
        }
    }

    part def ControlComputer {
        attribute clockSpeed : Frequency = 2000.0;
        attribute missionActive : Boolean = false;
        attribute memorySize : Integer = 32;
        attribute redundancyLevel : Integer = 2;

        port powerIn : PowerPort;
        port commandIn : CommandPort;
        port imageIn : ImagePort;
        port baseControl : ControlPort;
        port armControl : ControlPort;
        port effectorControl : ControlPort;
        port sensorControl : ControlPort;

        action planTrajectory {
            in command : MissionCommand;
            in targetPose : TargetPose;
            out trajectory : TrajectoryPlan;
        }

        action processImageData {
            in image : ImageData;
            out targetPose : TargetPose;
        }

        action coordinateOperations {
            in command : MissionCommand;
            in trajectory : TrajectoryPlan;
            out baseCommand : TrajectoryPlan;
            out armCommand : TrajectoryPlan;
            out effectorCommand : TrajectoryPlan;
        }

        action monitorHealth {
            in telemetry : TelemetryData[0..*];
            out healthReport : HealthStatus;
        }

        action executeCommand {
            in command : MissionCommand;
            out status : String;
        }

        action faultDetection {
            in telemetry : TelemetryData;
            out faultStatus : String;
        }
    }

    part def PowerDistributionUnit {
        attribute inputVoltage : Voltage = 160.0;
        attribute outputVoltage : Voltage = 120.0;
        attribute maxOutputPower : Power = 5000.0;
        attribute efficiency : Real = 0.95;
        attribute redundancyEnabled : Boolean = true;

        port powerInput : PowerPort;
        port basePowerOut : PowerPort;
        port armPowerOut : PowerPort;
        port effectorPowerOut : PowerPort;
        port sensorPowerOut : PowerPort;
        port computerPowerOut : PowerPort;

        action distributePower {
            in inputPower : ElectricalPower;
            out basePower : ElectricalPower;
            out armPower : ElectricalPower;
            out effectorPower : ElectricalPower;
            out sensorPower : ElectricalPower;
            out computerPower : ElectricalPower;
        }

        action regulateVoltage {
            in inputVoltage : Voltage;
            out regulatedVoltage : Voltage;
        }

        action monitorPower {
            out powerStatus : HealthStatus;
        }

        action faultRecovery {
            out recoveryStatus : String;
        }
    }

    // ===== Main System Definition =====
    part def MobileServicingSystem {
        attribute systemId : String = "MSS-001";
        attribute systemHealth : String = "nominal";
        attribute missionCommandReceived : Boolean = false;
        attribute basePositioned : Boolean = false;
        attribute targetAcquired : Boolean = false;
        attribute serviceComplete : Boolean = false;
        attribute returnComplete : Boolean = false;
        attribute emergencyDetected : Boolean = false;
        attribute systemRecovered : Boolean = false;
        attribute maxReach : ReachDistance = 18.0;
        attribute maxPayload : PayloadMass = 120.0;

        port externalCommand : CommandPort;
        port externalPower : PowerPort;

        part mobileBase : MobileBase;
        part manipulatorArm : ManipulatorArm;
        part endEffector : LatchingEndEffector;
        part visionSensor : VisionSensor;
        part controlComputer : ControlComputer;
        part powerUnit : PowerDistributionUnit;

        // Power connections
        connection powerSourceToPdu : PowerConnection
            connect externalPower to powerUnit.powerInput;
        connection pduToBase : PowerConnection
            connect powerUnit.basePowerOut to mobileBase.powerIn;
        connection pduToArm : PowerConnection
            connect powerUnit.armPowerOut to manipulatorArm.powerIn;
        connection pduToEffector : PowerConnection
            connect powerUnit.effectorPowerOut to endEffector.powerIn;
        connection pduToSensor : PowerConnection
            connect powerUnit.sensorPowerOut to visionSensor.powerIn;
        connection pduToComputer : PowerConnection
            connect powerUnit.computerPowerOut to controlComputer.powerIn;

        // Internal power distribution within sub-components
        connection pduToBaseBrake : PowerConnection
            connect mobileBase.powerIn to mobileBase.brakeAssembly.powerIn;
        connection pduToArmJoints : PowerConnection
            connect manipulatorArm.powerIn to manipulatorArm.joints.powerIn;
        connection pduToEffectorLatch : PowerConnection
            connect endEffector.powerIn to endEffector.latchMechanism.powerIn;
        connection pduToSensorCamera : PowerConnection
            connect visionSensor.powerIn to visionSensor.camera.powerIn;
        connection pduToSensorProcessor : PowerConnection
            connect visionSensor.powerIn to visionSensor.processor.powerIn;

        // Data connections
        connection commandToComputer : DataConnection
            connect externalCommand to controlComputer.commandIn;
        connection sensorToComputer : DataConnection
            connect visionSensor.imageOut to controlComputer.imageIn;
        connection cameraToProcessor : DataConnection
            connect visionSensor.camera.imageOut to visionSensor.processor.imageIn;
        connection computerToBase : DataConnection
            connect controlComputer.baseControl to mobileBase.controlIn;
        connection computerToArm : DataConnection
            connect controlComputer.armControl to manipulatorArm.controlIn;
        connection computerToEffector : DataConnection
            connect controlComputer.effectorControl to endEffector.controlIn;
        connection computerToSensor : DataConnection
            connect controlComputer.sensorControl to visionSensor.controlIn;
        connection computerToBaseBrake : DataConnection
            connect mobileBase.controlIn to mobileBase.brakeAssembly.controlIn;
        connection computerToArmJoints : DataConnection
            connect manipulatorArm.controlIn to manipulatorArm.joints.controlIn;
        connection computerToEffectorLatch : DataConnection
            connect endEffector.controlIn to endEffector.latchMechanism.controlIn;
        connection computerToSensorProcessor : DataConnection
            connect visionSensor.controlIn to visionSensor.processor.controlIn;

        // State machine
        state operationalStates {
            state Standby {
                entry action enterStandby {
                    out log : String = "Entering Standby mode";
                }
                do action monitorHealth {
                    in telemetry : TelemetryData[0..*];
                    out healthReport : HealthStatus;
                }
                exit action exitStandby {
                    out log : String = "Exiting Standby mode, mission command received";
                }
            }

            state Active {
                entry action activate {
                    in command : MissionCommand;
                    out log : String = "System Activated, beginning mission sequence";
                }
                exit action deactivate {
                    out log : String = "Mission sequence complete, exiting Active mode";
                }

                state Positioning {
                    entry action positionBase {
                        in trajectory : TrajectoryPlan;
                        out status : String = "Moving base to worksite";
                    }
                    do action holdPosition {
                        out status : String = "Base holding at worksite";
                    }
                    exit action baseSecured {
                        out status : String = "Base secured at worksite, brakes engaged";
                    }
                }

                state Acquiring {
                    entry action acquireTarget {
                        in image : ImageData;
                        out targetPose : TargetPose;
                    }
                    do action trackTarget {
                        in image : ImageData;
                        out trackedPose : TargetPose;
                    }
                    exit action targetFound {
                        out status : String = "Target acquired and pose confirmed";
                    }
                }

                state Servicing {
                    entry action beginService {
                        in targetPose : TargetPose;
                        in trajectory : TrajectoryPlan;
                        out status : String = "Beginning servicing operations";
                    }
                    do action executeService {
                        in trajectory : TrajectoryPlan;
                        out serviceStatus : String = "Servicing in progress";
                    }
                    exit action completeService {
                        out status : String = "Service task complete, payload released";
                    }
                }

                state Returning {
                    entry action returnHome {
                        in trajectory : TrajectoryPlan;
                        out status : String = "Returning to home position";
                    }
                    do action homingSequence {
                        out status : String = "Homing sequence in progress";
                    }
                    exit action returnCompleteAction {
                        out status : String = "Returned to home position";
                    }
                }

                transition first Positioning;
                transition Positioning to Acquiring when basePositioned;
                transition Acquiring to Servicing when targetAcquired;
                transition Servicing to Returning when serviceComplete;
            }

            state Safing {
                entry action safeSystem {
                    out status : String = "Entering Safing mode, halting all operations";
                }
                do action monitorRecovery {
                    in telemetry : TelemetryData[0..*];
                    out healthReport : HealthStatus;
                }
                exit action exitSafing {
                    out status : String = "System recovered, exiting Safing mode";
                }
            }

            transition first Standby;
            transition Standby to Active when missionCommandReceived;
            transition Active.Returning to Standby when returnComplete;
            transition Standby to Safing when emergencyDetected;
            transition Active to Safing when emergencyDetected;
            transition Safing to Standby when systemRecovered;
        }

        // Requirement satisfaction
        requirement reachReq : ReachRequirement {
            attribute minReach = 17.0;
        }
        satisfy reachReq by manipulatorArm;

        requirement payloadReq : PayloadCapacityRequirement {
            attribute minPayload = 100.0;
        }
        satisfy payloadReq by manipulatorArm;

        requirement jointReq : JointCountRequirement {
            attribute requiredJoints = 7;
        }
        satisfy jointReq by manipulatorArm;

        requirement latchReq : LatchForceRequirement {
            attribute minLatchForce = 5000.0;
        }
        satisfy latchReq by endEffector;

        requirement powerReq : PowerStabilityRequirement {
            attribute nominalVoltage = 120.0;
        }
        satisfy powerReq by powerUnit;

        requirement visionReq : VisionResolutionRequirement {
            attribute minResolution = "3840x2160";
        }
        satisfy visionReq by visionSensor;

        requirement missionSeqReq : MissionSequenceRequirement {
        }
        satisfy missionSeqReq by MobileServicingSystem;
    }
}

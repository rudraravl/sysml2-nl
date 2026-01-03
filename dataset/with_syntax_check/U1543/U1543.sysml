package DextreRoboticManipulatorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def PositionVector {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }

    attribute def OrientationAngles {
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }

    enum def TaskStatus {
        pending;
        inProgress;
        completed;
        failed;
    }

    enum def GripperMode {
        open;
        closed;
        gripping;
        releasing;
    }

    enum def SystemMode {
        standby;
        autonomous;
        teleoperated;
        safing;
    }

    item def OrbitalReplacementUnit {
        attribute mass : MassValue;
        attribute dimensions : PositionVector;
        attribute graspPoints : PositionVector[1..*];
    }

    item def MaintenanceTool {
        attribute toolType : String;
        attribute mass : MassValue;
        attribute requiredGripForce : ForceValue;
    }

    port def PowerPort {
        out voltage : Real;
        out current : Real;
    }

    port def DataPort {
        in commands : String;
        out telemetry : String;
    }

    port def MechanicalPort {
        attribute attachmentForce : ForceValue;
        attribute attachmentTorque : TorqueValue;
    }

    value def TorqueValue :> ISQ::torque {
        attribute :>> num : Real;
        attribute :>> mRef : TorqueUnit;
    }

    part def Joint {
        attribute jointID : Integer;
        attribute currentAngle : Real;
        attribute targetAngle : Real;
        attribute maxTorque : TorqueValue;
        attribute angularVelocity : Real;

        port motorControl;

        action def MoveToAngle {
            in target : Real;
            out reached : Boolean;
        }
    }

    part def EndEffector {
        attribute maxGripForce : ForceValue = 300 [N];
        attribute currentGripForce : ForceValue;
        attribute gripperState : GripperMode;
        attribute toolAttached : Boolean;

        port mechanicalInterface : MechanicalPort;
        port sensorInterface;

        part forceSensors[6] {
            attribute reading : ForceValue;
        }

        part proximityDetectors[4] {
            attribute distance : LengthValue;
            attribute objectDetected : Boolean;
        }

        action def GraspObject {
            in targetObject : OrbitalReplacementUnit;
            in requiredForce : ForceValue;
            out graspSuccess : Boolean;
        }

        action def ReleaseObject {
            out releaseSuccess : Boolean;
        }

        action def AttachTool {
            in tool : MaintenanceTool;
            out attachSuccess : Boolean;
        }
    }

    part def RoboticArm {
        attribute armID : String;
        attribute totalLength : LengthValue = 3.35 [m];
        attribute maxReach : LengthValue = 3.5 [m];
        attribute maxPayload : MassValue = 600 [kg];
        attribute currentPosition : PositionVector;
        attribute currentOrientation : OrientationAngles;

        port powerInput : PowerPort;
        port controlData : DataPort;

        part shoulderJoint : Joint {
            attribute :>> jointID = 1;
            attribute :>> maxTorque = 250 [N * m];
        }

        part elbowJoint : Joint {
            attribute :>> jointID = 2;
            attribute :>> maxTorque = 200 [N * m];
        }

        part wristJoints : Joint[3] {
            attribute :>> maxTorque = 150 [N * m];
        }

        part rollJoint : Joint {
            attribute :>> jointID = 6;
            attribute :>> maxTorque = 100 [N * m];
        }

        part pitchJoint : Joint {
            attribute :>> jointID = 7;
            attribute :>> maxTorque = 100 [N * m];
        }

        part gripper : EndEffector;

        action def MoveToPosition {
            in targetPos : PositionVector;
            in targetOrient : OrientationAngles;
            out moveComplete : Boolean;
        }

        action def FollowTrajectory {
            in waypoints : PositionVector[2..*];
            out trajectoryComplete : Boolean;
        }
    }

    part def VisionSystem {
        attribute cameraCount : Integer = 4;
        attribute resolution : Integer = 1920;
        attribute frameRate : Real = 30.0;

        port dataOutput : DataPort;

        part cameras[4] {
            attribute active : Boolean;
            attribute zoomLevel : Real;
            attribute fieldOfView : Real;
        }

        part ledLights[8] {
            attribute intensity : Real;
            attribute wavelength : LengthValue;
        }

        action def CaptureScene {
            in targetArea : String;
            out imageData : String;
        }

        action def TrackTarget {
            in targetID : String;
            out targetPosition : PositionVector;
            out trackingConfidence : Real;
        }

        action def VerifyAlignment {
            in expectedPosition : PositionVector;
            out alignmentError : LengthValue;
        }
    }

    part def ControlComputer {
        attribute processorSpeed : Real = 2.5;
        attribute memoryGB : Real = 512.0;
        attribute operatingMode : SystemMode;

        port commandInterface : DataPort;
        port telemetryInterface : DataPort;
        port leftArmControl : DataPort;
        port rightArmControl : DataPort;
        port visionControl : DataPort;

        action def ProcessGroundCommand {
            in command : String;
            out armCommands : String;
            out executionStatus : TaskStatus;
        }

        action def MonitorSystemHealth {
            out healthStatus : Real;
            out diagnosticData : String;
        }

        action def CoordinateArms {
            in leftTarget : PositionVector;
            in rightTarget : PositionVector;
            out coordinationSuccess : Boolean;
        }

        action def ExecuteAutonomousTask {
            in taskDescriptor : String;
            out taskResult : TaskStatus;
        }
    }

    part def PowerSystem {
        attribute inputVoltage : Real = 120.0;
        attribute maxPowerOutput : Real = 2000.0;
        attribute efficiency : Real = 0.92;

        port stationPower;
        port leftArmPower : PowerPort;
        port rightArmPower : PowerPort;
        port computerPower : PowerPort;
        port visionPower : PowerPort;

        action def DistributePower {
            in totalDemand : Real;
            out allocationSuccess : Boolean;
        }

        action def ManagePowerBudget {
            out availablePower : Real;
        }
    }

    part def ToolStorage {
        attribute storageSlots : Integer = 4;

        part toolBays[4] {
            attribute occupied : Boolean;
            attribute storedTool : MaintenanceTool;
        }

        action def RetrieveTool {
            in slotNumber : Integer;
            out tool : MaintenanceTool;
        }

        action def StoreTool {
            in tool : MaintenanceTool;
            in slotNumber : Integer;
            out storeSuccess : Boolean;
        }
    }

    part def Dextre {
        doc /* Special Purpose Dexterous Manipulator (SPDM) - Dextre is a sophisticated 
             * dual-arm robotic system designed to perform intricate maintenance, repair, 
             * and assembly operations on the exterior of the International Space Station, 
             * reducing the need for astronaut spacewalks and enabling precise manipulation 
             * of orbital replacement units and specialized tools.
             */

        attribute totalMass : MassValue = 1662 [kg];
        attribute operatingTempMin : TemperatureValue = -40 ['°C'];
        attribute operatingTempMax : TemperatureValue = 50 ['°C'];
        attribute systemMode : SystemMode;
        attribute missionUptime : DurationValue;

        port groundControlLink : DataPort;
        port stationPowerLink : PowerPort;
        port stationDataLink : DataPort;
        port mobileBaseAttachment : MechanicalPort;

        part leftArm : RoboticArm {
            attribute :>> armID = "ARM_LEFT";
            attribute :>> totalLength = 3.35 [m];
            attribute :>> maxReach = 3.5 [m];
            attribute :>> maxPayload = 600 [kg];
        }

        part rightArm : RoboticArm {
            attribute :>> armID = "ARM_RIGHT";
            attribute :>> totalLength = 3.35 [m];
            attribute :>> maxReach = 3.5 [m];
            attribute :>> maxPayload = 600 [kg];
        }

        part centralBody {
            attribute bodyMass : MassValue = 400 [kg];

            part controller : ControlComputer {
                attribute :>> processorSpeed = 2.5;
                attribute :>> memoryGB = 512.0;
            }

            part vision : VisionSystem {
                attribute :>> cameraCount = 4;
                attribute :>> resolution = 1920;
            }

            part power : PowerSystem {
                attribute :>> inputVoltage = 120.0;
                attribute :>> maxPowerOutput = 2000.0;
            }

            part toolStorage : ToolStorage {
                attribute :>> storageSlots = 4;
            }
        }

        connection leftArmControlLink connect
            centralBody.controller.leftArmControl to leftArm.controlData;

        connection rightArmControlLink connect
            centralBody.controller.rightArmControl to rightArm.controlData;

        connection visionDataLink connect
            centralBody.vision.dataOutput to centralBody.controller.visionControl;

        connection leftArmPowerLink connect
            centralBody.power.leftArmPower to leftArm.powerInput;

        connection rightArmPowerLink connect
            centralBody.power.rightArmPower to rightArm.powerInput;

        action def PerformExternalMaintenance {
            doc /* Primary high-level function: Execute complex maintenance and assembly 
                 * tasks on ISS exterior structures by coordinating dual robotic arms with 
                 * vision guidance to manipulate orbital replacement units and specialized 
                 * tools with high precision.
                 */

            first start;

            then action receiveTaskAssignment {
                doc /* Receive detailed task parameters from ground control */
            }

            then action positionAtWorksite {
                doc /* Use mobile base system to position Dextre at target location */
            }

            then action visualSurvey : centralBody.vision.CaptureScene {
                in targetArea = "worksite_overview";
                out imageData;
            }

            then action planManipulation : centralBody.controller.ProcessGroundCommand {
                in command = "plan_task";
                out armCommands;
                out executionStatus;
            }

            then decide;
                if planManipulation.executionStatus == TaskStatus::inProgress then acquireTool;
                else abort;

            action acquireTool {
                doc /* Retrieve appropriate tool from storage bay */

                action selectTool : centralBody.toolStorage.RetrieveTool {
                    in slotNumber = 1;
                    out tool;
                }

                then action graspTool : leftArm.gripper.GraspObject {
                    in targetObject;
                    in requiredForce = 150 [N];
                    out graspSuccess;
                }
            }

            then merge coordinateDualArms;

            then action coordinateDualArms {
                doc /* Coordinate both arms for synchronized manipulation */

                action positionLeftArm : leftArm.MoveToPosition {
                    in targetPos;
                    in targetOrient;
                    out moveComplete;
                }

                action positionRightArm : rightArm.MoveToPosition {
                    in targetPos;
                    in targetOrient;
                    out moveComplete;
                }

                action synchronize : centralBody.controller.CoordinateArms {
                    in leftTarget;
                    in rightTarget;
                    out coordinationSuccess;
                }
            }

            then action executeManipulation {
                doc /* Perform precise manipulation task with coordinated arm movements */

                action trackProgress : centralBody.vision.TrackTarget {
                    in targetID = "oru_target";
                    out targetPosition;
                    out trackingConfidence;
                }

                action adjustGrip : leftArm.gripper.GraspObject {
                    in targetObject;
                    in requiredForce = 200 [N];
                    out graspSuccess;
                }
            }

            then action verifyTaskCompletion : centralBody.vision.VerifyAlignment {
                in expectedPosition;
                out alignmentError;
            }

            then decide;
                if verifyTaskCompletion.alignmentError <= 2 [mm] then stowEquipment;
                else coordinateDualArms;

            action stowEquipment {
                doc /* Return tool to storage and secure arms */

                action releaseTool : leftArm.gripper.ReleaseObject {
                    out releaseSuccess;
                }

                then action storeTool : centralBody.toolStorage.StoreTool {
                    in tool;
                    in slotNumber = 1;
                    out storeSuccess;
                }

                then action retractArms {
                    action retractLeft : leftArm.MoveToPosition {
                        in targetPos;
                        in targetOrient;
                        out moveComplete;
                    }

                    action retractRight : rightArm.MoveToPosition {
                        in targetPos;
                        in targetOrient;
                        out moveComplete;
                    }
                }
            }

            then action reportMissionComplete : centralBody.controller.MonitorSystemHealth {
                out healthStatus;
                out diagnosticData;
            }

            then done;

            action abort {
                doc /* Safe abort sequence for task failure */
            }

            then done;
        }

        perform action maintenanceOperations[*] ordered references PerformExternalMaintenance;
    }

    requirement <'REQ-DEXTRE-PRIMARY-001'> primaryMaintenanceFunction {
        doc /* Dextre shall perform complex maintenance, repair, and assembly operations 
             * on the exterior of the International Space Station, manipulating orbital 
             * replacement units and specialized tools to reduce astronaut EVA requirements.
             */

        subject dextre : Dextre;

        require dualArmCoordination;
        require precisionManipulation;
        require toolManagement;
        require visionGuidance;
    }

    requirement <'REQ-DEXTRE-002'> dualArmCoordination {
        doc /* Dextre shall coordinate two independent 7-DOF robotic arms simultaneously 
             * for complex bimanual manipulation tasks.
             */

        subject dextre : Dextre;

        assert constraint {
            dextre.leftArm.shoulderJoint.jointID == 1 and
            dextre.rightArm.shoulderJoint.jointID == 1 and
            dextre.leftArm.pitchJoint.jointID == 7 and
            dextre.rightArm.pitchJoint.jointID == 7
        }
    }

    requirement <'REQ-DEXTRE-003'> precisionManipulation {
        doc /* Each robotic arm shall achieve positioning accuracy of 2mm or better 
             * at maximum extension for precise ORU handling and bolt operations.
             */

        subject arm : RoboticArm;

        assert constraint {
            arm.maxReach >= 3.0 [m] and
            arm.maxPayload >= 600 [kg]
        }
    }

    requirement <'REQ-DEXTRE-004'> toolManagement {
        doc /* Dextre shall store, retrieve, and utilize at least 4 specialized tools 
             * for different maintenance operations.
             */

        subject dextre : Dextre;

        assert constraint {
            dextre.centralBody.toolStorage.storageSlots >= 4
        }
    }

    requirement <'REQ-DEXTRE-005'> visionGuidance {
        doc /* Dextre shall incorporate multi-camera vision system for task monitoring, 
             * target tracking, and alignment verification.
             */

        subject vision : VisionSystem;

        assert constraint {
            vision.cameraCount >= 4 and
            vision.resolution >= 1920
        }
    }

    requirement <'REQ-DEXTRE-006'> massConstraint {
        doc /* Total system mass shall not exceed 1700 kg to maintain compatibility 
             * with station structural and mobile base limits.
             */

        subject dextre : Dextre;

        assert constraint {
            dextre.totalMass <= 1700 [kg]
        }
    }

    requirement <'REQ-DEXTRE-007'> thermalOperatingRange {
        doc /* Dextre shall operate throughout thermal cycles experienced on ISS 
             * exterior during orbital day/night transitions.
             */

        subject dextre : Dextre;

        assert constraint {
            dextre.operatingTempMin <= -40 ['°C'] and
            dextre.operatingTempMax >= 50 ['°C']
        }
    }

    requirement <'REQ-DEXTRE-008'> gripperCapability {
        doc /* End effectors shall provide sufficient grip force for secure handling 
             * of orbital replacement units up to 600 kg mass.
             */

        subject gripper : EndEffector;

        assert constraint {
            gripper.maxGripForce >= 300 [N]
        }
    }

    part dextreSystem : Dextre;

    satisfy primaryMaintenanceFunction by dextreSystem.maintenanceOperations;
    satisfy dualArmCoordination by dextreSystem;
    satisfy massConstraint by dextreSystem;
    satisfy thermalOperatingRange by dextreSystem;
    satisfy toolManagement by dextreSystem;
}

package HumanoidRobotSystem {
    private import ISQ::*;
    private import ScalarValues::*;

    package TypeDefinitions {
        attribute def Coordinate3D {
            attribute x : LengthValue;
            attribute y : LengthValue;
            attribute z : LengthValue;
        }
        attribute def VideoResolution {
            attribute verticalPixels : Integer;
            attribute frameRate : Real;
        }
        enum def GripperAction {
            open;
            close;
            hold;
            release;
        }
        enum def SystemMode {
            standby;
            operational;
            maintenance;
            emergency;
        }
        enum def TaskStatus {
            pending;
            inProgress;
            completed;
            aborted;
        }
        attribute def TaskCommand {
            attribute taskName : String;
            attribute targetLocation : Coordinate3D;
            attribute targetObject : String;
        }
        attribute def StatusReport {
            attribute status : TaskStatus;
            attribute mode : SystemMode;
            attribute batteryLevel : Real;
            attribute description : String;
        }
        attribute def SigActivate;
        attribute def SigStandby;
        attribute def SigMaintenance;
        attribute def SigEmergency;
        attribute def SigClearEmergency;
        attribute def SigLowBattery;
        attribute def SigStartTask;
        attribute def SigTaskComplete;
        attribute def SigTaskAbort;
    }

    package ActionDefinitions {
        private import TypeDefinitions::*;

        action def ScanArea {
            in area : Coordinate3D;
            out objectLocations : Coordinate3D[*];
            first start;
            then action captureFrame;
            then action detectObjects;
            then action localizeObjects;
            then done;
        }
        action def PlanMotion {
            in currentLocation : Coordinate3D;
            in targetLocation : Coordinate3D;
            in detectedObjects : Coordinate3D[*];
            out bodyPath : Coordinate3D[*];
            out armPath : Coordinate3D[*];
            first start;
            then action evaluateObstacles;
            then action computeBodyPath;
            then action computeArmPath;
            then done;
        }
        action def NavigateToTarget {
            in destination : Coordinate3D;
            in currentLocation : Coordinate3D;
            out newLocation : Coordinate3D;
            first start;
            then action computePath;
            then action driveToTarget;
            then done;
        }
        action def GraspObject {
            in targetLocation : Coordinate3D;
            in force : ForceValue;
            out secured : Boolean;
            first start;
            then action selectArm;
            then action moveArm;
            then action operateGripper;
            then action verifyHold;
            then done;
        }
        action def ExecuteTask {
            in command : TaskCommand;
            in currentLocation : Coordinate3D;
            out finalStatus : TaskStatus;
            first start;
            then perform action scan : ScanArea {
                in area = currentLocation;
                out objectLocations;
            }
            then perform action plan : PlanMotion {
                in currentLocation = currentLocation;
                in targetLocation = command.targetLocation;
                in detectedObjects = scan.objectLocations;
                out bodyPath;
                out armPath;
            }
            then perform action navigate : NavigateToTarget {
                in destination = command.targetLocation;
                in currentLocation = currentLocation;
                out newLocation;
            }
            then perform action grasp : GraspObject {
                in targetLocation = command.targetLocation;
                in force = 20.0 [N];
                out secured;
            }
            then assign finalStatus := TaskStatus::completed;
            then done;
        }
    }

    package ComponentDefinitions {
        private import TypeDefinitions::*;
        private import ActionDefinitions::*;

        part def RechargeableBattery {
            attribute capacity : ElectricChargeValue;
            attribute currentLevel : Real;
            attribute voltage : VoltageValue;
            port powerOut {
                out attribute voltageOut : VoltageValue;
            }
            port statusOut {
                out attribute level : Real;
            }
            perform action discharge {
                in powerDraw : Real;
                out level : Real;
                first start;
                then done;
            }
        }

        part def WheeledBase {
            attribute wheelCount : Integer;
            attribute maxSpeed : SpeedValue;
            part battery : RechargeableBattery;
            port drivePort {
                in attribute targetVelocity : SpeedValue;
                in attribute heading : Real;
            }
        }

        part def VisionSystem {
            attribute resolution : VideoResolution;
            attribute detectionRange : LengthValue;
            port videoPort {
                out attribute frameData : Integer;
                out attribute detectedObjects : Coordinate3D[*];
            }
        }

        part def MotionController {
            attribute controlFrequency : FrequencyValue;
            port sensorPort {
                in attribute visionData : Coordinate3D[*];
                in attribute batteryLevel : Real;
                in attribute perimeterBreach : Boolean;
            }
            port commandPort {
                in attribute task : TaskCommand;
            }
            port actuatorPort {
                out attribute bodyPath : Coordinate3D[*];
                out attribute armPath : Coordinate3D[*];
            }
        }

        part def Joint {
            attribute minAngle : Real;
            attribute maxAngle : Real;
            attribute currentAngle : Real;
            port controlPort {
                in attribute targetAngle : Real;
            }
        }

        part def Gripper {
            attribute fingerCount : Integer;
            attribute maxForce : ForceValue;
            port gripperPort {
                in attribute gripperAction : GripperAction;
                in attribute gripForce : ForceValue;
                out attribute holdingObject : Boolean;
            }
        }

        part def Arm {
            attribute jointCount : Integer;
            part joints[jointCount] : Joint;
            part gripper : Gripper;
            port armControlPort {
                in attribute path : Coordinate3D[*];
                in attribute gripperAction : GripperAction;
                in attribute gripForce : ForceValue;
            }
        }

        part def SafetyPerimeter {
            attribute boundary : Coordinate3D[*];
            port alertPort {
                out attribute boundaryViolation : Boolean;
            }
        }

        part def ControlCenter {
            port commandPort {
                out attribute command : TaskCommand;
            }
            port statusPort {
                in attribute report : StatusReport;
            }
        }

        part def HumanoidRobot {
            attribute height : LengthValue;
            attribute mass : MassValue;
            attribute mode : SystemMode;
            attribute currentLocation : Coordinate3D;
            part mobileBase : WheeledBase;
            part visionSystem : VisionSystem;
            part motionController : MotionController;
            part leftArm : Arm;
            part rightArm : Arm;
            part safetyPerimeter : SafetyPerimeter;
            port communicationPort {
                in attribute command : TaskCommand;
                out attribute report : StatusReport;
            }
            connect visionSystem.videoPort to motionController.sensorPort;
            connect mobileBase.battery.statusOut to motionController.sensorPort;
            connect safetyPerimeter.alertPort to motionController.sensorPort;
            state robotStates {
                entry; then standby;
                state standby;
                accept SigActivate then operational;
                accept SigMaintenance then maintenance;
                state operational;
                accept SigStartTask then executingTask;
                accept SigStandby then standby;
                accept SigEmergency then emergency;
                state executingTask;
                accept SigTaskComplete then operational;
                accept SigTaskAbort then operational;
                accept SigEmergency then emergency;
                state maintenance;
                accept SigStandby then standby;
                state emergency;
                accept SigClearEmergency then standby;
            }
            perform action executeTask : ExecuteTask;
        }
    }

    package Requirements {
        private import TypeDefinitions::*;
        private import ComponentDefinitions::*;

        requirement def HeightRequirement {
            attribute requiredHeight : LengthValue;
            subject robot : HumanoidRobot;
            constraint { robot.height == requiredHeight }
        }
        requirement def MassRequirement {
            attribute requiredMass : MassValue;
            subject robot : HumanoidRobot;
            constraint { robot.mass == requiredMass }
        }
        requirement def BatteryCapacityRequirement {
            attribute minCapacity : ElectricChargeValue;
            subject battery : RechargeableBattery;
            constraint { battery.capacity >= minCapacity }
        }
        requirement def VisionResolutionRequirement {
            attribute minPixels : Integer;
            attribute minFrameRate : Real;
            subject vision : VisionSystem;
            constraint { vision.resolution.verticalPixels >= minPixels and vision.resolution.frameRate >= minFrameRate }
        }
        requirement def ArmJointRequirement {
            attribute requiredJoints : Integer;
            subject arm : Arm;
            constraint { arm.jointCount == requiredJoints }
        }
        requirement def GripperFingerRequirement {
            attribute requiredFingers : Integer;
            subject gripper : Gripper;
            constraint { gripper.fingerCount == requiredFingers }
        }
        requirement def SafetyPerimeterRequirement {
            subject robot : HumanoidRobot;
            constraint { robot.safetyPerimeter.boundary->size() > 0 }
        }
        requirement def ModeSafetyRequirement {
            subject robot : HumanoidRobot;
            constraint { robot.mobileBase.battery.currentLevel > 10.0 }
        }
        requirement def TaskCompletionRequirement {
            subject robot : HumanoidRobot;
            constraint { robot.mode == SystemMode::operational }
        }

        requirement heightSpec : HeightRequirement {
            :>> requiredHeight = 1.7 [m];
        }
        requirement massSpec : MassRequirement {
            :>> requiredMass = 80.0 [kg];
        }
        requirement batterySpec : BatteryCapacityRequirement {
            :>> minCapacity = 8000 [C];
        }
        requirement visionSpec : VisionResolutionRequirement {
            :>> minPixels = 2048;
            :>> minFrameRate = 60.0;
        }
        requirement armSpec : ArmJointRequirement {
            :>> requiredJoints = 7;
        }
        requirement gripperSpec : GripperFingerRequirement {
            :>> requiredFingers = 2;
        }
        requirement safetySpec : SafetyPerimeterRequirement {
        }
        requirement modeSafetySpec : ModeSafetyRequirement {
        }
        requirement taskCompletionSpec : TaskCompletionRequirement {
        }
    }

    package SystemInstances {
        private import TypeDefinitions::*;
        private import ComponentDefinitions::*;
        private import Requirements::*;

        part workZone {
            attribute zoneBoundary : Coordinate3D[*];
            attribute zoneName : String;
        }

        part controlCenter : ControlCenter;
        part humanoidRobot : HumanoidRobot {
            :>> height = 1.7 [m];
            :>> mass = 80.0 [kg];
            :>> mode = SystemMode::standby;
            :>> currentLocation {
                :>> x = 0.0 [m];
                :>> y = 0.0 [m];
                :>> z = 0.0 [m];
            }
            :>> mobileBase {
                :>> wheelCount = 4;
                :>> maxSpeed = 2.0 [m/s];
                :>> battery {
                    :>> capacity = 10000 [C];
                    :>> currentLevel = 95.0;
                    :>> voltage = 24.0 [V];
                }
            }
            :>> visionSystem {
                :>> resolution {
                    :>> verticalPixels = 2048;
                    :>> frameRate = 60.0;
                }
                :>> detectionRange = 10.0 [m];
            }
            :>> motionController {
                :>> controlFrequency = 1000.0 [Hz];
            }
            :>> leftArm {
                :>> jointCount = 7;
                :>> gripper {
                    :>> fingerCount = 2;
                    :>> maxForce = 50.0 [N];
                }
            }
            :>> rightArm {
                :>> jointCount = 7;
                :>> gripper {
                    :>> fingerCount = 2;
                    :>> maxForce = 50.0 [N];
                }
            }
            :>> safetyPerimeter {
                :>> boundary;
            }
            satisfy heightSpec;
            satisfy massSpec;
            satisfy batterySpec;
            satisfy visionSpec;
            satisfy armSpec;
            satisfy gripperSpec;
            satisfy safetySpec;
            satisfy modeSafetySpec;
            satisfy taskCompletionSpec;
        }

        connect controlCenter.commandPort to humanoidRobot.communicationPort;
        connect humanoidRobot.communicationPort to controlCenter.statusPort;
    }
}

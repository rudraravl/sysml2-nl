package RoboticsSuiteSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def VoltageValue :> ElectricPotentialValue;
    attribute def CurrentValue :> ElectricCurrentValue;
    attribute def PowerValue :> PowerValue;
    attribute def EnergyValue :> EnergyValue;
    attribute def TorqueValue :> TorqueValue;
    attribute def AngularVelocityValue :> AngularVelocityValue;
    
    enum def RobotOperatingMode {
        standby;
        autonomous;
        manual;
        calibration;
        fault;
    }
    
    enum def GripperState {
        open;
        closed;
        partial;
    }
    
    enum def TaskStatus {
        pending;
        inProgress;
        completed;
        failed;
    }
    
    item def WorkPiece {
        attribute mass : MassValue;
        attribute dimensions : LengthValue[3];
        attribute position : LengthValue[3];
    }
    
    item def MotionCommand {
        attribute targetPosition : LengthValue[3];
        attribute targetOrientation : PlaneAngleValue[3];
        attribute velocity : SpeedValue;
    }
    
    item def SensorData {
        attribute objectDetected : Boolean;
        attribute objectPosition : LengthValue[3];
        attribute proximityDistance : LengthValue;
        attribute forceApplied : ForceValue;
    }
    
    item def PowerSupply {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute power : PowerValue;
    }
    
    port def ControlPort {
        in item command : MotionCommand;
        out item feedback : SensorData;
    }
    
    port def PowerPort {
        in item supply : PowerSupply;
    }
    
    port def DataPort {
        out item sensorOutput : SensorData;
    }
    
    part def Battery {
        attribute capacity : EnergyValue;
        attribute voltage : VoltageValue;
        attribute currentCharge : EnergyValue;
        
        port powerOutput : PowerPort;
    }
    
    part def VisionSystem {
        attribute resolution : Integer[2];
        attribute frameRate : FrequencyValue;
        attribute fieldOfView : PlaneAngleValue;
        
        port dataOutput : DataPort;
        port powerInput : PowerPort;
        
        action def CaptureImage {
            out imageData : SensorData;
        }
        
        action def DetectObject {
            in imageData : SensorData;
            out objectFound : Boolean;
            out objectLocation : LengthValue[3];
        }
    }
    
    part def ManipulatorArm {
        attribute numberOfJoints : Integer;
        attribute reachRadius : LengthValue;
        attribute payloadCapacity : MassValue;
        attribute currentPosition : LengthValue[3];
        
        part joint1 {
            attribute angle : PlaneAngleValue;
            attribute torque : TorqueValue;
            attribute angularVelocity : AngularVelocityValue;
        }
        
        part joint2 {
            attribute angle : PlaneAngleValue;
            attribute torque : TorqueValue;
            attribute angularVelocity : AngularVelocityValue;
        }
        
        part joint3 {
            attribute angle : PlaneAngleValue;
            attribute torque : TorqueValue;
            attribute angularVelocity : AngularVelocityValue;
        }
        
        part gripper {
            attribute state : GripperState;
            attribute gripForce : ForceValue;
            attribute maxGripForce : ForceValue;
        }
        
        port controlInput : ControlPort;
        port powerInput : PowerPort;
    }
    
    part def MobileBase {
        attribute maxSpeed : SpeedValue;
        attribute currentSpeed : SpeedValue;
        attribute position : LengthValue[2];
        attribute heading : PlaneAngleValue;
        
        port controlInput : ControlPort;
        port powerInput : PowerPort;
    }
    
    part def SafetyController {
        attribute emergencyStopActive : Boolean;
        attribute collisionDetected : Boolean;
        attribute safetyZoneRadius : LengthValue;
        
        port sensorInput : DataPort;
        port powerInput : PowerPort;
        
        action def MonitorSafety {
            in sensorData : SensorData;
            out safetyViolation : Boolean;
        }
        
        action def TriggerEmergencyStop {
            out stopCommand : Boolean;
        }
    }
    
    part def MasterController {
        attribute operatingMode : RobotOperatingMode;
        attribute currentTask : TaskStatus;
        attribute systemHealth : Real;
        
        port visionInput : DataPort;
        port safetyInput : DataPort;
        port armControl : ControlPort;
        port baseControl : ControlPort;
        port powerInput : PowerPort;
        
        perform action orchestrateOperation : AutonomousPickAndPlace;
    }
    
    action def ScanEnvironment {
        in scanResolution : Real;
        out environmentMap : SensorData;
        out objectsDetected : Integer;
    }
    
    action def PlanMotion {
        in startPosition : LengthValue[3];
        in targetPosition : LengthValue[3];
        in obstacles : SensorData[0..*];
        out motionPath : LengthValue[0..*];
        out pathValid : Boolean;
    }
    
    action def MoveToPosition {
        in targetPosition : LengthValue[3];
        in speed : SpeedValue;
        out positionReached : Boolean;
        out actualPosition : LengthValue[3];
    }
    
    action def GraspObject {
        in objectPosition : LengthValue[3];
        in objectMass : MassValue;
        in gripForce : ForceValue;
        out graspSuccessful : Boolean;
    }
    
    action def ReleaseObject {
        in releasePosition : LengthValue[3];
        out releaseSuccessful : Boolean;
    }
    
    action def MonitorSafetyAction {
        in sensorData : SensorData;
        out safetyViolation : Boolean;
    }
    
    action def TriggerEmergencyStopAction {
        out stopCommand : Boolean;
    }
    
    action def AutonomousPickAndPlace {
        first start;
        then merge checkSafety;
        
        action checkSafety : MonitorSafetyAction;
        then decide;
            if checkSafety.safetyViolation then emergencyStop;
            if !checkSafety.safetyViolation then scanEnvironment;
        
        action emergencyStop : TriggerEmergencyStopAction;
        then done;
        
        action scanEnvironment : ScanEnvironment {
            in scanResolution = 0.01;
            out environmentMap;
            out objectsDetected;
        }
        then decide;
            if scanEnvironment.objectsDetected > 0 then planApproach;
            if scanEnvironment.objectsDetected == 0 then scanEnvironment;
        
        action planApproach : PlanMotion {
            in startPosition;
            in targetPosition;
            out motionPath;
            out pathValid;
        }
        then decide;
            if planApproach.pathValid then moveToObject;
            if !planApproach.pathValid then scanEnvironment;
        
        action moveToObject : MoveToPosition {
            in targetPosition;
            in speed = 0.5 [m/s];
            out positionReached;
        }
        then action graspObject : GraspObject {
            in gripForce = 50.0 [N];
            out graspSuccessful;
        }
        then decide;
            if graspObject.graspSuccessful then planPlacement;
            if !graspObject.graspSuccessful then retryGrasp;
        
        action retryGrasp : GraspObject {
            in gripForce = 75.0 [N];
        }
        then decide;
            if retryGrasp.graspSuccessful then planPlacement;
            if !retryGrasp.graspSuccessful then scanEnvironment;
        
        action planPlacement : PlanMotion {
            out motionPath;
            out pathValid;
        }
        then action moveToTarget : MoveToPosition {
            in speed = 0.5 [m/s];
            out positionReached;
        }
        then action releaseObject : ReleaseObject {
            out releaseSuccessful;
        }
        then decide;
            if releaseObject.releaseSuccessful then done;
            if !releaseObject.releaseSuccessful then moveToTarget;
    }
    
    state def RobotSystemStates {
        entry; then idle;
        
        state idle;
        
        transition idle_to_autonomous
            first idle
            accept taskAssigned
            then autonomous;
        
        state autonomous {
            do action executeTask : AutonomousPickAndPlace;
        }
        
        transition autonomous_to_idle
            first autonomous
            accept taskCompleted
            then idle;
        
        transition autonomous_to_fault
            first autonomous
            accept errorDetected
            then fault;
        
        state fault;
        
        transition fault_to_calibration
            first fault
            accept resetInitiated
            then calibration;
        
        state calibration;
        
        transition calibration_to_idle
            first calibration
            accept calibrationComplete
            then idle;
    }
    
    part def RoboticsSuite {
        attribute totalMass : MassValue;
        attribute operationalMode : RobotOperatingMode;
        attribute workspaceVolume : VolumeValue;
        
        part battery : Battery {
            attribute :>> capacity = 5000.0 [W*h];
            attribute :>> voltage = 48.0 [V];
            attribute :>> currentCharge = 4500.0 [W*h];
        }
        
        part vision : VisionSystem {
            attribute :>> resolution = (1920, 1080);
            attribute :>> frameRate = 30.0 [Hz];
            attribute :>> fieldOfView = 90.0 [deg];
        }
        
        part manipulator : ManipulatorArm {
            attribute :>> numberOfJoints = 6;
            attribute :>> reachRadius = 1.2 [m];
            attribute :>> payloadCapacity = 15.0 [kg];
            
            part :>> gripper {
                attribute :>> maxGripForce = 100.0 [N];
            }
        }
        
        part base : MobileBase {
            attribute :>> maxSpeed = 1.5 [m/s];
            attribute :>> currentSpeed = 0.0 [m/s];
        }
        
        part safety : SafetyController {
            attribute :>> emergencyStopActive = false;
            attribute :>> collisionDetected = false;
            attribute :>> safetyZoneRadius = 2.0 [m];
        }
        
        part controller : MasterController {
            attribute :>> operatingMode = RobotOperatingMode::standby;
            attribute :>> currentTask = TaskStatus::pending;
            attribute :>> systemHealth = 100.0;
            
            exhibit state systemStates : RobotSystemStates;
        }
        
        connection powerBatteryToVision : PowerPort connect battery.powerOutput to vision.powerInput;
        connection powerBatteryToManipulator : PowerPort connect battery.powerOutput to manipulator.powerInput;
        connection powerBatteryToBase : PowerPort connect battery.powerOutput to base.powerInput;
        connection powerBatteryToSafety : PowerPort connect battery.powerOutput to safety.powerInput;
        connection powerBatteryToController : PowerPort connect battery.powerOutput to controller.powerInput;
        
        connection dataVisionToController : DataPort connect vision.dataOutput to controller.visionInput;
        connection dataSafetyToController : DataPort connect safety.sensorInput to controller.safetyInput;
        
        connection controlControllerToArm : ControlPort connect controller.armControl to manipulator.controlInput;
        connection controlControllerToBase : ControlPort connect controller.baseControl to base.controlInput;
    }
    
    requirement <'REQ-1000'> autonomousManipulationCapability {
        doc /* The robotics suite shall autonomously identify, approach, grasp, 
             * transport, and place objects within its workspace without human intervention.
             */
        subject suite : RoboticsSuite;
        
        require <'REQ-1001'> visionCapability {
            doc /* The vision system shall detect and locate objects with sufficient 
                 * resolution and frame rate for real-time operation.
                 */
            subject vision :>> suite.vision;
            assert constraint {
                vision.frameRate >= 25.0 [Hz] and
                vision.resolution[0] >= 1280 and
                vision.resolution[1] >= 720
            }
        }
        
        require <'REQ-1002'> manipulationCapability {
            doc /* The manipulator shall handle objects up to 15 kg within a 1.2 m reach. */
            subject manipulator :>> suite.manipulator;
            assert constraint {
                manipulator.payloadCapacity >= 15.0 [kg] and
                manipulator.reachRadius >= 1.2 [m]
            }
        }
        
        require <'REQ-1003'> energyCapacity {
            doc /* The battery shall provide sufficient energy for at least 4 hours 
                 * of continuous operation.
                 */
            subject battery :>> suite.battery;
            assert constraint {
                battery.capacity >= 4000.0 [W*h]
            }
        }
        
        require <'REQ-1004'> safetyCompliance {
            doc /* The safety system shall detect hazards and trigger emergency stop 
                 * within the defined safety zone.
                 */
            subject safety :>> suite.safety;
            assert constraint {
                safety.safetyZoneRadius >= 1.5 [m]
            }
        }
        
        require <'REQ-1005'> mobilityCapability {
            doc /* The mobile base shall navigate at speeds up to 1.5 m/s. */
            subject base :>> suite.base;
            assert constraint {
                base.maxSpeed >= 1.5 [m/s]
            }
        }
    }
    
    part roboticsSuiteInstance : RoboticsSuite {
        attribute :>> totalMass = 180.0 [kg];
        attribute :>> operationalMode = RobotOperatingMode::standby;
        attribute :>> workspaceVolume = 15.0 [m^3];
    }
    
    satisfy autonomousManipulationCapability by roboticsSuiteInstance;
}

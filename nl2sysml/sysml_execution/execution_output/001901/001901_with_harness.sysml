package RobonautSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def ForceValue :> ISQ::ForceValue;
    attribute def TorqueValue :> ISQ::TorqueValue;
    attribute def VoltageValue :> ISQ::VoltageValue;
    attribute def CurrentValue :> ISQ::ElectricCurrentValue;
    attribute def AngleValue :> ISQ::PlaneAngleValue;
    attribute def AngularVelocityValue :> ISQ::AngularVelocityValue;

    item def WorkObject {
        attribute mass : ISQ::MassValue;
        attribute position : Real[3];
        attribute orientation : Real[3];
    }

    item def Tool {
        attribute toolType : String;
        attribute mass : ISQ::MassValue;
        attribute requiredGripForce : ForceValue;
    }

    item def CommandMessage {
        attribute commandId : String;
        attribute taskType : String;
        attribute parameters : Real[*];
    }

    item def TelemetryMessage {
        attribute timestamp : Real;
        attribute systemStatus : String;
        attribute batteryLevel : Real;
        attribute jointStates : Real[*];
    }

    item def SensorData {
        attribute imageData : String;
        attribute depthMap : Real[*];
        attribute objectDetections : String[*];
    }

    port def PowerPort {
        in voltage : VoltageValue;
        in current : CurrentValue;
    }

    port def DataPort {
        in commandData : CommandMessage;
        out telemetryData : TelemetryMessage;
    }

    port def SensorPort {
        out sensorOutput : SensorData;
    }

    port def ActuatorPort {
        in controlSignal : Real;
        out position : AngleValue;
        out torque : TorqueValue;
    }

    part def VisionSystem {
        attribute mass : ISQ::MassValue;
        attribute resolution : Integer[2];
        attribute fieldOfView : AngleValue;
        
        port sensorOut : SensorPort;
        port powerIn : PowerPort;
        
        part stereoCameras[2] {
            attribute cameraResolution : Integer[2];
        }
        part depthSensor {
            attribute maxRange : ISQ::LengthValue;
            attribute accuracy : ISQ::LengthValue;
        }
        part imageProcessor {
            attribute processingRate : Real;
        }
    }

    part def DexterousHand {
        attribute mass : ISQ::MassValue;
        attribute fingerCount : Integer;
        attribute maxGripForce : ForceValue;
        
        port powerIn : PowerPort;
        port controlIn : DataPort;
        
        part fingers[5] {
            attribute maxForce : ForceValue;
            attribute jointCount : Integer;
            port actuator : ActuatorPort;
        }
        part palm {
            attribute tactileSensors : Integer;
        }
        part wrist {
            attribute degreesOfFreedom : Integer;
            port actuator : ActuatorPort;
        }
    }

    part def RoboticArm {
        attribute mass : ISQ::MassValue;
        attribute reach : ISQ::LengthValue;
        attribute payloadCapacity : ISQ::MassValue;
        
        port powerIn : PowerPort;
        port controlIn : DataPort;
        
        part shoulder {
            attribute maxTorque : TorqueValue;
            attribute degreesOfFreedom : Integer;
            port actuator : ActuatorPort;
        }
        part elbow {
            attribute maxTorque : TorqueValue;
            port actuator : ActuatorPort;
        }
        part forearm {
            attribute length : ISQ::LengthValue;
        }
    }

    part def Torso {
        attribute mass : ISQ::MassValue;
        attribute height : ISQ::LengthValue;
        
        port powerIn : PowerPort;
        
        part waist {
            attribute rotationRange : AngleValue;
            port actuator : ActuatorPort;
        }
        part spine {
            attribute flexibility : AngleValue;
        }
    }

    part def MobilityBase {
        attribute mass : ISQ::MassValue;
        attribute maxSpeed : Real;
        
        port powerIn : PowerPort;
        port controlIn : DataPort;
        
        part wheels[4] {
            attribute diameter : ISQ::LengthValue;
        }
        part driveMotors[4] {
            attribute maxTorque : TorqueValue;
        }
    }

    part def ControlComputer {
        attribute mass : ISQ::MassValue;
        attribute processorCores : Integer;
        attribute memoryCapacity : Real;
        
        port powerIn : PowerPort;
        port commsPort : DataPort;
        port visionInput : SensorPort;
        
        part mainProcessor {
            attribute clockSpeed : Real;
        }
        part motionPlanner {
            attribute planningRate : Real;
        }
        part safetyMonitor {
            attribute monitoringRate : Real;
        }
    }

    part def PowerSystem {
        attribute mass : ISQ::MassValue;
        attribute voltage : VoltageValue;
        attribute capacity : Real;
        attribute currentCharge : Real;
        
        port powerOut : PowerPort;
        
        part battery {
            attribute energyCapacity : Real;
            attribute cellCount : Integer;
        }
        part powerDistribution {
            attribute efficiency : Real;
        }
        part batteryManagement {
            attribute balancingEnabled : Boolean;
        }
    }

    action def PerceiveEnvironment {
        in visionSystem : VisionSystem;
        out detectedObjects : WorkObject[*];
        out sceneMap : SensorData;
    }

    action def PlanMotion {
        in targetObject : WorkObject;
        in currentArmState : Real[*];
        out trajectoryPlan : Real[*];
        out estimatedTime : Real;
    }

    action def MoveArm {
        in trajectory : Real[*];
        in arm : RoboticArm;
        out finalPosition : Real[3];
    }

    action def GraspObject {
        in targetObject : WorkObject;
        in hand : DexterousHand;
        in requiredForce : ForceValue;
        out graspSuccess : Boolean;
    }

    action def ManipulateObject {
        in graspedObject : WorkObject;
        in targetPosition : Real[3];
        out manipulationSuccess : Boolean;
    }

    action def ReleaseObject {
        in hand : DexterousHand;
        out releaseSuccess : Boolean;
    }

    state def ManipulationStateMachine {
        entry; then idle;
        
        state idle {
            entry; do action waitForCommand;
        }
        transition idle_to_perceiving
            first idle
            accept CommandMessage
            then perceiving;
        
        state perceiving {
            entry; do action perceiveAction : PerceiveEnvironment;
        }
        transition perceiving_to_planning
            first perceiving
            then planning;
        transition perceiving_to_idle
            first perceiving
            then idle;
        
        state planning {
            entry; do action planMotion : PlanMotion;
        }
        transition planning_to_approaching
            first planning
            then approaching;
        
        state approaching {
            entry; do action moveArm : MoveArm;
        }
        transition approaching_to_grasping
            first approaching
            then grasping;
        
        state grasping {
            entry; do action graspAction : GraspObject;
        }
        transition grasping_to_manipulating
            first grasping
            then manipulating;
        transition grasping_to_idle
            first grasping
            then idle;
        
        state manipulating {
            entry; do action manipulateAction : ManipulateObject;
        }
        transition manipulating_to_releasing
            first manipulating
            then releasing;
        
        state releasing {
            entry; do action release : ReleaseObject;
        }
        transition releasing_to_idle
            first releasing
            then idle;
    }

    action def PerformHumanoidTask {
        first start;
        then merge coordinateArms;
        then action perceiveScene : PerceiveEnvironment {
            out detectedObjects : WorkObject[*];
            out sceneMap : SensorData;
        }
        then action planLeftArm : PlanMotion {
            out trajectoryPlan : Real[*];
        }
        then action planRightArm : PlanMotion {
            out trajectoryPlan : Real[*];
        }
        then action moveLeftArm : MoveArm {
            in trajectory = planLeftArm.trajectoryPlan;
            out finalPosition : Real[3];
        }
        then action moveRightArm : MoveArm {
            in trajectory = planRightArm.trajectoryPlan;
            out finalPosition : Real[3];
        }
        then action graspLeft : GraspObject {
            out graspSuccess : Boolean;
        }
        then action graspRight : GraspObject {
            out graspSuccess : Boolean;
        }
        then action coordinatedManipulation : ManipulateObject {
            out manipulationSuccess : Boolean;
        }
        then action releaseLeft : ReleaseObject {
            out releaseSuccess : Boolean;
        }
        then action releaseRight : ReleaseObject {
            out releaseSuccess : Boolean;
        }
        then coordinateArms;
        then done;
    }

    part def Robonaut {
        attribute totalMass : ISQ::MassValue;
        attribute operatingVoltage : VoltageValue;
        attribute maxReach : ISQ::LengthValue;
        attribute dexterityLevel : Integer;
        
        perform action primaryTask[*] ordered references humanoidManipulation;
        
        part head : VisionSystem {
            attribute :>> mass = 8.0 [SI::kg];
            attribute :>> resolution = (1920, 1080);
            attribute :>> fieldOfView = 120.0 [SI::'°'];
        }
        
        part torsoAssembly : Torso {
            attribute :>> mass = 35.0 [SI::kg];
            attribute :>> height = 0.8 [SI::m];
            perform primaryTask.perceiveScene;
        }
        
        part leftArm : RoboticArm {
            attribute :>> mass = 18.0 [SI::kg];
            attribute :>> reach = 1.2 [SI::m];
            attribute :>> payloadCapacity = 10.0 [SI::kg];
            perform primaryTask.moveLeftArm;
        }
        
        part rightArm : RoboticArm {
            attribute :>> mass = 18.0 [SI::kg];
            attribute :>> reach = 1.2 [SI::m];
            attribute :>> payloadCapacity = 10.0 [SI::kg];
            perform primaryTask.moveRightArm;
        }
        
        part leftHand : DexterousHand {
            attribute :>> mass = 3.5 [SI::kg];
            attribute :>> fingerCount = 5;
            attribute :>> maxGripForce = 120.0 [SI::N];
            perform primaryTask.graspLeft;
        }
        
        part rightHand : DexterousHand {
            attribute :>> mass = 3.5 [SI::kg];
            attribute :>> fingerCount = 5;
            attribute :>> maxGripForce = 120.0 [SI::N];
            perform primaryTask.graspRight;
        }
        
        part mobilityBase : MobilityBase {
            attribute :>> mass = 40.0 [SI::kg];
            attribute :>> maxSpeed = 1.5;
        }
        
        part controlSystem : ControlComputer {
            attribute :>> mass = 12.0 [SI::kg];
            attribute :>> processorCores = 8;
            attribute :>> memoryCapacity = 64.0;
            perform primaryTask.planLeftArm;
            perform primaryTask.planRightArm;
        }
        
        part powerSystem : PowerSystem {
            attribute :>> mass = 25.0 [SI::kg];
            attribute :>> voltage = 48.0 [SI::V];
            attribute :>> capacity = 250.0;
            attribute :>> currentCharge = 250.0;
        }
        
        port mainComms : DataPort;
        port mainPower : PowerPort;
        
        connection powerToHead : PowerConnection connect powerSystem.powerOut to head.powerIn;
        connection powerToTorso : PowerConnection connect powerSystem.powerOut to torsoAssembly.powerIn;
        connection powerToLeftArm : PowerConnection connect powerSystem.powerOut to leftArm.powerIn;
        connection powerToRightArm : PowerConnection connect powerSystem.powerOut to rightArm.powerIn;
        connection powerToLeftHand : PowerConnection connect powerSystem.powerOut to leftHand.powerIn;
        connection powerToRightHand : PowerConnection connect powerSystem.powerOut to rightHand.powerIn;
        connection powerToBase : PowerConnection connect powerSystem.powerOut to mobilityBase.powerIn;
        connection powerToControl : PowerConnection connect powerSystem.powerOut to controlSystem.powerIn;
        
        connection visionToControl : DataConnection connect head.sensorOut to controlSystem.visionInput;
        connection controlToLeftArm : DataConnection connect controlSystem.commsPort to leftArm.controlIn;
        connection controlToRightArm : DataConnection connect controlSystem.commsPort to rightArm.controlIn;
        connection controlToLeftHand : DataConnection connect controlSystem.commsPort to leftHand.controlIn;
        connection controlToRightHand : DataConnection connect controlSystem.commsPort to rightHand.controlIn;
        connection controlToBase : DataConnection connect controlSystem.commsPort to mobilityBase.controlIn;
    }

    connection def PowerConnection {
        end source : PowerPort;
        end sink : PowerPort;
    }

    connection def DataConnection {
        end portA : DataPort;
        end portB : DataPort;
    }

    action humanoidManipulation : ManipulationStateMachine {
        first start;
        then action perceiveScene : PerceiveEnvironment {
            out detectedObjects : WorkObject[*];
            out sceneMap : SensorData;
        }
        then action planLeftArm : PlanMotion {
            out trajectoryPlan : Real[*];
        }
        then action planRightArm : PlanMotion {
            out trajectoryPlan : Real[*];
        }
        then merge dualArmSync;
        then action moveLeftArm : MoveArm {
            in trajectory = planLeftArm.trajectoryPlan;
            out finalPosition : Real[3];
        }
        then action moveRightArm : MoveArm {
            in trajectory = planRightArm.trajectoryPlan;
            out finalPosition : Real[3];
        }
        then action graspLeft : GraspObject {
            out graspSuccess : Boolean;
        }
        then action graspRight : GraspObject {
            out graspSuccess : Boolean;
        }
        then action coordinatedManipulation : ManipulateObject {
            out manipulationSuccess : Boolean;
        }
        then action releaseLeft : ReleaseObject {
            out releaseSuccess : Boolean;
        }
        then action releaseRight : ReleaseObject {
            out releaseSuccess : Boolean;
        }
        then dualArmSync;
        then done;
    }

    part robonaut : Robonaut {
        attribute :>> totalMass = head.mass + torsoAssembly.mass + leftArm.mass + rightArm.mass + 
                                   leftHand.mass + rightHand.mass + mobilityBase.mass + 
                                   controlSystem.mass + powerSystem.mass;
        attribute :>> operatingVoltage = 48.0 [SI::V];
        attribute :>> maxReach = 1.2 [SI::m];
        attribute :>> dexterityLevel = 5;
    }

    requirement def MissionCapability;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;

    requirement <'REQ-1000'> humanoidManipulationCapability : MissionCapability {
        doc /* The Robonaut shall perform dexterous manipulation tasks in human-oriented 
             * environments using dual anthropomorphic arms with human-like dexterity. */
        subject robonaut :>> RobonautSystem::robonaut;
    }

    requirement <'REQ-1001'> dualArmCoordination : PerformanceRequirement {
        doc /* The Robonaut shall coordinate both arms simultaneously for bimanual manipulation tasks. */
        subject robonaut :>> RobonautSystem::robonaut;
        assert constraint {
            robonaut.leftArm.reach >= 1.0 [SI::m] and robonaut.rightArm.reach >= 1.0 [SI::m]
        }
    }

    requirement <'REQ-1002'> dexterousGrasping : PerformanceRequirement {
        doc /* Each hand shall provide human-like dexterity with five-fingered grasping capability. */
        subject robonaut :>> RobonautSystem::robonaut;
        assert constraint {
            robonaut.leftHand.fingerCount == 5 and robonaut.rightHand.fingerCount == 5 and
            robonaut.leftHand.maxGripForce >= 100.0 [SI::N] and robonaut.rightHand.maxGripForce >= 100.0 [SI::N]
        }
    }

    requirement <'REQ-1003'> visionCapability : PerformanceRequirement {
        doc /* The vision system shall provide stereoscopic perception for object detection and manipulation. */
        subject head :>> RobonautSystem::robonaut.head;
        assert constraint {
            head.fieldOfView >= 100.0 [SI::'°']
        }
    }

    requirement <'REQ-1004'> massConstraint : PerformanceRequirement {
        doc /* The total system mass shall not exceed 200 kg to enable deployment and mobility. */
        subject robonaut :>> RobonautSystem::robonaut;
        assert constraint {
            robonaut.totalMass <= 200.0 [SI::kg]
        }
    }

    requirement <'REQ-1005'> powerEndurance : PerformanceRequirement {
        doc /* The power system shall provide sufficient capacity for extended operation. */
        subject powerSystem :>> RobonautSystem::robonaut.powerSystem;
        assert constraint {
            powerSystem.capacity >= 200.0 and powerSystem.voltage == 48.0 [SI::V]
        }
    }

    requirement <'REQ-1006'> safeOperation : SafetyRequirement {
        doc /* The control system shall continuously monitor safety parameters during operation. */
        subject controlSystem :>> RobonautSystem::robonaut.controlSystem;
        assert constraint {
            controlSystem.safetyMonitor.monitoringRate >= 100.0
        }
    }

    satisfy humanoidManipulationCapability by robonaut.primaryTask;
    satisfy dualArmCoordination by robonaut;
    satisfy dexterousGrasping by robonaut.leftHand;
    satisfy dexterousGrasping by robonaut.rightHand;
    satisfy visionCapability by robonaut.head;
    satisfy massConstraint by robonaut;
    satisfy powerEndurance by robonaut.powerSystem;
    satisfy safeOperation by robonaut.controlSystem;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import RobonautSystem::*;

    part testSubject : VisionSystem {
        exhibit state sm : ManipulationStateMachine;
    }

    action orchestrator {
        // TODO(human): unsupported trigger payload type for CommandMessage
    }
}

package HumanoidAssistantSystem {
    attribute def errorDetected;

    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TaskCommand;
    attribute def EnvironmentData;
    attribute def ObjectIdentifier;
    attribute def NavigationPath;
    attribute def ManipulationPlan;
    attribute def SystemStatus;
    
    attribute def JointAngle :> Real;
    attribute def JointTorque :> Real;
    attribute def GripForce :> Real;
    attribute def BatteryCharge :> Real;
    
    item def ElectricalPower;
    item def ControlData;
    item def SensorReading;
    
    port def PowerPort {
        in power : ElectricalPower;
    }
    
    port def ControlPort {
        in command : ControlData;
        out feedback : SensorReading;
    }
    
    port def DataPort {
        inout data : EnvironmentData;
    }
    
    port def UserInterfacePort {
        in taskCommand : TaskCommand;
        out status : SystemStatus;
    }
    
    part def VisionSensor {
        port sensorOut : DataPort {
            out data : EnvironmentData;
        }
        port powerIn : PowerPort;
        
        action captureImage {
            out imageData : EnvironmentData;
        }
    }
    
    part def RangeSensor {
        port sensorOut : DataPort {
            out data : EnvironmentData;
        }
        port powerIn : PowerPort;
        
        action measureDistance {
            out distanceData : LengthValue;
        }
    }
    
    part def AudioSensor {
        port sensorOut : DataPort {
            out data : EnvironmentData;
        }
        port powerIn : PowerPort;
        
        action captureAudio {
            out audioData : EnvironmentData;
        }
    }
    
    part def JointActuator {
        attribute maxTorque : JointTorque;
        attribute currentAngle : JointAngle;
        attribute targetAngle : JointAngle;
        
        port controlIn : ControlPort;
        port powerIn : PowerPort;
        
        action moveToAngle {
            in target : JointAngle;
            out achieved : JointAngle;
        }
    }
    
    part def Gripper {
        attribute maxForce : GripForce;
        attribute currentForce : GripForce;
        attribute isGrasping : Boolean;
        
        port controlIn : ControlPort;
        port powerIn : PowerPort;
        
        action grasp {
            in targetForce : GripForce;
            out graspSuccess : Boolean;
        }
        
        action release {
            out releaseSuccess : Boolean;
        }
    }
    
    part def Arm {
        part shoulder : JointActuator {
            :>> maxTorque = 50.0;
        }
        part elbow : JointActuator {
            :>> maxTorque = 30.0;
        }
        part wrist : JointActuator {
            :>> maxTorque = 15.0;
        }
        part gripper : Gripper {
            :>> maxForce = 100.0;
        }
        
        port armControl : ControlPort;
        port armPower : PowerPort;
        
        connection connect armControl to shoulder.controlIn;
        connection connect armControl to elbow.controlIn;
        connection connect armControl to wrist.controlIn;
        connection connect armControl to gripper.controlIn;
        
        connection connect armPower to shoulder.powerIn;
        connection connect armPower to elbow.powerIn;
        connection connect armPower to wrist.powerIn;
        connection connect armPower to gripper.powerIn;
    }
    
    part def Leg {
        part hip : JointActuator {
            :>> maxTorque = 80.0;
        }
        part knee : JointActuator {
            :>> maxTorque = 60.0;
        }
        part ankle : JointActuator {
            :>> maxTorque = 40.0;
        }
        
        port legControl : ControlPort;
        port legPower : PowerPort;
        
        connection connect legControl to hip.controlIn;
        connection connect legControl to knee.controlIn;
        connection connect legControl to ankle.controlIn;
        
        connection connect legPower to hip.powerIn;
        connection connect legPower to knee.powerIn;
        connection connect legPower to ankle.powerIn;
    }
    
    part def Head {
        part neckPan : JointActuator {
            :>> maxTorque = 10.0;
        }
        part neckTilt : JointActuator {
            :>> maxTorque = 10.0;
        }
        part visionSensor : VisionSensor;
        part rangeSensor : RangeSensor;
        part audioSensor : AudioSensor;
        
        port headControl : ControlPort;
        port headPower : PowerPort;
        port headData : DataPort;
        
        connection connect headControl to neckPan.controlIn;
        connection connect headControl to neckTilt.controlIn;
        connection connect headPower to neckPan.powerIn;
        connection connect headPower to neckTilt.powerIn;
        connection connect headPower to visionSensor.powerIn;
        connection connect headPower to rangeSensor.powerIn;
        connection connect headPower to audioSensor.powerIn;
        connection connect headData to visionSensor.sensorOut;
        connection connect headData to rangeSensor.sensorOut;
        connection connect headData to audioSensor.sensorOut;
    }
    
    part def PowerManagementSystem {
        attribute batteryCapacity : EnergyValue;
        attribute currentCharge : BatteryCharge;
        
        port powerOut : PowerPort {
            out power : ElectricalPower;
        }
        
        action monitorBattery {
            out chargeLevel : BatteryCharge;
        }
        
        action distributePower {
            in demand : PowerValue;
            out supply : ElectricalPower;
        }
    }
    
    part def PerceptionModule {
        action processVisualData {
            in rawImage : EnvironmentData;
            out objectList : ObjectIdentifier[*];
        }
        
        action buildEnvironmentMap {
            in sensorData : EnvironmentData[*];
            out environmentMap : EnvironmentData;
        }
        
        action detectObstacles {
            in rangeData : EnvironmentData;
            out obstacles : EnvironmentData[*];
        }
    }
    
    part def PlanningModule {
        action planNavigation {
            in currentPosition : LengthValue[3];
            in targetPosition : LengthValue[3];
            in obstacles : EnvironmentData[*];
            out path : NavigationPath;
        }
        
        action planManipulation {
            in objectPose : EnvironmentData;
            in targetPose : EnvironmentData;
            out manipulationPlan : ManipulationPlan;
        }
        
        action selectAction {
            in taskGoal : TaskCommand;
            in environmentState : EnvironmentData;
            out actionSequence : ControlData[*];
        }
    }
    
    part def ControlModule {
        action generateMotorCommands {
            in plan : ManipulationPlan;
            out commands : ControlData[*];
        }
        
        action maintainBalance {
            in bodyState : SensorReading;
            out balanceCorrection : ControlData;
        }
        
        action coordinateMovement {
            in leftArmCmd : ControlData;
            in rightArmCmd : ControlData;
            in leftLegCmd : ControlData;
            in rightLegCmd : ControlData;
            out synchronizedCmd : ControlData[*];
        }
    }
    
    action def PerceiveEnvironment {
        in sensorInputs : EnvironmentData[*];
        out worldModel : EnvironmentData;
    }
    
    action def DecideAction {
        in worldModel : EnvironmentData;
        in taskGoal : TaskCommand;
        out actionPlan : ManipulationPlan;
    }
    
    action def ExecuteAction {
        in actionPlan : ManipulationPlan;
        out executionStatus : SystemStatus;
    }
    
    action def AssistHuman {
        in userTask : TaskCommand;
        out taskResult : SystemStatus;
        
        first start;
        then merge operationCycle;
        
        action perceive : PerceiveEnvironment {
            in sensorInputs;
            out worldModel;
        }
        
        then action decide : DecideAction {
            in worldModel = perceive.worldModel;
            in taskGoal = userTask;
            out actionPlan;
        }
        
        then action execute : ExecuteAction {
            in actionPlan = decide.actionPlan;
            out executionStatus;
        }
        
        then decide;
            if execute.executionStatus == SystemStatus::taskComplete then reportSuccess;
            if execute.executionStatus == SystemStatus::taskInProgress then operationCycle;
        
        action reportSuccess {
            assign taskResult := SystemStatus::taskComplete;
        }
        then done;
    }
    
    state def OperationalMode {
        entry action initialize;
        do action operateNormally;
        exit action shutdown;
        
        state standby {
            entry action enterStandby;
        }
        state active {
            entry action activateSystems;
        }
        state executing {
            entry action beginExecution;
        }
        state recovering {
            entry action initiateRecovery;
        }
        state lowPower {
            entry action reducePower;
        }
        
        transition standby_to_active
            first standby
            accept taskReceived : TaskCommand
            then active;
        
        transition active_to_executing
            first active
            if planReady
            then executing;
        
        transition executing_to_standby
            first executing
            if taskCompleted
            then standby;
        
        transition any_to_recovering
            first standby
            accept errorDetected
            then recovering;
        
        transition recovering_to_standby
            first recovering
            if systemNominal
            then standby;
        
        transition any_to_lowPower
            first standby
            if batteryLow
            then lowPower;
        
        transition lowPower_to_standby
            first lowPower
            if batteryCharged
            then standby;
    }
    
    part def Humanoid {
        doc /* 
            A humanoid robotic system designed to assist humans by autonomously 
            perceiving the environment, making intelligent decisions, and executing 
            physical tasks involving navigation, manipulation, and interaction with 
            objects and people in human-centric environments.
        */
        
        part leftArm : Arm;
        part rightArm : Arm;
        part leftLeg : Leg;
        part rightLeg : Leg;
        part head : Head;
        part torso {
            part waist : JointActuator {
                :>> maxTorque = 100.0;
            }
        }
        
        part powerSystem : PowerManagementSystem {
            :>> batteryCapacity = 10000.0 [W * h];
            :>> currentCharge = 100.0;
        }
        
        part perceptionModule : PerceptionModule;
        part planningModule : PlanningModule;
        part controlModule : ControlModule;
        
        port userInterface : UserInterfacePort;
        
        connection powerToLeftArm connect powerSystem.powerOut to leftArm.armPower;
        connection powerToRightArm connect powerSystem.powerOut to rightArm.armPower;
        connection powerToLeftLeg connect powerSystem.powerOut to leftLeg.legPower;
        connection powerToRightLeg connect powerSystem.powerOut to rightLeg.legPower;
        connection powerToHead connect powerSystem.powerOut to head.headPower;
        connection powerToTorso connect powerSystem.powerOut to torso.waist.powerIn;
        
        connection headDataToPerception connect head.headData to perceptionModule;
        connection perceptionToPlanning connect perceptionModule to planningModule;
        connection planningToControl connect planningModule to controlModule;
        connection controlToLeftArm connect controlModule to leftArm.armControl;
        connection controlToRightArm connect controlModule to rightArm.armControl;
        connection controlToLeftLeg connect controlModule to leftLeg.legControl;
        connection controlToRightLeg connect controlModule to rightLeg.legControl;
        connection controlToHead connect controlModule to head.headControl;
        
        perform action primaryFunction : AssistHuman {
            in userTask = userInterface.taskCommand;
            out taskResult;
        }
        
        state operationalMode : OperationalMode;
    }
    
    requirement def FunctionalRequirement {
        doc /* Base requirement for system functionality */
    }
    
    requirement def PerformanceRequirement {
        doc /* Base requirement for system performance */
    }
    
    requirement def SafetyRequirement {
        doc /* Base requirement for system safety */
    }
    
    requirement <'HR-F-001'> primaryMissionRequirement : FunctionalRequirement {
        doc /* 
            The Humanoid system shall autonomously assist humans by perceiving 
            its environment, making intelligent decisions about task execution, 
            and performing physical actions including navigation, object manipulation, 
            and human-robot interaction in dynamic, unstructured environments.
        */
        subject humanoid : Humanoid;
        
        assume constraint environmentAccessible {
            doc /* The environment is accessible and navigable by the humanoid */
        }
        
        assume constraint tasksWellDefined {
            doc /* Task commands are properly formatted and achievable */
        }
    }
    
    requirement <'HR-P-001'> manipulationCapability : PerformanceRequirement {
        doc /* 
            The Humanoid shall manipulate objects with a maximum payload 
            of 5 kg per arm with positioning accuracy of ±5 mm.
        */
        subject humanoid : Humanoid;
    }
    
    requirement <'HR-P-002'> mobilityRequirement : PerformanceRequirement {
        doc /* 
            The Humanoid shall navigate at speeds up to 1.5 m/s and 
            maintain balance on surfaces with inclinations up to 15 degrees.
        */
        subject humanoid : Humanoid;
    }
    
    requirement <'HR-P-003'> enduranceRequirement : PerformanceRequirement {
        doc /* 
            The Humanoid shall operate continuously for at least 4 hours 
            on a single battery charge under normal operating conditions.
        */
        subject humanoid : Humanoid;
    }
    
    requirement <'HR-S-001'> collisionAvoidance : SafetyRequirement {
        doc /* 
            The Humanoid shall detect and avoid collisions with humans, 
            obstacles, and other objects during all operations.
        */
        subject humanoid : Humanoid;
    }
    
    requirement <'HR-S-002'> emergencyStop : SafetyRequirement {
        doc /* 
            The Humanoid shall execute an emergency stop within 0.5 seconds 
            of detecting a critical safety condition.
        */
        subject humanoid : Humanoid;
    }
    
    part humanoidAssistant : Humanoid {
        satisfy primaryMissionRequirement by self;
        satisfy manipulationCapability by self;
        satisfy mobilityRequirement by self;
        satisfy enduranceRequirement by self;
        satisfy collisionAvoidance by self;
        satisfy emergencyStop by self;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import HumanoidAssistantSystem::*;

    part testSubject : VisionSensor {
        exhibit state sm : OperationalMode;
    }

    action orchestrator {
        action perceiveProbe : PerceiveEnvironment {
            // TODO(human): unsupported input type for sensorInputs: EnvironmentData[*] (type is not a primitive, enum, extracted payload def, or known value type)
        }
        attribute testErrorDetected : errorDetected;
        action triggererrorDetected send testErrorDetected to testSubject;
        first perceiveProbe;
        then triggererrorDetected;
    }
}

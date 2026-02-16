package ArticulatedSoftRoboticsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def PressureValue :> ISQ::pressure;
    attribute def AngleValue :> ISQ::planeAngle;
    attribute def ForceValue :> ISQ::force;
    attribute def FlowRateValue :> Real;
    attribute def ComplianceValue :> Real;
    attribute def StrainValue :> Real;
    
    enum def ActuationMode {
        idle;
        inflating;
        deflating;
        holding;
        emergency;
    }
    
    enum def GripperState {
        open;
        closing;
        gripping;
        releasing;
    }
    
    item def SoftMaterial {
        attribute elasticModulus : Real;
        attribute maxStrain : StrainValue;
        attribute compliance : ComplianceValue;
    }
    
    port def PneumaticPort {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }
    
    port def SensorPort {
        attribute signal : Real;
    }
    
    port def ControlPort {
        attribute command : Real;
        attribute feedback : Real;
    }
    
    part def PressureSensor {
        attribute reading : PressureValue;
        port output : SensorPort;
    }
    
    part def BendingSensor {
        attribute angle : AngleValue;
        port output : SensorPort;
    }
    
    part def ForceSensor {
        attribute force : ForceValue;
        attribute threshold : ForceValue;
        port output : SensorPort;
    }
    
    part def PneumaticValve {
        attribute isOpen : Boolean;
        attribute maxFlow : FlowRateValue;
        port inlet : PneumaticPort;
        port outlet : PneumaticPort;
        port control : ControlPort;
    }
    
    part def AirCompressor {
        attribute maxPressure : PressureValue;
        attribute flowRate : FlowRateValue;
        port airOut : PneumaticPort;
    }
    
    part def SoftActuatorSegment {
        attribute material : SoftMaterial;
        attribute currentPressure : PressureValue;
        attribute bendAngle : AngleValue;
        attribute segmentLength : LengthValue;
        attribute maxBendAngle : AngleValue;
        
        port pneumaticIn : PneumaticPort;
        port controlIn : ControlPort;
        
        part pressureSensor : PressureSensor;
        part bendSensor : BendingSensor;
        
        state def SegmentControl {
            entry; then idle;
            
            state idle;
            
            state inflating;
            
            state holding;
            
            state deflating;
            
            transition idle_to_inflating
                first idle
                accept InflateCommand
                then inflating;
            
            transition inflating_to_holding
                first inflating
                if pressureSensor.reading >= controlIn.command
                then holding;
            
            transition holding_to_deflating
                first holding
                accept DeflateCommand
                then deflating;
            
            transition deflating_to_idle
                first deflating
                if pressureSensor.reading <= 5.0
                then idle;
        }
    }
    
    part def SoftGripper {
        attribute numberOfFingers : Integer;
        attribute maxGripForce : ForceValue;
        attribute currentState : GripperState;
        
        port pneumaticSupply : PneumaticPort;
        port controlIn : ControlPort;
        
        part finger1 : SoftActuatorSegment {
            attribute :>> segmentLength = 80.0 [mm];
            attribute :>> maxBendAngle = 90.0 [deg];
        }
        part finger2 : SoftActuatorSegment {
            attribute :>> segmentLength = 80.0 [mm];
            attribute :>> maxBendAngle = 90.0 [deg];
        }
        part finger3 : SoftActuatorSegment {
            attribute :>> segmentLength = 80.0 [mm];
            attribute :>> maxBendAngle = 90.0 [deg];
        }
        part forceSensor : ForceSensor {
            attribute :>> threshold = 30.0 [N];
        }
        
        action def GraspObject {
            in targetForce : ForceValue;
            out achieved : Boolean;
            
            first start;
            then action closeFinger1;
            then action closeFinger2;
            then action closeFinger3;
            then action checkForce {
                out measured : ForceValue;
            }
            then decide;
                if checkForce.measured >= targetForce then success;
                if checkForce.measured < targetForce then adjustGrip;
            action success {
                out achieved = true;
            }
            action adjustGrip {
                out achieved = false;
            }
            then done;
        }
        
        action def ReleaseObject {
            first start;
            then action openFinger1;
            then action openFinger2;
            then action openFinger3;
            then done;
        }
    }
    
    part def ArticulatedArm {
        attribute numberOfSegments : Integer;
        attribute totalLength : LengthValue;
        attribute maxReach : LengthValue;
        attribute maxPayload : MassValue;
        
        port pneumaticSupply : PneumaticPort;
        port controlBus : ControlPort;
        
        part baseSegment : SoftActuatorSegment {
            attribute :>> segmentLength = 150.0 [mm];
            attribute :>> maxBendAngle = 120.0 [deg];
        }
        part midSegment : SoftActuatorSegment {
            attribute :>> segmentLength = 150.0 [mm];
            attribute :>> maxBendAngle = 120.0 [deg];
        }
        part tipSegment : SoftActuatorSegment {
            attribute :>> segmentLength = 100.0 [mm];
            attribute :>> maxBendAngle = 90.0 [deg];
        }
        part endEffector : SoftGripper {
            attribute :>> numberOfFingers = 3;
            attribute :>> maxGripForce = 50.0 [N];
        }
    }
    
    part def PneumaticControlUnit {
        attribute targetPressure : PressureValue;
        attribute operatingMode : ActuationMode;
        
        port compressorControl : ControlPort;
        port valveControl : ControlPort;
        port sensorFeedback : SensorPort;
        
        part compressor : AirCompressor {
            attribute :>> maxPressure = 600.0 [kPa];
            attribute :>> flowRate = 50.0;
        }
        part supplyValve : PneumaticValve {
            attribute :>> maxFlow = 40.0;
        }
        part exhaustValve : PneumaticValve {
            attribute :>> maxFlow = 40.0;
        }
        part regulator : PressureSensor;
        
        action def RegulateSupplyPressure {
            in target : PressureValue;
            in current : PressureValue;
            out valveCommand : Real;
            
            first start;
            then merge checkPressure;
            then action measure {
                in currentPressure = current;
                out error : Real;
            }
            then decide;
                if measure.error > 10.0 then increase;
                if measure.error < -10.0 then decrease;
                if abs(measure.error) <= 10.0 then maintain;
            action increase {
                out valveCommand = 1.0;
            }
            then checkPressure;
            action decrease {
                out valveCommand = 0.0;
            }
            then checkPressure;
            action maintain {
                out valveCommand = 0.5;
            }
            then done;
        }
    }
    
    part def MotionController {
        attribute desiredPose : AngleValue[3];
        attribute currentPose : AngleValue[3];
        attribute controlGain : Real;
        
        port armControl : ControlPort;
        port gripperControl : ControlPort;
        port sensorInput : SensorPort;
        
        action def CalculateInverseKinematics {
            in targetPosition : Real[3];
            out jointAngles : AngleValue[3];
        }
        
        action def ExecuteMotion {
            in targetAngles : AngleValue[3];
            out commands : Real[3];
        }
    }
    
    action def PerformPickAndPlace {
        first start;
        then merge beginOperation;
        
        then action moveToApproach {
            in approachPose : AngleValue[3];
            out reached : Boolean;
        }
        
        then decide;
            if moveToApproach.reached then openGripper;
            if not moveToApproach.reached then retry;
        
        action retry;
        then beginOperation;
        
        action openGripper;
        
        then action moveToGrasp {
            in graspPose : AngleValue[3];
            out positioned : Boolean;
        }
        
        then action closeGripper {
            in targetForce : ForceValue;
            out grasped : Boolean;
        }
        
        then action liftObject {
            in liftHeight : LengthValue;
            out lifted : Boolean;
        }
        
        then action moveToPlace {
            in placePose : AngleValue[3];
            out arrived : Boolean;
        }
        
        then action releaseObject;
        
        then action retractArm;
        
        then done;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The articulated soft robotics system shall safely manipulate delicate objects 
             * in unstructured environments through compliant grasping and precise positioning. */
    }
    
    requirement <'REQ-ASR-001'> safeManipulation : PrimaryFunctionRequirement {
        doc /* The system shall manipulate objects without causing damage through compliant interaction. */
        subject system : ArticulatedSoftRoboticsSystem;
    }
    
    requirement <'REQ-ASR-002'> maxGripForce {
        doc /* The gripper shall limit maximum grip force to prevent object damage. */
        subject gripper : SoftGripper;
        require constraint {
            gripper.maxGripForce <= 50.0 [N]
        }
    }
    
    requirement <'REQ-ASR-003'> pressureLimit {
        doc /* The pneumatic system shall not exceed safe operating pressure. */
        subject pneumatics : PneumaticControlUnit;
        require constraint {
            pneumatics.compressor.maxPressure <= 600.0 [kPa]
        }
    }
    
    requirement <'REQ-ASR-004'> payloadCapacity {
        doc /* The articulated arm shall support minimum payload capacity. */
        subject arm : ArticulatedArm;
        require constraint {
            arm.maxPayload >= 2.0 [kg]
        }
    }
    
    requirement <'REQ-ASR-005'> workspaceReach {
        doc /* The articulated arm shall achieve minimum workspace reach. */
        subject arm : ArticulatedArm;
        require constraint {
            arm.maxReach >= 400.0 [mm]
        }
    }
    
    requirement <'REQ-ASR-006'> materialCompliance {
        doc /* The soft actuator material shall provide sufficient compliance for safe interaction. */
        subject segment : SoftActuatorSegment;
        require constraint {
            segment.material.compliance >= 0.7
        }
    }
    
    part articulatedSoftRobot : ArticulatedSoftRoboticsSystem {
        attribute systemMass : MassValue = 3.2 [kg];
        attribute operatingVoltage : Real = 24.0;
        
        part arm : ArticulatedArm {
            attribute :>> numberOfSegments = 3;
            attribute :>> totalLength = 400.0 [mm];
            attribute :>> maxReach = 450.0 [mm];
            attribute :>> maxPayload = 2.5 [kg];
            
            part :>> baseSegment {
                part :>> material {
                    attribute :>> elasticModulus = 0.5;
                    attribute :>> maxStrain = 3.0;
                    attribute :>> compliance = 0.85;
                }
            }
            
            part :>> endEffector {
                attribute :>> currentState = GripperState::open;
            }
        }
        
        part pneumaticSystem : PneumaticControlUnit {
            attribute :>> targetPressure = 400.0 [kPa];
            attribute :>> operatingMode = ActuationMode::idle;
        }
        
        part motionControl : MotionController {
            attribute :>> controlGain = 0.75;
        }
        
        connection pneumaticSupply connect
            pneumaticSystem.compressor.airOut to arm.pneumaticSupply;
        
        connection armControlConnection connect
            motionControl.armControl to arm.controlBus;
        
        connection gripperControlConnection connect
            motionControl.gripperControl to arm.endEffector.controlIn;
        
        connection baseSegmentPneumatic connect
            arm.pneumaticSupply to arm.baseSegment.pneumaticIn;
        
        connection midSegmentPneumatic connect
            arm.pneumaticSupply to arm.midSegment.pneumaticIn;
        
        connection tipSegmentPneumatic connect
            arm.pneumaticSupply to arm.tipSegment.pneumaticIn;
        
        connection gripperPneumatic connect
            arm.pneumaticSupply to arm.endEffector.pneumaticSupply;
        
        perform action manipulationTask : PerformPickAndPlace;
    }
    
    satisfy safeManipulation by articulatedSoftRobot;
    satisfy maxGripForce by articulatedSoftRobot.arm.endEffector;
    satisfy pressureLimit by articulatedSoftRobot.pneumaticSystem;
    satisfy payloadCapacity by articulatedSoftRobot.arm;
    satisfy workspaceReach by articulatedSoftRobot.arm;
    satisfy materialCompliance by articulatedSoftRobot.arm.baseSegment;
}

package NecroboticsGripperSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def PressureValue :> ISQ::PressureValue;
    attribute def ForceValue :> ISQ::ForceValue;
    attribute def MassValue :> ISQ::MassValue;
    attribute def TimeValue :> ISQ::TimeValue;
    attribute def LengthValue :> ISQ::LengthValue;
    
    enum def GripperState {
        relaxed;
        actuated;
        gripping;
        releasing;
    }
    
    enum def ControlCommand {
        actuate;
        release;
        hold;
    }

    item def TargetObject {
        attribute mass : MassValue;
        attribute diameter : LengthValue;
    }
    
    item def PneumaticFluid {
        attribute pressure : PressureValue;
        attribute flowRate : Real;
    }

    port def PneumaticPort {
        inout fluid : PneumaticFluid;
    }
    
    port def ControlPort {
        in command : ControlCommand;
        out status : GripperState;
    }
    
    port def SensorPort {
        out contactDetected : Boolean;
        out appliedForce : ForceValue;
    }

    part def SpiderCarcassGripper {
        doc /* Preserved spider carcass used as a biologically-derived gripper mechanism.
             * The prosoma (cephalothorax) acts as a hydraulic chamber that extends
             * the legs when pressurized. */
        
        attribute bodyMass : MassValue = 0.5 [SI::g];
        attribute maxGripForce : ForceValue = 0.35 [SI::N];
        attribute operatingPressure : PressureValue = 55158.0 [SI::Pa];
        attribute currentState : GripperState = GripperState::relaxed;
        attribute appliedForce : ForceValue;
        
        port pneumaticInput : PneumaticPort;
        port sensorOutput : SensorPort;
        
        action def UpdateStateRelaxed {
            assign currentState = GripperState::relaxed;
            assign appliedForce = maxGripForce;
        }
        
        action def UpdateStateActuated {
            assign currentState = GripperState::actuated;
            assign appliedForce = 0.0 [SI::N];
        }
        
        action def UpdateStateGripping {
            assign currentState = GripperState::gripping;
            assign appliedForce = 0.3 [SI::N];
        }
        
        action def UpdateStateReleasing {
            assign currentState = GripperState::releasing;
            assign appliedForce = 0.1 [SI::N];
        }
    }
    
    part def PneumaticActuationSystem {
        doc /* Pneumatic system providing controlled air pressure to actuate the gripper. */
        
        attribute maxPressure : PressureValue = 68947.6 [SI::Pa];
        attribute currentPressure : PressureValue;
        attribute responseTime : TimeValue = 0.2 [SI::s];
        
        port pneumaticOutput : PneumaticPort;
        port controlInput : ControlPort;
        
        part airPump {
            attribute pumpPressure : PressureValue = 68947.6 [SI::Pa];
        }
        
        part pressureRegulator {
            attribute setPoint : PressureValue;
            attribute tolerance : PressureValue = 3447.4 [SI::Pa];
        }
        
        part solenoidValve {
            attribute isOpen : Boolean;
        }
        
        action def RegulateFlow {
            in targetPressure : PressureValue;
            in command : ControlCommand;
            out outputPressure : PressureValue;
            
            first start;
            then decide;
                if command == ControlCommand::actuate then pressurize;
                if command == ControlCommand::release then depressurize;
                if command == ControlCommand::hold then maintain;
            
            action pressurize {
                assign outputPressure = targetPressure;
            }
            then done;
            
            action depressurize {
                assign outputPressure = 0.0 [SI::Pa];
            }
            then done;
            
            action maintain {
                assign outputPressure = currentPressure;
            }
            then done;
        }
    }
    
    part def MicrocontrollerUnit {
        doc /* Electronic control unit managing gripper operation and sensor feedback. */
        
        attribute cycleTime : TimeValue = 0.05 [SI::s];
        attribute targetForce : ForceValue = 0.3 [SI::N];
        
        port controlOutput : ControlPort;
        port sensorInput : SensorPort;
        port externalCommand;
        
        action def ControlLoop {
            in desiredForce : ForceValue;
            in sensorFeedback : SensorPort;
            out controlSignal : ControlCommand;
            
            first start;
            then action readSensors {
                out contactStatus : Boolean = sensorFeedback.contactDetected;
                out measuredForce : ForceValue = sensorFeedback.appliedForce;
            }
            then decide;
                if readSensors.contactStatus == false then sendActuate;
                if readSensors.measuredForce < desiredForce then sendHold;
                if readSensors.measuredForce >= desiredForce then sendRelease;
            
            action sendActuate {
                assign controlSignal = ControlCommand::actuate;
            }
            then done;
            
            action sendHold {
                assign controlSignal = ControlCommand::hold;
            }
            then done;
            
            action sendRelease {
                assign controlSignal = ControlCommand::release;
            }
            then done;
        }
    }
    
    part def ContactSensor {
        doc /* Sensor detecting contact between gripper and target object. */
        
        attribute sensitivity : ForceValue = 0.05 [SI::N];
        attribute detectionThreshold : ForceValue = 0.1 [SI::N];
        
        port sensorOutput : SensorPort;
    }

    part def NecroboticsGripperSystem {
        doc /* Complete necrobotics gripper system integrating biological and 
             * electromechanical components for object manipulation. */
        
        attribute maxPayload : MassValue = 0.65 [SI::g];
        attribute gripCycles : Integer;
        attribute systemMass : MassValue;
        
        part gripper : SpiderCarcassGripper {
            attribute :>> bodyMass = 0.5 [SI::g];
            attribute :>> maxGripForce = 0.35 [SI::N];
            attribute :>> operatingPressure = 55158.0 [SI::Pa];
        }
        
        part actuationSystem : PneumaticActuationSystem {
            attribute :>> maxPressure = 68947.6 [SI::Pa];
            attribute :>> responseTime = 0.2 [SI::s];
        }
        
        part controller : MicrocontrollerUnit {
            attribute :>> cycleTime = 0.05 [SI::s];
            attribute :>> targetForce = 0.3 [SI::N];
            
            perform action controlLoop[*] ordered
                references ControlLoop;
        }
        
        part sensor : ContactSensor {
            attribute :>> sensitivity = 0.05 [SI::N];
            attribute :>> detectionThreshold = 0.1 [SI::N];
        }
        
        connect actuationSystem.pneumaticOutput to gripper.pneumaticInput;
        connect controller.controlOutput to actuationSystem.controlInput;
        connect sensor.sensorOutput to controller.sensorInput;
        connect gripper.sensorOutput to sensor.sensorOutput;
        
        assert constraint massBalance {
            systemMass == gripper.bodyMass + 2.0 [SI::g]
        }
        
        assert constraint payloadCapacity {
            maxPayload >= 1.3 * gripper.bodyMass
        }
        
        assert constraint forceRequirement {
            gripper.maxGripForce >= 0.3 [SI::N]
        }
    }

    action def GraspAndReleaseSequence {
        doc /* Primary operational sequence for grasping and releasing objects. */
        
        in targetObject : TargetObject;
        in gripDuration : TimeValue;
        out success : Boolean;
        
        first start;
        then action approach {
            doc /* Position gripper near target object. */
        }
        then action actuate {
            doc /* Apply pneumatic pressure to extend gripper legs. */
            out pressure : PressureValue = 55158.0 [SI::Pa];
        }
        then action detectContact {
            doc /* Monitor sensors for object contact. */
            out contacted : Boolean;
        }
        then decide;
            if detectContact.contacted == true then grip;
            if detectContact.contacted == false then retry;
        
        action grip {
            doc /* Reduce pressure to allow legs to curl and grip object. */
            out holdPressure : PressureValue = 13789.5 [SI::Pa];
        }
        then action hold {
            doc /* Maintain grip for specified duration. */
            in duration = gripDuration;
        }
        then action release {
            doc /* Fully depressurize to release object. */
            out releasePressure : PressureValue = 0.0 [SI::Pa];
        }
        then action verify {
            assign success = true;
        }
        then done;
        
        action retry {
            doc /* Retry actuation if contact not detected. */
        }
        then actuate;
    }

    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    
    requirement <'REQ-NB-001'> primaryFunction : FunctionalRequirement {
        doc /* The necrobotics gripper system shall grasp and release small objects
             * using pneumatically-actuated preserved biological tissue. */
        subject system : NecroboticsGripperSystem;
    }
    
    requirement <'REQ-NB-002'> payloadCapability : PerformanceRequirement {
        doc /* The system shall manipulate objects with mass up to 130% of the
             * gripper body mass. */
        subject system : NecroboticsGripperSystem;
        
        assert constraint {
            system.maxPayload >= 1.3 * system.gripper.bodyMass
        }
    }
    
    requirement <'REQ-NB-003'> gripForce : PerformanceRequirement {
        doc /* The gripper shall exert a minimum force of 0.3 N when in gripping state. */
        subject gripper : SpiderCarcassGripper;
        
        assert constraint {
            gripper.maxGripForce >= 0.3 [SI::N]
        }
    }
    
    requirement <'REQ-NB-004'> actuationPressure : PerformanceRequirement {
        doc /* The actuation system shall provide controlled pressure up to 68947.6 Pa. */
        subject actuationSystem : PneumaticActuationSystem;
        
        assert constraint {
            actuationSystem.maxPressure <= 68947.6 [SI::Pa]
        }
    }
    
    requirement <'REQ-NB-005'> responseTime : PerformanceRequirement {
        doc /* The system shall respond to control commands within 0.2 seconds. */
        subject actuationSystem : PneumaticActuationSystem;
        
        assert constraint {
            actuationSystem.responseTime <= 0.2 [SI::s]
        }
    }
    
    requirement <'REQ-NB-006'> cycleDurability : PerformanceRequirement {
        doc /* The gripper shall maintain functionality for at least 1000 actuation cycles. */
        subject system : NecroboticsGripperSystem;
        
        assert constraint {
            system.gripCycles >= 1000
        }
    }
    
    requirement <'REQ-NB-007'> pressureSafety : SafetyRequirement {
        doc /* The system shall not exceed maximum safe operating pressure to prevent
             * tissue damage. */
        subject actuationSystem : PneumaticActuationSystem;
        
        assert constraint {
            actuationSystem.currentPressure <= actuationSystem.maxPressure
        }
    }
    
    part necroboticsGripper : NecroboticsGripperSystem;
    
    satisfy primaryFunction by necroboticsGripper;
    satisfy payloadCapability by necroboticsGripper;
    satisfy gripForce by necroboticsGripper.gripper;
    satisfy actuationPressure by necroboticsGripper.actuationSystem;
    satisfy responseTime by necroboticsGripper.actuationSystem;
    satisfy cycleDurability by necroboticsGripper;
    satisfy pressureSafety by necroboticsGripper.actuationSystem;
}

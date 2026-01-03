package 'Soft Robotics System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
    attribute def ForceValue :> ISQ::ForceValue;
    attribute def DisplacementValue :> ISQ::LengthValue;
    attribute def ComplianceValue :> Real;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    
    attribute def GraspCommand {
        attribute targetForce : ForceValue;
        attribute targetCompliance : ComplianceValue;
    }
    
    attribute def ReleaseCommand;
    
    attribute def ActuatorState {
        attribute currentPressure : PressureValue;
        attribute currentDisplacement : DisplacementValue;
        attribute currentCompliance : ComplianceValue;
    }
    
    item def CompressedAir {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute temperature : TemperatureValue;
    }
    
    port def PneumaticPort {
        inout item air : CompressedAir;
    }
    
    port def ControlPort {
        in command : GraspCommand;
        out status : ActuatorState;
    }
    
    port def SensorPort {
        out force : ForceValue;
        out displacement : DisplacementValue;
    }
    
    part def AirCompressor {
        attribute maxOutputPressure : PressureValue;
        attribute maxFlowRate : FlowRateValue;
        out port pneumaticOutput : PneumaticPort;
    }
    
    part def PressureRegulator {
        attribute setPointPressure : PressureValue;
        in port pneumaticInput : PneumaticPort;
        out port pneumaticOutput : PneumaticPort[3];
        in attribute controlSignal : Real;
    }
    
    part def SoftPneumaticActuator {
        attribute maxPressure : PressureValue;
        attribute maxDisplacement : DisplacementValue;
        attribute materialCompliance : ComplianceValue;
        in port pneumaticInput : PneumaticPort;
        out port sensorOutput : SensorPort;
    }
    
    part def ForceSensor {
        attribute sensitivity : Real;
        attribute measurementRange : ForceValue;
        in port sensorInput : SensorPort;
        out measuredForce : ForceValue;
    }
    
    part def ControlUnit {
        in targetGrasp : GraspCommand;
        in sensorFeedback : ActuatorState[3];
        out pressureCommand : Real;
        out systemStatus : ActuatorState;
    }
    
    part def FlexibleGripper {
        attribute numberOfFingers : Integer;
        attribute maxGraspForce : ForceValue;
        part actuators : SoftPneumaticActuator[3];
        in port controlInterface : ControlPort;
    }
    
    action def InflateActuator {
        in targetPressure : PressureValue;
        in currentPressure : PressureValue;
        out outputPressure : PressureValue;
        out displacement : DisplacementValue;
    }
    
    action def DeflateActuator {
        in currentPressure : PressureValue;
        out outputPressure : PressureValue;
    }
    
    action def MeasureGraspForce {
        in actuatorState : ActuatorState;
        out graspForce : ForceValue;
    }
    
    action def AdjustCompliance {
        in targetCompliance : ComplianceValue;
        in currentPressure : PressureValue;
        out adjustedPressure : PressureValue;
    }
    
    action def PerformGrasp {
        in graspCmd : GraspCommand;
        out finalForce : ForceValue;
        out finalState : ActuatorState;
        
        first start;
        then merge controlLoop;
        
        then action initializeActuators {
            out initialPressure : PressureValue;
        }
        
        then action inflateSequence : InflateActuator {
            in targetPressure;
            in currentPressure = initializeActuators.initialPressure;
            out outputPressure;
            out displacement;
        }
        
        then action measureContact : MeasureGraspForce {
            in actuatorState {
                attribute currentPressure = inflateSequence.outputPressure;
                attribute currentDisplacement = inflateSequence.displacement;
                attribute currentCompliance = graspCmd.targetCompliance;
            }
            out graspForce;
        }
        
        then decide;
            if measureContact.graspForce < graspCmd.targetForce then adjustPressure;
            if measureContact.graspForce >= graspCmd.targetForce then maintainGrasp;
        
        action adjustPressure : AdjustCompliance {
            in targetCompliance = graspCmd.targetCompliance;
            in currentPressure = inflateSequence.outputPressure;
            out adjustedPressure;
        }
        then controlLoop;
        
        action maintainGrasp {
            out heldForce : ForceValue = measureContact.graspForce;
            out heldState : ActuatorState;
        }
        
        then assign finalForce := maintainGrasp.heldForce;
        then assign finalState := maintainGrasp.heldState;
        then done;
    }
    
    action def ReleaseObject {
        in currentState : ActuatorState;
        
        first start;
        then action deflate : DeflateActuator {
            in currentPressure = currentState.currentPressure;
            out outputPressure;
        }
        then action openGripper {
            in releasePressure : PressureValue = deflate.outputPressure;
        }
        then done;
    }
    
    state def GripperStateMachine {
        entry; then idle;
        
        state idle;
        
        accept graspCommand : GraspCommand
            then grasping;
        
        state grasping {
            do action activeGrasp : PerformGrasp;
        }
        
        accept releaseCommand : ReleaseCommand
            then releasing;
        
        state releasing {
            do action activeRelease : ReleaseObject;
        }
        then idle;
    }
    
    part softRoboticsSystem : FlexibleGripper {
        attribute numberOfFingers = 3;
        attribute maxGraspForce : ForceValue;
        
        part compressor : AirCompressor {
            attribute maxOutputPressure : PressureValue;
            attribute maxFlowRate : FlowRateValue;
        }
        
        part regulator : PressureRegulator {
            attribute setPointPressure : PressureValue;
        }
        
        part gripper : FlexibleGripper {
            attribute numberOfFingers = 3;
            
            part finger1 : SoftPneumaticActuator {
                attribute maxPressure : PressureValue;
                attribute maxDisplacement : DisplacementValue;
                attribute materialCompliance : ComplianceValue;
            }
            
            part finger2 : SoftPneumaticActuator {
                attribute maxPressure : PressureValue;
                attribute maxDisplacement : DisplacementValue;
                attribute materialCompliance : ComplianceValue;
            }
            
            part finger3 : SoftPneumaticActuator {
                attribute maxPressure : PressureValue;
                attribute maxDisplacement : DisplacementValue;
                attribute materialCompliance : ComplianceValue;
            }
            
            perform action graspOperation[*] ordered references graspSequence;
        }
        
        part forceSensors : ForceSensor[3] {
            attribute sensitivity = 0.01;
            attribute measurementRange : ForceValue;
        }
        
        part controller : ControlUnit;
        
        connect compressor.pneumaticOutput to regulator.pneumaticInput {
            item flow airSupply : CompressedAir;
        }
        
        connect regulator.pneumaticOutput[1] to gripper.finger1.pneumaticInput {
            item flow airToFinger1 : CompressedAir;
        }
        
        connect regulator.pneumaticOutput[2] to gripper.finger2.pneumaticInput {
            item flow airToFinger2 : CompressedAir;
        }
        
        connect regulator.pneumaticOutput[3] to gripper.finger3.pneumaticInput {
            item flow airToFinger3 : CompressedAir;
        }
    }
    
    action graspSequence : PerformGrasp {
        in graspCmd : GraspCommand {
            attribute targetForce : ForceValue;
            attribute targetCompliance : ComplianceValue;
        }
        out finalForce : ForceValue;
        out finalState : ActuatorState;
    }
    
    requirement <'SR-001'> softGraspRequirement {
        doc /* The soft robotics system shall grasp delicate objects without damage 
             by conforming to object geometry and applying controlled force through 
             compliant pneumatic actuators. */
        
        subject softRoboticsSystem;
        
        require constraint maxForceLimit {
            softRoboticsSystem.maxGraspForce <= 50.0
        }
        
        require constraint adaptiveConformance {
            softRoboticsSystem.gripper.numberOfFingers >= 3
        }
    }
    
    requirement <'SR-002'> safetyRequirement {
        doc /* The system shall operate at safe pressure levels and include 
             pressure relief mechanisms to prevent actuator damage. */
        
        subject softRoboticsSystem;
        
        require constraint pressureSafety {
            softRoboticsSystem.compressor.maxOutputPressure <= 600.0
        }
    }
    
    requirement <'SR-003'> performanceRequirement {
        doc /* The system shall achieve grasp within specified time and 
             maintain stable grip force with minimal variation. */
        
        subject graspSequence;
        
        assume constraint initialConditions {
            graspSequence.graspCmd.targetForce > 0.0
        }
        
        require constraint forceAccuracy {
            (graspSequence.finalForce - graspSequence.graspCmd.targetForce).abs() 
                <= graspSequence.graspCmd.targetForce * 0.1
        }
    }
}

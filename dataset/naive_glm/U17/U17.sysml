package SoftRoboticArmSystem {
    import ISQ::*;
    
    attribute def Pressure :> Real { unit "kPa"; }
    attribute def FlowRate :> Real { unit "L/min"; }
    attribute def Force :> Real { unit "N"; }
    attribute def BendingAngle :> Real { unit "deg"; }
    attribute def Length :> Real { unit "mm"; }
    attribute def Position :> Real { unit "mm"; }
    attribute def PressureCommand :> Real { unit "kPa"; }
    
    item def CompressedAir;
    item def DelicateObject;
    
    enum def GripperState { open, closing, gripping, releasing; }
    
    port def PneumaticPort {
        inout item air : CompressedAir;
    }
    port def PressureSensorPort {
        out attribute pressure : Pressure;
    }
    port def BendingSensorPort {
        out attribute bending : BendingAngle;
    }
    port def ForceSensorPort {
        out attribute force : Force;
    }
    port def ValveCommandPort {
        in attribute pressureCmd : PressureCommand;
    }
    port def PressureCommandPort {
        in attribute basePressureCmd : PressureCommand;
        in attribute middlePressureCmd : PressureCommand;
        in attribute tipPressureCmd : PressureCommand;
        in attribute gripperPressureCmd : PressureCommand;
    }
    port def GripperCommandPort {
        in attribute cmd : GripperState;
    }
    port def MotionCommandPort {
        in attribute targetX : Position;
        in attribute targetY : Position;
        in attribute targetZ : Position;
    }
    
    part def PressureSensor {
        attribute measuredPressure : Pressure;
        port pressureOut : PressureSensorPort;
        bind pressureOut.pressure = measuredPressure;
    }
    part def BendingSensor {
        attribute measuredBending : BendingAngle;
        port bendingOut : BendingSensorPort;
        bind bendingOut.bending = measuredBending;
    }
    part def ForceSensor {
        attribute measuredForce : Force;
        port forceOut : ForceSensorPort;
        bind forceOut.force = measuredForce;
    }
    
    part def AirCompressor {
        attribute outputPressure : Pressure;
        attribute flowRate : FlowRate;
        port airOut : PneumaticPort;
    }
    part def Valve {
        attribute openState : Boolean;
        attribute regulatedPressure : Pressure;
        port airIn : PneumaticPort;
        port airOut : PneumaticPort;
        port commandIn : ValveCommandPort;
        bind regulatedPressure = commandIn.pressureCmd;
    }
    
    part def SoftActuatorSegment {
        attribute targetPressure : Pressure;
        attribute currentPressure : Pressure;
        attribute currentBending : BendingAngle;
        attribute segmentLength : Length;
        port pneumaticPort : PneumaticPort;
        port pressureFeedback : PressureSensorPort;
        port bendingFeedback : BendingSensorPort;
        part pressureSensor : PressureSensor;
        part bendingSensor : BendingSensor;
        bind currentPressure = pressureSensor.measuredPressure;
        bind currentBending = bendingSensor.measuredBending;
        bind pressureFeedback.pressure = pressureSensor.measuredPressure;
        bind bendingFeedback.bending = bendingSensor.measuredBending;
        state machine ActuatorStateMachine {
            state inflating;
            state deflating;
            state holding;
            transition inflating -> holding when (currentPressure >= targetPressure);
            transition holding -> deflating when (targetPressure < currentPressure);
            transition deflating -> holding when (currentPressure <= targetPressure);
            transition holding -> inflating when (targetPressure > currentPressure);
        }
    }
    
    part def SoftFinger {
        attribute targetPressure : Pressure;
        attribute currentPressure : Pressure;
        port pneumaticPort : PneumaticPort;
        port pressureFeedback : PressureSensorPort;
        part pressureSensor : PressureSensor;
        bind currentPressure = pressureSensor.measuredPressure;
        bind pressureFeedback.pressure = pressureSensor.measuredPressure;
        state machine FingerStateMachine {
            state inflating;
            state deflating;
            state holding;
            transition inflating -> holding when (currentPressure >= targetPressure);
            transition holding -> deflating when (targetPressure < currentPressure);
            transition deflating -> holding when (currentPressure <= targetPressure);
            transition holding -> inflating when (targetPressure > currentPressure);
        }
    }
    
    part def SoftGripper {
        attribute gripForce : Force;
        attribute maxGripForce : Force = 5.0;
        attribute minGripForce : Force = 0.5;
        attribute fingerTargetPressure : Pressure;
        port gripperCommand : GripperCommandPort;
        port forceFeedback : ForceSensorPort;
        port pneumaticPort : PneumaticPort;
        part fingers : SoftFinger[3];
        part forceSensor : ForceSensor;
        bind forceFeedback.force = forceSensor.measuredForce;
        bind fingers.targetPressure = fingerTargetPressure;
        connect pneumaticPort to fingers.pneumaticPort;
        state machine GripperStateMachine {
            state open {
                entry { fingerTargetPressure = 0; }
            }
            state closing {
                entry { fingerTargetPressure = 100; }
            }
            state gripping {
                entry { fingerTargetPressure = 80; }
            }
            state releasing {
                entry { fingerTargetPressure = 0; }
            }
            transition open -> closing when (gripperCommand.cmd == GripperState::closing);
            transition closing -> gripping when (forceSensor.measuredForce >= minGripForce);
            transition gripping -> releasing when (gripperCommand.cmd == GripperState::releasing);
            transition releasing -> open when (forceSensor.measuredForce == 0);
        }
    }
    
    part def PneumaticControlUnit {
        attribute supplyPressure : Pressure = 200.0;
        port basePneumatic : PneumaticPort;
        port middlePneumatic : PneumaticPort;
        port tipPneumatic : PneumaticPort;
        port gripperPneumatic : PneumaticPort;
        port commandIn : PressureCommandPort;
        part compressor : AirCompressor;
        part baseValve : Valve;
        part middleValve : Valve;
        part tipValve : Valve;
        part gripperValve : Valve;
        connect compressor.airOut to baseValve.airIn;
        connect compressor.airOut to middleValve.airIn;
        connect compressor.airOut to tipValve.airIn;
        connect compressor.airOut to gripperValve.airIn;
        connect baseValve.airOut to basePneumatic;
        connect middleValve.airOut to middlePneumatic;
        connect tipValve.airOut to tipPneumatic;
        connect gripperValve.airOut to gripperPneumatic;
        bind baseValve.commandIn.pressureCmd = commandIn.basePressureCmd;
        bind middleValve.commandIn.pressureCmd = commandIn.middlePressureCmd;
        bind tipValve.commandIn.pressureCmd = commandIn.tipPressureCmd;
        bind gripperValve.commandIn.pressureCmd = commandIn.gripperPressureCmd;
        state machine PneumaticStateMachine {
            state idle;
            state regulating;
            transition idle -> regulating when (commandIn.basePressureCmd > 0);
            transition regulating -> idle when (commandIn.basePressureCmd == 0);
        }
    }
    
    part def MotionController {
        attribute targetX : Position;
        attribute targetY : Position;
        attribute targetZ : Position;
        attribute taskComplete : Boolean;
        port motionCommand : MotionCommandPort;
        port basePressureFeedback : PressureSensorPort;
        port baseBendingFeedback : BendingSensorPort;
        port middlePressureFeedback : PressureSensorPort;
        port middleBendingFeedback : BendingSensorPort;
        port tipPressureFeedback : PressureSensorPort;
        port tipBendingFeedback : BendingSensorPort;
        port gripperForceFeedback : ForceSensorPort;
        port pneumaticCommand : PressureCommandPort;
        port gripperCommand : GripperCommandPort;
        state machine ControllerStateMachine {
            state idle;
            state planning {
                entry {
                    pneumaticCommand.basePressureCmd = 50;
                    pneumaticCommand.middlePressureCmd = 60;
                    pneumaticCommand.tipPressureCmd = 70;
                    gripperCommand.cmd = GripperState::closing;
                }
            }
            state executing;
            state monitoring;
            transition idle -> planning when (motionCommand.targetX != 0);
            transition planning -> executing when (true);
            transition executing -> monitoring when (true);
            transition monitoring -> idle when (taskComplete);
        }
    }
    
    part def ArticulatedSoftArm {
        part baseSegment : SoftActuatorSegment;
        part middleSegment : SoftActuatorSegment;
        part tipSegment : SoftActuatorSegment;
    }
    
    part def SoftRoboticArmSystem {
        port userCommand : MotionCommandPort;
        part arm : ArticulatedSoftArm;
        part gripper : SoftGripper;
        part pneumaticUnit : PneumaticControlUnit;
        part controller : MotionController;
        
        connect userCommand to controller.motionCommand;
        connect pneumaticUnit.basePneumatic to arm.baseSegment.pneumaticPort;
        connect pneumaticUnit.middlePneumatic to arm.middleSegment.pneumaticPort;
        connect pneumaticUnit.tipPneumatic to arm.tipSegment.pneumaticPort;
        connect pneumaticUnit.gripperPneumatic to gripper.pneumaticPort;
        connect arm.baseSegment.pressureFeedback to controller.basePressureFeedback;
        connect arm.baseSegment.bendingFeedback to controller.baseBendingFeedback;
        connect arm.middleSegment.pressureFeedback to controller.middlePressureFeedback;
        connect arm.middleSegment.bendingFeedback to controller.middleBendingFeedback;
        connect arm.tipSegment.pressureFeedback to controller.tipPressureFeedback;
        connect arm.tipSegment.bendingFeedback to controller.tipBendingFeedback;
        connect gripper.forceFeedback to controller.gripperForceFeedback;
        connect controller.pneumaticCommand to pneumaticUnit.commandIn;
        connect controller.gripperCommand to gripper.gripperCommand;
        
        bind arm.baseSegment.targetPressure = pneumaticUnit.baseValve.regulatedPressure;
        bind arm.middleSegment.targetPressure = pneumaticUnit.middleValve.regulatedPressure;
        bind arm.tipSegment.targetPressure = pneumaticUnit.tipValve.regulatedPressure;
        bind gripper.fingerTargetPressure = pneumaticUnit.gripperValve.regulatedPressure;
    }
    
    requirement def SafeHandlingRequirement {
        doc "The system shall handle delicate objects without causing damage.";
        subject : SoftRoboticArmSystem;
        require {
            constraint { gripper.gripForce <= gripper.maxGripForce }
        }
    }
    requirement def PickAndPlaceRequirement {
        doc "The system shall perform pick and place tasks by coordinating arm and gripper.";
        subject : SoftRoboticArmSystem;
        require {
            constraint { controller.taskComplete == true }
        }
    }
    requirement def PneumaticControlRequirement {
        doc "The pneumatic control unit shall regulate air pressure to all soft actuators.";
        subject : PneumaticControlUnit;
        require {
            constraint { supplyPressure >= 100.0 [kPa] }
        }
    }
}

package IndustrialRoboticArmSystem {

    import ISQ::*;
    import SI::*;

    // ---------- Value Types ----------
    value def AngleValue :> RealValue { unit 'deg'; }
    value def TorqueValue :> RealValue { unit 'N*m'; }
    value def ForceValue :> RealValue { unit 'N'; }
    value def MassValue :> RealValue { unit 'kg'; }
    value def LengthValue :> RealValue { unit 'mm'; }
    value def VoltageValue :> RealValue { unit 'V'; }
    value def CurrentValue :> RealValue { unit 'A'; }
    value def PowerValue :> RealValue { unit 'W'; }
    value def CoordinateValue :> RealValue { unit 'mm'; }

    value def Position3D {
        attribute x : CoordinateValue;
        attribute y : CoordinateValue;
        attribute z : CoordinateValue;
    }

    value def Orientation3D {
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
    }

    value def Pose {
        attribute position : Position3D;
        attribute orientation : Orientation3D;
    }

    value def JointCommand {
        attribute targetAngle : AngleValue;
        attribute targetTorque : TorqueValue;
    }

    value def JointFeedback {
        attribute currentAngle : AngleValue;
        attribute currentTorque : TorqueValue;
    }

    value def GripperCommand {
        attribute gripForce : ForceValue;
        attribute closed : Boolean;
    }

    value def GripperFeedback {
        attribute measuredForce : ForceValue;
        attribute objectDetected : Boolean;
    }

    value def RobotCommand {
        attribute targetPose : Pose;
        attribute payloadMass : MassValue;
    }

    // ---------- Port Definitions ----------
    port def JointCommandPort {
        out attribute command : JointCommand;
    }

    port def JointFeedbackPort {
        out attribute feedback : JointFeedback;
    }

    port def GripperCommandPort {
        out attribute command : GripperCommand;
    }

    port def GripperFeedbackPort {
        out attribute feedback : GripperFeedback;
    }

    port def RobotCommandPort {
        in attribute command : RobotCommand;
    }

    port def PowerPort {
        out attribute voltage : VoltageValue;
        out attribute current : CurrentValue;
    }

    // ---------- Item Definitions ----------
    item def PowerFlow;
    item def ControlSignal;

    // ---------- Requirements ----------
    requirement def PositioningAccuracyRequirement {
        doc /* The system shall position its gripper within 0.5 mm of a target coordinate. */
        attribute maxPositionError : LengthValue = 0.5 [mm];
        subject :> positioningSystem;
        constraint { positioningSystem.positionError <= maxPositionError }
    }

    requirement def PayloadCapacityRequirement {
        doc /* The system shall handle payloads up to 5 kg. */
        attribute maxPayload : MassValue = 5 [kg];
        subject :> payloadSystem;
        constraint { payloadSystem.payloadMass <= maxPayload }
    }

    requirement def SafetyForceLimitRequirement {
        doc /* The system shall limit the forces it exerts to ensure safe operation. */
        attribute maxExertedForce : ForceValue = 80 [N];
        subject :> forceSystem;
        constraint { forceSystem.exertedForce <= maxExertedForce }
    }

    requirement def JointRangeRequirement {
        doc /* Each joint shall rotate within its specified angular range. */
        attribute minAngle : AngleValue;
        attribute maxAngle : AngleValue;
        subject :> joint;
        constraint { joint.currentAngle >= minAngle and joint.currentAngle <= maxAngle }
    }

    requirement def ClosedLoopControlRequirement {
        doc /* The controller shall continuously receive joint feedback and adjust commands. */
        subject :> controlLoop;
        constraint { controlLoop.feedbackRate >= 1000 [Hz] }
    }

    // ---------- Joint Part ----------
    part def Joint {
        attribute jointId : String;
        attribute minAngle : AngleValue;
        attribute maxAngle : AngleValue;
        attribute maxTorque : TorqueValue;
        attribute currentAngle : AngleValue;
        attribute currentTorque : TorqueValue;

        port commandIn : JointCommandPort;
        port feedbackOut : JointFeedbackPort;
        port powerIn : PowerPort;

        requirement jointRange : JointRangeRequirement {
            attribute minAngle = self.minAngle;
            attribute maxAngle = self.maxAngle;
            subject = self;
        }

        state def JointBehavior {
            entry; then Idle;
            state Idle;
            state Moving;
            state Holding;
            state Faulted;

            transition Idle_to_Moving
                first Idle
                if commandIn.command.targetAngle != currentAngle
                then Moving;

            transition Moving_to_Holding
                first Moving
                if abs(currentAngle - commandIn.command.targetAngle) < 0.1 [deg]
                then Holding;

            transition Holding_to_Moving
                first Holding
                if commandIn.command.targetAngle != currentAngle
                then Moving;

            transition to_Faulted
                first {Idle, Moving, Holding}
                if currentTorque > maxTorque
                then Faulted;

            transition Faulted_to_Idle
                first Faulted
                if currentTorque <= maxTorque
                then Idle;
        }

        action def ExecuteJointMotion {
            in cmd : JointCommand;
            out fb : JointFeedback;
            perform {
                // Apply torque toward target angle
                if cmd.targetAngle > currentAngle {
                    currentTorque := min(cmd.targetTorque, maxTorque);
                    currentAngle := currentAngle + 0.5 [deg];
                } else if cmd.targetAngle < currentAngle {
                    currentTorque := min(cmd.targetTorque, maxTorque);
                    currentAngle := currentAngle - 0.5 [deg];
                } else {
                    currentTorque := 0 [N*m];
                }
                fb.currentAngle := currentAngle;
                fb.currentTorque := currentTorque;
            }
        }
    }

    // ---------- Specific Joint Specializations ----------
    part def ShoulderJoint :> Joint {
        attribute minAngle = -180 [deg];
        attribute maxAngle = 180 [deg];
        attribute maxTorque = 200 [N*m];
    }

    part def UpperArmJoint :> Joint {
        attribute minAngle = -90 [deg];
        attribute maxAngle = 90 [deg];
        attribute maxTorque = 180 [N*m];
    }

    part def ElbowJoint :> Joint {
        attribute minAngle = -135 [deg];
        attribute maxAngle = 135 [deg];
        attribute maxTorque = 150 [N*m];
    }

    part def ForearmJoint :> Joint {
        attribute minAngle = -180 [deg];
        attribute maxAngle = 180 [deg];
        attribute maxTorque = 100 [N*m];
    }

    part def WristAxis1Joint :> Joint {
        attribute minAngle = -180 [deg];
        attribute maxAngle = 180 [deg];
        attribute maxTorque = 50 [N*m];
    }

    part def WristAxis2Joint :> Joint {
        attribute minAngle = -180 [deg];
        attribute maxAngle = 180 [deg];
        attribute maxTorque = 50 [N*m];
    }

    // ---------- Gripper ----------
    part def Gripper {
        attribute maxGripForce : ForceValue = 60 [N];
        attribute currentForce : ForceValue;
        attribute isClosed : Boolean = false;
        attribute objectDetected : Boolean = false;

        port commandIn : GripperCommandPort;
        port feedbackOut : GripperFeedbackPort;
        port powerIn : PowerPort;

        state def GripperBehavior {
            entry; then Open;
            state Open;
            state Closing;
            state Closed;
            state Releasing;

            transition Open_to_Closing
                first Open
                if commandIn.command.closed == true
                then Closing;

            transition Closing_to_Closed
                first Closing
                if objectDetected == true or currentForce >= commandIn.command.gripForce
                then Closed;

            transition Closed_to_Releasing
                first Closed
                if commandIn.command.closed == false
                then Releasing;

            transition Releasing_to_Open
                first Releasing
                if currentForce <= 0 [N]
                then Open;
        }

        action def ActuateGripper {
            in cmd : GripperCommand;
            out fb : GripperFeedback;
            perform {
                if cmd.closed == true {
                    currentForce := min(cmd.gripForce, maxGripForce);
                    isClosed := true;
                    if currentForce >= 5 [N] { objectDetected := true; }
                } else {
                    currentForce := 0 [N];
                    isClosed := false;
                    objectDetected := false;
                }
                fb.measuredForce := currentForce;
                fb.objectDetected := objectDetected;
            }
        }
    }

    // ---------- End Effector ----------
    part def EndEffector {
        port gripperCommandOut : GripperCommandPort;
        port gripperFeedbackIn : GripperFeedbackPort;
        port powerIn : PowerPort;

        part gripper : Gripper {
            port commandIn :> gripperCommandOut;
            port feedbackOut :> gripperFeedbackIn;
            port powerIn :> powerIn;
        }
    }

    // ---------- Articulated Arm ----------
    part def ArticulatedArm {
        port jointCommandOut[6] : JointCommandPort;
        port jointFeedbackIn[6] : JointFeedbackPort;
        port powerIn : PowerPort;

        part shoulder : ShoulderJoint {
            port commandIn :> jointCommandOut[1];
            port feedbackOut :> jointFeedbackIn[1];
            port powerIn :> powerIn;
        }

        part upperArm : UpperArmJoint {
            port commandIn :> jointCommandOut[2];
            port feedbackOut :> jointFeedbackIn[2];
            port powerIn :> powerIn;
        }

        part elbow : ElbowJoint {
            port commandIn :> jointCommandOut[3];
            port feedbackOut :> jointFeedbackIn[3];
            port powerIn :> powerIn;
        }

        part forearm : ForearmJoint {
            port commandIn :> jointCommandOut[4];
            port feedbackOut :> jointFeedbackIn[4];
            port powerIn :> powerIn;
        }

        part wristAxis1 : WristAxis1Joint {
            port commandIn :> jointCommandOut[5];
            port feedbackOut :> jointFeedbackIn[5];
            port powerIn :> powerIn;
        }

        part wristAxis2 : WristAxis2Joint {
            port commandIn :> jointCommandOut[6];
            port feedbackOut :> jointFeedbackIn[6];
            port powerIn :> powerIn;
        }

        part endEffector : EndEffector {
            port powerIn :> powerIn;
        }
    }

    // ---------- Controller ----------
    part def CentralController {
        attribute positionError : LengthValue;
        attribute payloadMass : MassValue;
        attribute exertedForce : ForceValue;
        attribute feedbackRate : Real = 1000;

        port robotCommandIn : RobotCommandPort;
        port jointCommandOut[6] : JointCommandPort;
        port jointFeedbackIn[6] : JointFeedbackPort;
        port gripperCommandOut : GripperCommandPort;
        port gripperFeedbackIn : GripperFeedbackPort;
        port powerIn : PowerPort;

        requirement positioning : PositioningAccuracyRequirement {
            subject = self;
        }
        requirement payload : PayloadCapacityRequirement {
            subject = self;
        }
        requirement safety : SafetyForceLimitRequirement {
            subject = self;
        }
        requirement closedLoop : ClosedLoopControlRequirement {
            subject = self;
        }

        state def ControllerBehavior {
            entry; then WaitingForCommand;
            state WaitingForCommand;
            state Computing;
            state Executing;
            state Monitoring;
            state EmergencyStop;

            transition Waiting_to_Computing
                first WaitingForCommand
                if robotCommandIn.command.targetPose != null
                then Computing;

            transition Computing_to_Executing
                first Computing
                then Executing;

            transition Executing_to_Monitoring
                first Executing
                then Monitoring;

            transition Monitoring_to_Waiting
                first Monitoring
                if allJointsAtTarget() == true
                then WaitingForCommand;

            transition to_EmergencyStop
                first {Computing, Executing, Monitoring}
                if safetyViolation() == true
                then EmergencyStop;

            transition EmergencyStop_to_Waiting
                first EmergencyStop
                if safetyViolation() == false
                then WaitingForCommand;
        }

        action def InverseKinematics {
            in targetPose : Pose;
            out jointCommands[6] : JointCommand;
            perform {
                // Compute joint angles from target pose
                jointCommands[1].targetAngle := computeShoulderAngle(targetPose);
                jointCommands[2].targetAngle := computeUpperArmAngle(targetPose);
                jointCommands[3].targetAngle := computeElbowAngle(targetPose);
                jointCommands[4].targetAngle := computeForearmAngle(targetPose);
                jointCommands[5].targetAngle := computeWrist1Angle(targetPose);
                jointCommands[6].targetAngle := computeWrist2Angle(targetPose);
                // Set default torque values
                for i in 1..6 {
                    jointCommands[i].targetTorque := 50 [N*m];
                }
            }
        }

        action def MonitorFeedback {
            in feedback[6] : JointFeedback;
            out adjustedCommands[6] : JointCommand;
            perform {
                for i in 1..6 {
                    if abs(feedback[i].currentAngle - jointCommandOut[i].command.targetAngle) > 2 [deg] {
                        adjustedCommands[i].targetTorque := jointCommandOut[i].command.targetTorque + 5 [N*m];
                    }
                }
            }
        }

        private computeShoulderAngle(p : Pose) : AngleValue;
        private computeUpperArmAngle(p : Pose) : AngleValue;
        private computeElbowAngle(p : Pose) : AngleValue;
        private computeForearmAngle(p : Pose) : AngleValue;
        private computeWrist1Angle(p : Pose) : AngleValue;
        private computeWrist2Angle(p : Pose) : AngleValue;
        private allJointsAtTarget() : Boolean;
        private safetyViolation() : Boolean;
    }

    // ---------- Power Supply ----------
    part def PowerSupply {
        attribute outputVoltage : VoltageValue = 48 [V];
        attribute maxCurrent : CurrentValue = 50 [A];
        attribute totalPower : PowerValue;

        port powerOut : PowerPort;

        action def RegulatePower {
            out v : VoltageValue;
            out i : CurrentValue;
            perform {
                v := outputVoltage;
                i := maxCurrent;
                totalPower := v * i;
            }
        }
    }

    // ---------- Top-Level Robotic Arm System ----------
    part def RoboticArmSystem {
        attribute systemId : String = "ROBOT-6AXIS-001";
        attribute maxReach : LengthValue = 850 [mm];
        attribute maxPayload : MassValue = 5 [kg];

        port commandIn : RobotCommandPort;
        port powerIn : PowerPort;

        part powerSupply : PowerSupply {
            port powerOut :> powerIn;
        }

        part controller : CentralController {
            port robotCommandIn :> commandIn;
            port powerIn :> powerIn;
        }

        part arm : ArticulatedArm {
            port powerIn :> powerIn;
        }

        // Connect controller joint commands to arm joints
        connection : JointCommandPort connect controller.jointCommandOut[1] to arm.jointCommandOut[1];
        connection : JointCommandPort connect controller.jointCommandOut[2] to arm.jointCommandOut[2];
        connection : JointCommandPort connect controller.jointCommandOut[3] to arm.jointCommandOut[3];
        connection : JointCommandPort connect controller.jointCommandOut[4] to arm.jointCommandOut[4];
        connection : JointCommandPort connect controller.jointCommandOut[5] to arm.jointCommandOut[5];
        connection : JointCommandPort connect controller.jointCommandOut[6] to arm.jointCommandOut[6];

        // Connect arm joint feedback to controller
        connection : JointFeedbackPort connect arm.jointFeedbackIn[1] to controller.jointFeedbackIn[1];
        connection : JointFeedbackPort connect arm.jointFeedbackIn[2] to controller.jointFeedbackIn[2];
        connection : JointFeedbackPort connect arm.jointFeedbackIn[3] to controller.jointFeedbackIn[3];
        connection : JointFeedbackPort connect arm.jointFeedbackIn[4] to controller.jointFeedbackIn[4];
        connection : JointFeedbackPort connect arm.jointFeedbackIn[5] to controller.jointFeedbackIn[5];
        connection : JointFeedbackPort connect arm.jointFeedbackIn[6] to controller.jointFeedbackIn[6];

        // Connect controller to gripper
        connection : GripperCommandPort connect controller.gripperCommandOut to arm.endEffector.gripperCommandOut;
        connection : GripperFeedbackPort connect arm.endEffector.gripperFeedbackIn to controller.gripperFeedbackIn;

        // Power distribution
        connection : PowerPort connect powerSupply.powerOut to controller.powerIn;
        connection : PowerPort connect powerSupply.powerOut to arm.powerIn;

        // System-level requirements
        requirement sysPositioning : PositioningAccuracyRequirement {
            subject = self;
        }
        requirement sysPayload : PayloadCapacityRequirement {
            subject = self;
        }
        requirement sysSafety : SafetyForceLimitRequirement {
            subject = self;
        }

        action def PickAndPlaceSequence {
            in sourcePose : Pose;
            in destPose : Pose;
            in payload : MassValue;
            perform {
                // Move to source
                action moveToSource : InverseKinematics {
                    in targetPose = sourcePose;
                }
                // Close gripper
                action gripObject {
                    perform {
                        controller.gripperCommandOut.command.closed := true;
                        controller.gripperCommandOut.command.gripForce := 30 [N];
                    }
                }
                // Move to destination
                action moveToDest : InverseKinematics {
                    in targetPose = destPose;
                }
                // Release object
                action releaseObject {
                    perform {
                        controller.gripperCommandOut.command.closed := false;
                        controller.gripperCommandOut.command.gripForce := 0 [N];
                    }
                }
            }
        }
    }

}

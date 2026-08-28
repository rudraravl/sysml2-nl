package ContinuumRobotSystem {
    import ScalarValues::*;

    // ---------- Value Types with Units ----------
    attribute def Length :> Real { unit 'mm'; }
    attribute def Mass :> Real { unit 'kg'; }
    attribute def Force :> Real { unit 'N'; }
    attribute def Pressure :> Real {> Real { unit 'kPa'; }
    attribute def Voltage :> Real { unit 'V'; }
    attribute def Current :> Real { unit 'A'; }
    attribute def Power :> Real { unit 'W'; }
    attribute def TimeValue :> Real { unit 's'; }
    attribute def Frequency :> Real { unit 'Hz'; }
    attribute def Angle :> Real { unit 'deg'; }
    attribute def Percent :> Real { unit '%'; }
    attribute def Accuracy :> Real { unit 'mm'; }
    attribute def FlowRate :> Real { unit 'L/min'; }

    // ---------- Item Definitions ----------
    item def PneumaticFluid;
    item def TaskObjective {
        attribute targetPosition : Length[3];
        attribute targetOrientation : Angle[3];
        attribute payloadMass : Mass;
    }
    item def GraspCommand {
        attribute commandOpen : Boolean;
        attribute commandForce : Force;
    }
    item def ActuationCommand {
        attribute segmentId : Integer;
        actuatorId : Integer;
        targetPressure : Pressure;
    }
    item def ShapeFeedback {
        attribute segmentId : Integer;
        attribute bendAngle : Angle;
        attribute curvature : Real;
        attribute position : Length[3];
    }
    item def ForceFeedback {
        attribute measuredForce : Force;
        attribute contactDetected : Boolean;
    }

    // ---------- Port Definitions ----------
    port def PressureCommandPort {
        out item commands : ActuationCommand[*];
    }
    port def ShapeFeedbackPort {
        in item feedback : ShapeFeedback[*];
    }
    port def ForceFeedbackPort {
        in item feedback : ForceFeedback;
    }
    port def GraspCommandPort {
        out item command : GraspCommand;
    }
    port def PowerPort {
        in attribute voltage : Voltage;
        in attribute current : Current;
    }
    port def PneumaticPort {
        out item fluid : PneumaticFluid;
        attribute pressure : Pressure;
        attribute flow : FlowRate;
    }
    port def TaskPort {
        in item task : TaskObjective;
        out attribute taskAccepted : Boolean;
        out attribute taskComplete : Boolean;
    }

    // ---------- Requirements ----------
    requirement def PositioningAccuracyRequirement {
        doc { The system shall position the end-effector tip within 2 mm of the commanded target. }
        attribute requiredAccuracy : Accuracy = 2.0 [mm];
        subject robot : ContinuumRobot;
        assert { |robot.tipPositionError| <= requiredAccuracy; }
    }

    requirement def PayloadCapacityRequirement {
        doc { The end-effector shall grasp and hold objects up to 2 kg without slip or damage. }
        attribute maxPayload : Mass = 2.0 [kg];
        subject gripper : GripperEndEffector;
        assert { gripper.ratedPayload >= maxPayload; }
    }

    requirement def TaskSuccessRateRequirement {
        doc { The system shall achieve a task success rate of at least 98 percent over 1000 missions. }
        attribute minSuccessRate : Percent = 98.0 [%];
        subject system : ContinuumRobot;
        attribute observedSuccessRate : Percent;
        assert { observedSuccessRate >= minSuccessRate; }
    }

    requirement def ReliabilityRequirement {
        doc { The system shall demonstrate mean time between failures of at least 1000 hours. }
        attribute minMTBF : TimeValue = 1000.0 [s * 1000];
        subject system : ContinuumRobot;
        attribute observedMTBF : TimeValue;
        assert { observedMTBF >= minMTBF; }
    }

    requirement def ArmLengthRequirement {
        doc { The continuum arm shall be approximately 600 mm in length. }
        attribute nominalLength : Length = 600.0 [mm];
        subject arm : ContinuumArm;
        assert { arm.totalLength ~= nominalLength; }
    }

    requirement def SegmentCountRequirement {
        doc { The continuum arm shall comprise three bendable segments. }
        attribute segmentCount : Integer = 3;
        subject arm : ContinuumArm;
        assert { arm.segments->size() == segmentCount; }
    }

    requirement def ActuatorCountRequirement {
        doc { The arm shall be driven by nine pneumatic actuators, three per segment. }
        attribute actuatorCount : Integer = 9;
        subject arm : ContinuumArm;
        assert { arm.actuators->size() == actuatorCount; }
    }

    requirement def SystemPerformanceRequirement {
        satisfy PositioningAccuracyRequirement;
        satisfy PayloadCapacityRequirement;
        satisfy TaskSuccessRateRequirement;
        satisfy ReliabilityRequirement;
        satisfy ArmLengthRequirement;
        satisfy SegmentCountRequirement;
        satisfy ActuatorCountRequirement;
    }

    // ---------- Part Definitions ----------
    part def PneumaticActuator {
        attribute id : Integer;
        attribute segmentId : Integer;
        attribute maxPressure : Pressure = 600.0 [kPa];
        attribute maxForce : Force = 80.0 [N];
        attribute currentPressure : Pressure;
        port in cmdPort : PressureCommandPort;
        port in pneumaticIn : PneumaticPort;
        attribute commandedPressure : Pressure;
        attribute cylinderLength : Length = 100.0 [mm];

        action def Actuate {
            in pressure : Pressure;
            out forceOut : Force;
            // Constrain pressure within limits
            assign currentPressure = clamp(pressure, 0.0 [kPa], maxPressure);
            assign forceOut = currentPressure * 0.0001 [N/kPa] * 1.0; // simplified mapping
        }
        compute actuationLogic {
            receive cmd : ActuationCommand from cmdPort.commands;
            assign commandedPressure = cmd.targetPressure;
            do Actuate(commandedPressure);
        }
    }

    part def ShapeSensor {
        attribute id : Integer;
        attribute segmentId : Integer;
        attribute sampleRate : Frequency = 100.0 [Hz];
        attribute bendAngle : Angle;
        attribute curvature : Real;
        attribute positionEstimate : Length[3];
        port out fbPort : ShapeFeedbackPort {
            output feedback : ShapeFeedback = ShapeFeedback{segmentId = segmentId; bendAngle = bendAngle; curvature = curvature; position = positionEstimate;};
        }
        action def SampleShape {
            // Represents strain/EM-based shape estimation
            assign bendAngle = readBend();
            assign curvature = bendAngle / 200.0 [mm];
            assign positionEstimate = computeForwardKinematics(bendAngle, curvature);
        }
        attribute readBend : Angle;
        compute sense {
            do SampleShape();
        }
    }

    part def ContinuumSegment {
        attribute id : Integer;
        attribute length : Length = 200.0 [mm];
        attribute maxBendAngle : Angle = 90.0 [deg];
        attribute currentBend : Angle;
        part actuators : PneumaticActuator[3] {
            each actuator {
                redefinition segmentId = that.id;
            }
        }
        part shapeSensor : ShapeSensor {
            redefinition segmentId = id;
        }
        port out cmdPort : PressureCommandPort;
        port out shapePort : ShapeFeedbackPort;
        flow fluidIn : PneumaticFluid;
        action def BendSegment {
            in pressureA : Pressure;
            in pressureB : Pressure;
            in pressureC : Pressure;
            // Antagonistic actuation produces a resultant bend
            assign currentBend = ((pressureA - pressureB) * 0.1 [deg/kPa]) + (pressureC * 0.0 [deg/kPa]);
        }
        compute segmentDynamics {
            do BendSegment(actuators[1].currentPressure, actuators[2].currentPressure, actuators[3].currentPressure);
        }
    }

    part def ContinuumArm {
        attribute totalLength : Length = 600.0 [mm];
        attribute segmentCount : Integer = 3;
        part segments : ContinuumSegment[3] {
            each segment {
                redefinition length = 200.0 [mm];
            }
        }
        part actuators : PneumaticActuator[*] = segments.actuators;
        part sensors : ShapeSensor[*] = segments.shapeSensor;
        attribute tipPosition : Length[3];
        attribute tipOrientation : Angle[3];
        attribute tipPositionError : Accuracy;
        port in actuationCommands : PressureCommandPort;
        port out shapeFeedback : ShapeFeedbackPort;
        port in fluidSupply : PneumaticPort;
        flow pneumaticSupply : PneumaticFluid;
        action def ForwardKinematics {
            // Compute cumulative tip pose from segment bends
            assign tipPosition = integrateSegmentPositions(segments);
            assign tipOrientation = integrateSegmentOrientations(segments);
        }
        compute kinematics {
            do ForwardKinematics();
        }
    }

    part def GripperFinger {
        attribute id : Integer;
        attribute length : Length = 40.0 [mm];
        attribute contactForce : Force;
        attribute deflection : Length;
        action def Grasp {
            in targetForce : Force;
            assign contactForce = targetForce;
        }
    }

    part def ForceSensor {
        attribute id : Integer;
        attribute ratedForce : Force = 50.0 [N];
        attribute measuredForce : Force;
        attribute contactDetected : Boolean;
        port out fbPort : ForceFeedbackPort {
            output feedback : ForceFeedback = ForceFeedback{measuredForce = measuredForce; contactDetected = contactDetected;};
        }
        action def Measure {
            assign measuredForce = readLoadCell();
            assign contactDetected = (measuredForce > 0.5 [N]);
        }
        attribute readLoadCell : Force;
        compute sensing {
            do Measure();
        }
    }

    part def GripperEndEffector {
        attribute ratedPayload : Mass = 2.0 [kg];
        attribute maxGripForce : Force = 40.0 [N];
        attribute openingWidth : Length = 60.0 [mm];
        part fingers : GripperFinger[2];
        part forceSensor : ForceSensor;
        port in graspCmdPort : GraspCommandPort;
        port out forceFbPort : ForceFeedbackPort;
        attribute gripForce : Force;
        action def ExecuteGrasp {
            in cmd : GraspCommand;
            attribute targetForce : Force = cmd.commandForce;
            if cmd.commandOpen then {
                assign gripForce = 0.0 [N];
            } else {
                assign gripForce = min(targetForce, maxGripForce);
            }
            // Drive both fingers
            parallel {
                do fingers[1].Grasp(gripForce);
                do fingers[2].Grasp(gripForce);
            }
        }
        compute gripperControl {
            receive cmd : GraspCommand from graspCmdPort.command;
            do ExecuteGrasp(cmd);
        }
    }

    part def PneumaticSupply {
        attribute supplyPressure : Pressure = 700.0 [kPa];
        attribute maxFlow : FlowRate = 50.0 [L/min];
        port in powerIn : PowerPort;
        port out pneumaticOut : PneumaticPort {
            output fluid : PneumaticFluid;
            attribute pressure : Pressure = supplyPressure;
            attribute flow : FlowRate = maxFlow;
        }
        action def Regulate {
            // Pressure regulator and compressor operation
        }
        compute regulation {
            do Regulate();
        }
    }

    part def PowerSupply {
        attribute nominalVoltage : Voltage = 24.0 [V];
        attribute maxCurrent : Current = 30.0 [A];
        attribute outputPower : Power;
        port out powerOut : PowerPort {
            attribute voltage : Voltage = nominalVoltage;
            attribute current : Current = maxCurrent;
        }
        action def SupplyPower {
            assign outputPower = nominalVoltage * maxCurrent;
        }
        compute power {
            do SupplyPower();
        }
    }

    part def ControlComputer {
        attribute cycleTime : TimeValue = 0.001 [s];
        attribute controlFrequency : Frequency = 1000.0 [Hz];
        attribute targetPosition : Length[3];
        attribute targetOrientation : Angle[3];
        attribute planningActive : Boolean;
        attribute currentTask : TaskObjective;
        port in shapeFbIn : ShapeFeedbackPort;
        port in forceFbIn : ForceFeedbackPort;
        port out cmdOut : PressureCommandPort;
        port out graspCmdOut : GraspCommandPort;
        port taskPort : TaskPort;
        attribute integratedShape : ShapeFeedback[*];
        attribute integratedForce : ForceFeedback;
        action def ControlLoop {
            // Continuous control loop
            action acquireFeedback {
                receive shapeData : ShapeFeedback[*] from shapeFbIn.feedback;
                receive forceData : ForceFeedback from forceFbIn.feedback;
                assign integratedShape = shapeData;
                assign integratedForce = forceData;
            }
            action planTrajectory {
                // Generate pressure setpoints to move toward target pose
                attribute setpoints : Pressure[9];
                assign setpoints = solveInverseKinematics(targetPosition, targetOrientation, integratedShape);
            }
            action sendCommands {
                // Dispatch nine pressure setpoints to actuators
                attribute i : Integer;
                while i < 9 loop {
                    send ActuationCommand{segmentId = (i / 3) + 1; actuatorId = (i % 3) + 1; targetPressure = setpoints[i+1];} to cmdOut.commands;
                    assign i = i + 1;
                }
            }
            do acquireFeedback;
            do planTrajectory;
            do sendCommands;
        }
        action def TaskHandler {
            receive newTask : TaskObjective from taskPort.task;
            assign currentTask = newTask;
            assign targetPosition = newTask.targetPosition;
            assign targetOrientation = newTask.targetOrientation;
            send true to taskPort.taskAccepted;
            // Execute control loops until convergence
            do ControlLoop until |tipPositionError| <= 2.0 [mm];
            send true to taskPort.taskComplete;
        }
        attribute solveInverseKinematics : Pressure[*];
        compute scheduler {
            do TaskHandler();
        }
    }

    part def ContinuumRobot {
        part controlComputer : ControlComputer;
        part arm : ContinuumArm;
        part gripper : GripperEndEffector;
        part powerSupply : PowerSupply;
        part pneumaticSupply : PneumaticSupply;
        attribute tipPositionError : Accuracy;
        attribute operationalState : String;
        port taskInterface : TaskPort;
        satisfy SystemPerformanceRequirement;

        connection powerToPneumatic connect powerSupply.powerOut to pneumaticSupply.powerIn;
        connection pneumaticToArm connect pneumaticSupply.pneumaticOut to arm.fluidSupply;
        connection cmdToArm connect controlComputer.cmdOut to arm.actuationCommands;
        connection shapeFbToComputer connect arm.shapeFeedback to controlComputer.shapeFbIn;
        connection graspCmdToGripper connect controlComputer.graspCmdOut to gripper.graspCmdPort;
        connection forceFbToComputer connect gripper.forceFbPort to controlComputer.forceFbIn;
        connection taskRouting connect taskInterface to controlComputer.taskPort;

        // Expose gripper's force sensor through gripper's port aggregate
        // (already routed via gripper.forceFbPort)

        state def OperationalStateMachine {
            entry attribute entryTime : TimeValue;
            state idle {
                entry { assign operationalState = "idle"; }
                on initSignal transition to calibrating;
            }
            state calibrating {
                entry {
                    assign operationalState = "calibrating";
                    // Zero all shape sensors and actuators
                }
                do ControlComputer.ControlLoop;
                on calibrationComplete transition to ready;
                on faultDetected transition to faulted;
            }
            state ready {
                entry { assign operationalState = "ready"; }
                on taskAssigned transition to executing;
                on faultDetected transition to faulted;
            }
            state executing {
                entry { assign operationalState = "executing"; }
                do ControlComputer.TaskHandler;
                on taskCompleted transition to ready;
                on faultDetected transition to faulted;
            }
            state faulted {
                entry { assign operationalState = "faulted"; }
                on resetCommand transition to idle;
            }
        }
        state machine operationalBehavior : OperationalStateMachine;

        attribute initSignal : Boolean;
        attribute calibrationComplete : Boolean;
        attribute taskAssigned : Boolean;
        attribute taskCompleted : Boolean;
        attribute faultDetected : Boolean;
        attribute resetCommand : Boolean;
    }

    // ---------- Top-level system instance ----------
    part continuumRobotSystem : ContinuumRobot {
        // Default values to satisfy requirements
        attribute nominalLength = 600.0 [mm];
        attribute payloadCapacity = 2.0 [kg];
        attribute accuracyTarget = 2.0 [mm];
    }

    // ---------- Verification package ----------
    verification def AccuracyVerification {
        subject robot : ContinuumRobot;
        objective { Verify PositioningAccuracyRequirement on robot. }
        method {
            attribute trials : Integer = 100;
            attribute measuredErrors : Accuracy[*];
            attribute i : Integer;
            while i < trials loop {
                // command a target, measure error
                attribute err : Accuracy;
                append err to measuredErrors;
                assign i = i + 1;
            }
            assert measuredErrors->forAll(e | e <= 2.0 [mm]);
        }
    }

    verification def PayloadVerification {
        subject gripper : GripperEndEffector;
        objective { Verify PayloadCapacityRequirement on gripper. }
        method {
            attribute testLoads : Mass[*] = [0.5, 1.0, 1.5, 2.0];
            attribute allPass : Boolean = true;
            assert gripper.ratedPayload >= 2.0 [kg];
        }
    }
}

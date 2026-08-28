package LinearActuator {

    import ScalarValues::*;

    // ---- Value Types with Units ----
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def Power :> Real { unit 'W'; }
    value def Force :> Real { unit 'N'; }
    value def Torque :> Real { unit 'N*m'; }
    value def Length :> Real { unit 'mm'; }
    value def Velocity :> Real { unit 'mm/s'; }
    value def Angle :> Real { unit 'rad'; }
    value def AngularVelocity :> Real { unit 'rad/s'; }
    value def TimeValue :> Real { unit 's'; }
    value def Gain :> Real;

    // ---- Performance Attributes ----
    attribute maxForce : Force = 8000 [N];
    attribute strokeRange : Length = 200 [mm];
    attribute positionAccuracy : Length = 0.05 [mm];
    attribute maxVelocity : Velocity = 500 [mm/s];

    // ---- Item Types ----
    item def CommandSignal {
        attribute targetPosition : Length;
        attribute targetForce : Force;
        attribute mode : String; // "position" or "force"
    }

    item def PositionFeedback {
        attribute measuredPosition : Length;
        attribute timestamp : TimeValue;
    }

    item def ForceFeedback {
        attribute measuredForce : Force;
        attribute timestamp : TimeValue;
    }

    item def ControlSignal {
        attribute commandVoltage : Voltage;
        attribute commandCurrent : Current;
    }

    item def PowerSignal {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
    }

    item def RotationalMotion {
        attribute angle : Angle;
        attribute angularVelocity : AngularVelocity;
        attribute torque : Torque;
    }

    item def LinearMotion {
        attribute position : Length;
        attribute velocity : Velocity;
        attribute force : Force;
    }

    // ---- Port Definitions ----
    port def CommandFlow {
        in item command : CommandSignal;
    }

    port def PositionFeedbackFlow {
        out item positionFeedback : PositionFeedback;
    }

    port def ForceFeedbackFlow {
        out item forceFeedback : ForceFeedback;
    }

    port def ControlFlow {
        out item controlSignal : ControlSignal;
    }

    port def PowerFlow {
        out item powerSignal : PowerSignal;
    }

    port def RotationalFlow {
        out item rotation : RotationalMotion;
    }

    port def LinearFlow {
        out item motion : LinearMotion;
    }

    // ---- Control Processor ----
    part def ControlProcessor {
        attribute targetPosition : Length;
        attribute targetForce : Force;
        attribute currentPosition : Length;
        attribute currentForce : Force;
        attribute positionError : Length;
        attribute forceError : Force;
        attribute controlGain : Gain = 2.5;
        attribute samplePeriod : TimeValue = 0.001 [s];

        port commandIn : CommandFlow;
        port positionIn : ~PositionFeedbackFlow;
        port forceIn : ~ForceFeedbackFlow;
        port controlOut : ControlFlow;

        action computeControlSignal {
            in cmd : CommandSignal;
            in pos : PositionFeedback;
            in frc : ForceFeedback;
            out ctrl : ControlSignal;

            // Compute error and corrective signal
            perform {
                positionError := cmd.targetPosition - pos.measuredPosition;
                forceError := cmd.targetForce - frc.measuredForce;
                ctrl.commandVoltage := controlGain * positionError / 10 [mm] * 10 [V];
                ctrl.commandCurrent := controlGain * forceError / 1000 [N] * 5 [A];
            }
        }
    }

    // ---- Power Amplifier ----
    part def PowerAmplifier {
        attribute voltageGain : Gain = 20.0;
        attribute currentGain : Gain = 15.0;
        attribute maxOutputPower : Power = 1500 [W];
        attribute efficiency : Real = 0.92;

        port controlIn : ~ControlFlow;
        port supplyIn : ~PowerFlow;
        port powerOut : PowerFlow;

        action amplify {
            in ctrl : ControlSignal;
            in supply : PowerSignal;
            out power : PowerSignal;

            perform {
                power.voltage := voltageGain * ctrl.commandVoltage;
                power.current := currentGain * ctrl.commandCurrent;
                power.power := power.voltage * power.current;
            }
        }
    }

    // ---- Electric Motor ----
    part def ElectricMotor {
        attribute torqueConstant : Real = 0.08; // N*m/A
        attribute backEMFConstant : Real = 0.08; // V*s/rad
        attribute maxTorque : Torque = 12 [N*m];
        attribute maxAngularVelocity : AngularVelocity = 300 [rad/s];
        attribute windingResistance : Real = 0.5; // ohm

        port powerIn : ~PowerFlow;
        port rotationOut : RotationalFlow;

        action convertElectricalToRotational {
            in power : PowerSignal;
            out rotation : RotationalMotion;

            perform {
                rotation.torque := torqueConstant * power.current;
                rotation.angularVelocity := power.voltage / backEMFConstant;
                rotation.angle := rotation.angularVelocity * 0.001 [s];
            }
        }
    }

    // ---- Transmission Mechanism ----
    part def TransmissionMechanism {
        attribute lead : Length = 5 [mm]; // linear travel per revolution
        attribute gearRatio : Real = 2.0;
        attribute efficiency : Real = 0.90;
        attribute backlash : Length = 0.02 [mm];

        port rotationIn : ~RotationalFlow;
        port linearOut : LinearFlow;

        action convertRotationalToLinear {
            in rotation : RotationalMotion;
            out motion : LinearMotion;

            perform {
                motion.position := (rotation.angle / (2 * 3.14159265 [rad])) * lead * gearRatio;
                motion.velocity := (rotation.angularVelocity / (2 * 3.14159265 [rad])) * lead * gearRatio;
                motion.force := (rotation.torque * 2 * 3.14159265 * efficiency) / (lead / 1000 [mm]);
            }
        }
    }

    // ---- Position Sensor ----
    part def PositionSensor {
        attribute resolution : Length = 0.001 [mm];
        attribute measurementRange : Length = 250 [mm];
        attribute accuracy : Length = 0.005 [mm];
        attribute updateRate : TimeValue = 0.0005 [s];

        port linearIn : ~LinearFlow;
        port feedbackOut : PositionFeedbackFlow;

        action measurePosition {
            in motion : LinearMotion;
            out feedback : PositionFeedback;

            perform {
                feedback.measuredPosition := motion.position;
                feedback.timestamp := 0 [s];
            }
        }
    }

    // ---- Force Sensor ----
    part def ForceSensor {
        attribute measurementRange : Force = 10000 [N];
        attribute accuracy : Force = 5 [N];
        attribute updateRate : TimeValue = 0.0005 [s];

        port linearIn : ~LinearFlow;
        port feedbackOut : ForceFeedbackFlow;

        action measureForce {
            in motion : LinearMotion;
            out feedback : ForceFeedback;

            perform {
                feedback.measuredForce := motion.force;
                feedback.timestamp := 0 [s];
            }
        }
    }

    // ---- Actuator State Machine ----
    state def ActuatorStates {
        entry;

        state initializing {
            entry { /* perform power-on self-test, calibrate sensors */ }
            do { /* verify communication with all subcomponents */ }
            transition to ready
                when selfTestComplete == true;
            transition to fault
                when faultDetected == true;
        }

        state ready {
            entry { /* enable monitoring, await commands */ }
            transition to active
                when commandReceived == true;
            transition to fault
                when faultDetected == true;
        }

        state active {
            entry { /* engage motor drive, execute motion profile */ }
            do { /* continuously adjust control signal based on feedback */ }
            transition to holding
                when targetReached == true;
            transition to ready
                when commandCompleted == true;
            transition to fault
                when faultDetected == true;
        }

        state holding {
            entry { /* maintain position with closed-loop corrections */ }
            do { /* apply holding current, monitor disturbances */ }
            transition to active
                when newCommand == true;
            transition to fault
                when faultDetected == true;
        }

        state fault {
            entry { /* disable power amplifier, engage brake if present */ }
            do { /* log fault, await reset */ }
            transition to initializing
                when faultReset == true;
        }
    }

    // ---- Top-Level Linear Actuator System ----
    part def LinearActuatorSystem {
        attribute selfTestComplete : Boolean = false;
        attribute commandReceived : Boolean = false;
        attribute targetReached : Boolean = false;
        attribute commandCompleted : Boolean = false;
        attribute newCommand : Boolean = false;
        attribute faultDetected : Boolean = false;
        attribute faultReset : Boolean = false;

        // External interfaces
        port commandIn : CommandFlow;
        port supplyIn : ~PowerFlow;
        port linearOut : LinearFlow;

        // Internal components
        part controlProcessor : ControlProcessor;
        part powerAmplifier : PowerAmplifier;
        part electricMotor : ElectricMotor;
        part transmission : TransmissionMechanism;
        part positionSensor : PositionSensor;
        part forceSensor : ForceSensor;

        // Connections: command delegation
        connection commandDelegate connect commandIn to controlProcessor.commandIn;

        // Control signal from processor to amplifier
        connection controlSignalConn connect controlProcessor.controlOut to powerAmplifier.controlIn;

        // External power supply delegation to amplifier
        connection supplyDelegate connect supplyIn to powerAmplifier.supplyIn;

        // Amplified power to motor
        connection powerConn connect powerAmplifier.powerOut to electricMotor.powerIn;

        // Motor rotation to transmission
        connection rotationConn connect electricMotor.rotationOut to transmission.rotationIn;

        // Linear output delegation to external port
        connection linearOutDelegate connect transmission.linearOut to linearOut;

        // Sensor taps on linear motion
        connection positionSenseConn connect transmission.linearOut to positionSensor.linearIn;
        connection forceSenseConn connect transmission.linearOut to forceSensor.linearIn;

        // Feedback to processor
        connection positionFeedbackConn connect positionSensor.feedbackOut to controlProcessor.positionIn;
        connection forceFeedbackConn connect forceSensor.feedbackOut to controlProcessor.forceIn;

        // State behavior
        exhibit actuatorStates : ActuatorStates;
    }

    // ---- Requirements ----
    requirement def ForceCapabilityRequirement {
        doc /* The actuator shall deliver up to 8000 N of force. */
        subject actuator : LinearActuatorSystem;
        require { actuator.maxForce <= 8000 [N] }
    }

    requirement def StrokeRangeRequirement {
        doc /* The actuator shall operate over a 200 mm stroke range. */
        subject actuator : LinearActuatorSystem;
        require { actuator.strokeRange >= 200 [mm] }
    }

    requirement def PositioningAccuracyRequirement {
        doc /* The actuator shall achieve positioning accuracy of 0.05 mm or better. */
        subject actuator : LinearActuatorSystem;
        require { actuator.positionAccuracy <= 0.05 [mm] }
    }

    requirement def ClosedLoopFeedbackRequirement {
        doc /* The actuator shall use continuous position and force feedback for closed-loop control. */
        subject actuator : LinearActuatorSystem;
        require { actuator.positionSensor.resolution <= 0.01 [mm] }
        require { actuator.forceSensor.measurementRange >= 8000 [N] }
    }

    requirement def StateMachineRequirement {
        doc /* The actuator shall operate in initializing, ready, active, holding, and fault states. */
        subject actuator : LinearActuatorSystem;
        require { actuator.actuatorStates.initializing.exists() }
        require { actuator.actuatorStates.ready.exists() }
        require { actuator.actuatorStates.active.exists() }
        require { actuator.actuatorStates.holding.exists() }
        require { actuator.actuatorStates.fault.exists() }
    }

    requirement def SafetyFaultRequirement {
        doc /* Upon fault detection, the actuator shall disable power and enter a safe fault state. */
        subject actuator : LinearActuatorSystem;
        require { actuator.faultDetected == true implies actuator.actuatorStates.fault.active }
    }

}

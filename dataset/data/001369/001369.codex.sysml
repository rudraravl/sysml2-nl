package BioroboticRehabilitationSystem {
    import ScalarValues::*;
    import ISQ::*;

    item def EMGSignal {
        attribute amplitude : Real;
        attribute frequency : Real;
        attribute timestamp : Real;
    }

    item def JointCommand {
        attribute targetAngle : Real;
        attribute targetTorque : Real;
        attribute stiffness : Real;
    }

    item def JointState {
        attribute angle : Real;
        attribute angularVelocity : Real;
        attribute measuredTorque : Real;
    }

    item def PowerFlow {
        attribute voltage : Real;
        attribute current : Real;
        attribute power : Real;
    }

    item def TherapyProfile {
        attribute targetRangeOfMotion : Real;
        attribute assistanceLevel : Real;
        attribute repetitions : Integer;
        attribute sessionDuration : Real;
    }

    port def SensorPort {
        out item signal : EMGSignal;
        out item state : JointState;
    }

    port def ControlPort {
        in item profile : TherapyProfile;
        out item command : JointCommand;
    }

    port def ActuationPort {
        in item command : JointCommand;
        out item state : JointState;
    }

    port def PowerPort {
        inout item electricalPower : PowerFlow;
    }

    part def SoftActuator {
        attribute maxTorque : Real = 45.0;
        attribute responseTime : Real = 0.08;
        attribute compliance : Real = 0.72;

        port control : ActuationPort;
        port power : PowerPort;

        action generateAssistiveTorque {
            in item command : JointCommand;
            out item producedState : JointState;
        }
    }

    part def BiosignalSensorArray {
        attribute electrodeCount : Integer = 16;
        attribute sampleRate : Real = 1000.0;
        attribute noiseFloor : Real = 0.003;

        port sensor : SensorPort;

        action acquireMuscleIntent {
            out item emg : EMGSignal;
        }

        action estimateJointMotion {
            out item state : JointState;
        }
    }

    part def AdaptiveController {
        attribute controlLoopRate : Real = 250.0;
        attribute intentConfidence : Real;
        attribute safetyTorqueLimit : Real = 38.0;

        port sensing : SensorPort;
        port therapyInput : ControlPort;
        port actuation : ActuationPort;

        action inferUserIntent {
            in item emg : EMGSignal;
            in item state : JointState;
            out item command : JointCommand;
        }

        action adaptAssistance {
            in item profile : TherapyProfile;
            in item state : JointState;
            out item command : JointCommand;
        }
    }

    part def WearableExosleeve {
        attribute mass : Real = 2.4;
        attribute supportedJoint : String = "elbow";
        attribute rangeOfMotion : Real = 135.0;

        part actuator : SoftActuator;
        part sensorArray : BiosignalSensorArray;
        part controller : AdaptiveController;

        port userInterface : ControlPort;
        port powerInput : PowerPort;

        connect sensorArray.sensor to controller.sensing;
        connect controller.actuation to actuator.control;
        connect userInterface to controller.therapyInput;
        connect powerInput to actuator.power;
    }

    part def BatteryPack {
        attribute capacity : Real = 180.0;
        attribute nominalVoltage : Real = 24.0;
        attribute maxContinuousCurrent : Real = 8.0;

        port output : PowerPort;
    }

    part def ClinicianConsole {
        attribute displayRefreshRate : Real = 60.0;

        port therapyControl : ControlPort;

        action configureTherapy {
            out item profile : TherapyProfile;
        }

        action monitorProgress {
            in item state : JointState;
        }
    }

    part def BioroboticRehabilitationAssistant {
        doc
        /*
         * Primary function: assist human limb rehabilitation by sensing biological
         * muscle intent, interpreting patient movement capability, and applying
         * adaptive compliant robotic support to guide therapeutic motion.
         */

        attribute operationalMass : Real = 3.1;
        attribute maximumSessionDuration : Real = 45.0;
        attribute intendedUse : String = "adaptive neuromuscular rehabilitation assistance";

        part exosleeve : WearableExosleeve;
        part battery : BatteryPack;
        part console : ClinicianConsole;

        connect battery.output to exosleeve.powerInput;
        connect console.therapyControl to exosleeve.userInterface;

        state def RehabilitationOperation {
            state idle;
            state calibrating;
            state ready;
            state assistingMovement;
            state adaptingAssistance;
            state paused;
            state fault;

            entry action initializeSystem;
            action initializeSystem;

            transition first idle;

            transition idle_to_calibrating
                first idle then calibrating
                accept configureTherapy;

            transition calibrating_to_ready
                first calibrating then ready
                accept calibrationComplete;

            transition ready_to_assist
                first ready then assistingMovement
                accept patientMovementDetected;

            transition assist_to_adapt
                first assistingMovement then adaptingAssistance
                accept performanceDeviationDetected;

            transition adapt_to_assist
                first adaptingAssistance then assistingMovement
                accept assistanceUpdated;

            transition assist_to_paused
                first assistingMovement then paused
                accept clinicianPause;

            transition paused_to_ready
                first paused then ready
                accept resumeSession;

            transition any_to_fault
                first idle then fault
                accept safetyLimitExceeded;
        }

        action conductTherapySession {
            in item profile : TherapyProfile;
            out item finalState : JointState;

            first startSession;
            then calibrateSensors;
            then loopAssistiveMotion;
            then summarizeSession;
        }

        action startSession;
        action calibrateSensors;
        action loopAssistiveMotion;
        action summarizeSession;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : BioroboticRehabilitationAssistant;

        require constraint {
            system.intendedUse == "adaptive neuromuscular rehabilitation assistance"
        }

        doc
        /*
         * The system shall provide adaptive robotic assistance for rehabilitation
         * by sensing biological intent and delivering compliant joint support.
         */
    }

    requirement def SafetyTorqueRequirement {
        subject controller : AdaptiveController;

        require constraint {
            controller.safetyTorqueLimit <= 40.0
        }

        doc
        /*
         * The controller shall limit commanded assistance torque to protect the user.
         */
    }

    requirement def TherapyDurationRequirement {
        subject system : BioroboticRehabilitationAssistant;

        require constraint {
            system.maximumSessionDuration <= 60.0
        }

        doc
        /*
         * The system shall support clinical therapy sessions without exceeding
         * a one-hour continuous-use limit.
         */
    }

    requirement def ResponsivenessRequirement {
        subject actuator : SoftActuator;

        require constraint {
            actuator.responseTime <= 0.10
        }

        doc
        /*
         * The actuator shall respond quickly enough to synchronize assistance
         * with voluntary patient motion.
         */
    }

    requirement def BiosignalSamplingRequirement {
        subject sensors : BiosignalSensorArray;

        require constraint {
            sensors.sampleRate >= 500.0
        }

        doc
        /*
         * The biosignal sensor array shall sample muscle activity fast enough
         * to support real-time intent recognition.
         */
    }
}
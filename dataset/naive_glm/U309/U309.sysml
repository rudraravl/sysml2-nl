package MichelangeloHand {
    import ScalarValues::*;
    import ISQ::*;
    import ISQElectromagnetism::*;
    import ISQForce::*;

    // ---------- Value Types ----------
    attribute def Voltage :> Real { unit 'V'; }
    attribute def Current :> Real { unit 'A'; }
    attribute def Force :> Real { unit 'N'; }
    attribute def Power :> Real { unit 'W'; }
    attribute def Energy :> Real { unit 'J'; }
    attribute def Angle :> Real { unit 'deg'; }
    attribute def Frequency :> Real { unit 'Hz'; }
    attribute def Time :> Real { unit 's'; }
    attribute def Mass :> Real {> Real {
        attribute value : Voltage;
    }

    item def GripCommand {
        attribute gripType : GripType;
        attribute targetForce : Force;
    }

    item def ForceFeedback {
        attribute fingerId : String;
        attribute measuredForce : Force;
    }

    item def MotorCommand {
        attribute direction : MotorDirection;
        attribute dutyCycle : Real; // 0.0 to 1.0
    }

    item def BatteryStatus {
        attribute chargeLevel : Percent;
        attribute voltage : Voltage;
        attribute temperature : Temperature;
    }

    item def PowerSupply {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    // ---------- Port Definitions ----------
    port def EMGSignalOut {
        out signal : EMGSignal;
    }

    port def EMGSignalIn {
        in signal : EMGSignal;
    }

    port def CommandOut {
        out command : GripCommand;
    }

    port def CommandIn {
        in command : GripCommand;
    }

    port def MotorCommandOut {
        out command : MotorCommand;
    }

    port def MotorCommandIn {
        in command : MotorCommand;
    }

    port def ForceFeedbackOut {
        out feedback : ForceFeedback;
    }

    port def ForceFeedbackIn {
        in feedback : ForceFeedback;
    }

    port def PowerPort {
        out supply : PowerSupply;
    }

    port def PowerInPort {
        in supply : PowerSupply;
    }

    port def BatteryStatusOut {
        out status : BatteryStatus;
    }

    port def BatteryStatusIn {
        in status : BatteryStatus;
    }

    // ---------- Parts ----------
    part def EMGSensor {
        attribute sensorId : String;
        attribute placement : String;
        attribute samplingRate : Frequency = 1000 [Hz];
        attribute sensitivity : Voltage = 0.001 [V];

        port emgOut : EMGSignalOut;

        attribute currentSignal : EMGSignal;

        action def SenseEMG {
            in muscleContraction : Voltage;
            out signal : EMGSignal;
        }

        perform action sense : SenseEMG {
            in muscleContraction;
            out signal = currentSignal;
        }

        flow emgOut.signal <- currentSignal;
    }

    part def ControllerBoard {
        attribute clockSpeed : Frequency = 16 [MHz];
        attribute adcResolution : Integer = 12;
        attribute controlLoopRate : Frequency = 200 [Hz];

        port emgIn1 : EMGSignalIn;
        port emgIn2 : EMGSignalIn;
        port commandOut : CommandOut;
        port feedbackIn : ForceFeedbackIn;
        port powerIn : PowerInPort;
        port batteryStatusIn : BatteryStatusIn;

        port motorCommands[5] : MotorCommandOut;

        attribute flexorSignal : EMGSignal;
        attribute extensorSignal : EMGSignal;
        attribute interpretedGrip : GripType;
        attribute targetGripForce : Force;
        attribute currentGripForces[5] : Force;
        attribute batteryLevel : Percent;

        action def InterpretEMG {
            in flexor : EMGSignal;
            in extensor : EMGSignal;
            out grip : GripType;
            out force : Force;
        }

        action def ComputeMotorCommands {
            in grip : GripType;
            in targetForce : Force;
            in currentForces[5] : Force;
            out commands[5] : MotorCommand;
        }

        action def AdjustGrip {
            in feedback[5] : ForceFeedback;
            in targetForce : Force;
            out adjustedCommands[5] : MotorCommand;
        }

        perform action interpret : InterpretEMG {
            in flexor = flexorSignal;
            in extensor = extensorSignal;
            out grip = interpretedGrip;
            out force = targetGripForce;
        }

        perform action compute : ComputeMotorCommands {
            in grip = interpretedGrip;
            in targetForce = targetGripForce;
            in currentForces = currentGripForces;
            out commands;
        }

        perform action adjust : AdjustGrip {
            in feedback;
            in targetForce = targetGripForce;
            out adjustedCommands;
        }

        flow emgIn1.signal -> flexorSignal;
        flow emgIn2.signal -> extensorSignal;

        state def ControllerBehavior {
            entry; then Calibrating;

            state Calibrating {
                entry;
                // Establish baseline EMG thresholds
                do assign interpretedGrip = GripType::open;
                then Active;
            }

            state Active {
                entry;
                do action waitForCommand {
                    in flexor = flexorSignal;
                    in extensor = extensorSignal;
                }
                transition if flexorSignal.amplitude > 0.5 [V] then Grasping;
                transition if extensorSignal.amplitude > 0.5 [V] then Releasing;
            }

            state Grasping {
                entry;
                do action executeGrip {
                    in grip = interpretedGrip;
                    out command;
                }
                then Holding;
            }

            state Holding {
                entry;
                do action maintainGrip {
                    in feedback;
                    in targetForce = targetGripForce;
                }
                transition if extensorSignal.amplitude > 0.5 [V] then Releasing;
                transition if batteryLevel < 10 [%] then LowPower;
            }

            state Releasing {
                entry;
                do action openHand;
                then Active;
            }

            state LowPower {
                entry;
                do action shutdownSequence;
            }
        }

        exhibit state behavior : ControllerBehavior;

        flow commandOut.command <- GripCommand { gripType = interpretedGrip; targetForce = targetGripForce; };
    }

    part def Finger {
        attribute fingerName : String;
        attribute maxForce : Force = 30 [N];
        attribute maxFlexionAngle : Angle = 90 [deg];
        attribute motorStallCurrent : Current = 1.5 [A];

        port commandIn : MotorCommandIn;
        port forceOut : ForceFeedbackOut;
        port powerIn : PowerInPort;

        attribute currentForce : Force;
        attribute currentAngle : Angle;
        attribute motorDutyCycle : Real;

        part motor : DCMotor {
            attribute ratedVoltage : Voltage = 6 [V];
            attribute noLoadSpeed : Real = 200; // RPM
            port powerIn : PowerInPort;
        }

        part tendon : Tendon {
            attribute tensileStrength : Force = 100 [N];
            attribute length : Length = 0.05 [m];
        }

        part forceSensor : ForceSensor {
            attribute range : Force = 50 [N];
            attribute sensitivity : Real = 0.01; // V/N
            port forceOut : ForceFeedbackOut;
        }

        action def Flex {
            in command : MotorCommand;
            out angle : Angle;
        }

        action def Extend {
            in command : MotorCommand;
            out angle : Angle;
        }

        action def MeasureForce {
            out force : Force;
        }

        perform action flex : Flex {
            in command;
            out angle = currentAngle;
        }

        perform action extend : Extend {
            in command;
            out angle = currentAngle;
        }

        perform action measure : MeasureForce {
            out force = currentForce;
        }

        flow forceOut.feedback <- ForceFeedback { fingerId = fingerName; measuredForce = currentForce; };
    }

    part def DCMotor {
        attribute ratedVoltage : Voltage = 6 [V];
        attribute ratedCurrent : Current = 0.5 [A];
        attribute noLoadSpeed : Real = 200;
        attribute stallTorque : Real = 0.05;

        port powerIn : PowerInPort;

        action def Drive {
            in dutyCycle : Real;
            out speed : Real;
        }

        perform action drive : Drive;
    }

    part def Tendon {
        attribute material : String = "Dyneema";
        attribute diameter : Length = 0.001 [m];
        attribute tensileStrength : Force = 100 [N];
    }

    part def ForceSensor {
        attribute type : String = "Strain Gauge";
        attribute range : Force = 50 [N];
        attribute sensitivity : Real = 0.01;
        attribute samplingRate : Frequency = 500 [Hz];

        port forceOut : ForceFeedbackOut;

        action def Sense {
            in appliedForce : Force;
            out feedback : ForceFeedback;
        }

        perform action sense : Sense;
    }

    part def Battery {
        attribute chemistry : String = "Lithium-Ion";
        attribute nominalVoltage : Voltage = 7.4 [V];
        attribute capacity : Energy = 40000 [J];
        attribute chargeLevel : Percent = 100 [%];
        attribute maxDischargeCurrent : Current = 3 [A];
        attribute cycleLife : Integer = 500;

        port powerOut : PowerPort;
        port statusOut : BatteryStatusOut;

        action def Discharge {
            in load : Power;
            out supply : PowerSupply;
        }

        action def Charge {
            in supply : PowerSupply;
        }

        action def MonitorCharge {
            out status : BatteryStatus;
        }

        perform action discharge : Discharge;
        perform action monitor : MonitorCharge;

        flow powerOut.supply <- PowerSupply { voltage = nominalVoltage; current = 1 [A]; };
        flow statusOut.status <- BatteryStatus { chargeLevel = chargeLevel; voltage = nominalVoltage; temperature = 25 [K] * 1 + 248.15; };
    }

    // ---------- Top-level System ----------
    part def MichelangeloHandSystem {
        attribute systemMass : Mass = 0.5 [kg];
        attribute operatingTemperature : Temperature = 310 [K];
        attribute waterproofRating : String = "IP54";

        port powerIn : PowerInPort;

        part battery : Battery {
            attribute nominalVoltage : Voltage = 7.4 [V];
            attribute capacity : Energy = 40000 [J];
        }

        part emgSensorFlexor : EMGSensor {
            attribute sensorId = "EMG_01";
            attribute placement = "Flexor muscle group";
        }

        part emgSensorExtensor : EMGSensor {
            attribute sensorId = "EMG_02";
            attribute placement = "Extensor muscle group";
        }

        part controller : ControllerBoard {
            attribute clockSpeed : Frequency = 16 [MHz];
        }

        part thumb : Finger {
            attribute fingerName = "Thumb";
            attribute maxForce : Force = 25 [N];
        }

        part indexFinger : Finger {
            attribute fingerName = "Index";
            attribute maxForce : Force = 30 [N];
        }

        part middleFinger : Finger {
            attribute fingerName = "Middle";
            attribute maxForce : Force = 30 [N];
        }

        part ringFinger : Finger {
            attribute fingerName = "Ring";
            attribute maxForce : Force = 25 [N];
        }

        part pinkyFinger : Finger {
            attribute fingerName = "Pinky";
            attribute maxForce : Force = 20 [N];
        }

        // Connections: EMG sensors to controller
        connect emgSensorFlexor.emgOut to controller.emgIn1;
        connect emgSensorExtensor.emgOut to controller.emgIn2;

        // Connections: Controller motor commands to fingers
        connect controller.motorCommands[0] to thumb.commandIn;
        connect controller.motorCommands[1] to indexFinger.commandIn;
        connect controller.motorCommands[2] to middleFinger.commandIn;
        connect controller.motorCommands[3] to ringFinger.commandIn;
        connect controller.motorCommands[4] to pinkyFinger.commandIn;

        // Connections: Force feedback from fingers to controller
        connect thumb.forceOut to controller.feedbackIn;
        connect indexFinger.forceOut to controller.feedbackIn;
        connect middleFinger.forceOut to controller.feedbackIn;
        connect ringFinger.forceOut to controller.feedbackIn;
        connect pinkyFinger.forceOut to controller.feedbackIn;

        // Connections: Battery power distribution
        connect battery.powerOut to controller.powerIn;
        connect battery.powerOut to thumb.powerIn;
        connect battery.powerOut to indexFinger.powerIn;
        connect battery.powerOut to middleFinger.powerIn;
        connect battery.powerOut to ringFinger.powerIn;
        connect battery.powerOut to pinkyFinger.powerIn;

        // Connection: Battery status to controller
        connect battery.statusOut to controller.batteryStatusIn;

        // System-level state machine
        state def SystemOperation {
            entry; then Boot;

            state Boot {
                entry;
                do action initializeSystem {
                    out message = "Initializing Michelangelo Hand";
                }
                then Calibrating;
            }

            state Calibrating {
                entry;
                do action calibrateEMG {
                    in flexorSensor = emgSensorFlexor;
                    in extensorSensor = emgSensorExtensor;
                }
                do action calibrateFingers {
                    in fingers = (thumb, indexFinger, middleFinger, ringFinger, pinkyFinger);
                }
                then Active;
            }

            state Active {
                entry;
                do action monitorEMG;
                transition if controller.interpretedGrip != GripType::open then Grasping;
            }

            state Grasping {
                entry;
                do action executeGripSequence {
                    in grip = controller.interpretedGrip;
                }
                then Holding;
            }

            state Holding {
                entry;
                do action maintainGripWithFeedback {
                    in feedback;
                }
                transition if controller.extensorSignal.amplitude > 0.5 [V] then Releasing;
            }

            state Releasing {
                entry;
                do action releaseObject;
                then Active;
            }

            state Error {
                entry;
                do action logError;
                transition then Boot;
            }
        }

        exhibit state operation : SystemOperation;
    }

    // ---------- Requirements ----------
    requirement def EMGSensingRequirement {
        subject : EMGSensor;
        objective {
            doc /* The EMG sensor shall detect muscle contraction signals with amplitude as low as 0.1 mV. */
        }
        assume {
            doc /* The sensor is properly placed on the skin over the target muscle. */
        }
    }

    requirement def DualEMGRequirement {
        subject : MichelangeloHandSystem;
        objective {
            doc /* The system shall include two EMG sensors placed over the flexor and extensor muscle groups. */
        }
    }

    requirement def GripTypeRequirement {
        subject : ControllerBoard;
        objective {
            doc /* The controller shall support power, precision, lateral, tripod, and open grip types. */
        }
    }

    requirement def SignalInterpretationRequirement {
        subject : ControllerBoard;
        objective {
            doc /* The controller shall interpret strong muscle signals as power grip commands and moderate signals as precision grip commands. */
        }
    }

    requirement def FingerActuationRequirement {
        subject : Finger;
        objective {
            doc /* Each finger shall be individually actuated by its own DC motor driving a tendon for flexion and extension. */
        }
    }

    requirement def ForceSensingRequirement {
        subject : Finger;
        objective {
            doc /* Each finger shall be equipped with a force sensor to measure grip force. */
        }
    }

    requirement def GripFeedbackRequirement {
        subject : ControllerBoard;
        objective {
            doc /* The controller shall use force feedback from all fingers to adjust grip force automatically, maintaining secure hold without crushing objects. */
        }
    }

    requirement def BatteryLifeRequirement {
        subject : Battery;
        objective {
            doc /* The battery shall provide sufficient power for a full day of typical use, defined as at least 8 hours of intermittent operation. */
        }
    }

    requirement def FiveFingerRequirement {
        subject : MichelangeloHandSystem;
        objective {
            doc /* The system shall include five individually actuated fingers: thumb, index, middle, ring, and pinky. */
        }
    }

    requirement def OperationalStatesRequirement {
        subject : MichelangeloHandSystem;
        objective {
            doc /* The system shall cycle through calibrating, active, grasping, holding, and releasing states. */
        }
    }

    requirement def ProstheticReplacementRequirement {
        subject : MichelangeloHandSystem;
        objective {
            doc /* The system shall replace a missing hand and provide the user with natural, intuitive grasping and manipulation capability. */
        }
    }

    // ---------- Requirement Satisfaction ----------
    satisfaction dualEMGSat : DualEMGRequirement {
        subject : MichelangeloHandSystem;
    }

    satisfaction gripTypeSat : GripTypeRequirement {
        subject : ControllerBoard;
    }

    satisfaction fingerActSat : FingerActuationRequirement {
        subject : Finger;
    }

    satisfaction forceSensingSat : ForceSensingRequirement {
        subject : Finger;
    }

    satisfaction batteryLifeSat : BatteryLifeRequirement {
        subject : Battery;
    }

    satisfaction fiveFingerSat : FiveFingerRequirement {
        subject : MichelangeloHandSystem;
    }

    satisfaction operationalStatesSat : OperationalStatesRequirement {
        subject : MichelangeloHandSystem;
    }

    satisfaction prostheticReplacementSat : ProstheticReplacementRequirement {
        subject : MichelangeloHandSystem;
    }
}

package BiomimeticFinSystem {
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value type AngleValue :> Real { unit 'rad'; }
    value type AngularVelocityValue :> Real { unit 'rad/s'; }
    value type TorqueValue :> Real { unit 'N*m'; }
    value type ThrustValue :> Real { unit 'N'; }
    value type MassValue :> Real { unit 'kg'; }
    value type FrequencyValue :> Real { unit 'Hz'; }
    value type VoltageValue :> Real { unit 'V'; }
    value type CurrentValue :> Real { unit 'A'; }
    value type LengthValue :> Real { unit 'm'; }
    value type PowerValue :> Real { unit 'W'; }
    value type TimeValue :> Real { unit 's'; }

    // ===== Item Definitions =====
    item def AngleMeasurement {
        attr angle : AngleValue;
        attr angularVelocity : AngularVelocityValue;
    }

    item def MotorCommand {
        attr torque : TorqueValue;
        attr direction : Integer;
    }

    item def ControlCommand {
        attr targetAngle : AngleValue;
        attr targetVelocity : AngularVelocityValue;
        attr oscillationFrequency : FrequencyValue;
    }

    item def StartSignal;
    item def StopSignal;
    item def CalibrationComplete;
    item def FaultDetected;
    item def SystemReset;

    // ===== Port Definitions =====
    port def CommandPort {
        out command : ControlCommand;
    }

    port def MotorCommandPort {
        out command : MotorCommand;
    }

    port def FeedbackPort {
        out measurement : AngleMeasurement;
    }

    port def PowerPort {
        out voltage : VoltageValue;
        out current : CurrentValue;
    }

    port def MechanicalPort {
        out torque : TorqueValue;
        out angle : AngleValue;
        out angularVelocity : AngularVelocityValue;
    }

    port def ThrustPort {
        out thrust : ThrustValue;
    }

    // ===== Fin Blade =====
    part def FinBlade {
        attr length : LengthValue = 0.25 [m];
        attr width : LengthValue = 0.10 [m];
        attr mass : MassValue = 0.5 [kg];
        attr rigidityFactor : Real = 0.8;
        attr maxDeflection : AngleValue = 0.785 [rad];
        attr chordRatio : Real = 0.4;

        port mechanicalIn : ~MechanicalPort;
        port thrustOut : ThrustPort;

        action generateThrust {
            in torqueInput : TorqueValue;
            in angleInput : AngleValue;
            in angularVelocityInput : AngularVelocityValue;
            out thrustOutput : ThrustValue;
        }

        action deflect {
            in appliedTorque : TorqueValue;
            out currentAngle : AngleValue;
            out currentAngularVelocity : AngularVelocityValue;
        }
    }

    // ===== Motor =====
    part def Motor {
        attr maxTorque : TorqueValue = 5.0 [N*m];
        attr maxSpeed : AngularVelocityValue = 10.0 [rad/s];
        attr mass : MassValue = 1.2 [kg];
        attr nominalVoltage : VoltageValue = 24.0 [V];
        attr stallCurrent : CurrentValue = 15.0 [A];
        attr efficiency : Real = 0.85;
        attr torqueConstant : Real = 0.33;

        port powerIn : ~PowerPort;
        port commandIn : ~MotorCommandPort;
        port mechanicalOut : MechanicalPort;

        action driveFin {
            in command : MotorCommand;
            in voltage : VoltageValue;
            in current : CurrentValue;
            out torque : TorqueValue;
            out angle : AngleValue;
            out angularVelocity : AngularVelocityValue;
        }

        action regulatePower {
            in voltage : VoltageValue;
            in current : CurrentValue;
            out outputPower : PowerValue;
        }
    }

    // ===== Angle Sensor =====
    part def AngleSensor {
        attr resolution : AngleValue = 0.001 [rad];
        attr sampleRate : FrequencyValue = 1000.0 [Hz];
        attr mass : MassValue = 0.1 [kg];
        attr accuracy : AngleValue = 0.005 [rad];
        attr latency : TimeValue = 0.001 [s];

        port mechanicalIn : ~MechanicalPort;
        port feedbackOut : FeedbackPort;

        action measureAngle {
            in angleInput : AngleValue;
            in angularVelocityInput : AngularVelocityValue;
            out measurement : AngleMeasurement;
        }

        action filterNoise {
            in rawMeasurement : AngleMeasurement;
            out filteredMeasurement : AngleMeasurement;
        }
    }

    // ===== Fin Controller =====
    part def FinController {
        attr controlRate : FrequencyValue = 500.0 [Hz];
        attr mass : MassValue = 0.15 [kg];
        attr proportionalGain : Real = 10.0;
        attr derivativeGain : Real = 0.5;
        attr integralGain : Real = 2.0;
        attr maxOutputTorque : TorqueValue = 5.0 [N*m];
        attr integralError : AngleValue = 0.0 [rad];

        port commandIn : ~CommandPort;
        port feedbackIn : ~FeedbackPort;
        port motorCommandOut : MotorCommandPort;

        action computeControl {
            in target : ControlCommand;
            in measured : AngleMeasurement;
            out command : MotorCommand;
        }

        action oscillate {
            in frequency : FrequencyValue;
            in amplitude : AngleValue;
            in timeElapsed : TimeValue;
            out targetAngle : AngleValue;
            out targetVelocity : AngularVelocityValue;
        }

        action calibrateZero {
            in measured : AngleMeasurement;
            out zeroOffset : AngleValue;
        }
    }

    // ===== Requirements =====
    requirement def ThrustRequirement {
        doc "The system shall generate a minimum thrust of 10 N during active operation.";
        subject finSystem : BiomimeticFinSystem;
        require finSystem.maxThrust >= 10.0 [N];
    }

    requirement def AccuracyRequirement {
        doc "The system shall maintain control accuracy within 0.0175 rad (1 degree).";
        subject finSystem : BiomimeticFinSystem;
        require finSystem.controlAccuracy <= 0.0175 [rad];
    }

    requirement def WeightRequirement {
        doc "The total system mass shall not exceed 3.0 kg.";
        subject finSystem : BiomimeticFinSystem;
        require finSystem.totalMass <= 3.0 [kg];
    }

    requirement def FrequencyRequirement {
        doc "The system shall support oscillation frequencies from 0.1 Hz to 5.0 Hz.";
        subject finSystem : BiomimeticFinSystem;
        require finSystem.maxOscillationFrequency >= 5.0 [Hz];
    }

    requirement def InitializationRequirement {
        doc "The system shall complete initialization and calibration within 5 seconds of startup.";
        subject finSystem : BiomimeticFinSystem;
        require finSystem.initializationTime <= 5.0 [s];
    }

    requirement def PowerRequirement {
        doc "The system shall operate on a 24 V DC power supply with a maximum current draw of 15 A.";
        subject finSystem : BiomimeticFinSystem;
        require finSystem.operatingVoltage == 24.0 [V];
    }

    // ===== Biomimetic Fin System =====
    part def BiomimeticFinSystem {
        attr totalMass : MassValue;
        attr maxThrust : ThrustValue;
        attr controlAccuracy : AngleValue;
        attr maxOscillationFrequency : FrequencyValue;
        attr initializationTime : TimeValue;
        attr operatingVoltage : VoltageValue;

        port externalCommand : ~CommandPort;
        port externalPower : ~PowerPort;
        port thrustOutput : ThrustPort;

        part finBlade : FinBlade;
        part motor : Motor;
        part angleSensor : AngleSensor;
        part controller : FinController;

        // Connections
        connection extCmdToController connect externalCommand to controller.commandIn;
        connection controllerToMotor connect controller.motorCommandOut to motor.commandIn;
        connection motorToFin connect motor.mechanicalOut to finBlade.mechanicalIn;
        connection motorToSensor connect motor.mechanicalOut to angleSensor.mechanicalIn;
        connection sensorToController connect angleSensor.feedbackOut to controller.feedbackIn;
        connection powerToMotor connect externalPower to motor.powerIn;
        connection finToThrustOutput connect finBlade.thrustOut to thrustOutput;

        // State Machine
        state machine OperationalStates {
            state idle {
                doc "System powered but not generating thrust. Motor holds fin at zero position.";
            }
            state initializing {
                doc "Boot-up sequence: sensor zeroing, motor self-test, and controller boot.";
            }
            state calibrating {
                doc "Calibration phase: fin zero-position calibration and PID controller tuning.";
            }
            state active {
                doc "Propulsion mode: fin oscillates according to commanded parameters to generate thrust.";
            }
            state fault {
                doc "Fault condition: system safe, motor disabled, awaiting reset.";
            }

            transition initial -> idle;
            transition idle_to_initializing: idle -> initializing on startSignal;
            transition initializing_to_calibrating: initializing -> calibrating after 2.0 [s];
            transition calibrating_to_active: calibrating -> active on calibrationComplete;
            transition active_to_idle: active -> idle on stopSignal;
            transition idle_to_fault: idle -> fault on faultDetected;
            transition initializing_to_fault: initializing -> fault on faultDetected;
            transition calibrating_to_fault: calibrating -> fault on faultDetected;
            transition active_to_fault: active -> fault on faultDetected;
            transition fault_to_idle: fault -> idle on systemReset;
        }

        // Requirement satisfactions
        satisfy ThrustRequirement by finBlade;
        satisfy AccuracyRequirement by controller;
        satisfy WeightRequirement by self;
        satisfy FrequencyRequirement by controller;
        satisfy InitializationRequirement by self;
        satisfy PowerRequirement by motor;
    }
}

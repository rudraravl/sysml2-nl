package AtomicClockSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def FrequencyValue :> Real;
    attribute def StabilityValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def PressureValue :> Real;

    enum def OperationalState {
        initializing;
        warmingUp;
        stabilizing;
        locked;
        operational;
        fault;
    }

    item def MicrowaveSignal {
        attribute frequency : FrequencyValue;
        attribute power : PowerValue;
        attribute phaseNoise : Real;
    }

    item def TimeSignal {
        attribute epoch : DurationValue;
        attribute accuracy : DurationValue;
    }

    port def MicrowavePort {
        out item signal : MicrowaveSignal;
    }

    port def ControlPort {
        in item errorSignal : Real;
        out item correctionSignal : Real;
    }

    port def TimeOutputPort {
        out item timeSignal : TimeSignal;
    }

    port def AtomPort;

    part def CesiumResonator {
        attribute resonanceFrequency : FrequencyValue = 9192631770.0;
        attribute operatingTemperature : TemperatureValue;
        port microwaveInput;
        port atomicResponse;
        port atomPort : AtomPort;

        action interrogateAtoms {
            in microwaveFrequency : FrequencyValue;
            out resonanceResponse : Real;
        }
    }

    part def VacuumChamber {
        attribute pressure : PressureValue;
        attribute volume : VolumeValue;
        port atomPort : AtomPort;

        action maintainVacuum {
            in targetPressure : PressureValue;
        }
    }

    part def MagneticShield {
        attribute shieldingFactor : Real;
        attribute layers : Integer;

        action shieldExternalFields {
            in externalField : Real;
            out shieldedField : Real;
        }
    }

    part def CrystalOscillator {
        attribute nominalFrequency : FrequencyValue = 10000000.0;
        attribute controlVoltage : Real;
        port controlInput;
        port rfOutput : MicrowavePort;

        action generateSignal {
            in voltage : Real;
            out signal : MicrowaveSignal;
        }
    }

    part def FrequencyMultiplier {
        attribute multiplicationFactor : Integer = 919;
        port inputPort;
        port outputPort : MicrowavePort;

        action multiplyFrequency {
            in inputFrequency : FrequencyValue;
            out outputFrequency : FrequencyValue;
        }
    }

    part def PhaseDetector {
        attribute sensitivity : Real;
        port atomicSignal;
        port referenceSignal;
        port errorOutput;

        action detectPhaseDifference {
            in atomicPhase : Real;
            in referencePhase : Real;
            out phaseError : Real;
        }
    }

    part def ServoController {
        attribute loopGain : Real;
        attribute integrationConstant : Real;
        port errorInput;
        port controlOutput : ControlPort;

        action computeCorrection {
            in error : Real;
            out correction : Real;
        }
    }

    part def FrequencyDivider {
        attribute divisionRatio : Integer = 1000000;
        port inputPort;
        port outputPort : TimeOutputPort;

        action divideFrequency {
            in inputFrequency : FrequencyValue;
            out pulsePerSecond;
        }
    }

    part def PowerSupply {
        attribute outputVoltage : Real;
        attribute outputCurrent : Real;
        port powerOutput;

        action providePower {
            out voltage : Real;
            out current : Real;
        }
    }

    part def TemperatureController {
        attribute setpoint : TemperatureValue;
        attribute tolerance : TemperatureValue;
        port sensorInput;
        port heaterOutput;

        action regulateTemperature {
            in currentTemp : TemperatureValue;
            out heaterPower : PowerValue;
        }
    }

    state def ClockStateMachine {
        entry; then Initializing;

        state Initializing;

        state WarmingUp {
            entry action startHeating;
        }

        state Stabilizing {
            entry action beginStabilization;
        }

        state Locked {
            entry action confirmLock;
        }

        state Operational {
            entry action enableOutput;
            do action continuousMonitoring;
        }

        state Fault {
            entry action logError;
        }

        transition first Initializing to WarmingUp
            accept powerApplied;
        transition WarmingUp to Stabilizing
            accept temperatureReached;
        transition Stabilizing to Locked
            accept frequencyStable;
        transition Locked to Operational
            accept lockConfirmed;
        transition Operational to Fault
            accept signalLost;
        transition Fault to Initializing
            accept resetCommand;
    }

    part atomicClock {
        doc /* 
         * An atomic clock system that uses the hyperfine transition frequency 
         * of cesium-133 atoms (9,192,631,770 Hz) as a fundamental time reference 
         * to generate highly accurate and stable time signals.
         */

        attribute currentState : OperationalState;
        attribute systemAccuracy : DurationValue;
        attribute uptimeHours : Real;

        part cesiumCell : CesiumResonator {
            attribute :>> operatingTemperature = 323.15;
        }

        part vacuum : VacuumChamber {
            attribute :>> pressure = 1.0e-8;
            attribute :>> volume = 0.0005;
        }

        part shield : MagneticShield {
            attribute :>> shieldingFactor = 50000.0;
            attribute :>> layers = 3;
        }

        part localOscillator : CrystalOscillator {
            attribute :>> nominalFrequency = 10000000.0;
        }

        part multiplier : FrequencyMultiplier {
            attribute :>> multiplicationFactor = 919;
        }

        part detector : PhaseDetector {
            attribute :>> sensitivity = 0.001;
        }

        part servo : ServoController {
            attribute :>> loopGain = 1.5;
            attribute :>> integrationConstant = 0.1;
        }

        part divider : FrequencyDivider {
            attribute :>> divisionRatio = 10000000;
        }

        part power : PowerSupply {
            attribute :>> outputVoltage = 24.0;
            attribute :>> outputCurrent = 2.5;
        }

        part tempControl : TemperatureController {
            attribute :>> setpoint = 323.15;
            attribute :>> tolerance = 0.01;
        }

        connection oscToMultiplier connect localOscillator.rfOutput to multiplier.inputPort;
        connection multiplierToCesium connect multiplier.outputPort to cesiumCell.microwaveInput;
        connection cesiumToDetector connect cesiumCell.atomicResponse to detector.atomicSignal;
        connection oscToDetector connect localOscillator.rfOutput to detector.referenceSignal;
        connection detectorToServo connect detector.errorOutput to servo.errorInput;
        connection servoToOsc connect servo.controlOutput to localOscillator.controlInput;
        connection oscToDivider connect localOscillator.rfOutput to divider.inputPort;
        connection cesiumToVacuum connect cesiumCell.atomPort to vacuum.atomPort;
        connection powerToTemp connect power.powerOutput to tempControl.heaterOutput;

        perform action generatePreciseTime {
            doc /* 
             * Primary operation: continuously interrogate cesium atoms with 
             * microwave radiation at their hyperfine transition frequency, 
             * measure the atomic resonance, and lock the local oscillator 
             * to this atomic reference to produce a highly stable time signal.
             */

            first start;
            then merge continuousOperation;

            then action initialize {
                action powerUp : power.providePower;
                then action evacuate : vacuum.maintainVacuum {
                    in targetPressure = 1.0e-8;
                }
                then action activateShielding : shield.shieldExternalFields;
            }

            then action warmUp {
                action stabilizeTemperature : tempControl.regulateTemperature;
                then action waitForStability;
            }

            then action lockToAtomic {
                action generateMicrowave : multiplier.multiplyFrequency;
                then action interrogate : cesiumCell.interrogateAtoms;
                then action measurePhase : detector.detectPhaseDifference;
                then action correctFrequency : servo.computeCorrection;
                then action adjustOscillator : localOscillator.generateSignal;
            }

            then decide;
                if currentState == OperationalState::locked then outputTime;
                if currentState == OperationalState::fault then handleFault;

            action outputTime : divider.divideFrequency;
            then continuousOperation;

            action handleFault {
                action diagnose;
                then action reset;
            }
            then initialize;
        }

        exhibit state clockBehavior : ClockStateMachine;
    }

    requirement <'REQ-AC-001'> atomicReference {
        doc /* 
         * The atomic clock shall use the hyperfine transition frequency 
         * of cesium-133 atoms (9,192,631,770 Hz) as the fundamental 
         * time reference.
         */
        subject clock :>> atomicClock;

        require constraint {
            clock.cesiumCell.resonanceFrequency == 9192631770.0
        }
    }

    requirement <'REQ-AC-002'> timekeepingAccuracy {
        doc /* 
         * The atomic clock shall maintain timekeeping accuracy better 
         * than 1 nanosecond per day during operational state.
         */
        subject clock :>> atomicClock;

        require constraint {
            clock.systemAccuracy.num <= 1.0e-9
        }
    }

    requirement <'REQ-AC-003'> environmentalIsolation {
        doc /* 
         * The atomic clock shall maintain ultra-high vacuum and 
         * magnetic shielding to isolate cesium atoms from external 
         * disturbances.
         */
        subject clock :>> atomicClock;

        require constraint {
            clock.vacuum.pressure <= 1.0e-7 and
            clock.shield.shieldingFactor >= 10000.0
        }
    }

    requirement <'REQ-AC-004'> continuousOperation {
        doc /* 
         * The atomic clock shall operate continuously with automatic 
         * frequency locking through closed-loop servo control.
         */
        subject clock :>> atomicClock;

        require constraint {
            clock.currentState == OperationalState::operational or
            clock.currentState == OperationalState::locked
        }
    }

    requirement <'REQ-AC-005'> outputStability {
        doc /* 
         * The atomic clock shall provide a stable 10 MHz reference 
         * output and 1 pulse-per-second time signal.
         */
        subject clock :>> atomicClock;

        require constraint {
            clock.localOscillator.nominalFrequency == 10000000.0 and
            clock.divider.divisionRatio == 10000000
        }
    }

    satisfy atomicReference by atomicClock;
    satisfy timekeepingAccuracy by atomicClock;
    satisfy environmentalIsolation by atomicClock;
    satisfy continuousOperation by atomicClock;
    satisfy outputStability by atomicClock;
}

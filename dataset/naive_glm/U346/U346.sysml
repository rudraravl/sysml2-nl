package PapooseBoard {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ---- Value types with units ----
    value type VoltageValue :> Real { unit = Volt; }
    value type CurrentValue :> Real { unit = Ampere; }
    value type TemperatureValue :> Real { unit = Celsius; }
    value type PressureValue :> Real { unit = Pascal; }
    value type PositionValue :> Real { unit = Radian; }
    value type FrequencyValue :> Real { unit = Hertz; }
    value type TimeValue :> Real { unit = Second; }
    value type DutyCycleValue :> Real { unit = Percent; }

    // ---- Item definitions ----
    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    item def SensorData {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute position : PositionValue;
        attribute timestamp : TimeValue;
    }

    item def ControlCommand {
        attribute motorSpeed : FrequencyValue;
        attribute valvePosition : PositionValue;
        attribute pumpEnabled : Boolean;
        attribute dutyCycle : DutyCycleValue;
    }

    item def StatusPacket {
        attribute boardId : String;
        attribute currentState : String;
        attribute sensorReading : SensorData;
        attribute timestamp : TimeValue;
    }

    item def HostInstruction {
        attribute command : String;
        attribute parameter : Real;
    }

    // ---- Port definitions ----
    port def ExternalPowerPort {
        in rawPower : ElectricalPower;
    }

    port def PowerPort {
        out power : ElectricalPower;
    }

    port def SensorDataPort {
        out data : SensorData;
    }

    port def CommandPort {
        in command : ControlCommand;
    }

    port def CommunicationPort {
        out status : StatusPacket;
        in instruction : HostInstruction;
    }

    // ---- Microcontroller ----
    part def Microcontroller {
        port powerIn : PowerPort;
        port sensorIn : SensorDataPort;
        port commandOut : CommandPort;
        port commPort : CommunicationPort;

        attribute clockFrequency : FrequencyValue = 168e6 [Hz];
        attribute programMemory : Integer = 512;
        attribute ramSize : Integer = 128;
        attribute cycleTime : TimeValue = 0.001 [s];

        action def ProcessSensorData {
            in sensorData : SensorData;
            out command : ControlCommand;
            out status : StatusPacket;
        }

        action runControlLoop : ProcessSensorData {
            in sensorData : SensorData;
            out command : ControlCommand;
            out status : StatusPacket;
        }
    }

    // ---- Power Regulator ----
    part def PowerRegulator {
        port rawPowerIn : ExternalPowerPort;
        port mcuPowerOut : PowerPort;
        port modulePowerOut : PowerPort;

        attribute inputVoltageMin : VoltageValue = 6.0 [V];
        attribute inputVoltageMax : VoltageValue = 36.0 [V];
        attribute outputVoltage : VoltageValue = 5.0 [V];
        attribute maxOutputCurrent : CurrentValue = 10.0 [A];
        attribute overloadDetected : Boolean = false;
        attribute startupTime : TimeValue = 0.5 [s];
        attribute protectionTimeout : TimeValue = 2.0 [s];

        state machine PowerStates {
            state Off {
                entry action { overloadDetected = false; }
            }
            state Starting {
                entry action { outputVoltage = 0.0 [V]; }
            }
            state On {
                entry action { outputVoltage = 5.0 [V]; }
            }
            state SelfProtection {
                entry action { outputVoltage = 0.0 [V]; }
            }

            transition off_to_starting
                first Off
                if rawPowerIn.rawPower.voltage >= inputVoltageMin
                then Starting;

            transition starting_to_on
                first Starting
                after startupTime
                then On;

            transition on_to_protection
                first On
                if overloadDetected
                then SelfProtection;

            transition protection_to_off
                first SelfProtection
                after protectionTimeout
                then Off;
        }
    }

    // ---- Sensor Array ----
    part def SensorArray {
        port powerIn : PowerPort;
        port dataOut : SensorDataPort;

        attribute samplingRate : FrequencyValue = 1000 [Hz];
        attribute channelCount : Integer = 8;
        attribute resolutionBits : Integer = 16;

        action def AcquireData {
            out data : SensorData;
        }

        action acquire : AcquireData {
            out data : SensorData;
        }
    }

    // ---- Actuator Controller ----
    part def ActuatorController {
        port powerIn : PowerPort;
        port commandIn : CommandPort;

        attribute outputChannels : Integer = 6;
        attribute maxDriveCurrent : CurrentValue = 2.5 [A];
        attribute pwmFrequency : FrequencyValue = 20000 [Hz];

        action def DriveActuators {
            in command : ControlCommand;
        }

        action drive : DriveActuators {
            in command : ControlCommand;
        }
    }

    // ---- Communication Module ----
    part def CommunicationModule {
        port powerIn : PowerPort;
        port commPort : CommunicationPort;

        attribute baudRate : FrequencyValue = 115200 [Hz];
        attribute protocol : String = "UART";
        attribute maxPacketSize : Integer = 256;
        attribute retryCount : Integer = 3;

        action def TransmitStatus {
            in status : StatusPacket;
        }

        action def ReceiveInstruction {
            out instruction : HostInstruction;
        }

        action transmit : TransmitStatus {
            in status : StatusPacket;
        }

        action receive : ReceiveInstruction {
            out instruction : HostInstruction;
        }
    }

    // ---- Top-level Papoose Board ----
    part def PapooseBoard {
        port externalPower : ExternalPowerPort;
        port externalComm : CommunicationPort;

        attribute boardId : String = "PAPOOSE-001";
        attribute firmwareVersion : String = "1.0.0";
        attribute maxLoopTime : TimeValue = 0.010 [s];
        attribute faultDetected : Boolean = false;

        part powerRegulator : PowerRegulator {
            exhibit PowerStates;
        }
        part microcontroller : Microcontroller {}
        part sensorArray : SensorArray {}
        part actuatorController : ActuatorController {}
        part communicationModule : CommunicationModule {}

        // Power distribution
        connection rawPowerConnection
            connect externalPower to powerRegulator.rawPowerIn;

        connection mcuPowerConnection
            connect powerRegulator.mcuPowerOut to microcontroller.powerIn;

        connection sensorPowerConnection
            connect powerRegulator.modulePowerOut to sensorArray.powerIn;

        connection actuatorPowerConnection
            connect powerRegulator.modulePowerOut to actuatorController.powerIn;

        connection commPowerConnection
            connect powerRegulator.modulePowerOut to communicationModule.powerIn;

        // Data and command flows
        connection sensorDataConnection
            connect sensorArray.dataOut to microcontroller.sensorIn;

        connection commandConnection
            connect microcontroller.commandOut to actuatorController.commandIn;

        connection internalCommConnection
            connect microcontroller.commPort to communicationModule.commPort;

        connection externalCommConnection
            connect communicationModule.commPort to externalComm;

        // Board-level state machine
        state machine BoardStates {
            state Idle {
                entry action { faultDetected = false; }
            }

            state Active {
                entry action { /* begin control loop */ }

                state Acquiring {
                    do action sensorArray.acquire;
                }
                state Processing {
                    do action microcontroller.runControlLoop;
                }
                state Actuating {
                    do action actuatorController.drive;
                }
                state Communicating {
                    do action communicationModule.transmit;
                }

                transition acquire_to_process first Acquiring then Processing;
                transition process_to_actuate first Processing then Actuating;
                transition actuate_to_communicate first Actuating then Communicating;
                transition communicate_to_acquire first Communicating then Acquiring;
            }

            state Fault {
                entry action { faultDetected = true; }
            }

            transition idle_to_active
                first Idle
                if externalComm.instruction.command == "START"
                then Active;

            transition active_to_fault
                first Active
                if powerRegulator.overloadDetected or faultDetected
                then Fault;

            transition fault_to_idle
                first Fault
                if externalComm.instruction.command == "RESET"
                then Idle;
        }

        exhibit BoardStates;
    }

    // ---- Requirements ----
    requirement def PowerInputRangeRequirement {
        doc "The power regulator shall accept a wide input voltage range."
        subject powerRegulator : PowerRegulator;
        require {
            powerRegulator.inputVoltageMin <= 6.0 [V];
            powerRegulator.inputVoltageMax >= 36.0 [V];
        }
    }

    requirement def RegulatedOutputRequirement {
        doc "The regulator shall provide a stable 5V output to onboard modules."
        subject powerRegulator : PowerRegulator;
        require powerRegulator.outputVoltage == 5.0 [V];
    }

    requirement def OverloadProtectionRequirement {
        doc "The regulator shall enter self-protection on overload."
        subject powerRegulator : PowerRegulator;
        require powerRegulator.PowerStates.SelfProtection.reachable;
    }

    requirement def RealTimeControlRequirement {
        doc "The board shall complete one control loop within 10 ms."
        subject board : PapooseBoard;
        require board.maxLoopTime <= 0.010 [s];
    }

    requirement def SensorSamplingRequirement {
        doc "The sensor array shall sample at least 1000 Hz."
        subject sensorArray : SensorArray;
        require sensorArray.samplingRate >= 1000 [Hz];
    }

    requirement def CommunicationRequirement {
        doc "The communication module shall support at least 115200 baud."
        subject communicationModule : CommunicationModule;
        require communicationModule.baudRate >= 115200 [Hz];
    }

    requirement def SafetyFaultRequirement {
        doc "The board shall enter a fault state on detected errors and halt the control loop."
        subject board : PapooseBoard;
        require board.BoardStates.Fault.reachable;
    }

    requirement def ActuatorDriveRequirement {
        doc "The actuator controller shall drive up to 6 channels at 2.5 A each."
        subject actuatorController : ActuatorController;
        require {
            actuatorController.outputChannels >= 6;
            actuatorController.maxDriveCurrent >= 2.5 [A];
        }
    }

    // ---- Requirement satisfaction ----
    satisfaction powerInputRangeSatisfaction
        by powerRegulator satisfies PowerInputRangeRequirement;

    satisfaction regulatedOutputSatisfaction
        by powerRegulator satisfies RegulatedOutputRequirement;

    satisfaction overloadProtectionSatisfaction
        by powerRegulator satisfies OverloadProtectionRequirement;

    satisfaction realTimeControlSatisfaction
        by PapooseBoard satisfies RealTimeControlRequirement;

    satisfaction sensorSamplingSatisfaction
        by sensorArray satisfies SensorSamplingRequirement;

    satisfaction communicationSatisfaction
        by communicationModule satisfies CommunicationRequirement;

    satisfaction safetyFaultSatisfaction
        by PapooseBoard satisfies SafetyFaultRequirement;

    satisfaction actuatorDriveSatisfaction
        by actuatorController satisfies ActuatorDriveRequirement;
}

package MicrocontrollerBasedMonitoringSystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    value def Volt :> ISQ::electricPotential;
    value def Ampere :> ISQ::electricCurrent;
    value def Watt :> ISQ::power;
    value def Ohm :> ISQ::resistance;
    value def Hertz :> ISQ::frequency;
    value def Bitrate {
        unit kbps;
        unit Mbps;
    }
    value def Percent {
        unit percent;
    }
    value def Celsius :> ISQ::thermodynamicTemperature;
    value def Millisecond :> ISQ::time;
    value def Byte {
        unit B;
        unit kB;
        unit MB;
    }

    item def AnalogSample {
        attribute channelId : Integer;
        attribute voltage : Volt;
        attribute sampledAt : Millisecond;
    }

    item def DigitalSample {
        attribute channelId : Integer;
        attribute state : Boolean;
        attribute sampledAt : Millisecond;
    }

    item def SensorMeasurement {
        attribute temperature : Celsius;
        attribute supplyVoltage : Volt;
        attribute signalQuality : Percent;
        attribute measuredAt : Millisecond;
    }

    item def ControlCommand {
        attribute commandId : Integer;
        attribute targetOutput : Integer;
        attribute requestedState : Boolean;
        attribute issuedAt : Millisecond;
    }

    item def DiagnosticRecord {
        attribute uptime : Millisecond;
        attribute resetCount : Integer;
        attribute cpuLoad : Percent;
        attribute faultCode : Integer;
    }

    item def TelemetryFrame {
        attribute sequenceNumber : Integer;
        attribute payloadLength : Byte;
        attribute checksumValid : Boolean;
    }

    port def PowerInputPort {
        in item supplyVoltage : Volt;
        in item supplyCurrent : Ampere;
    }

    port def GroundPort {
        inout item referencePotential : Volt;
    }

    port def AnalogInputPort {
        in item sample : AnalogSample;
    }

    port def DigitalInputPort {
        in item sample : DigitalSample;
    }

    port def DigitalOutputPort {
        out item command : ControlCommand;
    }

    port def CommunicationPort {
        in item receivedCommand : ControlCommand;
        out item telemetry : TelemetryFrame;
        out item diagnostics : DiagnosticRecord;
    }

    port def ProgrammingPort {
        in item firmwareImageSize : Byte;
        out item programmingStatus : Boolean;
    }

    part def RegulatedPowerSubsystem {
        attribute inputVoltageMin : Volt = 7 [V];
        attribute inputVoltageMax : Volt = 24 [V];
        attribute regulatedVoltage : Volt = 3.3 [V];
        attribute maxOutputCurrent : Ampere = 0.5 [A];
        attribute conversionEfficiency : Percent = 88 [percent];

        port powerIn : PowerInputPort;
        port ground : GroundPort;
        port regulatedOut : PowerInputPort;

        state def PowerRegulationState {
            state off;
            state ramping;
            state regulated;
            state fault;

            transition first off;
            transition off to ramping
                accept PowerApplied;
            transition ramping to regulated
                if inputVoltageMin <= 12 [V] and inputVoltageMax >= 12 [V];
            transition ramping to fault
                if regulatedVoltage < 3.0 [V];
            transition regulated to fault
                if regulatedVoltage > 3.6 [V];
            transition fault to off
                accept PowerRemoved;
        }
    }

    part def Microcontroller {
        attribute coreClock : Hertz = 120 [MHz];
        attribute flashMemory : Byte = 512 [kB];
        attribute ramMemory : Byte = 128 [kB];
        attribute adcResolutionBits : Integer = 12;
        attribute adcReferenceVoltage : Volt = 3.3 [V];
        attribute maxGpioCurrent : Ampere = 0.02 [A];
        attribute watchdogTimeout : Millisecond = 1000 [ms];

        port power : PowerInputPort;
        port ground : GroundPort;
        port analogIn[4] : AnalogInputPort;
        port digitalIn[4] : DigitalInputPort;
        port digitalOut[4] : DigitalOutputPort;
        port comms : CommunicationPort;
        port programming : ProgrammingPort;

        action def AcquireInputs {
            in item analogSamples[4] : AnalogSample;
            in item digitalSamples[4] : DigitalSample;
            out item measurement : SensorMeasurement;
        }

        action def EvaluateControlLogic {
            in item measurement : SensorMeasurement;
            in item receivedCommand : ControlCommand;
            out item outputCommand[4] : ControlCommand;
        }

        action def PublishTelemetry {
            in item measurement : SensorMeasurement;
            in item diagnostics : DiagnosticRecord;
            out item telemetry : TelemetryFrame;
        }

        action def RunPrimaryControlCycle {
            first start;
            action acquire : AcquireInputs;
            action evaluate : EvaluateControlLogic;
            action publish : PublishTelemetry;
            then acquire;
            then evaluate;
            then publish;
            then done;
        }

        state def FirmwareExecutionState {
            state reset;
            state boot;
            state selfTest;
            state applicationReady;
            state sampling;
            state processing;
            state communicating;
            state degraded;
            state safeShutdown;

            transition first reset;
            transition reset to boot;
            transition boot to selfTest;
            transition selfTest to applicationReady
                if flashMemory >= 256 [kB] and ramMemory >= 64 [kB];
            transition selfTest to degraded
                if adcReferenceVoltage < 3.0 [V];
            transition applicationReady to sampling;
            transition sampling to processing;
            transition processing to communicating;
            transition communicating to sampling;
            transition sampling to degraded
                if watchdogTimeout < 100 [ms];
            transition degraded to safeShutdown
                accept CriticalFaultDetected;
            transition safeShutdown to reset
                accept ExternalReset;
        }
    }

    part def SensorInterface {
        attribute sensorSupplyVoltage : Volt = 3.3 [V];
        attribute inputImpedance : Ohm = 100000 [Ohm];
        attribute sampleRate : Hertz = 1000 [Hz];
        attribute temperatureRangeLow : Celsius = -40 [K];
        attribute temperatureRangeHigh : Celsius = 398.15 [K];

        port power : PowerInputPort;
        port ground : GroundPort;
        port analogSignal[2] : AnalogInputPort;
        port digitalSignal[2] : DigitalInputPort;
        port conditionedAnalog[2] : AnalogInputPort;
        port conditionedDigital[2] : DigitalInputPort;

        action def ConditionSensorSignals {
            in item rawAnalog[2] : AnalogSample;
            in item rawDigital[2] : DigitalSample;
            out item conditionedAnalog[2] : AnalogSample;
            out item conditionedDigital[2] : DigitalSample;
        }
    }

    part def OutputDriver {
        attribute outputVoltage : Volt = 12 [V];
        attribute maxLoadCurrent : Ampere = 1.5 [A];
        attribute channelCount : Integer = 4;
        attribute shortCircuitLimit : Ampere = 2.0 [A];

        port power : PowerInputPort;
        port ground : GroundPort;
        port logicCommand[4] : DigitalOutputPort;
        port loadOutput[4] : DigitalOutputPort;

        state def DriverState {
            state disabled;
            state enabled;
            state currentLimited;
            state faultLatched;

            transition first disabled;
            transition disabled to enabled
                accept EnableOutputs;
            transition enabled to currentLimited
                if maxLoadCurrent > shortCircuitLimit;
            transition currentLimited to faultLatched
                after 50 [ms];
            transition faultLatched to disabled
                accept ClearFault;
        }
    }

    part def CommunicationInterface {
        attribute busVoltage : Volt = 3.3 [V];
        attribute baudRate : Bitrate = 500 [kbps];
        attribute maxFrameSize : Byte = 256 [B];
        attribute protocolOverhead : Byte = 12 [B];

        port power : PowerInputPort;
        port ground : GroundPort;
        port mcuComms : CommunicationPort;
        port externalComms : CommunicationPort;

        action def ExchangeFrames {
            in item commandFromHost : ControlCommand;
            in item telemetryFromController : TelemetryFrame;
            out item commandToController : ControlCommand;
            out item telemetryToHost : TelemetryFrame;
        }
    }

    part def StatusIndicator {
        attribute ledForwardVoltage : Volt = 2.1 [V];
        attribute ledCurrent : Ampere = 0.01 [A];
        attribute blinkPeriod : Millisecond = 500 [ms];

        port power : PowerInputPort;
        port ground : GroundPort;
        port control : DigitalOutputPort;

        state def IndicationState {
            state off;
            state bootBlink;
            state normalHeartbeat;
            state faultBlink;

            transition first off;
            transition off to bootBlink
                accept BootStarted;
            transition bootBlink to normalHeartbeat
                accept ApplicationReady;
            transition normalHeartbeat to faultBlink
                accept FaultDetected;
            transition faultBlink to normalHeartbeat
                accept FaultCleared;
        }
    }

    part def MicrocontrollerBasedSystem {
        attribute nominalInputVoltage : Volt = 12 [V];
        attribute nominalPowerConsumption : Watt = 2.5 [W];
        attribute controlLoopPeriod : Millisecond = 10 [ms];
        attribute requiredAvailability : Percent = 99 [percent];

        port dcInput : PowerInputPort;
        port chassisGround : GroundPort;
        port externalSensorAnalog[2] : AnalogInputPort;
        port externalSensorDigital[2] : DigitalInputPort;
        port controlledLoads[4] : DigitalOutputPort;
        port hostLink : CommunicationPort;
        port servicePort : ProgrammingPort;

        part powerSubsystem : RegulatedPowerSubsystem;
        part controller : Microcontroller;
        part sensorInterface : SensorInterface;
        part outputDriver : OutputDriver;
        part communicationInterface : CommunicationInterface;
        part indicator : StatusIndicator;

        connect dcInput to powerSubsystem.powerIn;
        connect chassisGround to powerSubsystem.ground;
        connect powerSubsystem.regulatedOut to controller.power;
        connect powerSubsystem.regulatedOut to sensorInterface.power;
        connect powerSubsystem.regulatedOut to communicationInterface.power;
        connect powerSubsystem.regulatedOut to indicator.power;
        connect chassisGround to controller.ground;
        connect chassisGround to sensorInterface.ground;
        connect chassisGround to outputDriver.ground;
        connect chassisGround to communicationInterface.ground;
        connect chassisGround to indicator.ground;

        connect externalSensorAnalog[0] to sensorInterface.analogSignal[0];
        connect externalSensorAnalog[1] to sensorInterface.analogSignal[1];
        connect externalSensorDigital[0] to sensorInterface.digitalSignal[0];
        connect externalSensorDigital[1] to sensorInterface.digitalSignal[1];

        connect sensorInterface.conditionedAnalog[0] to controller.analogIn[0];
        connect sensorInterface.conditionedAnalog[1] to controller.analogIn[1];
        connect sensorInterface.conditionedDigital[0] to controller.digitalIn[0];
        connect sensorInterface.conditionedDigital[1] to controller.digitalIn[1];

        connect controller.digitalOut[0] to outputDriver.logicCommand[0];
        connect controller.digitalOut[1] to outputDriver.logicCommand[1];
        connect controller.digitalOut[2] to outputDriver.logicCommand[2];
        connect controller.digitalOut[3] to outputDriver.logicCommand[3];

        connect outputDriver.loadOutput[0] to controlledLoads[0];
        connect outputDriver.loadOutput[1] to controlledLoads[1];
        connect outputDriver.loadOutput[2] to controlledLoads[2];
        connect outputDriver.loadOutput[3] to controlledLoads[3];

        connect controller.comms to communicationInterface.mcuComms;
        connect communicationInterface.externalComms to hostLink;
        connect controller.programming to servicePort;
        connect controller.digitalOut[3] to indicator.control;

        perform controller.RunPrimaryControlCycle;

        requirement def PrimaryFunctionRequirement {
            subject system : MicrocontrollerBasedSystem;
            doc /* The system shall use a microcontroller to acquire sensor inputs, evaluate embedded control logic, drive external loads, and publish operational telemetry to a host interface. */
            require constraint {
                system.controlLoopPeriod <= 10 [ms]
            }
        }

        requirement def PowerRequirement {
            subject system : MicrocontrollerBasedSystem;
            doc /* The system shall operate from a nominal 12 VDC input and provide regulated 3.3 V power to internal low-voltage electronics. */
            require constraint {
                system.nominalInputVoltage == 12 [V]
            }
        }

        requirement def SamplingRequirement {
            subject interface : SensorInterface;
            doc /* The sensor interface shall condition analog and digital sensor signals before they are sampled by the microcontroller. */
            require constraint {
                interface.sampleRate >= 1000 [Hz]
            }
        }

        requirement def CommunicationRequirement {
            subject interface : CommunicationInterface;
            doc /* The communication interface shall exchange command, telemetry, and diagnostic records between the microcontroller and an external host. */
            require constraint {
                interface.baudRate >= 500 [kbps]
            }
        }

        requirement def FaultHandlingRequirement {
            subject controller : Microcontroller;
            doc /* The firmware shall enter a degraded or safe shutdown state when self-test, watchdog, or critical-fault conditions indicate unsafe operation. */
            require constraint {
                controller.watchdogTimeout <= 1000 [ms]
            }
        }

        requirement def OutputProtectionRequirement {
            subject driver : OutputDriver;
            doc /* The output driver shall limit current and latch a fault when a controlled load exceeds the configured current threshold. */
            require constraint {
                driver.shortCircuitLimit <= 2.0 [A]
            }
        }
    }

    satisfy MicrocontrollerBasedSystem::PrimaryFunctionRequirement by MicrocontrollerBasedSystem::controller;
    satisfy MicrocontrollerBasedSystem::PowerRequirement by MicrocontrollerBasedSystem::powerSubsystem;
    satisfy MicrocontrollerBasedSystem::SamplingRequirement by MicrocontrollerBasedSystem::sensorInterface;
    satisfy MicrocontrollerBasedSystem::CommunicationRequirement by MicrocontrollerBasedSystem::communicationInterface;
    satisfy MicrocontrollerBasedSystem::FaultHandlingRequirement by MicrocontrollerBasedSystem::controller;
    satisfy MicrocontrollerBasedSystem::OutputProtectionRequirement by MicrocontrollerBasedSystem::outputDriver;
}
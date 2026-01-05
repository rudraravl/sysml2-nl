package MicrocontrollerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def ClockFrequency :> ISQ::FrequencyValue;
    attribute def VoltageLevel :> ISQ::VoltageValue;
    attribute def MemorySize :> ISQ::InformationValue;
    attribute def PinCount :> ScalarValues::Integer;
    attribute def SamplingRate :> ISQ::FrequencyValue;
    attribute def TemperatureValue :> ISQ::TemperatureValue;
    attribute def PowerValue :> ISQ::PowerValue;

    enum def SignalState {
        low;
        high;
        tristate;
    }

    enum def OperatingMode {
        active;
        sleep;
        deepSleep;
        shutdown;
    }

    attribute def DigitalSignal {
        attribute level : VoltageLevel;
        attribute state : SignalState;
    }

    item def SensorData {
        attribute timestamp : ISQ::TimeValue;
        attribute temperature : TemperatureValue;
        attribute valid : Boolean;
    }

    item def ControlCommand {
        attribute targetDevice : String;
        attribute outputLevel : VoltageLevel;
        attribute enabled : Boolean;
    }

    port def DigitalInputPort {
        in attribute signal : DigitalSignal;
    }

    port def DigitalOutputPort {
        out attribute signal : DigitalSignal;
    }

    port def AnalogInputPort {
        in attribute voltage : VoltageLevel;
    }

    port def PowerPort {
        in attribute supply : VoltageLevel;
        in attribute current : ISQ::ElectricCurrentValue;
    }

    part def Microcontroller {
        attribute clockSpeed : ClockFrequency;
        attribute operatingVoltage : VoltageLevel;
        attribute flashMemory : MemorySize;
        attribute ramMemory : MemorySize;
        attribute pinCount : PinCount;
        attribute currentMode : OperatingMode;

        port powerIn : PowerPort;
        port analogInputs : AnalogInputPort[4];
        port digitalOutputs : DigitalOutputPort[8];

        part cpu {
            attribute processingLoad : Real;
        }

        part memory {
            attribute dataBuffer : SensorData[*];
            attribute commandQueue : ControlCommand[*];
        }

        part peripherals {
            part adc {
                attribute resolution : Integer;
                attribute samplingRate : SamplingRate;
            }
            part timer {
                attribute period : ISQ::TimeValue;
                attribute enabled : Boolean;
            }
        }

        perform action controlOperation;
    }

    part def TemperatureSensor {
        attribute sensorId : String;
        attribute measurementRange : TemperatureValue[2];
        attribute accuracy : TemperatureValue;

        port output : AnalogInputPort;
        port power : PowerPort;

        perform action measureTemperature;
    }

    part def HeatingElement {
        attribute elementId : String;
        attribute maxPower : PowerValue;
        attribute currentState : Boolean;

        port control : DigitalInputPort;
        port power : PowerPort;

        perform action applyHeat;
    }

    part def PowerSupply {
        attribute inputVoltage : VoltageLevel;
        attribute outputVoltage : VoltageLevel;
        attribute maxCurrent : ISQ::ElectricCurrentValue;

        port powerOut : PowerPort;
    }

    action def ReadSensor {
        in port sensorPort : AnalogInputPort;
        out sensorReading : SensorData;
    }

    action def ProcessSensorData {
        in rawData : SensorData;
        in setpoint : TemperatureValue;
        out processedValue : TemperatureValue;
        out isValid : Boolean;
        out controlDecision : Boolean;
    }

    action def GenerateControlSignal {
        in controlDecision : Boolean;
        out controlCmd : ControlCommand;
    }

    action def SendCommand {
        in command : ControlCommand;
        in port outputPort : DigitalOutputPort;
    }

    action controlOperation : ControlOperation {
        first start;
        then merge controlLoop;

        action controlLoop {
            action readSensor : ReadSensor {
                in port sensorPort;
                out sensorReading : SensorData;
            }

            then action processData : ProcessSensorData {
                in rawData = readSensor.sensorReading;
                in setpoint = 25.0;
                out processedValue : TemperatureValue;
                out isValid : Boolean;
                out controlDecision : Boolean;
            }

            then decide;
                if processData.isValid and processData.controlDecision then activateHeater;
                if processData.isValid and not processData.controlDecision then deactivateHeater;
                if not processData.isValid then handleError;

            action activateHeater : GenerateControlSignal {
                in controlDecision = true;
                out controlCmd : ControlCommand;
            }
            then sendControl;

            action deactivateHeater : GenerateControlSignal {
                in controlDecision = false;
                out controlCmd : ControlCommand;
            }
            then sendControl;

            action handleError {
                action logError;
            }
            then sendControl;

            action sendControl : SendCommand {
                in command;
                in port outputPort;
            }

            then controlLoop;
        }
    }

    action def ControlOperation {
        in attribute targetTemperature : TemperatureValue;
        in attribute samplingInterval : ISQ::TimeValue;
        out attribute systemStatus : Boolean;
    }

    attribute def PowerLossEvent;
    attribute def CriticalErrorEvent;
    attribute def WakeupEvent;
    attribute def ResetCompleteEvent;

    state def MicrocontrollerStates {
        entry; then initialization;

        state initialization {
            entry assign currentMode := OperatingMode::active;
        }
        then running;

        state running;
        accept powerLoss : PowerLossEvent then lowPower;
        accept criticalError : CriticalErrorEvent then errorHandling;

        state lowPower {
            entry assign currentMode := OperatingMode::sleep;
        }
        accept wakeup : WakeupEvent then running;

        state errorHandling {
            entry assign currentMode := OperatingMode::shutdown;
        }
        then recovery;

        state recovery;
        accept resetComplete : ResetCompleteEvent then initialization;
    }

    part temperatureControlSystem {
        part mcu : Microcontroller {
            attribute :>> clockSpeed = 48.0;
            attribute :>> operatingVoltage = 3.3;
            attribute :>> flashMemory = 256.0;
            attribute :>> ramMemory = 64.0;
            attribute :>> pinCount = 64;
            attribute :>> currentMode = OperatingMode::active;

            perform action operation : ControlOperation {
                in attribute :>> targetTemperature = 25.0;
                in attribute :>> samplingInterval = 100.0;
                out attribute :>> systemStatus;
            }
        }

        part tempSensor1 : TemperatureSensor {
            attribute :>> sensorId = "TEMP_01";
            attribute :>> accuracy = 0.5;

            perform action sensing : ReadSensor;
        }

        part tempSensor2 : TemperatureSensor {
            attribute :>> sensorId = "TEMP_02";
            attribute :>> accuracy = 0.5;
        }

        part heater : HeatingElement {
            attribute :>> elementId = "HEAT_01";
            attribute :>> maxPower = 100.0;
            attribute :>> currentState = false;

            perform action heating : SendCommand;
        }

        part powerSupply : PowerSupply {
            attribute :>> inputVoltage = 12.0;
            attribute :>> outputVoltage = 3.3;
            attribute :>> maxCurrent = 2.0;
        }

        connection sensorConnection1 connect 
            tempSensor1.output to mcu.analogInputs;

        connection sensorConnection2 connect 
            tempSensor2.output to mcu.analogInputs;

        connection heaterConnection connect 
            mcu.digitalOutputs to heater.control;

        connection powerConnection1 connect 
            powerSupply.powerOut to mcu.powerIn;

        connection powerConnection2 connect 
            powerSupply.powerOut to tempSensor1.power;

        connection powerConnection3 connect 
            powerSupply.powerOut to tempSensor2.power;

        connection powerConnection4 connect 
            powerSupply.powerOut to heater.power;
    }

    requirement def SystemRequirement;

    requirement <'MCU-001'> primaryFunctionRequirement : SystemRequirement {
        doc /*
            The microcontroller system shall continuously monitor environmental 
            temperature through multiple sensors and automatically control a heating 
            element to maintain the temperature at a specified setpoint. The system 
            shall process sensor data at regular intervals, make control decisions 
            based on the measured temperature versus the setpoint, and execute 
            appropriate actuator commands while maintaining system health monitoring 
            and error handling capabilities.
        */

        subject temperatureControlSystem;

        require constraint performanceRequirement {
            temperatureControlSystem.mcu.clockSpeed >= 16.0
        }

        require constraint memoryRequirement {
            temperatureControlSystem.mcu.flashMemory >= 128.0 and
            temperatureControlSystem.mcu.ramMemory >= 32.0
        }

        require constraint powerRequirement {
            temperatureControlSystem.mcu.operatingVoltage >= 3.0 and
            temperatureControlSystem.mcu.operatingVoltage <= 3.6
        }

        require constraint samplingRequirement {
            temperatureControlSystem.mcu.operation.samplingInterval <= 200.0
        }
    }

    requirement <'MCU-002'> reliabilityRequirement : SystemRequirement {
        doc /*
            The system shall maintain operational reliability through continuous 
            health monitoring and graceful degradation in case of sensor failures 
            or communication errors.
        */

        assume constraint sensorAccuracy {
            temperatureControlSystem.tempSensor1.accuracy <= 1.0 and
            temperatureControlSystem.tempSensor2.accuracy <= 1.0
        }
    }
}

package MedicalFluidWarmingSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    value def TemperatureValue :> Real {
        doc "Fluid temperature in degrees Celsius."
        unit unit Celsius;
    }

    value def FlowRateValue :> Real {
        doc "Fluid flow rate in milliliters per minute."
        unit unit mL_per_min {
            definition mL_per_min :> 1 [mL/min];
        }
    }

    value def PowerValue :> Real {
        doc "Electrical power in watts."
        unit unit W;
    }

    value def VoltageValue :> Real {
        doc "Electrical voltage in volts."
        unit unit V;
    }

    value def CurrentValue :> Real {
        doc "Electrical current in amperes."
        unit unit A;
    }

    value def HeatingPowerValue :> Real {
        doc "Power delivered to the heating element in watts."
        unit unit W;
    }

    value def TemperatureToleranceValue :> Real {
        doc "Temperature tolerance in degrees Celsius."
        unit unit Celsius;
    }

    // ===== Item Definitions =====

    item def IVFluid {
        doc "Intravenous fluid such as saline, blood, or dextrose.";
        attribute fluidType : String;
        attribute currentTemperature : TemperatureValue;
    }

    item def WarmedFluid :> IVFluid {
        doc "IV fluid that has been warmed to physiological temperature.";
    }

    item def ColdFluid :> IVFluid {
        doc "IV fluid entering the warming system at ambient or storage temperature.";
    }

    // ===== Port Definitions =====

    port def FluidInPort {
        doc "Port for incoming cold IV fluid.";
        out item coldFluid : ColdFluid;
    }

    port def FluidOutPort {
        doc "Port for outgoing warmed IV fluid.";
        out item warmedFluid : WarmedFluid;
    }

    port def ElectricalPowerPort {
        doc "Port for electrical power supply.";
        in attribute voltage : VoltageValue;
        in attribute current : CurrentValue;
    }

    port def HeatingPowerPort {
        doc "Port for power delivered to the heating element.";
        in attribute power : HeatingPowerValue;
    }

    port def TemperatureSignalPort {
        doc "Port for temperature sensor signal output.";
        out attribute temperature : TemperatureValue;
    }

    port def FlowSignalPort {
        doc "Port for flow sensor signal output.";
        out attribute flowRate : FlowRateValue;
    }

    port def ControlSignalPort {
        doc "Port for control commands to the heating element.";
        out attribute commandedPower : HeatingPowerValue;
    }

    port def AlarmSignalPort {
        doc "Port for alarm activation signals.";
        out attribute alarmActive : Boolean;
        out attribute alarmReason : String;
    }

    port def DisplayDataPort {
        doc "Port for display data sent to the user interface.";
        out attribute displayedTemperature : TemperatureValue;
        out attribute displayedFlowRate : FlowRateValue;
        out attribute operatingMode : String;
        out attribute alarmStatus : Boolean;
    }

    port def UserCommandPort {
        doc "Port for user commands from the user interface.";
        out attribute powerOn : Boolean;
        out attribute powerOff : Boolean;
        out attribute startWarming : Boolean;
        out attribute stopWarming : Boolean;
        out attribute targetTemperature : TemperatureValue;
    }

    // ===== Part Definitions =====

    part def WarmingChamber {
        doc "Core chamber through which IV fluid flows and is heated.";
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        attribute chamberVolume : Real = 50.0;
        attribute heatTransferCoefficient : Real = 0.8;
        attribute internalTemperature : TemperatureValue;
    }

    part def HeatingElement {
        doc "Electrical heating element coupled to the warming chamber.";
        port powerInput : HeatingPowerPort;
        attribute maxPower : PowerValue = 200.0;
        attribute currentPower : HeatingPowerValue;
        attribute efficiency : Real = 0.95;
    }

    part def TemperatureSensor {
        doc "Measures the temperature of fluid leaving the warming chamber.";
        port signalOut : TemperatureSignalPort;
        attribute measuredTemperature : TemperatureValue;
        attribute accuracy : TemperatureToleranceValue = 0.1;
        attribute samplingRate : Real = 10.0;
    }

    part def FlowSensor {
        doc "Monitors the rate of IV fluid flow through the system.";
        port signalOut : FlowSignalPort;
        attribute measuredFlowRate : FlowRateValue;
        attribute minDetectableFlow : FlowRateValue = 1.0;
        attribute maxDetectableFlow : FlowRateValue = 500.0;
        attribute accuracy : Real = 0.05;
    }

    part def AlarmSystem {
        doc "Monitors fluid temperature and activates alarms on safety threshold violations.";
        port alarmOut : AlarmSignalPort;
        port tempInput : TemperatureSignalPort;
        attribute maxSafeTemperature : TemperatureValue = 39.0;
        attribute minSafeTemperature : TemperatureValue = 35.0;
        attribute alarmActive : Boolean = false;
        attribute alarmReason : String;
    }

    part def PowerSupply {
        doc "Standard electrical power supply for the device.";
        port powerOut : ElectricalPowerPort;
        attribute inputVoltage : VoltageValue = 120.0;
        attribute inputFrequency : Real = 60.0;
        attribute maxOutputPower : PowerValue = 250.0;
        attribute isOn : Boolean = false;
    }

    part def UserInterface {
        doc "Provides real-time information to medical staff and accepts user commands.";
        port displayInput : DisplayDataPort;
        port commandOutput : UserCommandPort;
        attribute displayType : String = "LCD";
        attribute hasTouchscreen : Boolean = true;
        attribute backlightEnabled : Boolean = true;
    }

    part def ControlUnit {
        doc "Central control unit managing the warming process, safety, and user interaction.";
        port tempFeedback : TemperatureSignalPort;
        port flowFeedback : FlowSignalPort;
        port heatingControl : ControlSignalPort;
        port alarmInput : AlarmSignalPort;
        port displayOutput : DisplayDataPort;
        port userCommandInput : UserCommandPort;
        port powerInput : ElectricalPowerPort;

        attribute targetTemperature : TemperatureValue = 37.0;
        attribute temperatureTolerance : TemperatureToleranceValue = 0.5;
        attribute proportionalGain : Real = 2.0;
        attribute integralGain : Real = 0.1;
        attribute derivativeGain : Real = 0.05;
        attribute commandedPower : HeatingPowerValue = 0.0;
        attribute currentMode : String = "off";

        // State machine for control unit behavior
        state machine ControlStateMachine {
            state off {
                entry action {
                    currentMode = "off";
                    commandedPower = 0.0;
                }
            }

            state standby {
                entry action {
                    currentMode = "standby";
                    commandedPower = 0.0;
                }
            }

            state warming {
                entry action {
                    currentMode = "warming";
                }
                do action {
                    // PID-like control logic
                    var tempError : TemperatureValue;
                    var flowFactor : Real;
                    tempError = targetTemperature - tempFeedback.temperature;
                    flowFactor = flowFeedback.flowRate / 100.0;
                    if tempError > 0.0 {
                        commandedPower = maxPower * (proportionalGain * tempError + integralGain * tempError) * flowFactor;
                        if commandedPower > 200.0 {
                            commandedPower = 200.0;
                        }
                        if commandedPower < 0.0 {
                            commandedPower = 0.0;
                        }
                    } else {
                        commandedPower = 0.0;
                    }
                }
            }

            state maintaining {
                entry action {
                    currentMode = "maintaining";
                }
                do action {
                    var tempError : TemperatureValue;
                    tempError = targetTemperature - tempFeedback.temperature;
                    if abs(tempError) > temperatureTolerance {
                        // Transition back to warming if drift exceeds tolerance
                    } else {
                        commandedPower = commandedPower * 0.5;
                    }
                }
            }

            state alarm {
                entry action {
                    currentMode = "alarm";
                    commandedPower = 0.0;
                }
            }

            transition off_to_standby
                first off
                accept userCommandInput.powerOn
                then standby;

            transition standby_to_off
                first standby
                accept userCommandInput.powerOff
                then off;

            transition standby_to_warming
                first standby
                accept userCommandInput.startWarming
                then warming;

            transition warming_to_maintaining
                first warming
                accept when (abs(tempFeedback.temperature - targetTemperature) <= temperatureTolerance)
                then maintaining;

            transition maintaining_to_warming
                first maintaining
                accept when (abs(tempFeedback.temperature - targetTemperature) > temperatureTolerance)
                then warming;

            transition warming_to_off
                first warming
                accept userCommandInput.stopWarming
                then standby;

            transition maintaining_to_off
                first maintaining
                accept userCommandInput.stopWarming
                then standby;

            transition any_to_alarm
                first {off, standby, warming, maintaining}
                accept alarmInput.alarmActive when alarmInput.alarmActive == true
                then alarm;

            transition alarm_to_standby
                first alarm
                accept when (alarmInput.alarmActive == false)
                then standby;
        }
    }

    // ===== Top-level System Part =====

    part def FluidWarmingSystem {
        doc "Medical fluid warming system for heating IV fluids to physiological temperature.";

        // Sub-parts
        part warmingChamber : WarmingChamber;
        part heatingElement : HeatingElement;
        part controlUnit : ControlUnit;
        part temperatureSensor : TemperatureSensor;
        part flowSensor : FlowSensor;
        part alarmSystem : AlarmSystem;
        part powerSupply : PowerSupply;
        part userInterface : UserInterface;

        // External ports
        port fluidInput : FluidInPort;
        port fluidOutput : FluidOutPort;
        port mainsPower : ElectricalPowerPort;

        // Connections
        connection fluidInToChamber connect fluidInput.coldFluid to warmingChamber.fluidIn.coldFluid;
        connection chamberToFluidOut connect warmingChamber.fluidOut.warmedFluid to fluidOutput.warmedFluid;

        connection powerToControl connect powerSupply.powerOut to controlUnit.powerInput;
        connection mainsToPower connect mainsPower to powerSupply.powerOut;

        connection tempSensorToControl connect temperatureSensor.signalOut to controlUnit.tempFeedback;
        connection tempSensorToAlarm connect temperatureSensor.signalOut to alarmSystem.tempInput;
        connection flowSensorToControl connect flowSensor.signalOut to controlUnit.flowFeedback;

        connection controlToHeater connect controlUnit.heatingControl to heatingElement.powerInput;
        connection heaterToChamber connect heatingElement to warmingChamber;

        connection alarmToControl connect alarmSystem.alarmOut to controlUnit.alarmInput;

        connection controlToDisplay connect controlUnit.displayOutput to userInterface.displayInput;
        connection uiToControl connect userInterface.commandOutput to controlUnit.userCommandInput;

        // System-level state machine
        state machine SystemStateMachine {
            state systemOff {
                entry action {
                    powerSupply.isOn = false;
                }
            }

            state systemStandby {
                entry action {
                    powerSupply.isOn = true;
                }
            }

            state systemWarming {
                entry action {
                    powerSupply.isOn = true;
                }
            }

            state systemMaintaining {
                entry action {
                    powerSupply.isOn = true;
                }
            }

            state systemAlarm {
                entry action {
                    powerSupply.isOn = true;
                }
            }

            transition offToStandby
                first systemOff
                accept userInterface.commandOutput.powerOn
                then systemStandby;

            transition standbyToOff
                first systemStandby
                accept userInterface.commandOutput.powerOff
                then systemOff;

            transition standbyToWarming
                first systemStandby
                accept userInterface.commandOutput.startWarming
                then systemWarming;

            transition warmingToMaintaining
                first systemWarming
                accept when (abs(temperatureSensor.measuredTemperature - controlUnit.targetTemperature) <= controlUnit.temperatureTolerance)
                then systemMaintaining;

            transition maintainingToWarming
                first systemMaintaining
                accept when (abs(temperatureSensor.measuredTemperature - controlUnit.targetTemperature) > controlUnit.temperatureTolerance)
                then systemWarming;

            transition warmingToStandby
                first systemWarming
                accept userInterface.commandOutput.stopWarming
                then systemStandby;

            transition maintainingToStandby
                first systemMaintaining
                accept userInterface.commandOutput.stopWarming
                then systemStandby;

            transition anyToAlarm
                first {systemOff, systemStandby, systemWarming, systemMaintaining}
                accept when (alarmSystem.alarmActive == true)
                then systemAlarm;

            transition alarmToStandby
                first systemAlarm
                accept when (alarmSystem.alarmActive == false)
                then systemStandby;
        }
    }

    // ===== Requirements =====

    requirement def TemperatureControlRequirement {
        doc "The system shall maintain fluid output temperature within ±0.5°C of the target temperature of 37°C.";
        attribute targetTemp : TemperatureValue = 37.0;
        attribute tolerance : TemperatureToleranceValue = 0.5;
        subject fluidWarmingSystem : FluidWarmingSystem;
        objective {
            assert fluidWarmingSystem.temperatureSensor.measuredTemperature >= (targetTemp - tolerance)
            and fluidWarmingSystem.temperatureSensor.measuredTemperature <= (targetTemp + tolerance);
        }
    }

    requirement def SafetyAlarmRequirement {
        doc "The system shall activate an alarm and stop heating if fluid temperature exceeds 39°C or drops below 35°C.";
        attribute maxSafeTemp : TemperatureValue = 39.0;
        attribute minSafeTemp : TemperatureValue = 35.0;
        subject fluidWarmingSystem : FluidWarmingSystem;
        objective {
            assert (if fluidWarmingSystem.temperatureSensor.measuredTemperature > maxSafeTemp
                    or fluidWarmingSystem.temperatureSensor.measuredTemperature < minSafeTemp
                then fluidWarmingSystem.alarmSystem.alarmActive == true
                    and fluidWarmingSystem.controlUnit.commandedPower == 0.0);
        }
    }

    requirement def FlowMonitoringRequirement {
        doc "The system shall monitor fluid flow rate and adjust heating power proportionally.";
        attribute minFlow : FlowRateValue = 1.0;
        attribute maxFlow : FlowRateValue = 500.0;
        subject fluidWarmingSystem : FluidWarmingSystem;
        objective {
            assert fluidWarmingSystem.flowSensor.measuredFlowRate >= minFlow
            and fluidWarmingSystem.flowSensor.measuredFlowRate <= maxFlow;
        }
    }

    requirement def DisplayRequirement {
        doc "The user interface shall display current fluid temperature, flow rate, and operating mode in real time.";
        subject fluidWarmingSystem : FluidWarmingSystem;
        objective {
            assert fluidWarmingSystem.userInterface.displayInput.displayedTemperature == fluidWarmingSystem.temperatureSensor.measuredTemperature
            and fluidWarmingSystem.userInterface.displayInput.displayedFlowRate == fluidWarmingSystem.flowSensor.measuredFlowRate;
        }
    }

    requirement def PowerSupplyRequirement {
        doc "The system shall operate from a standard electrical power supply.";
        attribute nominalVoltage : VoltageValue = 120.0;
        attribute maxPower : PowerValue = 250.0;
        subject fluidWarmingSystem : FluidWarmingSystem;
        objective {
            assert fluidWarmingSystem.powerSupply.inputVoltage == nominalVoltage
            and fluidWarmingSystem.powerSupply.maxOutputPower <= maxPower;
        }
    }

    requirement def OperatingStatesRequirement {
        doc "The system shall support five operating states: off, standby, warming, maintaining, and alarm.";
        subject fluidWarmingSystem : FluidWarmingSystem;
        objective {
            assert fluidWarmingSystem.controlUnit.currentMode in {"off", "standby", "warming", "maintaining", "alarm"};
        }
    }

    // ===== Requirement Satisfaction =====

    satisfaction satisfyTemperatureControl by FluidWarmingSystem satisfies TemperatureControlRequirement;
    satisfaction satisfySafetyAlarm by FluidWarmingSystem satisfies SafetyAlarmRequirement;
    satisfaction satisfyFlowMonitoring by FluidWarmingSystem satisfies FlowMonitoringRequirement;
    satisfaction satisfyDisplay by FluidWarmingSystem satisfies DisplayRequirement;
    satisfaction satisfyPowerSupply by FluidWarmingSystem satisfies PowerSupplyRequirement;
    satisfaction satisfyOperatingStates by FluidWarmingSystem satisfies OperatingStatesRequirement;

}

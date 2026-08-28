package ThermalManagementSystem {

    import ScalarValues::*;
    import ISQ::Thermodynamics::*;
    import ISQ::SpaceAndTime::*;

    // ---------- Value Types ----------

    value type TempSetpoint specializes TemperatureValue {
        unit cel;
    }

    value type TempReading specializes TemperatureValue {
        unit cel;
    }

    value type PowerValue specializes Real {
        unit 'W';
    }

    value type PercentValue specializes Real {
        unit '%';
    }

    value type FanSpeedValue specializes Integer {
        unit 'rpm';
    }

    value type PumpRateValue specializes Real {
        unit 'L/min';
    }

    attribute maxTempThreshold : TempSetpoint := 75.0 [cel];
    attribute criticalTempThreshold : TempSetpoint := 85.0 [cel];
    attribute nominalSetpoint : TempSetpoint := 65.0 [cel];

    // ---------- Item Definitions ----------

    item def TemperatureSample {
        attribute sensorId : Integer;
        attribute value : TempReading;
        attribute timestamp : TimeValue;
    }

    item def CoolingCommand {
        attribute fanSpeed : FanSpeedValue;
        attribute pumpRate : PumpRateValue;
        attribute powerLevel : PercentValue;
    }

    item def AlarmSignal {
        attribute active : Boolean;
        attribute severity : String;
        attribute message : String;
    }

    item def MonitoringStatus {
        attribute currentMode : String;
        attribute maxObservedTemp : TempReading;
        attribute powerConsumption : PowerValue;
        attribute alarmActive : Boolean;
        attribute currentSetpoint : TempSetpoint;
    }

    item def SetpointAdjustment {
        attribute newSetpoint : TempSetpoint;
    }

    // ---------- Port Definitions ----------

    port def SensorOutputPort {
        out samples : TemperatureSample;
    }

    port def ControllerSensorInputPort {
        in samples : TemperatureSample;
    }

    port def ControllerCommandOutputPort {
        out command : CoolingCommand;
    }

    port def CoolingCommandInputPort {
        in command : CoolingCommand;
    }

    port def CoolingAlarmPort {
        out alarm : AlarmSignal;
    }

    port def MonitoringPort {
        in setpointRequest : SetpointAdjustment;
        out status : MonitoringStatus;
    }

    // ---------- Temperature Sensor ----------

    part def TemperatureSensor {
        attribute sensorId : Integer;
        attribute samplingRate : TimeValue := 0.5 [s];
        attribute measurementRangeMin : TempReading := -20.0 [cel];
        attribute measurementRangeMax : TempReading := 120.0 [cel];

        port sensorOut : SensorOutputPort;

        attribute currentValue : TempReading;

        action def senseTemperature {
            in sensorRef : TemperatureSensor;
            out sample : TemperatureSample;
        }

        do senseTemperature {
            // continuously emits current measured temperature
            emit sensorOut.samples by sensorRef.sensorId;
        }

        compute currentValue = (measurementRangeMin + measurementRangeMax) / 2.0;

        statemachine SensorStates {
            entry action { sensorRef.currentValue = nominalSetpoint; }
            state Idle;
            state Sampling {
                entry action { sensorRef.currentValue = measure(sensorRef.sensorId); }
                do send TemperatureSample { sensorId = sensorRef.sensorId; value = sensorRef.currentValue; } 
                   via sensorOut;
            }
            transition Idle -> Sampling;
            transition Sampling -> Idle after sensorRef.samplingRate;
        }
    }

    // ---------- Thermal Controller ----------

    part def ThermalController {
        attribute controllerId : String = "CTRL-01";
        attribute targetSetpoint : TempSetpoint := nominalSetpoint;
        attribute proportionalGain : Real := 1.5;
        attribute integralGain : Real := 0.2;
        attribute derivativeGain : Real := 0.05;

        port sensorInputs : ControllerSensorInputPort[4];
        port commandOutput : ControllerCommandOutputPort;
        port alarmOutput : CoolingAlarmPort;
        port monitorPort : MonitoringPort;

        attribute latestReadings : TempReading[4];
        attribute maxObserved : TempReading;
        attribute currentPowerLevel : PercentValue;
        attribute currentMode : String;
        attribute alarmActive : Boolean;
        attribute powerConsumption : PowerValue;

        action def ProcessReadings {
            in readings : TempReading[4];
            out maxTemp : TempReading;
        }

        action def ComputeCommand {
            in setpoint : TempSetpoint;
            in maxTemp : TempReading;
            out cmd : CoolingCommand;
        }

        do {
            // process incoming readings continuously
            accept sensorInputs.samples;
            // compute command based on readings
            // emit command on commandOutput
            // update monitoring status
        }

        compute maxObserved = max(latestReadings);

        statemachine ControllerModeStateMachine {
            state Standby {
                entry action { currentMode = "Standby"; currentPowerLevel = 0.0 [%]; 
                              powerConsumption = 5.0 ['W']; }
                do emit CoolingCommand { fanSpeed = 0 [rpm]; pumpRate = 0.0 [L/min]; powerLevel = 0.0 [%]; }
                   via commandOutput;
            }
            state Active {
                entry action { currentMode = "Active"; }
                do {
                    var errorVal : Real;
                    errorVal = (maxObserved - targetSetpoint) / 1.0 [cel];
                    currentPowerLevel = min(100.0 [%], max(10.0 [%], errorVal * proportionalGain * 1.0 [%]));
                    powerConsumption = 50.0 + currentPowerLevel.value * 1.5 ['W'];
                    emit CoolingCommand { 
                        fanSpeed = (currentPowerLevel.value * 30) [rpm]; 
                        pumpRate = (currentPowerLevel.value * 0.4) [L/min]; 
                        powerLevel = currentPowerLevel 
                    } via commandOutput;
                }
            }
            state Critical {
                entry action { currentMode = "Critical"; alarmActive = true; 
                              currentPowerLevel = 100.0 [%]; powerConsumption = 200.0 ['W']; }
                do {
                    emit CoolingCommand { fanSpeed = 3000 [rpm]; pumpRate = 40.0 [L/min]; powerLevel = 100.0 [%]; }
                       via commandOutput;
                    emit AlarmSignal { active = true; severity = "High"; message = "Critical temperature exceeded"; }
                       via alarmOutput;
                }
            }

            transition Standby -> Active 
                guard maxObserved > targetSetpoint;
            transition Active -> Standby 
                guard maxObserved < (targetSetpoint - 2.0 [cel]);
            transition Active -> Critical 
                guard maxObserved >= criticalTempThreshold;
            transition Critical -> Active 
                guard maxObserved < (criticalTempThreshold - 3.0 [cel]);
            transition Standby -> Critical 
                guard maxObserved >= criticalTempThreshold;

            // handle setpoint adjustment from monitoring port
            transition then Standby -> Standby 
                guard monitorPort.setpointRequest.newSetpoint != targetSetpoint 
                effect { targetSetpoint = monitorPort.setpointRequest.newSetpoint; };
        }
    }

    // ---------- Cooling Unit ----------

    part def CoolingUnit {
        attribute unitId : String = "COOL-01";
        attribute maxPower : PowerValue := 500.0 ['W'];
        attribute maxFanSpeed : FanSpeedValue := 3000 [rpm];
        attribute maxPumpRate : PumpRateValue := 40.0 [L/min];
        attribute currentFanSpeed : FanSpeedValue;
        attribute currentPumpRate : PumpRateValue;
        attribute currentPowerDraw : PowerValue;

        port commandInput : CoolingCommandInputPort;

        do {
            accept commandInput.command;
            currentFanSpeed = commandInput.command.fanSpeed;
            currentPumpRate = commandInput.command.pumpRate;
            currentPowerDraw = (commandInput.command.powerLevel.value / 100.0) * maxPower;
        }

        statemachine CoolingUnitStates {
            state Off {
                entry action { currentFanSpeed = 0 [rpm]; currentPumpRate = 0.0 [L/min]; currentPowerDraw = 0.0 ['W']; }
            }
            state Running {
                do {
                    // apply received commands to physical hardware
                }
            }
            transition Off -> Running 
                guard commandInput.command.powerLevel > 0.0 [%]
                effect { currentFanSpeed = commandInput.command.fanSpeed; };
            transition Running -> Off 
                guard commandInput.command.powerLevel == 0.0 [%];
            transition Running -> Running 
                effect { currentFanSpeed = commandInput.command.fanSpeed; currentPumpRate = commandInput.command.pumpRate; };
        }
    }

    // ---------- Thermal Management System (Assembly) ----------

    part thermalManagementSystem {
        attribute systemId : String = "TMS-001";
        attribute operationalMode : String;
        attribute systemPowerConsumption : PowerValue;

        port externalMonitoring : MonitoringPort;
        port systemAlarmPort : CoolingAlarmPort;

        part sensors : TemperatureSensor[4] {
            part sensor1 : TemperatureUnit { sensorId = 1; }
            part sensor2 : TemperatureUnit { sensorId = 2; }
            part sensor3 : TemperatureUnit { sensorId = 3; }
            part sensor4 : TemperatureUnit { sensorId = 4; }
        }

        part controller : ThermalController {
            // controller configuration
        }

        part coolingUnit : CoolingUnit {
            // cooling unit configuration
        }

        // Connections between parts
        connection sensor1.sensorOut to controller.sensorInputs[1];
        connection sensor2.sensorOut to controller.sensorInputs[2];
        connection sensor3.sensorOut to controller.sensorInputs[3];
        connection sensor4.sensorOut to controller.sensorInputs[4];
        connection controller.commandOutput to coolingUnit.commandInput;
        connection controller.alarmOutput to systemAlarmPort;
        connection externalMonitoring to controller.monitorPort;

        // System-level state machine
        statemachine SystemOperationModes {
            state Initializing {
                entry action { operationalMode = "Initializing"; }
            }
            state Operational {
                entry action { operationalMode = "Operational"; }
            }
            state Faulted {
                entry action { operationalMode = "Faulted"; }
            }
            state Maintenance {
                entry action { operationalMode = "Maintenance"; }
            }
            transition Initializing -> Operational 
                after 2.0 [s];
            transition Operational -> Faulted 
                guard systemAlarmPort.alarm.active == true;
            transition Faulted -> Operational 
                guard systemAlarmPort.alarm.active == false 
                effect { operationalMode = "Operational"; };
            transition Operational -> Maintenance 
                guard externalMonitoring.setpointRequest.newSetpoint.value < 0.0 [cel];
            transition Maintenance -> Operational 
                guard externalMonitoring.setpointRequest.newSetpoint.value > 0.0 [cel];
        }

        compute systemPowerConsumption = controller.powerConsumption + coolingUnit.currentPowerDraw;
    }

    // ---------- Requirements ----------

    requirement def TemperatureMonitoringRequirement {
        doc 
        /* The system shall continuously monitor temperature using four sensors 
           distributed at critical equipment locations. */;
        subject tms : thermalManagementSystem;
        requirement 
            rm1: The system shall include four TemperatureSensor parts.
        requirement 
            rm2: Each sensor shall provide TemperatureSample data at least every 0.5 [s].
        requirement 
            rm3: Sensors shall measure temperatures from -20 [cel] to 120 [cel].
    }

    requirement def ControlProcessingRequirement {
        doc 
        /* The controller shall compare readings against a setpoint and generate 
           proportional cooling commands. */;
        subject controller : ThermalController;
        requirement 
            rc1: The controller shall accept four TemperatureSample inputs.
        requirement 
            rc2: The controller shall compute the maximum observed temperature.
        requirement 
            rc3: The controller shall emit CoolingCommand on its commandOutput port.
        requirement 
            rc4: The controller shall enter Critical mode when maxObserved >= 85.0 [cel].
    }

    requirement def CoolingUnitRequirement {
        doc 
        /* The cooling unit shall execute received cooling commands to remove heat 
           from the equipment. */;
        subject cooling : CoolingUnit;
        requirement 
            ru1: The cooling unit shall accept CoolingCommand via commandInput.
        requirement 
            ru2: The cooling unit shall support fan speeds up to 3000 [rpm].
        requirement 
            ru3: The cooling unit shall support pump rates up to 40.0 [L/min].
        requirement 
            ru4: The cooling unit shall draw power proportional to commanded powerLevel.
    }

    requirement def MonitoringInterfaceRequirement {
        doc 
        /* The system shall expose a monitoring port for status, power, alarms, 
           and setpoint adjustment. */;
        subject tms : thermalManagementSystem;
        requirement 
            rm4: The system shall expose a MonitoringPort.
        requirement 
            rm5: The MonitoringPort shall provide MonitoringStatus with currentMode, 
                 maxObservedTemp, powerConsumption, and alarmActive.
        requirement 
            rm6: The MonitoringPort shall accept SetpointAdjustment commands.
    }

    requirement def OperationalModesRequirement {
        doc 
        /* The system shall operate in Standby, Active, and Critical modes 
           depending on observed temperature. */;
        subject tms : thermalManagementSystem;
        requirement 
            ro1: In Standby mode, the system shall command cooling at or below 10 [%] power.
        requirement 
            ro2: In Active mode, the system shall proportionally increase cooling 
                 based on (maxObserved - setpoint).
        requirement 
            ro3: In Critical mode, the system shall command maximum cooling capacity 
                 and emit an AlarmSignal.
    }

    // ---------- Requirement Satisfaction ----------

    satisfaction rm1 by thermalManagementSystem.sensors;
    satisfaction rm2 by TemperatureSensor.samplingRate;
    satisfaction rm3 by TemperatureSensor.measurementRangeMin;
    satisfaction rc1 by ThermalController.sensorInputs;
    satisfaction rc2 by ThermalController.maxObserved;
    satisfaction rc3 by ThermalController.commandOutput;
    satisfaction rc4 by ThermalController.ControllerModeStateMachine.Critical;
    satisfaction ru1 by CoolingUnit.commandInput;
    satisfaction ru2 by CoolingUnit.maxFanSpeed;
    satisfaction ru3 by CoolingUnit.maxPumpRate;
    satisfaction rm4 by thermalManagementSystem.externalMonitoring;
    satisfaction rm5 by MonitoringStatus;
    satisfaction rm6 by MonitoringPort.setpointRequest;
    satisfaction ro1 by ThermalController.ControllerModeStateMachine.Standby;
    satisfaction ro2 by ThermalController.ControllerModeStateMachine.Active;
    satisfaction ro3 by ThermalController.ControllerModeStateMachine.Critical;

} // end package ThermalManagementSystem

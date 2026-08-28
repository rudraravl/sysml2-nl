package IndustrialAutomationSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def PressureValue :> Real {
        unit :> ISQ::Pressure { }
    }
    value def TemperatureValue :> Real {
        unit :> ISQ::ThermodynamicTemperature { }
    }
    value def FlowRateValue :> Real {
        unit :> ISQ::VolumeFlowRate { }
    }
    value def MotorSpeedValue :> Real {
        unit :> ISQ::AngularVelocity { }
    }
    value def PercentValue :> Real {
        unit :> One { }
    }

    // ===== Item Types =====
    item def ChemicalFeed;
    item def ChemicalProduct;
    item def CoolingMedium;
    item def SensorReading {
        attribute value : Real;
        attribute timestamp : DateTime;
    }
    item def ControlCommand {
        attribute commandId : String;
        attribute value : Real;
    }
    item def AlarmMessage {
        attribute severity : String;
        attribute description : String;
        attribute timestamp : DateTime;
    }
    item def ProcessStatus {
        attribute reactorState : String;
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute valvePosition : PercentValue;
        attribute motorSpeed : MotorSpeedValue;
    }

    // ===== Port Definitions =====
    port def PressureReadingPort {
        out reading : SensorReading;
    }
    port def TemperatureReadingPort {
        out reading : SensorReading;
    }
    port def ControlCommandPort {
        in command : ControlCommand;
    }
    port def StatusOutputPort {
        out status : ProcessStatus;
    }
    port def AlarmPort {
        out alarm : AlarmMessage;
    }
    port def MaterialFlowPort {
        in feed : ChemicalFeed;
        out product : ChemicalProduct;
    }
    port def CoolingPort {
        in coolant : CoolingMedium;
    }
    port def MotorDrivePort {
        out speed : MotorSpeedValue;
    }
    port def ValveControlPort {
        out position : PercentValue;
    }
    port def HMICommandPort {
        out command : ControlCommand;
    }
    port def HMIDisplayPort {
        in status : ProcessStatus;
        in alarm : AlarmMessage;
    }

    // ===== Requirements =====
    requirement def SafeOperationRequirement {
        doc << "The system shall maintain reactor temperature and pressure within safe limits.">>
        attribute maxTemperature : TemperatureValue = 150 [K];
        attribute minTemperature : TemperatureValue = 273.15 [K];
        attribute maxPressure : PressureValue = 1000000 [Pa];
        attribute minPressure : PressureValue = 0 [Pa];
        require constraint {
            (reactorTemperature >= minTemperature) and (reactorTemperature <= maxTemperature) and
            (reactorPressure >= minPressure) and (reactorPressure <= maxPressure)
        }
    }
    requirement def MonitoringRequirement {
        doc << "The system shall continuously monitor reactor temperature and pressure.">>
        require constraint { samplingInterval <= 1 [s] }
        attribute samplingInterval : Real = 0.5;
    }
    requirement def AlarmRequirement {
        doc << "The system shall generate an alarm on the HMI when conditions exceed safe limits.">>
        require constraint { alarmLatency <= 2 [s] }
        attribute alarmLatency : Real = 1.0;
    }
    requirement def ProductionCycleRequirement {
        doc << "The reactor shall execute a production cycle consisting of filling, heating, reacting, cooling, and draining.">>
    }

    // ===== Part Definitions =====

    part def PressureSensor {
        attribute sensorId : String;
        attribute minRange : PressureValue = 0 [Pa];
        attribute maxRange : PressureValue = 2000000 [Pa];
        attribute accuracy : PercentValue = 0.01;
        port pressureOut : PressureReadingPort;
        attribute currentReading : PressureValue;
        action def sensePressure {
            in reactorPressure : PressureValue;
            out reading : SensorReading;
        }
    }

    part def TemperatureSensor {
        attribute sensorId : String;
        attribute minRange : TemperatureValue = 223.15 [K];
        attribute maxRange : TemperatureValue = 573.15 [K];
        attribute accuracy : PercentValue = 0.005;
        port tempOut : TemperatureReadingPort;
        attribute currentReading : TemperatureValue;
        action def senseTemperature {
            in reactorTemp : TemperatureValue;
            out reading : SensorReading;
        }
    }

    part def ControlValve {
        attribute valveId : String;
        attribute currentPosition : PercentValue = 0;
        attribute maxFlowRate : FlowRateValue = 0.01 [m^3/s];
        port cmdIn : ControlCommandPort;
        port flowPort : MaterialFlowPort;
        action def adjustPosition {
            in targetPosition : PercentValue;
            then updateFlow;
        }
        action def updateFlow {
            in position : PercentValue;
            out flowRate : FlowRateValue;
        }
    }

    part def ConveyorMotor {
        attribute motorId : String;
        attribute currentSpeed : MotorSpeedValue = 0 [rad/s];
        attribute maxSpeed : MotorSpeedValue = 157.08 [rad/s];
        attribute ratedPower : Real = 1500 [W];
        port cmdIn : ControlCommandPort;
        port driveOut : MotorDrivePort;
        action def setSpeed {
            in targetSpeed : MotorSpeedValue;
            out actualSpeed : MotorSpeedValue;
        }
    }

    part def ProcessReactor {
        attribute reactorId : String;
        attribute volume : Real = 5 [m^3];
        attribute currentTemperature : TemperatureValue = 293.15 [K];
        attribute currentPressure : PressureValue = 101325 [Pa];
        attribute setpointTemperature : TemperatureValue = 353.15 [K];
        attribute setpointPressure : PressureValue = 200000 [Pa];
        attribute fillLevel : PercentValue = 0;
        port materialPort : MaterialFlowPort;
        port coolingPort : CoolingPort;
        port pressureSensorPort : PressureReadingPort;
        port tempSensorPort : TemperatureReadingPort;
        port valveCmdPort : ControlCommandPort;
        port motorCmdPort : ControlCommandPort;

        state machine def ReactorProductionCycle {
            entry; then Filling;
            state Filling {
                entry { fillLevel := 0; }
                do { fillLevel := fillLevel + 0.1; }
                transition to Heating
                    when fillLevel >= 1.0;
            }
            state Heating {
                entry { currentTemperature := currentTemperature; }
                do { currentTemperature := currentTemperature + 0.5 [K]; }
                transition to Reacting
                    when currentTemperature >= setpointTemperature;
            }
            state Reacting {
                entry { /* reaction initiated */ }
                do { currentPressure := currentPressure + 100 [Pa]; }
                transition to Cooling
                    when currentPressure >= setpointPressure;
            }
            state Cooling {
                entry { /* cooling initiated */ }
                do { currentTemperature := currentTemperature - 0.3 [K]; }
                transition to Draining
                    when currentTemperature <= 303.15 [K];
            }
            state Draining {
                entry { /* draining initiated */ }
                do { fillLevel := fillLevel - 0.1; }
                transition to Filling
                    when fillLevel <= 0.0;
            }
        }
    }

    part def PLC {
        attribute plcId : String;
        attribute firmwareVersion : String = "2.4.1";
        attribute temperatureSetpoint : TemperatureValue = 353.15 [K];
        attribute pressureSetpoint : PressureValue = 200000 [Pa];
        attribute valvePosition : PercentValue = 0;
        attribute motorSpeed : MotorSpeedValue = 0 [rad/s];
        attribute alarmActive : Boolean = false;
        attribute safeMaxTemp : TemperatureValue = 423.15 [K];
        attribute safeMaxPressure : PressureValue = 500000 [Pa];

        port pressureIn : PressureReadingPort;
        port tempIn : TemperatureReadingPort;
        port valveCmdOut : ControlCommandPort;
        port motorCmdOut : ControlCommandPort;
        port statusOut : StatusOutputPort;
        port alarmOut : AlarmPort;
        port hmiCmdIn : HMICommandPort;

        action def ProcessSensorData {
            in pressureReading : SensorReading;
            in tempReading : SensorReading;
            out valveCommand : ControlCommand;
            out motorCommand : ControlCommand;
            out status : ProcessStatus;
            out alarm : AlarmMessage;
        }

        state machine def PLCOperationalStates {
            entry; then Startup;
            state Startup {
                entry { /* initialize I/O, load configuration */ }
                do { /* self-test routines */ }
                transition to Running
                    when selfTestComplete;
            }
            state Running {
                entry { /* begin control loop */ }
                do { /* execute PID control */ }
                transition to Fault
                    when faultDetected;
                transition to Maintenance
                    when maintenanceRequested;
            }
            state Fault {
                entry { alarmActive := true; }
                do { /* log fault, safe shutdown */ }
                transition to Startup
                    when faultCleared;
            }
            state Maintenance {
                entry { /* enter maintenance mode */ }
                do { /* allow manual overrides */ }
                transition to Startup
                    when maintenanceComplete;
            }
        }
    }

    part def HMI {
        attribute hmiId : String;
        attribute displayWidth : Integer = 1024;
        attribute displayHeight : Integer = 768;
        attribute touchEnabled : Boolean = true;
        attribute currentDisplay : ProcessStatus;
        attribute activeAlarms : AlarmMessage[0..*];

        port displayIn : HMIDisplayPort;
        port cmdOut : HMICommandPort;

        action def updateDisplay {
            in status : ProcessStatus;
            in alarm : AlarmMessage;
        }
        action def handleOperatorInput {
            in touchEvent : String;
            out command : ControlCommand;
        }
    }

    // ===== System Assembly =====
    part def AutomationSystem {
        satisfy SafeOperationRequirement;
        satisfy MonitoringRequirement;
        satisfy AlarmRequirement;
        satisfy ProductionCycleRequirement;

        part reactor : ProcessReactor {
            attribute reactorId = "R-101";
        }
        part pressureSensor : PressureSensor {
            attribute sensorId = "PT-101";
        }
        part temperatureSensor : TemperatureSensor {
            attribute sensorId = "TT-101";
        }
        part plc : PLC {
            attribute plcId = "PLC-001";
        }
        part controlValve : ControlValve {
            attribute valveId = "CV-101";
        }
        part conveyorMotor : ConveyorMotor {
            attribute motorId = "M-101";
        }
        part hmi : HMI {
            attribute hmiId = "HMI-001";
        }

        // Connections
        connection pressureSensorToReactor connect pressureSensor.pressureOut to reactor.pressureSensorPort;
        connection tempSensorToReactor connect temperatureSensor.tempOut to reactor.tempSensorPort;
        connection pressureSensorToPLC connect pressureSensor.pressureOut to plc.pressureIn;
        connection tempSensorToPLC connect temperatureSensor.tempOut to plc.tempIn;
        connection plcToValve connect plc.valveCmdOut to controlValve.cmdIn;
        connection plcToMotor connect plc.motorCmdOut to conveyorMotor.cmdIn;
        connection valveToReactor connect controlValve.flowPort to reactor.materialPort;
        connection motorToValve connect conveyorMotor.driveOut to controlValve.flowPort;
        connection plcToHMIStatus connect plc.statusOut to hmi.displayIn;
        connection plcToHMIAlarm connect plc.alarmOut to hmi.displayIn;
        connection hmiToPLC connect hmi.cmdOut to plc.hmiCmdIn;
        connection reactorToPLCStatus connect reactor.valveCmdPort to plc.hmiCmdIn;

        // Allocate behaviors
        perform reactor.ReactorProductionCycle;
        perform plc.PLCOperationalStates;
    }
}

package RotationalViscometer {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    value def DynamicViscosity :> Real {
        unit 'Pa·s';
    }
    value def Torque :> Real {
        unit 'N·m';
    }
    value def AngularVelocity :> Real {
        unit 'rad/s';
    }
    value def RotationalSpeed :> Real {
        unit 'rpm';
    }
    value def Temperature :> Real {
        unit '°C';
    }
    value def SpindleConstant :> Real {
        unit '1';
    }
    value def Power :> Real {
        unit 'W';
    }
    value def TimeStamp :> Real {
        unit 's';
    }

    // ===== Item Definitions =====

    item def FluidSample;
    item def TorqueReading {
        value torque : Torque;
        value timestamp : TimeStamp;
    }
    item def TemperatureReading {
        value temperature : Temperature;
        value timestamp : TimeStamp;
    }
    item def SpeedReading {
        value speed : RotationalSpeed;
        value timestamp : TimeStamp;
    }
    item def ViscosityResult {
        value viscosity : DynamicViscosity;
        value temperature : Temperature;
        value timestamp : TimeStamp;
    }
    item def MeasurementRecord {
        value result : ViscosityResult;
        value spindleId : String;
        value speed : RotationalSpeed;
    }
    item def UserCommand {
        attribute commandType : String;
        attribute targetSpeed : RotationalSpeed;
        attribute targetTemperature : Temperature;
    }

    // ===== Port Definitions =====

    port def FluidInterface;
    port def TorqueSignalOut {
        out torqueReading : TorqueReading;
    }
    port def TemperatureSignalOut {
        out temperatureReading : TemperatureReading;
    }
    port def SpeedSignalOut {
        out speedReading : SpeedReading;
    }
    port def ControlSignalIn {
        in command : UserCommand;
    }
    port def HeatingControlPort {
        out heatingPower : Power;
    }
    port def MotorDrivePort {
        out targetSpeed : RotationalSpeed;
        in actualSpeed : SpeedReading;
    }
    port def DisplayPort {
        in result : ViscosityResult;
    }
    port def LoggingPort {
        in record : MeasurementRecord;
    }
    port def SpindleDrivePort {
        in driveSpeed : RotationalSpeed;
        out torqueReaction : TorqueReading;
    }

    // ===== Part Definitions =====

    part def Spindle {
        attribute spindleId : String;
        attribute spindleConstant : SpindleConstant;
        port fluidInterface : FluidInterface;
        port drivePort : SpindleDrivePort;
        attribute currentSpeed : RotationalSpeed;
    }

    part def PrecisionMotor {
        port drivePort : MotorDrivePort;
        attribute nominalSpeed : RotationalSpeed;
        attribute actualSpeed : RotationalSpeed;
    }

    part def TorqueSensor {
        port signalOut : TorqueSignalOut;
        attribute calibrationFactor : Real;
    }

    part def TemperatureSensor {
        port signalOut : TemperatureSignalOut;
        attribute calibrationOffset : Temperature;
    }

    part def HeatingElement {
        port controlPort : HeatingControlPort;
        attribute maxPower : Power;
        attribute currentPower : Power;
    }

    part def TemperatureController {
        port heatingControl : HeatingControlPort;
        port temperatureInput : TemperatureSignalOut;
        attribute setpoint : Temperature;
        attribute proportionalGain : Real;
        attribute integralGain : Real;
    }

    part def SampleChamber {
        port fluidInterface : FluidInterface;
        attribute volume : Real;
        attribute currentTemperature : Temperature;
    }

    part def CentralProcessingUnit {
        port torqueInput : TorqueSignalOut;
        port speedInput : SpeedSignalOut;
        port temperatureInput : TemperatureSignalOut;
        port motorControl : MotorDrivePort;
        port displayOutput : DisplayPort;
        port loggingOutput : LoggingPort;
        port userCommandInput : ControlSignalIn;
        attribute spindleConstant : SpindleConstant;
        attribute calculatedViscosity : DynamicViscosity;
    }

    part def DisplayUnit {
        port displayInput : DisplayPort;
        attribute lastResult : ViscosityResult;
    }

    part def DataLogger {
        port loggingInput : LoggingPort;
        attribute records : MeasurementRecord[0..*];
    }

    part def UserInterface {
        port commandOutput : ControlSignalIn;
        attribute targetSpeed : RotationalSpeed;
        attribute targetTemperature : Temperature;
    }

    // ===== The Rotational Viscometer System =====

    part def RotationalViscometerSystem {

        port userPort : ControlSignalIn;
        port displayOut : DisplayPort;

        part spindle : Spindle {
            attribute spindleId = "SP-01";
            attribute spindleConstant = 0.1;
        }
        part motor : PrecisionMotor {
            attribute nominalSpeed = 100.0;
        }
        part torqueSensor : TorqueSensor {
            attribute calibrationFactor = 1.0;
        }
        part temperatureSensor : TemperatureSensor {
            attribute calibrationOffset = 0.0;
        }
        part heatingElement : HeatingElement {
            attribute maxPower = 200.0;
        }
        part temperatureController : TemperatureController {
            attribute proportionalGain = 2.0;
            attribute integralGain = 0.5;
        }
        part sampleChamber : SampleChamber {
            attribute volume = 0.0005;
        }
        part cpu : CentralProcessingUnit {
            attribute spindleConstant = 0.1;
        }
        part display : DisplayUnit;
        part dataLogger : DataLogger;
        part userInterface : UserInterface {
            attribute targetSpeed = 60.0;
            attribute targetTemperature = 25.0;
        }

        // Connections
        connection motorToSpindle connect motor.drivePort to spindle.drivePort;
        connection spindleToTorqueSensor connect spindle.drivePort.torqueReaction to torqueSensor.signalOut.torqueReading;
        connection torqueSensorToCPU connect torqueSensor.signalOut to cpu.torqueInput;
        connection motorToCPU connect motor.drivePort.actualSpeed to cpu.speedInput.speedReading;
        connection tempSensorToCPU connect temperatureSensor.signalOut to cpu.temperatureInput;
        connection tempSensorToController connect temperatureSensor.signalOut to temperatureController.temperatureInput;
        connection controllerToHeater connect temperatureController.heatingControl to heatingElement.controlPort;
        connection cpuToMotor connect cpu.motorControl to motor.drivePort;
        connection cpuToDisplay connect cpu.displayOutput to display.displayInput;
        connection cpuToLogger connect cpu.loggingOutput to dataLogger.loggingInput;
        connection userToCPU connect userInterface.commandOutput to cpu.userCommandInput;
        connection userToSystem connect userPort to userInterface.commandOutput;
        connection displayToSystem connect cpu.displayOutput to displayOut;
        connection spindleFluid connect spindle.fluidInterface to sampleChamber.fluidInterface;

        // ===== State Machine for Measurement Sequence =====

        state def MeasurementStateMachine;

        state measurementBehavior : MeasurementStateMachine {
            entry action initialize {
                cpu.calculatedViscosity := 0.0;
            }

            state Idle;
            state LoadingSample;
            state StabilizingTemperature;
            state PerformingMeasurement;
            state CalculatingResult;
            state ReportingAndLogging;
            state UnloadingSample;

            transition idleToLoading first Idle then LoadingSample
                when userPort.command.commandType == "START";
            transition loadingToStabilizing first LoadingSample then StabilizingTemperature
                when sampleChamber.fluidInterface @ FluidSample;
            transition stabilizingToMeasuring first StabilizingTemperature then PerformingMeasurement
                when abs(temperatureSensor.signalOut.temperatureReading.temperature - temperatureController.setpoint) < 0.5;
            transition measuringToCalculating first PerformingMeasurement then CalculatingResult
                when torqueSensor.signalOut.torqueReading.timestamp > 10.0;
            transition calculatingToReporting first CalculatingResult then ReportingAndLogging
                when cpu.calculatedViscosity > 0.0;
            transition reportingToUnloading first ReportingAndLogging then UnloadingSample
                when dataLogger.loggingInput @ MeasurementRecord;
            transition unloadingToIdle first UnloadingSample then Idle
                when !sampleChamber.fluidInterface @ FluidSample;

            // Actions within states
            action LoadingSample.do {
                // User places fluid sample into chamber
            }
            action StabilizingTemperature.do {
                // Temperature controller regulates heating element
                temperatureController.setpoint := userInterface.targetTemperature;
            }
            action PerformingMeasurement.do {
                // Motor drives spindle at target speed, torque sensor measures resistance
                motor.actualSpeed := userInterface.targetSpeed;
                cpu.calculatedViscosity := (torqueSensor.signalOut.torqueReading.torque * cpu.spindleConstant) / motor.actualSpeed;
            }
            action CalculatingResult.do {
                // CPU computes dynamic viscosity using calibrated spindle constant
                cpu.calculatedViscosity := (torqueSensor.signalOut.torqueReading.torque * cpu.spindleConstant) / motor.actualSpeed;
            }
            action ReportingAndLogging.do {
                // Display result and log measurement record
                display.lastResult.viscosity := cpu.calculatedViscosity;
                display.lastResult.temperature := temperatureSensor.signalOut.temperatureReading.temperature;
                dataLogger.records := dataLogger.records.append(MeasurementRecord {
                    result = display.lastResult,
                    spindleId = spindle.spindleId,
                    speed = motor.actualSpeed
                });
            }
            action UnloadingSample.do {
                // User removes fluid sample from chamber
            }
        }
    }

    // ===== Requirements =====

    requirement def ViscosityMeasurementRequirement {
        subject viscometer : RotationalViscometerSystem;
        objective {
            doc "The viscometer shall measure the dynamic viscosity of a fluid sample with high precision."
        }
        requirement {
            subject viscometer;
            requirement viscometer.cpu.calculatedViscosity >= 0.0;
        }
    }

    requirement def TemperatureStabilityRequirement {
        subject viscometer : RotationalViscometerSystem;
        objective {
            doc "The temperature control system shall maintain the sample temperature within ±0.5°C of the setpoint."
        }
        requirement {
            subject viscometer;
            requirement abs(viscometer.temperatureSensor.signalOut.temperatureReading.temperature - viscometer.temperatureController.setpoint) <= 0.5;
        }
    }

    requirement def TorqueMeasurementRequirement {
        subject viscometer : RotationalViscometerSystem;
        objective {
            doc "The torque sensor shall detect the rotational resistance of the spindle in the fluid."
        }
        requirement {
            subject viscometer;
            requirement viscometer.torqueSensor.signalOut.torqueReading.torque >= 0.0;
        }
    }

    requirement def DataLoggingRequirement {
        subject viscometer : RotationalViscometerSystem;
        objective {
            doc "The data logger shall record viscosity, temperature, spindle ID, and speed for each measurement."
        }
        requirement {
            subject viscometer;
            requirement viscometer.dataLogger.records->size() >= 1;
        }
    }

    requirement def MeasurementSequenceRequirement {
        subject viscometer : RotationalViscometerSystem;
        objective {
            doc "The measurement process shall follow the sequence: load sample, stabilize temperature, perform measurement, calculate result, report and log, then unload."
        }
    }

    requirement ViscometerFunctionalRequirement : ViscosityMeasurementRequirement {
        subject viscometer : RotationalViscometerSystem;
    }
    requirement ViscometerTempStability : TemperatureStabilityRequirement {
        subject viscometer : RotationalViscometerSystem;
    }
    requirement ViscometerTorqueSensing : TorqueMeasurementRequirement {
        subject viscometer : RotationalViscometerSystem;
    }
    requirement ViscometerDataLogging : DataLoggingRequirement {
        subject viscometer : RotationalViscometerSystem;
    }
    requirement ViscometerSequence : MeasurementSequenceRequirement {
        subject viscometer : RotationalViscometerSystem;
    }

    // ===== Satisfaction =====

    satisfaction ViscometerFunctionalRequirement by RotationalViscometerSystem.measurementBehavior;
    satisfaction ViscometerTempStability by RotationalViscometerSystem.temperatureController;
    satisfaction ViscometerTorqueSensing by RotationalViscometerSystem.torqueSensor;
    satisfaction ViscometerDataLogging by RotationalViscometerSystem.dataLogger;
    satisfaction ViscometerSequence by RotationalViscometerSystem.measurementBehavior;

}

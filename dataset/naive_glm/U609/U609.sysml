package DigitalBarometer {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQThermodynamics::*;

    // ---------- Value Types ----------
    value def PressureUnit :> Real { unit Pa; }
    value def TemperatureUnit :> Real { unit K; }
    value def AltitudeUnit :> Real { unit m; }
    value def VoltageUnit :> Real { unit V; }
    value def PowerUnit :> Real { unit W; }
    value def PercentUnit :> Real { unit '%'; }

    value def PressureValue :> Real {
        :>> unit = PressureUnit::Pa;
    }
    value def TemperatureValue :> Real {
        :>> unit = TemperatureUnit::K;
    }
    value def AltitudeValue :> Real {
        :>> unit = AltitudeUnit::m;
    }
    value def VoltageValue :> Real {
        :>> unit = VoltageUnit::V;
    }
    value def PowerValue :> Real {
        :>> unit = PowerUnit::W;
    }
    value def BatteryLevel :> Real {
        :>> unit = PercentUnit::'%';
    }

    // ---------- Item Types ----------
    item def RawSensorData {
        attribute rawPressure : PressureValue;
        attribute rawTemperature : TemperatureValue;
        attribute timestamp : TimeValue;
    }

    item def ProcessedData {
        attribute compensatedPressure : PressureValue;
        attribute filteredPressure : PressureValue;
        attribute altitudeEstimate : AltitudeValue;
        attribute timestamp : TimeValue;
    }

    item def DisplayData {
        attribute displayPressure : PressureValue;
        attribute displayAltitude : AltitudeValue;
        attribute displayTemperature : TemperatureValue;
        attribute timestamp : TimeValue;
    }

    item def PowerCommand {
        attribute targetState : PowerStateKind;
    }

    enum def PowerStateKind {
        active;
        standby;
        shutdown;
    }

    enum def OperationalModeKind {
        idle;
        measuring;
        calibrating;
    }

    item def CalibrationData {
        attribute seaLevelPressure : PressureValue = 101325.0 [Pa];
        attribute sensorOffset : PressureValue = 0.0 [Pa];
        attribute temperatureCoefficient : Real = 0.0;
    }

    // ---------- Port Definitions ----------
    port def RawDataOut {
        out item rawSensorData : RawSensorData;
    }

    port def RawDataIn {
        in item rawSensorData : RawSensorData;
    }

    port def ProcessedDataOut {
        out item processedData : ProcessedData;
    }

    port def ProcessedDataIn {
        in item processedData : ProcessedData;
    }

    port def DisplayDataOut {
        out item displayData : DisplayData;
    }

    port def DisplayDataIn {
        in item displayData : DisplayData;
    }

    port def PowerOut {
        out attribute supplyVoltage : VoltageValue;
        out attribute availablePower : PowerValue;
    }

    port def PowerIn {
        in attribute supplyVoltage : VoltageValue;
        in attribute availablePower : PowerValue;
    }

    port def PowerControlOut {
        out item powerCommand : PowerCommand;
    }

    port def PowerControlIn {
        in item powerCommand : PowerCommand;
    }

    port def CalibrationPort {
        in item calibrationData : CalibrationData;
        out item currentCalibration : CalibrationData;
    }

    // ---------- Requirements ----------
    requirement def BarometerRequirements {
        requirement MeasurePressure {
            doc /* The system shall measure atmospheric pressure with an accuracy of ±1 hPa. */
            attribute maxError : PressureValue = 100.0 [Pa];
        }
        requirement MeasureTemperature {
            doc /* The system shall measure ambient temperature for compensation. */
            attribute range : TemperatureValue = 233.15 [K] to 353.15 [K];
        }
        requirement CalculateAltitude {
            doc /* The system shall calculate altitude from compensated pressure. */
            attribute maxAltitudeError : AltitudeValue = 5.0 [m];
        }
        requirement DisplayReadings {
            doc /* The system shall display pressure and altitude to the user. */
            attribute refreshRate : TimeValue = 1.0 [s];
        }
        requirement PowerEfficiency {
            doc /* The system shall support active, standby, and shutdown power modes. */
            attribute standbyPower : PowerValue = 0.001 [W];
            attribute activePower : PowerValue = 0.05 [W];
        }
        requirement BatteryLife {
            doc /* The system shall operate for at least 168 hours on a single charge in standby. */
            attribute minStandbyDuration : TimeValue = 168 [h];
        }
    }

    // ---------- Pressure Sensor ----------
    part def PressureSensor {
        port rawOut : RawDataOut;
        port powerIn : PowerIn;
        port calibration : CalibrationPort;

        attribute samplingInterval : TimeValue = 0.5 [s];
        attribute isPowered : Boolean = false;

        action def SenseAction {
            in calibration : CalibrationData;
            out raw : RawSensorData;
        }

        perform sense : SenseAction {
            in calibration = calibration.currentCalibration;
            out raw = rawOut.rawSensorData;
        }

        state def SensorStates {
            entry; then Off;
            state Off;
            state Sensing {
                entry;
                do send rawOut.rawSensorData;
            }
            transition off_to_sensing first Off then Sensing
                when powerIn.supplyVoltage > 0.0 [V];
            transition sensing_to_off first Sensing then Off
                when powerIn.supplyVoltage <= 0.0 [V];
        }

        exhibit sensorBehavior : SensorStates;
    }

    // ---------- Data Processor ----------
    part def DataProcessor {
        port rawIn : RawDataIn;
        port processedOut : ProcessedDataOut;
        port powerIn : PowerIn;
        port calibration : CalibrationPort;

        attribute filterCoefficient : Real = 0.2;
        attribute previousFilteredPressure : PressureValue = 0.0 [Pa];
        attribute storedCalibration : CalibrationData;

        action def CompensatePressure {
            in raw : RawSensorData;
            in calibration : CalibrationData;
            out compensated : PressureValue;
        }

        action def FilterPressure {
            in compensated : PressureValue;
            in previous : PressureValue;
            in coefficient : Real;
            out filtered : PressureValue;
        }

        action def CalculateAltitudeAction {
            in filteredPressure : PressureValue;
            in seaLevelPressure : PressureValue;
            out altitude : AltitudeValue;
        }

        action def ProcessingCycle {
            in raw : RawSensorData;
            in calibration : CalibrationData;
            out processed : ProcessedData;
            action compensate : CompensatePressure {
                in raw = raw;
                in calibration = calibration;
                out compensated;
            }
            then action filter : FilterPressure {
                in compensated = compensate.compensated;
                in previous = previousFilteredPressure;
                in coefficient = filterCoefficient;
                out filtered;
            }
            then action calcAltitude : CalculateAltitudeAction {
                in filteredPressure = filter.filtered;
                in seaLevelPressure = calibration.seaLevelPressure;
                out altitude;
            }
            then assign processed.compensatedPressure = compensate.compensated;
            assign processed.filteredPressure = filter.filtered;
            assign processed.altitudeEstimate = calcAltitude.altitude;
            assign processed.timestamp = raw.timestamp;
            assign previousFilteredPressure = filter.filtered;
        }

        perform processing : ProcessingCycle {
            in raw = rawIn.rawSensorData;
            in calibration = storedCalibration;
            out processed = processedOut.processedData;
        }

        state def ProcessorStates {
            entry; then Inactive;
            state Inactive;
            state Processing {
                entry;
                do send processedOut.processedData;
            }
            transition inactive_to_processing first Inactive then Processing
                when powerIn.supplyVoltage > 0.0 [V];
            transition processing_to_inactive first Processing then Inactive
                when powerIn.supplyVoltage <= 0.0 [V];
        }

        exhibit processorBehavior : ProcessorStates;
    }

    // ---------- User Interface ----------
    part def UserInterface {
        port displayIn : DisplayDataIn;
        port powerIn : PowerIn;

        attribute backlightEnabled : Boolean = true;
        attribute displayResolution : Integer = 4;
        attribute lastDisplayed : DisplayData;

        action def UpdateDisplay {
            in data : DisplayData;
        }

        perform update : UpdateDisplay {
            in data = displayIn.displayData;
        }

        state def DisplayStates {
            entry; then DisplayOff;
            state DisplayOff;
            state DisplayOn {
                entry;
                do accept displayIn.displayData;
            }
            transition off_to_on first DisplayOff then DisplayOn
                when powerIn.supplyVoltage > 0.0 [V];
            transition on_to_off first DisplayOn then DisplayOff
                when powerIn.supplyVoltage <= 0.0 [V];
        }

        exhibit displayBehavior : DisplayStates;
    }

    // ---------- Power Management ----------
    part def PowerManagement {
        port powerOut : PowerOut[4];
        port controlIn : PowerControlIn;

        attribute batteryCapacity : VoltageValue = 3.7 [V];
        attribute batteryLevel : BatteryLevel = 100.0 [%];
        attribute activePowerDraw : PowerValue = 0.05 [W];
        attribute standbyPowerDraw : PowerValue = 0.001 [W];
        attribute shutdownPowerDraw : PowerValue = 0.0 [W];
        attribute currentPowerState : PowerStateKind = PowerStateKind::active;

        action def SwitchPowerState {
            in command : PowerCommand;
            out newState : PowerStateKind;
            out voltage : VoltageValue;
            out power : PowerValue;
        }

        perform switchState : SwitchPowerState {
            in command = controlIn.powerCommand;
            out newState;
            out voltage;
            out power;
        }

        state def PowerStates {
            entry; then Active;
            state Active {
                entry;
                do assign powerOut.supplyVoltage = batteryCapacity;
                assign powerOut.availablePower = activePowerDraw;
            }
            state Standby {
                entry;
                do assign powerOut.supplyVoltage = batteryCapacity;
                assign powerOut.availablePower = standbyPowerDraw;
            }
            state Shutdown {
                entry;
                do assign powerOut.supplyVoltage = 0.0 [V];
                assign powerOut.availablePower = shutdownPowerDraw;
            }
            transition active_to_standby first Active then Standby
                when controlIn.powerCommand.targetState == PowerStateKind::standby;
            transition standby_to_active first Standby then Active
                when controlIn.powerCommand.targetState == PowerStateKind::active;
            transition active_to_shutdown first Active then Shutdown
                when controlIn.powerCommand.targetState == PowerStateKind::shutdown;
            transition standby_to_shutdown first Standby then Shutdown
                when controlIn.powerCommand.targetState == PowerStateKind::shutdown;
            transition shutdown_to_active first Shutdown then Active
                when controlIn.powerCommand.targetState == PowerStateKind::active;
        }

        exhibit powerBehavior : PowerStates;
    }

    // ---------- Barometer System ----------
    part def BarometerSystem {
        satisfy BarometerRequirements;

        port calibrationPort : CalibrationPort;
        port controlPort : PowerControlIn;

        part pressureSensor : PressureSensor {
            port rawOut : RawDataOut;
            port powerIn : PowerIn;
            port calibration : CalibrationPort;
        }

        part dataProcessor : DataProcessor {
            port rawIn : RawDataIn;
            port processedOut : ProcessedDataOut;
            port powerIn : PowerIn;
            port calibration : CalibrationPort;
        }

        part userInterface : UserInterface {
            port displayIn : DisplayDataIn;
            port powerIn : PowerIn;
        }

        part powerManagement : PowerManagement {
            port powerOut : PowerOut[4];
            port controlIn : PowerControlIn;
        }

        // Internal connections
        connection rawDataFlow connect pressureSensor.rawOut to dataProcessor.rawIn;
        connection processedDataFlow connect dataProcessor.processedOut to userInterface.displayIn;
        connection powerToSensor connect powerManagement.powerOut[0] to pressureSensor.powerIn;
        connection powerToProcessor connect powerManagement.powerOut[1] to dataProcessor.powerIn;
        connection powerToDisplay connect powerManagement.powerOut[2] to userInterface.powerIn;
        connection calibrationFlow connect calibrationPort to pressureSensor.calibration;
        connection calibrationToProcessor connect pressureSensor.calibration to dataProcessor.calibration;
        connection controlFlow connect controlPort to powerManagement.controlIn;

        // System-level operational state machine
        attribute currentMode : OperationalModeKind = OperationalModeKind::idle;

        state def OperationalModes {
            entry; then Idle;
            state Idle {
                entry;
                do send controlPort.powerCommand.targetState = PowerStateKind::standby;
            }
            state Measuring {
                entry;
                do send controlPort.powerCommand.targetState = PowerStateKind::active;
                // Continuous measurement cycle
                do accept pressureSensor.rawOut.rawSensorData;
                then accept dataProcessor.processedOut.processedData;
                then accept userInterface.displayIn.displayData;
            }
            state Calibrating {
                entry;
                do send controlPort.powerCommand.targetState = PowerStateKind::active;
                do accept calibrationPort.calibrationData;
            }
            transition idle_to_measuring first Idle then Measuring
                when currentMode == OperationalModeKind::measuring;
            transition measuring_to_idle first Measuring then Idle
                when currentMode == OperationalModeKind::idle;
            transition idle_to_calibrating first Idle then Calibrating
                when currentMode == OperationalModeKind::calibrating;
            transition calibrating_to_idle first Calibrating then Idle
                when currentMode == OperationalModeKind::idle;
            transition measuring_to_calibrating first Measuring then Calibrating
                when currentMode == OperationalModeKind::calibrating;
            transition calibrating_to_measuring first Calibrating then Measuring
                when currentMode == OperationalModeKind::measuring;
        }

        exhibit operationalBehavior : OperationalModes;
    }
}

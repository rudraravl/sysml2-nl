package MagnetometerModel {
    import ScalarValues::Real;
    import ScalarValues::Boolean;
    import ScalarValues::Integer;
    import SI::tesla;
    import SI::volt;
    import SI::ampere;
    import SI::kelvin;
    import SI::hertz;
    import SI::degree_Celsius;

    // ----- Value Types -----
    value type MagneticFluxDensityValue :> Real {
        unit microtesla [uT] = 1.0E-6 [tesla];
    }

    value type AnalogVoltageValue :> Real {
        unit millivolt [mV] = 1.0E-3 [volt];
    }

    value type CurrentValue :> Real {
        unit milliampere [mA] = 1.0E-3 [ampere];
    }

    value type TemperatureValue :> Real {
        unit degC [°C] = 1.0 [degree_Celsius];
    }

    value type DigitalCountValue :> Integer {
    }

    value type FrequencyValue :> Real {
        unit kilohertz [kHz] = 1000.0 [hertz];
    }

    value type MagneticMagnitudeValue :> Real {
        unit microtesla [uT] = 1.0E-6 [tesla];
    }

    // ----- Item Types -----
    item def RawMagneticSignal {
        attribute xVoltage : AnalogVoltageValue;
        attribute yVoltage : AnalogVoltageValue;
        attribute zVoltage : AnalogVoltageValue;
        attribute timestamp : Integer;
    }

    item def ConditionedSignal {
        attribute xVoltage : AnalogVoltageValue;
        attribute yVoltage : AnalogVoltageValue;
        attribute zVoltage : AnalogVoltageValue;
        attribute timestamp : Integer;
        attribute noiseFloor : AnalogVoltageValue;
    }

    item def DigitalSample {
        attribute xCount : DigitalCountValue;
        attribute yCount : DigitalCountValue;
        attribute zCount : DigitalCountValue;
        attribute timestamp : Integer;
        attribute overRange : Boolean;
    }

    item def CalibratedMagneticReading {
        attribute xField : MagneticFluxDensityValue;
        attribute yField : MagneticFluxDensityValue;
        attribute zField : MagneticFluxDensityValue;
        attribute magnitude : MagneticMagnitudeValue;
        attribute temperature : TemperatureValue;
        attribute timestamp : Integer;
        attribute valid : Boolean;
    }

    item def CalibrationParameters {
        attribute hardIronOffsetX : MagneticFluxDensityValue;
        attribute hardIronOffsetY : MagneticFluxDensityValue;
        attribute hardIronOffsetZ : MagneticFluxDensityValue;
        attribute softIronScaleXX : Real;
        attribute softIronScaleYY : Real;
        attribute softIronScaleZZ : Real;
        attribute tempCompSlope : Real;
        attribute referenceTemp : TemperatureValue;
    }

    item def PowerStatus {
        attribute inputVoltage : Real :> volt;
        attribute regulatedVoltage : Real :> volt;
        attribute currentDraw : CurrentValue;
        attribute powerGood : Boolean;
    }

    item def CommandRequest {
        attribute commandId : Integer;
        attribute payload : Integer[0..*];
    }

    // ----- Interface Definitions -----
    port def AnalogOutputPort {
        out signal : RawMagneticSignal;
    }

    port def AnalogInputPort {
        in signal : RawMagneticSignal;
    }

    port def ConditionedAnalogPort {
        out signal : ConditionedSignal;
    }

    port def ConditionedAnalogInputPort {
        in signal : ConditionedSignal;
    }

    port def DigitalDataPort {
        out sample : DigitalSample;
    }

    port def DigitalDataInputPort {
        in sample : DigitalSample;
    }

    port def CalibratedDataPort {
        out reading : CalibratedMagneticReading;
    }

    port def CommandPort {
        in command : CommandRequest;
        out status : Integer;
    }

    port def HostInterfacePort {
        in hostCommand : CommandRequest;
        out hostReading : CalibratedMagneticReading;
        out hostStatus : Integer;
    }

    port def PowerInputPort {
        in externalVoltage : Real :> volt;
    }

    port def PowerOutputPort {
        out regulatedVoltage : Real :> volt;
        out powerStatus : PowerStatus;
    }

    port def PowerConsumerPort {
        in regulatedVoltage : Real :> volt;
    }

    port def TemperatureOutputPort {
        out temperature : TemperatureValue;
    }

    port def TemperatureInputPort {
        in temperature : TemperatureValue;
    }

    // ----- Sensing Element -----
    part def SensingElement {
        exhibit state {
            entry;
            inactive;
            active;
        }

        port rawOut : AnalogOutputPort;
        port powerIn : PowerConsumerPort;

        attribute sensitivity : Real = 1.0;  // mV/uT
        attribute measurementRange : MagneticFluxDensityValue = 1000.0 [uT];
        attribute axisCount : Integer = 3;

        action detectMagneticField : RawMagneticSignal {
            in fieldX : MagneticFluxDensityValue;
            in fieldY : MagneticFluxDensityValue;
            in fieldZ : MagneticFluxDensityValue;
            out raw : RawMagneticSignal;
        }

        state machine sensingState {
            state inactive {
                entry;
            }
            state active {
                entry;
            }
            transition from inactive to active when powerIn.regulatedVoltage > 0.0 [volt];
        }
    }

    // ----- Signal Conditioner -----
    part def SignalConditioner {
        port analogIn : AnalogInputPort;
        port analogOut : ConditionedAnalogPort;
        port powerIn : PowerConsumerPort;

        attribute gain : Real = 10.0;
        attribute lowPassCutoff : FrequencyValue = 50.0 [kHz];
        attribute commonModeRejection : Real = 80.0;

        action conditionSignal {
            in raw : RawMagneticSignal;
            out conditioned : ConditionedSignal;
        }

        state machine conditionerState {
            state idle;
            state amplifying {
                entry;
            }
            transition from idle to amplifying when analogIn.signal.timestamp > 0;
            transition from amplifying to idle when analogOut.signal.timestamp > 0;
        }
    }

    // ----- ADC -----
    part def AnalogToDigitalConverter {
        port analogIn : ConditionedAnalogInputPort;
        port digitalOut : DigitalDataPort;
        port powerIn : PowerConsumerPort;

        attribute resolutionBits : Integer = 16;
        attribute sampleRate : FrequencyValue = 100.0 [kHz];
        attribute referenceVoltage : Real :> volt = 3.3 [volt];

        action convert {
            in conditioned : ConditionedSignal;
            out digital : DigitalSample;
        }

        state machine adcState {
            state waiting;
            state converting {
                entry;
            }
            transition from waiting to converting when analogIn.signal.timestamp > 0;
            transition from converting to waiting when digitalOut.sample.timestamp > 0;
        }
    }

    // ----- Digital Processor -----
    part def DigitalProcessor {
        port dataIn : DigitalDataInputPort;
        port tempIn : TemperatureInputPort;
        port commandIn : CommandPort;
        port calibratedOut : CalibratedDataPort;
        port powerIn : PowerConsumerPort;

        attribute storedCalibration : CalibrationParameters;
        attribute clockFrequency : FrequencyValue = 8.0 [kHz];
        attribute algorithmVersion : Integer = 2;

        action applyCalibration {
            in digital : DigitalSample;
            in temp : TemperatureValue;
            in cal : CalibrationParameters;
            out reading : CalibratedMagneticReading;
        }

        action computeMagnitude {
            in xField : MagneticFluxDensityValue;
            in yField : MagneticFluxDensityValue;
            in zField : MagneticFluxDensityValue;
            out magnitude : MagneticMagnitudeValue;
        }

        action updateCalibration {
            in samples : DigitalSample[0..*];
            out newCal : CalibrationParameters;
        }

        state machine processorState {
            state idle;
            state processing {
                entry;
            }
            state calibratingState {
                entry;
            }
            transition from idle to processing when dataIn.sample.timestamp > 0;
            transition from processing to idle when calibratedOut.reading.valid;
            transition from idle to calibratingState when commandIn.command.commandId == 2;
            transition from calibratingState to idle when storedCalibration.referenceTemp > 0.0 [°C];
        }
    }

    // ----- Communication Interface -----
    part def CommunicationInterface {
        port hostPort : HostInterfacePort;
        port internalCommand : CommandPort;
        port internalData : CalibratedDataPort;
        port powerIn : PowerConsumerPort;

        attribute protocol : String = "I2C";
        attribute address : Integer = 0x1E;
        attribute clockSpeed : FrequencyValue = 400.0 [kHz];

        action transmitReading {
            in reading : CalibratedMagneticReading;
        }

        action receiveCommand {
            out command : CommandRequest;
        }

        state machine commState {
            state listening;
            state transmitting {
                entry;
            }
            transition from listening to transmitting when internalData.reading.valid;
            transition from transmitting to listening when hostPort.hostReading.valid;
        }
    }

    // ----- Power Management Unit -----
    part def PowerManagementUnit {
        port powerInput : PowerInputPort;
        port regulatedPowerOut : PowerOutputPort;
        port sensorPower : PowerConsumerPort;

        attribute regulatedVoltageLevel : Real :> volt = 3.3 [volt];
        attribute maxCurrent : CurrentValue = 50.0 [mA];
        attribute efficiency : Real = 0.92;
        attribute overCurrentThreshold : CurrentValue = 75.0 [mA];

        action regulateVoltage {
            in inputVoltage : Real :> volt;
            out outputVoltage : Real :> volt;
            out status : PowerStatus;
        }

        action monitorCurrent {
            out current : CurrentValue;
            out powerGood : Boolean;
        }

        state machine pmuState {
            state off;
            state regulating {
                entry;
            }
            state fault {
                entry;
            }
            transition from off to regulating when powerInput.externalVoltage > 0.0 [volt];
            transition from regulating to fault when monitorCurrent.current > overCurrentThreshold;
            transition from fault to off when powerInput.externalVoltage == 0.0 [volt];
        }
    }

    // ----- Temperature Sensor -----
    part def TemperatureSensor {
        port tempOut : TemperatureOutputPort;
        port powerIn : PowerConsumerPort;

        attribute accuracy : TemperatureValue = 0.5 [°C];
        attribute operatingRange : TemperatureValue[2] = [-40.0, 85.0];
        attribute measurementTime : Integer = 5;

        action measureTemperature {
            out temp : TemperatureValue;
        }

        state machine tempState {
            state idle;
            state measuring {
                entry;
            }
            transition from idle to measuring when powerIn.regulatedVoltage > 0.0 [volt];
            transition from measuring to idle when tempOut.temperature >= -273.15 [°C];
        }
    }

    // ----- Top-Level Magnetometer System -----
    part def ThreeAxisDigitalMagnetometer {
        // Subcomponents
        part sensingElement : SensingElement;
        part signalConditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter;
        part digitalProcessor : DigitalProcessor;
        part communicationInterface : CommunicationInterface;
        part powerManagement : PowerManagementUnit;
        part temperatureSensor : TemperatureSensor;

        // Ports
        port extPower : PowerInputPort;
        port hostConnection : HostInterfacePort;

        // Internal power connections
        connection powerFeed connect powerManagement.powerInput to extPower;
        connection regulatedBus connect powerManagement.regulatedPowerOut to sensingElement.powerIn;
        connection regulatedBus2 connect powerManagement.regulatedPowerOut to signalConditioner.powerIn;
        connection regulatedBus3 connect powerManagement.regulatedPowerOut to adc.powerIn;
        connection regulatedBus4 connect powerManagement.regulatedPowerOut to digitalProcessor.powerIn;
        connection regulatedBus5 connect powerManagement.regulatedPowerOut to communicationInterface.powerIn;
        connection regulatedBus6 connect powerManagement.regulatedPowerOut to temperatureSensor.powerIn;

        // Signal chain connections
        connection rawSignalFlow connect sensingElement.rawOut to signalConditioner.analogIn;
        connection conditionedSignalFlow connect signalConditioner.analogOut to adc.analogIn;
        connection digitalDataFlow connect adc.digitalOut to digitalProcessor.dataIn;
        connection temperatureFlow connect temperatureSensor.tempOut to digitalProcessor.tempIn;
        connection calibratedDataFlow connect digitalProcessor.calibratedOut to communicationInterface.internalData;
        connection commandFlow connect communicationInterface.internalCommand to digitalProcessor.commandIn;
        connection hostCommandPath connect hostConnection.hostCommand to communicationInterface.hostPort.hostCommand;
        connection hostDataPath connect communicationInterface.hostPort.hostReading to hostConnection.hostReading;
        connection hostStatusPath connect communicationInterface.hostPort.hostStatus to hostConnection.hostStatus;

        // System-level state machine
        state machine systemState {
            state powerOff {
                entry;
            }
            state initializing {
                entry;
            }
            state idle {
                entry;
            }
            state measuring {
                entry;
            }
            state calibrating {
                entry;
            }
            state fault {
                entry;
            }

            transition from powerOff to initializing when extPower.externalVoltage > 0.0 [volt];
            transition from initializing to idle after 500 [ms];
            transition from initializing to fault when powerManagement.regulatedPowerOut.powerStatus.powerGood == false;
            transition from idle to measuring when hostConnection.hostCommand.commandId == 1;
            transition from measuring to idle when hostConnection.hostCommand.commandId == 0;
            transition from idle to calibrating when hostConnection.hostCommand.commandId == 2;
            transition from calibrating to idle when digitalProcessor.storedCalibration.referenceTemp > 0.0 [°C];
            transition from measuring to fault when digitalProcessor.calibratedOut.reading.valid == false;
            transition from fault to powerOff when extPower.externalVoltage == 0.0 [volt];
        }

        attribute modelIdentifier : String = "3-Axis Digital Magnetometer";
        attribute firmwareVersion : String = "1.0.0";
        attribute manufacturer : String = "GenericSensors Inc.";
        attribute interfaceProtocol : String = "I2C";
        attribute defaultAddress : Integer = 0x1E;
    }

    // ----- Requirements -----
    requirement def MeasurementAccuracy {
        doc /* The magnetometer shall measure magnetic field strength with an accuracy of better than ±1°/µT across all three axes after calibration. */
        attribute maxError : MagneticFluxDensityValue = 1.0 [uT];
        subject magnetometer : ThreeAxisDigitalMagnetometer;
    }

    requirement def OperatingTemperature {
        doc /* The system shall operate over the industrial temperature range of -40°C to +85°C. */
        attribute minTemp : TemperatureValue = -40.0 [°C];
        attribute maxTemp : TemperatureValue = 85.0 [°C];
        subject magnetometer : ThreeAxisDigitalMagnetometer;
    }

    requirement def PowerConsumption {
        doc /* The total power consumption shall not exceed 50 mA at 3.3V during continuous measurement. */
        attribute maxCurrent : CurrentValue = 50.0 [mA];
        attribute nominalVoltage : Real :> volt = 3.3 [volt];
        subject magnetometer : ThreeAxisDigitalMagnetometer;
    }

    requirement def FieldMeasurementRange {
        doc /* The sensor shall measure magnetic fields in the range of ±1000 µT. */
        attribute minRange : MagneticFluxDensityValue = -1000.0 [uT];
        attribute maxRange : MagneticFluxDensityValue = 1000.0 [uT];
        subject magnetometer : ThreeAxisDigitalMagnetometer;
    }

    requirement def CalibrationCorrection {
        doc /* The digital processor shall apply hard-iron and soft-iron compensation using stored calibration parameters, and shall account for temperature drift using the onboard temperature sensor. */
        subject magnetometer : ThreeAxisDigitalMagnetometer;
    }

    requirement def CommunicationProtocol {
        doc /* The system shall provide calibrated digital output to a host device using the I2C protocol at a clock speed up to 400 kHz. */
        attribute protocol : String = "I2C";
        attribute maxClock : FrequencyValue = 400.0 [kHz];
        subject magnetometer : ThreeAxisDigitalMagnetometer;
    }

    requirement def OperationalStates {
        doc /* The system shall support the operational states: powerOff, initializing, idle, measuring, calibrating, and fault. */
        subject magnetometer : ThreeAxisDigitalMagnetometer;
    }

    requirement def ContinuousMeasurement {
        doc /* The system shall be capable of continuous measurement at a sample rate of at least 100 Hz. */
        attribute minSampleRate : FrequencyValue = 100.0 [kHz];
        subject magnetometer : ThreeAxisDigitalMagnetometer;
    }

    requirement def SelfTestOnPower {
        doc /* Upon power-up, the system shall perform self-tests during the initializing state and enter the fault state if any test fails. */
        subject magnetometer : ThreeAxisDigitalMagnetometer;
    }

    // ----- Requirements Satisfaction -----
    requirement measurementAccuracyReq : MeasurementAccuracy {
        magnetometer.sensingElement.measurementRange = 1000.0 [uT];
        magnetometer.digitalProcessor.algorithmVersion = 2;
    }

    requirement operatingTempReq : OperatingTemperature {
        magnetometer.temperatureSensor.operatingRange = [-40.0, 85.0];
    }

    requirement powerConsumptionReq : PowerConsumption {
        magnetometer.powerManagement.maxCurrent = 50.0 [mA];
        magnetometer.powerManagement.regulatedVoltageLevel = 3.3 [volt];
    }

    requirement fieldRangeReq : FieldMeasurementRange {
        magnetometer.sensingElement.measurementRange = 1000.0 [uT];
    }

    requirement calibrationReq : CalibrationCorrection {
        magnetometer.digitalProcessor.storedCalibration.hardIronOffsetX = 0.0 [uT];
        magnetometer.digitalProcessor.storedCalibration.hardIronOffsetY = 0.0 [uT];
        magnetometer.digitalProcessor.storedCalibration.hardIronOffsetZ = 0.0 [uT];
    }

    requirement commReq : CommunicationProtocol {
        magnetometer.communicationInterface.protocol = "I2C";
        magnetometer.communicationInterface.clockSpeed = 400.0 [kHz];
    }

    requirement statesReq : OperationalStates {
    }

    requirement continuousReq : ContinuousMeasurement {
        magnetometer.adc.sampleRate = 100.0 [kHz];
    }

    requirement selfTestReq : SelfTestOnPower {
    }
}

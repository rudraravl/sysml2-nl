package TiltSensingUnitModel {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value Types ----
    value type Voltage :> Real { unit "V"; }
    value type Angle :> Real { unit "deg"; }
    value type Temperature :> Real { unit "degC"; }
    value type Duration :> Real { unit "s"; }
    value type QualityScore :> Real { unit "1"; min 0; max 1; }
    value type Slope :> Real { unit "1"; }
    value type Offset :> Angle { unit "deg"; }
    value type Frequency :> Real { unit "Hz"; }

    // ---- Item Types ----
    item def RawSensorData {
        attribute pitchVoltage : Voltage;
        attribute rollVoltage : Voltage;
        attribute temperature : Temperature;
    }

    item def CalibrationParams {
        attribute pitchSlope : Slope;
        attribute pitchOffset : Offset;
        attribute rollSlope : Slope;
        attribute rollOffset : Offset;
    }

    item def TiltMeasurement {
        attribute pitch : Angle;
        attribute roll : Angle;
        attribute timestamp : TimeInstant;
        attribute quality : QualityScore;
    }

    item def PowerSupply {
        attribute voltage : Voltage;
        attribute current : Real { unit "A"; }
    }

    item def MeasurementCommand {
        attribute commandId : String;
        attribute requested : Boolean;
    }

    // ---- Port Definitions ----
    port def PowerPort {
        out item supply : PowerSupply;
    }

    port def RawDataPort {
        out item raw : RawSensorData;
    }

    port def CommandPort {
        in item cmd : MeasurementCommand;
    }

    port def MeasurementPort {
        out item measurement : TiltMeasurement;
    }

    // ---- Tilt Sensor ----
    part def TiltSensor {
        port powerIn : PowerPort;
        port rawDataOut : RawDataPort;

        attribute supplyVoltage : Voltage = 5.0;
        attribute operatingTempMin : Temperature = -40;
        attribute operatingTempMax : Temperature = 85;

        attribute pitchSensitivity : Slope = 18.0;  // mV/deg
        attribute rollSensitivity : Slope = 18.0;
        attribute pitchZeroVoltage : Voltage = 2.5;
        attribute rollZeroVoltage : Voltage = 2.5;

        action def AcquireRawData {
            in temp : Temperature;
            out raw : RawSensorData;
        }

        action acquire : AcquireRawData {
            in temp = self.currentTemperature;
            out raw = self.rawDataOut.raw;
        }

        attribute currentTemperature : Temperature;

        action def SensorInit {
            out status : String;
        }

        action initialize : SensorInit {
            out status = "SensorReady";
        }
    }

    // ---- Signal Processor ----
    part def SignalProcessor {
        port rawDataIn : RawDataPort;
        port measurementOut : MeasurementPort;

        attribute calibration : CalibrationParams;
        attribute filterCutoff : Frequency = 10.0;

        action def Convert {
            in raw : RawSensorData;
            out pitchEstimate : Angle;
            out rollEstimate : Angle;
        }

        action def Calibrate {
            in pitchIn : Angle;
            in rollIn : Angle;
            in params : CalibrationParams;
            out pitchCalibrated : Angle;
            out rollCalibrated : Angle;
        }

        action def Filter {
            in pitchIn : Angle;
            in rollIn : Angle;
            out pitchFiltered : Angle;
            out rollFiltered : Angle;
        }

        action def Validate {
            in pitchIn : Angle;
            in rollIn : Angle;
            in temp : Temperature;
            out measurement : TiltMeasurement;
        }

        action def ProcessMeasurement {
            in raw : RawSensorData;
            out measurement : TiltMeasurement;

            action convert : Convert {
                in raw = ProcessMeasurement::raw;
                out pitchEstimate;
                out rollEstimate;
            }
            action calibrate : Calibrate {
                in pitchIn = convert.pitchEstimate;
                in rollIn = convert.rollEstimate;
                in params = self.calibration;
                out pitchCalibrated;
                out rollCalibrated;
            }
            action filter : Filter {
                in pitchIn = calibrate.pitchCalibrated;
                in rollIn = calibrate.rollCalibrated;
                out pitchFiltered;
                out rollFiltered;
            }
            action validate : Validate {
                in pitchIn = filter.pitchFiltered;
                in rollIn = filter.rollFiltered;
                in temp = raw.temperature;
                out measurement = ProcessMeasurement::measurement;
            }
        }

        action process : ProcessMeasurement {
            in raw = self.rawDataIn.raw;
            out measurement = self.measurementOut.measurement;
        }

        action def ProcessorInit {
            out status : String;
        }

        action initialize : ProcessorInit {
            out status = "ProcessorReady";
        }
    }

    // ---- Tilt Sensing Unit ----
    part def TiltSensingUnit {
        port powerInput : PowerPort;
        port commandInput : CommandPort;
        port measurementOutput : MeasurementPort;

        part tiltSensor : TiltSensor {
            port powerIn :>> powerInput;
        }

        part signalProcessor : SignalProcessor {
            port measurementOut :>> measurementOutput;
        }

        connection rawLink connect tiltSensor.rawDataOut to signalProcessor.rawDataIn;

        attribute initialized : Boolean = false;
        attribute lastMeasurement : TiltMeasurement;

        // ---- State Machine ----
        state def TiltUnitLifecycle {
            state Off;
            state Starting;
            state InitializingSensor;
            state InitializingProcessor;
            state Standby;
            state Measuring;
            state Error;
            state Resetting;

            transition off_to_starting first Off if (powerInput.supply.voltage > 4.5) then Starting;
            transition start_to_initSensor then InitializingSensor;
            transition initSensor_done then InitializingProcessor
                when (tiltSensor.initialize.status == "SensorReady");
            transition initProcessor_done then Standby
                when (signalProcessor.initialize.status == "ProcessorReady");

            transition standby_to_measuring then Measuring
                when (commandInput.cmd.requested == true);
            transition measuring_done then Standby
                when (measurementOutput.measurement != null);

            transition any_to_error then Error
                when (self.errorCondition == true);
            transition error_to_resetting then Resetting
                when (commandInput.cmd.commandId == "reset");
            transition resetting_done then Off;

            entry action Off { assign self.initialized = false; }
            entry action Standby { assign self.initialized = true; }
            entry action Measuring {
                tiltSensor.acquire();
                signalProcessor.process();
            }
        }

        attribute errorCondition : Boolean = false;

        state machine lifecycle : TiltUnitLifecycle;
    }

    // ---- Requirements ----
    requirement def AccuracyRequirement {
        attribute maxError : Angle = 0.5;
        subject measurement : TiltMeasurement;
        require {
            abs(measurement.pitch - truePitch) <= maxError and
            abs(measurement.roll - trueRoll) <= maxError
        }
    }

    requirement def MeasurementRangeRequirement {
        attribute minAngle : Angle = -90;
        attribute maxAngle : Angle = 90;
        subject measurement : TiltMeasurement;
        require {
            measurement.pitch >= minAngle and measurement.pitch <= maxAngle and
            measurement.roll >= minAngle and measurement.roll <= maxAngle
        }
    }

    requirement def ResponseTimeRequirement {
        attribute maxResponseTime : Duration = 0.1;
        subject unit : TiltSensingUnit;
        require {
            unit.measurementLatency <= maxResponseTime
        }
    }

    requirement def TemperatureRangeRequirement {
        attribute minTemp : Temperature = -40;
        attribute maxTemp : Temperature = 85;
        subject unit : TiltSensingUnit;
        require {
            unit.tiltSensor.currentTemperature >= minTemp and
            unit.tiltSensor.currentTemperature <= maxTemp
        }
    }

    requirement def TiltSensingUnitRequirements {
        requirement accuracy : AccuracyRequirement;
        requirement range : MeasurementRangeRequirement;
        requirement responseTime : ResponseTimeRequirement;
        requirement tempRange : TemperatureRangeRequirement;
    }

    package TiltSensingUnitInstances {
        part tiltUnit : TiltSensingUnit {
            satisfy TiltSensingUnitRequirements by tiltUnit;
            attribute measurementLatency : Duration = 0.08;
            attribute truePitch : Angle;
            attribute trueRoll : Angle;
        }
    }
}

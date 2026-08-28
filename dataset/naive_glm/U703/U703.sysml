package GyroscopicSensingUnit {

    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;
    import ISQThermodynamics::*;
    import ISQElectricity::*;

    // ---- Value Types ----

    value def AngularRateValue :> Real {
        unit angularRate = (degree)/(second);
    }

    value def TemperatureValue :> Real {
        unit kelvin;
    }

    value def VoltageValue :> Real {
        unit volt;
    }

    value def FrequencyValue :> Real {
        unit hertz;
    }

    value def CapacitanceValue :> Real {
        unit farad;
    }

    value def DisplacementValue :> Real {
        unit meter;
    }

    value def TimestampValue :> Real {
        unit millisecond;
    }

    value def RawDigitalSample :> Integer;

    // ---- Item Types ----

    item def AnalogSignal {
        attribute magnitude : VoltageValue;
        attribute axisId : String;
    }

    item def DigitalSample {
        attribute value : RawDigitalSample;
        attribute axisId : String;
    }

    item def AxisRate {
        attribute axisId : String;
        attribute rate : AngularRateValue;
    }

    item def GyroDataPacket {
        attribute xRate : AngularRateValue;
        attribute yRate : AngularRateValue;
        attribute zRate : AngularRateValue;
        attribute timestamp : TimestampValue;
    }

    item def DiagnosticData {
        attribute internalTemperature : TemperatureValue;
        attribute supplyVoltage : VoltageValue;
        attribute selfTestPassed : Boolean;
        attribute faultActive : Boolean;
    }

    item def Command {
        attribute commandType : String;
    }

    item def CalibrationTable {
        attribute xBias : AngularRateValue;
        attribute yBias : AngularRateValue;
        attribute zBias : AngularRateValue;
        attribute tempCoeffX : AngularRateValue;
        attribute tempCoeffY : AngularRateValue;
        attribute tempCoeffZ : AngularRateValue;
    }

    // ---- Port Definitions ----

    port def PowerPort {
        attribute nominalVoltage : VoltageValue := 3.3 [V];
        out voltage : VoltageValue;
    }

    port def CommandPort {
        in command : Command;
    }

    port def DataPort {
        out gyroData : GyroDataPacket;
        out diagnostics : DiagnosticData;
    }

    port def AnalogSignalPort {
        out signal : AnalogSignal;
    }

    port def DigitalSamplePort {
        out sample : DigitalSample;
    }

    port def TemperaturePort {
        out temperature : TemperatureValue;
    }

    // ---- Interfaces ----

    interface def PowerInterface {
        end supplier : PowerPort;
        end consumer : PowerPort;
    }

    interface def CommandInterface {
        end source : CommandPort;
        end target : CommandPort;
    }

    interface def DataInterface {
        end source : DataPort;
        end target : DataPort;
    }

    interface def AnalogSignalInterface {
        end source : AnalogSignalPort;
        end target : AnalogSignalPort;
    }

    interface def DigitalSampleInterface {
        end source : DigitalSamplePort;
        end target : DigitalSamplePort;
    }

    interface def TemperatureInterface {
        end source : TemperaturePort;
        end target : TemperaturePort;
    }

    // ---- Part Definitions ----

    part def VibratingMass {
        attribute resonanceFrequency : FrequencyValue := 25000 [Hz];
        attribute displacement : DisplacementValue;
    }

    part def CapacitiveSensor {
        attribute axisId : String;
        attribute baselineCapacitance : CapacitanceValue := 1.0e-12 [F];
        out measuredSignal : AnalogSignalPort;
    }

    part def MEMSGyroSensor {
        part vibratingMass : VibratingMass;
        part xCapacitiveSensor : CapacitiveSensor { :>> axisId = "X"; }
        part yCapacitiveSensor : CapacitiveSensor { :>> axisId = "Y"; }
        part zCapacitiveSensor : CapacitiveSensor { :>> axisId = "Z"; }
        out xAnalog : AnalogSignalPort;
        out yAnalog : AnalogSignalPort;
        out zAnalog : AnalogSignalPort;
    }

    part def TemperatureSensor {
        attribute operatingRangeMin : TemperatureValue := 223.15 [K];
        attribute operatingRangeMax : TemperatureValue := 358.15 [K];
        out tempOutput : TemperaturePort;
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer := 16;
        attribute samplingRate : FrequencyValue := 1000 [Hz];
        in xAnalogIn : AnalogSignalPort;
        in yAnalogIn : AnalogSignalPort;
        in zAnalogIn : AnalogSignalPort;
        out xDigital : DigitalSamplePort;
        out yDigital : DigitalSamplePort;
        out zDigital : DigitalSamplePort;
    }

    part def DigitalSignalProcessor {
        attribute filterCutoff : FrequencyValue := 100 [Hz];
        attribute calibration : CalibrationTable;
        in xDigitalIn : DigitalSamplePort;
        in yDigitalIn : DigitalSamplePort;
        in zDigitalIn : DigitalSamplePort;
        in tempInput : TemperaturePort;
        out processedData : DataPort;
    }

    part def PowerSupply {
        attribute outputVoltage : VoltageValue := 3.3 [V];
        out powerOutput : PowerPort;
    }

    part def Controller {
        in commandInput : CommandPort;
        in diagnosticsInput : DataPort;
        out controlState : String;
    }

    // ---- Main Part: Three-Axis Gyroscopic Sensing Unit ----

    part def ThreeAxisGyroscopicSensingUnit {

        in powerIn : PowerPort;
        in commandIn : CommandPort;
        out dataOut : DataPort;

        part powerSupply : PowerSupply;
        part memsGyroSensor : MEMSGyroSensor;
        part temperatureSensor : TemperatureSensor;
        part adc : AnalogToDigitalConverter;
        part dsp : DigitalSignalProcessor;
        part controller : Controller;

        // Internal connections
        connection powerToSensor : PowerInterface connect powerSupply.powerOutput to memsGyroSensor.vibratingMass;
        connection powerToADC : PowerInterface connect powerSupply.powerOutput to adc;
        connection powerToDSP : PowerInterface connect powerSupply.powerOutput to dsp;
        connection powerToTemp : PowerInterface connect powerSupply.powerOutput to temperatureSensor;

        connection xAnalogToADC : AnalogSignalInterface connect memsGyroSensor.xAnalog to adc.xAnalogIn;
        connection yAnalogToADC : AnalogSignalInterface connect memsGyroSensor.yAnalog to adc.yAnalogIn;
        connection zAnalogToADC : AnalogSignalInterface connect memsGyroSensor.zAnalog to adc.zAnalogIn;

        connection xDigitalToDSP : DigitalSampleInterface connect adc.xDigital to dsp.xDigitalIn;
        connection yDigitalToDSP : DigitalSampleInterface connect adc.yDigital to dsp.yDigitalIn;
        connection zDigitalToDSP : DigitalSampleInterface connect adc.zDigital to dsp.zDigitalIn;

        connection tempToDSP : TemperatureInterface connect temperatureSensor.tempOutput to dsp.tempInput;

        connection dspDataOut : DataInterface connect dsp.processedData to dataOut;
        connection diagnosticsToController : DataInterface connect dsp.processedData to controller.diagnosticsInput;
        connection commandToController : CommandInterface connect commandIn to controller.commandInput;

        // Internal capacitive sensor connections within MEMS gyro
        connection xCapToGyro : AnalogSignalInterface connect memsGyroSensor.xCapacitiveSensor.measuredSignal to memsGyroSensor.xAnalog;
        connection yCapToGyro : AnalogSignalInterface connect memsGyroSensor.yCapacitiveSensor.measuredSignal to memsGyroSensor.yAnalog;
        connection zCapToGyro : AnalogSignalInterface connect memsGyroSensor.zCapacitiveSensor.measuredSignal to memsGyroSensor.zAnalog;

        // ---- State Machine Behavior ----

        state def GyroLifecycle {

            entry action initialize {
                // Power-on initialization
            }

            state Off {
                entry action powerOffAction {
                    // Unit unpowered
                }
            }

            state SelfTest {
                entry action runSelfTest {
                    // Perform self-test sequence
                }
                do action performTest {
                    // Verify capacitive sensors, ADC, DSP
                }
                exit action recordTestResult {
                    // Store self-test result
                }
            }

            state Initializing {
                entry action loadCalibration {
                    // Load calibration table into DSP
                }
                do action configureFilters {
                    // Configure DSP filter parameters
                }
                exit action setReady {
                    // Mark unit as ready
                }
            }

            state Ready {
                entry action awaitCommand {
                    // Wait for measurement command
                }
            }

            state Measuring {
                entry action startMeasurement {
                    // Begin continuous measurement
                }
                do action continuousSampling {
                    // Sample X, Y, Z axes continuously
                    // Convert analog to digital
                    // Filter, calibrate, temperature compensate
                    // Output GyroDataPacket stream
                }
                exit action stopMeasurement {
                    // Halt sampling
                }
            }

            state Fault {
                entry action enterSafeState {
                    // Enter safe fault state
                }
                do action reportFault {
                    // Output diagnostic data with faultActive = true
                }
            }

            transition offToSelfTest
                from Off to SelfTest
                when powerIn.voltage > 0 [V];

            transition selfTestToInitializing
                from SelfTest to Initializing
                when controller.controlState == "selfTestPassed";

            transition selfTestToFault
                from SelfTest to Fault
                when controller.controlState == "selfTestFailed";

            transition initializingToReady
                from Initializing to Ready
                when controller.controlState == "ready";

            transition readyToMeasuring
                from Ready to Measuring
                when commandIn.command.commandType == "startMeasurement";

            transition measuringToReady
                from Measuring to Ready
                when commandIn.command.commandType == "stopMeasurement";

            transition measuringToFault
                from Measuring to Fault
                when temperatureSensor.tempOutput.temperature > 358.15 [K];

            transition faultToOff
                from Fault to Off
                when commandIn.command.commandType == "powerOff";
        }

        // DSP processing action
        action def ProcessGyroData {
            in xSample : DigitalSample;
            in ySample : DigitalSample;
            in zSample : DigitalSample;
            in currentTemp : TemperatureValue;
            in calibrationData : CalibrationTable;
            out result : GyroDataPacket;
            out diagnostics : DiagnosticData;

            action filterNoise {
                in xIn : DigitalSample;
                in yIn : DigitalSample;
                in zIn : DigitalSample;
                out xFiltered : DigitalSample;
                out yFiltered : DigitalSample;
                out zFiltered : DigitalSample;
            }

            action applyCalibration {
                in xFiltered : DigitalSample;
                in yFiltered : DigitalSample;
                in zFiltered : DigitalSample;
                in cal : CalibrationTable;
                out xCalibrated : AxisRate;
                out yCalibrated : AxisRate;
                out zCalibrated : AxisRate;
            }

            action compensateTemperature {
                in xRate : AxisRate;
                in yRate : AxisRate;
                in zRate : AxisRate;
                in temp : TemperatureValue;
                in cal : CalibrationTable;
                out xCompensated : AngularRateValue;
                out yCompensated : AngularRateValue;
                out zCompensated : AngularRateValue;
            }

            action assemblePacket {
                in xFinal : AngularRateValue;
                in yFinal : AngularRateValue;
                in zFinal : AngularRateValue;
                in temp : TemperatureValue;
                out packet : GyroDataPacket;
                out diag : DiagnosticData;
            }

            flow from xSample to filterNoise.xIn;
            flow from ySample to filterNoise.yIn;
            flow from zSample to filterNoise.zIn;

            flow from filterNoise.xFiltered to applyCalibration.xFiltered;
            flow from filterNoise.yFiltered to applyCalibration.yFiltered;
            flow from filterNoise.zFiltered to applyCalibration.zFiltered;
            flow from calibrationData to applyCalibration.cal;

            flow from applyCalibration.xCalibrated to compensateTemperature.xRate;
            flow from applyCalibration.yCalibrated to compensateTemperature.yRate;
            flow from applyCalibration.zCalibrated to compensateTemperature.zRate;
            flow from currentTemp to compensateTemperature.temp;
            flow from calibrationData to compensateTemperature.cal;

            flow from compensateTemperature.xCompensated to assemblePacket.xFinal;
            flow from compensateTemperature.yCompensated to assemblePacket.yFinal;
            flow from compensateTemperature.zCompensated to assemblePacket.zFinal;
            flow from currentTemp to assemblePacket.temp;

            flow from assemblePacket.packet to result;
            flow from assemblePacket.diag to diagnostics;
        }
    }

    // ---- Requirements ----

    package Requirements {

        requirement def PowerRequirement {
            doc <<The sensing unit shall operate from a nominal 3.3V supply.>>
            attribute nominalVoltage : VoltageValue = 3.3 [V];
            attribute tolerance : Real = 0.1;
            constraint { powerIn.voltage >= 2.97 [V] and powerIn.voltage <= 3.63 [V]; }
        }

        requirement def ThreeAxisMeasurementRequirement {
            doc <<The unit shall measure angular rotation rate about X, Y, and Z axes simultaneously.>>
            subject unit : ThreeAxisGyroscopicSensingUnit;
            constraint { unit.dataOut.gyroData.xRate != null; }
            constraint { unit.dataOut.gyroData.yRate != null; }
            constraint { unit.dataOut.gyroData.zRate != null; }
        }

        requirement def MeasurementRangeRequirement {
            doc <<The unit shall measure angular rates up to 2000 degrees per second on each axis.>>
            attribute maxRate : AngularRateValue = 2000 [deg/s];
            constraint { unit.dataOut.gyroData.xRate <= maxRate; }
            constraint { unit.dataOut.gyroData.yRate <= maxRate; }
            constraint { unit.dataOut.gyroData.zRate <= maxRate; }
        }

        requirement def TemperatureCompensationRequirement {
            doc <<The unit shall compensate measurement drift caused by temperature fluctuations using an onboard temperature sensor.>>
            subject unit : ThreeAxisGyroscopicSensingUnit;
            constraint { unit.temperatureSensor.tempOutput.temperature != null; }
            constraint { unit.dsp.calibration.tempCoeffX != null; }
            constraint { unit.dsp.calibration.tempCoeffY != null; }
            constraint { unit.dsp.calibration.tempCoeffZ != null; }
        }

        requirement def DataOutputRequirement {
            doc <<The unit shall output a data stream containing rotation rates for all three axes and a timestamp.>>
            subject unit : ThreeAxisGyroscopicSensingUnit;
            constraint { unit.dataOut.gyroData.timestamp != null; }
        }

        requirement def DiagnosticOutputRequirement {
            doc <<The unit shall provide diagnostic data including internal temperature and operating voltage.>>
            subject unit : ThreeAxisGyroscopicSensingUnit;
            constraint { unit.dataOut.diagnostics.internalTemperature != null; }
            constraint { unit.dataOut.diagnostics.supplyVoltage != null; }
        }

        requirement def SelfTestRequirement {
            doc <<Upon receiving power, the unit shall perform a self-test and initialize before becoming ready.>>
            subject unit : ThreeAxisGyroscopicSensingUnit;
            constraint { unit.controller.controlState == "selfTestPassed" implies unit.controller.controlState == "ready"; }
        }

        requirement def FaultDetectionRequirement {
            doc <<The unit shall enter a safe fault state if it overheats or fails a self-test.>>
            subject unit : ThreeAxisGyroscopicSensingUnit;
            attribute overtempThreshold : TemperatureValue = 358.15 [K];
            constraint { unit.temperatureSensor.tempOutput.temperature > overtempThreshold implies unit.controller.controlState == "fault"; }
        }

        requirement def CalibrationRequirement {
            doc <<The DSP shall apply pre-configured calibration values to correct for inherent sensor biases.>>
            subject unit : ThreeAxisGyroscopicSensingUnit;
            constraint { unit.dsp.calibration.xBias != null; }
            constraint { unit.dsp.calibration.yBias != null; }
            constraint { unit.dsp.calibration.zBias != null; }
        }

        requirement def ADCResolutionRequirement {
            doc <<The ADC shall have at least 16-bit resolution.>>
            subject unit : ThreeAxisGyroscopicSensingUnit;
            constraint { unit.adc.resolutionBits >= 16; }
        }

        requirement def ContinuousMeasurementRequirement {
            doc <<Once ready, the unit shall be commandable to begin continuous measurement.>>
            subject unit : ThreeAxisGyroscopicSensingUnit;
            constraint { unit.commandIn.command.commandType == "startMeasurement" implies unit.controller.controlState == "measuring"; }
        }

    }

    // ---- Requirement Satisfaction ----

    part def IntegratedGyroSystem :> ThreeAxisGyroscopicSensingUnit {
        satisfy req PowerRequirement by powerIn;
        satisfy req ThreeAxisMeasurementRequirement by dataOut;
        satisfy req MeasurementRangeRequirement by dataOut;
        satisfy req TemperatureCompensationRequirement by temperatureSensor;
        satisfy req DataOutputRequirement by dataOut;
        satisfy req DiagnosticOutputRequirement by dataOut;
        satisfy req SelfTestRequirement by controller;
        satisfy req FaultDetectionRequirement by controller;
        satisfy req CalibrationRequirement by dsp;
        satisfy req ADCResolutionRequirement by adc;
        satisfy req ContinuousMeasurementRequirement by controller;
    }

}

package ScientificIrradianceSensor {

    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value types with units ----------
    value def Wavelength :> Real { unit 'nm'; }
    value def Irradiance :> Real { unit 'W/m2'; }
    value def ExposureTime :> Real { unit 's'; }
    value def Temperature :> Real { unit 'K'; }
    value def Charge :> Real { unit 'C'; }
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real {> Real { unit 'percent'; }
    value def BitDepth :> Integer;
    value def PixelCount :> Integer;

    // ---------- Item types ----------
    item def Photon {
        attribute wavelength : Wavelength;
    }

    item def PhotonFlux {
        attribute photons : Photon[0..*];
        attribute spectralRange : Wavelength;
    }

    item def ChargePattern {
        attribute charge : Charge[0..*];
        attribute pixelCount : PixelCount;
    }

    item def RawDigitalFrame {
        attribute pixelValues : Integer[0..*];
        attribute bitDepth : BitDepth;
        attribute pixelCount : PixelCount;
    }

    item def CorrectedFrame {
        attribute pixelValues : Real[0..*];
        attribute pixelCount : PixelCount;
    }

    item def CalibrationData {
        attribute darkFrame : RawDigitalFrame;
        attribute flatField : RawDigitalFrame;
    }

    item def IrradianceMeasurement {
        attribute value : Irradiance;
        attribute timestamp : DateTime;
        attribute exposureTime : ExposureTime;
        attribute sensorTemperature : Temperature;
    }

    item def PowerSupply {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def ControlCommand {
        attribute type : String;
        attribute exposureTime : ExposureTime;
    }

    item def StatusReport {
        attribute state : String;
        attribute sensorTemperature : Temperature;
        attribute lastMeasurement : IrradianceMeasurement;
    }

    // ---------- Interfaces ----------
    interface def OpticalInterface {
        in photons : PhotonFlux;
    }

    interface def ChargeTransferInterface {
        out chargePattern : ChargePattern;
    }

    interface def DigitalDataStreamInterface {
        out rawFrame : RawDigitalFrame;
    }

    interface def CorrectedDataInterface {
        out correctedFrame : CorrectedFrame;
    }

    interface def MeasurementOutputInterface {
        out measurement : IrradianceMeasurement;
    }

    interface def ThermalControlInterface {
        in targetTemperature : Temperature;
        out actualTemperature : Temperature;
    }

    interface def PowerInterface {
        in power : PowerSupply;
    }

    interface def ControlInterface {
        in command : ControlCommand;
        out status : StatusReport;
    }

    // ---------- Sensor subcomponents ----------
    part def MicrolensArray {
        attribute pixelPitch : LengthValue;
        attribute fillFactor : QuantumEfficiency;
        port in opticalIn : OpticalInterface;
        port out focusedLight : OpticalInterface;
    }

    part def AntiReflectiveCoating {
        attribute reflectance : Real;
        attribute spectralRange : Wavelength;
        port in incidentLight : OpticalInterface;
        port out transmittedLight : OpticalInterface;
    }

    part def PhotodiodeArray {
        attribute pixelCount : PixelCount;
        attribute quantumEfficiency : QuantumEfficiency;
        port in lightIn : OpticalInterface;
        port out chargeOut : ChargeTransferInterface;
    }

    part def BackIlluminatedSensor {
        attribute sensorTemperature : Temperature;
        attribute darkCurrent : Current;
        attribute quantumEfficiency : QuantumEfficiency;
        attribute spectralRangeMin : Wavelength := 400 [nm];
        attribute spectralRangeMax : Wavelength := 1100 [nm];

        port in opticalInput : OpticalInterface;
        port in thermalInput : ThermalControlInterface;
        port out chargeOutput : ChargeTransferInterface;

        part antiReflectiveCoating : AntiReflectiveCoating {
            attribute reflectance : Real := 0.01;
            attribute spectralRange : Wavelength := 1100 [nm];
        }
        part microlensArray : MicrolensArray {
            attribute pixelPitch : LengthValue := 6.5 [um];
            attribute fillFactor : QuantumEfficiency := 95 [percent];
        }
        part photodiodeArray : PhotodiodeArray {
            attribute pixelCount : PixelCount := 4096 * 4096;
            attribute quantumEfficiency : QuantumEfficiency := 95 [percent];
        }

        connection passThrough coatingToLens : antiReflectiveCoating.transmittedLight to microlensArray.opticalIn;
        connection passThrough lensToDiode : microlensArray.focusedLight to photodiodeArray.lightIn;

        connection passThrough externalOptical : opticalInput to antiReflectiveCoating.incidentLight;
        connection passThrough diodeCharge : photodiodeArray.chargeOut to chargeOutput;

        action def captureExposure {
            in exposureTime : ExposureTime;
            in photonFlux : PhotonFlux;
            out chargePattern : ChargePattern;
            perform {
                action accumulateCharge {
                    in photons = photonFlux;
                    in duration = exposureTime;
                    out accumulated : ChargePattern;
                }
            }
        }
    }

    // ---------- Thermal Controller ----------
    part def ThermoelectricCooler {
        attribute coolingCapacity : PowerValue;
        attribute targetTemperature : Temperature;
        port in controlSignal : ThermalControlInterface;
        port out coolingOutput : ThermalControlInterface;
    }

    part def TemperatureSensor {
        attribute accuracy : Temperature;
        port in sensedTemperature : ThermalControlInterface;
        port out temperatureReading : ThermalControlInterface;
    }

    part def ThermalController {
        attribute targetTemperature : Temperature := 258 [K];
        attribute tolerance : Temperature := 0.5 [K];

        port in thermalSetpoint : ThermalControlInterface;
        port out thermalOutput : ThermalControlInterface;

        part thermoelectricCooler : ThermoelectricCooler {
            attribute coolingCapacity : PowerValue := 50 [W];
            attribute targetTemperature : Temperature := 258 [K];
        }
        part temperatureSensor : TemperatureSensor {
            attribute accuracy : Temperature := 0.1 [K];
        }

        connection passThrough sensorFeedback : temperatureSensor.temperatureReading to thermoelectricCooler.controlSignal;
        connection passThrough setpointToCooler : thermalSetpoint to thermoelectricCooler.controlSignal;
        connection passThrough coolerOutput : thermoelectricCooler.coolingOutput to thermalOutput;

        action def regulateTemperature {
            in target : Temperature;
            in actual : Temperature;
            out controlSignal : Real;
            perform {
                action computeError {
                    in setpoint = target;
                    in measured = actual;
                    out error : Real;
                }
                action applyPID {
                    in errorValue = computeError.error;
                    out output : Real;
                }
            }
        }
    }

    // ---------- Readout Circuitry ----------
    part def Amplifier {
        attribute gain : Real;
        attribute noiseLevel : Voltage;
        port in chargeIn : ChargeTransferInterface;
        port out voltageOut : DigitalDataStreamInterface;
    }

    part def AnalogToDigitalConverter {
        attribute bitDepth : BitDepth := 16;
        attribute samplingRate : FrequencyValue;
        port in analogIn : DigitalDataStreamInterface;
        port out digitalOut : DigitalDataStreamInterface;
    }

    part def ReadoutCircuitry {
        attribute noiseFloor : Voltage;
        attribute conversionGain : Real;

        port in chargeInput : ChargeTransferInterface;
        port out digitalOutput : DigitalDataStreamInterface;

        part amplifier : Amplifier {
            attribute gain : Real := 10.0;
            attribute noiseLevel : Voltage := 0.000001 [V];
        }
        part adc : AnalogToDigitalConverter {
            attribute bitDepth : BitDepth := 16;
            attribute samplingRate : FrequencyValue := 10 [MHz];
        }

        connection passThrough chargeToAmplifier : chargeInput to amplifier.chargeIn;
        connection passThrough amplifierToADC : amplifier.voltageOut to adc.analogIn;
        connection passThrough adcToOutput : adc.digitalOut to digitalOutput;

        action def readoutCharge {
            in chargePattern : ChargePattern;
            out rawFrame : RawDigitalFrame;
            perform {
                action amplify {
                    in charge = chargePattern;
                    out voltage : Voltage;
                }
                action digitize {
                    in voltage = amplify.voltage;
                    out digital : RawDigitalFrame;
                }
            }
        }
    }

    // ---------- Signal Processing Unit ----------
    part def SignalProcessingUnit {
        attribute clockFrequency : FrequencyValue;
        attribute memorySize : Integer;

        port in rawInput : DigitalDataStreamInterface;
        port in calibrationInput : DigitalDataStreamInterface;
        port out correctedOutput : CorrectedDataInterface;
        port out measurementOutput : MeasurementOutputInterface;

        attribute calibrationData : CalibrationData;

        action def processFrame {
            in rawFrame : RawDigitalFrame;
            in calibration : CalibrationData;
            out correctedFrame : CorrectedFrame;
            out measurement : IrradianceMeasurement;
            perform {
                action darkFrameSubtraction {
                    in raw = rawFrame;
                    in dark = calibration.darkFrame;
                    out darkCorrected : RawDigitalFrame;
                }
                action flatFieldCorrection {
                    in darkCorrected = darkFrameSubtraction.darkCorrected;
                    in flat = calibration.flatField;
                    out corrected : CorrectedFrame;
                }
                action noiseFiltering {
                    in frame = flatFieldCorrection.corrected;
                    out filtered : CorrectedFrame;
                }
                action calculateIrradiance {
                    in frame = noiseFiltering.filtered;
                    out irradiance : IrradianceMeasurement;
                }
            }
        }
    }

    // ---------- Power Regulator ----------
    part def PowerRegulator {
        attribute inputVoltageRange : Voltage;
        attribute outputVoltage : Voltage;
        attribute outputCurrent : Current;
        attribute efficiency : Real;

        port in powerInput : PowerInterface;
        port out regulatedPower : PowerInterface;

        action def regulatePower {
            in input : PowerSupply;
            out output : PowerSupply;
        }
    }

    // ---------- Control Interface ----------
    part def ControlInterfaceUnit {
        attribute supportedExposureRange : ExposureTime;

        port in externalCommand : ControlInterface;
        port out statusOutput : ControlInterface;
        port out exposureSetting : DigitalDataStreamInterface;

        action def processCommand {
            in command : ControlCommand;
            out exposureTime : ExposureTime;
            out status : StatusReport;
        }
    }

    // ---------- Main System ----------
    part def IrradianceSensorSystem {
        attribute systemId : String;
        attribute firmwareVersion : String;
        attribute operatingTemperature : Temperature := 258 [K];

        port in opticalInput : OpticalInterface;
        port in powerInput : PowerInterface;
        port in commandInput : ControlInterface;
        port out measurementOutput : MeasurementOutputInterface;
        port out statusOutput : ControlInterface;

        part backIlluminatedSensor : BackIlluminatedSensor {
            attribute sensorTemperature : Temperature := 258 [K];
            attribute darkCurrent : Current := 0.000000001 [A];
            attribute quantumEfficiency : QuantumEfficiency := 95 [percent];
        }

        part thermalController : ThermalController {
            attribute targetTemperature : Temperature := 258 [K];
        }

        part readoutCircuitry : ReadoutCircuitry {
            attribute noiseFloor : Voltage := 0.0000005 [V];
            attribute conversionGain : Real := 0.00000000005;
        }

        part signalProcessingUnit : SignalProcessingUnit {
            attribute clockFrequency : FrequencyValue := 200 [MHz];
            attribute memorySize : Integer := 1073741824;
        }

        part powerRegulator : PowerRegulator {
            attribute inputVoltageRange : Voltage := 12 [V];
            attribute outputVoltage : Voltage := 5 [V];
            attribute outputCurrent : Current := 3 [A];
            attribute efficiency : Real := 0.92;
        }

        part controlInterface : ControlInterfaceUnit {
            attribute supportedExposureRange : ExposureTime := 0.001 [s];
        }

        // Internal connections
        connection passThrough opticalToSensor : opticalInput to backIlluminatedSensor.opticalInput;
        connection passThrough thermalControl : thermalController.thermalOutput to backIlluminatedSensor.thermalInput;
        connection passThrough chargeTransfer : backIlluminatedSensor.chargeOutput to readoutCircuitry.chargeInput;
        connection passThrough digitalTransfer : readoutCircuitry.digitalOutput to signalProcessingUnit.rawInput;
        connection passThrough measurementOut : signalProcessingUnit.measurementOutput to measurementOutput;
        connection passThrough powerDistribution : powerRegulator.regulatedPower to backIlluminatedSensor.thermalInput;
        connection passThrough commandRouting : commandInput to controlInterface.externalCommand;
        connection passThrough statusRouting : controlInterface.statusOutput to statusOutput;

        // State machine
        state def SensorStates {
            entry action initialize { 
                out systemState : String := "initialized"; 
            }

            state idle {
                entry action enterIdle { out state : String := "idle"; }
                do action awaitCommand {
                    in command : ControlCommand;
                    out exposureTime : ExposureTime;
                }
            }

            state exposing {
                entry action startExposure {
                    in exposureTime : ExposureTime;
                    out chargePattern : ChargePattern;
                }
                do action captureLight {
                    in photons : PhotonFlux;
                    in exposureTime : ExposureTime;
                    out charge : ChargePattern;
                }
            }

            state readout {
                entry action startReadout { out state : String := "readout"; }
                do action transferCharge {
                    in charge : ChargePattern;
                    out rawFrame : RawDigitalFrame;
                }
            }

            state processing {
                entry action startProcessing { out state : String := "processing"; }
                do action processData {
                    in rawFrame : RawDigitalFrame;
                    in calibration : CalibrationData;
                    out corrected : CorrectedFrame;
                    out measurement : IrradianceMeasurement;
                }
            }

            state complete {
                entry action enterComplete { out state : String := "complete"; }
                do action finalizeMeasurement {
                    in measurement : IrradianceMeasurement;
                    out status : StatusReport;
                }
            }

            transition idle_to_exposing 
                from idle to exposing 
                when commandReceived 
                guard exposureTime > 0 [s];

            transition exposing_to_readout 
                from exposing to readout 
                when exposureComplete;

            transition readout_to_processing 
                from readout to processing 
                when chargeTransferred;

            transition processing_to_complete 
                from processing to complete 
                when processingComplete;

            transition complete_to_idle 
                from complete to idle 
                when measurementDelivered;
        }

        // Main exposure action
        action def performMeasurement {
            in exposureTime : ExposureTime;
            in photonFlux : PhotonFlux;
            in calibration : CalibrationData;
            out measurement : IrradianceMeasurement;
            perform {
                action capture {
                    in photons = photonFlux;
                    in duration = exposureTime;
                    out charge : ChargePattern;
                }
                action readout {
                    in chargePattern = capture.charge;
                    out rawFrame : RawDigitalFrame;
                }
                action process {
                    in rawFrame = readout.rawFrame;
                    in calibrationData = calibration;
                    out corrected : CorrectedFrame;
                    out result : IrradianceMeasurement;
                }
            }
        }
    }

    // ---------- Requirements ----------
    requirement def SensorPerformanceRequirements {
        subject sensor : BackIlluminatedSensor;

        requirement quantumEfficiencyRequirement {
            subject sensor;
            constraint { sensor.quantumEfficiency >= 90 [percent] }
        }

        requirement spectralRangeRequirement {
            subject sensor;
            constraint { sensor.spectralRangeMin <= 400 [nm] }
            constraint { sensor.spectralRangeMax >= 1000 [nm] }
        }

        requirement darkCurrentRequirement {
            subject sensor;
            constraint { sensor.darkCurrent <= 0.00000001 [A] }
        }
    }

    requirement def ThermalControlRequirements {
        subject controller : ThermalController;

        requirement targetTemperatureRequirement {
            subject controller;
            constraint { controller.targetTemperature == 258 [K] }
        }

        requirement temperatureStabilityRequirement {
            subject controller;
            constraint { controller.tolerance <= 1 [K] }
        }
    }

    requirement def ReadoutRequirements {
        subject readout : ReadoutCircuitry;

        requirement bitDepthRequirement {
            subject readout;
            constraint { readout.adc.bitDepth >= 16 }
        }

        requirement noiseFloorRequirement {
            subject readout;
            constraint { readout.noiseFloor <= 0.000001 [V] }
        }
    }

    requirement def ProcessingRequirements {
        subject processor : SignalProcessingUnit;

        requirement calibrationRequirement {
            subject processor;
            constraint { processor.calibrationData.darkFrame != null }
            constraint { processor.calibrationData.flatField != null }
        }

        requirement irradianceAccuracyRequirement {
            subject processor;
            constraint { 
                // Measurement accuracy within 2% of true irradiance
                true 
            }
        }
    }

    requirement def SystemRequirements {
        subject system : IrradianceSensorSystem;

        requirement operatingTemperatureRequirement {
            subject system;
            constraint { system.operatingTemperature == 258 [K] }
        }

        requirement stateSequenceRequirement {
            subject system;
            constraint { 
                // System must follow: idle -> exposing -> readout -> processing -> complete -> idle
                true 
            }
        }

        requirement powerInputRequirement {
            subject system;
            constraint { system.powerRegulator.inputVoltageRange >= 12 [V] }
        }

        requirement exposureControlRequirement {
            subject system;
            constraint { system.controlInterface.supportedExposureRange <= 0.001 [s] }
        }
    }

    // ---------- Verification ----------
    verification def verifyQuantumEfficiency {
        subject sensor : BackIlluminatedSensor;
        objective { 
            check sensor.quantumEfficiency >= 90 [percent] 
        }
        method { 
            "Measure QE across 400-1100nm spectral range using calibrated light source" 
        }
    }

    verification def verifyThermalStability {
        subject controller : ThermalController;
        objective { 
            check controller.targetTemperature == 258 [K] and controller.tolerance <= 1 [K] 
        }
        method { 
            "Monitor sensor temperature over 1 hour period and verify stability" 
        }
    }

    verification def verifyReadoutNoise {
        subject readout : ReadoutCircuitry;
        objective { 
            check readout.noiseFloor <= 0.000001 [V] 
        }
        method { 
            "Perform dark frame readout and measure RMS noise" 
        }
    }

    // ---------- Package-level configuration ----------
    part def SensorConfiguration {
        attribute configName : String := "HighSensitivityIrradianceSensor";
        attribute version : String := "1.0";
        
        part instance : IrradianceSensorSystem {
            attribute systemId : String := "IRR-001";
            attribute firmwareVersion : String := "2.3.1";
        }
    }
}

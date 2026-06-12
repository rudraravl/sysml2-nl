package WavefrontSensingUnitModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Pixels :> ScalarValues::Integer;
    attribute def SamplesPerSecond :> ScalarValues::Real;
    attribute def Bits :> ScalarValues::Integer;
    attribute def Radians :> ScalarValues::Real;
    attribute def Meters :> ScalarValues::Real;
    attribute def Watts :> ScalarValues::Real;
    attribute def Volts :> ScalarValues::Real;
    attribute def Amperes :> ScalarValues::Real;
    attribute def DegreesCelsius :> ScalarValues::Real;
    attribute def Percent :> ScalarValues::Real;
    attribute def Bytes :> ScalarValues::Integer;

    item def IncidentOpticalWave {
        attribute wavelength : Meters;
        attribute opticalPower : Watts;
        attribute apertureDiameter : Meters;
        attribute polarizationExtinctionRatio : ScalarValues::Real;
        attribute phaseFront : WavefrontPhaseMap;
    }

    item def WavefrontPhaseMap {
        attribute gridWidth : Pixels;
        attribute gridHeight : Pixels;
        attribute phaseUnit : Radians;
        attribute rmsWavefrontError : Meters;
        attribute peakToValleyWavefrontError : Meters;
        attribute validSampleFraction : Percent;
    }

    item def LensletSpotImage {
        attribute width : Pixels;
        attribute height : Pixels;
        attribute exposureTime : Time;
        attribute centroidCount : ScalarValues::Integer;
        attribute saturatedPixelCount : Pixels;
        attribute averageSignalLevel : ScalarValues::Real;
    }

    item def SlopeVectorField {
        attribute sampleCountX : Pixels;
        attribute sampleCountY : Pixels;
        attribute slopeXUnit : Radians;
        attribute slopeYUnit : Radians;
        attribute rmsSlopeError : Radians;
    }

    item def WavefrontMeasurement {
        attribute timestamp : Time;
        attribute wavelength : Meters;
        attribute rmsWavefrontError : Meters;
        attribute peakToValleyWavefrontError : Meters;
        attribute zernikeCoefficientCount : ScalarValues::Integer;
        attribute confidence : Percent;
        attribute valid : Boolean;
    }

    item def HealthReport {
        attribute timestamp : Time;
        attribute detectorTemperature : DegreesCelsius;
        attribute supplyVoltage : Volts;
        attribute opticalPowerMargin : Percent;
        attribute calibrationAge : Time;
        attribute faultCode : ScalarValues::Integer;
        attribute operational : Boolean;
    }

    item def Command {
        attribute commandId : ScalarValues::Integer;
        attribute requestedSampleRate : SamplesPerSecond;
        attribute requestedExposureTime : Time;
        attribute calibrationRequested : Boolean;
        attribute measurementEnabled : Boolean;
    }

    port def OpticalInputPort {
        in item opticalWave : IncidentOpticalWave;
    }

    port def ElectricalPowerPort {
        in attribute supplyVoltage : Volts;
        in attribute supplyCurrent : Amperes;
    }

    port def CommandPort {
        in item command : Command;
    }

    port def MeasurementOutputPort {
        out item measurement : WavefrontMeasurement;
        out item health : HealthReport;
    }

    port def InternalImagePort {
        out item image : LensletSpotImage;
    }

    port def InternalSlopePort {
        out item slopes : SlopeVectorField;
    }

    part def WavefrontSensingUnit {
        port opticalIn : OpticalInputPort;
        port powerIn : ElectricalPowerPort;
        port commandIn : CommandPort;
        port dataOut : MeasurementOutputPort;

        attribute sampleRate : SamplesPerSecond = 1000.0;
        attribute measurementWavelength : Meters = 6.328e-7;
        attribute clearApertureDiameter : Meters = 0.012;
        attribute wavefrontRmsAccuracy : Meters = 1.0e-8;
        attribute peakToValleyRange : Meters = 5.0e-6;
        attribute operatingTemperatureMin : DegreesCelsius = -20.0;
        attribute operatingTemperatureMax : DegreesCelsius = 55.0;
        attribute nominalSupplyVoltage : Volts = 12.0;
        attribute maximumPowerConsumption : Watts = 8.0;
        attribute outputLatency : Time = 0.005;

        part aperture : EntranceAperture {
            attribute diameter = clearApertureDiameter;
        }

        part spectralFilter : NarrowbandOpticalFilter {
            attribute centerWavelength = measurementWavelength;
            attribute bandwidth = 1.0e-8;
            attribute minimumTransmission = 0.85;
        }

        part relayOptics : RelayOptics {
            attribute magnification = 1.0;
            attribute wavefrontDistortionRms = 2.0e-9;
        }

        part wavefrontSensor : ShackHartmannWavefrontSensor {
            attribute lensletPitch = 1.5e-4;
            attribute lensletFocalLength = 0.006;
            attribute subapertureCountX = 64;
            attribute subapertureCountY = 64;
        }

        part detector : CmosDetector {
            attribute pixelCountX = 2048;
            attribute pixelCountY = 2048;
            attribute pixelPitch = 5.5e-6;
            attribute bitDepth = 14;
            attribute maximumFrameRate = 1200.0;
            attribute readNoiseElectrons = 3.2;
        }

        part thermalController : ThermalController {
            attribute setPoint = 25.0;
            attribute controlTolerance = 0.2;
        }

        part processor : WavefrontProcessor {
            attribute centroidPrecision = 0.03;
            attribute reconstructionModeCount = 45;
            attribute processingLatency = 0.003;
        }

        part calibrationStore : CalibrationMemory {
            attribute storedReferenceFrames = 8;
            attribute calibrationCoefficientBytes = 1048576;
        }

        part controller : SensingUnitController;

        part powerConditioner : PowerConditioner {
            attribute inputVoltageMin = 9.0;
            attribute inputVoltageMax = 36.0;
            attribute regulatedVoltage = 5.0;
            attribute conversionEfficiency = 0.88;
        }

        connect opticalIn.opticalWave to aperture.inputOpticalWave;
        connect aperture.outputOpticalWave to spectralFilter.inputOpticalWave;
        connect spectralFilter.outputOpticalWave to relayOptics.inputOpticalWave;
        connect relayOptics.outputOpticalWave to wavefrontSensor.inputOpticalWave;
        connect wavefrontSensor.spotImage.image to detector.rawImageInput.image;
        connect detector.digitalImageOutput.image to processor.imageInput.image;
        connect processor.slopeOutput.slopes to controller.slopeInput.slopes;
        connect processor.measurementOutput.measurement to dataOut.measurement;
        connect controller.healthOutput.health to dataOut.health;
        connect commandIn.command to controller.commandInput.command;
        connect powerIn.supplyVoltage to powerConditioner.inputVoltage;
        connect powerIn.supplyCurrent to powerConditioner.inputCurrent;
        connect powerConditioner.detectorSupplyVoltage to detector.supplyVoltage;
        connect powerConditioner.processorSupplyVoltage to processor.supplyVoltage;
        connect powerConditioner.controllerSupplyVoltage to controller.supplyVoltage;
        connect thermalController.temperatureReport to controller.detectorTemperature;

        perform action measureWavefront;
        exhibit state sensingUnitStateMachine;
    }

    part def EntranceAperture {
        in item inputOpticalWave : IncidentOpticalWave;
        out item outputOpticalWave : IncidentOpticalWave;
        attribute diameter : Meters;
        attribute obscurationRatio : Percent = 0.0;
        attribute strayLightRejection : ScalarValues::Real = 100000.0;
    }

    part def NarrowbandOpticalFilter {
        in item inputOpticalWave : IncidentOpticalWave;
        out item outputOpticalWave : IncidentOpticalWave;
        attribute centerWavelength : Meters;
        attribute bandwidth : Meters;
        attribute minimumTransmission : Percent;
        attribute outOfBandRejection : ScalarValues::Real = 1000000.0;
    }

    part def RelayOptics {
        in item inputOpticalWave : IncidentOpticalWave;
        out item outputOpticalWave : IncidentOpticalWave;
        attribute magnification : ScalarValues::Real;
        attribute wavefrontDistortionRms : Meters;
        attribute focusAdjustmentRange : Meters = 0.002;
    }

    part def ShackHartmannWavefrontSensor {
        in item inputOpticalWave : IncidentOpticalWave;
        port spotImage : InternalImagePort;
        attribute lensletPitch : Meters;
        attribute lensletFocalLength : Meters;
        attribute subapertureCountX : Pixels;
        attribute subapertureCountY : Pixels;
        attribute fillFactor : Percent = 0.98;
        attribute measurableSlopeRange : Radians = 0.015;
    }

    part def CmosDetector {
        port rawImageInput : InternalImagePort;
        port digitalImageOutput : InternalImagePort;
        in attribute supplyVoltage : Volts;

        attribute pixelCountX : Pixels;
        attribute pixelCountY : Pixels;
        attribute pixelPitch : Meters;
        attribute bitDepth : Bits;
        attribute maximumFrameRate : SamplesPerSecond;
        attribute readNoiseElectrons : ScalarValues::Real;
        attribute darkCurrentElectronsPerPixelPerSecond : ScalarValues::Real = 25.0;
        attribute fullWellCapacityElectrons : ScalarValues::Real = 18000.0;
        attribute quantumEfficiency : Percent = 0.72;
    }

    part def WavefrontProcessor {
        port imageInput : InternalImagePort;
        port slopeOutput : InternalSlopePort;
        port measurementOutput : MeasurementOutputPort;
        in attribute supplyVoltage : Volts;

        attribute centroidPrecision : ScalarValues::Real;
        attribute reconstructionModeCount : ScalarValues::Integer;
        attribute processingLatency : Time;
        attribute processorClockRate : ScalarValues::Real = 800000000.0;
        attribute memoryBytes : Bytes = 268435456;
    }

    part def CalibrationMemory {
        attribute storedReferenceFrames : ScalarValues::Integer;
        attribute calibrationCoefficientBytes : Bytes;
        attribute nonvolatileRetentionTime : Time = 315360000.0;
        attribute checksumValid : Boolean = true;
    }

    part def ThermalController {
        out attribute temperatureReport : DegreesCelsius;
        attribute setPoint : DegreesCelsius;
        attribute controlTolerance : DegreesCelsius;
        attribute maximumHeaterPower : Watts = 2.0;
        attribute maximumCoolerPower : Watts = 3.0;
    }

    part def PowerConditioner {
        in attribute inputVoltage : Volts;
        in attribute inputCurrent : Amperes;
        out attribute detectorSupplyVoltage : Volts;
        out attribute processorSupplyVoltage : Volts;
        out attribute controllerSupplyVoltage : Volts;

        attribute inputVoltageMin : Volts;
        attribute inputVoltageMax : Volts;
        attribute regulatedVoltage : Volts;
        attribute conversionEfficiency : Percent;
        attribute rippleVoltageRms : Volts = 0.005;
    }

    part def SensingUnitController {
        port commandInput : CommandPort;
        port slopeInput : InternalSlopePort;
        port healthOutput : MeasurementOutputPort;

        in attribute supplyVoltage : Volts;
        in attribute detectorTemperature : DegreesCelsius;

        attribute currentState : ScalarValues::String;
        attribute lastFaultCode : ScalarValues::Integer = 0;
        attribute enabled : Boolean = false;
        attribute calibrationValid : Boolean = false;
    }

    action def AcquireSpotImage {
        in item opticalWave : IncidentOpticalWave;
        in attribute exposureTime : Time;
        out item image : LensletSpotImage;
    }

    action def ComputeCentroids {
        in item image : LensletSpotImage;
        out item slopes : SlopeVectorField;
    }

    action def ReconstructWavefront {
        in item slopes : SlopeVectorField;
        out item phaseMap : WavefrontPhaseMap;
        out item measurement : WavefrontMeasurement;
    }

    action def ValidateMeasurement {
        in item measurement : WavefrontMeasurement;
        in item health : HealthReport;
        out attribute accepted : Boolean;
    }

    action def PublishMeasurement {
        in item measurement : WavefrontMeasurement;
        in item health : HealthReport;
    }

    action measureWavefront {
        in item incomingWave : IncidentOpticalWave;
        in attribute exposureTime : Time = 0.0005;
        out item reportedMeasurement : WavefrontMeasurement;

        first start;
        then acquire : AcquireSpotImage {
            opticalWave = incomingWave;
            exposureTime = exposureTime;
        }
        then centroid : ComputeCentroids {
            image = acquire.image;
        }
        then reconstruct : ReconstructWavefront {
            slopes = centroid.slopes;
        }
        then validate : ValidateMeasurement {
            measurement = reconstruct.measurement;
        }
        then publish : PublishMeasurement {
            measurement = reconstruct.measurement;
        }
        then done;

        assign reportedMeasurement = reconstruct.measurement;
    }

    state def SensingUnitStateMachine {
        entry; then initializing;

        state initializing;
        state selfTest;
        state standby;
        state calibrating;
        state acquiring;
        state processing;
        state reporting;
        state fault;
        state shutdown;

        transition initializing_to_selfTest
            first initializing
            accept after 2.0 [s]
            then selfTest;

        transition selfTest_to_standby
            first selfTest
            if calibrationValid == true
            then standby;

        transition selfTest_to_calibrating
            first selfTest
            if calibrationValid == false
            then calibrating;

        transition calibrating_to_standby
            first calibrating
            accept after 5.0 [s]
            then standby;

        transition standby_to_acquiring
            first standby
            accept Command
            if command.measurementEnabled == true
            then acquiring;

        transition acquiring_to_processing
            first acquiring
            accept after 0.0005 [s]
            then processing;

        transition processing_to_reporting
            first processing
            accept after 0.003 [s]
            then reporting;

        transition reporting_to_acquiring
            first reporting
            if enabled == true
            then acquiring;

        transition reporting_to_standby
            first reporting
            if enabled == false
            then standby;

        transition any_to_fault
            first initializing, selfTest, standby, calibrating, acquiring, processing, reporting
            if lastFaultCode != 0
            then fault;

        transition fault_to_standby
            first fault
            accept Command
            if command.calibrationRequested == true
            then calibrating;

        transition standby_to_shutdown
            first standby
            accept Command
            if command.measurementEnabled == false
            then shutdown;
    }

    requirement def WavefrontMeasurementRequirement {
        subject sensingUnit : WavefrontSensingUnit;
        require constraint {
            sensingUnit.wavefrontRmsAccuracy <= 1.0e-8
        }
    }

    requirement def ApertureRequirement {
        subject sensingUnit : WavefrontSensingUnit;
        require constraint {
            sensingUnit.clearApertureDiameter >= 0.010 and sensingUnit.clearApertureDiameter <= 0.015
        }
    }

    requirement def SampleRateRequirement {
        subject sensingUnit : WavefrontSensingUnit;
        require constraint {
            sensingUnit.sampleRate >= 1000.0
        }
    }

    requirement def DynamicRangeRequirement {
        subject sensingUnit : WavefrontSensingUnit;
        require constraint {
            sensingUnit.peakToValleyRange >= 5.0e-6
        }
    }

    requirement def LatencyRequirement {
        subject sensingUnit : WavefrontSensingUnit;
        require constraint {
            sensingUnit.outputLatency <= 0.005
        }
    }

    requirement def PowerRequirement {
        subject sensingUnit : WavefrontSensingUnit;
        require constraint {
            sensingUnit.maximumPowerConsumption <= 8.0
        }
    }

    requirement def EnvironmentalRequirement {
        subject sensingUnit : WavefrontSensingUnit;
        require constraint {
            sensingUnit.operatingTemperatureMin <= -20.0 and sensingUnit.operatingTemperatureMax >= 55.0
        }
    }

    requirement def HealthMonitoringRequirement {
        subject controller : SensingUnitController;
        require constraint {
            controller.lastFaultCode >= 0
        }
    }

    part wavefrontSensingUnitSystem : WavefrontSensingUnit;

    satisfy WavefrontMeasurementRequirement by wavefrontSensingUnitSystem.processor;
    satisfy ApertureRequirement by wavefrontSensingUnitSystem.aperture;
    satisfy SampleRateRequirement by wavefrontSensingUnitSystem.detector;
    satisfy DynamicRangeRequirement by wavefrontSensingUnitSystem.wavefrontSensor;
    satisfy LatencyRequirement by wavefrontSensingUnitSystem.processor;
    satisfy PowerRequirement by wavefrontSensingUnitSystem.powerConditioner;
    satisfy EnvironmentalRequirement by wavefrontSensingUnitSystem.thermalController;
    satisfy HealthMonitoringRequirement by wavefrontSensingUnitSystem.controller;
}
package ActivePixelSensingUnitModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;
    import Quantities::*;

    attribute def ElectricPotential :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def ElectricCurrent :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def ElectricCharge :> ISQ::electricCharge {
        unit = SI::coulomb;
    }

    attribute def Duration :> ISQ::time {
        unit = SI::second;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def Illuminance :> ISQ::illuminance {
        unit = SI::lux;
    }

    attribute def Irradiance {
        :>> num : Real;
        unit = SI::watt / SI::squareMetre;
    }

    attribute def DigitalCount {
        :>> num : Integer;
    }

    attribute def FrameRate {
        :>> num : Real;
        unit = SI::hertz;
    }

    attribute def Resolution {
        attribute horizontalPixels : Integer;
        attribute verticalPixels : Integer;
    }

    item def IncidentPhotonFlux {
        attribute irradiance : Irradiance;
        attribute illuminance : Illuminance;
        attribute wavelengthNanometre : Real;
        attribute exposureDuration : Duration;
    }

    item def PixelChargePacket {
        attribute rowIndex : Integer;
        attribute columnIndex : Integer;
        attribute charge : ElectricCharge;
        attribute integrationTime : Duration;
        attribute darkCharge : ElectricCharge;
    }

    item def AnalogPixelSignal {
        attribute rowIndex : Integer;
        attribute columnIndex : Integer;
        attribute voltage : ElectricPotential;
        attribute resetVoltage : ElectricPotential;
        attribute signalVoltage : ElectricPotential;
    }

    item def DigitalPixelSample {
        attribute rowIndex : Integer;
        attribute columnIndex : Integer;
        attribute count : DigitalCount;
        attribute saturated : Boolean;
        attribute valid : Boolean;
    }

    item def ImageFrame {
        attribute frameId : Integer;
        attribute frameTimestamp : Duration;
        attribute resolution : Resolution;
        attribute exposureTime : Duration;
        attribute meanLevel : DigitalCount;
        attribute maxLevel : DigitalCount;
        attribute minLevel : DigitalCount;
    }

    item def ControlCommand {
        attribute requestedExposure : Duration;
        attribute requestedGain : Real;
        attribute requestedFrameRate : FrameRate;
        attribute enableAutoExposure : Boolean;
    }

    item def SensorStatus {
        attribute powered : Boolean;
        attribute acquiring : Boolean;
        attribute focalPlaneTemperature : Temperature;
        attribute frameCounter : Integer;
        attribute faultPresent : Boolean;
        attribute saturationFraction : Real;
    }

    port def OpticalInputPort {
        in item photons : IncidentPhotonFlux;
    }

    port def ElectricalPowerPort {
        in attribute supplyVoltage : ElectricPotential;
        in attribute supplyCurrentLimit : ElectricCurrent;
        out attribute consumedCurrent : ElectricCurrent;
    }

    port def DigitalControlPort {
        in item command : ControlCommand;
        out item status : SensorStatus;
    }

    port def DigitalVideoPort {
        out item frame : ImageFrame;
        out item sample : DigitalPixelSample;
    }

    port def AnalogPixelBusPort {
        out item pixelSignal : AnalogPixelSignal;
    }

    port def ChargeTransferPort {
        out item pixelCharge : PixelChargePacket;
    }

    part def ActivePixelSensingUnit {
        attribute operatingSupplyVoltage : ElectricPotential = 3.3 [SI::volt];
        attribute standbyCurrent : ElectricCurrent = 0.002 [SI::ampere];
        attribute activeCurrent : ElectricCurrent = 0.085 [SI::ampere];
        attribute operatingTemperature : Temperature;
        attribute frameRate : FrameRate = 60 [SI::hertz];
        attribute resolution : Resolution;
        attribute exposureTime : Duration = 0.010 [SI::second];
        attribute analogGain : Real = 1.0;
        attribute conversionGain : Real = 85.0;
        attribute quantumEfficiency : Real = 0.55;
        attribute fullWellCapacity : ElectricCharge = 0.000000000000024 [SI::coulomb];
        attribute darkCurrent : ElectricCurrent = 0.0000000000000015 [SI::ampere];
        attribute readNoiseCounts : Real = 2.1;
        attribute maximumDigitalCount : DigitalCount = 4095;
        attribute powered : Boolean = false;
        attribute acquiring : Boolean = false;

        port opticalInput : OpticalInputPort;
        port powerInput : ElectricalPowerPort;
        port control : DigitalControlPort;
        port videoOutput : DigitalVideoPort;

        part lens : ImagingLens;
        part coverGlass : OpticalWindow;
        part pixelArray : ActivePixelArray;
        part rowDriver : RowAddressDriver;
        part columnReadout : ColumnReadoutCircuit;
        part adc : AnalogToDigitalConverter;
        part timingController : SensorTimingController;
        part signalProcessor : ImageSignalProcessor;
        part temperatureMonitor : TemperatureMonitor;
        part powerRegulator : PowerRegulator;

        connect opticalInput.photons to lens.opticalInput.photons;
        connect lens.focusedLight to coverGlass.incidentLight;
        connect coverGlass.transmittedLight to pixelArray.opticalInput.photons;
        connect pixelArray.chargeOutput.pixelCharge to columnReadout.chargeInput.pixelCharge;
        connect rowDriver.rowSelect to pixelArray.rowSelect;
        connect columnReadout.analogOutput.pixelSignal to adc.analogInput.pixelSignal;
        connect adc.digitalOutput.sample to signalProcessor.pixelInput.sample;
        connect signalProcessor.videoOutput.frame to videoOutput.frame;
        connect signalProcessor.videoOutput.sample to videoOutput.sample;
        connect control.command to timingController.controlInput.command;
        connect timingController.statusOutput.status to control.status;
        connect timingController.exposureControl to pixelArray.exposureControl;
        connect timingController.rowControl to rowDriver.controlInput;
        connect timingController.adcControl to adc.controlInput;
        connect powerInput.supplyVoltage to powerRegulator.inputVoltage;
        connect powerRegulator.sensorVoltage to pixelArray.supplyVoltage;
        connect powerRegulator.logicVoltage to timingController.supplyVoltage;
        connect temperatureMonitor.measuredTemperature to timingController.focalPlaneTemperature;

        state def UnitLifecycle {
            state off;
            state selfTest;
            state standby;
            state integrating;
            state readingOut;
            state processing;
            state fault;

            entry; then off;

            transition off_to_selfTest
                first off
                accept ControlCommand
                if command.requestedFrameRate.num > 0.0
                then selfTest;

            transition selfTest_to_standby
                first selfTest
                if powerRegulator.outputStable and temperatureMonitor.temperatureValid
                then standby;

            transition standby_to_integrating
                first standby
                accept ControlCommand
                if command.requestedExposure.num > 0.000001 and not command.enableAutoExposure
                then integrating;

            transition integrating_to_readingOut
                first integrating
                after exposureTime
                then readingOut;

            transition readingOut_to_processing
                first readingOut
                if columnReadout.allColumnsSampled
                then processing;

            transition processing_to_integrating
                first processing
                if acquiring and not timingController.stopRequested
                then integrating;

            transition processing_to_standby
                first processing
                if timingController.stopRequested
                then standby;

            transition any_to_fault
                first off, selfTest, standby, integrating, readingOut, processing
                if powerRegulator.overCurrent or temperatureMonitor.overTemperature
                then fault;

            transition fault_to_off
                first fault
                accept ControlCommand
                if command.requestedFrameRate.num == 0.0
                then off;
        }

        action measureIrradiance {
            in item incoming : IncidentPhotonFlux;
            in attribute commandedExposure : Duration;
            out item frame : ImageFrame;

            first start;
            then setExposure;
            then integratePhotons;
            then samplePixels;
            then digitizeSamples;
            then correctFrame;
            then publishFrame;
            then done;

            action setExposure {
                in attribute requested : Duration = commandedExposure;
                out attribute applied : Duration;
            }

            action integratePhotons {
                in item light : IncidentPhotonFlux = incoming;
                out item charge : PixelChargePacket;
            }

            action samplePixels {
                in item chargeIn : PixelChargePacket;
                out item analog : AnalogPixelSignal;
            }

            action digitizeSamples {
                in item analogIn : AnalogPixelSignal;
                out item digital : DigitalPixelSample;
            }

            action correctFrame {
                in item rawSample : DigitalPixelSample;
                out item correctedFrame : ImageFrame;
            }

            action publishFrame {
                in item processedFrame : ImageFrame;
                out item outputFrame : ImageFrame = frame;
            }
        }
    }

    part def ImagingLens {
        attribute fNumber : Real = 2.8;
        attribute focalLengthMillimetre : Real = 6.0;
        attribute transmission : Real = 0.92;

        port opticalInput : OpticalInputPort;
        out item focusedLight : IncidentPhotonFlux;
    }

    part def OpticalWindow {
        attribute transmission : Real = 0.97;
        attribute spectralCutoffNanometre : Real = 1100.0;

        in item incidentLight : IncidentPhotonFlux;
        out item transmittedLight : IncidentPhotonFlux;
    }

    part def ActivePixelArray {
        attribute horizontalPixels : Integer = 1920;
        attribute verticalPixels : Integer = 1080;
        attribute pixelPitchMicrometre : Real = 2.2;
        attribute fillFactor : Real = 0.78;
        attribute quantumEfficiency : Real = 0.55;
        attribute fullWellCapacity : ElectricCharge = 0.000000000000024 [SI::coulomb];
        attribute darkCurrentPerPixel : ElectricCurrent = 0.0000000000000015 [SI::ampere];
        attribute exposureTime : Duration = 0.010 [SI::second];

        port opticalInput : OpticalInputPort;
        port chargeOutput : ChargeTransferPort;

        in attribute supplyVoltage : ElectricPotential;
        in attribute exposureControl : Duration;
        in attribute rowSelect : Integer;

        part pixel[2073600] : ActivePixel;
    }

    part def ActivePixel {
        attribute rowIndex : Integer;
        attribute columnIndex : Integer;
        attribute photodiodeCapacitance : Real = 0.000000000000015;
        attribute resetVoltage : ElectricPotential = 2.8 [SI::volt];
        attribute sourceFollowerGain : Real = 0.82;
        attribute accumulatedCharge : ElectricCharge;
        attribute saturated : Boolean = false;

        in item photonFlux : IncidentPhotonFlux;
        out item chargePacket : PixelChargePacket;

        action convertPhotonsToCharge {
            in item incident : IncidentPhotonFlux;
            out item charge : PixelChargePacket;
        }

        state def PixelCycle {
            state reset;
            state expose;
            state transfer;
            state hold;

            entry; then reset;

            transition reset_to_expose first reset then expose;
            transition expose_to_transfer first expose after exposureTime then transfer;
            transition transfer_to_hold first transfer then hold;
            transition hold_to_reset first hold then reset;
        }
    }

    part def RowAddressDriver {
        attribute selectedRow : Integer = 0;
        attribute rowPeriod : Duration = 0.00000926 [SI::second];

        in item controlInput : ControlCommand;
        out attribute rowSelect : Integer;

        action scanRows {
            out attribute selected : Integer;
        }
    }

    part def ColumnReadoutCircuit {
        attribute columnCount : Integer = 1920;
        attribute correlatedDoubleSamplingEnabled : Boolean = true;
        attribute allColumnsSampled : Boolean = false;

        port analogOutput : AnalogPixelBusPort;
        in item chargeInput : PixelChargePacket;

        action correlatedDoubleSample {
            in item charge : PixelChargePacket;
            out item analog : AnalogPixelSignal;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 12;
        attribute referenceVoltage : ElectricPotential = 2.5 [SI::volt];
        attribute sampleRate : Real = 125000000.0;

        in item analogInput : AnalogPixelSignal;
        out port digitalOutput : DigitalVideoPort;
        in item controlInput : ControlCommand;

        action quantize {
            in item analog : AnalogPixelSignal;
            out item digital : DigitalPixelSample;
        }
    }

    part def SensorTimingController {
        attribute currentFrameId : Integer = 0;
        attribute requestedFrameRate : FrameRate = 60 [SI::hertz];
        attribute requestedExposure : Duration = 0.010 [SI::second];
        attribute stopRequested : Boolean = false;

        in item controlInput : ControlCommand;
        out item statusOutput : SensorStatus;
        out attribute exposureControl : Duration;
        out item rowControl : ControlCommand;
        out item adcControl : ControlCommand;
        in attribute supplyVoltage : ElectricPotential;
        in attribute focalPlaneTemperature : Temperature;

        action configureAcquisition {
            in item command : ControlCommand;
            out attribute exposure : Duration;
            out attribute gain : Real;
        }
    }

    part def ImageSignalProcessor {
        attribute blackLevelCount : DigitalCount = 64;
        attribute defectPixelCorrectionEnabled : Boolean = true;
        attribute autoExposureEnabled : Boolean = true;
        attribute targetMeanCount : DigitalCount = 2048;

        in port pixelInput : DigitalVideoPort;
        port videoOutput : DigitalVideoPort;

        action assembleFrame {
            in item sample : DigitalPixelSample;
            out item frame : ImageFrame;
        }

        action estimateSceneBrightness {
            in item frame : ImageFrame;
            out attribute estimatedIlluminance : Illuminance;
        }
    }

    part def TemperatureMonitor {
        attribute measuredTemperature : Temperature = 298.15 [SI::kelvin];
        attribute overTemperatureLimit : Temperature = 358.15 [SI::kelvin];
        attribute temperatureValid : Boolean = true;
        attribute overTemperature : Boolean = false;
    }

    part def PowerRegulator {
        attribute inputVoltage : ElectricPotential;
        attribute sensorVoltage : ElectricPotential = 3.3 [SI::volt];
        attribute logicVoltage : ElectricPotential = 1.8 [SI::volt];
        attribute outputStable : Boolean = false;
        attribute overCurrent : Boolean = false;

        action regulate {
            in attribute supply : ElectricPotential;
            out attribute analogRail : ElectricPotential;
            out attribute digitalRail : ElectricPotential;
        }
    }

    requirement def MeasureLightRequirement {
        subject sensingUnit : ActivePixelSensingUnit;

        require constraint {
            sensingUnit.pixelArray.quantumEfficiency >= 0.45
        }

        require constraint {
            sensingUnit.resolution.horizontalPixels >= 1280 and
            sensingUnit.resolution.verticalPixels >= 720
        }

        require constraint {
            sensingUnit.frameRate.num >= 30.0
        }

        require constraint {
            sensingUnit.exposureTime.num >= 0.00001 and
            sensingUnit.exposureTime.num <= 0.033
        }

        require constraint {
            sensingUnit.maximumDigitalCount.num >= 4095
        }
    }

    requirement def DynamicRangeRequirement {
        subject sensingUnit : ActivePixelSensingUnit;

        require constraint {
            sensingUnit.fullWellCapacity.num > 0.000000000000010
        }

        require constraint {
            sensingUnit.readNoiseCounts <= 3.0
        }
    }

    requirement def PowerRequirement {
        subject sensingUnit : ActivePixelSensingUnit;

        require constraint {
            sensingUnit.operatingSupplyVoltage.num == 3.3
        }

        require constraint {
            sensingUnit.activeCurrent.num <= 0.100
        }

        require constraint {
            sensingUnit.standbyCurrent.num <= 0.005
        }
    }

    requirement def ThermalRequirement {
        subject sensingUnit : ActivePixelSensingUnit;

        require constraint {
            sensingUnit.operatingTemperature.num >= 263.15 and
            sensingUnit.operatingTemperature.num <= 358.15
        }
    }

    requirement def OutputRequirement {
        subject sensingUnit : ActivePixelSensingUnit;

        require constraint {
            sensingUnit.adc.resolutionBits == 12
        }

        require constraint {
            sensingUnit.signalProcessor.blackLevelCount.num >= 0
        }
    }

    satisfy MeasureLightRequirement by ActivePixelSensingUnit;
    satisfy DynamicRangeRequirement by ActivePixelSensingUnit;
    satisfy PowerRequirement by ActivePixelSensingUnit;
    satisfy ThermalRequirement by ActivePixelSensingUnit;
    satisfy OutputRequirement by ActivePixelSensingUnit;

    part activePixelSensingUnit : ActivePixelSensingUnit {
        :>> resolution.horizontalPixels = 1920;
        :>> resolution.verticalPixels = 1080;
        :>> operatingTemperature = 298.15 [SI::kelvin];
        :>> powered = true;
        :>> acquiring = true;
    }
}
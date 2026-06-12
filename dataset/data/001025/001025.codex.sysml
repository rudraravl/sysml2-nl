package DigitalHolographySystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    value def PixelCount :> Natural;
    value def FrameRate :> Real { unit = "Hz"; }
    value def OpticalPower :> Real { unit = "mW"; }
    value def Wavelength :> Real { unit = "nm"; }
    value def ExposureTime :> Real { unit = "ms"; }
    value def Distance :> Real { unit = "mm"; }
    value def Resolution :> Real { unit = "um"; }
    value def DataRate :> Real { unit = "Gb/s"; }
    value def Temperature :> Real { unit = "degC"; }

    item def CoherentLight {
        attribute wavelength : Wavelength;
        attribute power : OpticalPower;
        attribute coherenceLength : Distance;
    }

    item def ObjectLight :> CoherentLight;
    item def ReferenceLight :> CoherentLight;

    item def HologramFrame {
        attribute widthPixels : PixelCount;
        attribute heightPixels : PixelCount;
        attribute exposure : ExposureTime;
        attribute captureRate : FrameRate;
    }

    item def ReconstructedField {
        attribute lateralResolution : Resolution;
        attribute axialResolution : Resolution;
        attribute reconstructionDistance : Distance;
    }

    item def ThreeDimensionalImage {
        attribute lateralResolution : Resolution;
        attribute depthResolution : Resolution;
        attribute frameRate : FrameRate;
    }

    item def ControlCommand {
        attribute requestedFrameRate : FrameRate;
        attribute requestedExposure : ExposureTime;
        attribute reconstructionDepth : Distance;
    }

    item def DiagnosticStatus {
        attribute sensorTemperature : Temperature;
        attribute opticalPower : OpticalPower;
        attribute dataThroughput : DataRate;
    }

    port def LightOutputPort {
        out light : CoherentLight;
    }

    port def LightInputPort {
        in light : CoherentLight;
    }

    port def HologramOutputPort {
        out frame : HologramFrame;
    }

    port def HologramInputPort {
        in frame : HologramFrame;
    }

    port def ImageOutputPort {
        out image : ThreeDimensionalImage;
    }

    port def CommandInputPort {
        in command : ControlCommand;
    }

    port def StatusOutputPort {
        out status : DiagnosticStatus;
    }

    part def LaserSource {
        attribute nominalWavelength : Wavelength = 532;
        attribute maximumPower : OpticalPower = 50;
        attribute coherenceLength : Distance = 100;

        port lightOut : LightOutputPort;

        action emitCoherentBeam {
            out beam : CoherentLight;
        }

        state def LaserOperatingState {
            state off;
            state warmUp;
            state stableEmission;
            state fault;

            transition first off;
            transition off_to_warmUp
                first off then warmUp;

            transition warmUp_to_stableEmission
                first warmUp then stableEmission;

            transition stableEmission_to_fault
                first stableEmission then fault;
        }
    }

    part def BeamSplitter {
        port inputBeam : LightInputPort;
        port objectBeamOut : LightOutputPort;
        port referenceBeamOut : LightOutputPort;

        attribute splitRatio : Real = 0.5;

        action splitBeam {
            in incidentLight : CoherentLight;
            out objectBeam : ObjectLight;
            out referenceBeam : ReferenceLight;
        }
    }

    part def ObjectIlluminationOptics {
        port objectBeamIn : LightInputPort;
        port objectLightOut : LightOutputPort;

        attribute workingDistance : Distance = 75;
        attribute illuminationNumericalAperture : Real = 0.30;

        action illuminateObject {
            in objectBeam : ObjectLight;
            out scatteredObjectLight : ObjectLight;
        }
    }

    part def ReferenceArmOptics {
        port referenceBeamIn : LightInputPort;
        port referenceLightOut : LightOutputPort;

        attribute pathLengthAdjustmentRange : Distance = 25;
        attribute referenceWavefrontFlatness : Real = 0.95;

        action conditionReferenceWave {
            in referenceBeam : ReferenceLight;
            out conditionedReferenceLight : ReferenceLight;
        }
    }

    part def Interferometer {
        port objectLightIn : LightInputPort;
        port referenceLightIn : LightInputPort;
        port interferencePatternOut : HologramOutputPort;

        attribute opticalPathDifference : Distance = 0.1;
        attribute fringeVisibility : Real = 0.85;

        action formInterferencePattern {
            in objectLight : ObjectLight;
            in referenceLight : ReferenceLight;
            out hologram : HologramFrame;
        }
    }

    part def DigitalImageSensor {
        port opticalPatternIn : HologramInputPort;
        port hologramDataOut : HologramOutputPort;
        port commandIn : CommandInputPort;
        port statusOut : StatusOutputPort;

        attribute sensorWidthPixels : PixelCount = 4096;
        attribute sensorHeightPixels : PixelCount = 3000;
        attribute pixelPitch : Resolution = 3.45;
        attribute maximumFrameRate : FrameRate = 120;
        attribute minimumExposure : ExposureTime = 0.01;
        attribute maximumExposure : ExposureTime = 100;

        action captureHologram {
            in opticalPattern : HologramFrame;
            out digitalHologram : HologramFrame;
        }

        state def SensorState {
            state idle;
            state configured;
            state exposing;
            state transferring;
            state overheated;

            transition first idle;
            transition configure
                first idle then configured;

            transition startExposure
                first configured then exposing;

            transition finishExposure
                first exposing then transferring;

            transition transferComplete
                first transferring then configured;

            transition thermalFault
                first exposing then overheated;
        }
    }

    part def ReconstructionProcessor {
        port hologramIn : HologramInputPort;
        port commandIn : CommandInputPort;
        port imageOut : ImageOutputPort;
        port statusOut : StatusOutputPort;

        attribute processingThroughput : DataRate = 8;
        attribute supportedFrameRate : FrameRate = 60;
        attribute defaultReconstructionDistance : Distance = 20;

        action removeReferenceBias {
            in rawHologram : HologramFrame;
            out normalizedHologram : HologramFrame;
        }

        action propagateWavefront {
            in normalizedHologram : HologramFrame;
            out field : ReconstructedField;
        }

        action renderThreeDimensionalImage {
            in field : ReconstructedField;
            out image : ThreeDimensionalImage;
        }

        action reconstructImage {
            in rawHologram : HologramFrame;
            out image : ThreeDimensionalImage;

            first start;
            then removeReferenceBias;
            then propagateWavefront;
            then renderThreeDimensionalImage;
            then done;
        }

        state def ProcessingState {
            state waitingForFrame;
            state preprocessing;
            state numericalPropagation;
            state rendering;
            state outputReady;

            transition first waitingForFrame;
            transition frameReceived
                first waitingForFrame then preprocessing;

            transition biasRemoved
                first preprocessing then numericalPropagation;

            transition fieldComputed
                first numericalPropagation then rendering;

            transition imageRendered
                first rendering then outputReady;

            transition outputTransferred
                first outputReady then waitingForFrame;
        }
    }

    part def ControlComputer {
        port commandOut : CommandInputPort;
        port sensorStatusIn : StatusOutputPort;
        port processorStatusIn : StatusOutputPort;

        attribute targetFrameRate : FrameRate = 30;
        attribute targetExposure : ExposureTime = 2;
        attribute targetReconstructionDepth : Distance = 20;

        action configureAcquisition {
            out command : ControlCommand;
        }

        action monitorHealth {
            in sensorStatus : DiagnosticStatus;
            in processorStatus : DiagnosticStatus;
        }
    }

    part def DisplayInterface {
        port imageIn : ImageOutputPort;

        attribute displayFrameRate : FrameRate = 60;
        attribute displayWidthPixels : PixelCount = 3840;
        attribute displayHeightPixels : PixelCount = 2160;

        action presentImage {
            in image : ThreeDimensionalImage;
        }
    }

    part def DigitalHolographySystem {
        doc /* Primary function: acquire an interference pattern produced by coherent object and reference light, digitally record it as a hologram, numerically reconstruct the optical wavefront, and output a three-dimensional image of the observed object. */

        part laser : LaserSource;
        part splitter : BeamSplitter;
        part objectOptics : ObjectIlluminationOptics;
        part referenceOptics : ReferenceArmOptics;
        part interferometer : Interferometer;
        part sensor : DigitalImageSensor;
        part processor : ReconstructionProcessor;
        part controller : ControlComputer;
        part display : DisplayInterface;

        port commandIn : CommandInputPort;
        port imageOut : ImageOutputPort;
        port statusOut : StatusOutputPort;

        connect laser.lightOut to splitter.inputBeam;
        connect splitter.objectBeamOut to objectOptics.objectBeamIn;
        connect splitter.referenceBeamOut to referenceOptics.referenceBeamIn;
        connect objectOptics.objectLightOut to interferometer.objectLightIn;
        connect referenceOptics.referenceLightOut to interferometer.referenceLightIn;
        connect interferometer.interferencePatternOut to sensor.opticalPatternIn;
        connect sensor.hologramDataOut to processor.hologramIn;
        connect processor.imageOut to display.imageIn;
        connect processor.imageOut to imageOut;
        connect commandIn to sensor.commandIn;
        connect commandIn to processor.commandIn;

        perform action acquireAndReconstruct {
            first start;
            then laser.emitCoherentBeam;
            then splitter.splitBeam;
            then objectOptics.illuminateObject;
            then referenceOptics.conditionReferenceWave;
            then interferometer.formInterferencePattern;
            then sensor.captureHologram;
            then processor.reconstructImage;
            then display.presentImage;
            then done;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : DigitalHolographySystem;

        require constraint {
            system.processor.supportedFrameRate >= 30
        }

        doc /* The system shall convert digitally captured holograms into three-dimensional image output at a minimum reconstructed frame rate of 30 Hz. */
    }

    requirement def OpticalCoherenceRequirement {
        subject laser : LaserSource;

        require constraint {
            laser.coherenceLength >= 50
        }

        doc /* The laser source shall provide sufficient coherence length to support stable interference between object and reference optical paths. */
    }

    requirement def SensorResolutionRequirement {
        subject sensor : DigitalImageSensor;

        require constraint {
            sensor.sensorWidthPixels >= 2048 and sensor.sensorHeightPixels >= 2048
        }

        doc /* The image sensor shall provide at least 2048 by 2048 pixels for digital hologram acquisition. */
    }

    requirement def ReconstructionResolutionRequirement {
        subject image : ThreeDimensionalImage;

        require constraint {
            image.lateralResolution <= 5 and image.depthResolution <= 20
        }

        doc /* The reconstructed image shall provide lateral resolution of 5 um or better and depth resolution of 20 um or better. */
    }

    requirement def RealTimeThroughputRequirement {
        subject processor : ReconstructionProcessor;

        require constraint {
            processor.processingThroughput >= 4
        }

        doc /* The reconstruction processor shall sustain at least 4 Gb/s hologram processing throughput. */
    }

    requirement def ThermalMonitoringRequirement {
        subject sensor : DigitalImageSensor;

        require constraint {
            sensor.maximumFrameRate >= 60
        }

        doc /* The acquisition subsystem shall support high-speed operation while reporting diagnostic status for thermal monitoring. */
    }

}
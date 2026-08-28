package ThermalImagingSystem {
    import ScalarValues::*;

    value def Temperature :> Real;
    value def TemperatureDelta :> Real;
    value def FrameRate :> Real;
    value def Resistance :> Real;
    value def Power :> Real;

    item def InfraredRadiation;
    item def RawFrame;
    item def ThermalImage;
    item def CalibrationData;
    item def DisplayFrame;

    action def FocusInfrared { in item scene : InfraredRadiation; out item focusedIR : InfraredRadiation; }
    action def StabilizeTemperature { in item coolingPower : Power; out item arrayTemperature : Temperature; }
    action def SenseResistanceMap { in item focusedIR : InfraredRadiation; in item arrayTemperature : Temperature; out item resistanceMap : Resistance; }
    action def ReadoutAndDigitize { in item resistanceMap : Resistance; out item rawFrame : RawFrame; }
    action def CalibrateThermalFrame { in item rawFrame : RawFrame; in item calibrationData : CalibrationData; out item thermalImage : ThermalImage; }
    action def PrepareDisplayFrame { in item thermalImage : ThermalImage; in item frameRate : FrameRate; out item displayFrame : DisplayFrame; }

    action def ThermalImagingProcess {
        in item incomingScene : InfraredRadiation;
        in item stabilizedArrayTemperature : Temperature;
        in item storedCalibrationData : CalibrationData;
        in item requestedFrameRate : FrameRate;
        out item finalDisplayFrame : DisplayFrame;

        action focus : FocusInfrared {
            in item scene = incomingScene;
            out item focusedIR;
        }
        action sense : SenseResistanceMap {
            in item focusedIR;
            in item arrayTemperature = stabilizedArrayTemperature;
            out item resistanceMap;
        }
        flow from focus.focusedIR to sense.focusedIR;

        action readout : ReadoutAndDigitize {
            in item resistanceMap;
            out item rawFrame;
        }
        flow from sense.resistanceMap to readout.resistanceMap;

        action calibrate : CalibrateThermalFrame {
            in item rawFrame;
            in item calibrationData = storedCalibrationData;
            out item thermalImage;
        }
        flow from readout.rawFrame to calibrate.rawFrame;

        action prepare : PrepareDisplayFrame {
            in item thermalImage;
            in item frameRate = requestedFrameRate;
            out item displayFrame;
        }
        flow from calibrate.thermalImage to prepare.thermalImage;
        bind prepare.displayFrame = finalDisplayFrame;
    }

    part def OpticalSystem {
        in item scene : InfraredRadiation;
        out item focusedIR : InfraredRadiation;
    }
    part def ThermoelectricCooler {
        in item coolingPower : Power;
        out item arrayTemperature : Temperature;
    }
    part def MicrobolometerFPA {
        in item focusedIR : InfraredRadiation;
        in item arrayTemperature : Temperature;
        out item resistanceMap : Resistance;
        attribute resolutionX : Integer = 640;
        attribute resolutionY : Integer = 480;
        attribute sensitivity : TemperatureDelta = 0.05;
    }
    part def ROIC {
        in item resistanceMap : Resistance;
        out item rawFrame : RawFrame;
    }
    part def SignalProcessingUnit {
        in item rawFrame : RawFrame;
        in item calibrationData : CalibrationData;
        out item thermalImage : ThermalImage;
        attribute frameRate : FrameRate = 30.0;
    }
    part def DisplayInterface {
        in item thermalImage : ThermalImage;
        out item displayFrame : DisplayFrame;
    }

    part def ThermalCamera {
        in item scene : InfraredRadiation;
        in item coolingPower : Power;
        in item calibrationData : CalibrationData;
        out item displayFrame : DisplayFrame;

        part optics : OpticalSystem;
        part cooler : ThermoelectricCooler;
        part focalPlane : MicrobolometerFPA;
        part roic : ROIC;
        part processor : SignalProcessingUnit;
        part display : DisplayInterface;

        bind optics.scene = scene;
        bind cooler.coolingPower = coolingPower;
        bind processor.calibrationData = calibrationData;
        bind display.displayFrame = displayFrame;

        flow from optics.focusedIR to focalPlane.focusedIR;
        flow from cooler.arrayTemperature to focalPlane.arrayTemperature;
        flow from focalPlane.resistanceMap to roic.resistanceMap;
        flow from roic.rawFrame to processor.rawFrame;
        flow from processor.thermalImage to display.thermalImage;

        state def CameraStates {
            entry; then PowerOn;
            state PowerOn;
            transition first PowerOn then WarmUpCalibration;
            state WarmUpCalibration;
            transition first WarmUpCalibration then ActiveImaging;
            state ActiveImaging;
            transition first ActiveImaging then Standby;
            state Standby;
            transition first Standby then ActiveImaging;
            transition first ActiveImaging then Fault;
            transition first WarmUpCalibration then Fault;
            transition first Standby then Fault;
            state Fault;
        }

        state cameraState : CameraStates;
    }

    requirement def ThermalCameraSpecs {
        attribute minTempDifference : TemperatureDelta = 0.05;
        attribute frameRate : FrameRate = 30.0;
        attribute resolution : Integer = 307200;

        requirement detectTempDifferences {
            doc /* The camera must detect temperature differences as small as 0.05 K. */
        }
        requirement outputFrameRate {
            doc /* The camera must output 30 frames per second. */
        }
    }

    part thermalCamera : ThermalCamera {
        satisfy ThermalCameraSpecs;
    }
}

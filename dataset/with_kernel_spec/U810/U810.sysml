package 'Photoelasticity Analysis System' {
    private import ISQ::*;
    private import ScalarValues::*;
    private import SequenceFunctions::*;

    item def LightBeam {
        attribute wavelength : LengthValue;
    }
    item def LinearPolarizedLight :> LightBeam {
        attribute polarizationAngle : PlaneAngleValue;
    }
    item def CircularPolarizedLight :> LinearPolarizedLight;

    item def Image {
        attribute width : Natural = 2048;
        attribute height : Natural = 2048;
    }
    item def StressMap {
        attribute stressValues : PressureValue[*];
    }

    part def MonochromaticLightSource {
        out port lightOut : LightBeam;
        attribute wavelength : LengthValue = 589.3;
    }

    part def Polarizer {
        in port lightIn : LightBeam;
        out port lightOut : LinearPolarizedLight;
        attribute orientation : PlaneAngleValue;
    }

    part def QuarterWavePlate {
        in port lightIn : LinearPolarizedLight;
        out port lightOut : CircularPolarizedLight;
    }

    part def PhotoelasticSpecimen {
        in port lightIn : CircularPolarizedLight;
        out port lightOut : CircularPolarizedLight;
        in port mechanicalLoad : ForceValue;
        attribute material : String;
    }

    part def LoadingFrame {
        out port appliedForce : ForceValue;
        attribute maxForce : ForceValue = 50000;
    }

    part def Analyzer specializes Polarizer {
        attribute orientation : PlaneAngleValue = 90;
    }

    part def DigitalCamera {
        in port lightIn : CircularPolarizedLight;
        out port imageOut : Image;
        attribute resolutionX : Integer = 2048;
        attribute resolutionY : Integer = 2048;
    }

    part def ImageProcessor {
        in port imageIn : Image;
        out port stressMapOut : StressMap;
    }

    part def DisplayUnit {
        in port stressMapIn : StressMap;
    }

    part def PhotoelasticitySystem {
        part lightSource : MonochromaticLightSource;
        part polarizer1 : Polarizer { attribute orientation = 0; }
        part qwp1 : QuarterWavePlate;
        part specimen : PhotoelasticSpecimen { attribute material = "Polycarbonate"; }
        part loadingFrame : LoadingFrame;
        part qwp2 : QuarterWavePlate;
        part analyzer : Analyzer;
        part camera : DigitalCamera;
        part processor : ImageProcessor;
        part display : DisplayUnit;

        flow lightSource.lightOut to polarizer1.lightIn;
        flow polarizer1.lightOut to qwp1.lightIn;
        flow qwp1.lightOut to specimen.lightIn;
        flow loadingFrame.appliedForce to specimen.mechanicalLoad;
        flow specimen.lightOut to qwp2.lightIn;
        flow qwp2.lightOut to analyzer.lightIn;
        flow analyzer.lightOut to camera.lightIn;
        flow camera.imageOut to processor.imageIn;
        flow processor.stressMapOut to display.stressMapIn;
    }

    calc def PhaseShiftingAlgorithm {
        in inputImage : Image;
        in wavelength : LengthValue;
        in materialConstant : Real;
        return : StressMap;
    }

    action def PhotoelasticityExperiment {
        in maxLoad : ForceValue = 50000;
        in loadIncrement : ForceValue = 5000;
        in numSteps : Integer = 10;

        private attribute currentLoad : ForceValue = 0;
        out attribute stressHistory : StressMap[*] := ();

        action calibrate;
        action applyLoad {
            in targetForce : ForceValue;
        }
        action captureImage {
            out capturedImage : Image;
        }
        action processImage {
            in inputImage : Image;
            out stressMap : StressMap;
        }

        perform calibrate;
        for i in 1..numSteps {
            assign currentLoad := currentLoad + loadIncrement;
            perform applyLoad {
                in targetForce = currentLoad;
            }
            then perform captureImage;
            then perform processImage {
                in inputImage = captureImage.capturedImage;
            }
            then assign stressHistory := stressHistory->including(processImage.stressMap);
        }
    }

    state def ExperimentControl {
        state Idle;
        state Calibrating;
        state Loading;
        state Capturing;
        state Processing;
        state Checking;
        state Complete;

        initial;
        transition from initial to Idle;
        transition from Idle to Calibrating;
        transition from Calibrating to Loading;
        transition from Loading to Capturing;
        transition from Capturing to Processing;
        transition from Processing to Checking;
        transition from Checking to Loading;
        transition from Checking to Complete;
    }

    requirement def PhotoelasticitySystemRequirements {
        requirement def LightSourceReq {
            subject lightSource : MonochromaticLightSource;
            require lightSource.wavelength == 589.3;
        }
        requirement def LoadingFrameReq {
            subject loadingFrame : LoadingFrame;
            require loadingFrame.maxForce >= 50000;
        }
        requirement def CameraReq {
            subject camera : DigitalCamera;
            require camera.resolutionX >= 2048 and camera.resolutionY >= 2048;
        }
        requirement def ProcessingReq {
            subject processor : ImageProcessor;
            doc /* The image processor shall use a phase-shifting algorithm to calculate stress values. */
        }
    }

    part satisfactionContext {
        ref system : PhotoelasticitySystem;
        satisfy requirement req1 : PhotoelasticitySystemRequirements::LightSourceReq by system.lightSource;
        satisfy requirement req2 : PhotoelasticitySystemRequirements::LoadingFrameReq by system.loadingFrame;
        satisfy requirement req3 : PhotoelasticitySystemRequirements::CameraReq by system.camera;
        satisfy requirement req4 : PhotoelasticitySystemRequirements::ProcessingReq by system.processor;
    }
}

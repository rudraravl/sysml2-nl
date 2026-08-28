package DigitalHolographySystem {
    import ISQ::*;
    import ScalarValues::*;

    // Value Types
    def Wavelength :> Real { unit 'm'; }
    def OpticalPower :> Real { unit 'W'; }
    def LengthResolution :> Real { unit 'm'; }

    // Item Types
    item def CoherentLightBeam {
        attr wavelength : Wavelength;
        attr power : OpticalPower;
    }
    item def ObjectWavefront {
        attr wavelength : Wavelength;
    }
    item def ReferenceWavefront {
        attr wavelength : Wavelength;
    }
    item def HologramData {
        attr pixelCount : Integer;
    }
    item def ThreeDimensionalImage {
        attr depthResolution : LengthResolution;
    }

    // Port Definitions
    port def OpticalOutPort {
        out item beam : CoherentLightBeam;
    }
    port def OpticalInPort {
        in item beam : CoherentLightBeam;
    }
    port def WavefrontOutPort {
        out item wavefront : ObjectWavefront;
    }
    port def RefWavefrontOutPort {
        out item wavefront : ReferenceWavefront;
    }
    port def WavefrontInPort {
        in item objWavefront : ObjectWavefront;
        in item refWavefront : ReferenceWavefront;
    }
    port def DataOutPort {
        out item data : HologramData;
    }
    port def DataInPort {
        in item data : HologramData;
    }
    port def ImageOutPort {
        out item image : ThreeDimensionalImage;
    }

    // Parts
    part def LaserSource {
        port opticalOut : OpticalOutPort;
        attr wavelength : Wavelength = 532e-9 [m];
        attr power : OpticalPower = 0.05 [W];
    }

    part def BeamSplitter {
        port input : OpticalInPort;
        port objectPath : OpticalOutPort;
        port referencePath : OpticalOutPort;
    }

    part def TargetObject {
        port illuminationIn : OpticalInPort;
        port wavefrontOut : WavefrontOutPort;
    }

    part def Mirror {
        port refIn : OpticalInPort;
        port refOut : RefWavefrontOutPort;
    }

    part def InterferenceRecorder {
        port wavefrontIn : WavefrontInPort;
        port dataOut : DataOutPort;
        attr resolution : LengthResolution = 1e-6 [m];
    }

    part def NumericalReconstructor {
        port dataIn : DataInPort;
        port imageOut : ImageOutPort;
    }

    part def DigitalHolographySystem {
        part laser : LaserSource;
        part splitter : BeamSplitter;
        part target : TargetObject;
        part mirror : Mirror;
        part recorder : InterferenceRecorder;
        part reconstructor : NumericalReconstructor;

        connection opticalPath1 connect laser.opticalOut to splitter.input;
        connection opticalPath2 connect splitter.objectPath to target.illuminationIn;
        connection opticalPath3 connect splitter.referencePath to mirror.refIn;
        connection wavefrontPath1 connect target.wavefrontOut to recorder.wavefrontIn;
        connection wavefrontPath2 connect mirror.refOut to recorder.wavefrontIn;
        connection dataPath connect recorder.dataOut to reconstructor.dataIn;

        requirement def HighDepthResolution {
            subject system : DigitalHolographySystem;
            objective {
                doc /* The system shall achieve depth resolution smaller than a micrometer. */
                assert system.recorder.resolution <= 1e-6 [m];
            }
        }
        
        requirement highResReq : HighDepthResolution;

        action def CaptureHologram {
            in item objWave : ObjectWavefront;
            in item refWave : ReferenceWavefront;
            out item hologram : HologramData;
        }

        action def ReconstructImage {
            in item hologram : HologramData;
            out item image : ThreeDimensionalImage;
        }

        state def SystemStates {
            initial Idle;
            state Active {
                entry action generateBeam;
                do action captureHologram;
                exit action reconstructImage;
            }
            accept Start from Idle to Active;
            accept Complete from Active to Idle;
        }
    }
}

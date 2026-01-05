package DigitalHolographySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def CoherenceLength :> ISQ::LengthValue;
    attribute def SpatialFrequency;
    attribute def FringeContrast;
    
    item def CoherentBeam {
        attribute wavelength : ISQ::LengthValue;
        attribute power : ISQ::PowerValue;
        attribute coherenceLength : CoherenceLength;
        attribute phase : Real;
    }
    
    item def ObjectWavefront {
        attribute wavelength : ISQ::LengthValue;
    }
    
    item def ReferenceWavefront {
        attribute amplitude : Real;
        attribute phase : Real;
        attribute wavelength : ISQ::LengthValue;
    }
    
    item def InterferencePattern {
        attribute fringeSpacing : ISQ::LengthValue;
        attribute contrast : FringeContrast;
    }
    
    item def HologramData {
        attribute resolution : ISQ::LengthValue;
        attribute bitDepth : Integer;
    }
    
    item def ReconstructedWavefront {
        attribute depthRange : ISQ::LengthValue;
    }
    
    item def ThreeDImage {
        attribute quality : Real;
    }
    
    port def OpticalPort {
        out item beam : CoherentBeam;
    }
    
    port def WavefrontPort {
        in item wavefront : ObjectWavefront;
        out item wavefront : ObjectWavefront;
    }
    
    port def DataPort {
        out item data : HologramData;
    }
    
    port def ImagePort {
        out item image : ThreeDImage;
    }
    
    part def LaserSource {
        port output : OpticalPort;
        attribute wavelength : ISQ::LengthValue;
        attribute outputPower : ISQ::PowerValue;
        attribute coherenceLength : CoherenceLength;
        
        action emitLaser {
            out item laserBeam : CoherentBeam;
            then send laserBeam via output;
        }
    }
    
    part def BeamSplitter {
        port input : OpticalPort;
        port referenceOutput : OpticalPort;
        port objectOutput : OpticalPort;
        attribute splitRatio : Real;
        
        action splitBeam {
            action receive accept incomingBeam : CoherentBeam via input;
            then action divide {
                in item sourceBeam;
                out item refBeam : CoherentBeam;
                out item objBeam : CoherentBeam;
            }
            flow from divide.refBeam to sendRef.beam;
            flow from divide.objBeam to sendObj.beam;
            then action sendRef {
                in item beam : CoherentBeam;
            }
            then send sendRef.beam via referenceOutput;
            action sendObj {
                in item beam : CoherentBeam;
            }
            then send sendObj.beam via objectOutput;
        }
    }
    
    part def ObjectIlluminator {
        port illuminationInput : OpticalPort;
        port scatteredOutput : WavefrontPort;
        
        action illuminateObject {
            action receive accept illumination : CoherentBeam via illuminationInput;
            then action scatter {
                in item incident;
                out item scattered : ObjectWavefront;
            }
            then send scatter.scattered via scatteredOutput;
        }
    }
    
    part def ReferenceMirror {
        port input : OpticalPort;
        port output : OpticalPort;
        
        action reflectBeam {
            action receive accept incomingBeam : CoherentBeam via input;
            then action reflect {
                in item incident;
                out item reflected : ReferenceWavefront;
            }
            then send reflect.reflected via output;
        }
    }
    
    part def InterferenceRecorder {
        port objectInput : WavefrontPort;
        port referenceInput : OpticalPort;
        port dataOutput : DataPort;
        attribute sensorResolution : ISQ::LengthValue;
        attribute sensorSize : Integer;
        
        action recordInterference {
            action receiveObject accept objWave : ObjectWavefront via objectInput;
            action receiveReference accept refWave : ReferenceWavefront via referenceInput;
            then action interfere {
                in item object;
                in item reference;
                out item pattern : InterferencePattern;
            }
            flow from interfere.pattern to digitize.pattern;
            then action digitize {
                in item pattern : InterferencePattern;
                out item hologram : HologramData;
            }
            then send digitize.hologram via dataOutput;
        }
    }
    
    part def NumericalReconstructor {
        port hologramInput : DataPort;
        port imageOutput : ImagePort;
        
        action def DiffractionPropagation {
            in item hologramData : HologramData;
            in propagationDistance : ISQ::LengthValue;
            out item wavefront : ReconstructedWavefront;
        }
        
        action def PhaseRecovery {
            in item intensityData : HologramData;
            out item phaseData : HologramData;
        }
        
        action def VolumeReconstruction {
            in item wavefrontData : ReconstructedWavefront;
            out item volume : ThreeDImage;
        }
        
        action reconstructImage {
            action receive accept rawHologram : HologramData via hologramInput;
            then action recoverPhase : PhaseRecovery {
                in item intensityData;
                out item phaseData;
            }
            flow from recoverPhase.phaseData to propagate.hologramData;
            then action propagate : DiffractionPropagation {
                in item hologramData;
                in propagationDistance : ISQ::LengthValue;
                out item wavefront;
            }
            flow from propagate.wavefront to buildVolume.wavefrontData;
            then action buildVolume : VolumeReconstruction {
                in item wavefrontData;
                out item volume;
            }
            then send buildVolume.volume via imageOutput;
        }
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The digital holography system shall capture interference patterns 
               between object and reference wavefronts and numerically reconstruct 
               three-dimensional images of the object. */
        
        requirement <'1.1'> coherentIllumination {
            doc /* The system shall provide coherent illumination with sufficient 
                   coherence length to enable interference. */
        }
        
        requirement <'1.2'> interferenceCapture {
            doc /* The system shall record the interference pattern between object 
                   and reference wavefronts with sufficient spatial resolution. */
        }
        
        requirement <'1.3'> numericalReconstruction {
            doc /* The system shall computationally reconstruct three-dimensional 
                   images from recorded hologram data. */
        }
        
        requirement <'1.4'> depthResolution {
            doc /* The system shall provide depth resolution better than 1 micrometer. */
            attribute requiredDepthResolution : ISQ::LengthValue;
        }
    }
    
    part digitalHolographySystem {
        doc /* Digital holography system that captures interference patterns and 
               reconstructs three-dimensional images through numerical processing. */
        
        perform action holographicImaging;
        
        part laser : LaserSource {
            attribute wavelength : ISQ::LengthValue;
            attribute outputPower : ISQ::PowerValue;
            attribute coherenceLength : CoherenceLength;
        }
        
        part splitter : BeamSplitter {
            attribute splitRatio : Real;
        }
        
        part objectArm : ObjectIlluminator;
        
        part referenceArm : ReferenceMirror;
        
        part recorder : InterferenceRecorder {
            attribute sensorResolution : ISQ::LengthValue;
            attribute sensorSize : Integer;
        }
        
        part reconstructor : NumericalReconstructor;
        
        connect laser.output to splitter.input;
        connect splitter.objectOutput to objectArm.illuminationInput;
        connect splitter.referenceOutput to referenceArm.input;
        connect objectArm.scatteredOutput to recorder.objectInput;
        connect referenceArm.output to recorder.referenceInput;
        connect recorder.dataOutput to reconstructor.hologramInput;
        
        action holographicImaging {
            first start;
            then action emit;
            then action split;
            then action illuminate;
            then action reflect;
            then action record;
            then action reconstruct;
            then done;
        }
        
        satisfy PrimaryFunctionRequirement::coherentIllumination;
        satisfy PrimaryFunctionRequirement::interferenceCapture;
        satisfy PrimaryFunctionRequirement::numericalReconstruction;
        satisfy PrimaryFunctionRequirement::depthResolution;
    }
}

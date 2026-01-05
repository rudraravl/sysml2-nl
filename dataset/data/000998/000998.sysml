package BubbleChamberSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def ParticleType;
    attribute def TrackData;
    attribute def ImageData;
    attribute def ExpansionCommand;
    attribute def CompressionCommand;
    attribute def TriggerSignal;

    item def SuperheatedLiquid {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute volume : VolumeValue;
    }

    item def ChargedParticle {
        attribute particleType : ParticleType;
        attribute energy : EnergyValue;
        attribute charge : Real;
        attribute momentum : MomentumValue;
    }

    item def BubbleTrack {
        attribute trackData : TrackData;
        attribute formationTime : TimeValue;
        attribute curvature : Real;
    }

    port def LiquidPort {
        out attribute liquid : SuperheatedLiquid;
    }

    port def ParticlePort {
        in attribute particle : ChargedParticle;
    }

    port def ImagePort {
        out attribute image : ImageData;
    }

    port def ControlPort {
        in attribute expansionCmd : ExpansionCommand;
        in attribute compressionCmd : CompressionCommand;
        out attribute status : Real;
    }

    part def ChamberVessel {
        attribute operatingTemperature : TemperatureValue;
        attribute operatingPressure : PressureValue;
        attribute chamberVolume : VolumeValue;

        port liquidInterface : LiquidPort;
        port particleEntry : ParticlePort;
        port controlInterface : ControlPort;

        perform action maintainSuperheat {
            in tempTarget : TemperatureValue;
            in pressTarget : PressureValue;
            out currentStatus : Real;
        }
    }

    part def LiquidSystem {
        attribute liquidType : String;
        attribute currentTemperature : TemperatureValue;
        attribute currentPressure : PressureValue;

        port liquidOutput : LiquidPort;

        perform action supplyLiquid {
            out liquid : SuperheatedLiquid;
        }
    }

    part def ExpansionMechanism {
        attribute expansionRate : Real;
        attribute pistonPosition : LengthValue;

        perform action rapidExpansion {
            in initialPressure : PressureValue;
            out finalPressure : PressureValue;
            out expansionTime : TimeValue;
        }

        perform action recompress {
            in currentPressure : PressureValue;
            out finalPressure : PressureValue;
        }
    }

    part def MagneticFieldSystem {
        attribute fieldStrength : MagneticFluxDensityValue;
        attribute uniformity : Real;

        perform action generateField {
            in targetStrength : MagneticFluxDensityValue;
            out actualStrength : MagneticFluxDensityValue;
        }
    }

    part def ImagingSystem {
        attribute cameraCount : Integer;
        attribute frameRate : Real;
        attribute resolution : Real;

        port imageOutput : ImagePort;

        perform action captureTrackImage {
            in trackData : TrackData;
            out image : ImageData;
        }
    }

    part def IlluminationSystem {
        attribute lightIntensity : PowerValue;
        attribute flashDuration : TimeValue;

        perform action illuminateChamber {
            in trigger : TriggerSignal;
            out lightPulse : PowerValue;
        }
    }

    action def DetectParticle {
        in particle : ChargedParticle;
        out detectionSignal : TriggerSignal;
    }

    action def FormBubbles {
        in particle : ChargedParticle;
        in liquid : SuperheatedLiquid;
        out bubbleTrack : BubbleTrack;
    }

    action def ExpandChamber {
        in currentPressure : PressureValue;
        out newPressure : PressureValue;
    }

    action def CaptureImage {
        in bubbleTrack : BubbleTrack;
        out image : ImageData;
    }

    action def ResetChamber {
        in currentState : Real;
        out readyState : Real;
    }

    action def DetectParticleTrajectory {
        in incomingParticle : ChargedParticle;
        out trackData : TrackData;
        out imageData : ImageData;

        first start;
        then action detectEntry : DetectParticle {
            in particle = incomingParticle;
            out detectionSignal;
        }
        then action expandVolume : ExpandChamber {
            in currentPressure;
            out newPressure;
        }
        then action formTrack : FormBubbles {
            in particle = incomingParticle;
            in liquid;
            out bubbleTrack;
        }
        then action captureTrack : CaptureImage {
            in bubbleTrack = formTrack.bubbleTrack;
            out image;
        }
        then assign trackData := formTrack.bubbleTrack.trackData;
        then assign imageData := captureTrack.image;
        then action resetSystem : ResetChamber {
            in currentState;
            out readyState;
        }
        then done;
    }

    part bubbleChamber : ChamberVessel {
        part liquidSupply : LiquidSystem {
            perform action supplyLiquid;
        }

        part expansionUnit : ExpansionMechanism {
            perform action rapidExpansion;
            perform action recompress;
        }

        part magneticFieldUnit : MagneticFieldSystem {
            perform action generateField;
        }

        part cameras : ImagingSystem {
            perform action captureTrackImage;
        }

        part lighting : IlluminationSystem {
            perform action illuminateChamber;
        }

        perform action detectAndRecord[*] ordered {
            in incomingParticle : ChargedParticle;
            out trackData : TrackData;
            out imageData : ImageData;

            first start;
            then action detectEntry : DetectParticle {
                in particle = incomingParticle;
                out detectionSignal;
            }
            then action expandVolume : ExpandChamber {
                in currentPressure;
                out newPressure;
            }
            then action formTrack : FormBubbles {
                in particle = incomingParticle;
                in liquid;
                out bubbleTrack;
            }
            then action captureTrack : CaptureImage {
                in bubbleTrack = formTrack.bubbleTrack;
                out image;
            }
            then assign trackData := formTrack.bubbleTrack.trackData;
            then assign imageData := captureTrack.image;
            then action resetSystem : ResetChamber {
                in currentState;
                out readyState;
            }
            then done;
        }

        connection liquidFlow connect liquidSupply.liquidOutput to liquidInterface;
    }

    requirement def ParticleDetectionRequirement {
        doc /* The bubble chamber shall detect and visualize the trajectories of charged particles 
               passing through the superheated liquid medium. */

        require constraint {
            doc /* Charged particles shall ionize the liquid along their path. */
        }

        require constraint {
            doc /* Bubble formation shall occur within microseconds of chamber expansion. */
        }

        require constraint {
            doc /* Track images shall be captured before bubbles dissipate. */
        }
    }

    requirement def OperationalRequirement {
        doc /* The bubble chamber shall maintain precise control of liquid temperature and pressure 
               to ensure superheated state. */

        require constraint {
            doc /* Liquid temperature shall be maintained within 0.1 K of target. */
        }

        require constraint {
            doc /* Chamber pressure shall be controllable for rapid expansion cycles. */
        }
    }

    requirement def MagneticFieldRequirement {
        doc /* A uniform magnetic field shall be maintained to induce curvature in particle tracks 
               for momentum analysis. */

        require constraint {
            bubbleChamber.magneticFieldUnit.fieldStrength >= 1.0 [T]
        }

        require constraint {
            bubbleChamber.magneticFieldUnit.uniformity >= 0.95
        }
    }

    requirement systemRequirements {
        subject bubbleChamber;

        require particleDetectionReq : ParticleDetectionRequirement;
        require operationalControlReq : OperationalRequirement;
        require magneticFieldReq : MagneticFieldRequirement;

        doc /* The bubble chamber system shall detect charged particle trajectories by forming 
               visible bubble tracks in superheated liquid, capturing high-resolution images 
               for particle physics analysis. */
    }
}

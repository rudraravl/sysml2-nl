package ClinicalAcousticStethoscope {
    import ScalarValues::*;

    // ---- Units ----
    unit Hz;
    unit dB;
    unit g;
    unit mm;
    unit deg;

    // ---- Value Types ----
    value type Frequency {
        :>> unit = Hz;
    }
    value type SoundPressureLevel {
        :>> unit = dB;
    }
    value type Mass {
        :>> unit = g;
    }
    value type Length {
        :>> unit = mm;
    }
    value type Angle {
        :>> unit = deg;
    }

    // ---- Item Definitions ----
    item def AcousticVibration {
        attribute frequency : Frequency;
        attribute amplitude : SoundPressureLevel;
    }

    item def BodySound :> AcousticVibration {
        attribute sourceSystem : String; // cardiovascular, respiratory, gastrointestinal
    }

    item def AmbientNoise :> AcousticVibration;

    item def AcousticSignal :> AcousticVibration;

    // ---- Port Definitions ----
    port def AcousticFlowPort {
        out vibrationOut : AcousticVibration;
        in vibrationIn : AcousticVibration;
    }

    port def SkinContactPort {
        out capturedBodySound : BodySound;
    }

    port def EarDeliveryPort {
        in deliveredSound : AcousticSignal;
    }

    // ---- Requirements ----
    requirement def DiagnosticFrequencyRange {
        doc /* The stethoscope must perform effectively within 20 to 2000 Hz. */
        attribute minFrequency : Frequency = 20 [Hz];
        attribute maxFrequency : Frequency = 2000 [Hz];
        subject stethoscope : ClinicalStethoscope;
        constraint { stethoscope.operatingRange[1] >= minFrequency and stethoscope.operatingRange[2] <= maxFrequency }
    }

    requirement def LightweightDesign {
        doc /* Built to be lightweight and comfortable for extended use. */
        attribute maxMass : Mass = 200 [g];
        subject stethoscope : ClinicalStethoscope;
        constraint { stethoscope.totalMass <= maxMass }
    }

    requirement def AcousticSealRequirement {
        doc /* Earpieces create an acoustic seal to block ambient noise. */
        attribute minAttenuation : SoundPressureLevel = 20 [dB];
        subject earpiece : Earpiece;
        constraint { earpiece.siliconeTip.noiseAttenuation >= minAttenuation }
    }

    requirement def DualHeadFunction {
        doc /* Flat diaphragm for high-frequency sounds; concave bell for low-frequency sounds. */
        subject chestPiece : DualHeadChestPiece;
        constraint { chestPiece.diaphragm.optimizedRange[1] > chestPiece.bell.optimizedRange[2] }
    }

    requirement def MinimalAcousticLoss {
        doc /* Tubes transmit sound waves with minimal loss or distortion. */
        attribute maxAttenuation : SoundPressureLevel = 3 [dB];
        subject tube : AcousticTube;
        constraint { tube.attenuation <= maxAttenuation }
    }

    requirement def SimultaneousBinauralDelivery {
        doc /* Body sounds delivered clearly and simultaneously to both ears. */
        subject stethoscope : ClinicalStethoscope;
        constraint { stethoscope.leftTube.transmissionDelay == stethoscope.rightTube.transmissionDelay }
    }

    // ---- Part Definitions ----

    part def FlatDiaphragm {
        attribute diameter : Length = 45 [mm];
        attribute thickness : Length = 0.8 [mm];
        attribute optimizedRange : Frequency[2] = (100, 2000) [Hz];
        port acousticOut : AcousticFlowPort;

        action def CaptureHighFrequency {
            in bodySound : BodySound;
            out captured : AcousticSignal;
            constraint { bodySound.frequency >= 100 [Hz] }
        }
    }

    part def ConcaveBell {
        attribute depth : Length = 8 [mm];
        attribute aperture : Length = 30 [mm];
        attribute optimizedRange : Frequency[2] = (20, 200) [Hz];
        port acousticOut : AcousticFlowPort;

        action def CaptureLowFrequency {
            in bodySound : BodySound;
            out captured : AcousticSignal;
            constraint { bodySound.frequency <= 200 [Hz] }
        }
    }

    part def DualHeadChestPiece {
        attribute totalMass : Mass = 60 [g];
        attribute material : String = "Stainless Steel";

        part diaphragm : FlatDiaphragm;
        part bell : ConcaveBell;

        port skinContactPort : SkinContactPort;
        port tubeConnectionPort : AcousticFlowPort;

        attribute activeHead : String = "diaphragm";

        action def SelectHead {
            in bodySound : BodySound;
            out selectedSignal : AcousticSignal;
            decide basedOn bodySound.frequency {
                if bodySound.frequency > 200 [Hz] then {
                    perform diaphragm.CaptureHighFrequency {
                        in bodySound = bodySound;
                        out captured = selectedSignal;
                    }
                } else {
                    perform bell.CaptureLowFrequency {
                        in bodySound = bodySound;
                        out captured = selectedSignal;
                    }
                }
            }
        }

        connect skinContactPort.capturedBodySound to SelectHead.bodySound;
        connect SelectHead.selectedSignal to tubeConnectionPort.vibrationOut;
    }

    part def AcousticTube {
        attribute length : Length = 300 [mm];
        attribute innerDiameter : Length = 4 [mm];
        attribute material : String = "Flexible PVC";
        attribute attenuation : SoundPressureLevel = 2 [dB];
        attribute transmissionDelay : Real = 0.0; // ms, assumed equal for both tubes

        port chestPieceEnd : AcousticFlowPort;
        port binauralEnd : AcousticFlowPort;

        action def TransmitSound {
            in input : AcousticSignal;
            out output : AcousticSignal;
            constraint { output.amplitude >= input.amplitude - attenuation }
        }

        connect chestPieceEnd.vibrationIn to TransmitSound.input;
        connect TransmitSound.output to binauralEnd.vibrationOut;
    }

    part def SiliconeTip {
        attribute material : String = "Medical-grade Silicone";
        attribute diameter : Length = 11 [mm];
        attribute noiseAttenuation : SoundPressureLevel = 25 [dB];

        port earCanalPort : EarDeliveryPort;
        port tubeEndPort : AcousticFlowPort;

        action def CreateAcousticSeal {
            in incoming : AcousticSignal;
            in ambient : AmbientNoise;
            out delivered : AcousticSignal;
            constraint { delivered.amplitude >= incoming.amplitude }
        }

        connect tubeEndPort.vibrationIn to CreateAcousticSeal.incoming;
        connect CreateAcousticSeal.delivered to earCanalPort.deliveredSound;
    }

    part def Earpiece {
        attribute angle : Angle = 15 [deg];
        attribute material : String = "Stainless Steel";

        part siliconeTip : SiliconeTip;

        port binauralConnectionPort : AcousticFlowPort;
        port earDeliveryPort : EarDeliveryPort;

        connect binauralConnectionPort.vibrationIn to siliconeTip.tubeEndPort.vibrationIn;
        connect siliconeTip.earCanalPort.deliveredSound to earDeliveryPort.deliveredSound;
    }

    part def BinauralAssembly {
        attribute material : String = "Stainless Steel";
        attribute springTension : Real = 3.5;
        attribute totalMass : Mass = 40 [g];

        part leftEarpiece : Earpiece;
        part rightEarpiece : Earpiece;

        port leftTubePort : AcousticFlowPort;
        port rightTubePort : AcousticFlowPort;

        connect leftTubePort.vibrationIn to leftEarpiece.binauralConnectionPort.vibrationIn;
        connect rightTubePort.vibrationIn to rightEarpiece.binauralConnectionPort.vibrationIn;
    }

    // ---- Top-level Stethoscope ----
    part def ClinicalStethoscope {
        satisfy DiagnosticFrequencyRange;
        satisfy LightweightDesign;
        satisfy AcousticSealRequirement;
        satisfy DualHeadFunction;
        satisfy MinimalAcousticLoss;
        satisfy SimultaneousBinauralDelivery;

        attribute totalMass : Mass = 180 [g];
        attribute operatingRange : Frequency[2] = (20, 2000) [Hz];

        part chestPiece : DualHeadChestPiece;
        part leftTube : AcousticTube;
        part rightTube : AcousticTube;
        part binaural : BinauralAssembly;

        port patientContactPort : SkinContactPort;
        port clinicianLeftEarPort : EarDeliveryPort;
        port clinicianRightEarPort : EarDeliveryPort;

        connect patientContactPort.capturedBodySound to chestPiece.skinContactPort.capturedBodySound;
        connect chestPiece.tubeConnectionPort.vibrationOut to leftTube.chestPieceEnd.vibrationIn;
        connect chestPiece.tubeConnectionPort.vibrationOut to rightTube.chestPieceEnd.vibrationIn;
        connect leftTube.binauralEnd.vibrationOut to binaural.leftTubePort.vibrationIn;
        connect rightTube.binauralEnd.vibrationOut to binaural.rightTubePort.vibrationIn;
        connect binaural.leftEarpiece.earDeliveryPort.deliveredSound to clinicianLeftEarPort.deliveredSound;
        connect binaural.rightEarpiece.earDeliveryPort.deliveredSound to clinicianRightEarPort.deliveredSound;

        // ---- State Machine ----
        state def OperationalState {
            entry; then idle;

            state idle {
                doc /* Stethoscope is not in use. */
                entry;
            }

            state activeListening {
                doc /* Chest-piece is positioned on a patient for auscultation. */
                entry;
                do perform AuscultationProcess;
            }

            transition idle to activeListening
                when chestPiece.skinContactPort.capturedBodySound != null;

            transition activeListening to idle
                when chestPiece.skinContactPort.capturedBodySound == null;
        }

        // ---- Behavior ----
        action def AuscultationProcess {
            in bodySound : BodySound @ patientContactPort;
            out leftEarSound : AcousticSignal @ clinicianLeftEarPort;
            out rightEarSound : AcousticSignal @ clinicianRightEarPort;

            action capture : DualHeadChestPiece::SelectHead {
                in bodySound = bodySound;
            }

            action transmitLeft : AcousticTube::TransmitSound;
            action transmitRight : AcousticTube::TransmitSound;

            action sealLeft : SiliconeTip::CreateAcousticSeal;
            action sealRight : SiliconeTip::CreateAcousticSeal;

            flow capture.selectedSignal to transmitLeft.input;
            flow capture.selectedSignal to transmitRight.input;
            flow transmitLeft.output to sealLeft.incoming;
            flow transmitRight.output to sealRight.incoming;
            flow sealLeft.delivered to leftEarSound;
            flow sealRight.delivered to rightEarSound;
        }

        // ---- Verification Actions ----
        action def VerifyFrequencyRange {
            in stethoscope : ClinicalStethoscope;
            out pass : Boolean;
            constraint { pass == (stethoscope.operatingRange[1] >= 20 [Hz] and stethoscope.operatingRange[2] <= 2000 [Hz]) }
        }

        action def VerifyMass {
            in stethoscope : ClinicalStethoscope;
            out pass : Boolean;
            constraint { pass == (stethoscope.totalMass <= 200 [g]) }
        }
    }
}

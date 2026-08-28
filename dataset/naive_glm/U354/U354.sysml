package PinardHornFetalAuscultationSystem {
    import ScalarValues::*;

    // ===== Units =====
    unit mm;
    unit Pa;
    unit bpm;
    unit s;
    unit Hz;

    // ===== Value Types =====
    value type Length :> Real {
        unit mm;
    }

    value type Diameter :> Real {
        unit mm;
    }

    value type SoundPressure :> Real {
        unit Pa;
    }

    value type HeartRate :> Real {
        unit bpm;
    }

    value type Duration :> Real {
        unit s;
    }

    value type Frequency :> Real {
        unit Hz;
    }

    value type AcousticGain :> Real;

    // ===== Item Definitions =====
    item def AcousticWave {
        attribute frequency : Frequency;
        attribute pressure : SoundPressure;
    }

    item def FetalHeartbeat :> AcousticWave {
        attribute heartRate : HeartRate;
    }

    item def AmbientSound :> AcousticWave;

    item def AmplifiedSound :> AcousticWave {
        attribute gain : AcousticGain;
    }

    // ===== Port Definitions =====
    port def AcousticInPort {
        in item wave : AcousticWave;
    }

    port def AcousticOutPort {
        out item wave : AcousticWave;
    }

    // ===== Part: Bell (Sound Collector) =====
    part def Bell {
        attribute bellDiameter : Length = 50.0;
        attribute bellDepth : Length = 30.0;
        attribute material : String = "Wood";
        attribute isSterile : Boolean = true;
        attribute collectionEfficiency : Real = 0.8;

        port acousticIn : AcousticInPort;
        port acousticOut : AcousticOutPort;

        action collectSound {
            in item incomingWave : AcousticWave;
            out item collectedWave : AcousticWave;
        }
    }

    // ===== Part: ResonatingTube (Acoustic Amplifier) =====
    part def ResonatingTube {
        attribute tubeLength : Length = 160.0;
        attribute tubeDiameter : Diameter = 15.0;
        attribute resonanceFreq : Frequency = 120.0;
        attribute amplificationFactor : AcousticGain = 10.0;

        port acousticIn : AcousticInPort;
        port acousticOut : AcousticOutPort;

        action amplifySound {
            in item incomingWave : AcousticWave;
            out item amplifiedWave : AmplifiedSound;
        }
    }

    // ===== Part: Earpiece (Sound Delivery) =====
    part def Earpiece {
        attribute earpieceDiameter : Diameter = 25.0;
        attribute isFlat : Boolean = true;
        attribute contactSurface : String = "Smooth";

        port acousticIn : AcousticInPort;
        port acousticOut : AcousticOutPort;

        action deliverSound {
            in item amplifiedWave : AmplifiedSound;
            out item deliveredWave : AmplifiedSound;
        }
    }

    // ===== Part: PinardHorn (System) =====
    part def PinardHorn {
        attribute totalLength : Length = 190.0;
        attribute isPortable : Boolean = true;
        attribute requiresNoPower : Boolean = true;
        attribute isNonInvasive : Boolean = true;
        attribute weight : Real = 0.15;

        part bell : Bell;
        part tube : ResonatingTube;
        part earpiece : Earpiece;

        port patientInterface : AcousticInPort;
        port clinicianInterface : AcousticOutPort;

        connection bellInput from patientInterface to bell.acousticIn;
        connection soundCollection from bell.acousticOut to tube.acousticIn;
        connection soundAmplification from tube.acousticOut to earpiece.acousticIn;
        connection earpieceOutput from earpiece.acousticOut to clinicianInterface;

        action performAuscultation {
            // Full acoustic path: collect, amplify, deliver
        }
    }

    // ===== Actor: Clinician =====
    part def Clinician {
        attribute isTrained : Boolean = true;
        attribute hasExperience : Boolean = true;
        attribute detectionThreshold : SoundPressure = 0.01;
    }

    // ===== Actor: Patient =====
    part def Patient {
        attribute gestationalAgeWeeks : Integer;
        attribute abdomenThickness : Length;
        attribute fetalPosition : String;
    }

    // ===== Auscultation Procedure =====
    part def AuscultationProcedure {
        part clinician : Clinician;
        part patient : Patient;
        part horn : PinardHorn;

        attribute detectedHeartbeat : Boolean = false;
        attribute clearHeartbeat : Boolean = false;
        attribute soundTooWeak : Boolean = false;
        attribute beatCount : Integer = 0;
        attribute measurementDuration : Duration = 60.0;
        attribute measuredHeartRate : HeartRate;
        attribute positionAdjustments : Integer = 0;
        attribute maxAdjustments : Integer = 5;

        action positionHorn {
            // Position horn on maternal abdomen to locate fetal heartbeat
        }

        action listenForHeartbeat {
            // Listen through earpiece for fetal heart sounds
        }

        action adjustPosition {
            // Adjust horn position when sound is too weak
        }

        action countBeats {
            // Count beats over a fixed measurement period
        }

        action calculateHeartRate {
            // Compute BPM from beat count and measurement duration
        }

        action recordResult {
            // Record fetal heart rate measurement
        }

        state auscultationStateMachine {
            state initial;
            state positioning;
            state listening;
            state adjusting;
            state counting;
            state calculating;
            state recording;
            state complete;

            transition from initial to positioning;
            transition from positioning to listening when detectedHeartbeat == true;
            transition from listening to adjusting when soundTooWeak == true;
            transition from adjusting to positioning;
            transition from listening to counting when clearHeartbeat == true;
            transition from counting to calculating;
            transition from calculating to recording;
            transition from recording to complete;
        }
    }

    // ===== Requirements =====
    requirement def FetalAuscultationRequirements {
        subject pinardHorn : PinardHorn;

        requirement acousticCollection {
            doc "The bell shall collect fetal heartbeat sounds through the maternal abdominal wall.";
        }

        requirement acousticAmplification {
            doc "The resonating tube shall amplify sound waves through natural resonance without any external power source.";
        }

        requirement soundDelivery {
            doc "The earpiece shall deliver amplified sound to the clinician's ear for clear auscultation.";
        }

        requirement noPowerRequired {
            doc "The system shall operate without any electrical or battery power source.";
        }

        requirement portability {
            doc "The system shall be lightweight and portable for use in clinical and field settings.";
        }

        requirement nonInvasiveSafety {
            doc "The system shall be non-invasive and safe for routine fetal assessment during pregnancy.";
        }

        requirement usabilityByTrainedClinician {
            doc "The system shall be usable by trained midwives and clinicians for fetal heart rate monitoring.";
        }

        requirement mechanicalOnly {
            doc "The system shall rely solely on physical acoustics with no electronic components.";
        }

        requirement heartRateRange {
            doc "The system shall enable detection of fetal heart rates in the range of 110 to 160 bpm.";
        }
    }

    // ===== Satisfaction =====
    satisfaction acousticCollection by PinardHorn::bell;
    satisfaction acousticAmplification by PinardHorn::tube;
    satisfaction soundDelivery by PinardHorn::earpiece;
}

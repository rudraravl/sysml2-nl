package SextantNavigationSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----
    value def AngleValue :> Real { unit 'arcsec'; }
    value def DegreeAngle :> Real { unit 'deg'; }
    value def ArcMinuteAngle :> Real { unit 'arcmin'; }
    value def TimeUTC :> DateTime;
    value def HeightAboveSeaLevel :> Real { unit 'm'; }
    value def Magnification :> Real { unit 'x'; }
    value def Length :> Real { unit 'mm'; }
    value def Latitude :> Real { unit 'deg'; }
    value def Longitude :> Real { unit 'deg'; }
    value def RefractionCorrection :> Real { unit 'arcmin'; }
    value def IndexError :> Real { unit 'arcmin'; }
    value def DipCorrection :> Real { unit 'arcmin'; }

    // ---- Item Types ----
    item def LightRay;
    item def CelestialBody {
        attribute name : String;
        attribute declination : DegreeAngle;
        attribute hourAngle : DegreeAngle;
    }
    item def SightRecord {
        attribute bodyName : String;
        attribute measuredAngle : DegreeAngle;
        attribute timeOfSight : TimeUTC;
        attribute correctedAngle : DegreeAngle;
        attribute indexError : IndexError;
        attribute dipCorrection : DipCorrection;
        attribute refractionCorrection : RefractionCorrection;
    }
    item def LineOfPosition {
        attribute azimuth : DegreeAngle;
        attribute intercept : Length;
    }
    item def GeographicFix {
        attribute latitude : Latitude;
        attribute longitude : Longitude;
    }

    // ---- Port Definitions ----
    port def OpticalPort {
        in item ray : LightRay;
    }
    port def AdjustmentPort {
        in item adjustmentCmd : DegreeAngle;
        out item currentAngle : DegreeAngle;
    }
    port def ReadingPort {
        out item coarseAngle : DegreeAngle;
        out item fineAngle : ArcMinuteAngle;
    }
    port def SightDataPort {
        out item record : SightRecord;
    }

    // ---- Components ----
    part def Frame {
        attribute material : String = "brass";
        attribute mass : Real { unit 'kg'; }
        attribute length : Length;
    }

    part def Telescope {
        port in opticalInput : OpticalPort;
        attribute magnification : Magnification = 6;
        attribute focalLength : Length;
        action def View :> Action {
            in ray : LightRay;
            out magnifiedImage : LightRay;
        }
    }

    part def IndexMirror {
        port in incomingRay : OpticalPort;
        port out reflectedRay : OpticalPort;
        attribute reflectivity : Real;
        attribute rotationAngle : DegreeAngle;
        action def Reflect :> Action {
            in ray : LightRay;
            in angle : DegreeAngle;
            out reflected : LightRay;
        }
    }

    part def HorizonGlass {
        port in reflectedInput : OpticalPort;
        port in directInput : OpticalPort;
        port out combinedOutput : OpticalPort;
        attribute halfSilvered : Boolean = true;
        action def Combine :> Action {
            in reflected : LightRay;
            in direct : LightRay;
            out combined : LightRay;
        }
    }

    part def ShadingFilter {
        attribute density : Real;
        attribute engaged : Boolean;
        action def Attenuate :> Action {
            in ray : LightRay;
            out attenuated : LightRay;
        }
    }

    part def ShadingFilterAssembly {
        part sunFilter : ShadingFilter { density = 3.0; }
        part moonFilter : ShadingFilter { density = 1.0; }
        part starFilter : ShadingFilter { density = 0.5; }
    }

    part def IndexArm {
        port adjustment : AdjustmentPort;
        attribute locked : Boolean;
        attribute position : DegreeAngle;
        action def Swing :> Action {
            in target : DegreeAngle;
            out achieved : DegreeAngle;
        }
        action def Lock :> Action {
            in position : DegreeAngle;
        }
    }

    part def ArcScale {
        port reading : ReadingPort;
        attribute rangeMin : DegreeAngle = 0;
        attribute rangeMax : DegreeAngle = 120;
        attribute resolution : ArcMinuteAngle = 10;
        action def ReadCoarse :> Action {
            out angle : DegreeAngle;
        }
    }

    part def MicrometerDrum {
        port reading : ReadingPort;
        attribute resolution : ArcMinuteAngle = 1;
        attribute vernierResolution : ArcMinuteAngle = 0.2;
        action def ReadFine :> Action {
            out angle : ArcMinuteAngle;
        }
    }

    // ---- The Sextant ----
    part def Sextant {
        part frame : Frame {
            material = "brass";
            mass = 1.5;
            length = 180;
        }
        part telescope : Telescope {
            magnification = 6;
            focalLength = 90;
        }
        part indexMirror : IndexMirror;
        part horizonGlass : HorizonGlass;
        part indexArm : IndexArm;
        part arcScale : ArcScale;
        part micrometerDrum : MicrometerDrum;
        part filters : ShadingFilterAssembly;

        port celestialInput : OpticalPort;
        port horizonInput : OpticalPort;
        port eyepiece : OpticalPort;
        port dataOut : SightDataPort;
        port control : AdjustmentPort;

        connection celestialToIndex connect celestialInput to indexMirror.incomingRay;
        connection indexToHorizon connect indexMirror.reflectedRay to horizonGlass.reflectedInput;
        connection horizonDirect connect horizonInput to horizonGlass.directInput;
        connection horizonToTelescope connect horizonGlass.combinedOutput to telescope.opticalInput;
        connection telescopeToEye connect telescope.opticalInput to eyepiece;
        connection armControl connect control to indexArm.adjustment;
        connection armToMirror connect indexArm.adjustment.currentAngle to indexMirror.rotationAngle;
        connection coarseReading connect arcScale.reading to micrometerDrum.reading;
        connection fineReading connect micrometerDrum.reading to dataOut;

        attribute indexError : IndexError;
        attribute observerHeight : HeightAboveSeaLevel;

        // Operational State Machine
        state def OperationalState {
            entry action initialize;
            state stowed;
            state ready;
            state sighting;
            state aligning;
            state locked;
            state recording;

            transition stowed_to_ready first stowed -> ready
                when (control.adjustmentCmd > 0) {
                    do action prepareInstrument;
                }
            transition ready_to_sighting ready -> sighting
                when (control.adjustmentCmd > 0) {
                    do action beginSight;
                }
            transition sighting_to_aligning sighting -> aligning
                when (indexArm.position > 0) {
                    do action alignImages;
                }
            transition aligning_to_locked aligning -> locked
                when (indexArm.locked == true) {
                    do action captureReading;
                }
            transition locked_to_recording locked -> recording {
                do action recordSight;
            }
            transition recording_to_ready recording -> ready {
                do action resetForNextSight;
            }
            transition any_to_stowed ready -> stowed
                when (control.adjustmentCmd == 0) {
                    do action stowInstrument;
                }
        }

        exhibit state operational : OperationalState;

        action def initialize :> Action;
        action def prepareInstrument :> Action;
        action def beginSight :> Action;
        action def alignImages :> Action;
        action def captureReading :> Action {
            in coarse : DegreeAngle;
            in fine : ArcMinuteAngle;
            out record : SightRecord;
        }
        action def recordSight :> Action;
        action def resetForNextSight :> Action;
        action def stowInstrument :> Action;

        // Correction calculation action
        action def ApplyCorrections :> Action {
            in raw : SightRecord;
            in indexErr : IndexError;
            in dip : DipCorrection;
            in refraction : RefractionCorrection;
            out corrected : SightRecord;
        }
    }

    // ---- Navigator ----
    part def Navigator {
        part instrument : Sextant;
        attribute eyeHeight : HeightAboveSeaLevel = 2.0;
        attribute experienceLevel : String;

        action def TakeSight :> Action {
            in body : CelestialBody;
            out record : SightRecord;
        }
        action def CorrectSight :> Action {
            in raw : SightRecord;
            out corrected : SightRecord;
        }
        action def ComputeLOP :> Action {
            in sight : SightRecord;
            out lop : LineOfPosition;
        }
        action def DetermineFix :> Action {
            in lop1 : LineOfPosition;
            in lop2 : LineOfPosition;
            out fix : GeographicFix;
        }

        action def CelestialNavigationProcess :> Action {
            in body1 : CelestialBody;
            in body2 : CelestialBody;
            out fix : GeographicFix;
            flow takeSight1 : TakeSight {
                in body := body1;
            }
            flow takeSight2 : TakeSight {
                in body := body2;
            }
            flow correct1 : CorrectSight {
                in raw := takeSight1.record;
            }
            flow correct2 : CorrectSight {
                in raw := takeSight2.record;
            }
            flow lop1 : ComputeLOP {
                in sight := correct1.corrected;
            }
            flow lop2 : ComputeLOP {
                in sight := correct2.corrected;
            }
            flow fixCalc : DetermineFix {
                in lop1 := lop1.lop;
                in lop2 := lop2.lop;
                out fix := fix;
            }
        }

        perform navigation : CelestialNavigationProcess;
    }

    // ---- Requirements ----
    requirement def MeasurementAccuracy {
        subject sextant : Sextant;
        objective {
            doc "The sextant shall measure celestial body angles with an accuracy of at least 10 arcseconds."
        }
        require sextant.micrometerDrum.vernierResolution <= 0.2
    }

    requirement def DualSightFix {
        subject navigator : Navigator;
        objective {
            doc "The navigator shall determine a geographic fix using at least two celestial sights taken at distinct times."
        }
    }

    requirement def OperationalStates {
        subject sextant : Sextant;
        objective {
            doc "The sextant shall transition through stowed, ready, sighting, aligning, locked, and recording states during operation."
        }
    }

    requirement def FilterCapability {
        subject sextant : Sextant;
        objective {
            doc "The sextant shall provide shading filters to attenuate bright celestial bodies such as the sun."
        }
        require sextant.filters.sunFilter.density >= 3.0
    }

    requirement def IndexArmLocking {
        subject sextant : Sextant;
        objective {
            doc "The index arm shall be lockable to preserve the measured angle until read."
        }
        require sextant.indexArm.locked == true
    }

    // ---- Satisfy relationships ----
    satisfaction def AccuracySatisfaction {
        satisfy MeasurementAccuracy by Sextant::micrometerDrum;
    }
    satisfaction def FilterSatisfaction {
        satisfy FilterCapability by Sextant::filters;
    }
    satisfaction def LockSatisfaction {
        satisfy IndexArmLocking by Sextant::indexArm;
    }

    // ---- Instantiation ----
    part navigationSystem : Navigator {
        instrument.indexError = 0.5;
        instrument.observerHeight = 2.0;
        eyeHeight = 2.0;
        experienceLevel = "master";
    }
}


Note: The model above is complete SysML v2 concrete syntax. However, I realize I should not include markdown fences per the instructions. Let me provide the final output without fences.package SextantNavigationSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----
    value def AngleValue :> Real { unit 'arcsec'; }
    value def DegreeAngle :> Real { unit 'deg'; }
    value def ArcMinuteAngle :> Real { unit 'arcmin'; }
    value def TimeUTC :> DateTime;
    value def HeightAboveSeaLevel :> Real { unit 'm'; }
    value def Magnification :> Real { unit 'x'; }
    value def Length :> Real { unit 'mm'; }
    value def Latitude :> Real { unit 'deg'; }
    value def Longitude :> Real { unit 'deg'; }
    value def RefractionCorrection :> Real { unit 'arcmin'; }
    value def IndexError :> Real { unit 'arcmin'; }
    value def DipCorrection :> Real { unit 'arcmin'; }

    // ---- Item Types ----
    item def LightRay;
    item def CelestialBody {
        attribute name : String;
        attribute declination : DegreeAngle;
        attribute hourAngle : DegreeAngle;
    }
    item def SightRecord {
        attribute bodyName : String;
        attribute measuredAngle : DegreeAngle;
        attribute timeOfSight : TimeUTC;
        attribute correctedAngle : DegreeAngle;
        attribute indexError : IndexError;
        attribute dipCorrection : DipCorrection;
        attribute refractionCorrection : RefractionCorrection;
    }
    item def LineOfPosition {
        attribute azimuth : DegreeAngle;
        attribute intercept : Length;
    }
    item def GeographicFix {
        attribute latitude : Latitude;
        attribute longitude : Longitude;
    }

    // ---- Port Definitions ----
    port def OpticalPort {
        in item ray : LightRay;
    }
    port def AdjustmentPort {
        in item adjustmentCmd : DegreeAngle;
        out item currentAngle : DegreeAngle;
    }
    port def ReadingPort {
        out item coarseAngle : DegreeAngle;
        out item fineAngle : ArcMinuteAngle;
    }
    port def SightDataPort {
        out item record : SightRecord;
    }

    // ---- Components ----
    part def Frame {
        attribute material : String = "brass";
        attribute mass : Real { unit 'kg'; }
        attribute length : Length;
    }

    part def Telescope {
        port in opticalInput : OpticalPort;
        attribute magnification : Magnification = 6;
        attribute focalLength : Length;
        action def View :> Action {
            in ray : LightRay;
            out magnifiedImage : LightRay;
        }
    }

    part def IndexMirror {
        port in incomingRay : OpticalPort;
        port out reflectedRay : OpticalPort;
        attribute reflectivity : Real;
        attribute rotationAngle : DegreeAngle;
        action def Reflect :> Action {
            in ray : LightRay;
            in angle : DegreeAngle;
            out reflected : LightRay;
        }
    }

    part def HorizonGlass {
        port in reflectedInput : OpticalPort;
        port in directInput : OpticalPort;
        port out combinedOutput : OpticalPort;
        attribute halfSilvered : Boolean = true;
        action def Combine :> Action {
            in reflected : LightRay;
            in direct : LightRay;
            out combined : LightRay;
        }
    }

    part def ShadingFilter {
        attribute density : Real;
        attribute engaged : Boolean;
        action def Attenuate :> Action {
            in ray : LightRay;
            out attenuated : LightRay;
        }
    }

    part def ShadingFilterAssembly {
        part sunFilter : ShadingFilter { density = 3.0; }
        part moonFilter : ShadingFilter { density = 1.0; }
        part starFilter : ShadingFilter { density = 0.5; }
    }

    part def IndexArm {
        port adjustment : AdjustmentPort;
        attribute locked : Boolean;
        attribute position : DegreeAngle;
        action def Swing :> Action {
            in target : DegreeAngle;
            out achieved : DegreeAngle;
        }
        action def Lock :> Action {
            in position : DegreeAngle;
        }
    }

    part def ArcScale {
        port reading : ReadingPort;
        attribute rangeMin : DegreeAngle = 0;
        attribute rangeMax : DegreeAngle = 120;
        attribute resolution : ArcMinuteAngle = 10;
        action def ReadCoarse :> Action {
            out angle : DegreeAngle;
        }
    }

    part def MicrometerDrum {
        port reading : ReadingPort;
        attribute resolution : ArcMinuteAngle = 1;
        attribute vernierResolution : ArcMinuteAngle = 0.2;
        action def ReadFine :> Action {
            out angle : ArcMinuteAngle;
        }
    }

    // ---- The Sextant ----
    part def Sextant {
        part frame : Frame {
            material = "brass";
            mass = 1.5;
            length = 180;
        }
        part telescope : Telescope {
            magnification = 6;
            focalLength = 90;
        }
        part indexMirror : IndexMirror;
        part horizonGlass : HorizonGlass;
        part indexArm : IndexArm;
        part arcScale : ArcScale;
        part micrometerDrum : MicrometerDrum;
        part filters : ShadingFilterAssembly;

        port celestialInput : OpticalPort;
        port horizonInput : OpticalPort;
        port eyepiece : OpticalPort;
        port dataOut : SightDataPort;
        port control : AdjustmentPort;

        connection celestialToIndex connect celestialInput to indexMirror.incomingRay;
        connection indexToHorizon connect indexMirror.reflectedRay to horizonGlass.reflectedInput;
        connection horizonDirect connect horizonInput to horizonGlass.directInput;
        connection horizonToTelescope connect horizonGlass.combinedOutput to telescope.opticalInput;
        connection telescopeToEye connect telescope.opticalInput to eyepiece;
        connection armControl connect control to indexArm.adjustment;
        connection armToMirror connect indexArm.adjustment.currentAngle to indexMirror.rotationAngle;
        connection coarseReading connect arcScale.reading to micrometerDrum.reading;
        connection fineReading connect micrometerDrum.reading to dataOut;

        attribute indexError : IndexError;
        attribute observerHeight : HeightAboveSeaLevel;

        state def OperationalState {
            entry action initialize;
            state stowed;
            state ready;
            state sighting;
            state aligning;
            state locked;
            state recording;

            transition stowed_to_ready first stowed -> ready
                when (control.adjustmentCmd > 0) {
                    do action prepareInstrument;
                }
            transition ready_to_sighting ready -> sighting
                when (control.adjustmentCmd > 0) {
                    do action beginSight;
                }
            transition sighting_to_aligning sighting -> aligning
                when (indexArm.position > 0) {
                    do action alignImages;
                }
            transition aligning_to_locked aligning -> locked
                when (indexArm.locked == true) {
                    do action captureReading;
                }
            transition locked_to_recording locked -> recording {
                do action recordSight;
            }
            transition recording_to_ready recording -> ready {
                do action resetForNextSight;
            }
            transition any_to_stowed ready -> stowed
                when (control.adjustmentCmd == 0) {
                    do action stowInstrument;
                }
        }

        exhibit state operational : OperationalState;

        action def initialize :> Action;
        action def prepareInstrument :> Action;
        action def beginSight :> Action;
        action def alignImages :> Action;
        action def captureReading :> Action {
            in coarse : DegreeAngle;
            in fine : ArcMinuteAngle;
            out record : SightRecord;
        }
        action def recordSight :> Action;
        action def resetForNextSight :> Action;
        action def stowInstrument :> Action;

        action def ApplyCorrections :> Action {
            in raw : SightRecord;
            in indexErr : IndexError;
            in dip : DipCorrection;
            in refraction : RefractionCorrection;
            out corrected : SightRecord;
        }
    }

    // ---- Navigator ----
    part def Navigator {
        part instrument : Sextant;
        attribute eyeHeight : HeightAboveSeaLevel = 2.0;
        attribute experienceLevel : String;

        action def TakeSight :> Action {
            in body : CelestialBody;
            out record : SightRecord;
        }
        action def CorrectSight :> Action {
            in raw : SightRecord;
            out corrected : SightRecord;
        }
        action def ComputeLOP :> Action {
            in sight : SightRecord;
            out lop : LineOfPosition;
        }
        action def DetermineFix :> Action {
            in lop1 : LineOfPosition;
            in lop2 : LineOfPosition;
            out fix : GeographicFix;
        }

        action def CelestialNavigationProcess :> Action {
            in body1 : CelestialBody;
            in body2 : CelestialBody;
            out fix : GeographicFix;
            flow takeSight1 : TakeSight {
                in body := body1;
            }
            flow takeSight2 : TakeSight {
                in body := body2;
            }
            flow correct1 : CorrectSight {
                in raw := takeSight1.record;
            }
            flow correct2 : CorrectSight {
                in raw := takeSight2.record;
            }
            flow lop1 : ComputeLOP {
                in sight := correct1.corrected;
            }
            flow lop2 : ComputeLOP {
                in sight := correct2.corrected;
            }
            flow fixCalc : DetermineFix {
                in lop1 := lop1.lop;
                in lop2 := lop2.lop;
                out fix := fix;
            }
        }

        perform navigation : CelestialNavigationProcess;
    }

    // ---- Requirements ----
    requirement def MeasurementAccuracy {
        subject sextant : Sextant;
        objective {
            doc "The sextant shall measure celestial body angles with an accuracy of at least 10 arcseconds."
        }
        require sextant.micrometerDrum.vernierResolution <= 0.2
    }

    requirement def DualSightFix {
        subject navigator : Navigator;
        objective {
            doc "The navigator shall determine a geographic fix using at least two celestial sights taken at distinct times."
        }
    }

    requirement def OperationalStates {
        subject sextant : Sextant;
        objective {
            doc "The sextant shall transition through stowed, ready, sighting, aligning, locked, and recording states during operation."
        }
    }

    requirement def FilterCapability {
        subject sextant : Sextant;
        objective {
            doc "The sextant shall provide shading filters to attenuate bright celestial bodies such as the sun."
        }
        require sextant.filters.sunFilter.density >= 3.0
    }

    requirement def IndexArmLocking {
        subject sextant : Sextant;
        objective {
            doc "The index arm shall be lockable to preserve the measured angle until read."
        }
        require sextant.indexArm.locked == true
    }

    // ---- Satisfy relationships ----
    satisfaction def AccuracySatisfaction {
        satisfy MeasurementAccuracy by Sextant::micrometerDrum;
    }
    satisfaction def FilterSatisfaction {
        satisfy FilterCapability by Sextant::filters;
    }
    satisfaction def LockSatisfaction {
        satisfy IndexArmLocking by Sextant::indexArm;
    }

    // ---- Instantiation ----
    part navigationSystem : Navigator {
        instrument.indexError = 0.5;
        instrument.observerHeight = 2.0;
        eyeHeight = 2.0;
        experienceLevel = "master";
    }
}

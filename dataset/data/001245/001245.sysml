package SextantNavigationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def AngleDegrees :> Real;
    attribute def ArcMinutes :> Real;
    attribute def Azimuth :> AngleDegrees;
    attribute def Altitude :> AngleDegrees;
    attribute def GeographicLatitude :> AngleDegrees;
    attribute def GeographicLongitude :> AngleDegrees;
    attribute def UniversalTime :> ISQ::TimeValue;
    
    item def OpticalPath {
        attribute intensity : Real;
        attribute wavelength : ISQ::LengthValue;
    }
    
    item def CelestialObject {
        attribute name : String;
        attribute declination : AngleDegrees;
        attribute greenwichHourAngle : AngleDegrees;
    }
    
    item def HorizonReference {
        attribute visible : Boolean;
        attribute clarity : Real;
    }
    
    item def AngleMeasurement {
        attribute altitude : Altitude;
        attribute azimuth : Azimuth;
        attribute timestamp : UniversalTime;
        attribute celestialBody : CelestialObject;
        attribute indexCorrection : ArcMinutes;
    }
    
    item def GeographicPosition {
        attribute latitude : GeographicLatitude;
        attribute longitude : GeographicLongitude;
        attribute estimatedError : ISQ::LengthValue;
    }
    
    part def Frame {
        attribute material : String;
        attribute weight : ISQ::MassValue;
    }
    
    part def IndexMirror {
        attribute reflectivity : Real;
        port celestialInput : ~> OpticalPath;
        port reflectedOutput : ~> OpticalPath;
    }
    
    part def HorizonGlass {
        attribute silveredPortion : Real;
        attribute clearPortion : Real;
        port directHorizonInput : ~> OpticalPath;
        port reflectedCelestialInput : ~> OpticalPath;
        port combinedOutput : ~> OpticalPath;
    }
    
    part def IndexArm {
        attribute currentAngle : AngleDegrees;
        attribute locked : Boolean;
        
        action def RotateArm {
            in targetAngle : AngleDegrees;
            out finalAngle : AngleDegrees;
        }
        
        action def LockPosition {
            in angle : AngleDegrees;
            out locked : Boolean;
        }
    }
    
    part def ArcScale {
        attribute rangeMin : AngleDegrees;
        attribute rangeMax : AngleDegrees;
        attribute graduationInterval : ArcMinutes;
        
        action def ReadAngle {
            in armPosition : AngleDegrees;
            out measuredAngle : AngleDegrees;
        }
    }
    
    part def MicrometerDrum {
        attribute precision : ArcMinutes;
        
        action def FineAdjust {
            in coarseAngle : AngleDegrees;
            out preciseAngle : AngleDegrees;
        }
    }
    
    part def TelescopeAssembly {
        attribute magnification : Real;
        attribute fieldOfView : AngleDegrees;
        port opticalInput : ~> OpticalPath;
        port eyepieceOutput : ~> OpticalPath;
    }
    
    part def ShadingFilters {
        attribute filterCount : Integer;
        attribute transmissionFactor : Real;
        
        action def ApplyFilter {
            in lightIntensity : Real;
            out filteredIntensity : Real;
        }
    }
    
    action def AlignHorizon {
        in horizonReference : HorizonReference;
        out horizonAligned : Boolean;
    }
    
    action def AcquireCelestialBody {
        in bodyIdentifier : CelestialObject;
        in currentAzimuth : Azimuth;
        out bodyAcquired : Boolean;
        out bodyAzimuth : Azimuth;
    }
    
    action def SuperimposeImages {
        in horizonAligned : Boolean;
        in bodyAcquired : Boolean;
        in armAngle : AngleDegrees;
        out imagesSuperimposed : Boolean;
        out finalAngle : AngleDegrees;
    }
    
    action def RecordMeasurement {
        in angle : AngleDegrees;
        in azimuth : Azimuth;
        in celestialBody : CelestialObject;
        in observationTime : UniversalTime;
        out measurement : AngleMeasurement;
    }
    
    action def ApplyCorrections {
        in rawMeasurement : AngleMeasurement;
        in indexError : ArcMinutes;
        in dip : ArcMinutes;
        in refraction : ArcMinutes;
        out correctedAltitude : Altitude;
    }
    
    action def ComputePosition {
        in measurements : AngleMeasurement[2..*];
        in assumedPosition : GeographicPosition;
        out calculatedPosition : GeographicPosition;
    }
    
    action def TakeCelestialSight {
        doc /* Measure the angular altitude of a celestial body above the visible horizon
               to obtain navigational data for position determination. */
        
        first start;
        then merge beginSighting;
        
        then action alignToHorizon : AlignHorizon {
            in horizonReference : HorizonReference;
            out horizonAligned;
        }
        
        then action acquireBody : AcquireCelestialBody {
            in bodyIdentifier : CelestialObject;
            in currentAzimuth : Azimuth;
            out bodyAcquired;
            out bodyAzimuth;
        }
        
        then decide;
            if acquireBody.bodyAcquired then superimpose;
            if not acquireBody.bodyAcquired then beginSighting;
        
        action superimpose : SuperimposeImages {
            in horizonAligned = alignToHorizon.horizonAligned;
            in bodyAcquired = acquireBody.bodyAcquired;
            in armAngle : AngleDegrees;
            out imagesSuperimposed;
            out finalAngle;
        }
        
        then action lockArm {
            private attribute armLocked : Boolean;
        }
        
        then action readScale : ArcScale::ReadAngle {
            in armPosition = superimpose.finalAngle;
            out measuredAngle;
        }
        
        then action fineAdjust : MicrometerDrum::FineAdjust {
            in coarseAngle = readScale.measuredAngle;
            out preciseAngle;
        }
        
        then action recordTime {
            out currentTime : UniversalTime;
        }
        
        then action record : RecordMeasurement {
            in angle = fineAdjust.preciseAngle;
            in azimuth = acquireBody.bodyAzimuth;
            in celestialBody = acquireBody.bodyIdentifier;
            in observationTime = recordTime.currentTime;
            out measurement;
        }
        
        then done;
    }
    
    action def DetermineNavigationalPosition {
        doc /* Primary function: Determine geographic position by measuring angular altitudes
               of celestial bodies above the horizon and computing position lines. */
        
        first start;
        
        then action firstSight : TakeCelestialSight {
            out measurement : AngleMeasurement;
        }
        
        then action applyCorrections1 : ApplyCorrections {
            in rawMeasurement = firstSight.measurement;
            in indexError : ArcMinutes;
            in dip : ArcMinutes;
            in refraction : ArcMinutes;
            out correctedAltitude;
        }
        
        then action secondSight : TakeCelestialSight {
            out measurement : AngleMeasurement;
        }
        
        then action applyCorrections2 : ApplyCorrections {
            in rawMeasurement = secondSight.measurement;
            in indexError : ArcMinutes;
            in dip : ArcMinutes;
            in refraction : ArcMinutes;
            out correctedAltitude;
        }
        
        then action computeNavigationFix : ComputePosition {
            in measurements : AngleMeasurement[*];
            in assumedPosition : GeographicPosition;
            out calculatedPosition;
        }
        
        then done;
    }
    
    state def SextantOperationalStates {
        entry; then Stowed;
        
        state Stowed;
        accept StowedToReady
        then state Ready;
        accept ReadyToSighting
        then state Sighting {
            entry; then HorizonAlignment;
            state HorizonAlignment;
            accept AlignmentToAcquisition
            then state BodyAcquisition;
            accept AcquisitionToSuperposition
            then state ImageSuperposition;
            accept SuperpositionToReading
            then state AngleReading;
        }
        accept SightingToLocked
        then state Locked;
        accept LockedToReady
        then Ready;
        accept ReadyToStowed
        then Stowed;
    }
    
    part def Sextant {
        doc /* A precision optical navigation instrument that measures the angular distance
               between a celestial body and the visible horizon to determine geographic position
               through celestial navigation techniques. */
        
        port celestialPort : ~> OpticalPath;
        port horizonPort : ~> OpticalPath;
        port eyepiecePort : ~> OpticalPath;
        port measurementPort : ~> AngleMeasurement;
        
        part frame : Frame {
            attribute material = "brass";
            attribute weight = 2.0;
        }
        
        part indexMirror : IndexMirror {
            attribute reflectivity = 0.95;
        }
        
        part horizonGlass : HorizonGlass {
            attribute silveredPortion = 0.5;
            attribute clearPortion = 0.5;
        }
        
        part indexArm : IndexArm {
            attribute currentAngle = 0.0;
            attribute locked = false;
        }
        
        part arc : ArcScale {
            attribute rangeMin = -5.0;
            attribute rangeMax = 120.0;
            attribute graduationInterval = 10.0;
        }
        
        part micrometer : MicrometerDrum {
            attribute precision = 0.1;
        }
        
        part telescope : TelescopeAssembly {
            attribute magnification = 3.5;
            attribute fieldOfView = 5.0;
        }
        
        part filters : ShadingFilters {
            attribute filterCount = 4;
            attribute transmissionFactor = 0.25;
        }
        
        connect celestialPort to indexMirror.celestialInput;
        connect indexMirror.reflectedOutput to horizonGlass.reflectedCelestialInput;
        connect horizonPort to horizonGlass.directHorizonInput;
        connect horizonGlass.combinedOutput to telescope.opticalInput;
        connect telescope.eyepieceOutput to eyepiecePort;
        
        perform action navigationMeasurement : DetermineNavigationalPosition;
        
        flow navigationMeasurement.computeNavigationFix.calculatedPosition to measurementPort;
        
        exhibit state operationalState : SextantOperationalStates;
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* The sextant shall measure celestial altitudes with a precision
               of 0.1 arc minutes to enable position determination within
               one nautical mile under optimal conditions. */
        
        subject sextant : Sextant;
        
        require constraint {
            sextant.micrometer.precision <= 0.1
        }
    }
    
    requirement def AngularRangeRequirement {
        doc /* The sextant shall measure angles from -5 degrees to 120 degrees
               to accommodate all observable celestial bodies from below the
               horizon to near zenith. */
        
        subject sextant : Sextant;
        
        require constraint {
            sextant.arc.rangeMin <= -5.0 and
            sextant.arc.rangeMax >= 120.0
        }
    }
    
    requirement def OpticalQualityRequirement {
        doc /* The telescope and mirrors shall provide sufficient magnification
               and clarity to enable precise alignment of celestial bodies
               with the horizon in varying light conditions. */
        
        subject sextant : Sextant;
        
        require constraint {
            sextant.telescope.magnification >= 3.0 and
            sextant.indexMirror.reflectivity >= 0.90
        }
    }
    
    requirement <'SEXT-001'> primaryNavigationRequirement {
        doc /* The sextant system shall determine geographic position by measuring
               the angular altitude of celestial bodies above the visible horizon
               and computing position lines through celestial navigation methods. */
        
        subject sextant : Sextant;
        
        require MeasurementAccuracyRequirement;
        require AngularRangeRequirement;
        require OpticalQualityRequirement;
    }
    
    part navigationSystem {
        part marineSextant : Sextant {
            perform navigationMeasurement;
        }
        
        satisfy primaryNavigationRequirement by marineSextant;
    }
}

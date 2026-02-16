package PhosphorThermometrySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PhosphorType;
    attribute def ExcitationWavelength :> LengthValue;
    attribute def EmissionIntensity :> Real;
    attribute def DecayTime :> TimeValue;
    attribute def TemperatureReading :> ThermodynamicTemperatureValue;
    attribute def CalibrationCoefficient :> Real;
    
    value def PhosphorMaterial {
        attribute materialType : PhosphorType;
        attribute peakExcitationWavelength : ExcitationWavelength;
        attribute temperatureSensitivity : Real;
        attribute minOperatingTemp : ThermodynamicTemperatureValue;
        attribute maxOperatingTemp : ThermodynamicTemperatureValue;
    }
    
    value def OpticalSignal {
        attribute wavelength : LengthValue;
        attribute intensity : Real;
        attribute timestamp : TimeValue;
    }
    
    value def DecayProfile {
        attribute decayConstant : DecayTime;
        attribute measuredTemperature : TemperatureReading;
        attribute signalQuality : Real;
    }
    
    port def OpticalPort {
        out excitationBeam : OpticalSignal;
        in emissionSignal : OpticalSignal;
    }
    
    port def DataPort {
        out temperatureData : TemperatureReading;
        out decayData : DecayProfile;
    }
    
    port def ControlPort {
        in measurementTrigger : Boolean;
        in calibrationData : CalibrationCoefficient[*];
        out systemStatus : String;
    }
    
    part def ExcitationLaser {
        attribute wavelength : LengthValue;
        attribute power : PowerValue;
        attribute pulseWidth : TimeValue;
        
        port opticalOut : OpticalPort;
        
        action generatePulse {
            in trigger : Boolean;
            out pulse : OpticalSignal;
        }
    }
    
    part def PhosphorCoating {
        attribute material : PhosphorMaterial;
        attribute thickness : LengthValue;
        attribute surfaceArea : AreaValue;
        
        port opticalInterface : OpticalPort;
        
        action respondToExcitation {
            in excitation : OpticalSignal;
            in surfaceTemp : TemperatureReading;
            out emission : OpticalSignal;
            out decay : DecayProfile;
        }
    }
    
    part def PhotoDetector {
        attribute sensitivity : Real;
        attribute responseTime : TimeValue;
        attribute spectralRangeMin : LengthValue;
        attribute spectralRangeMax : LengthValue;
        
        port opticalIn : OpticalPort;
        port dataOut : DataPort;
        
        action detectEmission {
            in emission : OpticalSignal;
            out intensity : EmissionIntensity;
            out timestamp : TimeValue;
        }
    }
    
    part def SignalProcessor {
        attribute samplingRate : FrequencyValue;
        attribute filterBandwidth : FrequencyValue;
        attribute calibrationTable : CalibrationCoefficient[*];
        
        port dataIn : DataPort;
        port dataOut : DataPort;
        port control : ControlPort;
        
        action analyzeDecay {
            in rawIntensity : EmissionIntensity;
            in timeData : TimeValue;
            out decayProfile : DecayProfile;
        }
    }
    
    part def TemperatureCalculator {
        attribute algorithm : String;
        attribute accuracy : TemperatureReading;
        attribute resolution : TemperatureReading;
        
        port dataIn : DataPort;
        port dataOut : DataPort;
        
        action computeTemperature {
            in decay : DecayProfile;
            in calibration : CalibrationCoefficient[*];
            out temperature : TemperatureReading;
            out uncertainty : Real;
        }
    }
    
    action def PerformMeasurement {
        in targetSurface : PhosphorMaterial;
        in calibrationParams : CalibrationCoefficient[*];
        out measuredTemp : TemperatureReading;
        out uncertainty : Real;
        
        first start;
        then action initSystem {
            out ready : Boolean;
        }
        then merge measurementLoop;
        then action triggerLaser {
            out laserActive : Boolean;
        }
        then action excitePhosphor {
            in laserActive : Boolean;
            out phosphorExcited : Boolean;
        }
        then action captureEmission {
            in phosphorExcited : Boolean;
            out emissionData : OpticalSignal;
        }
        then action processDecay {
            in emissionData : OpticalSignal;
            out decayData : DecayProfile;
        }
        then action calculateTemp {
            in decayData : DecayProfile;
            out temperature : TemperatureReading;
        }
        then action validateResult {
            in temperature : TemperatureReading;
            out valid : Boolean;
        }
        then decide;
            if validateResult.valid then outputResult;
            else measurementLoop;
        action outputResult {
            in temperature : TemperatureReading;
            out finalTemp : TemperatureReading;
        }
        then done;
    }
    
    action def CalibrateSystem {
        in referenceTemps : TemperatureReading[*];
        in measuredDecays : DecayTime[*];
        out calibrationCoeffs : CalibrationCoefficient[*];
        out calibrationQuality : Real;
        
        first start;
        then action collectReferenceData {
            in refTemps : TemperatureReading[*];
            out dataPoints : Integer;
        }
        then action measureDecayTimes {
            in dataPoints : Integer;
            out decayTimes : DecayTime[*];
        }
        then action fitCalibrationCurve {
            in refTemps : TemperatureReading[*];
            in decayTimes : DecayTime[*];
            out coefficients : CalibrationCoefficient[*];
        }
        then action assessQuality {
            in coefficients : CalibrationCoefficient[*];
            out quality : Real;
        }
        then assign calibrationCoeffs := fitCalibrationCurve.coefficients;
        then assign calibrationQuality := assessQuality.quality;
        then done;
    }
    
    part def PhosphorThermometer {
        attribute operatingRangeMin : ThermodynamicTemperatureValue;
        attribute operatingRangeMax : ThermodynamicTemperatureValue;
        attribute measurementAccuracy : ThermodynamicTemperatureValue;
        attribute responseTime : TimeValue;
        attribute systemStatus : String;
        
        part laser : ExcitationLaser;
        part phosphor : PhosphorCoating;
        part detector : PhotoDetector;
        part processor : SignalProcessor;
        part calculator : TemperatureCalculator;
        
        connect laser.opticalOut to phosphor.opticalInterface;
        connect phosphor.opticalInterface to detector.opticalIn;
        connect detector.dataOut to processor.dataIn;
        connect processor.dataOut to calculator.dataIn;
        
        action measurementOperation : PerformMeasurement;
        
        state operatingBehavior {
            entry; then idle;
            
            state idle;
            
            transition idle_to_calibrating
                first idle
                accept calibrationRequest
                then calibrating;
            
            state calibrating {
                do action performCalibration : CalibrateSystem;
            }
            
            transition calibrating_to_ready
                first calibrating
                if performCalibration.calibrationQuality > 0.95
                then ready;
            
            transition calibrating_to_idle
                first calibrating
                if performCalibration.calibrationQuality <= 0.95
                then idle;
            
            state ready;
            
            transition ready_to_measuring
                first ready
                accept measurementTrigger
                then measuring;
            
            state measuring {
                do action performMeasurement : PerformMeasurement;
            }
            
            transition measuring_to_ready
                first measuring
                if performMeasurement.measuredTemp != null
                then ready;
            
            transition any_to_error
                first idle
                accept systemFault
                then error;
            
            state error;
            
            transition error_to_idle
                first error
                accept systemReset
                then idle;
        }
    }
    
    part phosphorThermometer : PhosphorThermometer {
        attribute :>> operatingRangeMin = 273.15 [K];
        attribute :>> operatingRangeMax = 1773.15 [K];
        attribute :>> measurementAccuracy = 1.0 [K];
        attribute :>> responseTime = 0.001 [s];
        
        part :>> laser {
            attribute :>> wavelength = 355.0e-9 [m];
            attribute :>> power = 0.010 [W];
            attribute :>> pulseWidth = 10.0e-9 [s];
        }
        
        part :>> phosphor {
            attribute :>> material : PhosphorMaterial {
                attribute :>> materialType = "YAG:Dy";
                attribute :>> peakExcitationWavelength = 355.0e-9 [m];
                attribute :>> temperatureSensitivity = 0.015;
                attribute :>> minOperatingTemp = 273.15 [K];
                attribute :>> maxOperatingTemp = 1773.15 [K];
            }
            attribute :>> thickness = 50.0e-6 [m];
            attribute :>> surfaceArea = 1.0e-4 [m^2];
        }
        
        part :>> detector {
            attribute :>> sensitivity = 0.85;
            attribute :>> responseTime = 1.0e-9 [s];
            attribute :>> spectralRangeMin = 400.0e-9 [m];
            attribute :>> spectralRangeMax = 700.0e-9 [m];
        }
        
        part :>> processor {
            attribute :>> samplingRate = 1.0e9 [Hz];
            attribute :>> filterBandwidth = 100.0e6 [Hz];
        }
        
        part :>> calculator {
            attribute :>> algorithm = "Exponential Decay Fit";
            attribute :>> accuracy = 0.5 [K];
            attribute :>> resolution = 0.1 [K];
        }
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* The phosphor thermometry system shall measure temperature 
                with an accuracy of ±1.0 K across the entire operating range. */
        
        subject system : PhosphorThermometer;
        
        require constraint {
            system.measurementAccuracy <= 1.0 [K]
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The system shall provide temperature readings with a 
                response time of less than 1 millisecond. */
        
        subject system : PhosphorThermometer;
        
        require constraint {
            system.responseTime < 0.001 [s]
        }
    }
    
    requirement def OperatingRangeRequirement {
        doc /* The system shall operate over a temperature range from 
                0°C to 1500°C (273.15 K to 1773.15 K). */
        
        subject system : PhosphorThermometer;
        
        require constraint {
            system.operatingRangeMin == 273.15 [K] and
            system.operatingRangeMax == 1773.15 [K]
        }
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The phosphor thermometry system shall provide non-contact 
                temperature measurement by exciting a phosphor coating with 
                pulsed laser light and analyzing the temperature-dependent 
                decay characteristics of the resulting luminescence emission. */
        
        subject system : PhosphorThermometer;
        
        require measurementAccuracy : MeasurementAccuracyRequirement;
        require responseTime : ResponseTimeRequirement;
        require operatingRange : OperatingRangeRequirement;
    }
}

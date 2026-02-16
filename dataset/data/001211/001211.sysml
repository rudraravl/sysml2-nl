package 'Pyrometer System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SpectralRange {
        attribute minWavelength : LengthValue;
        attribute maxWavelength : LengthValue;
    }
    
    attribute def TemperatureRange {
        attribute minTemp : ThermodynamicTemperatureValue;
        attribute maxTemp : ThermodynamicTemperatureValue;
    }
    
    item def ThermalRadiation {
        attribute intensity : PowerValue;
        attribute wavelength : LengthValue;
        attribute emissivity : Real;
    }
    
    item def TemperatureData {
        attribute value : ThermodynamicTemperatureValue;
        attribute timestamp : Real;
        attribute quality : MeasurementQuality;
    }
    
    enum def MeasurementQuality {
        valid;
        outOfRange;
        lowSignal;
        error;
    }
    
    item def CalibrationData {
        attribute referenceTemp : ThermodynamicTemperatureValue;
        attribute correctionFactor : Real;
    }
    
    item def MeasurementTrigger;
    item def StopMeasurement;
    item def CalibrationRequest;
    item def CalibrationComplete;
    item def ErrorDetected;
    item def FaultReset;
    
    port def OpticalInputPort {
        in radiation : ThermalRadiation;
    }
    
    port def TemperatureOutputPort {
        out tempData : TemperatureData;
    }
    
    port def CalibrationPort {
        in calibration : CalibrationData;
    }
    
    part def OpticalSystem {
        doc /* Collects and focuses thermal radiation from the target object. */
        
        attribute focusDistance : LengthValue;
        attribute apertureDiameter : LengthValue;
        attribute transmittance : Real;
        
        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalInputPort;
    }
    
    part def InfraredDetector {
        doc /* Converts thermal radiation into electrical signals. */
        
        attribute spectralResponse : SpectralRange;
        attribute sensitivity : Real;
        attribute detectorTemp : ThermodynamicTemperatureValue;
        
        port radiationIn : OpticalInputPort;
        port signalOut;
    }
    
    part def SignalProcessor {
        doc /* Processes detector signals and applies calibration. */
        
        attribute gain : Real;
        attribute filterBandwidth : FrequencyValue;
        
        port signalIn;
        port calibrationIn : CalibrationPort;
        port processedOut;
    }
    
    part def TemperatureComputer {
        doc /* Calculates temperature from processed signals using radiation laws. */
        
        attribute emissivitySetting : Real;
        attribute algorithm : String;
        
        port dataIn;
        port tempOut : TemperatureOutputPort;
    }
    
    part def DisplayController {
        doc /* Manages temperature display and user interface. */
        
        attribute updateRate : FrequencyValue;
        attribute displayResolution : Real;
        
        port tempIn : TemperatureOutputPort;
    }
    
    action def CaptureRadiation {
        in targetRadiation : ThermalRadiation;
        out focusedRadiation : ThermalRadiation;
    }
    
    action def DetectRadiation {
        in radiation : ThermalRadiation;
        out electricalSignal : Real;
    }
    
    action def ProcessSignal {
        in rawSignal : Real;
        in calibration : CalibrationData;
        out processedSignal : Real;
    }
    
    action def ComputeTemperature {
        in signal : Real;
        in emissivity : Real;
        out temperature : ThermodynamicTemperatureValue;
        out quality : MeasurementQuality;
    }
    
    action def UpdateDisplay {
        in tempData : TemperatureData;
    }
    
    action def PerformCalibration {
        in referenceSource : ThermodynamicTemperatureValue;
        out calibrationData : CalibrationData;
    }
    
    part def Pyrometer {
        doc /* A pyrometer is a non-contact temperature measurement instrument that 
               determines the temperature of an object by detecting and analyzing the 
               thermal radiation it emits in the infrared spectrum. */
        
        attribute operatingRange : TemperatureRange {
            attribute :>> minTemp = 273.15 [K];
            attribute :>> maxTemp = 3273.15 [K];
        }
        
        attribute spectralBand : SpectralRange {
            attribute :>> minWavelength = 0.8e-6 [m];
            attribute :>> maxWavelength = 14.0e-6 [m];
        }
        
        attribute accuracy : Real = 0.5;
        attribute responseTime : DurationValue = 0.1 [s];
        attribute emissivityDefault : Real = 0.95;
        
        port targetView : OpticalInputPort;
        port temperatureOutput : TemperatureOutputPort;
        port calibrationInput : CalibrationPort;
        
        part optics : OpticalSystem {
            attribute :>> focusDistance = 0.5 [m];
            attribute :>> apertureDiameter = 0.025 [m];
            attribute :>> transmittance = 0.92;
        }
        
        part detector : InfraredDetector {
            attribute :>> spectralResponse = spectralBand;
            attribute :>> sensitivity = 0.98;
            attribute :>> detectorTemp = 300.0 [K];
        }
        
        part processor : SignalProcessor {
            attribute :>> gain = 100.0;
            attribute :>> filterBandwidth = 1000.0 [Hz];
        }
        
        part computer : TemperatureComputer {
            attribute :>> emissivitySetting = emissivityDefault;
            attribute :>> algorithm = "Planck Radiation Law";
        }
        
        part display : DisplayController {
            attribute :>> updateRate = 10.0 [Hz];
            attribute :>> displayResolution = 0.1;
        }
        
        connect optics.opticalIn to targetView;
        connect optics.opticalOut to detector.radiationIn;
        connect detector.signalOut to processor.signalIn;
        connect processor.processedOut to computer.dataIn;
        connect computer.tempOut to display.tempIn;
        connect computer.tempOut to temperatureOutput;
        connect processor.calibrationIn to calibrationInput;
    }
    
    action def MeasureTargetTemperature {
        in targetRadiation : ThermalRadiation;
        out measuredTemp : ThermodynamicTemperatureValue;
        out measurementQuality : MeasurementQuality;
    }
    
    action measureTargetTemperature : MeasureTargetTemperature {
        in targetRadiation : ThermalRadiation;
        out measuredTemp : ThermodynamicTemperatureValue;
        out measurementQuality : MeasurementQuality;
        
        first start;
        then merge continueMeasurement;
        
        then action capture : CaptureRadiation {
            in targetRadiation = measureTargetTemperature::targetRadiation;
            out focusedRadiation : ThermalRadiation;
        }
        
        then action detect : DetectRadiation {
            in radiation = capture.focusedRadiation;
            out electricalSignal : Real;
        }
        
        then action process : ProcessSignal {
            in rawSignal = detect.electricalSignal;
            in calibration : CalibrationData;
            out processedSignal : Real;
        }
        
        then action compute : ComputeTemperature {
            in signal = process.processedSignal;
            in emissivity = 0.95;
            out temperature : ThermodynamicTemperatureValue;
            out quality : MeasurementQuality;
        }
        
        then decide;
            if compute.quality == MeasurementQuality::valid then displayTemp;
            if compute.quality == MeasurementQuality::outOfRange then recalibrate;
            if compute.quality == MeasurementQuality::lowSignal then adjustGain;
            if compute.quality == MeasurementQuality::error then handleError;
        
        action displayTemp : UpdateDisplay {
            in tempData : TemperatureData {
                attribute :>> value = compute.temperature;
                attribute :>> quality = compute.quality;
            }
        }
        then assign measuredTemp := compute.temperature;
        then assign measurementQuality := compute.quality;
        then continueMeasurement;
        
        action recalibrate : PerformCalibration {
            in referenceSource : ThermodynamicTemperatureValue;
            out calibrationData : CalibrationData;
        }
        then continueMeasurement;
        
        action adjustGain;
        then continueMeasurement;
        
        action handleError;
        then done;
    }
    
    state def PyrometerOperationalState {
        entry; then idle;
        
        state idle {
            doc /* Pyrometer is powered but not actively measuring. */
        }
        
        state measuring {
            doc /* Pyrometer is actively measuring target temperature. */
        }
        
        state calibrating {
            doc /* Pyrometer is performing calibration routine. */
        }
        
        state fault {
            doc /* Pyrometer has detected an error condition. */
        }
        
        transition idleToMeasuring
            first idle
            accept at MeasurementTrigger
            then measuring;
        
        transition measuringToIdle
            first measuring
            accept at StopMeasurement
            then idle;
        
        transition measuringToCalibrating
            first measuring
            accept at CalibrationRequest
            then calibrating;
        
        transition calibratingToMeasuring
            first calibrating
            accept at CalibrationComplete
            then measuring;
        
        transition toFault
            accept at ErrorDetected
            then fault;
        
        transition faultToIdle
            first fault
            accept at FaultReset
            then idle;
    }
    
    part pyrometerSystem : Pyrometer {
        doc /* The pyrometer system continuously monitors target temperature by 
               detecting thermal radiation, enabling non-contact temperature 
               measurement for industrial processes, furnaces, and hot objects. */
        
        perform action continuousMeasurement : MeasureTargetTemperature[*] ordered
            references measureTargetTemperature;
        
        state operationalState : PyrometerOperationalState;
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* The pyrometer shall measure temperature with specified accuracy. */
        
        subject pyrometer : Pyrometer;
        
        require constraint {
            pyrometer.accuracy <= 1.0
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The pyrometer shall provide temperature readings within response time. */
        
        subject pyrometer : Pyrometer;
        
        require constraint {
            pyrometer.responseTime <= 0.5 [s]
        }
    }
    
    requirement def OperatingRangeRequirement {
        doc /* The pyrometer shall operate within specified temperature range. */
        
        subject pyrometer : Pyrometer;
        
        require constraint {
            pyrometer.operatingRange.minTemp >= 200.0 [K] and
            pyrometer.operatingRange.maxTemp <= 3500.0 [K]
        }
    }
    
    requirement def SpectralRangeRequirement {
        doc /* The pyrometer shall detect radiation in infrared spectrum. */
        
        subject pyrometer : Pyrometer;
        
        require constraint {
            pyrometer.spectralBand.minWavelength >= 0.7e-6 [m] and
            pyrometer.spectralBand.maxWavelength <= 20.0e-6 [m]
        }
    }
    
    requirement <'PYR-SYS-001'> pyrometerSystemRequirement {
        doc /* The pyrometer system shall accurately measure the temperature of 
               remote objects without physical contact by detecting and analyzing 
               thermal radiation emitted in the infrared spectrum, providing 
               continuous temperature monitoring for industrial applications. */
        
        subject pyrometerSystem;
        
        assume constraint validEmissivity {
            pyrometerSystem.emissivityDefault >= 0.1 and
            pyrometerSystem.emissivityDefault <= 1.0
        }
        
        require accuracyReq : MeasurementAccuracyRequirement {
            subject pyrometer = pyrometerSystem;
        }
        
        require responseReq : ResponseTimeRequirement {
            subject pyrometer = pyrometerSystem;
        }
        
        require rangeReq : OperatingRangeRequirement {
            subject pyrometer = pyrometerSystem;
        }
        
        require spectralReq : SpectralRangeRequirement {
            subject pyrometer = pyrometerSystem;
        }
    }
}

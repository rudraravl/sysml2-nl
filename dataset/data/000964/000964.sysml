package ActinometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def RadiantIntensity :> ISQ::PowerValue {
        doc /* Radiant power per unit area, measured in W/m^2 */
    }
    
    attribute def WavelengthRange {
        attribute minWavelength : ISQ::LengthValue;
        attribute maxWavelength : ISQ::LengthValue;
    }
    
    attribute def CalibrationData {
        attribute calibrationFactor : Real;
        attribute calibrationDate : String;
        attribute referenceStandard : String;
    }
    
    attribute def MeasurementReading {
        attribute intensity : RadiantIntensity;
        attribute wavelength : ISQ::LengthValue;
        attribute timestamp : ISQ::TimeValue;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
    }
    
    attribute def CalibrationRequest;
    attribute def CalibrationComplete;
    attribute def MeasurementRequest;
    attribute def DataAcquired;
    attribute def DetectorFailure;
    attribute def ResetCommand;
    
    port def RadiationInputPort {
        in incidentRadiation : RadiantIntensity;
    }
    
    port def SignalOutputPort {
        out electricalSignal : ISQ::ElectricCurrentValue;
    }
    
    port def DataOutputPort {
        out measurementData : MeasurementReading;
    }
    
    port def ControlPort {
        in calibrationCommand : CalibrationData;
        in measurementCommand : String;
        out statusResponse : String;
    }
    
    part def PhotodetectorSensor {
        doc /* Converts incident electromagnetic radiation into electrical current */
        attribute spectralRange : WavelengthRange;
        attribute sensitivity : Real;
        attribute responsivity : Real;
        port radiationInput : RadiationInputPort;
        port signalOutput : SignalOutputPort;
    }
    
    part def SignalAmplifier {
        doc /* Amplifies weak electrical signal from photodetector */
        attribute gain : Real;
        attribute bandwidth : ISQ::FrequencyValue;
        port signalInput {
            in inputCurrent : ISQ::ElectricCurrentValue;
        }
        port amplifiedOutput {
            out outputVoltage : ISQ::ElectricPotentialValue;
        }
    }
    
    part def AnalogDigitalConverter {
        doc /* Converts analog voltage signal to digital representation */
        attribute resolution : Integer;
        attribute samplingRate : ISQ::FrequencyValue;
        port analogInput {
            in voltage : ISQ::ElectricPotentialValue;
        }
        port digitalOutput {
            out digitalValue : Integer;
        }
    }
    
    part def ProcessingUnit {
        doc /* Applies calibration and computes radiant intensity */
        attribute calibration : CalibrationData;
        port dataInput {
            in rawData : Integer;
        }
        port dataOutput : DataOutputPort;
        port control : ControlPort;
    }
    
    part def DisplayRecorder {
        doc /* Displays and records measurement results */
        attribute storageCapacity : Integer;
        port dataInput : DataOutputPort;
    }
    
    action def DetectRadiation {
        in incidentRadiation : RadiantIntensity;
        out electricalCurrent : ISQ::ElectricCurrentValue;
    }
    
    action def AmplifySignal {
        in inputCurrent : ISQ::ElectricCurrentValue;
        out amplifiedVoltage : ISQ::ElectricPotentialValue;
    }
    
    action def DigitizeSignal {
        in analogVoltage : ISQ::ElectricPotentialValue;
        out digitalValue : Integer;
    }
    
    action def ApplyCalibration {
        in rawData : Integer;
        in calibrationFactor : Real;
        out calibratedIntensity : RadiantIntensity;
    }
    
    action def RecordMeasurement {
        in intensity : RadiantIntensity;
        in timestamp : ISQ::TimeValue;
        in temperature : ISQ::ThermodynamicTemperatureValue;
        out reading : MeasurementReading;
    }
    
    action def MeasureRadiation {
        doc /* Complete measurement cycle from radiation detection to data recording */
        in radiation : RadiantIntensity;
        in calibration : CalibrationData;
        out finalReading : MeasurementReading;
        
        first start;
        then action detect : DetectRadiation {
            in incidentRadiation = radiation;
            out electricalCurrent;
        }
        then action amplify : AmplifySignal {
            in inputCurrent = detect.electricalCurrent;
            out amplifiedVoltage;
        }
        then action digitize : DigitizeSignal {
            in analogVoltage = amplify.amplifiedVoltage;
            out digitalValue;
        }
        then action calibrate : ApplyCalibration {
            in rawData = digitize.digitalValue;
            in calibrationFactor = calibration.calibrationFactor;
            out calibratedIntensity;
        }
        then action record : RecordMeasurement {
            in intensity = calibrate.calibratedIntensity;
            out reading;
        }
        then assign finalReading := record.reading;
        then done;
    }
    
    state def ActinometerStates {
        entry; then standby;
        
        state standby {
            doc /* System powered but not actively measuring */
        }
        
        transition standby_to_calibrating
            first standby
            accept calibrationRequest : CalibrationRequest
            then calibrating;
        
        state calibrating {
            doc /* Performing calibration against reference standard */
            entry action executeCalibration;
        }
        
        transition calibrating_to_standby
            first calibrating
            accept calibrationComplete : CalibrationComplete
            then standby;
        
        transition standby_to_measuring
            first standby
            accept measurementRequest : MeasurementRequest
            then measuring;
        
        state measuring {
            doc /* Actively detecting and measuring radiation */
            entry action initiateMeasurement;
            do action continuousMeasurement;
        }
        
        transition measuring_to_processing
            first measuring
            accept dataAcquired : DataAcquired
            then processing;
        
        state processing {
            doc /* Processing and calibrating measurement data */
            entry action processData;
        }
        
        transition processing_to_recording
            first processing
            then recording;
        
        state recording {
            doc /* Recording measurement to storage */
            entry action saveData;
        }
        
        transition recording_to_standby
            first recording
            then standby;
        
        transition measuring_to_error
            first measuring
            accept detectorFailure : DetectorFailure
            then error;
        
        state error {
            doc /* Error condition requiring intervention */
            entry action reportError;
        }
        
        transition error_to_standby
            first error
            accept resetCommand : ResetCommand
            then standby;
    }
    
    part def ActinometerSystemDef {
        doc /* Complete actinometer system for quantitative measurement of electromagnetic radiation intensity */
        
        attribute operatingRange : WavelengthRange;
        attribute measurementAccuracy : Real;
        attribute responseTime : ISQ::TimeValue;
        
        part photodetector : PhotodetectorSensor;
        part amplifier : SignalAmplifier;
        part adc : AnalogDigitalConverter;
        part processor : ProcessingUnit;
        part display : DisplayRecorder;
    }
    
    part actinometer : ActinometerSystemDef {
        
        :>> operatingRange {
            :>> minWavelength = 280.0 [SI::nm];
            :>> maxWavelength = 400.0 [SI::nm];
        }
        
        :>> measurementAccuracy = 0.02;
        :>> responseTime = 0.1 [SI::s];
        
        :>> photodetector {
            :>> spectralRange = actinometer.operatingRange;
            :>> sensitivity = 0.85;
            :>> responsivity = 0.45;
        }
        
        :>> amplifier {
            :>> gain = 100.0;
            :>> bandwidth = 1000.0 [SI::Hz];
        }
        
        :>> adc {
            :>> resolution = 16;
            :>> samplingRate = 10000.0 [SI::Hz];
        }
        
        :>> processor {
            :>> calibration {
                :>> calibrationFactor = 1.05;
                :>> calibrationDate = "2024-01-15";
                :>> referenceStandard = "NIST-SRM-2000";
            }
        }
        
        :>> display {
            :>> storageCapacity = 10000;
        }
        
        connection detectorToAmplifier
            connect photodetector.signalOutput to amplifier.signalInput;
        
        connection amplifierToADC
            connect amplifier.amplifiedOutput to adc.analogInput;
        
        connection adcToProcessor
            connect adc.digitalOutput to processor.dataInput;
        
        connection processorToDisplay
            connect processor.dataOutput to display.dataInput;
        
        perform action measurementCycle : MeasureRadiation[*] ordered;
        
        exhibit state operatingBehavior : ActinometerStates;
    }
    
    requirement def AccuracyRequirement {
        doc /* Actinometer shall measure radiant intensity within specified accuracy */
        subject actinometerSystem : ActinometerSystemDef;
        require constraint {
            actinometerSystem.measurementAccuracy <= 0.05
        }
    }
    
    requirement def SpectralRangeRequirement {
        doc /* Actinometer shall operate within ultraviolet spectrum range */
        subject actinometerSystem : ActinometerSystemDef;
        require constraint {
            actinometerSystem.operatingRange.minWavelength >= 280.0 [SI::nm] and
            actinometerSystem.operatingRange.maxWavelength <= 400.0 [SI::nm]
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* Actinometer shall complete measurement within specified time */
        subject actinometerSystem : ActinometerSystemDef;
        require constraint {
            actinometerSystem.responseTime <= 0.5 [SI::s]
        }
    }
    
    requirement def CalibrationTraceabilityRequirement {
        doc /* Actinometer shall maintain calibration traceability to national standards */
        subject processingUnit : ProcessingUnit;
        require constraint {
            processingUnit.calibration.referenceStandard != null
        }
    }
    
    requirement <'ACT-SYS-001'> primaryFunctionRequirement {
        doc /* The actinometer system shall accurately measure and quantify the intensity 
                of electromagnetic radiation, particularly in the ultraviolet spectrum, 
                for scientific research, environmental monitoring, and photochemical applications.
                The system converts incident radiation into calibrated electrical signals, 
                processes the data with reference to traceable standards, and records 
                measurements for analysis and documentation. */
        
        requirement accuracyReq : AccuracyRequirement;
        requirement spectralReq : SpectralRangeRequirement;
        requirement responseReq : ResponseTimeRequirement;
        requirement calibrationReq : CalibrationTraceabilityRequirement;
    }
}

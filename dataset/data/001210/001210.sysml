package PyrgeometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def LongwaveIrradianceValue :> ISQ::PowerPerAreaValue;
    attribute def ThermopileVoltageValue :> ISQ::ElectricPotentialValue;
    attribute def CaseTemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def DomeTemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def CalibrationConstant :> Real;
    
    item def MeasurementData {
        attribute thermopileVoltage : ThermopileVoltageValue;
        attribute caseTemperature : CaseTemperatureValue;
        attribute domeTemperature : DomeTemperatureValue;
        attribute timestamp : String;
    }
    
    item def IrradianceReport {
        attribute downwellingLongwave : LongwaveIrradianceValue;
        attribute measurementQuality : QualityIndicator;
        attribute timestamp : String;
    }
    
    enum def QualityIndicator {
        enum excellent;
        enum good;
        enum acceptable;
        enum poor;
    }
    
    port def SensorDataPort {
        out rawData : MeasurementData;
    }
    
    port def ProcessedDataPort {
        out irradianceData : IrradianceReport;
    }
    
    port def PowerSupplyPort {
        in powerLevel : ISQ::PowerValue;
    }
    
    part def ThermopileDetector {
        doc /* Thermopile detector measures infrared radiation by converting 
               thermal energy into electrical voltage. */
        
        attribute sensitivity : CalibrationConstant;
        attribute spectralRange : Real[2];
        port output : SensorDataPort;
        
        action detectLongwaveRadiation {
            in incidentRadiation : LongwaveIrradianceValue;
            out voltage : ThermopileVoltageValue;
        }
    }
    
    part def CaseThermistor {
        doc /* Thermistor measures the temperature of the pyrgeometer case 
               for thermal offset correction. */
        
        attribute accuracy : ISQ::ThermodynamicTemperatureValue;
        
        action measureCaseTemperature {
            out temperature : CaseTemperatureValue;
        }
    }
    
    part def DomeThermistor {
        doc /* Thermistor measures the temperature of the silicon dome 
               for thermal offset correction. */
        
        attribute accuracy : ISQ::ThermodynamicTemperatureValue;
        
        action measureDomeTemperature {
            out temperature : DomeTemperatureValue;
        }
    }
    
    part def SignalConditioner {
        doc /* Signal conditioner amplifies and filters thermopile voltage 
               and temperature signals. */
        
        attribute gain : Real;
        attribute filterCutoff : ISQ::FrequencyValue;
        
        action conditionSignals {
            in rawVoltage : ThermopileVoltageValue;
            in caseTemp : CaseTemperatureValue;
            in domeTemp : DomeTemperatureValue;
            out conditionedData : MeasurementData;
        }
    }
    
    part def IrradianceCalculator {
        doc /* Calculator applies Stefan-Boltzmann law and calibration factors 
               to compute downwelling longwave irradiance. */
        
        attribute stefanBoltzmannConstant : Real = 5.670374419e-8;
        attribute calibrationFactor : CalibrationConstant;
        attribute emissivity : Real = 0.98;
        
        action calculateIrradiance {
            in measurementData : MeasurementData;
            out irradiance : LongwaveIrradianceValue;
            out quality : QualityIndicator;
        }
    }
    
    part def DataLogger {
        doc /* Data logger stores and timestamps irradiance measurements. */
        
        attribute storageCapacity : Integer;
        attribute loggingInterval : ISQ::TimeValue;
        
        action logMeasurement {
            in irradiance : LongwaveIrradianceValue;
            in quality : QualityIndicator;
            out report : IrradianceReport;
        }
    }
    
    part def Pyrgeometer {
        doc /* Pyrgeometer measures downwelling atmospheric longwave infrared 
               radiation in the spectral range 4.5 to 42 micrometers using a 
               thermopile detector beneath a silicon dome. */
        
        attribute operatingTemperatureRange : ISQ::ThermodynamicTemperatureValue[2];
        attribute spectralResponseRange : Real[2];
        attribute currentQuality : QualityIndicator;
        
        port powerInput : PowerSupplyPort;
        port dataOutput : ProcessedDataPort;
        
        part thermopile : ThermopileDetector {
            attribute :>> sensitivity = 7.5e-6;
            attribute :>> spectralRange = (4.5, 42.0);
        }
        
        part caseThermistor : CaseThermistor {
            attribute :>> accuracy = 0.2;
        }
        
        part domeThermistor : DomeThermistor {
            attribute :>> accuracy = 0.2;
        }
        
        part signalConditioner : SignalConditioner {
            attribute :>> gain = 1000.0;
        }
        
        part calculator : IrradianceCalculator {
            attribute :>> calibrationFactor = 8.2e-6;
        }
        
        part logger : DataLogger {
            attribute :>> storageCapacity = 10000;
            attribute :>> loggingInterval = 1.0;
        }
        
        connection thermopileToConditioner connect 
            thermopile.output to signalConditioner;
        
        connection conditionerToCalculator connect 
            signalConditioner to calculator;
        
        connection calculatorToLogger connect 
            calculator to logger;
        
        connection loggerToOutput connect 
            logger to dataOutput;
        
        action warmUp {
            doc /* Warm-up period to stabilize thermal equilibrium. */
            
            action stabilizeTemperature {
                out stabilized : Boolean;
            }
        }
        
        action performMeasurement {
            doc /* Continuous measurement cycle for downwelling longwave radiation. */
            
            first start;
            then merge measurementCycle;
            
            action acquireThermopileVoltage : ThermopileDetector::detectLongwaveRadiation {
                in incidentRadiation;
                out voltage : ThermopileVoltageValue;
            }
            
            then action acquireCaseTemperature : CaseThermistor::measureCaseTemperature {
                out temperature : CaseTemperatureValue;
            }
            
            then action acquireDomeTemperature : DomeThermistor::measureDomeTemperature {
                out temperature : DomeTemperatureValue;
            }
            
            then action conditionSignals : SignalConditioner::conditionSignals {
                in rawVoltage = acquireThermopileVoltage.voltage;
                in caseTemp = acquireCaseTemperature.temperature;
                in domeTemp = acquireDomeTemperature.temperature;
                out conditionedData : MeasurementData;
            }
            
            then action computeIrradiance : IrradianceCalculator::calculateIrradiance {
                in measurementData = conditionSignals.conditionedData;
                out irradiance : LongwaveIrradianceValue;
                out quality : QualityIndicator;
            }
            
            then action recordMeasurement : DataLogger::logMeasurement {
                in irradiance = computeIrradiance.irradiance;
                in quality = computeIrradiance.quality;
                out report : IrradianceReport;
            }
            
            then action publishData {
                assign currentQuality := recordMeasurement.report.measurementQuality;
            }
            
            then measurementCycle;
        }
    }
    
    part def AtmosphericMonitoringStation {
        doc /* Atmospheric monitoring station integrating pyrgeometer for 
               radiation balance studies and climate research. */
        
        port stationPower : PowerSupplyPort;
        port radiationOutput : ProcessedDataPort;
        
        part pyrgeometerSensor : Pyrgeometer;
        
        part powerSupply {
            attribute outputVoltage : ISQ::ElectricPotentialValue;
            attribute outputCurrent : ISQ::ElectricCurrentValue;
        }
        
        connection powerToPyrgeometer connect 
            powerSupply to pyrgeometerSensor.powerInput;
        
        connection pyrgeometerToStation connect 
            pyrgeometerSensor.dataOutput to radiationOutput;
    }
    
    part monitoringStation : AtmosphericMonitoringStation {
        perform action measureDownwellingLongwave {
            doc /* Primary function: Continuously measure downwelling atmospheric 
                   longwave infrared radiation to quantify the thermal energy flux 
                   from the atmosphere to the Earth's surface for climate studies, 
                   energy balance calculations, and weather forecasting applications. */
            
            first start;
            then merge continuousOperation;
            
            action initializeSystem {
                out systemReady : Boolean;
            }
            
            then action acquireRadiationMeasurement {
                out radiationData : IrradianceReport;
            }
            
            then action validateData {
                in measurement = acquireRadiationMeasurement.radiationData;
                out isValid : Boolean;
            }
            
            then decide;
                if validateData.isValid then archiveData;
                if !validateData.isValid then flagAnomaly;
            
            action archiveData {
                in validData = acquireRadiationMeasurement.radiationData;
            }
            then continuousOperation;
            
            action flagAnomaly {
                out anomalyCode : String;
            }
            then continuousOperation;
        }
    }
    
    requirement def AccuracyRequirement {
        doc /* The pyrgeometer shall measure downwelling longwave radiation 
               with specified accuracy under operational conditions. */
        
        subject pyrgeometer : Pyrgeometer;
        
        require constraint measurementAccuracy {
            doc /* Measurement uncertainty shall not exceed ±5 W/m² for 
                   irradiance values between 0 and 700 W/m². */
        }
    }
    
    requirement def TemperatureRangeRequirement {
        doc /* The pyrgeometer shall operate across environmental temperature range. */
        
        subject pyrgeometer : Pyrgeometer;
        
        require constraint operatingTemperature {
            doc /* Operational temperature range: -40°C to +80°C ambient. */
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The pyrgeometer shall provide timely radiation measurements. */
        
        subject pyrgeometer : Pyrgeometer;
        
        require constraint responseTime {
            doc /* Time constant (95% response) shall be less than 5 seconds. */
        }
    }
    
    requirement def SpectralRangeRequirement {
        doc /* The pyrgeometer shall measure radiation in longwave infrared spectrum. */
        
        subject pyrgeometer : Pyrgeometer;
        
        require constraint spectralCoverage {
            doc /* Spectral range shall cover 4.5 to 42 micrometers to capture 
                   atmospheric thermal emission window. */
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for pyrgeometer-based atmospheric 
               radiation monitoring system. */
        
        requirement accuracy : AccuracyRequirement;
        requirement temperatureRange : TemperatureRangeRequirement;
        requirement responseTime : ResponseTimeRequirement;
        requirement spectralRange : SpectralRangeRequirement;
        
        requirement dataIntegrity {
            doc /* System shall timestamp and quality-flag all measurements. */
        }
        
        requirement thermalStability {
            doc /* System shall maintain thermal equilibrium to minimize 
                   measurement drift and offset errors. */
        }
    }
}

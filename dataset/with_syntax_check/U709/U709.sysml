package 'Hook Gauge Evaporimeter System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def WaterDepth :> ISQ::LengthValue {
        attribute :>> num : Real;
        attribute :>> mRef : LengthUnit;
    }
    
    attribute def EvaporationRate :> ISQ::SpeedValue {
        attribute :>> num : Real;
        attribute :>> mRef : SpeedUnit;
    }
    
    attribute def TimeInterval :> ISQ::TimeValue {
        attribute :>> num : Real;
        attribute :>> mRef : TimeUnit;
    }
    
    attribute def PanArea :> ISQ::AreaValue {
        attribute :>> num : Real;
        attribute :>> mRef : AreaUnit;
    }
    
    attribute def Temperature :> ISQ::ThermodynamicTemperatureValue {
        attribute :>> num : Real;
        attribute :>> mRef : ThermodynamicTemperatureUnit;
    }
    
    attribute def Humidity {
        attribute humidityValue : Real;
    }
    
    attribute def WindSpeed :> ISQ::SpeedValue {
        attribute :>> num : Real;
        attribute :>> mRef : SpeedUnit;
    }
    
    part def EvaporationPan {
        doc /* Standardized cylindrical container holding water for evaporation measurement. */
        
        attribute diameter : LengthValue;
        attribute depth : LengthValue;
        attribute surfaceArea : PanArea;
        attribute currentWaterLevel : WaterDepth;
        
        port waterSurface {
            out levelReading : WaterDepth;
        }
    }
    
    part def StillingWell {
        doc /* Vertical tube connected to pan that dampens surface oscillations. */
        
        attribute wellDiameter : LengthValue;
        attribute dampingCoefficient : Real;
        
        port panInterface {
            in panLevel : WaterDepth;
        }
        
        port gaugeInterface {
            out stabilizedLevel : WaterDepth;
        }
    }
    
    part def HookGauge {
        doc /* Precision mechanical device with pointed hook for measuring water surface level. */
        
        attribute precision : LengthValue;
        attribute hookPosition : WaterDepth;
        
        port measurementPoint {
            in waterLevel : WaterDepth;
            out depthReading : WaterDepth;
        }
    }
    
    part def DataLogger {
        doc /* Records depth measurements and timestamps for evaporation calculation. */
        
        attribute measurements : WaterDepth[*] ordered;
        attribute timestamps : TimeValue[*] ordered;
        attribute calculatedRates : EvaporationRate[*] ordered;
        
        port dataInput {
            in depthValue : WaterDepth;
            in timeValue : TimeValue;
        }
        
        port dataOutput {
            out evaporationData : EvaporationRate;
        }
    }
    
    part def WeatherStation {
        doc /* Monitors environmental conditions affecting evaporation. */
        
        attribute airTemp : Temperature;
        attribute relativeHumidity : Humidity;
        attribute wind : WindSpeed;
        
        port environmentalData {
            out temperature : Temperature;
            out humidity : Humidity;
            out windSpeed : WindSpeed;
        }
    }
    
    action def MeasureDepth {
        doc /* Performs single depth measurement using hook gauge. */
        
        in hookPos : WaterDepth;
        in surfaceLevel : WaterDepth;
        out reading : WaterDepth;
        out timestamp : TimeValue;
    }
    
    action def ComputeEvaporationRate {
        doc /* Calculates evaporation rate from depth change over time. */
        
        in initialDepth : WaterDepth;
        in finalDepth : WaterDepth;
        in timeElapsed : TimeInterval;
        in area : PanArea;
        out rate : EvaporationRate;
    }
    
    action def LogMeasurement {
        doc /* Records measurement to data logger. */
        
        in depth : WaterDepth;
        in time : TimeValue;
        out success : Boolean;
    }
    
    action def MonitorEvaporation {
        doc /* Continuous monitoring cycle measuring evaporation over time intervals. */
        
        in measurementPeriod : TimeInterval;
        in panArea : PanArea;
        out dailyRate : EvaporationRate;
        
        first start;
        then merge continueMeasurement;
        
        action initialReading : MeasureDepth {
            in hookPos;
            in surfaceLevel;
            out reading;
            out timestamp;
        }
        
        then action logInitial : LogMeasurement {
            in depth = initialReading.reading;
            in time = initialReading.timestamp;
            out success;
        }
        
        then action waitPeriod {
            in period = measurementPeriod;
        }
        
        then action finalReading : MeasureDepth {
            in hookPos;
            in surfaceLevel;
            out reading;
            out timestamp;
        }
        
        then action logFinal : LogMeasurement {
            in depth = finalReading.reading;
            in time = finalReading.timestamp;
            out success;
        }
        
        then action calculateRate : ComputeEvaporationRate {
            in initialDepth = initialReading.reading;
            in finalDepth = finalReading.reading;
            in timeElapsed = measurementPeriod;
            in area = panArea;
            out rate;
        }
        
        then decide;
            if calculateRate.rate.num >= 0.0 then continueMeasurement;
            if calculateRate.rate.num < 0.0 then checkAnomaly;
        
        action checkAnomaly {
            doc /* Handles negative evaporation indicating precipitation or error. */
        }
        then continueMeasurement;
    }
    
    attribute def StartMeasurement;
    
    state def EvaporimeterStates {
        doc /* Operating states of the evaporimeter system. */
        
        entry; then idle;
        
        state idle {
            doc /* System ready for measurement. */
            accept startCmd : StartMeasurement;
            then measuring;
        }
        
        state measuring {
            doc /* Actively taking depth measurement. */
            entry action takeMeasurement : MeasureDepth;
            then stabilizing;
        }
        
        state stabilizing {
            doc /* Allowing water surface to settle in stilling well. */
            do action waitForStabilization;
            then recording;
        }
        
        state recording {
            doc /* Logging measurement data. */
            do action recordData : LogMeasurement;
            then computing;
        }
        
        state computing {
            doc /* Calculating evaporation rate. */
            do action computeRate : ComputeEvaporationRate;
            then idle;
        }
    }
    
    part def HookGaugeEvaporimeter {
        doc /* Complete evaporimeter system for measuring open water evaporation using hook gauge method. */
        
        attribute systemID : String;
        attribute calibrationDate : String;
        attribute operationalStatus : Boolean;
    }
    
    part evaporimeterSystem : HookGaugeEvaporimeter {
        doc /* Integrated system measuring evaporation by tracking water level changes in standardized pan. */
        
        part pan : EvaporationPan {
            attribute :>> diameter = 1.2 [SI::m];
            attribute :>> depth = 0.255 [SI::m];
            attribute :>> surfaceArea = 1.131 [SI::m^2];
        }
        
        part well : StillingWell {
            attribute :>> wellDiameter = 0.05 [SI::m];
            attribute :>> dampingCoefficient = 0.9;
        }
        
        part gauge : HookGauge {
            attribute :>> precision = 0.0001 [SI::m];
        }
        
        part logger : DataLogger;
        
        part weather : WeatherStation;
        
        connect pan.waterSurface to well.panInterface;
        connect well.gaugeInterface to gauge.measurementPoint;
        connect gauge.measurementPoint to logger.dataInput;
        
        perform action monitor : MonitorEvaporation {
            in measurementPeriod = 24.0 [SI::h];
            in panArea = pan.surfaceArea;
            out dailyRate;
        }
    }
    
    requirement def AccuracyRequirement {
        doc /* System shall measure depth changes with precision sufficient for evaporation detection. */
        
        subject system : HookGaugeEvaporimeter;
        
        require constraint {
            system.gauge.precision.num <= 0.0001
        }
    }
    
    requirement def MeasurementFrequencyRequirement {
        doc /* System shall record measurements at regular intervals for trend analysis. */
        
        subject system : HookGaugeEvaporimeter;
        
        require constraint {
            system.logger.measurements->size() >= 2
        }
    }
    
    requirement def EnvironmentalDataRequirement {
        doc /* System shall monitor environmental conditions for evaporation correlation. */
        
        subject system : HookGaugeEvaporimeter;
        
        require constraint {
            system.weather.airTemp.num > 0.0 and
            system.weather.relativeHumidity.humidityValue >= 0.0 and
            system.weather.relativeHumidity.humidityValue <= 1.0
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for hook gauge evaporimeter system. */
        
        require accuracy : AccuracyRequirement;
        require frequency : MeasurementFrequencyRequirement;
        require environmental : EnvironmentalDataRequirement;
    }
}

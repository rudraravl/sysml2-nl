package 'Atmospheric Pressure Monitoring System' {
    private import ISQ::*;
    private import ScalarValues::*;
    private import SequenceFunctions::*;

    attribute def PressureValue :> ISQ::pressure;
    attribute def TemperatureValue :> ISQ::temperature;
    attribute def HumidityValue :> ScalarValues::Real;
    attribute def AltitudeValue :> ISQ::length;
    attribute def TimeValue :> ISQ::time;
    attribute def RateOfChangeValue :> ScalarValues::Real;

    enum def PressureTrend {
        stable;
        rising;
        falling;
        rapidChange;
    }

    enum def WeatherForecastKind {
        stableWeather;
        improving;
        deteriorating;
        stormApproaching;
    }

    item def SensorReading {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute timestamp : TimeValue;
    }

    item def CorrectedReading {
        attribute seaLevelPressure : PressureValue;
        attribute timestamp : TimeValue;
    }

    item def PressureLog {
        attribute entries : CorrectedReading[0..*] := ();
    }

    item def ForecastResult {
        attribute trend : PressureTrend;
        attribute rateOfChange : RateOfChangeValue;
        attribute forecast : WeatherForecastKind;
        attribute description : String;
    }

    port def SensorOutputPort {
        out reading : SensorReading;
    }
    port def ProcessorInputPort {
        in reading : SensorReading;
    }
    port def ProcessorOutputPort {
        out corrected : CorrectedReading;
    }
    port def LogOutputPort {
        out log : PressureLog;
    }
    port def LogInputPort {
        in log : PressureLog;
    }
    port def ForecastOutputPortType {
        out result : ForecastResult;
    }
    port def DisplayCorrectedPort {
        in corrected : CorrectedReading;
    }
    port def DisplayForecastPort {
        in result : ForecastResult;
    }

    calc def SeaLevelCorrection {
        in rawPressure : PressureValue;
        in temperature : TemperatureValue;
        in altitude : AltitudeValue;
        return correctedPressure : PressureValue;
    }

    calc def ComputeRateOfChange {
        in recent : CorrectedReading[0..*];
        return rate : RateOfChangeValue;
    }

    action def MeasureEnvironment {
        out reading : SensorReading;
    }

    action def ProcessReading {
        in reading : SensorReading;
        in altitude : AltitudeValue;
        in currentLog : PressureLog;
        out corrected : CorrectedReading;
        out updatedLog : PressureLog;
    }

    action def AnalyzeHistory {
        in log : PressureLog;
        out result : ForecastResult;
    }

    action def RefreshDisplay {
        in corrected : CorrectedReading;
        in result : ForecastResult;
    }

    action def MonitoringCycle {
        in altitude : AltitudeValue;
        in refresh : TimeValue;
        private attribute log : PressureLog := ();

        first start;
        then merge cycleStart;
        then action measure : MeasureEnvironment;
        then action process : ProcessReading {
            in reading = measure.reading;
            in altitude = altitude;
            in currentLog = log;
        }
        then action analyze : AnalyzeHistory {
            in log = process.updatedLog;
        }
        then action render : RefreshDisplay {
            in corrected = process.corrected;
            in result = analyze.result;
        }
        then cycleStart;
    }

    part def BarometricSensor {
        port sensorOut : SensorOutputPort;
        perform action measure : MeasureEnvironment {
            out reading = sensorOut.reading;
        }
    }

    part def DataProcessor {
        port procIn : ProcessorInputPort;
        port procOut : ProcessorOutputPort;
        port logOut : LogOutputPort;
        attribute configAltitude : AltitudeValue = 100 [m];
        attribute pressureLog : PressureLog;
        perform action process : ProcessReading {
            in reading = procIn.reading;
            in altitude = configAltitude;
            in currentLog = pressureLog;
            out corrected = procOut.corrected;
            out updatedLog = logOut.log;
        }
    }

    part def ForecastEngine {
        port forecastIn : LogInputPort;
        port forecastOut : ForecastOutputPortType;
        perform action analyze : AnalyzeHistory {
            in log = forecastIn.log;
            out result = forecastOut.result;
        }
    }

    part def DisplayUnit {
        port dispCorrected : DisplayCorrectedPort;
        port dispForecast : DisplayForecastPort;
        perform action render : RefreshDisplay {
            in corrected = dispCorrected.corrected;
            in result = dispForecast.result;
        }
    }

    part def WeatherStation {
        attribute stationAltitude : AltitudeValue = 100 [m];
        attribute refreshInterval : TimeValue = 600 [s];

        part sensor : BarometricSensor;
        part processor : DataProcessor;
        part forecaster : ForecastEngine;
        part display : DisplayUnit;

        connect sensor.sensorOut to processor.procIn;
        connect processor.procOut to display.dispCorrected;
        connect processor.logOut to forecaster.forecastIn;
        connect forecaster.forecastOut to display.dispForecast;

        state machine AtmosphericConditions {
            initial start;
            state stableWeather;
            state risingPressure;
            state fallingPressure;
            state stormApproaching;

            transition from start to stableWeather;
            transition from stableWeather to risingPressure
                when forecaster.forecastOut.result.trend == PressureTrend::rising;
            transition from stableWeather to fallingPressure
                when forecaster.forecastOut.result.trend == PressureTrend::falling;
            transition from stableWeather to stormApproaching
                when forecaster.forecastOut.result.trend == PressureTrend::rapidChange;
            transition from risingPressure to stableWeather
                when forecaster.forecastOut.result.trend == PressureTrend::stable;
            transition from risingPressure to stormApproaching
                when forecaster.forecastOut.result.trend == PressureTrend::rapidChange;
            transition from fallingPressure to stableWeather
                when forecaster.forecastOut.result.trend == PressureTrend::stable;
            transition from fallingPressure to stormApproaching
                when forecaster.forecastOut.result.trend == PressureTrend::rapidChange;
            transition from stormApproaching to stableWeather
                when forecaster.forecastOut.result.trend == PressureTrend::stable;
        }

        perform action monitor : MonitoringCycle {
            in altitude = stationAltitude;
            in refresh = refreshInterval;
        }
    }

    requirement def ReqContinuousMonitoring {
        doc /* The system shall continuously measure atmospheric pressure, temperature, and humidity in a cyclic manner. */
    }
    requirement def ReqAltitudeCorrection {
        doc /* The system shall correct raw pressure readings to sea-level equivalent using measured temperature and configured altitude. */
    }
    requirement def ReqPressureLogging {
        doc /* The system shall maintain a 24-hour historical log of corrected pressure readings. */
    }
    requirement def ReqTrendAnalysis {
        doc /* The system shall analyze pressure history to determine trend and rate of change. */
    }
    requirement def ReqWeatherForecast {
        doc /* The system shall generate a weather forecast based on pressure trend analysis. */
    }
    requirement def ReqDisplayRefresh {
        doc /* The system shall present corrected pressure and forecast to the user at regular intervals. */
    }
    requirement def ReqStormDetection {
        doc /* The system shall identify rapid pressure changes indicative of an approaching storm. */
    }

    satisfy ReqContinuousMonitoring by WeatherStation::sensor;
    satisfy ReqAltitudeCorrection by WeatherStation::processor;
    satisfy ReqPressureLogging by WeatherStation::processor;
    satisfy ReqTrendAnalysis by WeatherStation::forecaster;
    satisfy ReqWeatherForecast by WeatherStation::forecaster;
    satisfy ReqDisplayRefresh by WeatherStation::display;
    satisfy ReqStormDetection by WeatherStation::forecaster;
}

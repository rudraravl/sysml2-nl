package PsychrometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def RelativeHumidityValue :> Real;
    attribute def EvaporationRateValue :> Real;
    
    item def AirSample {
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute pressure : ISQ::PressureValue;
        attribute humidity : RelativeHumidityValue;
        attribute velocity : ISQ::SpeedValue;
    }
    
    item def WaterReservoir {
        attribute level : ISQ::LengthValue;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute flowRate : ISQ::VolumeFlowRateValue;
    }
    
    port def AirSamplingPort {
        in item sample : AirSample;
    }
    
    port def TemperatureReadingPort {
        out attribute temperature : ISQ::ThermodynamicTemperatureValue;
    }
    
    port def HumidityDataPort {
        out attribute relativeHumidity : RelativeHumidityValue;
        out attribute dryBulbTemp : ISQ::ThermodynamicTemperatureValue;
        out attribute wetBulbTemp : ISQ::ThermodynamicTemperatureValue;
    }
    
    port def WaterSupplyPort {
        in item water : WaterReservoir;
    }
    
    part def DryBulbThermometer {
        attribute currentReading : ISQ::ThermodynamicTemperatureValue;
        attribute calibrationOffset : ISQ::ThermodynamicTemperatureValue;
        attribute responseTime : ISQ::TimeValue;
        
        port airInput : AirSamplingPort;
        port tempOutput : TemperatureReadingPort;
        
        action def MeasureDryBulbTemperature {
            in airSample : AirSample;
            in offset : ISQ::ThermodynamicTemperatureValue;
            out temperature : ISQ::ThermodynamicTemperatureValue;
        }
        
        perform action measure : MeasureDryBulbTemperature {
            in airSample;
            in offset = calibrationOffset;
            out temperature;
        }
    }
    
    part def WetBulbThermometer {
        attribute currentReading : ISQ::ThermodynamicTemperatureValue;
        attribute calibrationOffset : ISQ::ThermodynamicTemperatureValue;
        attribute responseTime : ISQ::TimeValue;
        attribute wickSaturation : Real;
        
        port airInput : AirSamplingPort;
        port waterInput : WaterSupplyPort;
        port tempOutput : TemperatureReadingPort;
        
        part wick {
            attribute material : ScalarValues::String;
            attribute thickness : ISQ::LengthValue;
            attribute absorptionCapacity : Real;
        }
        
        action def SaturateWick {
            in water : WaterReservoir;
            out saturationLevel : Real;
        }
        
        action def MeasureWetBulbTemperature {
            in airSample : AirSample;
            in wickSaturation : Real;
            in offset : ISQ::ThermodynamicTemperatureValue;
            out temperature : ISQ::ThermodynamicTemperatureValue;
        }
        
        perform action measureWet {
            action saturate : SaturateWick {
                in water;
                out saturationLevel;
            }
            then action measure : MeasureWetBulbTemperature {
                in airSample;
                in wickSaturation = saturate.saturationLevel;
                in offset = calibrationOffset;
                out temperature;
            }
        }
    }
    
    part def HumidityProcessor {
        attribute lastCalculatedHumidity : RelativeHumidityValue;
        attribute calculationMethod : ScalarValues::String;
        attribute atmosphericPressure : ISQ::PressureValue;
        
        port dryTempInput : TemperatureReadingPort;
        port wetTempInput : TemperatureReadingPort;
        port humidityOutput : HumidityDataPort;
        
        action def ComputeRelativeHumidity {
            in dryBulbTemperature : ISQ::ThermodynamicTemperatureValue;
            in wetBulbTemperature : ISQ::ThermodynamicTemperatureValue;
            in pressure : ISQ::PressureValue;
            out relativeHumidity : RelativeHumidityValue;
        }
        
        action def ValidateTemperatureReadings {
            in dryTemp : ISQ::ThermodynamicTemperatureValue;
            in wetTemp : ISQ::ThermodynamicTemperatureValue;
            out isValid : ScalarValues::Boolean;
        }
        
        perform action processHumidity {
            in attribute dryReading : ISQ::ThermodynamicTemperatureValue;
            in attribute wetReading : ISQ::ThermodynamicTemperatureValue;
            out attribute humidity : RelativeHumidityValue;
            
            action validate : ValidateTemperatureReadings {
                in dryTemp = processHumidity::dryReading;
                in wetTemp = processHumidity::wetReading;
                out isValid;
            }
            then decide;
                if validate.isValid then compute;
                if not validate.isValid then error;
            action compute : ComputeRelativeHumidity {
                in dryBulbTemperature = processHumidity::dryReading;
                in wetBulbTemperature = processHumidity::wetReading;
                in pressure = atmosphericPressure;
                out relativeHumidity;
            }
            then assign humidity := compute.relativeHumidity;
            action error {
                then assign humidity := 0.0;
            }
        }
    }
    
    part def DisplayUnit {
        attribute displayResolution : Real;
        attribute updateInterval : ISQ::TimeValue;
        attribute backlightEnabled : ScalarValues::Boolean;
        
        port dataInput : HumidityDataPort;
        
        action def RenderHumidityData {
            in humidity : RelativeHumidityValue;
            in dryTemp : ISQ::ThermodynamicTemperatureValue;
            in wetTemp : ISQ::ThermodynamicTemperatureValue;
        }
        
        action def UpdateDisplay {
            in data : HumidityDataPort;
        }
        
        perform action displayCycle {
            in attribute humidityData : HumidityDataPort;
            
            loop {
                action render : RenderHumidityData {
                    in humidity = humidityData.relativeHumidity;
                    in dryTemp = humidityData.dryBulbTemp;
                    in wetTemp = humidityData.wetBulbTemp;
                }
                then action update : UpdateDisplay {
                    in data = humidityData;
                }
            }
        }
    }
    
    part def VentilationFan {
        attribute fanSpeed : ISQ::AngularVelocityValue;
        attribute powerConsumption : ISQ::PowerValue;
        
        action def CirculateAir {
            in targetVelocity : ISQ::SpeedValue;
            out airflow : ISQ::VolumeFlowRateValue;
        }
        
        perform action ventilate : CirculateAir {
            in targetVelocity;
            out airflow;
        }
    }
    
    action def DetermineAtmosphericHumidity {
        in ambientAir : AirSample;
        in waterSupply : WaterReservoir;
        out relativeHumidity : RelativeHumidityValue;
        out ambientTemperature : ISQ::ThermodynamicTemperatureValue;
        
        private attribute dryTemp : ISQ::ThermodynamicTemperatureValue;
        private attribute wetTemp : ISQ::ThermodynamicTemperatureValue;
        
        first start;
        then action sampleAir {
            in air : AirSample = ambientAir;
        }
        then fork;
            action measureDry : DryBulbThermometer::MeasureDryBulbTemperature {
                in airSample = ambientAir;
                in offset;
                out temperature;
            }
        and action measureWet : WetBulbThermometer::MeasureWetBulbTemperature {
                in airSample = ambientAir;
                in wickSaturation;
                in offset;
                out temperature;
            }
        join;
        then assign dryTemp := measureDry.temperature;
        then assign wetTemp := measureWet.temperature;
        then action calculate : HumidityProcessor::ComputeRelativeHumidity {
            in dryBulbTemperature = dryTemp;
            in wetBulbTemperature = wetTemp;
            in pressure = ambientAir.pressure;
            out relativeHumidity;
        }
        then assign relativeHumidity := calculate.relativeHumidity;
        then assign ambientTemperature := dryTemp;
        then done;
    }
    
    part def Psychrometer {
        doc /* A psychrometer determines atmospheric humidity by measuring the temperature 
               difference between a dry-bulb thermometer and a wet-bulb thermometer, then 
               calculating relative humidity using psychrometric principles. */
        
        port ambientAirPort : AirSamplingPort;
        port waterSupplyPort : WaterSupplyPort;
        port humidityOutputPort : HumidityDataPort;
        
        attribute operatingTemperatureRange : ISQ::ThermodynamicTemperatureValue[2];
        attribute measurementAccuracy : RelativeHumidityValue;
        attribute calibrationDate : ScalarValues::String;
        
        part dryThermometer : DryBulbThermometer {
            perform measure;
        }
        
        part wetThermometer : WetBulbThermometer {
            perform measureWet;
        }
        
        part processor : HumidityProcessor {
            perform processHumidity;
        }
        
        part display : DisplayUnit {
            perform displayCycle;
        }
        
        part fan : VentilationFan {
            perform ventilate;
        }
        
        part waterReservoir : WaterReservoir {
            attribute capacity : ISQ::VolumeValue;
            attribute currentLevel : ISQ::LengthValue;
        }
        
        perform action measureHumidity[*] ordered references determineAtmosphericHumidity {
            in ambientAir;
            in waterSupply;
            out relativeHumidity;
            out ambientTemperature;
        }
        
        connection airToDry : FlowConnection
            connect ambientAirPort to dryThermometer.airInput;
            
        connection airToWet : FlowConnection
            connect ambientAirPort to wetThermometer.airInput;
            
        connection waterToWet : FlowConnection
            connect waterSupplyPort to wetThermometer.waterInput;
            
        connection dryToProcessor : FlowConnection
            connect dryThermometer.tempOutput to processor.dryTempInput;
            
        connection wetToProcessor : FlowConnection
            connect wetThermometer.tempOutput to processor.wetTempInput;
            
        connection processorToDisplay : FlowConnection
            connect processor.humidityOutput to display.dataInput;
            
        connection processorToOutput : FlowConnection
            connect processor.humidityOutput to humidityOutputPort;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The psychrometer shall measure atmospheric relative humidity by comparing 
               dry-bulb and wet-bulb temperature readings and applying psychrometric calculations. */
        
        subject system : Psychrometer;
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* The psychrometer shall measure relative humidity with an accuracy of ±3% RH 
               across the operating range. */
        
        subject system : Psychrometer;
        
        require constraint {
            system.measurementAccuracy <= 3.0
        }
    }
    
    requirement def OperatingRangeRequirement {
        doc /* The psychrometer shall operate accurately within a temperature range of 
               0°C to 50°C and humidity range of 10% to 95% RH. */
        
        subject system : Psychrometer;
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The psychrometer shall provide stable humidity readings within 90 seconds 
               of measurement initiation. */
        
        subject system : Psychrometer;
    }
    
    requirement def WaterSupplyRequirement {
        doc /* The wet-bulb thermometer wick shall maintain adequate water saturation 
               throughout the measurement cycle. */
        
        subject wetBulb : WetBulbThermometer;
        
        require constraint {
            wetBulb.wickSaturation >= 0.95
        }
    }
    
    requirement psychrometerSystemRequirements {
        doc /* Top-level requirements for the psychrometer measurement system. */
        
        subject psychrometerSystem : Psychrometer;
        
        require primaryFunction : PrimaryFunctionRequirement;
        require accuracy : MeasurementAccuracyRequirement;
        require operatingRange : OperatingRangeRequirement;
        require responseTime : ResponseTimeRequirement;
        require waterSupply : WaterSupplyRequirement;
    }
    
    part psychrometerInstance : Psychrometer {
        :>> measurementAccuracy = 2.5;
        :>> calibrationDate = "2024-01-15";
        
        perform measureHumidity;
    }
}

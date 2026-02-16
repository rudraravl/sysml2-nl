package LifeSupportSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def OxygenConcentration :> Real;
    attribute def CarbonDioxideConcentration :> Real;
    attribute def RelativeHumidity :> Real;
    
    attribute def AtmosphericComposition {
        attribute oxygenLevel : OxygenConcentration;
        attribute co2Level : CarbonDioxideConcentration;
        attribute nitrogenLevel : Real;
        attribute pressure : ISQ::PressureValue;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute humidity : RelativeHumidity;
    }
    
    attribute def WaterQualityMetrics {
        attribute purity : Real;
        attribute pH : Real;
        attribute contaminantLevel : Real;
        attribute totalDissolvedSolids : ISQ::MassValue;
    }
    
    item def Atmosphere {
        attribute composition : AtmosphericComposition;
    }
    
    item def WaterSupply {
        attribute quality : WaterQualityMetrics;
        attribute volume : ISQ::VolumeValue;
        attribute flowRate : ISQ::VolumeValue;
    }
    
    port def AtmospherePort {
        inout atmosphere : Atmosphere;
    }
    
    port def WaterPort {
        inout water : WaterSupply;
    }
    
    port def PowerPort {
        in power : ISQ::PowerValue;
    }
    
    port def SensorDataPort {
        out atmosphereData : AtmosphericComposition;
        out waterData : WaterQualityMetrics;
    }
    
    port def ControlCommandPort {
        in oxygenGenerationRate : ISQ::VolumeValue;
        in co2RemovalRate : ISQ::VolumeValue;
        in temperatureSetpoint : ISQ::ThermodynamicTemperatureValue;
        in humiditySetpoint : RelativeHumidity;
    }
    
    part def OxygenGenerationSubsystem {
        port atmosphereOut : AtmospherePort;
        port powerIn : PowerPort;
        port controlIn : ControlCommandPort;
        
        attribute productionCapacity : ISQ::VolumeValue;
        attribute efficiency : Real;
        
        action generateOxygen {
            in powerLevel : ISQ::PowerValue;
            in targetRate : ISQ::VolumeValue;
            out oxygenProduced : ISQ::VolumeValue;
        }
    }
    
    part def CarbonDioxideRemovalSubsystem {
        port atmosphereIn : AtmospherePort;
        port atmosphereOut : AtmospherePort;
        port powerIn : PowerPort;
        port controlIn : ControlCommandPort;
        
        attribute removalCapacity : ISQ::VolumeValue;
        attribute scrubberEfficiency : Real;
        
        action removeCO2 {
            in contaminatedAtmosphere : Atmosphere;
            in removalRate : ISQ::VolumeValue;
            out cleanedAtmosphere : Atmosphere;
            out co2Removed : ISQ::VolumeValue;
        }
    }
    
    part def TemperatureHumidityControlSubsystem {
        port atmosphereInOut : AtmospherePort;
        port powerIn : PowerPort;
        port controlIn : ControlCommandPort;
        
        attribute coolingCapacity : ISQ::PowerValue;
        attribute heatingCapacity : ISQ::PowerValue;
        attribute dehumidificationRate : ISQ::VolumeValue;
        
        action regulateClimate {
            in currentTemp : ISQ::ThermodynamicTemperatureValue;
            in targetTemp : ISQ::ThermodynamicTemperatureValue;
            in currentHumidity : RelativeHumidity;
            in targetHumidity : RelativeHumidity;
            out adjustedAtmosphere : Atmosphere;
        }
    }
    
    part def WaterReclamationSubsystem {
        port wasteWaterIn : WaterPort;
        port potableWaterOut : WaterPort;
        port powerIn : PowerPort;
        
        attribute processingCapacity : ISQ::VolumeValue;
        attribute purificationEfficiency : Real;
        
        action purifyWater {
            in wasteWater : WaterSupply;
            out potableWater : WaterSupply;
            out contaminantsRemoved : ISQ::MassValue;
        }
    }
    
    part def EnvironmentalMonitoringSubsystem {
        port atmosphereSensor : AtmospherePort;
        port waterSensor : WaterPort;
        port sensorDataOut : SensorDataPort;
        
        action monitorEnvironment {
            in atmosphere : Atmosphere;
            in water : WaterSupply;
            out oxygenReading : OxygenConcentration;
            out co2Reading : CarbonDioxideConcentration;
            out temperatureReading : ISQ::ThermodynamicTemperatureValue;
            out humidityReading : RelativeHumidity;
            out pressureReading : ISQ::PressureValue;
            out waterQualityReading : WaterQualityMetrics;
        }
    }
    
    part def LifeSupportControlUnit {
        port sensorDataIn : SensorDataPort;
        port oxygenControl : ControlCommandPort;
        port co2Control : ControlCommandPort;
        port climateControl : ControlCommandPort;
        
        attribute controlCyclePeriod : ISQ::TimeValue;
        
        action analyzeAndControl {
            in sensorData : AtmosphericComposition;
            in waterData : WaterQualityMetrics;
            out oxygenCommand : ISQ::VolumeValue;
            out co2Command : ISQ::VolumeValue;
            out tempCommand : ISQ::ThermodynamicTemperatureValue;
            out humidityCommand : RelativeHumidity;
        }
        
        state controlStateMachine {
            entry; then Initialization;
            
            state Initialization;
            accept at Initialization then NominalOperation;
            
            state NominalOperation;
            accept at NominalOperation then EmergencyMode;
            
            state EmergencyMode;
            accept at EmergencyMode then NominalOperation;
            accept at EmergencyMode then Shutdown;
            accept at NominalOperation then Shutdown;
            
            state Shutdown;
        }
    }
    
    requirement def LifeSupportRequirements {
        doc /* The life support system shall maintain a safe and habitable environment 
               for human occupants by continuously regulating atmospheric composition, 
               temperature, humidity, pressure, and providing potable water. */
        
        requirement <'LSS-001'> atmosphericOxygenRequirement {
            doc /* Oxygen concentration shall be maintained between 19.5% and 23.5% by volume. */
            subject habitableEnvironment : Atmosphere;
            assume constraint {
                habitableEnvironment.composition.oxygenLevel >= 0.195 and
                habitableEnvironment.composition.oxygenLevel <= 0.235
            }
        }
        
        requirement <'LSS-002'> carbonDioxideRequirement {
            doc /* Carbon dioxide concentration shall not exceed 0.5% by volume. */
            subject habitableEnvironment : Atmosphere;
            require constraint {
                habitableEnvironment.composition.co2Level <= 0.005
            }
        }
        
        requirement <'LSS-003'> temperatureRequirement {
            doc /* Ambient temperature shall be maintained between 291.15 K and 300.15 K (18°C to 27°C). */
            subject habitableEnvironment : Atmosphere;
            require constraint {
                habitableEnvironment.composition.temperature >= 291.15[K] and
                habitableEnvironment.composition.temperature <= 300.15[K]
            }
        }
        
        requirement <'LSS-004'> humidityRequirement {
            doc /* Relative humidity shall be maintained between 30% and 70%. */
            subject habitableEnvironment : Atmosphere;
            require constraint {
                habitableEnvironment.composition.humidity >= 0.30 and
                habitableEnvironment.composition.humidity <= 0.70
            }
        }
        
        requirement <'LSS-005'> pressureRequirement {
            doc /* Atmospheric pressure shall be maintained between 95 kPa and 105 kPa. */
            subject habitableEnvironment : Atmosphere;
            require constraint {
                habitableEnvironment.composition.pressure >= 95000[Pa] and
                habitableEnvironment.composition.pressure <= 105000[Pa]
            }
        }
        
        requirement <'LSS-006'> waterQualityRequirement {
            doc /* Potable water purity shall be at least 99.9% with contaminant levels below 0.01%. */
            subject potableWater : WaterSupply;
            require constraint {
                potableWater.quality.purity >= 0.999 and
                potableWater.quality.contaminantLevel <= 0.0001
            }
        }
    }
    
    part def LifeSupportSystem {
        doc /* 
            The Life Support System maintains a habitable environment for human occupants 
            in enclosed or isolated environments such as spacecraft, submarines, or 
            underground facilities.
            
            Primary Function:
            The system continuously monitors and regulates atmospheric composition by 
            generating oxygen and removing carbon dioxide, controls temperature and humidity 
            to maintain comfort and safety, regulates atmospheric pressure, and reclaims 
            water from waste streams to provide potable water. It operates through a 
            closed-loop control system that uses sensor feedback to automatically adjust 
            subsystem operations, ensuring optimal conditions for human survival and comfort 
            while maximizing resource efficiency and system reliability.
        */
        
        part oxygenGenerator : OxygenGenerationSubsystem {
            :>> productionCapacity = 2.5[m^3];
            :>> efficiency = 0.85;
        }
        
        part co2Scrubber : CarbonDioxideRemovalSubsystem {
            :>> removalCapacity = 3.0[m^3];
            :>> scrubberEfficiency = 0.92;
        }
        
        part climateControl : TemperatureHumidityControlSubsystem {
            :>> coolingCapacity = 5000[W];
            :>> heatingCapacity = 3000[W];
            :>> dehumidificationRate = 0.5[m^3];
        }
        
        part waterReclamation : WaterReclamationSubsystem {
            :>> processingCapacity = 0.1[m^3];
            :>> purificationEfficiency = 0.995;
        }
        
        part environmentalMonitor : EnvironmentalMonitoringSubsystem;
        
        part controlUnit : LifeSupportControlUnit {
            :>> controlCyclePeriod = 1.0[s];
        }
        
        port habitatAtmosphere : AtmospherePort;
        port potableWaterSupply : WaterPort;
        port systemPower : PowerPort;
        
        connect environmentalMonitor.sensorDataOut to controlUnit.sensorDataIn;
        connect controlUnit.oxygenControl to oxygenGenerator.controlIn;
        connect controlUnit.co2Control to co2Scrubber.controlIn;
        connect controlUnit.climateControl to climateControl.controlIn;
        
        connect habitatAtmosphere to environmentalMonitor.atmosphereSensor;
        connect habitatAtmosphere to co2Scrubber.atmosphereIn;
        connect co2Scrubber.atmosphereOut to climateControl.atmosphereInOut;
        connect oxygenGenerator.atmosphereOut to habitatAtmosphere;
        
        connect waterReclamation.potableWaterOut to potableWaterSupply;
        connect potableWaterSupply to environmentalMonitor.waterSensor;
        
        satisfy LifeSupportRequirements;
        
        perform action maintainHabitableEnvironment {
            first start;
            then merge continuousControl;
            
            action monitor : EnvironmentalMonitoringSubsystem::monitorEnvironment {
                in atmosphere;
                in water;
                out oxygenReading;
                out co2Reading;
                out temperatureReading;
                out humidityReading;
                out pressureReading;
                out waterQualityReading;
            }
            
            then action control : LifeSupportControlUnit::analyzeAndControl {
                in sensorData;
                in waterData;
                out oxygenCommand;
                out co2Command;
                out tempCommand;
                out humidityCommand;
            }
            
            then action parallel {
                action generateO2 : OxygenGenerationSubsystem::generateOxygen {
                    in powerLevel;
                    in targetRate = control.oxygenCommand;
                    out oxygenProduced;
                }
                
                action scrubbingCO2 : CarbonDioxideRemovalSubsystem::removeCO2 {
                    in contaminatedAtmosphere;
                    in removalRate = control.co2Command;
                    out cleanedAtmosphere;
                    out co2Removed;
                }
                
                action regulateClimate : TemperatureHumidityControlSubsystem::regulateClimate {
                    in currentTemp = monitor.temperatureReading;
                    in targetTemp = control.tempCommand;
                    in currentHumidity = monitor.humidityReading;
                    in targetHumidity = control.humidityCommand;
                    out adjustedAtmosphere;
                }
                
                action reclaimWater : WaterReclamationSubsystem::purifyWater {
                    in wasteWater;
                    out potableWater;
                    out contaminantsRemoved;
                }
            }
            
            then continuousControl;
        }
    }
    
    part lifeSupportSystem : LifeSupportSystem;
}

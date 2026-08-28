package BrineProcessingSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQVolume::*;
    import ISQTemperature::*;
    import ISQPressure::*;
    import ISQMass::*;

    // ===== Item Types =====
    item def RawBrine {
        attribute salinity : MassDensity = 35.0 [g/L];
        attribute temperature : TemperatureValue = 25.0 [°C];
        attribute flowRate : VolumeFlowRateValue = 0.0 [L/min];
    }

    item def HeatedBrine :> RawBrine {
        redefines salinity = 35.0 [g/L];
        redefines temperature = 85.0 [°C];
    }

    item def WaterVapor {
        attribute temperature : TemperatureValue = 100.0 [°C];
        attribute pressure : PressureValue = 101.325 [kPa];
        attribute purity : MassFraction = 0.999;
    }

    item def FreshWater {
        attribute salinity : MassDensity = 0.5 [g/L];
        attribute temperature : TemperatureValue = 35.0 [°C];
        attribute volume : VolumeValue = 0.0 [L];
    }

    item def ConcentratedBrine :> RawBrine {
        redefines salinity = 250.0 [g/L];
        redefines temperature = 95.0 [°C];
    }

    // ===== Value Types =====
    value def SalinityValue :> MassDensity {
        unit g/L;
    }

    value def TemperatureSetpoint :> TemperatureValue {
        unit °C;
    }

    value def PressureSetpoint :> PressureValue {
        unit kPa;
    }

    value def FlowRateSetpoint :> VolumeFlowRateValue {
        unit L/min;
    }

    // ===== Port Definitions =====
    port def BrineInPort {
        out item brine : RawBrine;
    }

    port def BrineOutPort {
        in item brine : RawBrine;
    }

    port def HeatedBrineOutPort {
        out item heatedBrine : HeatedBrine;
    }

    port def HeatedBrineInPort {
        in item heatedBrine : HeatedBrine;
    }

    port def VaporOutPort {
        out item vapor : WaterVapor;
    }

    port def VaporInPort {
        in item vapor : WaterVapor;
    }

    port def FreshWaterOutPort {
        out item freshWater : FreshWater;
    }

    port def FreshWaterInPort {
        in item freshWater : FreshWater;
    }

    port def ConcentrateOutPort {
        out item concentrate : ConcentratedBrine;
    }

    port def ConcentrateInPort {
        in item concentrate : ConcentratedBrine;
    }

    port def ControlSignalPort {
        out attribute setpoint : TemperatureSetpoint;
        out attribute enable : Boolean;
    }

    port def ControlFeedbackPort {
        in attribute measuredTemp : TemperatureValue;
        in attribute measuredSalinity : SalinityValue;
    }

    port def SalinitySignalPort {
        out attribute salinityReading : SalinityValue;
        out attribute valid : Boolean;
    }

    // ===== Component Parts =====
    part def FeedTank {
        attribute capacity : VolumeValue = 5000.0 [L];
        attribute currentLevel : VolumeValue = 0.0 [L];
        port brineOut : BrineOutPort;
        
        action def dispenseBrine {
            in currentLevel : VolumeValue;
            out dispensedBrine : RawBrine;
        }
    }

    part def CirculationPump {
        attribute ratedFlowRate : FlowRateSetpoint = 50.0 [L/min];
        attribute powerConsumption : PowerValue = 2.2 [kW];
        attribute isRunning : Boolean = false;
        port brineIn : BrineInPort;
        port brineOut : BrineOutPort;
        
        action def pumpBrine {
            in rawBrine : RawBrine;
            out pumpedBrine : RawBrine;
        }
    }

    part def PreHeater {
        attribute targetTemperature : TemperatureSetpoint = 85.0 [°C];
        attribute heatingPower : PowerValue = 15.0 [kW];
        attribute isHeating : Boolean = false;
        port brineIn : BrineInPort;
        port heatedBrineOut : HeatedBrineOutPort;
        port controlIn : ControlSignalPort;
        port feedbackOut : ControlFeedbackPort;
        
        action def heatBrine {
            in incomingBrine : RawBrine;
            in setpoint : TemperatureSetpoint;
            out heatedBrine : HeatedBrine;
        }
    }

    part def EvaporationUnit {
        attribute operatingTemperature : TemperatureSetpoint = 100.0 [°C];
        attribute operatingPressure : PressureSetpoint = 101.325 [kPa];
        attribute heatInput : PowerValue = 50.0 [kW];
        attribute isOperational : Boolean = false;
        port heatedBrineIn : HeatedBrineInPort;
        port vaporOut : VaporOutPort;
        port concentrateOut : ConcentrateOutPort;
        
        action def evaporate {
            in heatedBrine : HeatedBrine;
            out vapor : WaterVapor;
            out concentrate : ConcentratedBrine;
        }
    }

    part def Condenser {
        attribute coolingWaterFlow : FlowRateSetpoint = 100.0 [L/min];
        attribute condensationEfficiency : Real = 0.95;
        port vaporIn : VaporInPort;
        port freshWaterOut : FreshWaterOutPort;
        
        action def condense {
            in vapor : WaterVapor;
            out freshWater : FreshWater;
        }
    }

    part def ProductTank {
        attribute capacity : VolumeValue = 3000.0 [L];
        attribute currentLevel : VolumeValue = 0.0 [L];
        attribute maxSalinity : SalinityValue = 1.0 [g/L];
        port freshWaterIn : FreshWaterInPort;
    }

    part def ConcentrateTank {
        attribute capacity : VolumeValue = 2000.0 [L];
        attribute currentLevel : VolumeValue = 0.0 [L];
        attribute minSalinity : SalinityValue = 200.0 [g/L];
        port concentrateIn : ConcentrateInPort;
    }

    part def TemperatureController {
        attribute setpoint : TemperatureSetpoint = 85.0 [°C];
        attribute proportionalGain : Real = 2.0;
        attribute integralGain : Real = 0.5;
        attribute isAuto : Boolean = false;
        port controlOut : ControlSignalPort;
        port feedbackIn : ControlFeedbackPort;
        
        action def regulateTemperature {
            in measuredTemp : TemperatureValue;
            in targetTemp : TemperatureSetpoint;
            out controlSignal : TemperatureSetpoint;
        }
    }

    part def SalinityMonitor {
        attribute measurementRange : SalinityValue = 300.0 [g/L];
        attribute accuracy : SalinityValue = 0.5 [g/L];
        attribute isCalibrated : Boolean = true;
        port salinityOut : SalinitySignalPort;
        
        action def measureSalinity {
            in brineSample : RawBrine;
            out salinityReading : SalinityValue;
            out valid : Boolean;
        }
    }

    // ===== Top-level System =====
    part BrineProcessingPlant {
        // Sub-parts
        part feedTank : FeedTank;
        part circulationPump : CirculationPump;
        part preHeater : PreHeater;
        part evaporationUnit : EvaporationUnit;
        part condenser : Condenser;
        part productTank : ProductTank;
        part concentrateTank : ConcentrateTank;
        part temperatureController : TemperatureController;
        part salinityMonitor : SalinityMonitor;

        // Connections
        connection feedToPump : BrineOutPort ::> BrineInPort connect 
            feedTank.brineOut to circulationPump.brineIn;
        
        connection pumpToHeater : BrineOutPort ::> BrineInPort connect 
            circulationPump.brineOut to preHeater.brineIn;
        
        connection heaterToEvap : HeatedBrineOutPort ::> HeatedBrineInPort connect 
            preHeater.heatedBrineOut to evaporationUnit.heatedBrineIn;
        
        connection evapToCondenser : VaporOutPort ::> VaporInPort connect 
            evaporationUnit.vaporOut to condenser.vaporIn;
        
        connection condenserToProduct : FreshWaterOutPort ::> FreshWaterInPort connect 
            condenser.freshWaterOut to productTank.freshWaterIn;
        
        connection evapToConcentrate : ConcentrateOutPort ::> ConcentrateInPort connect 
            evaporationUnit.concentrateOut to concentrateTank.concentrateIn;
        
        connection tempControl : ControlSignalPort ::> ControlSignalPort connect 
            temperatureController.controlOut to preHeater.controlIn;
        
        connection tempFeedback : ControlFeedbackPort ::> ControlFeedbackPort connect 
            preHeater.feedbackOut to temperatureController.feedbackIn;
        
        connection salinitySignal : SalinitySignalPort ::> SalinitySignalPort connect 
            salinityMonitor.salinityOut to temperatureController.feedbackIn;

        // ===== State Machine =====
        state def BrineProcessingLifecycle {
            entry action initializeSystem {
                // Initialize all components
            }

            state standby {
                entry action enterStandby {
                    // System idle, all pumps off, heaters off
                }
                do action monitorStandby {
                    // Monitor for start command
                }
            }

            state startup {
                entry action enterStartup {
                    // Power on controllers, verify sensors
                }
                do action runStartupChecks {
                    // Verify feed tank level, pump readiness
                }
                transition to heating 
                    when feedTank.currentLevel > 100.0 [L];
            }

            state heating {
                entry action enterHeating {
                    // Activate pre-heater and temperature controller
                }
                do action rampUpTemperature {
                    // Heat brine to 85°C
                }
                transition to evaporating 
                    when preHeater.targetTemperature >= 85.0 [°C];
            }

            state evaporating {
                entry action enterEvaporating {
                    // Activate evaporation unit
                }
                do action continuousEvaporation {
                    // Continuously evaporate brine
                }
                transition to concentrating 
                    when evaporationUnit.isOperational == true;
            }

            state concentrating {
                entry action enterConcentrating {
                    // Collect concentrated brine
                }
                do action collectConcentrate {
                    // Monitor concentrate salinity >= 200 g/L
                }
                transition to evaporating 
                    when concentrateTank.currentLevel < concentrateTank.capacity;
                transition to shutdown 
                    when feedTank.currentLevel < 50.0 [L];
            }

            state shutdown {
                entry action enterShutdown {
                    // Begin controlled cooldown
                }
                do action coolDown {
                    // Reduce temperatures safely
                }
                transition to standby 
                    when evaporationUnit.operatingTemperature < 40.0 [°C];
            }

            transition standby to startup 
                when feedTank.currentLevel > 500.0 [L];
            transition shutdown to standby 
                when evaporationUnit.operatingTemperature < 40.0 [°C];
        }

        // Instantiate state machine
        exhibit state BrineProcessingLifecycle;
    }

    // ===== Requirements =====
    requirement def FeedTankRequirement {
        doc /* The feed tank shall store raw brine with minimum capacity of 5000 L */
        subject feedTank : FeedTank;
        require feedTank.capacity >= 5000.0 [L];
    }

    requirement def PreHeaterTemperatureRequirement {
        doc /* The pre-heater shall raise brine temperature to 85°C ±2°C */
        subject preHeater : PreHeater;
        require preHeater.targetTemperature == 85.0 [°C];
    }

    requirement def FreshWaterQualityRequirement {
        doc /* The fresh water product shall have salinity less than 1 g/L */
        subject freshWater : FreshWater;
        require freshWater.salinity < 1.0 [g/L];
    }

    requirement def ConcentrateQualityRequirement {
        doc /* The concentrated brine shall have salinity of at least 200 g/L */
        subject concentrate : ConcentratedBrine;
        require concentrate.salinity >= 200.0 [g/L];
    }

    requirement def EvaporationOperatingConditionRequirement {
        doc /* The evaporation unit shall operate at 100°C and 101.325 kPa */
        subject evapUnit : EvaporationUnit;
        require evapUnit.operatingTemperature == 100.0 [°C];
        require evapUnit.operatingPressure == 101.325 [kPa];
    }

    requirement def PumpFlowRateRequirement {
        doc /* The circulation pump shall deliver at least 50 L/min */
        subject pump : CirculationPump;
        require pump.ratedFlowRate >= 50.0 [L/min];
    }

    requirement def SalinityMonitorAccuracyRequirement {
        doc /* The salinity monitor shall measure salinity with accuracy of 0.5 g/L */
        subject monitor : SalinityMonitor;
        require monitor.accuracy <= 0.5 [g/L];
    }

    requirement def SystemLifecycleRequirement {
        doc /* The system shall follow the lifecycle: standby, startup, heating, evaporating, concentrating, shutdown */
        subject plant : BrineProcessingPlant;
        require plant.state == BrineProcessingLifecycle::standby or
                plant.state == BrineProcessingLifecycle::startup or
                plant.state == BrineProcessingLifecycle::heating or
                plant.state == BrineProcessingLifecycle::evaporating or
                plant.state == BrineProcessingLifecycle::concentrating or
                plant.state == BrineProcessingLifecycle::shutdown;
    }

    // ===== Verification =====
    verification PreHeaterTempVerification : PreHeaterTemperatureRequirement {
        subject preHeater : PreHeater;
        objective verify preHeater.targetTemperature == 85.0 [°C];
    }

    verification FreshWaterQualityVerification : FreshWaterQualityRequirement {
        subject freshWater : FreshWater;
        objective verify freshWater.salinity < 1.0 [g/L];
    }

    verification ConcentrateQualityVerification : ConcentrateQualityRequirement {
        subject concentrate : ConcentratedBrine;
        objective verify concentrate.salinity >= 200.0 [g/L];
    }
}

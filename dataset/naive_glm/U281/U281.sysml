package LifeSupportSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;
    import ISQThermodynamics::*;
    import ISQMechanics::*;

    // ===== Value Types =====
    value type PercentValue :> Real;
    value type PPMValue :> Real;
    value type FlowRateValue :> Real;
    value type VolumeValue :> Real;
    value type PowerLevelValue :> Real;

    // ===== Item Definitions =====
    item def Atmosphere {
        attribute oxygenConcentration : PercentValue;
        attribute co2Concentration : PPMValue;
        attribute temperature : Temperature;
        attribute humidity : PercentValue;
        attribute totalPressure : Pressure;
    }

    item def SensorReading {
        attribute oxygenConcentration : PercentValue;
        attribute co2Concentration : PPMValue;
        attribute temperature : Temperature;
        attribute humidity : PercentValue;
        attribute totalPressure : Pressure;
        attribute waterPurity : PercentValue;
        attribute waterContaminantPPM : PPMValue;
    }

    item def OxygenGenerationCommand {
        attribute targetFlowRate : FlowRateValue;
        attribute activationLevel : PowerLevelValue;
    }

    item def CO2ScrubbingCommand {
        attribute targetRemovalRate : FlowRateValue;
        attribute powerLevel : PowerLevelValue;
    }

    item def ClimateCommand {
        attribute targetTemperature : Temperature;
        attribute targetHumidity : PercentValue;
        attribute coolingEnabled : Boolean;
        attribute heatingEnabled : Boolean;
        attribute dehumidifyingEnabled : Boolean;
    }

    item def WaterReclamationCommand {
        attribute flowRate : FlowRateValue;
        attribute targetPurity : PercentValue;
    }

    item def Wastewater {
        attribute turbidity : Real;
        attribute contaminantPPM : PPMValue;
        attribute volume : VolumeValue;
    }

    item def PotableWater {
        attribute purity : PercentValue;
        attribute contaminantPPM : PPMValue;
        attribute volume : VolumeValue;
    }

    // ===== Port Definitions =====
    port def SensorOutputPort {
        out item reading : SensorReading;
    }

    port def ControlInputPort {
        in item reading : SensorReading;
    }

    port def O2ControlPort {
        in item command : OxygenGenerationCommand;
    }

    port def CO2ControlPort {
        in item command : CO2ScrubbingCommand;
    }

    port def ClimateControlPort {
        in item command : ClimateCommand;
    }

    port def WaterControlPort {
        in item command : WaterReclamationCommand;
    }

    port def AirFlowPort {
        inout item air : Atmosphere;
    }

    port def WaterFlowPort {
        in item intake : Wastewater;
        out item output : PotableWater;
    }

    // ===== Subsystem Definitions =====

    part def EnvironmentalMonitoringSubsystem {
        port sensorOutput : SensorOutputPort;
        port airSampling : AirFlowPort;
        port waterSampling : WaterFlowPort;

        attribute oxygenMin : PercentValue = 19.5;
        attribute oxygenMax : PercentValue = 23.5;
        attribute co2Max : PPMValue = 5000;
        attribute tempMin : Temperature = 291.15 'K';
        attribute tempMax : Temperature = 300.15 'K';
        attribute humidityMin : PercentValue = 30;
        attribute humidityMax : PercentValue = 70;
        attribute pressureMin : Pressure = 90.0 'kPa';
        attribute pressureMax : Pressure = 110.0 'kPa';
        attribute waterPurityMin : PercentValue = 99.9;
        attribute waterContaminantMax : PPMValue = 10;

        part oxygenSensor {
            attribute currentReading : PercentValue;
        }
        part co2Sensor {
            attribute currentReading : PPMValue;
        }
        part temperatureSensor {
            attribute currentReading : Temperature;
        }
        part humiditySensor {
            attribute currentReading : PercentValue;
        }
        part pressureSensor {
            attribute currentReading : Pressure;
        }
        part waterQualitySensor {
            attribute currentPurity : PercentValue;
            attribute currentContaminant : PPMValue;
        }

        action sampleAtmosphere {
            in air : Atmosphere;
            out reading : SensorReading;
        }

        action sampleWaterQuality {
            in water : PotableWater;
            out purity : PercentValue;
            out contaminant : PPMValue;
        }

        action emitReadings {
            out reading : SensorReading;
        }

        action monitorCycle {
            in air : Atmosphere;
            in water : PotableWater;
            out reading : SensorReading;
        }
    }

    part def LifeSupportControlUnit {
        port sensorInput : ControlInputPort;
        port o2Output : O2ControlPort;
        port co2Output : CO2ControlPort;
        port climateOutput : ClimateControlPort;
        port waterOutput : WaterControlPort;

        attribute oxygenMin : PercentValue = 19.5;
        attribute oxygenMax : PercentValue = 23.5;
        attribute co2Max : PPMValue = 5000;
        attribute tempMin : Temperature = 291.15 'K';
        attribute tempMax : Temperature = 300.15 'K';
        attribute humidityMin : PercentValue = 30;
        attribute humidityMax : PercentValue = 70;
        attribute pressureMin : Pressure = 90.0 'kPa';
        attribute pressureMax : Pressure = 110.0 'kPa';
        attribute waterPurityMin : PercentValue = 99.9;

        attribute currentReading : SensorReading;
        attribute emergencyActive : Boolean = false;
        attribute shutdownRequested : Boolean = false;

        action analyzeSensorData {
            in reading : SensorReading;
        }

        action determineOxygenCommand {
            in reading : SensorReading;
            out command : OxygenGenerationCommand;
        }

        action determineCO2Command {
            in reading : SensorReading;
            out command : CO2ScrubbingCommand;
        }

        action determineClimateCommand {
            in reading : SensorReading;
            out command : ClimateCommand;
        }

        action determineWaterCommand {
            in reading : SensorReading;
            out command : WaterReclamationCommand;
        }

        state machine controlStateMachine {
            state NormalOperating {
                entry action {
                    emergencyActive = false;
                }
                do action {
                    analyzeSensorData(in reading = currentReading);
                    determineOxygenCommand(in reading = currentReading, out command = o2Output.command);
                    determineCO2Command(in reading = currentReading, out command = co2Output.command);
                    determineClimateCommand(in reading = currentReading, out command = climateOutput.command);
                    determineWaterCommand(in reading = currentReading, out command = waterOutput.command);
                }
            }

            state Emergency {
                entry action {
                    emergencyActive = true;
                }
                do action {
                    analyzeSensorData(in reading = currentReading);
                }
            }

            state SafeShutdown {
                entry action {
                    shutdownRequested = false;
                }
                do action {
                    // Graceful shutdown sequence
                }
            }

            transition from NormalOperating to Emergency
                when (currentReading.oxygenConcentration < oxygenMin ||
                      currentReading.oxygenConcentration > oxygenMax ||
                      currentReading.co2Concentration > co2Max ||
                      currentReading.totalPressure < pressureMin ||
                      currentReading.totalPressure > pressureMax);

            transition from Emergency to SafeShutdown
                when (shutdownRequested == true);

            transition from SafeShutdown to NormalOperating
                when (currentReading.oxygenConcentration >= oxygenMin &&
                      currentReading.oxygenConcentration <= oxygenMax &&
                      currentReading.co2Concentration <= co2Max &&
                      currentReading.totalPressure >= pressureMin &&
                      currentReading.totalPressure <= pressureMax);
        }
    }

    part def OxygenGenerationSubsystem {
        port commandInput : O2ControlPort;
        port airPort : AirFlowPort;

        attribute maxFlowRate : FlowRateValue = 5.0;
        attribute currentFlowRate : FlowRateValue = 0.0;
        attribute activationLevel : PowerLevelValue = 0.0;
        attribute operationalStatus : String = "standby";

        part electrolysisUnit {
            attribute powerConsumption : PowerLevelValue = 0.0;
            attribute maxPower : PowerLevelValue = 100.0;
        }

        part oxygenStorageTank {
            attribute storedVolume : VolumeValue = 0.0;
            attribute maxCapacity : VolumeValue = 100.0;
        }

        action generateOxygen {
            in command : OxygenGenerationCommand;
            in intakeAir : Atmosphere;
            out producedAir : Atmosphere;
        }

        action adjustFlowRate {
            in targetRate : FlowRateValue;
            out actualRate : FlowRateValue;
        }
    }

    part def CO2RemovalSubsystem {
        port commandInput : CO2ControlPort;
        port airPort : AirFlowPort;

        attribute maxRemovalRate : FlowRateValue = 10.0;
        attribute currentRemovalRate : FlowRateValue = 0.0;
        attribute powerLevel : PowerLevelValue = 0.0;
        attribute operationalStatus : String = "standby";

        part absorberBedA {
            attribute saturationLevel : PercentValue = 0.0;
            attribute inUse : Boolean = true;
        }

        part absorberBedB {
            attribute saturationLevel : PercentValue = 0.0;
            attribute inUse : Boolean = false;
        }

        part fanAssembly {
            attribute speed : PowerLevelValue = 0.0;
        }

        action scrubCO2 {
            in command : CO2ScrubbingCommand;
            in intakeAir : Atmosphere;
            out scrubbedAir : Atmosphere;
        }

        action regenerateBed {
            in bedId : String;
            out success : Boolean;
        }

        action switchBeds {
            out bedsSwitched : Boolean;
        }
    }

    part def TemperatureHumidityControlSubsystem {
        port commandInput : ClimateControlPort;
        port airPort : AirFlowPort;

        attribute targetTemperature : Temperature = 294.15 'K';
        attribute targetHumidity : PercentValue = 50;
        attribute coolingActive : Boolean = false;
        attribute heatingActive : Boolean = false;
        attribute dehumidifyingActive : Boolean = false;
        attribute operationalStatus : String = "standby";

        part heater {
            attribute powerLevel : PowerLevelValue = 0.0;
            attribute maxOutput : PowerLevelValue = 100.0;
        }

        part cooler {
            attribute powerLevel : PowerLevelValue = 0.0;
            attribute maxOutput : PowerLevelValue = 100.0;
        }

        part dehumidifier {
            attribute powerLevel : PowerLevelValue = 0.0;
            attribute maxOutput : PowerLevelValue = 100.0;
        }

        part condensateDrain {
            attribute drainVolume : VolumeValue = 0.0;
        }

        action regulateTemperature {
            in command : ClimateCommand;
            in intakeAir : Atmosphere;
            out conditionedAir : Atmosphere;
        }

        action regulateHumidity {
            in command : ClimateCommand;
            in intakeAir : Atmosphere;
            out conditionedAir : Atmosphere;
        }

        action activateCooling {
            in powerLevel : PowerLevelValue;
            out active : Boolean;
        }

        action activateHeating {
            in powerLevel : PowerLevelValue;
            out active : Boolean;
        }
    }

    part def WaterReclamationSubsystem {
        port commandInput : WaterControlPort;
        port waterPort : WaterFlowPort;

        attribute targetPurity : PercentValue = 99.9;
        attribute flowRate : FlowRateValue = 2.0;
        attribute operationalStatus : String = "standby";

        part particulateFilter {
            attribute filterEfficiency : PercentValue = 99.0;
            attribute saturationLevel : PercentValue = 0.0;
        }

        part carbonFilter {
            attribute filterEfficiency : PercentValue = 99.5;
            attribute saturationLevel : PercentValue = 0.0;
        }

        part reverseOsmosisUnit {
            attribute membraneIntegrity : PercentValue = 100.0;
            attribute flowRate : FlowRateValue = 2.0;
        }

        part uvSterilizer {
            attribute powerLevel : PowerLevelValue = 100.0;
            attribute operationalHours : Real = 0.0;
        }

        part potableWaterStorage {
            attribute storedVolume : VolumeValue = 0.0;
            attribute maxCapacity : VolumeValue = 5000.0;
        }

        action filterWater {
            in command : WaterReclamationCommand;
            in wastewater : Wastewater;
            out potableWater : PotableWater;
        }

        action monitorFilterSaturation {
            out particulateSaturation : PercentValue;
            out carbonSaturation : PercentValue;
        }

        action sterilizeWater {
            in water : PotableWater;
            out sterilized : PotableWater;
        }
    }

    // ===== Top-level Life Support System =====
    part def LifeSupportSystem {
        port externalAirPort : AirFlowPort;
        port externalWaterPort : WaterFlowPort;

        part monitoring : EnvironmentalMonitoringSubsystem;
        part controller : LifeSupportControlUnit;
        part oxygenGen : OxygenGenerationSubsystem;
        part co2Removal : CO2RemovalSubsystem;
        part climateControl : TemperatureHumidityControlSubsystem;
        part waterReclamation : WaterReclamationSubsystem;

        item habitatAtmosphere : Atmosphere;
        item habitatWater : PotableWater;

        connection monitoring.sensorOutput to controller.sensorInput;
        connection controller.o2Output to oxygenGen.commandInput;
        connection controller.co2Output to co2Removal.commandInput;
        connection controller.climateOutput to climateControl.commandInput;
        connection controller.waterOutput to waterReclamation.commandInput;

        flow of Atmosphere from externalAirPort to monitoring.airSampling;
        flow of Atmosphere from monitoring.airSampling to oxygenGen.airPort;
        flow of Atmosphere from oxygenGen.airPort to co2Removal.airPort;
        flow of Atmosphere from co2Removal.airPort to climateControl.airPort;
        flow of Atmosphere from climateControl.airPort to externalAirPort;

        flow of Wastewater from externalWaterPort to waterReclamation.waterPort;
        flow of PotableWater from waterReclamation.waterPort to externalWaterPort;
    }

    // ===== Requirements =====
    requirement oxygenLevelRange {
        subject lifeSupport : LifeSupportSystem;
        doc /* Oxygen concentration must remain between 19.5% and 23.5% */
        require lifeSupport.habitatAtmosphere.oxygenConcentration >= 19.5
            and lifeSupport.habitatAtmosphere.oxygenConcentration <= 23.5;
    }

    requirement co2LevelLimit {
        subject lifeSupport : LifeSupportSystem;
        doc /* CO2 concentration must not exceed 5000 ppm */
        require lifeSupport.habitatAtmosphere.co2Concentration <= 5000;
    }

    requirement temperatureRange {
        subject lifeSupport : LifeSupportSystem;
        doc /* Temperature must remain between 18 C and 27 C */
        require lifeSupport.habitatAtmosphere.temperature >= 291.15 'K'
            and lifeSupport.habitatAtmosphere.temperature <= 300.15 'K';
    }

    requirement humidityRange {
        subject lifeSupport : LifeSupportSystem;
        doc /* Humidity must remain between 30% and 70% */
        require lifeSupport.habitatAtmosphere.humidity >= 30
            and lifeSupport.habitatAtmosphere.humidity <= 70;
    }

    requirement pressureRange {
        subject lifeSupport : LifeSupportSystem;
        doc /* Total pressure must remain between 90 kPa and 110 kPa */
        require lifeSupport.habitatAtmosphere.totalPressure >= 90.0 'kPa'
            and lifeSupport.habitatAtmosphere.totalPressure <= 110.0 'kPa';
    }

    requirement waterPurityLevel {
        subject lifeSupport : LifeSupportSystem;
        doc /* Potable water purity must be at least 99.9% */
        require lifeSupport.habitatWater.purity >= 99.9;
    }

    requirement waterContaminantLimit {
        subject lifeSupport : LifeSupportSystem;
        doc /* Water contaminant level must not exceed 10 ppm */
        require lifeSupport.habitatWater.contaminantPPM <= 10;
    }

    requirement continuousMonitoring {
        subject lifeSupport : LifeSupportSystem;
        doc /* The controller must continuously monitor atmosphere and water */
        require lifeSupport.controller.currentReading.oxygenConcentration >= 0;
    }

    requirement automaticResponse {
        subject lifeSupport : LifeSupportSystem;
        doc /* System must activate corrective subsystems automatically upon deviation */
        require lifeSupport.oxygenGen.currentFlowRate >= 0;
    }

    requirement emergencyModeActivation {
        subject lifeSupport : LifeSupportSystem;
        doc /* Controller must enter emergency mode on critical failures */
        require (lifeSupport.controller.emergencyActive == true)
            implies (lifeSupport.habitatAtmosphere.oxygenConcentration < 19.5
                or lifeSupport.habitatAtmosphere.oxygenConcentration > 23.5
                or lifeSupport.habitatAtmosphere.co2Concentration > 5000
                or lifeSupport.habitatAtmosphere.totalPressure < 90.0 'kPa'
                or lifeSupport.habitatAtmosphere.totalPressure > 110.0 'kPa');
    }

    requirement safeShutdownSequence {
        subject lifeSupport : LifeSupportSystem;
        doc /* Controller must execute safe shutdown when requested */
        require lifeSupport.controller.shutdownRequested == false
            or lifeSupport.controller.emergencyActive == true;
    }
}

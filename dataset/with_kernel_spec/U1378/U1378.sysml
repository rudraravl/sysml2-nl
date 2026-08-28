package AquariumFiltrationSystem {
    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        private import ScalarValues::*;
        private import ISQ::*;
        private import SI::*;

        alias FlowRate for ISQ::VolumeFlowRateValue;
        attribute def MassConcentration :> ScalarValues::Real;
        alias Duration for ISQ::TimeValue;
        alias Power for ISQ::PowerValue;
        alias Area for ISQ::AreaValue;
        alias Mass for ISQ::MassValue;
        alias Length for ISQ::LengthValue;

        attribute def StartSignal;
        attribute def ShutdownSignal;
        attribute def MaintenanceSignal;
        attribute def MaintenanceDoneSignal;
        attribute def HighLoadSignal;
        attribute def NormalLoadSignal;

        item def Water;
        item def RawWater :> Water;
        item def MechanicallyFilteredWater :> Water;
        item def BiologicallyFilteredWater :> Water;
        item def ChemicallyFilteredWater :> Water;
        item def PurifiedWater :> ChemicallyFilteredWater;
        item def SolidWaste;
        item def DissolvedImpurity;

        attribute def AmmoniaLevel :> MassConcentration;
        attribute def NitriteLevel :> MassConcentration;
        attribute def NitrateLevel :> MassConcentration;
        attribute def DissolvedOxygenLevel :> MassConcentration;
        attribute def PHLevel :> ScalarValues::Real;

        attribute def WaterQualityReading {
            attribute ammonia : AmmoniaLevel;
            attribute nitrite : NitriteLevel;
            attribute nitrate : NitrateLevel;
            attribute ph : PHLevel;
            attribute dissolvedOxygen : DissolvedOxygenLevel;
        }

        attribute def FlowRateSetting :> FlowRate;
        attribute def OperatingHours :> Duration;

        port def WaterInPort {
            in item water : Water;
        }
        port def WaterOutPort {
            out item water : Water;
        }
        port def ControlPort {
            in attribute flowRateCmd : FlowRateSetting;
            out attribute operatingHours : OperatingHours;
            out attribute maintenanceRequest : ScalarValues::Boolean;
        }
        port def SensorDataPort {
            out attribute reading : WaterQualityReading;
        }

        part def WaterPump {
            port waterIn : WaterInPort;
            port waterOut : WaterOutPort;
            port control : ControlPort;
            attribute currentFlowRate : FlowRate;
            attribute totalOperatingHours : OperatingHours;
            attribute maintenanceInterval : Duration = 2000 [h];
            attribute maintenanceDue : ScalarValues::Boolean;
            attribute powerConsumption : Power;
        }

        part def MechanicalFilter {
            port waterIn : WaterInPort;
            port waterOut : WaterOutPort;
            part filterMedia {
                attribute mediaType : ScalarValues::String = "foam and sponge";
                attribute porosity : Length;
            }
            attribute trappedWasteMass : MassConcentration;
        }

        part def BiologicalFilter {
            port waterIn : WaterInPort;
            port waterOut : WaterOutPort;
            part bioMedia {
                attribute surfaceArea : Area;
                attribute bacteriaColonyDensity : MassConcentration;
            }
            attribute nitrificationRate : ScalarValues::Real;
        }

        part def ChemicalFilter {
            port waterIn : WaterInPort;
            port waterOut : WaterOutPort;
            part activatedCarbon {
                attribute mass : Mass;
                attribute adsorptionCapacity : MassConcentration;
                attribute remainingCapacity : MassConcentration;
            }
        }

        part def QualitySensor {
            port waterIn : WaterInPort;
            port waterOut : WaterOutPort;
            port sensorData : SensorDataPort;
            attribute currentReading : WaterQualityReading;
            attribute samplingInterval : Duration = 5 [min];
        }

        part def ControlModule {
            port sensorInput : SensorDataPort;
            port pumpControl : ControlPort;
            attribute targetFlowRate : FlowRate = 500 [L/min];
            attribute highLoadFlowRate : FlowRate = 800 [L/min];
            attribute totalOperatingHours : OperatingHours;
            attribute maintenanceInterval : Duration = 2000 [h];
            attribute maintenanceDue : ScalarValues::Boolean;
            attribute powerConsumption : Power;
        }

        action def DrawWater {
            in item rawWater : RawWater;
            in flowRateSetting : FlowRateSetting;
            out item pumpedWater : RawWater;
        }
        action def MechanicallyFilter {
            in item water : RawWater;
            out item filteredWater : MechanicallyFilteredWater;
            out item waste : SolidWaste;
        }
        action def BiologicallyFilter {
            in item water : MechanicallyFilteredWater;
            out item filteredWater : BiologicallyFilteredWater;
        }
        action def ChemicallyFilter {
            in item water : BiologicallyFilteredWater;
            out item filteredWater : ChemicallyFilteredWater;
            out item impurities : DissolvedImpurity;
        }
        action def SampleWater {
            in item water : ChemicallyFilteredWater;
            out item purifiedWater : PurifiedWater;
            out attribute reading : WaterQualityReading;
        }
        action def CirculateAndPurify {
            in item rawWater : RawWater;
            in flowRateSetting : FlowRateSetting;
            out item purifiedWater : PurifiedWater;
            out attribute qualityReading : WaterQualityReading;
        }

        state def FiltrationSystemStates {
            entry; then startup;
            state startup;
            transition startup_to_normal
                first startup
                accept StartSignal
                then normal;
            state normal;
            transition normal_to_highload
                first normal
                accept HighLoadSignal
                then highLoad;
            transition normal_to_maintenance
                first normal
                accept MaintenanceSignal
                then maintenance;
            transition normal_to_shutdown
                first normal
                accept ShutdownSignal
                then shutdown;
            state highLoad;
            transition highload_to_normal
                first highLoad
                accept NormalLoadSignal
                then normal;
            transition highload_to_maintenance
                first highLoad
                accept MaintenanceSignal
                then maintenance;
            transition highload_to_shutdown
                first highLoad
                accept ShutdownSignal
                then shutdown;
            state maintenance;
            transition maintenance_to_normal
                first maintenance
                accept MaintenanceDoneSignal
                then normal;
            transition maintenance_to_shutdown
                first maintenance
                accept ShutdownSignal
                then shutdown;
            state shutdown;
        }

        requirement def WaterQualityRequirement {
            doc /* The purified water shall maintain quality parameters within safe ranges for aquatic life. */
            attribute ammonia : MassConcentration;
            attribute nitrite : MassConcentration;
            attribute nitrate : MassConcentration;
            attribute ph : PHLevel;
            attribute dissolvedOxygen : MassConcentration;
            attribute maxAmmonia : MassConcentration = 0.02;
            attribute maxNitrite : MassConcentration = 0.1;
            attribute maxNitrate : MassConcentration = 50;
            attribute minPH : PHLevel = 6.5;
            attribute maxPH : PHLevel = 8.5;
            attribute minDissolvedOxygen : MassConcentration = 6;
            require constraint {
                ammonia <= maxAmmonia and
                nitrite <= maxNitrite and
                nitrate <= maxNitrate and
                ph >= minPH and ph <= maxPH and
                dissolvedOxygen >= minDissolvedOxygen
            }
        }
        requirement def FlowRateRequirement {
            doc /* The system shall maintain a minimum flow rate to ensure adequate circulation. */
            attribute actualFlowRate : FlowRate;
            attribute minFlowRate : FlowRate = 300 [L/min];
            attribute targetFlowRate : FlowRate = 500 [L/min];
            require constraint { actualFlowRate >= minFlowRate }
        }
        requirement def MaintenanceIntervalRequirement {
            doc /* The system shall operate for at least 2000 hours between maintenance cycles. */
            attribute operatingHoursBetweenMaintenance : Duration;
            attribute minInterval : Duration = 2000 [h];
            require constraint { operatingHoursBetweenMaintenance >= minInterval }
        }
        requirement def EnergyEfficiencyRequirement {
            doc /* The system shall keep power consumption below a specified maximum during normal operation. */
            attribute powerConsumption : Power;
            attribute maxPowerConsumption : Power = 50 [W];
            require constraint { powerConsumption <= maxPowerConsumption }
        }
        requirement def ReliabilityRequirement {
            doc /* The system shall be designed for continuous, reliable operation over long periods. */
            attribute meanTimeBetweenFailures : Duration;
            attribute minMTBF : Duration = 8760 [h];
            require constraint { meanTimeBetweenFailures >= minMTBF }
        }
    }

    package Usages {
        part AquariumFiltrationSystem {
            port aquariumIntake : WaterInPort;
            port aquariumReturn : WaterOutPort;

            requirement waterQualityReq : WaterQualityRequirement;
            requirement flowRateReq : FlowRateRequirement;
            requirement maintenanceIntervalReq : MaintenanceIntervalRequirement;
            requirement energyEfficiencyReq : EnergyEfficiencyRequirement;
            requirement reliabilityReq : ReliabilityRequirement;

            part waterPump : WaterPump;
            part mechanicalFilter : MechanicalFilter;
            part biologicalFilter : BiologicalFilter;
            part chemicalFilter : ChemicalFilter;
            part qualitySensor : QualitySensor;
            part controlModule : ControlModule;

            connect aquariumIntake to waterPump.waterIn;
            connect waterPump.waterOut to mechanicalFilter.waterIn;
            connect mechanicalFilter.waterOut to biologicalFilter.waterIn;
            connect biologicalFilter.waterOut to chemicalFilter.waterIn;
            connect chemicalFilter.waterOut to qualitySensor.waterIn;
            connect qualitySensor.waterOut to aquariumReturn;
            connect qualitySensor.sensorData to controlModule.sensorInput;
            connect controlModule.pumpControl to waterPump.control;

            perform action circulateAndPurify : CirculateAndPurify {
                in item rawWater : RawWater;
                in flowRateSetting : FlowRateSetting;
                out item purifiedWater : PurifiedWater;
                out attribute qualityReading : WaterQualityReading;

                action drawWater : DrawWater {
                    in item rawWater = circulateAndPurify::rawWater;
                    in flowRateSetting = circulateAndPurify::flowRateSetting;
                    out item pumpedWater : RawWater;
                }
                flow drawWater.pumpedWater to mechanicallyFilterAction.water;
                action mechanicallyFilterAction : MechanicallyFilter {
                    in item water : RawWater;
                    out item filteredWater : MechanicallyFilteredWater;
                    out item waste : SolidWaste;
                }
                flow mechanicallyFilterAction.filteredWater to biologicallyFilterAction.water;
                action biologicallyFilterAction : BiologicallyFilter {
                    in item water : MechanicallyFilteredWater;
                    out item filteredWater : BiologicallyFilteredWater;
                }
                flow biologicallyFilterAction.filteredWater to chemicallyFilterAction.water;
                action chemicallyFilterAction : ChemicallyFilter {
                    in item water : BiologicallyFilteredWater;
                    out item filteredWater : ChemicallyFilteredWater;
                    out item impurities : DissolvedImpurity;
                }
                flow chemicallyFilterAction.filteredWater to sampleWaterAction.water;
                action sampleWaterAction : SampleWater {
                    in item water : ChemicallyFilteredWater;
                    out item purifiedWater : PurifiedWater;
                    out attribute reading : WaterQualityReading;
                }
                bind circulateAndPurify::purifiedWater = sampleWaterAction.purifiedWater;
                bind circulateAndPurify::qualityReading = sampleWaterAction.reading;
            }

            state systemStates : FiltrationSystemStates;

            satisfy waterQualityReq by qualitySensor;
            satisfy flowRateReq by waterPump;
            satisfy maintenanceIntervalReq by controlModule;
            satisfy energyEfficiencyReq by waterPump;
            satisfy reliabilityReq by controlModule;
        }
    }
}

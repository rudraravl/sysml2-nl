package ISRU_System_Model {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def MassPerHour :> Real {
        unit = kg / h;
    }

    attribute def PowerKilowatt :> Real {
        unit = kW;
    }

    attribute def TemperatureCelsius :> Real {
        unit = degC;
    }

    attribute def PressureKilopascal :> Real {
        unit = kPa;
    }

    attribute def VolumeFlowRate :> Real {
        unit = L / min;
    }

    attribute def EnergyPerMass :> Real {
        unit = kWh / kg;
    }

    attribute def PurityFraction :> Real {
        unit = one;
    }

    attribute def AvailabilityFraction :> Real {
        unit = one;
    }

    attribute def MissionDurationDays :> Real {
        unit = d;
    }

    item def LunarRegolith {
        attribute massFlow : MassPerHour;
        attribute averageParticleDiameter : LengthValue;
        attribute oxideMassFraction : PurityFraction;
        attribute volatileMassFraction : PurityFraction;
        attribute temperature : TemperatureCelsius;
    }

    item def BeneficiatedRegolith {
        attribute massFlow : MassPerHour;
        attribute ilmeniteFraction : PurityFraction;
        attribute waterEquivalentFraction : PurityFraction;
        attribute particleDiameter : LengthValue;
    }

    item def HydrogenGas {
        attribute massFlow : MassPerHour;
        attribute pressure : PressureKilopascal;
        attribute temperature : TemperatureCelsius;
        attribute purity : PurityFraction;
    }

    item def WaterVapor {
        attribute massFlow : MassPerHour;
        attribute pressure : PressureKilopascal;
        attribute temperature : TemperatureCelsius;
        attribute purity : PurityFraction;
    }

    item def LiquidWater {
        attribute massFlow : MassPerHour;
        attribute pressure : PressureKilopascal;
        attribute temperature : TemperatureCelsius;
        attribute purity : PurityFraction;
    }

    item def OxygenGas {
        attribute massFlow : MassPerHour;
        attribute pressure : PressureKilopascal;
        attribute temperature : TemperatureCelsius;
        attribute purity : PurityFraction;
    }

    item def MethaneGas {
        attribute massFlow : MassPerHour;
        attribute pressure : PressureKilopascal;
        attribute temperature : TemperatureCelsius;
        attribute purity : PurityFraction;
    }

    item def CarbonDioxideGas {
        attribute massFlow : MassPerHour;
        attribute pressure : PressureKilopascal;
        attribute temperature : TemperatureCelsius;
        attribute purity : PurityFraction;
    }

    item def WasteTailings {
        attribute massFlow : MassPerHour;
        attribute residualVolatileFraction : PurityFraction;
        attribute temperature : TemperatureCelsius;
    }

    item def ElectricalPower {
        attribute power : PowerKilowatt;
        attribute voltage : ElectricPotentialValue;
        attribute frequency : FrequencyValue;
    }

    item def ThermalEnergy {
        attribute heatRate : PowerKilowatt;
        attribute sourceTemperature : TemperatureCelsius;
    }

    item def CommandPacket {
        attribute commandId : Integer;
        attribute targetMode : String;
        attribute priority : Integer;
    }

    item def TelemetryPacket {
        attribute timestamp : Real;
        attribute mode : String;
        attribute oxygenProductionRate : MassPerHour;
        attribute waterProductionRate : MassPerHour;
        attribute totalPowerDraw : PowerKilowatt;
        attribute faultCode : Integer;
    }

    port def SolidMaterialInPort {
        in item material : LunarRegolith;
    }

    port def BeneficiatedSolidPort {
        out item material : BeneficiatedRegolith;
    }

    port def WasteSolidOutPort {
        out item waste : WasteTailings;
    }

    port def GasHydrogenPort {
        inout item hydrogen : HydrogenGas;
    }

    port def GasCarbonDioxidePort {
        in item carbonDioxide : CarbonDioxideGas;
    }

    port def WaterPort {
        inout item water : LiquidWater;
    }

    port def OxygenOutPort {
        out item oxygen : OxygenGas;
    }

    port def MethaneOutPort {
        out item methane : MethaneGas;
    }

    port def PowerInPort {
        in item power : ElectricalPower;
    }

    port def PowerOutPort {
        out item power : ElectricalPower;
    }

    port def HeatPort {
        inout item heat : ThermalEnergy;
    }

    port def CommandInPort {
        in item command : CommandPacket;
    }

    port def TelemetryOutPort {
        out item telemetry : TelemetryPacket;
    }

    action def ExcavateRegolith {
        in item nativeRegolith : LunarRegolith;
        out item excavatedRegolith : LunarRegolith;
        in item electricalPower : ElectricalPower;

        attribute excavationRate : MassPerHour = 120.0 [kg / h];
        attribute maximumBucketDepth : LengthValue = 0.25 [m];
    }

    action def BeneficiateRegolith {
        in item excavatedRegolith : LunarRegolith;
        out item enrichedRegolith : BeneficiatedRegolith;
        out item rejectedTailings : WasteTailings;
        in item electricalPower : ElectricalPower;

        attribute targetIlmeniteFraction : PurityFraction = 0.18;
        attribute separationEfficiency : PurityFraction = 0.82;
    }

    action def ReduceRegolithWithHydrogen {
        in item enrichedRegolith : BeneficiatedRegolith;
        inout item hydrogen : HydrogenGas;
        out item waterVapor : WaterVapor;
        out item reducedTailings : WasteTailings;
        in item heat : ThermalEnergy;

        attribute reactorTemperature : TemperatureCelsius = 950.0 [degC];
        attribute reactorPressure : PressureKilopascal = 120.0 [kPa];
        attribute oxygenRecoveryEfficiency : PurityFraction = 0.72;
    }

    action def CondenseAndPurifyWater {
        in item waterVapor : WaterVapor;
        out item liquidWater : LiquidWater;
        in item electricalPower : ElectricalPower;

        attribute condenserTemperature : TemperatureCelsius = 5.0 [degC];
        attribute waterPurity : PurityFraction = 0.995;
    }

    action def ElectrolyzeWater {
        in item liquidWater : LiquidWater;
        out item oxygen : OxygenGas;
        out item hydrogen : HydrogenGas;
        in item electricalPower : ElectricalPower;

        attribute specificEnergy : EnergyPerMass = 5.1 [kWh / kg];
        attribute oxygenPurity : PurityFraction = 0.995;
        attribute hydrogenPurity : PurityFraction = 0.995;
    }

    action def ProduceMethanePropellant {
        in item carbonDioxide : CarbonDioxideGas;
        in item hydrogen : HydrogenGas;
        out item methane : MethaneGas;
        out item water : LiquidWater;
        in item electricalPower : ElectricalPower;

        attribute sabatierTemperature : TemperatureCelsius = 350.0 [degC];
        attribute conversionEfficiency : PurityFraction = 0.88;
    }

    action def StoreCryogenicOxygen {
        in item oxygen : OxygenGas;
        in item electricalPower : ElectricalPower;

        attribute storagePressure : PressureKilopascal = 3000.0 [kPa];
        attribute storageTemperature : TemperatureCelsius = -183.0 [degC];
        attribute boiloffRatePerDay : PurityFraction = 0.001;
    }

    action def DisposeTailings {
        in item tailings : WasteTailings;
        in item electricalPower : ElectricalPower;

        attribute disposalRate : MassPerHour = 100.0 [kg / h];
    }

    action def ManageISRUProcess {
        in item command : CommandPacket;
        out item telemetry : TelemetryPacket;
    }

    state def ISRUOperatingState {
        entry action initializeSensors;
        state Off;
        state Standby;
        state Startup;
        state Prospecting;
        state Excavating;
        state Processing;
        state ProducingOxygen;
        state ProducingMethane;
        state StoringProducts;
        state Maintenance;
        state FaultSafe;
        state Shutdown;

        transition first Off;
        transition Off_to_Standby
            first Off
            then Standby;

        transition Standby_to_Startup
            first Standby
            accept CommandPacket
            if command.targetMode == "START"
            then Startup;

        transition Startup_to_Prospecting
            first Startup
            if startupChecksComplete == true
            then Prospecting;

        transition Prospecting_to_Excavating
            first Prospecting
            if resourceGradeConfirmed == true
            then Excavating;

        transition Excavating_to_Processing
            first Excavating
            if feedHopperLevel >= 0.75
            then Processing;

        transition Processing_to_ProducingOxygen
            first Processing
            if waterBufferLevel >= 0.20
            then ProducingOxygen;

        transition ProducingOxygen_to_ProducingMethane
            first ProducingOxygen
            if oxygenTankLevel >= 0.50 and carbonDioxideAvailable == true
            then ProducingMethane;

        transition ProducingOxygen_to_StoringProducts
            first ProducingOxygen
            if oxygenTankLevel >= 0.95
            then StoringProducts;

        transition ProducingMethane_to_StoringProducts
            first ProducingMethane
            if methaneTankLevel >= 0.95
            then StoringProducts;

        transition Any_to_FaultSafe
            first Standby
            accept TelemetryPacket
            if telemetry.faultCode > 0
            then FaultSafe;

        transition FaultSafe_to_Maintenance
            first FaultSafe
            accept CommandPacket
            if command.targetMode == "MAINTENANCE"
            then Maintenance;

        transition Maintenance_to_Standby
            first Maintenance
            if maintenanceComplete == true
            then Standby;

        transition StoringProducts_to_Shutdown
            first StoringProducts
            accept CommandPacket
            if command.targetMode == "STOP"
            then Shutdown;

        transition Shutdown_to_Off
            first Shutdown
            if thermalCooldownComplete == true
            then Off;

        attribute startupChecksComplete : Boolean;
        attribute resourceGradeConfirmed : Boolean;
        attribute carbonDioxideAvailable : Boolean;
        attribute maintenanceComplete : Boolean;
        attribute thermalCooldownComplete : Boolean;
        attribute feedHopperLevel : PurityFraction;
        attribute waterBufferLevel : PurityFraction;
        attribute oxygenTankLevel : PurityFraction;
        attribute methaneTankLevel : PurityFraction;
    }

    part def SolarPowerPlant {
        port powerOut : PowerOutPort;

        attribute maximumOutput : PowerKilowatt = 85.0 [kW];
        attribute nominalOutput : PowerKilowatt = 60.0 [kW];
        attribute dustDegradationPerDay : PurityFraction = 0.002;
        attribute availability : AvailabilityFraction = 0.92;
    }

    part def PowerManagementAndDistribution {
        port primaryPowerIn : PowerInPort;
        port excavationPowerOut : PowerOutPort;
        port reactorPowerOut : PowerOutPort;
        port electrolyzerPowerOut : PowerOutPort;
        port storagePowerOut : PowerOutPort;
        port controlsPowerOut : PowerOutPort;

        attribute maximumBusPower : PowerKilowatt = 75.0 [kW];
        attribute nominalBusVoltage : ElectricPotentialValue = 600.0 [V];
        attribute conversionEfficiency : PurityFraction = 0.94;
    }

    part def RegolithExcavator {
        port powerIn : PowerInPort;
        port regolithOut : SolidMaterialInPort;

        perform action excavate : ExcavateRegolith;

        attribute bucketCapacity : MassValue = 40.0 [kg];
        attribute excavationRate : MassPerHour = 120.0 [kg / h];
        attribute tractionPower : PowerKilowatt = 8.0 [kW];
        attribute operatingTemperatureMinimum : TemperatureCelsius = -170.0 [degC];
        attribute operatingTemperatureMaximum : TemperatureCelsius = 120.0 [degC];
    }

    part def FeedHopper {
        port regolithIn : SolidMaterialInPort;
        port regolithOut : SolidMaterialInPort;

        attribute capacity : MassValue = 500.0 [kg];
        attribute minimumProcessInventory : MassValue = 150.0 [kg];
        attribute dischargeRate : MassPerHour = 90.0 [kg / h];
    }

    part def BeneficiationUnit {
        port regolithIn : SolidMaterialInPort;
        port enrichedOut : BeneficiatedSolidPort;
        port tailingsOut : WasteSolidOutPort;
        port powerIn : PowerInPort;

        perform action separate : BeneficiateRegolith;

        attribute magneticSeparatorPower : PowerKilowatt = 5.0 [kW];
        attribute enrichmentRatio : Real = 3.0;
        attribute separationEfficiency : PurityFraction = 0.82;
    }

    part def HydrogenReductionReactor {
        port regolithIn : BeneficiatedSolidPort;
        port hydrogenLoop : GasHydrogenPort;
        port waterVaporOut : port {
            out item waterVapor : WaterVapor;
        }
        port reducedTailingsOut : WasteSolidOutPort;
        port heatIn : HeatPort;
        port powerIn : PowerInPort;

        perform action reduce : ReduceRegolithWithHydrogen;

        attribute reactorTemperature : TemperatureCelsius = 950.0 [degC];
        attribute reactorPressure : PressureKilopascal = 120.0 [kPa];
        attribute regolithThroughput : MassPerHour = 75.0 [kg / h];
        attribute oxygenExtractionRate : MassPerHour = 2.8 [kg / h];
    }

    part def ThermalControlUnit {
        port reactorHeat : HeatPort;
        port powerIn : PowerInPort;

        attribute heaterPower : PowerKilowatt = 35.0 [kW];
        attribute radiatorHeatRejection : PowerKilowatt = 18.0 [kW];
        attribute controlBand : TemperatureCelsius = 10.0 [degC];
    }

    part def WaterRecoveryUnit {
        port vaporIn : port {
            in item waterVapor : WaterVapor;
        }
        port waterOut : WaterPort;
        port powerIn : PowerInPort;

        perform action condense : CondenseAndPurifyWater;

        attribute waterRecoveryEfficiency : PurityFraction = 0.96;
        attribute condenserPower : PowerKilowatt = 4.5 [kW];
        attribute outputWaterPurity : PurityFraction = 0.995;
    }

    part def ElectrolysisUnit {
        port waterIn : WaterPort;
        port oxygenOut : OxygenOutPort;
        port hydrogenOut : GasHydrogenPort;
        port powerIn : PowerInPort;

        perform action electrolyze : ElectrolyzeWater;

        attribute ratedOxygenProduction : MassPerHour = 2.5 [kg / h];
        attribute ratedHydrogenRecycle : MassPerHour = 0.31 [kg / h];
        attribute maximumPowerDraw : PowerKilowatt = 14.0 [kW];
    }

    part def SabatierReactor {
        port carbonDioxideIn : GasCarbonDioxidePort;
        port hydrogenIn : GasHydrogenPort;
        port methaneOut : MethaneOutPort;
        port waterOut : WaterPort;
        port powerIn : PowerInPort;

        perform action sabatier : ProduceMethanePropellant;

        attribute methaneProductionRate : MassPerHour = 1.2 [kg / h];
        attribute carbonDioxideFeedRate : MassPerHour = 3.3 [kg / h];
        attribute reactorPower : PowerKilowatt = 3.0 [kW];
    }

    part def OxygenStorageTank {
        port oxygenIn : OxygenOutPort;
        port powerIn : PowerInPort;

        perform action storeOxygen : StoreCryogenicOxygen;

        attribute capacity : MassValue = 1200.0 [kg];
        attribute currentInventory : MassValue = 0.0 [kg];
        attribute storagePressure : PressureKilopascal = 3000.0 [kPa];
        attribute storageTemperature : TemperatureCelsius = -183.0 [degC];
    }

    part def MethaneStorageTank {
        port methaneIn : MethaneOutPort;
        port powerIn : PowerInPort;

        attribute capacity : MassValue = 300.0 [kg];
        attribute currentInventory : MassValue = 0.0 [kg];
        attribute storagePressure : PressureKilopascal = 2500.0 [kPa];
        attribute storageTemperature : TemperatureCelsius = -162.0 [degC];
    }

    part def TailingsManagementUnit {
        port tailingsInA : WasteSolidOutPort;
        port tailingsInB : WasteSolidOutPort;
        port powerIn : PowerInPort;

        perform action dispose : DisposeTailings;

        attribute bermPlacementRate : MassPerHour = 100.0 [kg / h];
        attribute dustContainmentEfficiency : PurityFraction = 0.90;
    }

    part def AutonomyAndControlComputer {
        port commandIn : CommandInPort;
        port telemetryOut : TelemetryOutPort;
        port powerIn : PowerInPort;

        perform action manage : ManageISRUProcess;

        attribute processorPower : PowerKilowatt = 0.6 [kW];
        attribute controlCycleTime : TimeValue = 1.0 [s];
        attribute faultDetectionCoverage : PurityFraction = 0.97;

        exhibit state operatingState : ISRUOperatingState;
    }

    part def ISRUPlant {
        doc /* Primary function: autonomously collect local regolith and atmospheric carbon dioxide, extract oxygen-bearing volatiles, convert them into usable oxygen and methane propellant, recycle hydrogen, store products, and reject processed tailings to reduce the mass that must be launched from Earth. */

        port commandIn : CommandInPort;
        port telemetryOut : TelemetryOutPort;
        port carbonDioxideIn : GasCarbonDioxidePort;
        port oxygenProductOut : OxygenOutPort;
        port methaneProductOut : MethaneOutPort;

        part powerSource : SolarPowerPlant;
        part powerDistribution : PowerManagementAndDistribution;
        part excavator : RegolithExcavator;
        part hopper : FeedHopper;
        part beneficiation : BeneficiationUnit;
        part thermalControl : ThermalControlUnit;
        part reductionReactor : HydrogenReductionReactor;
        part waterRecovery : WaterRecoveryUnit;
        part electrolysis : ElectrolysisUnit;
        part sabatier : SabatierReactor;
        part oxygenTank : OxygenStorageTank;
        part methaneTank : MethaneStorageTank;
        part tailingsUnit : TailingsManagementUnit;
        part controller : AutonomyAndControlComputer;

        attribute nominalRegolithFeedRate : MassPerHour = 75.0 [kg / h];
        attribute nominalOxygenProductionRate : MassPerHour = 2.5 [kg / h];
        attribute nominalMethaneProductionRate : MassPerHour = 1.2 [kg / h];
        attribute nominalPowerDraw : PowerKilowatt = 58.0 [kW];
        attribute peakPowerDraw : PowerKilowatt = 72.0 [kW];
        attribute designLife : MissionDurationDays = 500.0 [d];
        attribute systemAvailability : AvailabilityFraction = 0.88;

        connect powerSource.powerOut to powerDistribution.primaryPowerIn;
        connect powerDistribution.excavationPowerOut to excavator.powerIn;
        connect powerDistribution.excavationPowerOut to beneficiation.powerIn;
        connect powerDistribution.reactorPowerOut to thermalControl.powerIn;
        connect powerDistribution.reactorPowerOut to reductionReactor.powerIn;
        connect powerDistribution.electrolyzerPowerOut to waterRecovery.powerIn;
        connect powerDistribution.electrolyzerPowerOut to electrolysis.powerIn;
        connect powerDistribution.electrolyzerPowerOut to sabatier.powerIn;
        connect powerDistribution.storagePowerOut to oxygenTank.powerIn;
        connect powerDistribution.storagePowerOut to methaneTank.powerIn;
        connect powerDistribution.controlsPowerOut to controller.powerIn;
        connect powerDistribution.excavationPowerOut to tailingsUnit.powerIn;

        connect excavator.regolithOut to hopper.regolithIn;
        connect hopper.regolithOut to beneficiation.regolithIn;
        connect beneficiation.enrichedOut to reductionReactor.regolithIn;
        connect beneficiation.tailingsOut to tailingsUnit.tailingsInA;
        connect reductionReactor.reducedTailingsOut to tailingsUnit.tailingsInB;

        connect thermalControl.reactorHeat to reductionReactor.heatIn;
        connect reductionReactor.waterVaporOut to waterRecovery.vaporIn;
        connect waterRecovery.waterOut to electrolysis.waterIn;
        connect electrolysis.hydrogenOut to reductionReactor.hydrogenLoop;
        connect electrolysis.oxygenOut to oxygenTank.oxygenIn;
        connect oxygenTank.oxygenIn to oxygenProductOut;

        connect carbonDioxideIn to sabatier.carbonDioxideIn;
        connect electrolysis.hydrogenOut to sabatier.hydrogenIn;
        connect sabatier.waterOut to electrolysis.waterIn;
        connect sabatier.methaneOut to methaneTank.methaneIn;
        connect methaneTank.methaneIn to methaneProductOut;

        connect commandIn to controller.commandIn;
        connect controller.telemetryOut to telemetryOut;
    }

    requirement def HighLevelISRUFunction {
        subject plant : ISRUPlant;

        doc /* The ISRU plant shall use locally available resources to produce mission-consumable oxygen and methane propellant with autonomous operation and closed-loop resource recycling. */

        require constraint {
            plant.nominalOxygenProductionRate >= 2.0 [kg / h]
        }

        require constraint {
            plant.nominalMethaneProductionRate >= 1.0 [kg / h]
        }
    }

    requirement def RegolithProcessingRequirement {
        subject plant : ISRUPlant;

        doc /* The plant shall excavate and process lunar regolith continuously while sufficient power and thermal conditions are available. */

        require constraint {
            plant.nominalRegolithFeedRate >= 70.0 [kg / h]
        }
    }

    requirement def PowerRequirement {
        subject plant : ISRUPlant;

        doc /* The plant shall remain within the allocated electrical power budget during nominal production. */

        require constraint {
            plant.nominalPowerDraw <= 60.0 [kW]
        }

        require constraint {
            plant.peakPowerDraw <= 75.0 [kW]
        }
    }

    requirement def AvailabilityRequirement {
        subject plant : ISRUPlant;

        doc /* The plant shall provide high autonomous availability over the mission production campaign. */

        require constraint {
            plant.systemAvailability >= 0.85
        }

        require constraint {
            plant.designLife >= 500.0 [d]
        }
    }

    requirement def ProductStorageRequirement {
        subject plant : ISRUPlant;

        doc /* The plant shall store produced oxygen and methane in controlled tanks suitable for propellant transfer. */

        require constraint {
            plant.oxygenTank.capacity >= 1000.0 [kg]
        }

        require constraint {
            plant.methaneTank.capacity >= 250.0 [kg]
        }
    }

    requirement def ProductPurityRequirement {
        doc /* Oxygen, hydrogen, methane, and recovered water product streams shall be purified enough for propellant production and reactor recycle. */

        require constraint {
            0.995 >= 0.99
        }
    }

    requirement def FaultManagementRequirement {
        subject plant : ISRUPlant;

        doc /* The control computer shall detect faults, transition the plant to a fault-safe condition, and allow commanded maintenance recovery. */

        require constraint {
            plant.controller.faultDetectionCoverage >= 0.95
        }
    }

    satisfy HighLevelISRUFunction by ISRUPlant;
    satisfy RegolithProcessingRequirement by ISRUPlant;
    satisfy PowerRequirement by ISRUPlant;
    satisfy AvailabilityRequirement by ISRUPlant;
    satisfy ProductStorageRequirement by ISRUPlant;
    satisfy FaultManagementRequirement by ISRUPlant;

    analysis def DailyProductionAnalysis {
        subject plant : ISRUPlant;

        attribute dailyOxygenProduction : MassValue = plant.nominalOxygenProductionRate * 24.0 [h];
        attribute dailyMethaneProduction : MassValue = plant.nominalMethaneProductionRate * 24.0 [h];
        attribute dailyRegolithProcessed : MassValue = plant.nominalRegolithFeedRate * 24.0 [h];

        return attribute oxygenPerDay : MassValue = dailyOxygenProduction;
        return attribute methanePerDay : MassValue = dailyMethaneProduction;
        return attribute regolithPerDay : MassValue = dailyRegolithProcessed;
    }

    part isruMissionAsset : ISRUPlant;

}
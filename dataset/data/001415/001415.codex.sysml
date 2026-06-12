package EmergingTechnologySystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Power :> ISQ::power {
        unit = SI::watt;
    }

    attribute def Energy :> ISQ::energy {
        unit = SI::joule;
    }

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def Current :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def TimeDuration :> ISQ::time {
        unit = SI::second;
    }

    attribute def Efficiency {
        :>> range = "0.0..1.0";
    }

    item def ElectricalEnergy {
        attribute power : Power;
        attribute voltage : Voltage;
        attribute current : Current;
        attribute frequencyHz : Real;
        attribute carbonIntensity_gCO2PerkWh : Real;
    }

    item def Hydrogen {
        attribute mass_kg : Real;
        attribute pressure_bar : Real;
        attribute purity_percent : Real;
        attribute temperature : Temperature;
    }

    item def WeatherForecast {
        attribute solarIrradiance_WPerM2 : Real;
        attribute windSpeed_mPerS : Real;
        attribute ambientTemperature : Temperature;
        attribute forecastHorizon : TimeDuration;
    }

    item def GridSignal {
        attribute electricityPrice_USDPerkWh : Real;
        attribute demandResponseRequest : Boolean;
        attribute gridFrequencyHz : Real;
        attribute importLimit_kW : Real;
        attribute exportLimit_kW : Real;
    }

    item def ControlCommand {
        attribute requestedPower : Power;
        attribute operatingMode : MicrogridOperatingMode;
        attribute priority : Integer;
        attribute validFor : TimeDuration;
    }

    item def HealthTelemetry {
        attribute stateOfCharge_percent : Real;
        attribute stateOfHealth_percent : Real;
        attribute temperature : Temperature;
        attribute faultActive : Boolean;
        attribute remainingUsefulLife_hours : Real;
    }

    enum def MicrogridOperatingMode {
        enum normal;
        enum islanded;
        enum gridSupport;
        enum hydrogenProduction;
        enum emergencyShutdown;
    }

    port def ElectricalPowerPort {
        inout energy : ElectricalEnergy;
    }

    port def HydrogenPort {
        inout hydrogen : Hydrogen;
    }

    port def ForecastPort {
        in forecast : WeatherForecast;
    }

    port def GridSignalPort {
        in signal : GridSignal;
    }

    port def CommandPort {
        in command : ControlCommand;
    }

    port def TelemetryPort {
        out telemetry : HealthTelemetry;
    }

    part def PerovskiteSolarArray {
        attribute ratedPower : Power = 250000 [SI::watt];
        attribute moduleEfficiency : Efficiency = 0.285;
        attribute activeArea_m2 : Real = 930.0;
        attribute maxOperatingTemperature : Temperature = 358 [SI::kelvin];

        port dcOutput : ElectricalPowerPort;
        port telemetryOut : TelemetryPort;

        action generateSolarPower {
            in irradiance_WPerM2 : Real;
            out generated : ElectricalEnergy;

            first start;
            then computeAvailablePower;
            then regulateDcOutput;
            then done;

            action computeAvailablePower {
                out availablePower : Power;
            }

            action regulateDcOutput {
                in availablePower : Power;
                out dcEnergy : ElectricalEnergy;
            }
        }

        state machine solarArrayState {
            state offline;
            state trackingMaximumPower;
            state curtailed;
            state faulted;

            entry; then offline;

            transition offline_to_tracking
                first offline
                accept ControlCommand
                if command.operatingMode != MicrogridOperatingMode::emergencyShutdown
                then trackingMaximumPower;

            transition tracking_to_curtailed
                first trackingMaximumPower
                accept ControlCommand
                if command.requestedPower < ratedPower
                then curtailed;

            transition curtailed_to_tracking
                first curtailed
                accept ControlCommand
                if command.requestedPower >= ratedPower
                then trackingMaximumPower;

            transition any_to_faulted
                first trackingMaximumPower
                accept HealthTelemetry
                if telemetry.faultActive
                then faulted;
        }
    }

    part def SolidStateBatteryBank {
        attribute usableCapacity : Energy = 1800000000 [SI::joule];
        attribute maxChargePower : Power = 400000 [SI::watt];
        attribute maxDischargePower : Power = 450000 [SI::watt];
        attribute roundTripEfficiency : Efficiency = 0.94;
        attribute minimumStateOfCharge_percent : Real = 12.0;
        attribute maximumStateOfCharge_percent : Real = 96.0;

        port dcBus : ElectricalPowerPort;
        port commandIn : CommandPort;
        port telemetryOut : TelemetryPort;

        action charge {
            in incomingEnergy : ElectricalEnergy;
            out storedEnergy : Energy;
        }

        action discharge {
            in requestedPower : Power;
            out suppliedEnergy : ElectricalEnergy;
        }

        state machine batteryState {
            state standby;
            state charging;
            state discharging;
            state thermalLimited;
            state protectedShutdown;

            entry; then standby;

            transition standby_to_charging
                first standby
                accept ControlCommand
                if command.requestedPower < 0 [SI::watt]
                then charging;

            transition standby_to_discharging
                first standby
                accept ControlCommand
                if command.requestedPower > 0 [SI::watt]
                then discharging;

            transition active_to_thermal
                first charging
                accept HealthTelemetry
                if telemetry.temperature > 333 [SI::kelvin]
                then thermalLimited;

            transition thermal_to_standby
                first thermalLimited
                accept HealthTelemetry
                if telemetry.temperature < 318 [SI::kelvin]
                then standby;

            transition emergency_shutdown
                first standby
                accept ControlCommand
                if command.operatingMode == MicrogridOperatingMode::emergencyShutdown
                then protectedShutdown;
        }
    }

    part def ProtonExchangeMembraneElectrolyzer {
        attribute ratedInputPower : Power = 300000 [SI::watt];
        attribute hydrogenProductionRate_kgPerHour : Real = 6.1;
        attribute conversionEfficiency : Efficiency = 0.71;
        attribute minimumLoadFraction : Real = 0.15;

        port electricalInput : ElectricalPowerPort;
        port hydrogenOutput : HydrogenPort;
        port commandIn : CommandPort;
        port telemetryOut : TelemetryPort;

        action produceHydrogen {
            in electricalEnergy : ElectricalEnergy;
            out producedHydrogen : Hydrogen;
        }

        state machine electrolyzerState {
            state idle;
            state warming;
            state producing;
            state purging;
            state faulted;

            entry; then idle;

            transition idle_to_warming
                first idle
                accept ControlCommand
                if command.operatingMode == MicrogridOperatingMode::hydrogenProduction
                then warming;

            transition warming_to_producing
                first warming
                after 180 [SI::second]
                then producing;

            transition producing_to_purging
                first producing
                accept ControlCommand
                if command.operatingMode != MicrogridOperatingMode::hydrogenProduction
                then purging;

            transition purging_to_idle
                first purging
                after 60 [SI::second]
                then idle;
        }
    }

    part def MetalHydrideHydrogenStorage {
        attribute storageCapacity_kg : Real = 120.0;
        attribute maximumPressure_bar : Real = 35.0;
        attribute minimumDeliveryPressure_bar : Real = 5.0;
        attribute absorptionEfficiency : Efficiency = 0.93;

        port hydrogenIn : HydrogenPort;
        port hydrogenOut : HydrogenPort;
        port telemetryOut : TelemetryPort;

        action absorbHydrogen {
            in incomingHydrogen : Hydrogen;
            out storedHydrogen : Hydrogen;
        }

        action releaseHydrogen {
            in requestedMass_kg : Real;
            out deliveredHydrogen : Hydrogen;
        }
    }

    part def HydrogenFuelCellGenerator {
        attribute ratedOutputPower : Power = 220000 [SI::watt];
        attribute electricalEfficiency : Efficiency = 0.58;
        attribute rampRate_WPerS : Real = 5000.0;

        port hydrogenInput : HydrogenPort;
        port dcOutput : ElectricalPowerPort;
        port commandIn : CommandPort;
        port telemetryOut : TelemetryPort;

        action generateBackupPower {
            in hydrogenFuel : Hydrogen;
            out generatedEnergy : ElectricalEnergy;
        }

        state machine fuelCellState {
            state standby;
            state starting;
            state generating;
            state cooldown;
            state faulted;

            entry; then standby;

            transition standby_to_starting
                first standby
                accept ControlCommand
                if command.requestedPower > 0 [SI::watt]
                then starting;

            transition starting_to_generating
                first starting
                after 120 [SI::second]
                then generating;

            transition generating_to_cooldown
                first generating
                accept ControlCommand
                if command.requestedPower == 0 [SI::watt]
                then cooldown;

            transition cooldown_to_standby
                first cooldown
                after 240 [SI::second]
                then standby;
        }
    }

    part def SiliconCarbidePowerConverter {
        attribute dcVoltageNominal : Voltage = 800 [SI::volt];
        attribute acVoltageNominal : Voltage = 480 [SI::volt];
        attribute conversionEfficiency : Efficiency = 0.975;
        attribute ratedBidirectionalPower : Power = 600000 [SI::watt];

        port dcSide : ElectricalPowerPort;
        port acSide : ElectricalPowerPort;
        port commandIn : CommandPort;
        port telemetryOut : TelemetryPort;

        action convertDcToAc {
            in dcEnergy : ElectricalEnergy;
            out acEnergy : ElectricalEnergy;
        }

        action convertAcToDc {
            in acEnergy : ElectricalEnergy;
            out dcEnergy : ElectricalEnergy;
        }
    }

    part def AIEnergyOrchestrator {
        attribute predictionInterval : TimeDuration = 300 [SI::second];
        attribute optimizationHorizon : TimeDuration = 86400 [SI::second];
        attribute maximumDecisionLatency : TimeDuration = 2 [SI::second];
        attribute minimumCriticalLoadReserve : Energy = 720000000 [SI::joule];

        port forecastIn : ForecastPort;
        port gridSignalIn : GridSignalPort;
        port batteryCommandOut : CommandPort;
        port converterCommandOut : CommandPort;
        port electrolyzerCommandOut : CommandPort;
        port fuelCellCommandOut : CommandPort;
        port telemetryIn : TelemetryPort;

        action forecastNetLoad {
            in forecast : WeatherForecast;
            in gridSignal : GridSignal;
            out expectedRenewablePower : Power;
            out expectedLoadPower : Power;
        }

        action optimizeDispatch {
            in expectedRenewablePower : Power;
            in expectedLoadPower : Power;
            in batteryTelemetry : HealthTelemetry;
            out batteryCommand : ControlCommand;
            out electrolyzerCommand : ControlCommand;
            out fuelCellCommand : ControlCommand;
            out converterCommand : ControlCommand;
        }

        action isolateFromGrid {
            out islandCommand : ControlCommand;
        }

        state machine orchestrationState {
            state learningBaseline;
            state economicDispatch;
            state hydrogenDispatch;
            state resilienceDispatch;
            state emergencyShutdown;

            entry; then learningBaseline;

            transition baseline_to_economic
                first learningBaseline
                after 3600 [SI::second]
                then economicDispatch;

            transition economic_to_hydrogen
                first economicDispatch
                accept GridSignal
                if signal.electricityPrice_USDPerkWh < 0.02
                then hydrogenDispatch;

            transition hydrogen_to_economic
                first hydrogenDispatch
                accept GridSignal
                if signal.electricityPrice_USDPerkWh >= 0.02
                then economicDispatch;

            transition economic_to_resilience
                first economicDispatch
                accept GridSignal
                if signal.gridFrequencyHz < 59.5
                then resilienceDispatch;

            transition resilience_to_economic
                first resilienceDispatch
                accept GridSignal
                if signal.gridFrequencyHz >= 59.9
                then economicDispatch;

            transition any_to_shutdown
                first economicDispatch
                accept HealthTelemetry
                if telemetry.faultActive
                then emergencyShutdown;
        }
    }

    part def CriticalFacilityLoad {
        attribute peakDemand : Power = 520000 [SI::watt];
        attribute criticalDemand : Power = 180000 [SI::watt];
        attribute requiredAvailability_percent : Real = 99.99;

        port acInput : ElectricalPowerPort;
    }

    part def UtilityGridInterface {
        attribute interconnectionLimit : Power = 750000 [SI::watt];
        attribute nominalFrequencyHz : Real = 60.0;
        attribute nominalVoltage : Voltage = 480 [SI::volt];

        port acConnection : ElectricalPowerPort;
        port gridSignalOut : GridSignalPort;
    }

    part def QuantumSecureCommunicationsGateway {
        attribute keyRefreshPeriod : TimeDuration = 60 [SI::second];
        attribute maximumPacketLatency : TimeDuration = 0.25 [SI::second];
        attribute postQuantumAlgorithm : String = "CRYSTALS-Kyber-1024";

        port telemetryOut : TelemetryPort;
        port commandIn : CommandPort;

        action authenticateControlMessage {
            in command : ControlCommand;
            out accepted : Boolean;
        }
    }

    part def AutonomousHydrogenMicrogrid {
        attribute primaryFunction : String =
            "Provide resilient, low-carbon electrical power by combining AI-optimized renewable generation, solid-state storage, hydrogen production, hydrogen storage, and fuel-cell backup.";
        attribute nominalAcBusVoltage : Voltage = 480 [SI::volt];
        attribute nominalDcBusVoltage : Voltage = 800 [SI::volt];
        attribute totalRenewableCapacity : Power = 250000 [SI::watt];
        attribute maximumContinuousLoad : Power = 520000 [SI::watt];
        attribute targetIslandedRuntime : TimeDuration = 172800 [SI::second];

        part solarArray : PerovskiteSolarArray;
        part batteryBank : SolidStateBatteryBank;
        part electrolyzer : ProtonExchangeMembraneElectrolyzer;
        part hydrogenStorage : MetalHydrideHydrogenStorage;
        part fuelCell : HydrogenFuelCellGenerator;
        part converter : SiliconCarbidePowerConverter;
        part orchestrator : AIEnergyOrchestrator;
        part facilityLoad : CriticalFacilityLoad;
        part gridInterface : UtilityGridInterface;
        part secureGateway : QuantumSecureCommunicationsGateway;

        port weatherForecastIn : ForecastPort;
        port externalGridSignalIn : GridSignalPort;
        port acServicePort : ElectricalPowerPort;

        connect solarArray.dcOutput to converter.dcSide;
        connect batteryBank.dcBus to converter.dcSide;
        connect electrolyzer.electricalInput to converter.dcSide;
        connect fuelCell.dcOutput to converter.dcSide;
        connect converter.acSide to facilityLoad.acInput;
        connect converter.acSide to gridInterface.acConnection;
        connect facilityLoad.acInput to acServicePort;

        connect electrolyzer.hydrogenOutput to hydrogenStorage.hydrogenIn;
        connect hydrogenStorage.hydrogenOut to fuelCell.hydrogenInput;

        connect weatherForecastIn to orchestrator.forecastIn;
        connect gridInterface.gridSignalOut to orchestrator.gridSignalIn;
        connect externalGridSignalIn to orchestrator.gridSignalIn;

        connect orchestrator.batteryCommandOut to batteryBank.commandIn;
        connect orchestrator.converterCommandOut to converter.commandIn;
        connect orchestrator.electrolyzerCommandOut to electrolyzer.commandIn;
        connect orchestrator.fuelCellCommandOut to fuelCell.commandIn;
        connect secureGateway.commandIn to orchestrator.batteryCommandOut;

        perform action manageEnergy {
            first collectForecasts;
            then estimateRenewableGeneration;
            then optimizeDispatchPlan;
            then issueSecureCommands;
            then balancePowerFlow;
            then updateHealthModel;
            then done;

            action collectForecasts {
                out forecast : WeatherForecast;
                out gridSignal : GridSignal;
            }

            action estimateRenewableGeneration {
                in forecast : WeatherForecast;
                out expectedSolarPower : Power;
            }

            action optimizeDispatchPlan {
                in expectedSolarPower : Power;
                in gridSignal : GridSignal;
                out selectedMode : MicrogridOperatingMode;
            }

            action issueSecureCommands {
                in selectedMode : MicrogridOperatingMode;
                out accepted : Boolean;
            }

            action balancePowerFlow {
                in selectedMode : MicrogridOperatingMode;
                out servedLoad : ElectricalEnergy;
            }

            action updateHealthModel {
                out health : HealthTelemetry;
            }
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall autonomously provide resilient, low-carbon power for a critical facility using emerging energy and AI technologies. */
        subject microgrid : AutonomousHydrogenMicrogrid;

        require constraint {
            microgrid.maximumContinuousLoad >= microgrid.facilityLoad.peakDemand
        }
    }

    requirement def RenewableUtilizationRequirement {
        doc /* The system shall preferentially serve facility load from renewable generation when sufficient solar energy is available. */
        subject microgrid : AutonomousHydrogenMicrogrid;

        require constraint {
            microgrid.solarArray.ratedPower >= 0 [SI::watt]
        }
    }

    requirement def IslandedOperationRequirement {
        doc /* The system shall support islanded operation for at least forty-eight hours for critical loads. */
        subject microgrid : AutonomousHydrogenMicrogrid;

        require constraint {
            microgrid.targetIslandedRuntime >= 172800 [SI::second]
        }
    }

    requirement def HydrogenProductionRequirement {
        doc /* The system shall convert surplus electrical energy into hydrogen when battery storage is near its maximum state of charge and grid export is constrained. */
        subject microgrid : AutonomousHydrogenMicrogrid;

        require constraint {
            microgrid.electrolyzer.conversionEfficiency >= 0.65
        }
    }

    requirement def DispatchLatencyRequirement {
        doc /* The AI energy orchestrator shall issue dispatch decisions within two seconds of receiving updated forecasts and grid signals. */
        subject controller : AIEnergyOrchestrator;

        require constraint {
            controller.maximumDecisionLatency <= 2 [SI::second]
        }
    }

    requirement def StorageSafetyRequirement {
        doc /* The hydrogen storage subsystem shall operate below its maximum certified storage pressure. */
        subject storage : MetalHydrideHydrogenStorage;

        require constraint {
            storage.maximumPressure_bar <= 35.0
        }
    }

    requirement def CybersecurityRequirement {
        doc /* Control commands shall be authenticated using post-quantum cryptography before execution by energy assets. */
        subject gateway : QuantumSecureCommunicationsGateway;

        require constraint {
            gateway.keyRefreshPeriod <= 60 [SI::second]
        }
    }

    requirement def PowerConversionEfficiencyRequirement {
        doc /* The bidirectional power converter shall maintain high conversion efficiency to reduce energy losses. */
        subject converter : SiliconCarbidePowerConverter;

        require constraint {
            converter.conversionEfficiency >= 0.97
        }
    }

    satisfy PrimaryFunctionRequirement by AutonomousHydrogenMicrogrid;
    satisfy IslandedOperationRequirement by AutonomousHydrogenMicrogrid;
    satisfy RenewableUtilizationRequirement by AutonomousHydrogenMicrogrid;
    satisfy HydrogenProductionRequirement by ProtonExchangeMembraneElectrolyzer;
    satisfy DispatchLatencyRequirement by AIEnergyOrchestrator;
    satisfy StorageSafetyRequirement by MetalHydrideHydrogenStorage;
    satisfy CybersecurityRequirement by QuantumSecureCommunicationsGateway;
    satisfy PowerConversionEfficiencyRequirement by SiliconCarbidePowerConverter;
}
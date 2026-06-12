package EnergyIndustryMicrogridSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Voltage :> ISQ::electricPotential {
        unit = V;
    }

    attribute def Current :> ISQ::electricCurrent {
        unit = A;
    }

    attribute def Power :> ISQ::power {
        unit = W;
    }

    attribute def Energy :> ISQ::energy {
        unit = Wh;
    }

    attribute def Frequency :> ISQ::frequency {
        unit = Hz;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = K;
    }

    attribute def Irradiance {
        :>> scalarValues::Real;
        unit = W / m^2;
    }

    attribute def StateOfCharge {
        :>> scalarValues::Real;
        unit = %;
    }

    attribute def CarbonIntensity {
        :>> scalarValues::Real;
        unit = g / kWh;
    }

    item def ElectricalEnergy {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute realPower : Power;
        attribute frequency : Frequency;
        attribute phaseCount : ScalarValues::Integer;
    }

    item def ControlCommand {
        attribute targetPower : Power;
        attribute targetVoltage : Voltage;
        attribute targetFrequency : Frequency;
        attribute enableExport : ScalarValues::Boolean;
        attribute priorityLevel : ScalarValues::Integer;
    }

    item def TelemetryPacket {
        attribute measuredPower : Power;
        attribute measuredVoltage : Voltage;
        attribute measuredFrequency : Frequency;
        attribute measuredTemperature : Temperature;
        attribute timeStamp_s : ScalarValues::Real;
    }

    item def FuelGas {
        attribute flowRate_kgPerS : ScalarValues::Real;
        attribute lowerHeatingValue_MJPerKg : ScalarValues::Real;
    }

    port def ACPowerPort {
        out item electricalEnergy : ElectricalEnergy;
    }

    port def ACPowerInlet {
        in item electricalEnergy : ElectricalEnergy;
    }

    port def BidirectionalACPort {
        inout item electricalEnergy : ElectricalEnergy;
    }

    port def ControlOutPort {
        out item command : ControlCommand;
    }

    port def ControlInPort {
        in item command : ControlCommand;
    }

    port def TelemetryOutPort {
        out item telemetry : TelemetryPacket;
    }

    port def TelemetryInPort {
        in item telemetry : TelemetryPacket;
    }

    port def GasInletPort {
        in item fuel : FuelGas;
    }

    action def ConvertSolarIrradianceToACPower {
        in attribute incidentIrradiance : Irradiance;
        in attribute dcArrayCapacity : Power;
        in attribute inverterEfficiency : ScalarValues::Real;
        out attribute acPowerOutput : Power;

        requirement conversionLimit {
            text = "Solar AC output shall not exceed installed inverter-rated capacity.";
            require acPowerOutput <= dcArrayCapacity * inverterEfficiency;
        }
    }

    action def DispatchStoragePower {
        in attribute requestedPower : Power;
        in attribute batteryStateOfCharge : StateOfCharge;
        in attribute maxChargePower : Power;
        in attribute maxDischargePower : Power;
        out attribute dispatchedPower : Power;

        requirement storageDispatchLimit {
            text = "Battery dispatch shall remain within charge and discharge power limits and shall preserve operating state of charge.";
            require dispatchedPower >= -maxChargePower and dispatchedPower <= maxDischargePower;
            require batteryStateOfCharge >= 10 [%] and batteryStateOfCharge <= 95 [%];
        }
    }

    action def BalanceMicrogrid {
        in attribute loadDemand : Power;
        in attribute solarAvailable : Power;
        in attribute batteryAvailable : Power;
        in attribute generatorAvailable : Power;
        out attribute gridImport : Power;
        out attribute gridExport : Power;
        out attribute servedLoad : Power;

        requirement balanceConservation {
            text = "Microgrid dispatch shall balance generation, storage, utility exchange, and served load during grid-connected operation.";
            require servedLoad == loadDemand;
            require solarAvailable + batteryAvailable + generatorAvailable + gridImport == servedLoad + gridExport;
        }
    }

    state def GridConnectionMode {
        state gridConnected;
        state islanded;
        state reconnectionPending;

        transition gridConnected_to_islanded
            first gridConnected
            then islanded;

        transition islanded_to_reconnectionPending
            first islanded
            then reconnectionPending;

        transition reconnectionPending_to_gridConnected
            first reconnectionPending
            then gridConnected;
    }

    state def BatteryOperatingMode {
        state standby;
        state charging;
        state discharging;
        state protectedShutdown;

        transition standby_to_charging
            first standby
            then charging;

        transition standby_to_discharging
            first standby
            then discharging;

        transition charging_to_standby
            first charging
            then standby;

        transition discharging_to_standby
            first discharging
            then standby;

        transition any_to_protectedShutdown
            first standby
            then protectedShutdown;
    }

    part def PhotovoltaicArray {
        attribute installedCapacity : Power = 500000 [W];
        attribute nominalDCVoltage : Voltage = 1000 [V];
        attribute moduleTemperature : Temperature;
        attribute planeOfArrayIrradiance : Irradiance;

        port acOutput : ACPowerPort;
        port controlInput : ControlInPort;
        port telemetryOutput : TelemetryOutPort;

        perform action generatePower : ConvertSolarIrradianceToACPower {
            in incidentIrradiance = planeOfArrayIrradiance;
            in dcArrayCapacity = installedCapacity;
            in inverterEfficiency = 0.975;
        }
    }

    part def BatteryEnergyStorageSystem {
        attribute usableEnergyCapacity : Energy = 1200000 [Wh];
        attribute maximumChargePower : Power = 400000 [W];
        attribute maximumDischargePower : Power = 400000 [W];
        attribute stateOfCharge : StateOfCharge;
        attribute roundTripEfficiency : ScalarValues::Real = 0.91;
        attribute cellTemperature : Temperature;

        port acPort : BidirectionalACPort;
        port controlInput : ControlInPort;
        port telemetryOutput : TelemetryOutPort;

        exhibit state batteryMode : BatteryOperatingMode;

        perform action dispatch : DispatchStoragePower {
            in batteryStateOfCharge = stateOfCharge;
            in maxChargePower = maximumChargePower;
            in maxDischargePower = maximumDischargePower;
        }
    }

    part def GasGenerator {
        attribute ratedPower : Power = 750000 [W];
        attribute minimumStablePower : Power = 150000 [W];
        attribute rampRate_WPerS : ScalarValues::Real = 8000;
        attribute exhaustCarbonIntensity : CarbonIntensity = 520 [g / kWh];

        port fuelInput : GasInletPort;
        port acOutput : ACPowerPort;
        port controlInput : ControlInPort;
        port telemetryOutput : TelemetryOutPort;

        requirement generatorOperatingBand {
            text = "The dispatchable generator shall operate between minimum stable power and rated power when committed.";
            require minimumStablePower <= ratedPower;
        }
    }

    part def UtilityGridIntertie {
        attribute nominalVoltage : Voltage = 13800 [V];
        attribute nominalFrequency : Frequency = 60 [Hz];
        attribute importLimit : Power = 1000000 [W];
        attribute exportLimit : Power = 600000 [W];
        attribute breakerClosed : ScalarValues::Boolean;

        port gridPort : BidirectionalACPort;
        port controlInput : ControlInPort;
        port telemetryOutput : TelemetryOutPort;

        exhibit state connectionMode : GridConnectionMode;
    }

    part def CriticalLoadCenter {
        attribute peakDemand : Power = 900000 [W];
        attribute presentDemand : Power;
        attribute minimumServedFraction : ScalarValues::Real = 0.98;
        attribute nominalVoltage : Voltage = 480 [V];

        port acInput : ACPowerInlet;
        port telemetryOutput : TelemetryOutPort;

        requirement loadServiceContinuity {
            text = "Critical loads shall receive at least 98 percent of present demand during normal and islanded operation.";
            require minimumServedFraction >= 0.98;
        }
    }

    part def MicrogridController {
        attribute dispatchInterval_s : ScalarValues::Real = 1.0;
        attribute targetFrequency : Frequency = 60 [Hz];
        attribute targetBusVoltage : Voltage = 480 [V];
        attribute reserveMargin : ScalarValues::Real = 0.15;
        attribute preferredCarbonIntensity : CarbonIntensity = 250 [g / kWh];

        port pvTelemetry : TelemetryInPort;
        port batteryTelemetry : TelemetryInPort;
        port generatorTelemetry : TelemetryInPort;
        port gridTelemetry : TelemetryInPort;
        port loadTelemetry : TelemetryInPort;

        port pvCommand : ControlOutPort;
        port batteryCommand : ControlOutPort;
        port generatorCommand : ControlOutPort;
        port gridCommand : ControlOutPort;

        perform action optimizeDispatch : BalanceMicrogrid;
    }

    part def ACDistributionBus {
        attribute nominalVoltage : Voltage = 480 [V];
        attribute nominalFrequency : Frequency = 60 [Hz];
        attribute shortCircuitRating_A : ScalarValues::Real = 65000;

        port pvInput : ACPowerInlet;
        port batteryPort : BidirectionalACPort;
        port generatorInput : ACPowerInlet;
        port gridPort : BidirectionalACPort;
        port loadOutput : ACPowerPort;
    }

    part def CommunityMicrogrid {
        doc
        /* The CommunityMicrogrid is an energy-industry system whose primary high-level function is to supply reliable, balanced electrical power to critical local loads by coordinating renewable generation, battery storage, dispatchable generation, and utility grid exchange. */

        attribute totalInstalledGeneration : Power = 1250000 [W];
        attribute totalStorageCapacity : Energy = 1200000 [Wh];
        attribute nominalSystemFrequency : Frequency = 60 [Hz];
        attribute nominalLowVoltageBus : Voltage = 480 [V];

        part photovoltaicArray : PhotovoltaicArray;
        part batteryStorage : BatteryEnergyStorageSystem;
        part gasGenerator : GasGenerator;
        part utilityIntertie : UtilityGridIntertie;
        part loadCenter : CriticalLoadCenter;
        part controller : MicrogridController;
        part distributionBus : ACDistributionBus;

        connect photovoltaicArray.acOutput to distributionBus.pvInput;
        connect batteryStorage.acPort to distributionBus.batteryPort;
        connect gasGenerator.acOutput to distributionBus.generatorInput;
        connect utilityIntertie.gridPort to distributionBus.gridPort;
        connect distributionBus.loadOutput to loadCenter.acInput;

        connect photovoltaicArray.telemetryOutput to controller.pvTelemetry;
        connect batteryStorage.telemetryOutput to controller.batteryTelemetry;
        connect gasGenerator.telemetryOutput to controller.generatorTelemetry;
        connect utilityIntertie.telemetryOutput to controller.gridTelemetry;
        connect loadCenter.telemetryOutput to controller.loadTelemetry;

        connect controller.pvCommand to photovoltaicArray.controlInput;
        connect controller.batteryCommand to batteryStorage.controlInput;
        connect controller.generatorCommand to gasGenerator.controlInput;
        connect controller.gridCommand to utilityIntertie.controlInput;

        requirement primaryFunction {
            text = "The system shall supply electrical energy to community critical loads by coordinating solar photovoltaic generation, battery energy storage, gas generation, and utility grid import or export.";
            subject this;
        }

        requirement frequencyRegulation {
            text = "The system shall maintain AC bus frequency within plus or minus 0.2 hertz of nominal frequency during steady-state operation.";
            require distributionBus.nominalFrequency >= 59.8 [Hz] and distributionBus.nominalFrequency <= 60.2 [Hz];
        }

        requirement voltageRegulation {
            text = "The system shall maintain the low-voltage AC distribution bus within plus or minus 5 percent of nominal voltage.";
            require distributionBus.nominalVoltage >= 456 [V] and distributionBus.nominalVoltage <= 504 [V];
        }

        requirement renewablePriority {
            text = "The controller shall prioritize available solar photovoltaic power before dispatching gas generation when load, storage, and grid constraints allow.";
            subject controller;
        }

        requirement islandedResilience {
            text = "The system shall support islanded operation for critical loads using photovoltaic generation, battery storage, and gas generation when the utility intertie is unavailable.";
            subject this;
        }

        requirement storageAutonomy {
            text = "Battery usable energy capacity shall be sufficient to supply at least 400 kilowatts for three hours without photovoltaic, generator, or grid support.";
            require batteryStorage.usableEnergyCapacity >= 1200000 [Wh];
        }

        requirement exportConstraint {
            text = "Power exported through the utility intertie shall not exceed the export limit established for the point of common coupling.";
            require utilityIntertie.exportLimit <= 600000 [W];
        }

        requirement importConstraint {
            text = "Power imported through the utility intertie shall not exceed the import limit established for the point of common coupling.";
            require utilityIntertie.importLimit <= 1000000 [W];
        }

        requirement emissionsManagement {
            text = "The dispatch strategy shall reduce gas generator operation when renewable generation and battery state of charge can satisfy load and reserve requirements.";
            subject controller;
        }

        perform action normalOperation : BalanceMicrogrid {
            in loadDemand = loadCenter.presentDemand;
            out servedLoad = loadCenter.presentDemand;
        }
    }

    satisfy CommunityMicrogrid.primaryFunction by CommunityMicrogrid;
    satisfy CommunityMicrogrid.frequencyRegulation by CommunityMicrogrid.distributionBus;
    satisfy CommunityMicrogrid.voltageRegulation by CommunityMicrogrid.distributionBus;
    satisfy CommunityMicrogrid.renewablePriority by CommunityMicrogrid.controller;
    satisfy CommunityMicrogrid.islandedResilience by CommunityMicrogrid;
    satisfy CommunityMicrogrid.storageAutonomy by CommunityMicrogrid.batteryStorage;
    satisfy CommunityMicrogrid.exportConstraint by CommunityMicrogrid.utilityIntertie;
    satisfy CommunityMicrogrid.importConstraint by CommunityMicrogrid.utilityIntertie;
    satisfy CommunityMicrogrid.emissionsManagement by CommunityMicrogrid.controller;
}
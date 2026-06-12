package PMCBasedPowerManagementSystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;
    import Requirements::*;

    attribute def Voltage :> ISQ::voltage {
        unit = SI::volt;
    }

    attribute def Current :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Power :> ISQ::power {
        unit = SI::watt;
    }

    attribute def Energy :> ISQ::energy {
        unit = SI::joule;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def Frequency :> ISQ::frequency {
        unit = SI::hertz;
    }

    attribute def Duration :> ISQ::duration {
        unit = SI::second;
    }

    attribute def Percent :> ScalarValues::Real {
        unit = SI::percent;
    }

    enum def PowerMode {
        enum off;
        enum standby;
        enum lowPower;
        enum nominal;
        enum performance;
        enum faultIsolated;
    }

    enum def SourceHealth {
        enum unavailable;
        enum degraded;
        enum available;
        enum preferred;
    }

    enum def LoadPriority {
        enum critical;
        enum essential;
        enum discretionary;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
        attribute frequency : Frequency;
    }

    item def PowerCommand {
        attribute requestedMode : PowerMode;
        attribute maxAllowedPower : Power;
        attribute transitionDeadline : Duration;
    }

    item def PowerStatus {
        attribute activeMode : PowerMode;
        attribute availablePower : Power;
        attribute consumedPower : Power;
        attribute reserveEnergy : Energy;
        attribute controllerTemperature : Temperature;
        attribute faultPresent : Boolean;
    }

    item def SensorSample {
        attribute busVoltage : Voltage;
        attribute busCurrent : Current;
        attribute sourceTemperature : Temperature;
        attribute loadTemperature : Temperature;
        attribute timestamp : Duration;
    }

    item def FaultReport {
        attribute overVoltage : Boolean;
        attribute underVoltage : Boolean;
        attribute overCurrent : Boolean;
        attribute overTemperature : Boolean;
        attribute sourceLost : Boolean;
        attribute affectedChannel : String;
    }

    port def PowerInputPort {
        in item suppliedPower : ElectricalPower;
        out item sourceHealth : SourceHealth;
    }

    port def PowerOutputPort {
        out item distributedPower : ElectricalPower;
        in item loadDemand : PowerCommand;
    }

    port def CommandPort {
        in item command : PowerCommand;
        out item status : PowerStatus;
    }

    port def TelemetryPort {
        out item status : PowerStatus;
        out item sample : SensorSample;
        out item fault : FaultReport;
    }

    port def SensorPort {
        in item sample : SensorSample;
    }

    port def ControlPort {
        out item enableSignal : Boolean;
        out item powerLimit : Power;
        out item targetMode : PowerMode;
        in item acknowledged : Boolean;
    }

    part def PowerSource {
        attribute ratedPower : Power;
        attribute nominalVoltage : Voltage;
        attribute health : SourceHealth;
        attribute outputPower : Power;

        port powerOut : PowerInputPort;
    }

    part def BatteryReserve {
        attribute storedEnergy : Energy;
        attribute stateOfCharge : Percent;
        attribute nominalVoltage : Voltage;
        attribute maxDischargePower : Power;
        attribute maxChargePower : Power;
        attribute health : SourceHealth;

        port reservePower : PowerInputPort;
        port telemetry : TelemetryPort;
    }

    part def PowerConversionUnit {
        attribute inputVoltage : Voltage;
        attribute outputVoltage : Voltage;
        attribute efficiency : Percent;
        attribute maxOutputPower : Power;
        attribute thermalLimit : Temperature;

        port primaryInput : PowerInputPort;
        port reserveInput : PowerInputPort;
        port regulatedOutput : PowerOutputPort;
        port control : ControlPort;
        port sensors : SensorPort;
    }

    part def LoadChannel {
        attribute priority : LoadPriority;
        attribute nominalPower : Power;
        attribute currentLimit : Current;
        attribute enabled : Boolean;
        attribute allocatedPower : Power;

        port powerIn : PowerOutputPort;
        port control : ControlPort;
        port telemetry : TelemetryPort;
    }

    part def CriticalProcessingLoad :> LoadChannel {
        attribute priority = LoadPriority::critical;
        attribute nominalPower = 250 [SI::watt];
        attribute currentLimit = 12 [SI::ampere];
    }

    part def CommunicationsLoad :> LoadChannel {
        attribute priority = LoadPriority::essential;
        attribute nominalPower = 120 [SI::watt];
        attribute currentLimit = 8 [SI::ampere];
    }

    part def AuxiliaryLoad :> LoadChannel {
        attribute priority = LoadPriority::discretionary;
        attribute nominalPower = 80 [SI::watt];
        attribute currentLimit = 5 [SI::ampere];
    }

    part def SensorArray {
        attribute samplePeriod : Duration;
        attribute voltageAccuracy : Percent;
        attribute currentAccuracy : Percent;
        attribute temperatureAccuracy : Temperature;

        port measuredData : SensorPort;
    }

    part def PowerManagementController {
        attribute activeMode : PowerMode;
        attribute maxSystemPower : Power;
        attribute reserveThreshold : Percent;
        attribute thermalWarningLimit : Temperature;
        attribute faultDetected : Boolean;

        port operatorInterface : CommandPort;
        port telemetryOut : TelemetryPort;
        port sensorInput : SensorPort;
        port converterControl : ControlPort;
        port criticalControl : ControlPort;
        port communicationsControl : ControlPort;
        port auxiliaryControl : ControlPort;

        action monitorPower {
            in item sample : SensorSample;
            out item status : PowerStatus;
        }

        action evaluateFaults {
            in item sample : SensorSample;
            out item report : FaultReport;
        }

        action allocatePower {
            in item command : PowerCommand;
            in item status : PowerStatus;
            out item criticalLimit : Power;
            out item communicationsLimit : Power;
            out item auxiliaryLimit : Power;
        }

        action commandLoads {
            in item selectedMode : PowerMode;
            out item criticalEnable : Boolean;
            out item communicationsEnable : Boolean;
            out item auxiliaryEnable : Boolean;
        }

        state def PMCLifecycle {
            entry action initializeController;

            state Off;
            state Standby;
            state NormalOperation;
            state LoadShedding;
            state PerformanceBoost;
            state FaultIsolation;
            state EmergencyShutdown;

            transition first Off;

            transition Off_to_Standby
                first Off
                then Standby
                accept PowerCommand
                if command.requestedMode == PowerMode::standby;

            transition Standby_to_Normal
                first Standby
                then NormalOperation
                accept PowerCommand
                if command.requestedMode == PowerMode::nominal;

            transition Normal_to_Performance
                first NormalOperation
                then PerformanceBoost
                accept PowerCommand
                if command.requestedMode == PowerMode::performance;

            transition Performance_to_Normal
                first PerformanceBoost
                then NormalOperation
                accept PowerCommand
                if command.requestedMode == PowerMode::nominal;

            transition Normal_to_LoadShedding
                first NormalOperation
                then LoadShedding
                if status.consumedPower > status.availablePower or status.reserveEnergy < 72000 [SI::joule];

            transition LoadShedding_to_Normal
                first LoadShedding
                then NormalOperation
                if status.availablePower - status.consumedPower > 100 [SI::watt];

            transition Any_to_FaultIsolation
                first NormalOperation
                then FaultIsolation
                if fault.overCurrent or fault.overTemperature or fault.sourceLost;

            transition FaultIsolation_to_EmergencyShutdown
                first FaultIsolation
                then EmergencyShutdown
                if fault.overVoltage and fault.overCurrent;

            transition EmergencyShutdown_to_Off
                first EmergencyShutdown
                then Off
                accept PowerCommand
                if command.requestedMode == PowerMode::off;
        }

        exhibit stateMachine : PMCLifecycle;
    }

    part def PMCBasedSystem {
        attribute systemNominalVoltage : Voltage = 28 [SI::volt];
        attribute systemMaximumPower : Power = 600 [SI::watt];
        attribute minimumReserveEnergy : Energy = 72000 [SI::joule];

        part primarySource : PowerSource {
            attribute ratedPower = 500 [SI::watt];
            attribute nominalVoltage = 28 [SI::volt];
        }

        part reserveBattery : BatteryReserve {
            attribute storedEnergy = 144000 [SI::joule];
            attribute stateOfCharge = 100;
            attribute nominalVoltage = 28 [SI::volt];
            attribute maxDischargePower = 300 [SI::watt];
            attribute maxChargePower = 100 [SI::watt];
        }

        part converter : PowerConversionUnit {
            attribute outputVoltage = 28 [SI::volt];
            attribute efficiency = 94;
            attribute maxOutputPower = 600 [SI::watt];
            attribute thermalLimit = 358 [SI::kelvin];
        }

        part pmc : PowerManagementController {
            attribute activeMode = PowerMode::standby;
            attribute maxSystemPower = 600 [SI::watt];
            attribute reserveThreshold = 25;
            attribute thermalWarningLimit = 348 [SI::kelvin];
        }

        part sensors : SensorArray {
            attribute samplePeriod = 0.1 [SI::second];
            attribute voltageAccuracy = 1;
            attribute currentAccuracy = 1;
            attribute temperatureAccuracy = 2 [SI::kelvin];
        }

        part criticalLoad : CriticalProcessingLoad;
        part communicationsLoad : CommunicationsLoad;
        part auxiliaryLoad : AuxiliaryLoad;

        port externalCommand : CommandPort;
        port externalTelemetry : TelemetryPort;
        port primaryPowerInput : PowerInputPort;

        connect primaryPowerInput to primarySource.powerOut;
        connect primarySource.powerOut to converter.primaryInput;
        connect reserveBattery.reservePower to converter.reserveInput;
        connect converter.regulatedOutput to criticalLoad.powerIn;
        connect converter.regulatedOutput to communicationsLoad.powerIn;
        connect converter.regulatedOutput to auxiliaryLoad.powerIn;

        connect sensors.measuredData to pmc.sensorInput;
        connect sensors.measuredData to converter.sensors;

        connect externalCommand to pmc.operatorInterface;
        connect pmc.telemetryOut to externalTelemetry;

        connect pmc.converterControl to converter.control;
        connect pmc.criticalControl to criticalLoad.control;
        connect pmc.communicationsControl to communicationsLoad.control;
        connect pmc.auxiliaryControl to auxiliaryLoad.control;

        connect criticalLoad.telemetry to externalTelemetry;
        connect communicationsLoad.telemetry to externalTelemetry;
        connect auxiliaryLoad.telemetry to externalTelemetry;
        connect reserveBattery.telemetry to externalTelemetry;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : PMCBasedSystem;

        doc /* The PMC-based system shall manage electrical power distribution by monitoring source availability, reserve energy, load demand, and thermal conditions, then commanding conversion and load channels so that critical functions remain powered while available energy is used efficiently and safely. */

        require constraint {
            system.criticalLoad.enabled == true
        }
    }

    requirement def CriticalLoadContinuityRequirement {
        subject system : PMCBasedSystem;

        doc /* The system shall maintain power to the critical processing load whenever either the primary source or reserve battery can provide sufficient electrical power. */

        require constraint {
            system.criticalLoad.allocatedPower >= 200 [SI::watt]
        }
    }

    requirement def OverCurrentProtectionRequirement {
        subject system : PMCBasedSystem;

        doc /* The PMC shall isolate a load channel when measured current exceeds the configured current limit for that channel. */

        require constraint {
            system.criticalLoad.currentLimit <= 12 [SI::ampere] and
            system.communicationsLoad.currentLimit <= 8 [SI::ampere] and
            system.auxiliaryLoad.currentLimit <= 5 [SI::ampere]
        }
    }

    requirement def ReserveEnergyRequirement {
        subject system : PMCBasedSystem;

        doc /* The system shall enter low-power operation and shed discretionary load when reserve energy falls below the configured reserve threshold. */

        require constraint {
            system.reserveBattery.storedEnergy >= system.minimumReserveEnergy
        }
    }

    requirement def ThermalProtectionRequirement {
        subject system : PMCBasedSystem;

        doc /* The PMC shall reduce load allocation or isolate affected channels before converter temperature exceeds the thermal safety limit. */

        require constraint {
            system.pmc.thermalWarningLimit < system.converter.thermalLimit
        }
    }

    requirement def TelemetryRequirement {
        subject system : PMCBasedSystem;

        doc /* The system shall report active power mode, consumed power, available power, reserve energy, thermal state, and active fault status through the telemetry interface. */

        require constraint {
            system.sensors.samplePeriod <= 0.5 [SI::second]
        }
    }

    satisfy PrimaryFunctionRequirement by PMCBasedSystem;
    satisfy CriticalLoadContinuityRequirement by PMCBasedSystem::criticalLoad;
    satisfy OverCurrentProtectionRequirement by PMCBasedSystem::pmc;
    satisfy ReserveEnergyRequirement by PMCBasedSystem::pmc;
    satisfy ThermalProtectionRequirement by PMCBasedSystem::pmc;
    satisfy TelemetryRequirement by PMCBasedSystem::externalTelemetry;

}
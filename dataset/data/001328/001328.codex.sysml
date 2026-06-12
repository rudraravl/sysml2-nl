package ABB_PrimaryFunctionModel {
    import ScalarValues::*;

    unit V;
    unit A;
    unit W;
    unit Wh;
    unit Hz;
    unit degC;
    unit ms;
    unit percent;

    attribute def Voltage :> Real { unit = V; }
    attribute def Current :> Real { unit = A; }
    attribute def Power :> Real { unit = W; }
    attribute def Energy :> Real { unit = Wh; }
    attribute def Frequency :> Real { unit = Hz; }
    attribute def Temperature :> Real { unit = degC; }
    attribute def Duration :> Real { unit = ms; }
    attribute def Percentage :> Real { unit = percent; }

    enum def OperatingMode {
        enum standby;
        enum charging;
        enum backupSupply;
        enum bypass;
        enum faultIsolated;
        enum maintenance;
    }

    item def ElectricalEnergy {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
        attribute frequency : Frequency;
    }

    item def ThermalEnergy {
        attribute temperature : Temperature;
        attribute heatFlow : Power;
    }

    item def ControlCommand {
        attribute requestedMode : OperatingMode;
        attribute priority : Integer;
    }

    item def SystemStatus {
        attribute activeMode : OperatingMode;
        attribute stateOfCharge : Percentage;
        attribute loadPower : Power;
        attribute remainingRuntime : Duration;
        attribute alarmActive : Boolean;
    }

    port def AcPowerPort {
        inout item energy : ElectricalEnergy;
    }

    port def DcPowerPort {
        inout item energy : ElectricalEnergy;
    }

    port def ThermalPort {
        out item heat : ThermalEnergy;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def StatusPort {
        out item status : SystemStatus;
    }

    part def ArchitectureBuildingBlock {
        attribute abbIdentifier : String;
        attribute primaryFunction : String;
        attribute allocatedPowerCapacity : Power;
        attribute nominalVoltage : Voltage;
    }

    part def GridInterface :> ArchitectureBuildingBlock {
        attribute primaryFunction = "Accept normal utility power and expose it to ABB conversion and bypass equipment.";
        attribute allocatedPowerCapacity = 6000 [W];
        attribute nominalVoltage = 120 [V];

        port utilityInput : AcPowerPort;
        port conditionedOutput : AcPowerPort;
        port statusOut : StatusPort;
    }

    part def BatteryModule :> ArchitectureBuildingBlock {
        attribute primaryFunction = "Store electrical energy for automatic backup supply when utility power is unavailable.";
        attribute allocatedPowerCapacity = 5000 [W];
        attribute nominalVoltage = 48 [V];
        attribute ratedEnergy : Energy = 9600 [Wh];
        attribute minimumStateOfCharge : Percentage = 15 [percent];
        attribute maximumStateOfCharge : Percentage = 100 [percent];
        attribute presentStateOfCharge : Percentage;

        port dcBus : DcPowerPort;
        port thermalOut : ThermalPort;
        port statusOut : StatusPort;
    }

    part def ChargerRectifier :> ArchitectureBuildingBlock {
        attribute primaryFunction = "Convert AC utility power into regulated DC power for battery charging and DC bus support.";
        attribute allocatedPowerCapacity = 3000 [W];
        attribute nominalVoltage = 48 [V];
        attribute chargeEfficiency : Percentage = 92 [percent];

        port acIn : AcPowerPort;
        port dcOut : DcPowerPort;
        port commandIn : CommandPort;
        port statusOut : StatusPort;
    }

    part def Inverter :> ArchitectureBuildingBlock {
        attribute primaryFunction = "Convert stored DC energy into regulated AC power for the protected load.";
        attribute allocatedPowerCapacity = 5000 [W];
        attribute nominalVoltage = 120 [V];
        attribute outputFrequency : Frequency = 60 [Hz];
        attribute inverterEfficiency : Percentage = 94 [percent];

        port dcIn : DcPowerPort;
        port acOut : AcPowerPort;
        port commandIn : CommandPort;
        port statusOut : StatusPort;
    }

    part def StaticTransferSwitch :> ArchitectureBuildingBlock {
        attribute primaryFunction = "Select utility bypass or inverter output without interrupting the protected load.";
        attribute allocatedPowerCapacity = 5000 [W];
        attribute nominalVoltage = 120 [V];
        attribute maximumTransferTime : Duration = 8 [ms];

        port gridIn : AcPowerPort;
        port inverterIn : AcPowerPort;
        port loadOut : AcPowerPort;
        port commandIn : CommandPort;
        port statusOut : StatusPort;
    }

    part def Controller :> ArchitectureBuildingBlock {
        attribute primaryFunction = "Monitor utility, battery, and load conditions and command ABB operating modes.";
        attribute allocatedPowerCapacity = 50 [W];
        attribute nominalVoltage = 24 [V];

        port commandOut : CommandPort;
        port statusIn : StatusPort;
        port externalStatus : StatusPort;
    }

    part def CoolingSubsystem :> ArchitectureBuildingBlock {
        attribute primaryFunction = "Remove internally generated heat to maintain safe battery and power electronics temperatures.";
        attribute allocatedPowerCapacity = 250 [W];
        attribute nominalVoltage = 24 [V];
        attribute maximumAllowedTemperature : Temperature = 45 [degC];

        port heatIn : ThermalPort;
        port commandIn : CommandPort;
        port statusOut : StatusPort;
    }

    part def CriticalLoad {
        attribute requiredVoltage : Voltage = 120 [V];
        attribute requiredFrequency : Frequency = 60 [Hz];
        attribute peakPowerDemand : Power = 4500 [W];
        port powerIn : AcPowerPort;
    }

    action def MonitorPowerQuality {
        in item utilityEnergy : ElectricalEnergy;
        in item loadEnergy : ElectricalEnergy;
        out item status : SystemStatus;
    }

    action def ChargeBattery {
        in item acEnergy : ElectricalEnergy;
        out item dcEnergy : ElectricalEnergy;
        out item status : SystemStatus;
    }

    action def SupplyBackupPower {
        in item storedEnergy : ElectricalEnergy;
        out item protectedEnergy : ElectricalEnergy;
        out item status : SystemStatus;
    }

    action def TransferLoad {
        in item preferredSource : ElectricalEnergy;
        out item loadEnergy : ElectricalEnergy;
        out item status : SystemStatus;
    }

    action def IsolateFault {
        in item status : SystemStatus;
        out item command : ControlCommand;
    }

    state def ABBOperatingStateMachine {
        state initializing;
        state standby;
        state charging;
        state backupSupply;
        state bypassSupply;
        state faultIsolated;
        state maintenance;

        initial then initializing;

        transition initializing_to_standby
            first initializing
            then standby;

        transition standby_to_charging
            first standby
            accept ControlCommand
            if command.requestedMode == OperatingMode::charging
            then charging;

        transition charging_to_standby
            first charging
            accept SystemStatus
            if status.stateOfCharge >= 98 [percent]
            then standby;

        transition standby_to_backup
            first standby
            accept SystemStatus
            if status.activeMode == OperatingMode::backupSupply
            then backupSupply;

        transition backup_to_standby
            first backupSupply
            accept SystemStatus
            if status.activeMode == OperatingMode::standby and status.stateOfCharge > 20 [percent]
            then standby;

        transition standby_to_bypass
            first standby
            accept ControlCommand
            if command.requestedMode == OperatingMode::bypass
            then bypassSupply;

        transition any_to_fault
            first standby
            then faultIsolated
            accept SystemStatus
            if status.alarmActive == true;

        transition fault_to_maintenance
            first faultIsolated
            accept ControlCommand
            if command.requestedMode == OperatingMode::maintenance
            then maintenance;
    }

    part def ABBSystem :> ArchitectureBuildingBlock {
        attribute abbIdentifier = "ABB-UPS-5000";
        attribute primaryFunction = "Provide uninterrupted regulated AC power to a critical load by automatically using stored battery energy when utility power is degraded or unavailable.";
        attribute allocatedPowerCapacity = 5000 [W];
        attribute nominalVoltage = 120 [V];

        part gridInterface : GridInterface;
        part battery : BatteryModule;
        part charger : ChargerRectifier;
        part inverter : Inverter;
        part transferSwitch : StaticTransferSwitch;
        part controller : Controller;
        part cooling : CoolingSubsystem;
        part protectedLoad : CriticalLoad;

        port utilityInput : AcPowerPort;
        port loadOutput : AcPowerPort;
        port operatorCommand : CommandPort;
        port systemStatus : StatusPort;

        connect utilityInput to gridInterface.utilityInput;
        connect gridInterface.conditionedOutput to charger.acIn;
        connect gridInterface.conditionedOutput to transferSwitch.gridIn;
        connect charger.dcOut to battery.dcBus;
        connect battery.dcBus to inverter.dcIn;
        connect inverter.acOut to transferSwitch.inverterIn;
        connect transferSwitch.loadOut to protectedLoad.powerIn;
        connect protectedLoad.powerIn to loadOutput;

        connect operatorCommand to controller.commandOut;
        connect controller.commandOut to charger.commandIn;
        connect controller.commandOut to inverter.commandIn;
        connect controller.commandOut to transferSwitch.commandIn;
        connect controller.commandOut to cooling.commandIn;

        connect gridInterface.statusOut to controller.statusIn;
        connect charger.statusOut to controller.statusIn;
        connect inverter.statusOut to controller.statusIn;
        connect transferSwitch.statusOut to controller.statusIn;
        connect battery.statusOut to controller.statusIn;
        connect cooling.statusOut to controller.statusIn;
        connect controller.externalStatus to systemStatus;

        perform action monitor : MonitorPowerQuality;
        perform action charge : ChargeBattery;
        perform action backup : SupplyBackupPower;
        perform action transfer : TransferLoad;
        perform action isolate : IsolateFault;

        exhibit state ABBOperatingStateMachine;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : ABBSystem;
        doc /* The ABB system shall provide uninterrupted regulated AC power to the protected load during normal utility operation and during utility loss. */
        require constraint {
            system.allocatedPowerCapacity >= system.protectedLoad.peakPowerDemand
        }
    }

    requirement def BackupRuntimeRequirement {
        subject system : ABBSystem;
        doc /* The ABB system shall support the protected load from stored battery energy for a minimum useful backup interval. */
        require constraint {
            system.battery.ratedEnergy >= 9000 [Wh]
        }
    }

    requirement def TransferRequirement {
        subject system : ABBSystem;
        doc /* The ABB system shall transfer the protected load between utility and inverter sources fast enough to avoid interruption. */
        require constraint {
            system.transferSwitch.maximumTransferTime <= 8 [ms]
        }
    }

    requirement def VoltageRegulationRequirement {
        subject system : ABBSystem;
        doc /* The ABB system shall provide nominal 120 V AC output to the protected load. */
        require constraint {
            system.nominalVoltage == system.protectedLoad.requiredVoltage
        }
    }

    requirement def ThermalProtectionRequirement {
        subject system : ABBSystem;
        doc /* The ABB system shall maintain power electronics and battery operating temperature below the allowed thermal limit. */
        require constraint {
            system.cooling.maximumAllowedTemperature <= 45 [degC]
        }
    }

    requirement def StateOfChargeProtectionRequirement {
        subject system : ABBSystem;
        doc /* The ABB system shall prevent battery discharge below the minimum state of charge needed to preserve battery health. */
        require constraint {
            system.battery.minimumStateOfCharge >= 15 [percent]
        }
    }

    part abbBasedBackupPowerSystem : ABBSystem;

    satisfy PrimaryFunctionRequirement by abbBasedBackupPowerSystem;
    satisfy BackupRuntimeRequirement by abbBasedBackupPowerSystem;
    satisfy TransferRequirement by abbBasedBackupPowerSystem;
    satisfy VoltageRegulationRequirement by abbBasedBackupPowerSystem;
    satisfy ThermalProtectionRequirement by abbBasedBackupPowerSystem;
    satisfy StateOfChargeProtectionRequirement by abbBasedBackupPowerSystem;
}
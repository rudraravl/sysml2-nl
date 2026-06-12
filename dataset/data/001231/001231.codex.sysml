package SSIES_Model {
    import ScalarValues::*;

    value def Volt {
        :>> unit = "V";
        attribute value : Real;
    }

    value def Ampere {
        :>> unit = "A";
        attribute value : Real;
    }

    value def Watt {
        :>> unit = "W";
        attribute value : Real;
    }

    value def WattHour {
        :>> unit = "Wh";
        attribute value : Real;
    }

    value def Celsius {
        :>> unit = "degC";
        attribute value : Real;
    }

    value def Percent {
        :>> unit = "%";
        attribute value : Real;
    }

    value def Lux {
        :>> unit = "lx";
        attribute value : Real;
    }

    value def Second {
        :>> unit = "s";
        attribute value : Real;
    }

    enum def PowerMode {
        enum off;
        enum standby;
        enum harvesting;
        enum normalSupply;
        enum degradedSupply;
        enum emergencySupply;
        enum faultIsolated;
    }

    enum def HealthState {
        enum nominal;
        enum warning;
        enum failed;
        enum isolated;
    }

    item def ElectricalEnergy {
        attribute amount : WattHour;
        attribute sourceMode : PowerMode;
    }

    item def DCPower {
        attribute voltage : Volt;
        attribute current : Ampere;
        attribute power : Watt;
        attribute quality : Percent;
    }

    item def SensorTelemetry {
        attribute batteryStateOfCharge : Percent;
        attribute busVoltage : Volt;
        attribute loadCurrent : Ampere;
        attribute ambientLight : Lux;
        attribute cabinetTemperature : Celsius;
        attribute controllerHealth : HealthState;
    }

    item def ControlCommand {
        attribute requestedMode : PowerMode;
        attribute loadSheddingEnabled : Boolean;
        attribute emergencyReserveEnabled : Boolean;
    }

    item def FaultReport {
        attribute faultedSubsystem : String;
        attribute severity : Percent;
        attribute isolationRequired : Boolean;
    }

    port def DCPowerSourcePort {
        out item power : DCPower;
    }

    port def DCPowerSinkPort {
        in item power : DCPower;
    }

    port def BidirectionalDCPowerPort {
        in item receivedPower : DCPower;
        out item suppliedPower : DCPower;
    }

    port def TelemetryOutPort {
        out item telemetry : SensorTelemetry;
    }

    port def TelemetryInPort {
        in item telemetry : SensorTelemetry;
    }

    port def CommandInPort {
        in item command : ControlCommand;
    }

    port def CommandOutPort {
        out item command : ControlCommand;
    }

    port def FaultOutPort {
        out item fault : FaultReport;
    }

    port def FaultInPort {
        in item fault : FaultReport;
    }

    interface def PowerTransfer {
        end source : DCPowerSourcePort;
        end sink : DCPowerSinkPort;
    }

    interface def TelemetryTransfer {
        end transmitter : TelemetryOutPort;
        end receiver : TelemetryInPort;
    }

    interface def CommandTransfer {
        end controller : CommandOutPort;
        end actuator : CommandInPort;
    }

    interface def FaultTransfer {
        end detector : FaultOutPort;
        end manager : FaultInPort;
    }

    part def PhotovoltaicArray {
        port dcOut : DCPowerSourcePort;
        port telemetryOut : TelemetryOutPort;

        attribute ratedPower : Watt = 1200;
        attribute maximumVoltage : Volt = 120;
        attribute conversionEfficiency : Percent = 22;
        attribute panelTemperature : Celsius;

        action generatePower {
            in ambientLight : Lux;
            in panelTemperature : Celsius;
            out producedPower : DCPower;
        }
    }

    part def EnergyStorageBattery {
        port dcBus : BidirectionalDCPowerPort;
        port telemetryOut : TelemetryOutPort;
        port commandIn : CommandInPort;
        port faultOut : FaultOutPort;

        attribute capacity : WattHour = 4800;
        attribute nominalVoltage : Volt = 48;
        attribute stateOfCharge : Percent;
        attribute minimumReserve : Percent = 20;
        attribute maximumChargeCurrent : Ampere = 60;
        attribute maximumDischargeCurrent : Ampere = 80;
        attribute health : HealthState;

        action charge {
            in chargingPower : DCPower;
            out storedEnergy : ElectricalEnergy;
        }

        action discharge {
            in requestedPower : Watt;
            out suppliedPower : DCPower;
        }

        action isolateOnFault {
            in fault : FaultReport;
            out isolated : Boolean;
        }
    }

    part def PowerConditioningUnit {
        port sourceIn : DCPowerSinkPort;
        port storagePort : BidirectionalDCPowerPort;
        port regulatedOut : DCPowerSourcePort;
        port commandIn : CommandInPort;
        port telemetryOut : TelemetryOutPort;
        port faultOut : FaultOutPort;

        attribute inputVoltageRangeLow : Volt = 24;
        attribute inputVoltageRangeHigh : Volt = 150;
        attribute regulatedBusVoltage : Volt = 48;
        attribute peakOutputPower : Watt = 3000;
        attribute conversionEfficiency : Percent = 94;
        attribute health : HealthState;

        action regulateBus {
            in sourcePower : DCPower;
            in storagePower : DCPower;
            out regulatedPower : DCPower;
        }

        action disconnectUnsafeInput {
            in busVoltage : Volt;
            out disconnected : Boolean;
        }
    }

    part def LoadDistributionUnit {
        port busIn : DCPowerSinkPort;
        port criticalLoadOut : DCPowerSourcePort;
        port missionLoadOut : DCPowerSourcePort;
        port auxiliaryLoadOut : DCPowerSourcePort;
        port commandIn : CommandInPort;
        port telemetryOut : TelemetryOutPort;

        attribute criticalLoadLimit : Watt = 900;
        attribute missionLoadLimit : Watt = 1200;
        attribute auxiliaryLoadLimit : Watt = 600;
        attribute sheddingThreshold : Percent = 25;

        action distributePower {
            in availablePower : DCPower;
            out criticalPower : DCPower;
            out missionPower : DCPower;
            out auxiliaryPower : DCPower;
        }

        action shedNonCriticalLoads {
            in batteryStateOfCharge : Percent;
            out sheddingEnabled : Boolean;
        }
    }

    part def SensorSuite {
        port telemetryOut : TelemetryOutPort;
        port faultOut : FaultOutPort;

        attribute measuredLight : Lux;
        attribute measuredTemperature : Celsius;
        attribute measuredBusVoltage : Volt;
        attribute measuredLoadCurrent : Ampere;
        attribute samplePeriod : Second = 1;

        action sampleEnvironment {
            out ambientLight : Lux;
            out cabinetTemperature : Celsius;
        }

        action sampleElectricalBus {
            out busVoltage : Volt;
            out loadCurrent : Ampere;
        }

        action detectFault {
            in telemetry : SensorTelemetry;
            out fault : FaultReport;
        }
    }

    part def SupervisoryController {
        port telemetryIn : TelemetryInPort;
        port faultIn : FaultInPort;
        port commandOut : CommandOutPort;

        attribute activeMode : PowerMode;
        attribute primaryFunction : String = "Integrate sensing, energy harvesting, storage, power conditioning, and load distribution to provide reliable regulated DC power to critical and mission loads.";
        attribute emergencyReserve : Percent = 20;
        attribute degradedReserve : Percent = 35;

        action evaluateEnergyState {
            in telemetry : SensorTelemetry;
            out command : ControlCommand;
        }

        action handleFault {
            in fault : FaultReport;
            out isolationCommand : ControlCommand;
        }

        state operatingState {
            entry; then initializing;

            state initializing;
            state standby;
            state harvesting;
            state normalSupply;
            state degradedSupply;
            state emergencySupply;
            state faultIsolated;
            state shutdown;

            transition initializing_to_standby
                first initializing
                then standby;

            transition standby_to_harvesting
                first standby
                accept ControlCommand
                if command.requestedMode == PowerMode::harvesting
                then harvesting;

            transition harvesting_to_normal
                first harvesting
                accept SensorTelemetry
                if telemetry.batteryStateOfCharge >= 60
                then normalSupply;

            transition normal_to_degraded
                first normalSupply
                accept SensorTelemetry
                if telemetry.batteryStateOfCharge < degradedReserve
                then degradedSupply;

            transition degraded_to_emergency
                first degradedSupply
                accept SensorTelemetry
                if telemetry.batteryStateOfCharge <= emergencyReserve
                then emergencySupply;

            transition any_to_faultIsolated
                first normalSupply
                accept FaultReport
                if fault.isolationRequired
                then faultIsolated;

            transition fault_to_shutdown
                first faultIsolated
                accept ControlCommand
                if command.requestedMode == PowerMode::off
                then shutdown;
        }
    }

    part def CriticalLoad {
        port powerIn : DCPowerSinkPort;
        attribute requiredPower : Watt = 750;
        attribute minimumVoltage : Volt = 44;
        attribute maximumVoltage : Volt = 52;
    }

    part def MissionLoad {
        port powerIn : DCPowerSinkPort;
        attribute nominalPower : Watt = 1000;
        attribute shedAllowed : Boolean = true;
    }

    part def AuxiliaryLoad {
        port powerIn : DCPowerSinkPort;
        attribute nominalPower : Watt = 400;
        attribute shedAllowed : Boolean = true;
    }

    part def SSIES {
        port externalServicePower : DCPowerSourcePort;
        port primaryPowerOutput : DCPowerSourcePort;
        port operatorCommand : CommandInPort;
        port systemTelemetry : TelemetryOutPort;

        part solarArray : PhotovoltaicArray;
        part battery : EnergyStorageBattery;
        part pcu : PowerConditioningUnit;
        part distribution : LoadDistributionUnit;
        part sensors : SensorSuite;
        part controller : SupervisoryController;
        part criticalLoad : CriticalLoad;
        part missionLoad : MissionLoad;
        part auxiliaryLoad : AuxiliaryLoad;

        attribute systemMode : PowerMode;
        attribute regulatedBusVoltage : Volt = 48;
        attribute maximumContinuousOutput : Watt = 2500;
        attribute minimumAutonomyAtCriticalLoad : WattHour = 1800;

        connection solar_to_pcu : PowerTransfer
            connect solarArray.dcOut to pcu.sourceIn;

        connection battery_to_pcu
            connect battery.dcBus to pcu.storagePort;

        connection pcu_to_distribution : PowerTransfer
            connect pcu.regulatedOut to distribution.busIn;

        connection distribution_to_critical : PowerTransfer
            connect distribution.criticalLoadOut to criticalLoad.powerIn;

        connection distribution_to_mission : PowerTransfer
            connect distribution.missionLoadOut to missionLoad.powerIn;

        connection distribution_to_auxiliary : PowerTransfer
            connect distribution.auxiliaryLoadOut to auxiliaryLoad.powerIn;

        connection sensor_telemetry_to_controller : TelemetryTransfer
            connect sensors.telemetryOut to controller.telemetryIn;

        connection solar_telemetry_to_controller : TelemetryTransfer
            connect solarArray.telemetryOut to controller.telemetryIn;

        connection battery_telemetry_to_controller : TelemetryTransfer
            connect battery.telemetryOut to controller.telemetryIn;

        connection pcu_telemetry_to_controller : TelemetryTransfer
            connect pcu.telemetryOut to controller.telemetryIn;

        connection distribution_telemetry_to_controller : TelemetryTransfer
            connect distribution.telemetryOut to controller.telemetryIn;

        connection controller_to_battery : CommandTransfer
            connect controller.commandOut to battery.commandIn;

        connection controller_to_pcu : CommandTransfer
            connect controller.commandOut to pcu.commandIn;

        connection controller_to_distribution : CommandTransfer
            connect controller.commandOut to distribution.commandIn;

        connection sensor_fault_to_controller : FaultTransfer
            connect sensors.faultOut to controller.faultIn;

        connection battery_fault_to_controller : FaultTransfer
            connect battery.faultOut to controller.faultIn;

        connection pcu_fault_to_controller : FaultTransfer
            connect pcu.faultOut to controller.faultIn;

        action performPrimaryFunction {
            in ambientLight : Lux;
            in loadDemand : Watt;
            out suppliedPower : DCPower;
            out telemetry : SensorTelemetry;

            first start;
            then collectTelemetry;
            then decideMode;
            then harvestOrDischarge;
            then regulatePower;
            then distributeToLoads;
            then reportStatus;

            action collectTelemetry {
                out telemetry : SensorTelemetry;
            }

            action decideMode {
                in telemetry : SensorTelemetry;
                out command : ControlCommand;
            }

            action harvestOrDischarge {
                in command : ControlCommand;
                out availablePower : DCPower;
            }

            action regulatePower {
                in availablePower : DCPower;
                out regulatedPower : DCPower;
            }

            action distributeToLoads {
                in regulatedPower : DCPower;
                out suppliedPower : DCPower;
            }

            action reportStatus {
                in telemetry : SensorTelemetry;
            }
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject ssies : SSIES;

        doc /* The SSIES shall provide a high-level integrated energy service by sensing operating conditions, harvesting available source energy, storing reserve energy, conditioning power, protecting against faults, and distributing regulated DC power to critical and mission loads. */

        require constraint {
            ssies.regulatedBusVoltage.value == 48.0
        }
    }

    requirement def CriticalLoadContinuityRequirement {
        subject ssies : SSIES;

        doc /* The SSIES shall maintain power to the critical load during normal, degraded, and emergency supply modes. */

        require constraint {
            ssies.criticalLoad.requiredPower.value <= 900.0
        }
    }

    requirement def EnergyReserveRequirement {
        subject ssies : SSIES;

        doc /* The SSIES shall preserve an emergency battery reserve for critical-load operation. */

        require constraint {
            ssies.battery.minimumReserve.value >= 20.0
        }
    }

    requirement def RegulatedBusRequirement {
        subject ssies : SSIES;

        doc /* The SSIES shall regulate its DC distribution bus within the acceptable input range of attached critical loads. */

        require constraint {
            ssies.regulatedBusVoltage.value >= ssies.criticalLoad.minimumVoltage.value and
            ssies.regulatedBusVoltage.value <= ssies.criticalLoad.maximumVoltage.value
        }
    }

    requirement def FaultIsolationRequirement {
        subject ssies : SSIES;

        doc /* The SSIES shall isolate failed energy storage or power conditioning elements when a fault report indicates isolation is required. */

        require constraint {
            ssies.battery.health != HealthState::failed or
            ssies.controller.activeMode == PowerMode::faultIsolated
        }
    }

    requirement def LoadSheddingRequirement {
        subject ssies : SSIES;

        doc /* The SSIES shall shed auxiliary and mission loads before interrupting critical loads when battery reserve is low. */

        require constraint {
            ssies.distribution.sheddingThreshold.value > ssies.battery.minimumReserve.value
        }
    }

    part ssiesSystem : SSIES;

    satisfy PrimaryFunctionRequirement by ssiesSystem;
    satisfy CriticalLoadContinuityRequirement by ssiesSystem;
    satisfy EnergyReserveRequirement by ssiesSystem;
    satisfy RegulatedBusRequirement by ssiesSystem;
    satisfy FaultIsolationRequirement by ssiesSystem;
    satisfy LoadSheddingRequirement by ssiesSystem;
}
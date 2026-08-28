package MicrogridEnergyManagementSystem {
    import ScalarValues::*;

    attribute def PowerKW :> Real;
    attribute def EnergyKWh :> Real;
    attribute def SOC :> Real;
    attribute def PricePerKWh :> Real;

    item def ElectricPower {
        attribute power : PowerKW;
        attribute voltage : Real;
    }

    item def Telemetry {
        attribute solarPower : PowerKW;
        attribute windPower : PowerKW;
        attribute batterySOC : SOC;
        attribute gridStatus : String;
        attribute totalLoad : PowerKW;
        attribute criticalLoad : PowerKW;
    }

    item def ControlCommand {
        attribute target : String;
        attribute action : String;
        attribute value : Real;
    }

    port def PowerOutPort {
        out power : ElectricPower;
    }

    port def PowerInPort {
        in power : ElectricPower;
    }

    port def BiDirPowerPort {
        in powerIn : ElectricPower;
        out powerOut : ElectricPower;
    }

    port def TelemetryOutPort {
        out telemetry : Telemetry;
    }

    port def TelemetryInPort {
        in telemetry : Telemetry;
    }

    port def ControlOutPort {
        out command : ControlCommand;
    }

    port def ControlInPort {
        in command : ControlCommand;
    }

    part def SolarArray {
        attribute maxOutput : PowerKW = 50;
        attribute currentOutput : PowerKW;
        port powerOut : PowerOutPort;
    }

    part def WindTurbine {
        attribute maxOutput : PowerKW = 30;
        attribute currentOutput : PowerKW;
        port powerOut : PowerOutPort;
    }

    part def GridConnection {
        attribute maxImport : PowerKW = 100;
        attribute maxExport : PowerKW = 100;
        attribute currentPrice : PricePerKWh;
        port gridPort : BiDirPowerPort;
    }

    part def BatteryStorage {
        attribute capacity : EnergyKWh = 200;
        attribute maxChargeRate : PowerKW = 20;
        attribute maxDischargeRate : PowerKW = 20;
        attribute soc : SOC;
        attribute currentCommand : ControlCommand;
        port powerPort : BiDirPowerPort;
        port controlPort : ControlInPort;

        action ReceiveCommand {
            // updates currentCommand from controlPort
        }
        perform ReceiveCommand;

        state def BatteryStates {
            initial -> Idle;
            state Idle;
            state Charging;
            state Discharging;
            transition from Idle to Charging when currentCommand.action == "charge";
            transition from Idle to Discharging when currentCommand.action == "discharge";
            transition from Charging to Idle when currentCommand.action == "idle";
            transition from Discharging to Idle when currentCommand.action == "idle";
        }
        perform BatteryStates;
    }

    part def LoadController {
        attribute criticalLoad : PowerKW = 20;
        attribute deferrableLoad : PowerKW = 40;
        attribute totalLoad : PowerKW = 60;
        attribute currentCommand : ControlCommand;
        port powerIn : PowerInPort;
        port controlIn : ControlInPort;
        
        action ReceiveCommand {
            // updates currentCommand from controlIn
        }
        perform ReceiveCommand;

        state def LoadStates {
            initial -> Normal;
            state Normal {
                entry { deferrableLoad = 40; }
            }
            state Shedding {
                entry { deferrableLoad = 10; }
            }
            transition from Normal to Shedding when currentCommand.action == "shed";
            transition from Shedding to Normal when currentCommand.action == "restore";
        }
        perform LoadStates;
    }

    part def PowerDistributionUnit {
        port solarIn : PowerInPort;
        port windIn : PowerInPort;
        port gridPort : BiDirPowerPort;
        port batteryPort : BiDirPowerPort;
        port loadOut : PowerOutPort;
        port telemetryOut : TelemetryOutPort;
        port controlIn : ControlInPort;
        
        attribute totalDistributed : PowerKW;
        
        action RoutePower;
        perform RoutePower;
    }

    part def EnergyMonitor {
        port telemetryIn : TelemetryInPort;
        port telemetryOut : TelemetryOutPort;
        attribute totalGeneration : PowerKW;
        attribute totalConsumption : PowerKW;
        attribute storageLevel : SOC;
        
        action MonitorFlows;
        perform MonitorFlows;
    }

    part def EnergyOptimizer {
        port telemetryIn : TelemetryInPort;
        port controlOut : ControlOutPort;
        
        attribute currentMode : String = "Standby";
        attribute currentTelemetry : Telemetry;
        attribute currentCommand : ControlCommand;
        attribute gridPrice : PricePerKWh;

        action ReceiveTelemetry {
            // updates currentTelemetry from telemetryIn
        }
        perform ReceiveTelemetry;

        state def OptimizationState {
            initial -> Standby;
            state Standby {
                entry { 
                    currentMode = "Standby";
                    // Minimizes own consumption while remaining ready
                }
            }
            state Economy {
                entry { 
                    currentMode = "Economy";
                    // Maximizes renewable use and charges battery, avoids grid power
                }
            }
            state Normal {
                entry { 
                    currentMode = "Normal";
                    // Balances efficiency and cost using renewables and storage
                }
            }
            state Peak {
                entry { 
                    currentMode = "Peak";
                    // Uses all available sources to meet high demand
                }
            }
            transition from Standby to Economy when currentTelemetry.totalLoad > 10;
            transition from Economy to Normal when currentTelemetry.totalLoad > 50;
            transition from Normal to Peak when currentTelemetry.totalLoad > 80;
            transition from Peak to Normal when currentTelemetry.totalLoad < 70;
            transition from Normal to Economy when currentTelemetry.totalLoad < 40;
            transition from Economy to Standby when currentTelemetry.totalLoad < 5;
        }
        perform OptimizationState;
    }

    part def MicrogridSystem {
        part solarArray : SolarArray;
        part windTurbine : WindTurbine;
        part gridConnection : GridConnection;
        part batteryStorage : BatteryStorage;
        part loadController : LoadController;
        part powerDistributionUnit : PowerDistributionUnit;
        part energyMonitor : EnergyMonitor;
        part energyOptimizer : EnergyOptimizer;

        connect solarArray.powerOut to powerDistributionUnit.solarIn;
        connect windTurbine.powerOut to powerDistributionUnit.windIn;
        connect gridConnection.gridPort to powerDistributionUnit.gridPort;
        connect batteryStorage.powerPort to powerDistributionUnit.batteryPort;
        connect powerDistributionUnit.loadOut to loadController.powerIn;
        connect powerDistributionUnit.telemetryOut to energyMonitor.telemetryIn;
        connect energyMonitor.telemetryOut to energyOptimizer.telemetryIn;
        connect energyOptimizer.controlOut to powerDistributionUnit.controlIn;
        connect energyOptimizer.controlOut to batteryStorage.controlPort;
        connect energyOptimizer.controlOut to loadController.controlIn;
    }

    requirement def OptimizeEnergyReq {
        subject system : MicrogridSystem;
        doc /* The system shall optimize generation, storage, and consumption */
    }

    requirement def EnsureReliabilityReq {
        subject system : MicrogridSystem;
        doc /* The system shall ensure power reliability by intelligently managing sources */
    }

    requirement def ReduceCostsReq {
        subject system : MicrogridSystem;
        doc /* The system shall reduce operational costs by prioritizing renewables and battery */
    }
}

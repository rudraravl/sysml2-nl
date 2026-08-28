package MarinePumpingSubsystemModel {

    // Units
    unit m3;
    unit m3_per_s;
    unit Pa;
    unit s;
    unit rpm;
    unit V;
    unit A;
    unit m;
    unit h;

    // Value Types
    value type Volume { unit m3; }
    value type FlowRate { unit m3_per_s; }
    value type Pressure { unit Pa; }
    value type Time { unit s; }
    value type RotationalSpeed { unit rpm; }
    value type Voltage { unit V; }
    value type Current { unit A; }
    value type Length { unit m; }
    value type Hours { unit h; }

    // Items
    item Seawater;

    // Ports
    port def FluidPort {
        in item seawater: Seawater;
        attribute pressure: Pressure;
        attribute flowRate: FlowRate;
    }

    port def ElectricPort {
        attribute voltage: Voltage;
        attribute current: Current;
    }

    port def CommandPort {
        out attribute speedCommand: RotationalSpeed;
        out attribute mode: String;
    }

    // Parts
    part def SuctionTank {
        port out fluidOut: FluidPort;
        attribute capacity: Volume = 10 [m3];
        attribute storedVolume: Volume;
    }

    part def SuctionStrainer {
        port in fluidIn: FluidPort;
        port out fluidOut: FluidPort;
        attribute meshSize: Length = 0.001 [m];
    }

    part def DischargeCheckValve {
        port in fluidIn: FluidPort;
        port out fluidOut: FluidPort;
        attribute crackingPressure: Pressure = 1e4 [Pa];
    }

    part def DischargeManifold {
        port in fluidIn: FluidPort;
        attribute distributionPressure: Pressure;
    }

    part def ElectricalPowerSupply {
        port out powerOut: ElectricPort;
        attribute supplyVoltage: Voltage = 440 [V];
        attribute supplyCurrent: Current = 100 [A];
    }

    part def PumpController {
        port out commandOut: CommandPort;
        attribute operatingMode: String; // "Manual" or "Auto"
    }

    part def MarinePump {
        port in fluidIn: FluidPort;
        port out fluidOut: FluidPort;
        port in powerIn: ElectricPort;
        port in commandIn: CommandPort;

        attribute currentSpeed: RotationalSpeed;
        attribute dischargePressure: Pressure;
        attribute suctionPressure: Pressure;

        attribute maxDischargePressure: Pressure = 5e6 [Pa];
        attribute minSuctionPressure: Pressure = 5e4 [Pa];
        attribute primingTime: Time = 30 [s];

        state PumpStateMachine {
            state Stopped {
                entry action { currentSpeed = 0 [rpm]; }
            }
            state Priming {
                entry action { currentSpeed = 500 [rpm]; }
            }
            state Running {
                entry action { currentSpeed = commandIn.speedCommand; }
            }
            state Faulted {
                entry action { currentSpeed = 0 [rpm]; }
            }

            transition from Stopped to Priming
                when commandIn.speedCommand > 0 [rpm];

            transition from Priming to Running
                after primingTime;

            transition from Running to Faulted
                when dischargePressure > maxDischargePressure or suctionPressure < minSuctionPressure;

            transition from Running to Stopped
                when commandIn.speedCommand == 0 [rpm];

            transition from Faulted to Stopped
                when commandIn.speedCommand == 0 [rpm];
        }
    }

    // Top-level Subsystem
    part def MarinePumpingSubsystem {
        part suctionTank: SuctionTank;
        part suctionStrainer: SuctionStrainer;
        part marinePump: MarinePump;
        part dischargeCheckValve: DischargeCheckValve;
        part dischargeManifold: DischargeManifold;
        part electricalPowerSupply: ElectricalPowerSupply;
        part pumpController: PumpController;

        attribute maintenanceInterval: Hours = 2000 [h];

        // Connections
        connection suctionTank.fluidOut to suctionStrainer.fluidIn;
        connection suctionStrainer.fluidOut to marinePump.fluidIn;
        connection marinePump.fluidOut to dischargeCheckValve.fluidIn;
        connection dischargeCheckValve.fluidOut to dischargeManifold.fluidIn;

        connection electricalPowerSupply.powerOut to marinePump.powerIn;
        connection pumpController.commandOut to marinePump.commandIn;
    }

    // Requirements
    requirement def FlowRateRequirement {
        subject subsystem: MarinePumpingSubsystem;
        attribute requiredFlowRate: FlowRate = 0.1 [m3_per_s];
        objective: subsystem.marinePump.fluidOut.flowRate >= requiredFlowRate;
    }

    requirement def DischargePressureRequirement {
        subject subsystem: MarinePumpingSubsystem;
        attribute requiredPressure: Pressure = 3e5 [Pa];
        objective: subsystem.marinePump.fluidOut.pressure >= requiredPressure;
    }

    requirement def UptimeRequirement {
        subject subsystem: MarinePumpingSubsystem;
        attribute requiredUptime: Hours = 2000 [h];
        objective: subsystem.maintenanceInterval >= requiredUptime;
    }
}

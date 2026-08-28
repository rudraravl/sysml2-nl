package PersonalCoolingVestSystem {
    attribute def Temperature :> Real { unit = "degC"; }
    attribute def Power :> Real { unit = "W"; }
    attribute def FlowRate :> Real { unit = "L/min"; }
    attribute def Current :> Real { unit = "A"; }
    attribute def Voltage :> Real { unit = "V"; }
    attribute def Energy :> Real { unit = "Wh"; }

    item def CoolingFluid {
        attribute temperature : Temperature;
        attribute flowRate : FlowRate;
    }
    item def ElectricalEnergy {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    item def Heat {
        attribute rate : Power;
    }
    item def TempSignal {
        attribute value : Temperature;
    }
    item def Command {
        attribute activate : Boolean;
    }

    part def Wearer {
        attribute bodyTemp : Temperature = 37.0;
        port out sensorHeatOut : Heat;
        port out vestHeatOut : Heat;
        action generateHeat {
            out sensorHeat : Heat;
            out vestHeat : Heat;
        }
    }

    part def AmbientAir {
        port in heatIn : Heat;
    }

    part def TemperatureSensor {
        port in heatIn : Heat;
        port out tempOut : TempSignal;
        port in powerIn : ElectricalEnergy;
        action senseTemperature {
            in bodyHeat : Heat;
            in power : ElectricalEnergy;
            out temp : TempSignal;
        }
    }

    part def ControlUnit {
        port in tempIn : TempSignal;
        port out pumpCmd : Command;
        port out tecCmd : Command;
        port in powerIn : ElectricalEnergy;

        attribute targetTemp : Temperature = 37.0;

        state controllerBehavior {
            state Off;
            state Monitoring {
                do { pumpCmd.activate = false; tecCmd.activate = false; }
            }
            state Active {
                do { pumpCmd.activate = true; tecCmd.activate = true; }
            }
            transition init to Off;
            transition powerOn from Off to Monitoring when powerIn.voltage > 0;
            transition warmDetected from Monitoring to Active when tempIn.value > targetTemp;
            transition coolEnough from Active to Monitoring when tempIn.value <= targetTemp;
        }
    }

    part def FluidPump {
        port in fluidIn : CoolingFluid;
        port out fluidOut : CoolingFluid;
        port in cmdIn : Command;
        port in powerIn : ElectricalEnergy;
        action pumpFluid {
            in fluid : CoolingFluid;
            in cmd : Command;
            in power : ElectricalEnergy;
            out pumpedFluid : CoolingFluid;
        }
    }

    part def ThermoelectricCooler {
        port in fluidIn : CoolingFluid;
        port out fluidOut : CoolingFluid;
        port out heatOut : Heat;
        port in cmdIn : Command;
        port in powerIn : ElectricalEnergy;
        action coolFluid {
            in warmFluid : CoolingFluid;
            in power : ElectricalEnergy;
            in cmd : Command;
            out chilledFluid : CoolingFluid;
            out wasteHeat : Heat;
        }
    }

    part def Reservoir {
        port in fluidReturn : CoolingFluid;
        port out fluidSupply : CoolingFluid;
    }

    part def VestGarment {
        port in fluidIn : CoolingFluid;
        port out fluidOut : CoolingFluid;
        port in skinHeatIn : Heat;
        part thermalDistributionNetwork {
            attribute channelCount : Integer = 50;
        }
        action absorbHeat {
            in chilledFluid : CoolingFluid;
            in bodyHeat : Heat;
            out warmedFluid : CoolingFluid;
        }
    }

    part def BatteryPack {
        port out powerOut : ElectricalEnergy;
        attribute capacity : Energy = 100;
        attribute voltage : Voltage = 12.0;
        attribute current : Current = 2.0;
        action discharge {
            out power : ElectricalEnergy;
        }
    }

    part def CoolingVestSystem {
        port in skinSensorHeatIn : Heat;
        port in vestHeatIn : Heat;
        port out wasteHeatOut : Heat;

        part battery : BatteryPack;
        part sensor : TemperatureSensor;
        part controller : ControlUnit;
        part pump : FluidPump;
        part cooler : ThermoelectricCooler;
        part reservoir : Reservoir;
        part garment : VestGarment;

        connection batteryToController connect battery.powerOut to controller.powerIn;
        connection batteryToSensor connect battery.powerOut to sensor.powerIn;
        connection batteryToPump connect battery.powerOut to pump.powerIn;
        connection batteryToCooler connect battery.powerOut to cooler.powerIn;

        connection skinSensorDelegation connect skinSensorHeatIn to sensor.heatIn;
        connection vestHeatDelegation connect vestHeatIn to garment.skinHeatIn;

        connection tempSignal connect sensor.tempOut to controller.tempIn;
        connection pumpControl connect controller.pumpCmd to pump.cmdIn;
        connection tecControl connect controller.tecCmd to cooler.cmdIn;

        connection fluidReservoirToPump connect reservoir.fluidSupply to pump.fluidIn;
        connection fluidPumpToCooler connect pump.fluidOut to cooler.fluidIn;
        connection fluidCoolerToVest connect cooler.fluidOut to garment.fluidIn;
        connection fluidVestToReservoir connect garment.fluidOut to reservoir.fluidReturn;

        connection wasteHeatDelegation connect cooler.heatOut to wasteHeatOut;
    }

    part def SystemContext {
        part vest : CoolingVestSystem;
        part wearer : Wearer;
        part ambient : AmbientAir;
        
        connection skinSensorThermal connect wearer.sensorHeatOut to vest.skinSensorHeatIn;
        connection skinVestThermal connect wearer.vestHeatOut to vest.vestHeatIn;
        connection wasteThermal connect vest.wasteHeatOut to ambient.heatIn;
    }

    package Requirements {
        requirement def MaintainBodyTemp {
            doc { The system shall maintain the wearer's body temperature within a safe and comfortable range. }
            attribute minTemp : Temperature = 36.0;
            attribute maxTemp : Temperature = 37.5;
            subject wearer : Wearer;
            constraint { wearer.bodyTemp >= minTemp and wearer.bodyTemp <= maxTemp }
        }
        requirement def SelfPowered {
            doc { The system shall be powered entirely by an internal rechargeable battery pack. }
            subject vest : CoolingVestSystem;
            constraint { vest.battery.capacity > 0 }
        }
        requirement def AutomaticRegulation {
            doc { The system shall automatically activate and deactivate cooling based on skin temperature. }
            subject vest : CoolingVestSystem;
            attribute targetTemp : Temperature = 37.0;
            constraint { vest.controller.targetTemp == targetTemp }
        }
    }
}

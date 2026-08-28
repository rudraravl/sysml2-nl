package HTSC_Magnet_System {
    import ISQ::*;
    import ScalarValues::*;

    value def Temperature :> Real { unit 'K'; }
    value def Current :> Real { unit 'A'; }
    value def Voltage :> Real { unit 'V'; }
    value def MagneticFluxDensity :> Real { unit 'T'; }
    value def MassFlowRate :> Real { unit 'kg/s'; }

    item def LiquidNitrogen;
    item def ElectricalEnergy;
    item def MagneticFlux;
    
    item def ControlSignal {
        attribute temperature : Temperature;
        attribute current : Current;
        attribute command : String;
    }

    port def ElectricalPort {
        out current : Current;
        in voltage : Voltage;
    }
    port def FluidPort {
        out liquidNitrogen : LiquidNitrogen;
        out flowRate : MassFlowRate;
    }
    port def MagneticPort {
        out magneticFlux : MagneticFlux;
        out fluxDensity : MagneticFluxDensity;
    }
    port def ControlPort {
        in signal : ControlSignal;
    }
    port def ThermalPort {
        out temperature : Temperature;
    }

    requirement def OperationalRequirements {
        subject magnetSystem : HTSCMagnetSystem;
        requirement generateField {
            doc /* The system shall generate a magnetic field of at least 5 T. */
            constraint { magnetSystem.coil.magneticOut.fluxDensity >= 5.0 }
        }
        requirement maintainCryogenicTemp {
            doc /* The system shall maintain the coil at 77 K. */
            constraint { magnetSystem.coil.thermalPort.temperature == 77.0 }
        }
        requirement supplyCurrent {
            doc /* The power supply shall provide 500 A. */
            constraint { magnetSystem.powerSupply.electricalOut.current == 500.0 }
        }
        requirement quenchProtection {
            doc /* The system shall detect quench and initiate emergency shutdown. */
        }
    }

    part def HTSCMagnetSystem {
        part coil : Coil;
        part coolingSystem : CoolingSystem;
        part powerSupply : PowerSupply;
        part shielding : MagneticShielding;
        part controlSystem : ControlSystem;

        port magneticPort : MagneticPort;
        port thermalPort : ThermalPort;

        connection coolingToCoil connect coolingSystem.fluidOut to coil.fluidIn;
        connection coilToCooling connect coil.fluidOut to coolingSystem.fluidIn;
        connection powerToCoil connect powerSupply.electricalOut to coil.electricalIn;
        connection coilToPower connect coil.electricalOut to powerSupply.electricalIn;
        connection coilToShielding connect coil.magneticOut to shielding.magneticIn;
        connection shieldingToExternal connect shielding.magneticOut to magneticPort;
        connection coilToThermalPort connect coil.thermalPort to thermalPort;
        
        connection controlToCooling connect controlSystem.controlOut to coolingSystem.controlIn;
        connection controlToPower connect controlSystem.controlOut to powerSupply.controlIn;
        connection coolingToControl connect coolingSystem.sensorOut to controlSystem.sensorIn;
        connection coilToControl connect coil.sensorOut to controlSystem.sensorIn;
        connection powerToControl connect powerSupply.sensorOut to controlSystem.sensorIn;

        satisfy OperationalRequirements by magnetSystem;
    }

    part def Coil {
        attribute material : String = "YBCO";
        attribute criticalTemp : Temperature = 90.0;
        
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port electricalIn : ElectricalPort;
        port electricalOut : ElectricalPort;
        port magneticOut : MagneticPort;
        port sensorOut : ControlPort;
        port thermalPort : ThermalPort;

        attribute currentTemp : Temperature;
        attribute currentCurrent : Current;
        attribute isSuperconducting : Boolean;

        state def CoilBehavior {
            entry; then Normal;
            state Normal;
            state Quenching;
            transition normalToQuench
                from Normal to Quenching
                when currentTemp > criticalTemp;
        }
    }

    part def CoolingSystem {
        part reservoir : LiquidNitrogenReservoir;
        part cryocooler : Cryocooler;
        part tempSensor : TemperatureSensor;
        part flowController : FlowController;

        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port controlIn : ControlPort;
        port sensorOut : ControlPort;

        connection reservoirToCryocooler connect reservoir.fluidOut to cryocooler.fluidIn;
        connection cryocoolerToFlowController connect cryocooler.fluidOut to flowController.fluidIn;
        connection flowControllerToFluidOut connect flowController.fluidOut to fluidOut;
        connection fluidInToReservoir connect fluidIn to reservoir.fluidIn;
        connection tempSensorToSensorOut connect tempSensor.signalOut to sensorOut;
    }

    part def LiquidNitrogenReservoir {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        attribute capacity : Real = 100.0;
    }

    part def Cryocooler {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        attribute coolingPower : Real = 500.0;
    }

    part def TemperatureSensor {
        port signalOut : ControlPort;
        attribute measuredTemp : Temperature;
    }

    part def FlowController {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port controlIn : ControlPort;
        attribute flowRate : MassFlowRate;
    }

    part def PowerSupply {
        port electricalOut : ElectricalPort;
        port electricalIn : ElectricalPort;
        port controlIn : ControlPort;
        port sensorOut : ControlPort;
        attribute outputCurrent : Current = 500.0;
        attribute outputVoltage : Voltage;
    }

    part def MagneticShielding {
        port magneticIn : MagneticPort;
        port magneticOut : MagneticPort;
        attribute shieldingFactor : Real = 0.99;
    }

    part def ControlSystem {
        port sensorIn : ControlPort;
        port controlOut : ControlPort;
        
        attribute quenchDetected : Boolean = false;

        state def ControlStateMachine {
            entry; then CoolDown;
            state CoolDown {
                entry /* send command to cooling system */;
                do /* monitor temperature */;
            }
            state ActiveSuperconducting {
                entry /* enable power supply */;
                do /* monitor current and temperature */;
            }
            state ControlledShutdown {
                entry /* ramp down power supply */;
                do /* maintain cooling */;
            }
            state QuenchManagement {
                entry /* trigger safety interlock */;
                do /* emergency shutdown */;
            }

            transition coolDownToActive
                from CoolDown to ActiveSuperconducting
                when sensorIn.signal.temperature <= 77.0;
            transition activeToShutdown
                from ActiveSuperconducting to ControlledShutdown
                when sensorIn.signal.command == "shutdown";
            transition activeToQuench
                from ActiveSuperconducting to QuenchManagement
                when quenchDetected;
            transition shutdownToOff
                from ControlledShutdown to Off
                when sensorIn.signal.current == 0.0;
            state Off;
        }
    }
}

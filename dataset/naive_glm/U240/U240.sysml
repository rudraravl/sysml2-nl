package HEALS_System {
    import ISQ::*;
    import ScalarValues::*;

    // Value Types
    def attribute def Voltage :>> Real { unit = 'V'; }
    def attribute def Current :>> Real { unit = 'A'; }
    def attribute def Temperature :>> Real { unit = 'K'; }
    def attribute def Wavelength :>> Real { unit = 'nm'; }
    def attribute def LuminousFlux :>> Real { unit = 'lm'; }
    def attribute def HeatFlow :>> Real { unit = 'W'; }
    def attribute def Concentration :>> Real { unit = '%'; }

    // Items
    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    item def OpticalRadiation {
        attribute wavelength : Wavelength = 550;
        attribute flux : LuminousFlux;
    }
    item def Coolant;
    item def WasteHeat {
        attribute heatFlow : HeatFlow;
    }

    // Ports
    port def ElectricalPowerPort {
        out power : ElectricalPower;
    }
    port def OpticalPort {
        out radiation : OpticalRadiation;
    }
    port def ThermalPort {
        out heat : WasteHeat;
    }
    port def CoolantPort {
        in coolantIn : Coolant;
        out coolantOut : Coolant;
    }

    // Requirements
    requirement def HEALSRequirements {
        doc /* Requirements for the HEALS system. */
        requirement GreenLightEmission {
            doc /* The system shall emit light peaking at 550 nm. */
            constraint { radiation.wavelength == 550 }
        }
        requirement ThermalManagement {
            doc /* The system shall maintain safe operating temperature. */
            constraint { temperature <= 350.0 }
        }
    }

    // Parts
    part def LuminescentPhosphorLayer {
        attribute matrix : String = "Yttrium Aluminum Garnet";
        attribute aluminumConcentration : Concentration = 5.0;
        attribute phosphorConcentration : Concentration = 2.0;
        port electricalIn : ~ElectricalPowerPort;
        port opticalOut : OpticalPort;
        port thermalOut : ThermalPort;
        
        action def EmitLight {
            in power : ElectricalPower;
            out radiation : OpticalRadiation;
            out heat : WasteHeat;
        }
    }

    part def AluminumReflectorLayer {
        attribute emissivity : Real = 0.9;
        port opticalIn : ~OpticalPort;
        port opticalOut : OpticalPort;
        port thermalIn : ~ThermalPort;
        port thermalOut : ThermalPort;
        
        action def ReflectAndSpread {
            in radiation : OpticalRadiation;
            out reflectedRadiation : OpticalRadiation;
            out heat : WasteHeat;
        }
    }

    part def EncapsulationLayer {
        attribute material : String = "Silicone Composite";
        port opticalIn : ~OpticalPort;
        port opticalOut : OpticalPort;
    }

    part def PowerSupplyUnit {
        attribute outputVoltage : Voltage = 12.0;
        attribute outputCurrent : Current = 5.0;
        port electricalOut : ElectricalPowerPort;
        
        action def RegulatePower {
            out power : ElectricalPower;
        }
    }

    part def ThermalManagementSubsystem {
        part heatSink;
        port thermalIn : ~ThermalPort;
        port coolantPort : CoolantPort;
        
        action def ManageHeat {
            in heat : WasteHeat;
            in coolantIn : Coolant;
            out coolantOut : Coolant;
        }
    }

    // System
    part def HEALSSystem {
        port opticalOutput : OpticalPort;
        port coolantInterface : CoolantPort;
        
        attribute temperature : Temperature = 298.0;
        
        part powerSupply : PowerSupplyUnit;
        part phosphorLayer : LuminescentPhosphorLayer;
        part reflectorLayer : AluminumReflectorLayer;
        part encapsulationLayer : EncapsulationLayer;
        part thermalSubsystem : ThermalManagementSubsystem;
        
        connection electricalConnection1 connect powerSupply.electricalOut to phosphorLayer.electricalIn;
        connection opticalConnection1 connect phosphorLayer.opticalOut to reflectorLayer.opticalIn;
        connection opticalConnection2 connect reflectorLayer.opticalOut to encapsulationLayer.opticalIn;
        connection opticalConnection3 connect encapsulationLayer.opticalOut to opticalOutput;
        
        connection thermalConnection1 connect phosphorLayer.thermalOut to reflectorLayer.thermalIn;
        connection thermalConnection2 connect reflectorLayer.thermalOut to thermalSubsystem.thermalIn;
        
        // State Machine
        state def HEALSStateMachine {
            state standby;
            state warmup;
            state active;
            state overtemperature;
            state cooldown;
            
            transition standby_to_warmup from standby to warmup when (powerSupply.outputVoltage > 0);
            transition warmup_to_active from warmup to active when (temperature > 290.0);
            transition active_to_overtemp from active to overtemperature when (temperature > 350.0);
            transition overtemp_to_active from overtemperature to active when (temperature < 330.0);
            transition active_to_cooldown from active to cooldown when (powerSupply.outputVoltage == 0);
            transition cooldown_to_standby from cooldown to standby when (temperature < 300.0);
        }
        
        behavior stateMachine : HEALSStateMachine;
    }
}

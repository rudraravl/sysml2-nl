package CHP_Plant {
    import ScalarValues::*;
    
    // Value Types
    def PressureValue :> Real { unit 'Pa'; }
    def MassFlowRateValue :> Real { unit 'kg/s'; }
    def TemperatureValue :> Real { unit 'K'; }
    def TorqueValue :> Real { unit 'N*m'; }
    def RotationalSpeedValue :> Real { unit 'rad/s'; }
    def ElectricPowerValue :> Real { unit 'W'; }
    def ThermalPowerValue :> Real { unit 'W'; }
    def VoltageValue :> Real { unit 'V'; }
    def CurrentValue :> Real { unit 'A'; }
    
    // Items
    item NaturalGas;
    item Air;
    item CombustionGas;
    item ExhaustGas;
    item Water;
    item Steam;
    
    // Port Definitions
    port def FluidPort {
        out item flow;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute massFlowRate : MassFlowRateValue;
    }
    
    port def MechanicalPort {
        attribute torque : TorqueValue;
        attribute speed : RotationalSpeedValue;
    }
    
    port def ElectricalPort {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    port def ControlPort {
        out attribute command : ElectricPowerValue;
        in attribute feedback : ElectricPowerValue;
    }
    
    // Requirements
    requirement def CHPPlantRequirement {
        doc "The CHP plant shall efficiently convert chemical energy in natural gas into electrical power and thermal energy."
    }
    
    requirement def EfficiencyRequirement :> CHPPlantRequirement {
        doc "The overall efficiency of the CHP plant shall exceed 80%."
    }
    
    // Parts
    part def FuelSupplySystem {
        port out gasOut : FluidPort;
        port in controlIn : ControlPort;
        
        attribute fuelFlowRate : MassFlowRateValue;
        
        action def RegulatePressure { in gas; out regulatedGas; }
        action def ControlFlow { in command; out flowRate; }
    }
    
    part def AirIntakeSystem {
        port out airOut : FluidPort;
        port in controlIn : ControlPort;
        
        attribute airFlowRate : MassFlowRateValue;
        
        action def CompressAir { in air; out compressedAir; }
    }
    
    part def CombustionChamber {
        port in gasIn : FluidPort;
        port in airIn : FluidPort;
        port out exhaustOut : FluidPort;
        
        action def Combust { in fuel; in air; out combustionGas; }
    }
    
    part def GasTurbine {
        port in gasIn : FluidPort;
        port out exhaustOut : FluidPort;
        port out shaftOut : MechanicalPort;
        
        action def ExpandGas { in combustionGas; out exhaustGas; out mechanicalRotation; }
    }
    
    part def ElectricalGenerator {
        port in shaftIn : MechanicalPort;
        port out powerOut : ElectricalPort;
        
        action def GeneratePower { in mechanicalRotation; out electricalPower; }
    }
    
    part def HeatRecoveryUnit {
        port in exhaustIn : FluidPort;
        port in waterIn : FluidPort;
        port out steamOut : FluidPort;
        
        action def RecoverHeat { in exhaustGas; in water; out steam; out cooledExhaust; }
    }
    
    part def ControlSystem {
        port out fuelControl : ControlPort;
        port out airControl : ControlPort;
        port in powerDemand : ControlPort;
        port in powerFeedback : ElectricalPort;
        
        attribute currentDemand : ElectricPowerValue;
        
        state def ControlStates {
            entry; then Idle;
            
            state Idle;
            state Starting;
            state SteadyState;
            state IncreasingPower;
            state DecreasingPower;
            
            transition from Idle to Starting when powerDemand.command > 0;
            transition from Starting to SteadyState when fuelControl.feedback > 0;
            transition from SteadyState to IncreasingPower when powerDemand.command > (powerFeedback.voltage * powerFeedback.current);
            transition from SteadyState to DecreasingPower when powerDemand.command < (powerFeedback.voltage * powerFeedback.current);
            transition from IncreasingPower to SteadyState when powerDemand.command == (powerFeedback.voltage * powerFeedback.current);
            transition from DecreasingPower to SteadyState when powerDemand.command == (powerFeedback.voltage * powerFeedback.current);
        }
    }
    
    part def CHPSystem {
        part fuelSupply : FuelSupplySystem;
        part airIntake : AirIntakeSystem;
        part combustionChamber : CombustionChamber;
        part gasTurbine : GasTurbine;
        part electricalGenerator : ElectricalGenerator;
        part heatRecovery : HeatRecoveryUnit;
        part controlSystem : ControlSystem;
        
        // Connections
        connect fuelSupply.gasOut to combustionChamber.gasIn;
        connect airIntake.airOut to combustionChamber.airIn;
        connect combustionChamber.exhaustOut to gasTurbine.gasIn;
        connect gasTurbine.shaftOut to electricalGenerator.shaftIn;
        connect gasTurbine.exhaustOut to heatRecovery.exhaustIn;
        
        connect controlSystem.fuelControl to fuelSupply.controlIn;
        connect controlSystem.airControl to airIntake.controlIn;
        connect electricalGenerator.powerOut to controlSystem.powerFeedback;
    }
}

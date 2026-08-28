package AutomatedWaterWellSystem {
    import SI::*;
    
    value def Pressure = Real { unit "Pa"; }
    value def Length = Real { unit "m"; }
    value def VolumeFlowRate = Real { unit "m3/s"; }
    value def Level = Real { unit "m"; }
    value def Volume = Real { unit "m3"; }
    
    item def Water;
    item def ElectricalPower;
    
    enumeration def ControlSignal {
        TurnOn;
        TurnOff;
        EnterMaintenance;
        ExitMaintenance;
    }
    
    port def FluidPort {
        in item water: Water;
        out item water: Water;
    }
    
    port def PowerPort {
        out item power: ElectricalPower;
    }
    
    port def ControlPort {
        out item signal: ControlSignal;
    }
    
    port def PressureSensorPort {
        out value pressure: Pressure;
    }
    
    port def LevelSensorPort {
        out value level: Level;
    }
    
    part def Aquifer {
        port fluidOut: FluidPort;
    }
    
    part def WellBore {
        port fluidIn: FluidPort;
        part aquifer: Aquifer;
    }
    
    part def SubmersiblePump {
        port powerIn: PowerPort;
        port controlIn: ControlPort;
        port fluidIn: FluidPort;
        port fluidOut: FluidPort;
        
        attribute flowRate: VolumeFlowRate = 0.01;
        
        state PumpStates {
            entry; then Off;
            state Off;
            state On;
            state Maintenance;
            
            transition off_to_on
                first Off 
                then On 
                when controlIn.signal == ControlSignal::TurnOn;
                
            transition on_to_off
                first On 
                then Off 
                when controlIn.signal == ControlSignal::TurnOff;
                
            transition to_maintenance
                first Off then Maintenance
                when controlIn.signal == ControlSignal::EnterMaintenance;
                
            transition from_maintenance
                first Maintenance then Off
                when controlIn.signal == ControlSignal::ExitMaintenance;
        }
    }
    
    part def RisingPipe {
        port fluidIn: FluidPort;
        port fluidOut: FluidPort;
    }
    
    part def NonReturnValve {
        port fluidIn: FluidPort;
        port fluidOut: FluidPort;
    }
    
    part def PressureVessel {
        port fluidIn: FluidPort;
        port fluidOut: FluidPort;
        port pressureOut: PressureSensorPort;
        
        attribute currentPressure: Pressure = 200000;
        attribute capacity: Volume = 0.1;
    }
    
    part def DistributionNetwork {
        port fluidIn: FluidPort;
    }
    
    part def WaterLevelSensor {
        port levelOut: LevelSensorPort;
        attribute currentLevel: Level;
    }
    
    part def PressureController {
        port pressureIn: PressureSensorPort;
        port levelIn: LevelSensorPort;
        port pumpControlOut: ControlPort;
        port powerOut: PowerPort;
        
        attribute lowPressureThreshold: Pressure = 150000;
        attribute highPressureThreshold: Pressure = 300000;
        attribute criticalLowLevel: Level = 5.0;
        
        action def ControlAction {
            in pressure: Pressure;
            in level: Level;
            out signal: ControlSignal;
            
            if pressure < lowPressureThreshold and level > criticalLowLevel {
                signal = ControlSignal::TurnOn;
            } else if pressure >= highPressureThreshold or level <= criticalLowLevel {
                signal = ControlSignal::TurnOff;
            }
        }
    }
    
    part def WaterWellSystem {
        part wellBore: WellBore;
        part pump: SubmersiblePump;
        part risingPipe: RisingPipe;
        part nonReturnValve: NonReturnValve;
        part pressureVessel: PressureVessel;
        part distributionNetwork: DistributionNetwork;
        part pressureController: PressureController;
        part waterLevelSensor: WaterLevelSensor;
        
        connection aquiferToPump: FluidPort connect wellBore.aquifer.fluidOut to pump.fluidIn;
        connection pumpToPipe: FluidPort connect pump.fluidOut to risingPipe.fluidIn;
        connection pipeToValve: FluidPort connect risingPipe.fluidOut to nonReturnValve.fluidIn;
        connection valveToTank: FluidPort connect nonReturnValve.fluidOut to pressureVessel.fluidIn;
        connection tankToNetwork: FluidPort connect pressureVessel.fluidOut to distributionNetwork.fluidIn;
        
        connection tankPressureToController: PressureSensorPort connect pressureVessel.pressureOut to pressureController.pressureIn;
        connection levelToController: LevelSensorPort connect waterLevelSensor.levelOut to pressureController.levelIn;
        connection controllerToPump: ControlPort connect pressureController.pumpControlOut to pump.controlIn;
        connection controllerPowerToPump: PowerPort connect pressureController.powerOut to pump.powerIn;
    }
    
    req def PumpControlRequirement {
        subject controller: PressureController;
        objective {
            doc "The controller shall turn the pump on when pressure drops below low threshold and off when above high threshold."
        }
    }
    
    req def DryRunProtectionRequirement {
        subject controller: PressureController;
        subject sensor: WaterLevelSensor;
        objective {
            doc "The system shall shut down the pump if water level drops to critical low."
        }
    }
    
    req def NonReturnValveRequirement {
        subject valve: NonReturnValve;
        objective {
            doc "The valve shall prevent water from flowing back into the well."
        }
    }
}

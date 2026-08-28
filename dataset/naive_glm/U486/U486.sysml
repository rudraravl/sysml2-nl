package FluidPumpingSystem {

    import ScalarValues::*;

    // ---- Units ----
    unit def Pa;
    unit def m3;
    unit def m3_per_s;
    unit def Hz;
    unit def W;
    unit def kg_per_m3;
    unit def cycle;
    unit def percent;

    // ---- Value types ----
    attribute def Pressure :> Real { unit Pa; }
    attribute def Volume :> Real { unit m3; }
    attribute def VolumeFlowRate :> Real { unit m3_per_s; }
    attribute def Frequency :> Real { unit Hz; }
    attribute def Power :> Real { unit W; }
    attribute def Density :> Real { unit kg_per_m3; }
    attribute def CycleCount :> Integer { unit cycle; }
    attribute def Efficiency :> Real { unit percent; }
    attribute def Dimensionless :> Real;

    // ---- Items ----
    item def Liquid {
        attribute density : Density = 1000 [kg_per_m3];
        attribute viscosity : Dimensionless;
    }

    item def CompressedAir;

    // ---- Port definitions ----
    port def FluidPort {
        in out item liquid : Liquid;
        attribute pressure : Pressure;
    }

    port def PneumaticPort {
        in item air : CompressedAir;
        attribute supplyPressure : Pressure;
    }

    port def SignalPort {
        out attribute value : Real;
    }

    // ---- Check valve ----
    part def CheckValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute crackingPressure : Pressure = 5000 [Pa];
        attribute isOpen : Boolean;
        
        assert constraint { 
            (inlet.pressure > outlet.pressure + crackingPressure) implies isOpen 
        }
    }

    // ---- Diaphragm ----
    part def Diaphragm {
        attribute material : String = "PTFE";
        attribute maxCycleLife : CycleCount = 10000000 [cycle];
        attribute position : Dimensionless; // -1 retracted, +1 extended
    }

    // ---- Pump chamber ----
    part def PumpChamber {
        port fluidPort : FluidPort;
        attribute volume : Volume;
        attribute minVolume : Volume = 0.00005 [m3];
        attribute maxVolume : Volume = 0.0002 [m3];
        attribute pressure : Pressure;
    }

    // ---- Actuator ----
    part def PneumaticActuator {
        port supply : PneumaticPort;
        attribute strokeComplete : Boolean;
        attribute driveFrequency : Frequency = 2 [Hz];
        attribute powerConsumption : Power;
        
        action def Stroke {
            in targetPosition : Dimensionless;
        }
    }

    // ---- Sensors ----
    part def PressureSensor {
        port fluidPort : FluidPort;
        port signal : SignalPort;
        attribute measuredPressure : Pressure;
    }

    part def FlowSensor {
        port fluidPort : FluidPort;
        port signal : SignalPort;
        attribute measuredFlowRate : VolumeFlowRate;
    }

    // ---- Reservoir ----
    part def SourceReservoir {
        port outlet : FluidPort;
        attribute level : Volume;
        attribute initialLevel : Volume = 1.0 [m3];
    }

    // ---- Process equipment ----
    part def ProcessEquipment {
        port inlet : FluidPort;
        attribute requiredInletPressure : Pressure = 200000 [Pa];
    }

    // ---- Diaphragm pump assembly ----
    part def DiaphragmPumpAssembly {
        port inletPort : FluidPort;
        port outletPort : FluidPort;
        port pneumaticSupply : PneumaticPort;
        
        part diaphragm : Diaphragm;
        part actuator : PneumaticActuator;
        part chamber : PumpChamber;
        part inletValve : CheckValve;
        part outletValve : CheckValve;
        
        attribute cycleFrequency : Frequency = 2 [Hz];
        attribute nominalFlowRate : VolumeFlowRate = 0.0003 [m3_per_s];
        attribute dischargePressure : Pressure = 300000 [Pa];
        
        connection pneumaticConn connect pneumaticSupply to actuator.supply;
        connection actuatorToDiaphragm connect actuator to diaphragm;
        connection inletToChamber connect inletPort to inletValve.inlet;
        connection inletValveToChamber connect inletValve.outlet to chamber.fluidPort;
        connection chamberToOutletValve connect chamber.fluidPort to outletValve.inlet;
        connection outletValveToPort connect outletValve.outlet to outletPort;
        
        // Pump operation state machine
        state def PumpOperation {
            entry; then IntakeStroke;
            
            state IntakeStroke {
                entry assign actuator.strokeComplete = false;
                entry assign diaphragm.position = -1;
                entry assign chamber.volume = chamber.maxVolume;
                entry assign inletValve.isOpen = true;
                entry assign outletValve.isOpen = false;
                do assign chamber.pressure = 80000 [Pa];
            }
            
            transition from IntakeStroke to DischargeStroke
                when actuator.strokeComplete;
            
            state DischargeStroke {
                entry assign actuator.strokeComplete = false;
                entry assign diaphragm.position = 1;
                entry assign chamber.volume = chamber.minVolume;
                entry assign inletValve.isOpen = false;
                entry assign outletValve.isOpen = true;
                do assign chamber.pressure = dischargePressure;
            }
            
            transition from DischargeStroke to IntakeStroke
                when actuator.strokeComplete;
        }
        
        part behavior pumpOperation : PumpOperation;
    }

    // ---- Top-level system ----
    part def FluidPumpingSystem {
        part reservoir : SourceReservoir;
        part pump : DiaphragmPumpAssembly;
        part equipment : ProcessEquipment;
        part inletPressureSensor : PressureSensor;
        part outletPressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        
        connection reservoirToPump connect reservoir.outlet to pump.inletPort;
        connection pumpToEquipment connect pump.outletPort to flowSensor.fluidPort;
        connection flowToEquipment connect flowSensor.fluidPort to equipment.inlet;
        connection inletSensing connect pump.inletPort to inletPressureSensor.fluidPort;
        connection outletSensing connect pump.outletPort to outletPressureSensor.fluidPort;
    }

    // ---- Requirements ----
    requirement def MinFlowRateRequirement {
        attribute minFlowRate : VolumeFlowRate = 0.00025 [m3_per_s];
        subject pump : DiaphragmPumpAssembly;
        require { pump.nominalFlowRate >= minFlowRate; }
    }

    requirement def MinDischargePressureRequirement {
        attribute minPressure : Pressure = 250000 [Pa];
        subject pump : DiaphragmPumpAssembly;
        require { pump.dischargePressure >= minPressure; }
    }

    requirement def EfficiencyRequirement {
        attribute minEfficiency : Efficiency = 60 [percent];
        subject pump : DiaphragmPumpAssembly;
        require { /* ratio of hydraulic power to actuator input power */ }
    }

    requirement def DiaphragmCycleLifeRequirement {
        attribute minCycleLife : CycleCount = 10000000 [cycle];
        subject diaphragm : Diaphragm;
        require { diaphragm.maxCycleLife >= minCycleLife; }
    }

    requirement def ContinuousOperationRequirement {
        subject system : FluidPumpingSystem;
        require { system.pump.cycleFrequency > 0 [Hz]; }
    }

    requirement def InstrumentationRequirement {
        subject system : FluidPumpingSystem;
        require { 
            system.inletPressureSensor.measuredPressure == system.pump.inletPort.pressure;
            system.outletPressureSensor.measuredPressure == system.pump.outletPort.pressure;
            system.flowSensor.measuredFlowRate > 0 [m3_per_s];
        }
    }

    // ---- Requirement satisfaction ----
    satisfaction satisfy MinFlowRateRequirement by pump;
    satisfaction satisfy MinDischargePressureRequirement by pump;
    satisfaction satisfy EfficiencyRequirement by pump;
    satisfaction satisfy DiaphragmCycleLifeRequirement by pump.diaphragm;
    satisfaction satisfy ContinuousOperationRequirement by pump;
    satisfaction satisfy InstrumentationRequirement by FluidPumpingSystem;

}

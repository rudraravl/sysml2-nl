package MedicalVentilatorSystem {
    private import ScalarValues::*;
    
    value def Pressure :> Real;
    value def Volume :> Real;
    value def Flow :> Real;
    
    item def SensorData;
    item def PressureData :> SensorData {
        attribute airwayPressure : Pressure;
    }
    item def VolumeData :> SensorData {
        attribute breathVolume : Volume;
    }
    
    item def ControlCommand;
    item def PEEPCommand :> ControlCommand {
        attribute peepLevel : Pressure;
    }
    item def FlowCommand :> ControlCommand {
        attribute flowRate : Flow;
        attribute oxygenFraction : Real;
    }
    
    item def AlarmSignal {
        attribute severity : String;
        attribute alarmMessage : String;
    }
    
    part def Patient {
        port gasInflowPort {
            in gasFlow : Flow;
        }
    }
    
    part def PressureSensor {
        port pressureDataPort {
            out pressureData : PressureData;
        }
    }
    
    part def VolumeSensor {
        port volumeDataPort {
            out volumeData : VolumeData;
        }
    }
    
    part def GasDeliveryUnit {
        port peepCommandPort {
            in peepCommand : PEEPCommand;
        }
        port flowCommandPort {
            in flowCommand : FlowCommand;
        }
        port gasDeliveryPort {
            out gasFlow : Flow;
        }
    }
    
    part def AlarmSystem {
        port alarmPort {
            in alarmSignal : AlarmSignal;
        }
    }
    
    state machine def VentilationCycle {
        state Inspiration {
            entry action deliverBreath;
        }
        state Expiration {
            entry action allowExhalation;
        }
        state PEEPMaintenance {
            entry action maintainPEEP;
        }
        transition first to Inspiration;
        transition Inspiration to Expiration;
        transition Expiration to PEEPMaintenance;
        transition PEEPMaintenance to Inspiration;
    }
    
    part def ControlProcessor {
        port pressureDataPort {
            in pressureData : PressureData;
        }
        port volumeDataPort {
            in volumeData : VolumeData;
        }
        port peepCommandPort {
            out peepCommand : PEEPCommand;
        }
        port flowCommandPort {
            out flowCommand : FlowCommand;
        }
        port alarmPort {
            out alarmSignal : AlarmSignal;
        }
        
        attribute maxSafePressure : Pressure = 40;
        attribute minSafeVolume : Volume = 300;
        
        state machine controlBehavior : VentilationCycle;
    }
    
    part def MechanicalVentilator {
        port gasDeliveryPort {
            out gasFlow : Flow;
        }
        
        part controlProcessor : ControlProcessor;
        part pressureSensor : PressureSensor;
        part volumeSensor : VolumeSensor;
        part gasDeliveryUnit : GasDeliveryUnit;
        part alarmSystem : AlarmSystem;
        ref patient : Patient;
        
        flow pressureDataFlow of PressureData 
            from pressureSensor.pressureDataPort.pressureData to controlProcessor.pressureDataPort.pressureData;
            
        flow volumeDataFlow of VolumeData 
            from volumeSensor.volumeDataPort.volumeData to controlProcessor.volumeDataPort.volumeData;
            
        flow peepCommandFlow of PEEPCommand 
            from controlProcessor.peepCommandPort.peepCommand to gasDeliveryUnit.peepCommandPort.peepCommand;
            
        flow flowCommandFlow of FlowCommand 
            from controlProcessor.flowCommandPort.flowCommand to gasDeliveryUnit.flowCommandPort.flowCommand;
            
        flow alarmSignalFlow of AlarmSignal 
            from controlProcessor.alarmPort.alarmSignal to alarmSystem.alarmPort.alarmSignal;
            
        flow gasFlowFlow of Flow 
            from gasDeliveryUnit.gasDeliveryPort.gasFlow to patient.gasInflowPort.gasFlow;
            
        bind gasDeliveryPort = gasDeliveryUnit.gasDeliveryPort;
    }
    
    requirement def PreventAtelectotrauma {
        subject ventilator : MechanicalVentilator;
        doc "The ventilator shall prevent atelectotrauma by maintaining alveolar recruitment.";
    }
    
    requirement def MaintainSafeLimits {
        subject ventilator : MechanicalVentilator;
        attribute maxPressure : Pressure = 40;
        attribute minVolume : Volume = 300;
        constraint { ventilator.controlProcessor.maxSafePressure <= maxPressure }
        constraint { ventilator.controlProcessor.minSafeVolume >= minVolume }
    }
    
    requirement preventAtelectotrauma : PreventAtelectotrauma;
    requirement maintainSafeLimits : MaintainSafeLimits;
    
    part ventilatorSystem : MechanicalVentilator;
    
    satisfy preventAtelectotrauma by ventilatorSystem;
    satisfy maintainSafeLimits by ventilatorSystem;
}

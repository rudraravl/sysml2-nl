package VacuumBellSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    item def Air;
    
    value type Pressure :> Real { unit = "Pa"; }
    value type Volume :> Real { unit = "m^3"; }
    value type FlowRate :> Real { unit = "m^3/s"; }
    value type Duration :> Real { unit = "s"; }
    value type Power :> Real { unit = "W"; }
    
    port def FluidPort {
        out item airOut : Air;
        in item airIn : Air;
    }
    
    port def PressurePort {
        inout pressure : Pressure;
    }
    
    port def PressureSignalPort {
        out pressureReading : Pressure;
    }
    
    port def CommandPort {
        in command : Real;
    }
    
    part def BellChamber {
        port fluidPort : FluidPort;
        port pressurePort : PressurePort;
        attribute volume : Volume = 0.002 [m^3];
        attribute currentPressure : Pressure;
    }
    
    part def VacuumPump {
        port fluidPort : FluidPort;
        port controlPort : CommandPort;
        attribute maxFlowRate : FlowRate = 0.0001 [m^3/s];
    }
    
    part def PressureSensor {
        port pressurePort : PressurePort;
        port signalPort : PressureSignalPort;
        attribute measuredPressure : Pressure;
    }
    
    part def ControlUnit {
        port sensorPort : ~PressureSignalPort;
        port pumpControlPort : ~CommandPort;
        port regulatorControlPort : ~CommandPort;
        port releaseValvePort : ~CommandPort;
        
        attribute targetPressure : Pressure = -20000 [Pa];
        attribute sessionDuration : Duration = 1800 [s];
        attribute safePressureThreshold : Pressure = -30000 [Pa];
        
        state def ControlStates {
            initial start;
            state Idle;
            state ActiveTreatment;
            state EmergencyRelease;
            state SessionComplete;
            
            transition start to Idle;
            transition Idle to ActiveTreatment when sensorPort.pressureReading < targetPressure;
            transition ActiveTreatment to EmergencyRelease when sensorPort.pressureReading > safePressureThreshold;
            transition ActiveTreatment to SessionComplete after sessionDuration;
            transition EmergencyRelease to Idle;
            transition SessionComplete to Idle;
        }
    }
    
    part def PressureRegulator {
        port fluidPort : FluidPort;
        port controlPort : CommandPort;
        attribute regulatedPressure : Pressure;
    }
    
    part def SafetyValve {
        port fluidPort : FluidPort;
        port pressurePort : PressurePort;
        attribute threshold : Pressure = -35000 [Pa];
        
        state def ValveStates {
            initial start;
            state Closed;
            state Open;
            
            transition start to Closed;
            transition Closed to Open when pressurePort.pressure > threshold;
            transition Open to Closed when pressurePort.pressure <= threshold;
        }
    }
    
    part def ReleaseValve {
        port fluidPort : FluidPort;
        port controlPort : CommandPort;
        
        state def ValveStates {
            initial start;
            state Closed;
            state Open;
            
            transition start to Closed;
            transition Closed to Open when controlPort.command > 0.0;
            transition Open to Closed when controlPort.command == 0.0;
        }
    }
    
    part def VacuumBellSystem {
        part bellChamber : BellChamber;
        part vacuumPump : VacuumPump;
        part pressureSensor : PressureSensor;
        part controlUnit : ControlUnit;
        part pressureRegulator : PressureRegulator;
        part safetyValve : SafetyValve;
        part releaseValve : ReleaseValve;
        
        connection fluidConn1 connect vacuumPump.fluidPort to pressureRegulator.fluidPort;
        connection fluidConn2 connect pressureRegulator.fluidPort to bellChamber.fluidPort;
        connection fluidConn3 connect bellChamber.fluidPort to safetyValve.fluidPort;
        connection fluidConn4 connect bellChamber.fluidPort to releaseValve.fluidPort;
        
        connection pressureConn1 connect bellChamber.pressurePort to pressureSensor.pressurePort;
        connection pressureConn2 connect bellChamber.pressurePort to safetyValve.pressurePort;
        
        connection signalConn1 connect pressureSensor.signalPort to controlUnit.sensorPort;
        connection signalConn2 connect controlUnit.pumpControlPort to vacuumPump.controlPort;
        connection signalConn3 connect controlUnit.regulatorControlPort to pressureRegulator.controlPort;
        connection signalConn4 connect controlUnit.releaseValvePort to releaseValve.controlPort;
    }
    
    requirement def SafetyRequirement {
        doc "The system must not exceed the safe pressure threshold under any circumstances."
    }
    
    requirement def TreatmentRequirement {
        doc "The system must maintain the target therapeutic pressure for the duration of the session."
    }
    
    requirement def EmergencyReleaseRequirement {
        doc "The system must be able to rapidly release vacuum pressure in an emergency."
    }
    
    requirement safetyReq : SafetyRequirement {
        subject safetyValve.threshold;
        constraint { safetyValve.threshold >= -35000 [Pa] }
    }
    
    requirement treatmentReq : TreatmentRequirement {
        subject controlUnit.targetPressure;
        constraint { controlUnit.targetPressure == -20000 [Pa] }
    }
    
    requirement emergencyReq : EmergencyReleaseRequirement {
        subject releaseValve;
        constraint { releaseValve.controlPort.command >= 0.0 }
    }
}

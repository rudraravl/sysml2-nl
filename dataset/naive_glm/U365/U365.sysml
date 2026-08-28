package RectalDilatorSystem {
    import ISQ::*;
    import ScalarValues::*;

    value type Diameter :> Length;
    value type TissuePressure :> Pressure;
    value type ExpansionForce :> Force;
    value type Duration :> Time;

    item def PressureReading {
        attr value : TissuePressure;
    }

    item def ControlCommand {
        attr targetDiameter : Diameter;
        attr mode : String;
    }

    item def AlarmSignal;

    port def MechanicalInterface {
        out force : ExpansionForce;
        in pressure : TissuePressure;
    }

    port def PressureDataPort {
        out reading : PressureReading;
    }

    port def ControlDataPort {
        in command : ControlCommand;
        out status : String;
    }

    port def AlarmPort {
        out alarm : AlarmSignal;
    }

    part def DilatorTip {
        attr material : String = "Biocompatible Medical Silicone";
        attr length : Diameter = 20 [mm];
        port mechanicalInterface : MechanicalInterface;
    }

    part def ExpandableShaft {
        attr material : String = "Biocompatible Medical Silicone";
        attr minDiameter : Diameter = 10 [mm];
        attr maxDiameter : Diameter = 40 [mm];
        attr currentDiameter : Diameter;
        
        port mechanicalInterface : MechanicalInterface;
        
        action def expand {
            in force : ExpansionForce;
            out newDiameter : Diameter;
        }
    }

    part def ExpansionMechanism {
        port mechanicalInterface : MechanicalInterface;
        port controlInterface : ControlDataPort;
        
        action def applyForce {
            in targetDiameter : Diameter;
            out force : ExpansionForce;
        }
    }

    part def PressureMonitor {
        attr safeThreshold : TissuePressure = 50 [kPa];
        attr criticalThreshold : TissuePressure = 80 [kPa];
        
        port mechanicalInterface : MechanicalInterface;
        port dataOut : PressureDataPort;
        port alarmOut : AlarmPort;
        
        action def measurePressure {
            out reading : PressureReading;
        }
    }

    part def SafetyRelease {
        port mechanicalInterface : MechanicalInterface;
        attr activated : Boolean = false;
        
        action def release {
            out force : ExpansionForce;
        }
    }

    part def ControlModule {
        attr targetDiameter : Diameter;
        attr procedureMode : String;
        attr currentDiameter : Diameter;
        attr alarmTriggered : Boolean = false;
        
        port controlInterface : ControlDataPort;
        port pressureIn : PressureDataPort;
        port alarmIn : AlarmPort;
        
        state machine ControlBehavior {
            state PreUseChecks;
            state LubricationAndPositioning;
            state IncrementalExpansion {
                state Expanding;
                state PausingAndMonitoring;
                transition expand_to_pause first Expanding then PausingAndMonitoring;
                transition pause_to_expand first PausingAndMonitoring then Expanding if targetDiameter > currentDiameter;
            }
            state MaintainTargetDiameter;
            state GradualRetraction;
            state EmergencyRetraction;
            
            transition init first initial then PreUseChecks;
            transition checks_done first PreUseChecks then LubricationAndPositioning;
            transition ready first LubricationAndPositioning then IncrementalExpansion;
            transition target_reached first IncrementalExpansion then MaintainTargetDiameter if targetDiameter == currentDiameter;
            transition maintained first MaintainTargetDiameter then GradualRetraction;
            transition emergency first IncrementalExpansion then EmergencyRetraction if alarmTriggered == true;
            transition emergency_maintained first MaintainTargetDiameter then EmergencyRetraction if alarmTriggered == true;
            transition done first GradualRetraction then final;
            transition emergency_done first EmergencyRetraction then final;
        }
    }

    part def RectalDilatorSystem {
        part tip : DilatorTip;
        part shaft : ExpandableShaft;
        part mechanism : ExpansionMechanism;
        part monitor : PressureMonitor;
        part safety : SafetyRelease;
        part controller : ControlModule;
        
        connect tip.mechanicalInterface to shaft.mechanicalInterface;
        connect shaft.mechanicalInterface to mechanism.mechanicalInterface;
        connect shaft.mechanicalInterface to monitor.mechanicalInterface;
        connect shaft.mechanicalInterface to safety.mechanicalInterface;
        
        connect mechanism.controlInterface to controller.controlInterface;
        connect monitor.dataOut to controller.pressureIn;
        connect monitor.alarmOut to controller.alarmIn;
    }

    requirement def SafeDilationRequirement {
        subject : RectalDilatorSystem;
        objective {
            doc "The system shall safely create access for medical examinations while minimizing patient discomfort and preventing tissue trauma."
        }
    }
    
    requirement def ShaftExpansionRequirement {
        subject : ExpandableShaft;
        objective {
            doc "The shaft shall gradually increase in diameter from 10 mm up to 40 mm."
        }
        constraint { minDiameter == 10 [mm] and maxDiameter == 40 [mm] }
    }
    
    requirement def PressureMonitoringRequirement {
        subject : PressureMonitor;
        objective {
            doc "If pressure exceeds a pre-set safe threshold, an alarm shall be activated."
        }
    }
    
    requirement def SafetyReleaseRequirement {
        subject : SafetyRelease;
        objective {
            doc "A mechanical safety release shall automatically activate and reduce pressure if it reaches a critical level."
        }
    }
    
    requirement def IncrementalProcedureRequirement {
        subject : ControlModule;
        objective {
            doc "The device shall expand in small steps, pausing after each one to monitor tissue pressure and response."
        }
    }
    
    requirement def EmergencyRetractionRequirement {
        subject : RectalDilatorSystem;
        objective {
            doc "In case of excessive pressure at any point, the system shall perform an emergency retraction."
        }
    }
}

package DLTSystem {
    // Value Types
    value type Pressure > Real { unit "cmH2O"; }
    value type Volume > Real { unit "mL"; }
    value type FlowRate > Real { unit "L/min"; }
    value type Frequency > Real { unit "breaths/min"; }
    value type Fraction > Real { unit "1"; }
    
    // Items
    item def BreathableGas {
        attribute oxygenConcentration : Fraction;
        attribute flowRate : FlowRate;
    }
    
    // Ports
    port def GasFlowPort {
        out gas : BreathableGas;
    }
    
    port def PressurePort {
        out pressure : Pressure;
    }
    
    // Enumerations
    enum def VentilationMode {
        BOTH_LUNGS;
        LEFT_LUNG_ONLY;
        RIGHT_LUNG_ONLY;
    }
    
    // Parts
    part def Cuff {
        attribute targetPressure : Pressure;
        attribute currentPressure : Pressure;
        attribute isInflated : Boolean;
        port pressurePort : PressurePort;
        
        action def InflateCuff {
            in target : Pressure;
            then SetInflated;
        }
        action SetInflated {
            // set isInflated = true
        }
    }
    
    part def Lumen {
        attribute targetLung : String;
        port distalGasFlow : GasFlowPort;
        port proximalGasFlow : GasFlowPort;
        
        connection passGas connect proximalGasFlow to distalGasFlow;
    }
    
    part def DoubleLumenTube {
        part trachealCuff : Cuff;
        part bronchialCuff : Cuff;
        part leftLumen : Lumen { redefines targetLung = "Left"; }
        part rightLumen : Lumen { redefines targetLung = "Right"; }
        
        port proximalLeftPort : GasFlowPort;
        port proximalRightPort : GasFlowPort;
        
        connection leftGasConn connect proximalLeftPort to leftLumen.proximalGasFlow;
        connection rightGasConn connect proximalRightPort to rightLumen.proximalGasFlow;
    }
    
    part def Lung {
        attribute isVentilated : Boolean;
        attribute isCollapsed : Boolean;
        port gasExchange : GasFlowPort;
    }
    
    part def Airway {
        part trachea {
            port opening : GasFlowPort;
            port leftBranch : GasFlowPort;
            port rightBranch : GasFlowPort;
        }
        part leftBronchus {
            port proximal : GasFlowPort;
            port distal : GasFlowPort;
        }
        part rightBronchus {
            port proximal : GasFlowPort;
            port distal : GasFlowPort;
        }
        
        connection tracheaToLeft connect trachea.leftBranch to leftBronchus.proximal;
        connection tracheaToRight connect trachea.rightBranch to rightBronchus.proximal;
    }
    
    part def Patient {
        part airway : Airway;
        part leftLung : Lung;
        part rightLung : Lung;
        
        connection leftAirway connect airway.leftBronchus.distal to leftLung.gasExchange;
        connection rightAirway connect airway.rightBronchus.distal to rightLung.gasExchange;
    }
    
    part def Ventilator {
        attribute mode : VentilationMode;
        attribute respiratoryRate : Frequency;
        attribute tidalVolume : Volume;
        attribute peakAirwayPressure : Pressure;
        
        port leftGasOut : GasFlowPort;
        port rightGasOut : GasFlowPort;
        
        state machine def VentilationStateMachine {
            initial start;
            state Idle;
            state VentilatingBoth;
            state VentilatingLeft;
            state VentilatingRight;
            
            transition from Idle to VentilatingBoth when mode == VentilationMode::BOTH_LUNGS;
            transition from Idle to VentilatingLeft when mode == VentilationMode::LEFT_LUNG_ONLY;
            transition from Idle to VentilatingRight when mode == VentilationMode::RIGHT_LUNG_ONLY;
            
            transition from VentilatingBoth to Idle when mode != VentilationMode::BOTH_LUNGS;
            transition from VentilatingLeft to Idle when mode != VentilationMode::LEFT_LUNG_ONLY;
            transition from VentilatingRight to Idle when mode != VentilationMode::RIGHT_LUNG_ONLY;
        }
    }
    
    // System Assembly
    part def DLTSystem {
        part ventilator : Ventilator;
        part tube : DoubleLumenTube;
        part patient : Patient;
        
        connection ventilatorToTubeLeft connect ventilator.leftGasOut to tube.proximalLeftPort;
        connection ventilatorToTubeRight connect ventilator.rightGasOut to tube.proximalRightPort;
        
        connection tubeToPatientLeft connect tube.leftLumen.distalGasFlow to patient.airway.leftBronchus.proximal;
        connection tubeToPatientRight connect tube.rightLumen.distalGasFlow to patient.airway.rightBronchus.proximal;
    }
    
    // Requirements
    requirement def LungIsolationRequirement {
        doc "The system shall provide complete physical separation between the two lungs when cuffs are inflated."
        attribute cuffPressure : Pressure;
        constraint { cuffPressure >= 20 and cuffPressure <= 30 }
    }
    
    requirement def SelectiveVentilationRequirement {
        doc "The system shall allow ventilation of both, only left, or only right lung."
        attribute mode : VentilationMode;
    }
    
    requirement def SafeCuffPressureRequirement {
        doc "Cuffs shall be inflated to a safe pressure to prevent tissue damage."
        attribute pressure : Pressure;
        constraint { pressure <= 30 }
    }
}

package NasalCannulaOxygenDeliverySystem {
    import ISQ::VolumeFlowRate;
    import ISQ::Pressure;
    import ISQ::Length;
    import ScalarValues::Real;
    import ScalarValues::Boolean;
    import ScalarValues::String;
    import ScalarValues::Integer;

    // Value Types
    value def OxygenPurity :> Real { unit: 'percent'; }
    value def FlowRate :> VolumeFlowRate { unit: 'L/min'; }
    value def SystemPressure :> Pressure { unit: 'Pa'; }
    value def TubeLength :> Length { unit: 'm'; }
    
    // Items
    item def MedicalOxygen;
    item def BreathingMixture;
    
    // Occurrences
    occurrence def StartCommand;
    occurrence def StopCommand;
    occurrence def Fault;
    occurrence def Reset;
    
    // Ports
    port def OxygenFlowPort {
        out item oxygen: MedicalOxygen;
        out value pressure: SystemPressure;
        out value flow: FlowRate;
    }
    
    port def CommandPort {
        in occurrence startCmd: StartCommand;
        in occurrence stopCmd: StopCommand;
        in attribute setFlow: FlowRate;
    }
    
    port def AlarmPort {
        out attribute alarmActive: Boolean;
        out attribute faultDescription: String;
    }
    
    // Connections
    connection def OxygenFlowConnection {
        end supplier: OxygenFlowPort;
        end consumer: ~OxygenFlowPort;
    }
    
    // Parts
    part def OxygenSource {
        port outFlow: OxygenFlowPort;
        attribute purity: OxygenPurity = 99.5;
        attribute supplyPressure: SystemPressure = 1.5e7; 
    }
    
    part def FlowMeter {
        port inFlow: ~OxygenFlowPort;
        port outFlow: OxygenFlowPort;
        attribute targetFlow: FlowRate;
    }
    
    part def OxygenTubing {
        port inFlow: ~OxygenFlowPort;
        port outFlow: OxygenFlowPort;
        attribute length: TubeLength = 2.0; 
        attribute innerDiameter: Real = 0.004; 
    }
    
    part def NasalCannula {
        port inFlow: ~OxygenFlowPort;
        port outFlow: OxygenFlowPort;
        attribute prongCount: Integer = 2;
    }
    
    part def Patient {
        port inFlow: ~OxygenFlowPort;
        attribute bloodOxygenSaturation: OxygenPurity;
    }
    
    // System
    part def OxygenDeliverySystem {
        port cmdPort: CommandPort;
        port alarmPort: AlarmPort;
        
        part oxygenSource: OxygenSource;
        part flowMeter: FlowMeter;
        part tubing: OxygenTubing;
        part cannula: NasalCannula;
        part patient: Patient;
        
        connection sourceToMeter: OxygenFlowConnection connect oxygenSource.outFlow to flowMeter.inFlow;
        connection meterToTubing: OxygenFlowConnection connect flowMeter.outFlow to tubing.inFlow;
        connection tubingToCannula: OxygenFlowConnection connect tubing.outFlow to cannula.inFlow;
        connection cannulaToPatient: OxygenFlowConnection connect cannula.outFlow to patient.inFlow;
        
        action regulateOxygenFlow;
        action monitorPatient;
        
        state def SystemStates {
            state idle {
                entry { /* powered on, ready */ }
            }
            state active {
                entry { /* start delivering oxygen */ }
                do regulateOxygenFlow;
                do monitorPatient;
            }
            state alarm {
                entry { /* trigger alarm */ }
            }
            
            transition first idle accept StartCommand then active;
            transition first active accept StopCommand then idle;
            transition first active accept Fault then alarm;
            transition first alarm accept Reset then idle;
        }
    }
    
    // Requirements
    req def OxygenDeliveryRequirement {
        subject system: OxygenDeliverySystem;
        objective {
            doc "The system shall increase the patient's blood oxygen saturation by delivering a controlled flow of high-purity oxygen."
        }
    }
    
    req def FlowControlRequirement {
        subject flowMeter: FlowMeter;
        objective {
            doc "The flow meter shall allow a clinician to set and regulate the exact rate of oxygen delivery, typically measured in liters per minute."
        }
    }
    
    req def SafetyRequirement {
        subject system: OxygenDeliverySystem;
        objective {
            doc "The system shall ensure a stable, controlled flow of oxygen at safe pressures, prioritizing patient safety and comfort."
        }
    }
}

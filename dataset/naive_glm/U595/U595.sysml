package BarometricAltimeterSystem {
    import ScalarValues::*;
    
    // Value Types
    item def PressureValue :> Real { 
        attribute unit : String = "hPa"; 
    }
    item def TemperatureValue :> Real { 
        attribute unit : String = "K"; 
    }
    item def AltitudeValue :> Real { 
        attribute unit : String = "ft"; 
    }
    item def ElectricalPower {
        attribute voltage : Real = 28.0;
        attribute unit : String = "V";
    }
    
    // Flow items
    item def AtmosphericData {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
    }
    item def AltitudeData {
        attribute altitude : AltitudeValue;
        attribute valid : Boolean;
    }
    item def AlertSignal {
        attribute message : String;
    }
    
    // Ports
    port def PowerPort {
        out power : ElectricalPower;
    }
    port def AtmosphericDataPort {
        out data : AtmosphericData;
    }
    port def AltitudeDataPort {
        out data : AltitudeData;
    }
    port def AlertPort {
        out alert : AlertSignal;
    }
    
    // Requirements
    requirement def AltimeterRequirement {
        doc "The system shall provide accurate altitude information."
    }
    requirement def PowerSupplyRequirement :> AltimeterRequirement {
        doc "The Power Supply shall provide electrical power to all components."
    }
    requirement def MeasurementRequirement :> AltimeterRequirement {
        doc "The Pressure Transducer shall measure static air pressure and ambient temperature."
    }
    requirement def CalculationRequirement :> AltimeterRequirement {
        doc "The Computer Module shall calculate altitude using calibrated pressure and temperature."
    }
    requirement def DisplayRequirement :> AltimeterRequirement {
        doc "The Indicator Display shall show the current altitude."
    }
    requirement def WarningRequirement :> AltimeterRequirement {
        doc "The Warning System shall trigger an alert if altitude is below minimum safe altitude or exceeds maximum operating altitude."
    }
    
    // Parts
    part def PressureTransducer {
        port powerIn : PowerPort;
        port dataOut : AtmosphericDataPort;
        
        action measureAtmosphericData {
            out atmosphericData : AtmosphericData;
        }
    }
    
    part def ComputerModule {
        port powerIn : PowerPort;
        port dataIn : AtmosphericDataPort;
        port dataOut : AltitudeDataPort;
        
        attribute barometricSetting : PressureValue = 1013.25;
        
        action calculateAltitude {
            in atmosphericData : AtmosphericData;
            out altitudeData : AltitudeData;
        }
        action validateData {
            in altitudeData : AltitudeData;
            out valid : Boolean;
        }
    }
    
    part def IndicatorDisplay {
        port powerIn : PowerPort;
        port dataIn : AltitudeDataPort;
        
        action displayAltitude {
            in altitudeData : AltitudeData;
        }
    }
    
    part def WarningSystem {
        port powerIn : PowerPort;
        port dataIn : AltitudeDataPort;
        port alertOut : AlertPort;
        
        attribute minSafeAltitude : AltitudeValue = 500.0;
        attribute maxOperatingAltitude : AltitudeValue = 50000.0;
        
        action monitorAltitude {
            in altitudeData : AltitudeData;
            out alert : AlertSignal;
        }
    }
    
    part def PowerSupply {
        port powerOut : PowerPort;
        
        action generatePower {
            out power : ElectricalPower;
        }
    }
    
    // State Machine
    state def AltimeterStates {
        initial state initialization {
            entry action {
                // Run self-test
            }
            transition to operational if true;
        }
        
        state operational {
            do action {
                // continuously measure, calculate, display
            }
            transition to fault if false; // condition for fault
        }
        
        state fault {
            entry action {
                // handle fault
            }
        }
    }
    
    part def BarometricAltimeter {
        satisfy AltimeterRequirement;
        
        part powerSupply : PowerSupply {
            perform generatePower;
        }
        part pressureTransducer : PressureTransducer {
            perform measureAtmosphericData;
        }
        part computerModule : ComputerModule {
            perform calculateAltitude;
            perform validateData;
        }
        part indicatorDisplay : IndicatorDisplay {
            perform displayAltitude;
        }
        part warningSystem : WarningSystem {
            perform monitorAltitude;
        }
        
        // Connections
        flow powerSupply.powerOut.power to pressureTransducer.powerIn.power;
        flow powerSupply.powerOut.power to computerModule.powerIn.power;
        flow powerSupply.powerOut.power to indicatorDisplay.powerIn.power;
        flow powerSupply.powerOut.power to warningSystem.powerIn.power;
        
        flow pressureTransducer.dataOut.data to computerModule.dataIn.data;
        flow computerModule.dataOut.data to indicatorDisplay.dataIn.data;
        flow computerModule.dataOut.data to warningSystem.dataIn.data;
        
        // State Machine
        exhibit state altimeterStateMachine : AltimeterStates;
    }
}

package MachmeterSystem {
    import ScalarValues::*;

    attribute def PressureValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def MachValue :> Real;
    attribute def AltitudeValue :> Real;
    attribute def FrequencyValue :> Real;

    item def PressureData {
        attribute totalPressure : PressureValue;
        attribute staticPressure : PressureValue;
    }
    
    item def TemperatureData {
        attribute ambientTemperature : TemperatureValue;
    }
    
    item def MachData {
        attribute machNumber : MachValue;
        attribute isValid : Boolean;
    }

    port def PressureOutPort {
        out pressureData : PressureData;
    }
    
    port def TempOutPort {
        out tempData : TemperatureData;
    }
    
    port def MachOutPort {
        out machData : MachData;
    }

    part def PitotStaticProbe {
        out port pressureOut : PressureOutPort;
    }
    
    part def TemperatureProbe {
        out port tempOut : TempOutPort;
    }
    
    part def MachComputationUnit satisfies ValidatePressure {
        in port pressureIn : PressureOutPort;
        in port tempIn : TempOutPort;
        out port machOut : MachOutPort;
        
        attribute computedMach : MachValue;
        attribute dataValid : Boolean;
        attribute initializationComplete : Boolean;
        
        action def ComputeMach {
            in pressure : PressureData;
            in temp : TemperatureData;
            out mach : MachData;
        }
        
        action computeMach : ComputeMach;
    }
    
    part def DisplayUnit satisfies HighUpdateRate {
        in port machIn : MachOutPort;
        attribute updateRate : FrequencyValue = 10;
    }

    part def Machmeter satisfies MeasureAndDisplayMachNumber, AltitudeRange {
        attribute powerOn : Boolean;
        
        part pitotStaticProbe : PitotStaticProbe;
        part temperatureProbe : TemperatureProbe;
        part machComputationUnit : MachComputationUnit;
        part displayUnit : DisplayUnit;
        
        connect pitotStaticProbe.pressureOut to machComputationUnit.pressureIn;
        connect temperatureProbe.tempOut to machComputationUnit.tempIn;
        connect machComputationUnit.machOut to displayUnit.machIn;
        
        state machmeterStateMachine {
            state off;
            state initializing;
            state operational {
                state subsonic;
                state transonic;
                state supersonic;
                
                transition subsonic to transonic when machComputationUnit.computedMach >= 0.8;
                transition transonic to supersonic when machComputationUnit.computedMach >= 1.2;
                transition supersonic to transonic when machComputationUnit.computedMach < 1.2;
                transition transonic to subsonic when machComputationUnit.computedMach < 0.8;
            }
            
            transition off to initializing when powerOn;
            transition initializing to operational when machComputationUnit.initializationComplete;
        }
    }

    requirement def MeasureAndDisplayMachNumber {
        doc /* The system shall continuously measure and display the aircraft's speed relative to the local speed of sound. */
    }
    
    requirement def ValidatePressure {
        doc /* The system shall validate pressure readings to ensure they are reliable. */
    }
    
    requirement def HighUpdateRate {
        doc /* The display shall update at a high rate, at least 10 times per second. */
        attribute minUpdateRate : FrequencyValue = 10;
    }
    
    requirement def AltitudeRange {
        doc /* The system shall be highly accurate across altitudes up to 60,000 feet. */
        attribute maxAltitude : AltitudeValue = 60000;
    }
}

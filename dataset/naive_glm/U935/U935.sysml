package TotalEnergyVariometerSystem {
    import ISQ::*;
    import ScalarValues::*;

    value def Pressure :> Real { unit Pa; }
    value def Altitude :> Real { unit m; }
    value def VerticalSpeed :> Real { unit "m/s"; }
    value def Airspeed :> Real { unit "m/s"; }
    value def Frequency :> Real { unit Hz; }
    value def TimeInterval :> Real { unit s; }

    item def PressureData {
        value staticPressure : Pressure;
        value dynamicPressure : Pressure;
    }
    
    item def DisplayCommand {
        value climbRate : VerticalSpeed;
    }
    
    item def AudioCommand {
        value frequency : Frequency;
        value beepInterval : TimeInterval;
    }

    port def PressureOutPort {
        out pressureData : PressureData;
    }
    
    port def PressureInPort {
        in pressureData : PressureData;
    }
    
    port def DisplayOutPort {
        out displayCommand : DisplayCommand;
    }
    
    port def DisplayInPort {
        in displayCommand : DisplayCommand;
    }
    
    port def AudioOutPort {
        out audioCommand : AudioCommand;
    }
    
    port def AudioInPort {
        in audioCommand : AudioCommand;
    }

    part def PressureSensor {
        port pressureOut : PressureOutPort;
        attribute isCalibrated : Boolean = false;
        
        action def measurePressure {
            out data : PressureData;
        }
    }

    part def ComputationUnit {
        port pressureIn : PressureInPort;
        port displayOut : DisplayOutPort;
        port audioOut : AudioOutPort;
        
        attribute currentAltitude : Altitude = 0 [m];
        attribute currentAirspeed : Airspeed = 0 ["m/s"];
        attribute currentVerticalSpeed : VerticalSpeed = 0 ["m/s"];
        attribute compensatedVerticalSpeed : VerticalSpeed = 0 ["m/s"];
        
        action def calculateAltitude {
            in pressure : Pressure;
            out altitude : Altitude;
        }
        
        action def calculateVerticalSpeed {
            in altitude : Altitude;
            out verticalSpeed : VerticalSpeed;
        }
        
        action def calculateTotalEnergyCompensation {
            in verticalSpeed : VerticalSpeed;
            in airspeed : Airspeed;
            out compensatedVerticalSpeed : VerticalSpeed;
        }
    }

    part def VisualDisplay {
        port displayIn : DisplayInPort;
        
        action def updateDisplay {
            in climbRate : VerticalSpeed;
        }
    }

    part def AudioIndicator {
        port audioIn : AudioInPort;
        
        action def generateTone {
            in frequency : Frequency;
            in beepInterval : TimeInterval;
        }
    }

    part def TotalEnergyVariometer {
        part pressureSensor : PressureSensor;
        part computationUnit : ComputationUnit;
        part visualDisplay : VisualDisplay;
        part audioIndicator : AudioIndicator;
        
        attribute powerOn : Boolean = true;
        
        connect pressureSensor.pressureOut to computationUnit.pressureIn;
        connect computationUnit.displayOut to visualDisplay.displayIn;
        connect computationUnit.audioOut to audioIndicator.audioIn;
        
        state machine VariometerStateMachine {
            state initializing {
                entry pressureSensor.isCalibrated = false;
            }
            state operational {
                state climbing;
                state descending;
                state levelFlight;
                
                transition from levelFlight to climbing
                    when computationUnit.compensatedVerticalSpeed > 0.0 ["m/s"];
                transition from levelFlight to descending
                    when computationUnit.compensatedVerticalSpeed < 0.0 ["m/s"];
                transition from climbing to levelFlight
                    when computationUnit.compensatedVerticalSpeed == 0.0 ["m/s"];
                transition from climbing to descending
                    when computationUnit.compensatedVerticalSpeed < 0.0 ["m/s"];
                transition from descending to levelFlight
                    when computationUnit.compensatedVerticalSpeed == 0.0 ["m/s"];
                transition from descending to climbing
                    when computationUnit.compensatedVerticalSpeed > 0.0 ["m/s"];
            }
            state poweredDown;
            
            transition from initializing to operational
                when pressureSensor.isCalibrated == true;
            transition from operational to poweredDown
                when powerOn == false;
            transition from poweredDown to initializing
                when powerOn == true;
        }
    }

    requirement def MeasureVerticalSpeed {
        doc /* The variometer shall measure the aircraft's vertical speed. */
    }
    
    requirement def TotalEnergyCompensation {
        doc /* The computation unit shall adjust the vertical speed reading to account for changes in the aircraft's airspeed. */
    }
    
    requirement def ProvideVisualFeedback {
        doc /* The visual display shall show the rate of climb or sink. */
    }
    
    requirement def ProvideAudioFeedback {
        doc /* The audio indicator shall generate audible tones whose frequency and rhythm change to reflect the vertical speed. */
    }
}

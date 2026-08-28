package AID_System {
    import ScalarValues::*;
    import ISQ::*;
    
    value type GlucoseLevel :> Real { unit = "mg/dL"; }
    value type GlucoseRateOfChange :> Real { unit = "mg/dL/min"; }
    value type InsulinDose :> Real { unit = "U"; }
    value type InsulinReservoirVolume :> Real { unit = "U"; }
    
    item def GlucoseReading {
        value level : GlucoseLevel;
        value trend : GlucoseRateOfChange;
        value timestamp : Real;
    }
    
    item def InsulinCommand {
        value dose : InsulinDose;
        value timestamp : Real;
        value commandId : String;
    }
    
    item def SafetyApproval {
        value approved : Boolean;
        value reason : String;
        value originalCommand : InsulinCommand;
    }
    
    item def UIData {
        value currentGlucose : GlucoseLevel;
        value currentTrend : GlucoseRateOfChange;
        value reservoirLevel : InsulinReservoirVolume;
        value systemMode : String;
        value activeAlerts : String;
    }
    
    item def UICommand {
        value commandType : String;
        value dose : InsulinDose;
        value timestamp : Real;
    }
    
    item def LogEntry {
        value eventType : String;
        value data : String;
        value timestamp : Real;
    }
    
    item def EncryptedData {
        value payload : String;
        value timestamp : Real;
    }
    
    port def GlucoseDataOut {
        out reading : GlucoseReading;
    }
    port def GlucoseDataIn {
        in reading : GlucoseReading;
    }
    port def CommandOut {
        out command : InsulinCommand;
    }
    port def CommandIn {
        in command : InsulinCommand;
    }
    port def SafetyCheckOut {
        out command : InsulinCommand;
        in approval : SafetyApproval;
    }
    port def SafetyCheckIn {
        in command : InsulinCommand;
        out approval : SafetyApproval;
    }
    port def UIDataOut {
        out data : UIData;
    }
    port def UIDataIn {
        in data : UIData;
    }
    port def UICommandOut {
        out command : UICommand;
    }
    port def UICommandIn {
        in command : UICommand;
    }
    port def LogOut {
        out entry : LogEntry;
    }
    port def LogIn {
        in entry : LogEntry;
    }
    port def WirelessOut {
        out data : EncryptedData;
    }
    port def WirelessIn {
        in data : EncryptedData;
    }
    
    part def ContinuousGlucoseSensor {
        port glucoseOut : GlucoseDataOut;
        port logOut : LogOut;
        
        attribute samplingRate : Real = 0.0167;
        
        action def MeasureGlucose {
            out reading : GlucoseReading;
        }
        
        state def SensorStates {
            entry; 
            state Active {
                entry; 
                do MeasureGlucose();
            }
            state Faulted {
                entry;
            }
            transition Active to Faulted accept "fault";
            transition Faulted to Active accept "reset";
        }
        
        state machine sensorStateMachine : SensorStates;
    }
    
    part def ControlAlgorithmProcessor {
        port glucoseIn : GlucoseDataIn;
        port commandOut : CommandOut;
        port safetyCheck : SafetyCheckOut;
        port uiCommandIn : UICommandIn;
        port logOut : LogOut;
        
        action def CalculateDose {
            in currentReading : GlucoseReading;
            in userCommand : UICommand;
            out calculatedCommand : InsulinCommand;
        }
        
        state def ProcessorStates {
            state Idle;
            state Processing {
                do CalculateDose();
            }
            transition Idle to Processing accept reading;
            transition Processing to Idle accept done;
        }
        
        state machine processorStateMachine : ProcessorStates;
    }
    
    part def SafetyMonitor {
        port safetyCheck : SafetyCheckIn;
        port commandOut : CommandOut;
        port logOut : LogOut;
        
        attribute maxSingleDose : InsulinDose = 10.0;
        attribute minSafeGlucose : GlucoseLevel = 70.0;
        
        action def ValidateCommand {
            in command : InsulinCommand;
            in currentGlucose : GlucoseLevel;
            out approval : SafetyApproval;
        }
    }
    
    part def InsulinPump {
        port commandIn : CommandIn;
        port uiDataOut : UIDataOut;
        port logOut : LogOut;
        
        attribute reservoirCapacity : InsulinReservoirVolume = 200.0;
        attribute currentReservoir : InsulinReservoirVolume = 200.0;
        
        action def DeliverInsulin {
            in command : InsulinCommand;
            out deliveredDose : InsulinDose;
        }
        
        state def PumpStates {
            state Ready;
            state Delivering {
                do DeliverInsulin();
            }
            state Empty;
            transition Ready to Delivering accept command;
            transition Delivering to Ready accept done;
            transition Ready to Empty accept empty;
        }
        
        state machine pumpStateMachine : PumpStates;
    }
    
    part def UserInterface {
        port uiDataIn : UIDataIn;
        port uiCommandOut : UICommandOut;
        port logOut : LogOut;
        
        action def DisplayData {
            in data : UIData;
        }
        action def ReceiveUserInput {
            out command : UICommand;
        }
    }
    
    part def DataLogger {
        port logIn : LogIn;
        port wirelessOut : WirelessOut;
        
        action def LogEvent {
            in entry : LogEntry;
        }
        action def EncryptAndTransmit {
            in entry : LogEntry;
            out data : EncryptedData;
        }
    }
    
    part def WirelessCommunication {
        port wirelessIn : WirelessIn;
        
        attribute protocol : String = "Bluetooth Low Energy";
        
        action def TransmitData {
            in data : EncryptedData;
        }
    }
    
    part def AutomatedInsulinDeliverySystem {
        part sensor : ContinuousGlucoseSensor;
        part processor : ControlAlgorithmProcessor;
        part safetyMonitor : SafetyMonitor;
        part pump : InsulinPump;
        part ui : UserInterface;
        part logger : DataLogger;
        part wireless : WirelessCommunication;
        
        connection sensorToProcessor connect sensor.glucoseOut to processor.glucoseIn;
        connection processorToSafety connect processor.safetyCheck to safetyMonitor.safetyCheck;
        connection safetyToPump connect safetyMonitor.commandOut to pump.commandIn;
        connection pumpToUI connect pump.uiDataOut to ui.uiDataIn;
        connection uiToProcessor connect ui.uiCommandOut to processor.uiCommandIn;
        
        connection sensorLog connect sensor.logOut to logger.logIn;
        connection processorLog connect processor.logOut to logger.logIn;
        connection safetyLog connect safetyMonitor.logOut to logger.logIn;
        connection pumpLog connect pump.logOut to logger.logIn;
        connection uiLog connect ui.logOut to logger.logIn;
        
        connection loggerToWireless connect logger.wirelessOut to wireless.wirelessIn;
    }
    
    requirement def AutomatedInsulinDeliveryRequirements {
        subject aidSystem : AutomatedInsulinDeliverySystem;
        
        requirement maintainGlucoseRange {
            subject aidSystem;
            doc /* The system shall maintain patient blood glucose between 70 and 180 mg/dL. */
            constraint { 70.0 <= GlucoseLevel <= 180.0 }
        }
        
        requirement preventHypoglycemia {
            subject aidSystem;
            doc /* The system shall prevent insulin delivery if glucose is below 70 mg/dL. */
        }
        
        requirement maxBolusLimit {
            subject aidSystem;
            doc /* The system shall limit single insulin dose to 10 U. */
        }
        
        requirement dataEncryption {
            subject aidSystem;
            doc /* The system shall encrypt all logged data before wireless transmission. */
        }
    }
}

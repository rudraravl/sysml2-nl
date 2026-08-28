package OneTouchUltraModel {
    import ScalarValues::*;
    
    value type GlucoseConcentration :> Real {
        attribute unit : String = "mg/dL";
    }
    
    value type ElectricalCurrent :> Real {
        attribute unit : String = "uA";
    }
    
    value type DigitalValue :> Real {
        attribute unit : String = "dimensionless";
    }
    
    value type Duration :> Real {
        attribute unit : String = "s";
    }
    
    item def BloodSample;
    
    item def DisposableTestStrip {
        attribute enzymeCoated : Boolean = true;
    }
    
    item def GlucoseReading {
        attribute concentration : GlucoseConcentration;
        attribute timestamp : Integer;
    }
    
    enum def DisplayCommand {
        SHOW_RESULT;
        SHOW_ERROR;
        SHOW_STANDBY;
        TURN_OFF;
    }
    
    port def BloodSampleInPort {
        in item bloodSample : BloodSample;
    }
    
    port def CurrentFlowOutPort {
        out attribute current : ElectricalCurrent;
    }
    
    port def CurrentFlowInPort {
        in attribute current : ElectricalCurrent;
    }
    
    port def DigitalValueOutPort {
        out attribute digitalSignal : DigitalValue;
    }
    
    port def DigitalValueInPort {
        in attribute digitalSignal : DigitalValue;
    }
    
    port def GlucoseResultOutPort {
        out attribute glucoseResult : GlucoseConcentration;
    }
    
    port def GlucoseResultInPort {
        in attribute glucoseResult : GlucoseConcentration;
    }
    
    port def DisplayCommandOutPort {
        out attribute command : DisplayCommand;
    }
    
    port def DisplayCommandInPort {
        in attribute command : DisplayCommand;
    }
    
    port def GlucoseReadingOutPort {
        out attribute reading : GlucoseReading;
    }
    
    port def GlucoseReadingInPort {
        in attribute reading : GlucoseReading;
    }
    
    part def ElectrochemicalSensor {
        port bloodIn : BloodSampleInPort;
        port currentOut : CurrentFlowOutPort;
        attribute isActive : Boolean = false;
    }
    
    part def AnalogToDigitalConverter {
        port currentIn : CurrentFlowInPort;
        port digitalOut : DigitalValueOutPort;
    }
    
    part def Microcontroller {
        port digitalIn : DigitalValueInPort;
        port glucoseResultOut : GlucoseResultOutPort;
        port displayCmdOut : DisplayCommandOutPort;
        port memoryWriteOut : GlucoseReadingOutPort;
        
        attribute computedConcentration : GlucoseConcentration = 0.0;
        attribute measuringDuration : Duration = 5.0;
        attribute stripInserted : Boolean = false;
        attribute bloodDetected : Boolean = false;
        
        attribute currentDisplayCommand : DisplayCommand = DisplayCommand::TURN_OFF;
        attribute currentGlucoseResult : GlucoseConcentration = 0.0;
        attribute currentReading : GlucoseReading;
        
        bind glucoseResultOut.glucoseResult = currentGlucoseResult;
        bind displayCmdOut.command = currentDisplayCommand;
        bind memoryWriteOut.reading = currentReading;
        
        state machine MeterStateMachine {
            state off;
            state standby;
            state measuring;
            state displayingResult;
            state displayingError;
            
            transition off_to_standby
                from off to standby
                when (stripInserted == true)
                do { currentDisplayCommand = DisplayCommand::SHOW_STANDBY; }
                
            transition standby_to_measuring
                from standby to measuring
                when (bloodDetected == true)
                do { computedConcentration = digitalIn.digitalSignal * 1000.0; }
                
            transition measuring_to_displayingResult
                from measuring to displayingResult
                after measuringDuration
                guard (computedConcentration >= 20 and computedConcentration <= 600)
                do { 
                    currentGlucoseResult = computedConcentration; 
                    currentReading = GlucoseReading { concentration = computedConcentration; timestamp = 0; }; 
                    currentDisplayCommand = DisplayCommand::SHOW_RESULT; 
                }
                
            transition measuring_to_displayingError
                from measuring to displayingError
                after measuringDuration
                guard (computedConcentration < 20 or computedConcentration > 600)
                do { currentDisplayCommand = DisplayCommand::SHOW_ERROR; }
        }
    }
    
    part def LiquidCrystalDisplay {
        port glucoseIn : GlucoseResultInPort;
        port commandIn : DisplayCommandInPort;
        attribute displayedValue : GlucoseConcentration = 0.0;
        attribute displayedMessage : String = "";
    }
    
    part def NonvolatileMemory {
        port readingIn : GlucoseReadingInPort;
        attribute maxReadings : Integer = 450;
        attribute storedReadings : GlucoseReading[0..*];
    }
    
    part def Battery {
        attribute voltage : Real = 3.0 {
            attribute unit : String = "V";
        }
        attribute capacity : Real = 300.0 {
            attribute unit : String = "mAh";
        }
    }
    
    part def OneTouchUltraMeter {
        part electrochemicalSensor : ElectrochemicalSensor;
        part adc : AnalogToDigitalConverter;
        part microcontroller : Microcontroller;
        part lcd : LiquidCrystalDisplay;
        part memory : NonvolatileMemory;
        part battery : Battery;
        
        port stripPort : BloodSampleInPort;
        
        connect stripPort to electrochemicalSensor.bloodIn;
        connect electrochemicalSensor.currentOut to adc.currentIn;
        connect adc.digitalOut to microcontroller.digitalIn;
        connect microcontroller.glucoseResultOut to lcd.glucoseIn;
        connect microcontroller.displayCmdOut to lcd.commandIn;
        connect microcontroller.memoryWriteOut to memory.readingIn;
    }
    
    requirement def MeasurementRangeRequirement {
        doc /* The meter shall measure glucose in the range of 20 to 600 mg/dL. */
        subject meter : OneTouchUltraMeter;
        constraint { meter.microcontroller.computedConcentration >= 20 and meter.microcontroller.computedConcentration <= 600 }
    }
    
    requirement def MemoryCapacityRequirement {
        doc /* The memory shall store up to 450 historical readings. */
        subject meter : OneTouchUltraMeter;
        constraint { meter.memory.maxReadings == 450 }
    }
    
    requirement def MeasurementTimeRequirement {
        doc /* The measuring state shall last approximately 5 seconds. */
        subject meter : OneTouchUltraMeter;
        constraint { meter.microcontroller.measuringDuration == 5.0 }
    }
    
    requirement def PowerRequirement {
        doc /* The system shall be powered by an internal battery. */
        subject meter : OneTouchUltraMeter;
        constraint { meter.battery.voltage > 0 }
    }
    
    requirement def ErrorHandlingRequirement {
        doc /* If the reading is outside the measurable range, display an error. */
        subject meter : OneTouchUltraMeter;
        constraint { if (meter.microcontroller.computedConcentration < 20 or meter.microcontroller.computedConcentration > 600) then meter.microcontroller.currentDisplayCommand == DisplayCommand::SHOW_ERROR }
    }
    
    requirement def StripInsertionRequirement {
        doc /* Meter powers on from Off state to Standby when a test strip is inserted. */
        subject meter : OneTouchUltraMeter;
        constraint { meter.microcontroller.stripInserted == true implies meter.lcd.commandIn.command == DisplayCommand::SHOW_STANDBY }
    }
}

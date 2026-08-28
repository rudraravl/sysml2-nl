package 'Airspeed Indicator System' {
    private import ScalarValues::*;
    
    attribute def PressureValue :> Real;
    attribute def SpeedValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def AltitudeValue :> Real;
    attribute def DensityValue :> Real;
    attribute def SignalValue :> Real;
    
    item def PressureReading {
        attribute value : PressureValue;
    }
    item def ElectronicSignal {
        attribute value : SignalValue;
    }
    item def AirspeedReading {
        attribute value : SpeedValue;
    }
    item def EnvironmentalData {
        attribute density : DensityValue;
        attribute temperature : TemperatureValue;
        attribute altitude : AltitudeValue;
    }
    
    attribute def PowerOnSignal;
    attribute def SelfTestCompleteSignal;
    attribute def IcingDetectedSignal;
    attribute def IcingClearedSignal;
    attribute def StallWarningSignal;
    attribute def OverspeedWarningSignal;
    
    port def PressureOutPort {
        out pressure : PressureReading;
    }
    port def PressureInPort {
        in pressure : PressureReading;
    }
    port def SignalOutPort {
        out signal : ElectronicSignal;
    }
    port def SignalInPort {
        in signal : ElectronicSignal;
    }
    port def AirspeedOutPort {
        out ias : AirspeedReading;
        out tas : AirspeedReading;
    }
    port def AirspeedInPort {
        in ias : AirspeedReading;
        in tas : AirspeedReading;
    }
    port def WarningOutPort {
        out stallWarning : Boolean;
        out overspeedWarning : Boolean;
    }
    port def WarningInPort {
        in stallWarning : Boolean;
        in overspeedWarning : Boolean;
    }
    port def EnvDataInPort {
        in env : EnvironmentalData;
    }
    
    action def 'Measure Total Pressure' {
        out pressure : PressureReading;
    }
    action def 'Measure Static Pressure' {
        out pressure : PressureReading;
    }
    action def 'Calculate Dynamic Pressure' {
        in totalPressure : PressureReading;
        in staticPressure : PressureReading;
        out signal : ElectronicSignal;
    }
    action def 'Calculate IAS' {
        in signal : ElectronicSignal;
        out ias : AirspeedReading;
    }
    action def 'Calculate TAS' {
        in ias : AirspeedReading;
        in env : EnvironmentalData;
        out tas : AirspeedReading;
    }
    action def 'Display IAS' {
        in ias : AirspeedReading;
    }
    action def 'Monitor Speed' {
        in ias : AirspeedReading;
        out stall : Boolean;
        out overspeed : Boolean;
    }
    action def 'Perform Self Test';
    action def 'Activate Heater';
    
    state def 'Heating States' {
        action 'activate heater' : 'Activate Heater';
        entry; then off;
        state off;
        accept IcingDetectedSignal
            do 'activate heater'
            then heating;
        state heating;
        accept IcingClearedSignal
            then off;
    }
    
    state def 'Display States' {
        action 'perform self test' : 'Perform Self Test';
        action 'display IAS' : 'Display IAS';
        entry; then off;
        state off;
        accept PowerOnSignal
            then selfTest;
        state selfTest {
            entry 'perform self test';
        }
        accept SelfTestCompleteSignal
            then normal;
        state normal {
            do 'display IAS';
        }
    }
    
    part def PitotTube {
        port totalPressureOut : PressureOutPort;
        perform action 'measure total pressure' : 'Measure Total Pressure';
        exhibit state 'heating states' : 'Heating States';
    }
    
    part def StaticPort {
        port staticPressureOut : PressureOutPort;
        perform action 'measure static pressure' : 'Measure Static Pressure';
    }
    
    part def PressureTransducer {
        port totalPressureIn : PressureInPort;
        port staticPressureIn : PressureInPort;
        port dynamicPressureSignalOut : SignalOutPort;
        perform action 'calculate dynamic pressure' : 'Calculate Dynamic Pressure';
    }
    
    part def AirDataComputer {
        port dynamicPressureSignalIn : SignalInPort;
        port envDataIn : EnvDataInPort;
        port airspeedOut : AirspeedOutPort;
        port warningOut : WarningOutPort;
        perform action 'calculate IAS' : 'Calculate IAS';
        perform action 'calculate TAS' : 'Calculate TAS';
        perform action 'monitor speed' : 'Monitor Speed';
    }
    
    part def CockpitDisplay {
        port airspeedIn : AirspeedInPort;
        port warningIn : WarningInPort;
        exhibit state 'display states' : 'Display States';
    }
    
    requirement def 'Indicated Airspeed Display Requirement' {
        doc
        /* The system shall display indicated airspeed to the pilot. */
    }
    requirement def 'Stall Warning Requirement' {
        doc
        /* The system shall provide a stall warning when airspeed is below the stall threshold. */
    }
    requirement def 'Overspeed Warning Requirement' {
        doc
        /* The system shall provide an overspeed warning when airspeed exceeds the overspeed threshold. */
    }
    requirement def 'Pitot Tube Heating Requirement' {
        doc
        /* The Pitot tube shall be heated to prevent ice buildup in icing conditions. */
    }
    
    requirement 'indicated airspeed display req' : 'Indicated Airspeed Display Requirement';
    requirement 'stall warning req' : 'Stall Warning Requirement';
    requirement 'overspeed warning req' : 'Overspeed Warning Requirement';
    requirement 'pitot tube heating req' : 'Pitot Tube Heating Requirement';
    
    part 'airspeed indicator system' {
        part pitotTube : PitotTube;
        part staticPort : StaticPort;
        part pressureTransducer : PressureTransducer;
        part airDataComputer : AirDataComputer;
        part cockpitDisplay : CockpitDisplay;
        
        connect pitotTube.totalPressureOut to pressureTransducer.totalPressureIn;
        connect staticPort.staticPressureOut to pressureTransducer.staticPressureIn;
        connect pressureTransducer.dynamicPressureSignalOut to airDataComputer.dynamicPressureSignalIn;
        connect airDataComputer.airspeedOut to cockpitDisplay.airspeedIn;
        connect airDataComputer.warningOut to cockpitDisplay.warningIn;
        
        satisfy 'indicated airspeed display req' by cockpitDisplay;
        satisfy 'stall warning req' by airDataComputer;
        satisfy 'overspeed warning req' by airDataComputer;
        satisfy 'pitot tube heating req' by pitotTube;
    }
}

package AirspeedIndicatorSystem {
    import ScalarValues::*;

    // ===== Units =====
    unit Pa;
    unit kt;
    unit K;
    unit ft;
    unit kg_per_m3;
    unit V;
    unit A;
    unit W;

    // ===== Value Types =====
    value def Pressure :> Real;
    value def Airspeed :> Real;
    value def Temperature :> Real;
    value def Altitude :> Real;
    value def AirDensity :> Real;
    value def Voltage :> Real;
    value def ElectricCurrent :> Real;
    value def Power :> Real;

    // ===== Item Types =====
    item def PressureSignal {
        attribute voltage : Voltage;
        attribute dynamicPressure : Pressure;
    }

    item def AirspeedData {
        attribute ias : Airspeed;
        attribute tas : Airspeed;
    }

    item def EnvironmentalData {
        attribute density : AirDensity;
        attribute temperature : Temperature;
        attribute altitude : Altitude;
    }

    item def WarningAlert {
        attribute warningType : String;
        attribute active : Boolean;
    }

    // ===== Signal / Event Types =====
    item def PowerOnSignal;
    item def SelfTestCompleteSignal;
    item def SelfTestFailedSignal;
    item def SpeedBelowStallSignal;
    item def SpeedAboveMaxSignal;
    item def SpeedRecoveredSignal;

    // ===== Port Definitions =====
    port def PressureOutPort {
        out item pressure : Pressure;
    }

    port def PressureInPort {
        in item pressure : Pressure;
    }

    port def SignalOutPort {
        out item signal : PressureSignal;
    }

    port def SignalInPort {
        in item signal : PressureSignal;
    }

    port def AirspeedOutPort {
        out item data : AirspeedData;
    }

    port def AirspeedInPort {
        in item data : AirspeedData;
    }

    port def EnvDataInPort {
        in item env : EnvironmentalData;
    }

    port def WarningOutPort {
        out item warning : WarningAlert;
    }

    port def WarningInPort {
        in item warning : WarningAlert;
    }

    port def PowerInPort {
        in item voltage : Voltage;
        in item current : ElectricCurrent;
    }

    // ===== Part: Pitot Heater =====
    part def PitotHeater {
        port powerIn : PowerInPort;
        attribute isOn : Boolean = false;
        attribute ratedPower : Power = 100[W];

        action activate {
            out isOn : Boolean;
        }

        action deactivate {
            out isOn : Boolean;
        }

        action generateHeat {
            in power : Power;
            out heatOutput : Power;
        }
    }

    // ===== Part: Pitot Tube =====
    part def PitotTube {
        port totalPressureOut : PressureOutPort;
        port powerIn : PowerInPort;

        attribute isIced : Boolean = false;
        attribute forwardFacing : Boolean = true;
        attribute designSpeed : Airspeed = 600[kt];

        part heater : PitotHeater;

        connection powerDelegation
            connect powerIn to heater.powerIn;

        action measureTotalPressure {
            in heatingActive : Boolean;
            out totalPressure : Pressure;
        }

        action detectIcing {
            out isIced : Boolean;
        }

        action activateHeater {
            in icingDetected : Boolean;
            out heaterCommand : Boolean;
        }

        action defrostPitot {
            in heaterOn : Boolean;
            out isIced : Boolean;
        }
    }

    // ===== Part: Static Port =====
    part def StaticPort {
        port staticPressureOut : PressureOutPort;

        attribute location : String = "fuselage";
        attribute portCount : Integer = 2;
        attribute undisturbed : Boolean = true;

        action measureStaticPressure {
            out staticPressure : Pressure;
        }

        action verifyAmbient {
            out isValid : Boolean;
        }
    }

    // ===== Part: Pressure Transducer =====
    part def PressureTransducer {
        port totalPressureIn : PressureInPort;
        port staticPressureIn : PressureInPort;
        port signalOut : SignalOutPort;

        attribute calibrationFactor : Real = 1.0;
        attribute operatingRange : Pressure = 150000[Pa];
        attribute supplyVoltage : Voltage = 5[V];

        action calculateDynamicPressure {
            in totalPressure : Pressure;
            in staticPressure : Pressure;
            out dynamicPressure : Pressure;
        }

        action convertToSignal {
            in dynamicPressure : Pressure;
            out signal : PressureSignal;
        }

        action calibrate {
            in referencePressure : Pressure;
            out calibrationFactor : Real;
        }
    }

    // ===== Part: Air Data Computer =====
    part def AirDataComputer {
        port signalIn : SignalInPort;
        port envDataIn : EnvDataInPort;
        port airspeedOut : AirspeedOutPort;
        port warningOut : WarningOutPort;

        attribute stallSpeedThreshold : Airspeed = 60[kt];
        attribute overspeedThreshold : Airspeed = 350[kt];
        attribute currentIAS : Airspeed = 0[kt];
        attribute currentTAS : Airspeed = 0[kt];
        attribute seaLevelDensity : AirDensity = 1.225[kg_per_m3];

        action calculateIAS {
            in signal : PressureSignal;
            out ias : Airspeed;
        }

        action calculateTAS {
            in ias : Airspeed;
            in env : EnvironmentalData;
            out tas : Airspeed;
        }

        action monitorSpeedLimits {
            in ias : Airspeed;
            out stallWarning : WarningAlert;
            out overspeedWarning : WarningAlert;
        }

        action processPressureData {
            in signal : PressureSignal;
            in env : EnvironmentalData;
            out data : AirspeedData;
            out warning : WarningAlert;

            action calcIAS : calculateIAS;
            action calcTAS : calculateTAS;
            action monitor : monitorSpeedLimits;

            succession first calcIAS then calcTAS;
            succession first calcIAS then monitor;

            flow from signal to calcIAS.signal;
            flow from calcIAS.ias to calcTAS.ias;
            flow from env to calcTAS.env;
            flow from calcIAS.ias to monitor.ias;
            flow from calcIAS.ias to data.ias;
            flow from calcTAS.tas to data.tas;
            flow from monitor.stallWarning to warning;
            flow from monitor.overspeedWarning to warning;
        }

        state warningState {
            entry; then Normal;

            state Normal {
                entry action clearWarnings {
                    out warning : WarningAlert;
                }
            }

            transition first Normal
                if currentIAS < stallSpeedThreshold
                accept SpeedBelowStallSignal
                then StallWarning;

            state StallWarning {
                entry action activateStallWarning {
                    out warning : WarningAlert;
                }
                do action maintainStallWarning {
                    in ias : Airspeed;
                    out warning : WarningAlert;
                }
            }

            transition first StallWarning
                if currentIAS >= stallSpeedThreshold
                accept SpeedRecoveredSignal
                then Normal;

            transition first Normal
                if currentIAS > overspeedThreshold
                accept SpeedAboveMaxSignal
                then OverspeedWarning;

            state OverspeedWarning {
                entry action activateOverspeedWarning {
                    out warning : WarningAlert;
                }
                do action maintainOverspeedWarning {
                    in ias : Airspeed;
                    out warning : WarningAlert;
                }
            }

            transition first OverspeedWarning
                if currentIAS <= overspeedThreshold
                accept SpeedRecoveredSignal
                then Normal;
        }
    }

    // ===== Part: Cockpit Display =====
    part def CockpitDisplay {
        port airspeedIn : AirspeedInPort;
        port warningIn : WarningInPort;
        port powerIn : PowerInPort;

        attribute displayedIAS : Airspeed = 0[kt];
        attribute displayedTAS : Airspeed = 0[kt];
        attribute selfTestPassed : Boolean = false;
        attribute isPowered : Boolean = false;
        attribute refreshRate : Integer = 60;
        attribute backlightBrightness : Real = 0.8;

        action runSelfTest {
            out result : Boolean;
        }

        action verifyDisplay {
            out result : Boolean;
        }

        action showAirspeed {
            in ias : Airspeed;
            out displayedIAS : Airspeed;
        }

        action updateDisplay {
            in data : AirspeedData;
            out displayedIAS : Airspeed;
            out displayedTAS : Airspeed;
        }

        action showWarning {
            in warning : WarningAlert;
        }

        action renderTapeIndicator {
            in ias : Airspeed;
        }

        action renderDigitalReadout {
            in ias : Airspeed;
            in tas : Airspeed;
        }

        state displayState {
            entry; then PowerOff;

            state PowerOff {
                entry action clearScreen;
            }

            transition first PowerOff
                accept PowerOnSignal
                then SelfTest;

            state SelfTest {
                entry action runSelfTest {
                    out result : Boolean;
                }
                do action verifyDisplay {
                    out result : Boolean;
                }
            }

            transition first SelfTest
                if selfTestPassed == true
                accept SelfTestCompleteSignal
                then Operational;

            transition first SelfTest
                if selfTestPassed == false
                accept SelfTestFailedSignal
                then PowerOff;

            state Operational {
                entry action showAirspeed {
                    in ias : Airspeed;
                    out displayedIAS : Airspeed;
                }
                do action updateDisplay {
                    in data : AirspeedData;
                    out displayedIAS : Airspeed;
                    out displayedTAS : Airspeed;
                }
            }

            transition first Operational
                accept PowerOnSignal
                then PowerOff;
        }

        action clearScreen;
    }

    // ===== Top-level System =====
    part def AirspeedIndicatorSystem {
        part pitotTube : PitotTube;
        part staticPort : StaticPort;
        part transducer : PressureTransducer;
        part airDataComputer : AirDataComputer;
        part cockpitDisplay : CockpitDisplay;

        connection pitotToTransducer
            connect pitotTube.totalPressureOut
            to transducer.totalPressureIn;

        connection staticToTransducer
            connect staticPort.staticPressureOut
            to transducer.staticPressureIn;

        connection transducerToADC
            connect transducer.signalOut
            to airDataComputer.signalIn;

        connection adcToDisplay
            connect airDataComputer.airspeedOut
            to cockpitDisplay.airspeedIn;

        connection adcWarningToDisplay
            connect airDataComputer.warningOut
            to cockpitDisplay.warningIn;
    }

    // ===== Requirements =====
    requirement def MeasureTotalPressureRequirement {
        subject pitotTube : PitotTube;
        doc /* The pitot tube shall measure total air pressure created by the aircraft forward motion through the airstream. */;
    }

    requirement def MeasureStaticPressureRequirement {
        subject staticPort : StaticPort;
        doc /* The static pressure ports on the fuselage shall measure ambient undisturbed air pressure. */;
    }

    requirement def PreventIcingRequirement {
        subject heater : PitotHeater;
        doc /* The pitot tube shall be equipped with a heating element to prevent ice buildup during icing conditions. */;
    }

    requirement def CalculateDynamicPressureRequirement {
        subject transducer : PressureTransducer;
        doc /* The pressure transducer shall calculate the difference between total and static pressure to determine dynamic pressure. */;
    }

    requirement def ConvertToSignalRequirement {
        subject transducer : PressureTransducer;
        doc /* The transducer shall convert the pressure differential into an electronic signal proportional to dynamic pressure. */;
    }

    requirement def CalculateIASRequirement {
        subject adc : AirDataComputer;
        doc /* The Air Data Computer shall process pressure data to calculate Indicated Airspeed as the primary speed reference for the pilot. */;
    }

    requirement def CalculateTASRequirement {
        subject adc : AirDataComputer;
        doc /* The Air Data Computer shall calculate True Airspeed using air density, temperature, and altitude data. */;
    }

    requirement def DisplaySelfTestRequirement {
        subject display : CockpitDisplay;
        doc /* Upon powering on, the display shall run a brief self-test before entering normal operational state. */;
    }

    requirement def DisplayIASRequirement {
        subject display : CockpitDisplay;
        doc /* During normal operation, the display shall continuously show Indicated Airspeed to the pilot. */;
    }

    requirement def StallWarningRequirement {
        subject adc : AirDataComputer;
        doc /* The system shall provide stall warnings when the aircraft is flying below the stall speed threshold. */;
    }

    requirement def OverspeedWarningRequirement {
        subject adc : AirDataComputer;
        doc /* The system shall provide overspeed warnings when the aircraft is flying above the overspeed threshold. */;
    }

    requirement AirspeedIndicatorSystemSpec {
        subject system : AirspeedIndicatorSystem;
        doc /* The Airspeed Indicator System shall measure and display the aircraft speed relative to the surrounding air and provide integrated safety warnings. */;

        requirement r1 : MeasureTotalPressureRequirement {
            subject pitotTube : PitotTube = system.pitotTube;
        }
        requirement r2 : MeasureStaticPressureRequirement {
            subject staticPort : StaticPort = system.staticPort;
        }
        requirement r3 : PreventIcingRequirement {
            subject heater : PitotHeater = system.pitotTube.heater;
        }
        requirement r4 : CalculateDynamicPressureRequirement {
            subject transducer : PressureTransducer = system.transducer;
        }
        requirement r5 : ConvertToSignalRequirement {
            subject transducer : PressureTransducer = system.transducer;
        }
        requirement r6 : CalculateIASRequirement {
            subject adc : AirDataComputer = system.airDataComputer;
        }
        requirement r7 : CalculateTASRequirement {
            subject adc : AirDataComputer = system.airDataComputer;
        }
        requirement r8 : DisplaySelfTestRequirement {
            subject display : CockpitDisplay = system.cockpitDisplay;
        }
        requirement r9 : DisplayIASRequirement {
            subject display : CockpitDisplay = system.cockpitDisplay;
        }
        requirement r10 : StallWarningRequirement {
            subject adc : AirDataComputer = system.airDataComputer;
        }
        requirement r11 : OverspeedWarningRequirement {
            subject adc : AirDataComputer = system.airDataComputer;
        }
    }
}

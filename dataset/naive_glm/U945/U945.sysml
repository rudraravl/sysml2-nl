package WeatherRadarSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----

    value def FrequencyUnit = Hz;
    value def PowerUnit = W;
    value def DistanceUnit = km;
    value def TimeUnit = s;
    value def AngleUnit = deg;
    value def VelocityUnit = m/s;
    value def DecibelUnit = dB;
    value def VoltageUnit = V;

    value def RF_Frequency :> Real { unit 'GHz'; }
    value def Pulse_Power :> Real { unit 'MW'; }
    value def Pulse_Duration :> Real { unit 'us'; }
    value def Pulse_Repetition_Interval :> Real { unit 'ms'; }
    value def Beamwidth :> Real { unit 'deg'; }
    value def Antenna_Diameter :> Real { unit 'm'; }
    value def Range :> Real { unit 'km'; }
    value def Reflectivity :> Real { unit 'dBZ'; }
    value def Radial_Velocity :> Real { unit 'm/s'; }
    value def Update_Period :> Real { unit 's'; }
    value def Input_Voltage :> Real { unit 'V'; }
    value def DC_Voltage :> Real { unit 'V'; }
    value def Antenna_Gain :> Real { unit 'dB'; }
    value def Noise_Figure :> Real { unit 'dB'; }

    // ---- Item Definitions ----

    item def RF_Pulse {
        attribute frequency : RF_Frequency;
        attribute power : Pulse_Power;
        attribute duration : Pulse_Duration;
    }

    item def Echo_Signal {
        attribute amplitude : Reflectivity;
        attribute timeDelay : Real { unit 'us'; }
        attribute dopplerShift : Real { unit 'Hz'; }
    }

    item def Amplified_Echo {
        attribute amplitude : Reflectivity;
        attribute timeDelay : Real { unit 'us'; }
        attribute dopplerShift : Real { unit 'Hz'; }
        attribute gain : Real { unit 'dB'; }
    }

    item def Weather_Product {
        attribute range : Range;
        attribute reflectivity : Reflectivity;
        attribute radialVelocity : Radial_Velocity;
        attribute precipitationType : PrecipitationType;
    }

    enum def PrecipitationType {
        rain;
        snow;
        hail;
        mixed;
        none;
    }

    item def Weather_Map {
        attribute reflectivityMap : Reflectivity[0..*];
        attribute velocityMap : Radial_Velocity[0..*];
        attribute timestamp : Real { unit 's'; }
    }

    item def AC_Power {
        attribute voltage : Input_Voltage;
        attribute frequency : Real { unit 'Hz'; }
    }

    item def DC_Power {
        attribute voltage : DC_Voltage;
        attribute current : Real { unit 'A'; }
    }

    item def Antenna_Position {
        attribute azimuth : AngleUnit;
        attribute elevation : AngleUnit;
    }

    item def Scan_Command {
        attribute pattern : ScanPattern;
        attribute startAzimuth : AngleUnit;
        attribute elevationStep : AngleUnit;
    }

    enum def ScanPattern {
        volumeScan360;
        sectorScan;
        pointScan;
    }

    // ---- Port Definitions ----

    port def RF_OutPort {
        out item rfPulse : RF_Pulse;
    }

    port def RF_InPort {
        in item rfPulse : RF_Pulse;
    }

    port def Echo_OutPort {
        out item echo : Echo_Signal;
    }

    port def Echo_InPort {
        in item echo : Echo_Signal;
    }

    port def Amplified_Echo_OutPort {
        out item amplifiedEcho : Amplified_Echo;
    }

    port def Amplified_Echo_InPort {
        in item amplifiedEcho : Amplified_Echo;
    }

    port def Weather_Product_OutPort {
        out item product : Weather_Product;
    }

    port def Weather_Product_InPort {
        in item product : Weather_Product;
    }

    port def AC_Power_InPort {
        in item acPower : AC_Power;
    }

    port def DC_Power_OutPort {
        out item dcPower : DC_Power;
    }

    port def DC_Power_InPort {
        in item dcPower : DC_Power;
    }

    port def Scan_Command_InPort {
        in item command : Scan_Command;
    }

    port def Antenna_Position_OutPort {
        out item position : Antenna_Position;
    }

    port def Antenna_Position_InPort {
        in item position : Antenna_Position;
    }

    port def Weather_Map_OutPort {
        out item map : Weather_Map;
    }

    // ---- Requirements ----

    requirement def RadarDetectionRequirement {
        attribute minRange : Range = 0.5;
        attribute maxRange : Range = 230;
        requirement
            The system shall detect atmospheric precipitation at ranges between {minRange} and {maxRange}.
    }

    requirement def AntennaScanRequirement {
        attribute dishDiameter : Antenna_Diameter = 8.5;
        attribute beamwidth : Beamwidth = 1.0;
        attribute scanRange : AngleUnit = 360;
        requirement
            The antenna system shall support full 360-degree volume scans with a beamwidth of {beamwidth}.
    }

    requirement def DopplerRequirement {
        attribute velocityRange : Radial_Velocity = 50.0;
        requirement
            The signal processor shall measure radial wind velocity up to {velocityRange} via Doppler shift analysis.
    }

    requirement def UpdateRequirement {
        attribute updatePeriod : Update_Period = 5.0;
        requirement
            The system shall provide updated weather products every {updatePeriod} seconds during active scanning.
    }

    requirement def PowerRequirement {
        attribute inputVoltage : Input_Voltage = 480;
        requirement
            The power subsystem shall convert {inputVoltage} V AC input to stable DC power for all electronics.
    }

    requirement def ClassificationRequirement {
        requirement
            The signal processor shall classify precipitation type as rain, snow, hail, mixed, or none based on reflectivity and velocity signatures.
    }

    // ---- Part Definitions ----

    part def Transmitter {
        port rfOut : RF_OutPort;
        port powerIn : DC_Power_InPort;

        attribute operatingFrequency : RF_Frequency = 2.7;
        attribute peakPower : Pulse_Power = 1.0;
        attribute pulseDuration : Pulse_Duration = 1.5;
        attribute pri : Pulse_Repetition_Interval = 1.0;

        action def GeneratePulse {
            out item pulse : RF_Pulse;
        }

        action generatePulses : GeneratePulse {
            assign pulse.frequency := operatingFrequency;
            assign pulse.power := peakPower;
            assign pulse.duration := pulseDuration;
        }
    }

    part def AntennaSystem {
        port rfIn : RF_InPort;
        port rfOut : RF_Echo_OutPort;
        port scanCommand : Scan_Command_InPort;
        port positionOut : Antenna_Position_OutPort;
        port powerIn : DC_Power_InPort;

        attribute dishDiameter : Antenna_Diameter = 8.5;
        attribute beamwidth : Beamwidth = 1.0;
        attribute gain : Antenna_Gain = 45.0;
        attribute currentAzimuth : AngleUnit = 0;
        attribute currentElevation : AngleUnit = 0;

        action def PositionAntenna {
            in item command : Scan_Command;
            out item position : Antenna_Position;
        }

        action def TransmitBeam {
            in item pulse : RF_Pulse;
        }

        action def ReceiveEcho {
            out item echo : Echo_Signal;
        }

        action positionAntenna : PositionAntenna;
        action transmitBeam : TransmitBeam;
        action receiveEcho : ReceiveEcho;
    }

    port def RF_Echo_OutPort {
        out item echo : Echo_Signal;
    }

    part def Receiver {
        port echoIn : Echo_InPort;
        port amplifiedOut : Amplified_Echo_OutPort;
        port powerIn : DC_Power_InPort;

        attribute noiseFigure : Noise_Figure = 2.0;
        attribute gain : Real { unit 'dB'; } = 80.0;
        attribute bandwidth : Real { unit 'MHz'; } = 10.0;

        action def AmplifyEcho {
            in item echo : Echo_Signal;
            out item amplified : Amplified_Echo;
        }

        action amplifyEcho : AmplifyEcho {
            assign amplified.amplitude := echo.amplitude;
            assign amplified.timeDelay := echo.timeDelay;
            assign amplified.dopplerShift := echo.dopplerShift;
            assign amplified.gain := gain;
        }
    }

    part def SignalProcessor {
        port echoIn : Amplified_Echo_InPort;
        port productOut : Weather_Product_OutPort;
        port positionIn : Antenna_Position_InPort;
        port powerIn : DC_Power_InPort;

        attribute speedOfLight : Real { unit 'm/s'; } = 3.0e8;
        attribute maxRange : Range = 230.0;

        action def CalculateRange {
            in item echo : Amplified_Echo;
            out range : Range;
        }

        action def CalculateReflectivity {
            in item echo : Amplified_Echo;
            out reflectivity : Reflectivity;
        }

        action def CalculateVelocity {
            in item echo : Amplified_Echo;
            out velocity : Radial_Velocity;
        }

        action def ClassifyPrecipitation {
            in reflectivity : Reflectivity;
            in velocity : Radial_Velocity;
            out precipType : PrecipitationType;
        }

        action def GenerateProduct {
            in range : Range;
            in reflectivity : Reflectivity;
            in velocity : Radial_Velocity;
            in precipType : PrecipitationType;
            out item product : Weather_Product;
        }

        action calcRange : CalculateRange;
        action calcReflectivity : CalculateReflectivity;
        action calcVelocity : CalculateVelocity;
        action classify : ClassifyPrecipitation;
        action generate : GenerateProduct;

        flow calcRange.range to generate.range;
        flow calcReflectivity.reflectivity to generate.reflectivity;
        flow calcVelocity.velocity to generate.velocity;
        flow classify.precipType to generate.precipType;
    }

    part def DisplayUnit {
        port productIn : Weather_Product_InPort;
        port mapOut : Weather_Map_OutPort;
        port powerIn : DC_Power_InPort;

        action def RenderMap {
            in item product : Weather_Product;
            out item map : Weather_Map;
        }

        action renderMap : RenderMap;
    }

    part def PowerSubsystem {
        port acIn : AC_Power_InPort;
        port dcOut : DC_Power_OutPort;

        attribute inputVoltage : Input_Voltage = 480.0;
        attribute outputVoltage : DC_Voltage = 48.0;
        attribute efficiency : Real = 0.92;

        action def ConvertPower {
            in item ac : AC_Power;
            out item dc : DC_Power;
        }

        action convertPower : ConvertPower {
            assign dc.voltage := outputVoltage;
        }
    }

    part def WeatherRadar {
        port acPowerInput : AC_Power_InPort;
        port scanCommandInput : Scan_Command_InPort;
        port weatherMapOutput : Weather_Map_OutPort;

        part transmitter : Transmitter;
        part antenna : AntennaSystem;
        part receiver : Receiver;
        part processor : SignalProcessor;
        part display : DisplayUnit;
        part power : PowerSubsystem;

        // Power distribution
        connection acToPower connect acPowerInput to power.acIn;
        connection powerToTransmitter connect power.dcOut to transmitter.powerIn;
        connection powerToAntenna connect power.dcOut to antenna.powerIn;
        connection powerToReceiver connect power.dcOut to receiver.powerIn;
        connection powerToProcessor connect power.dcOut to processor.powerIn;
        connection powerToDisplay connect power.dcOut to display.powerIn;

        // Signal path
        connection rfToAntenna connect transmitter.rfOut to antenna.rfIn;
        connection echoToReceiver connect antenna.rfOut to receiver.echoIn;
        connection amplifiedToProcessor connect receiver.amplifiedOut to processor.echoIn;
        connection positionToProcessor connect antenna.positionOut to processor.positionIn;
        connection productToDisplay connect processor.productOut to display.productIn;
        connection mapToOutput connect display.mapOut to weatherMapOutput;

        // Scan command
        connection scanToAntenna connect scanCommandInput to antenna.scanCommand;

        // Requirements satisfaction
        satisfy RadarDetectionRequirement by processor;
        satisfy AntennaScanRequirement by antenna;
        satisfy DopplerRequirement by processor;
        satisfy UpdateRequirement by WeatherRadar;
        satisfy PowerRequirement by power;
        satisfy ClassificationRequirement by processor;

        // ---- State Machine ----

        state def RadarStates {
            entry action initialize { /* cold start initialization */ }

            state offline {
                entry action powerOff { /* system unpowered */ }
                transition offline_to_standby
                    first offline
                    when power.acIn->acPower.voltage > 0
                    then standby;
            }

            state standby {
                entry action warmUp {
                    /* power stabilized, electronics warmed up, awaiting scan command */
                }
                do action monitorReady { /* ready to scan */ }
                transition standby_to_active
                    first standby
                    when scanCommandInput->command.pattern != ScanPattern::pointScan
                    then activeScanning;
                transition standby_to_offline
                    first standby
                    when power.acIn->acPower.voltage == 0
                    then offline;
            }

            state activeScanning {
                entry action startScan { /* begin volume scan */ }

                do action scanLoop {
                    // Continuous scan loop: transmit, receive, process, update
                    loop {
                        // Position antenna for next beam
                        antenna.positionAntenna();
                        // Transmit pulse
                        transmitter.generatePulses();
                        antenna.transmitBeam();
                        // Receive echo
                        antenna.receiveEcho();
                        // Amplify echo
                        receiver.amplifyEcho();
                        // Process echo
                        processor.calcRange();
                        processor.calcReflectivity();
                        processor.calcVelocity();
                        processor.classify();
                        processor.generate();
                        // Render weather map
                        display.renderMap();
                    } until (elapsed == 5.0 [s])
                }

                transition active_to_standby
                    first activeScanning
                    when scanCommandInput->command.pattern == ScanPattern::pointScan
                    then standby;
            }

            transition active_to_offline
                first activeScanning
                when power.acIn->acPower.voltage == 0
                then offline;
        }

        state machine radarStateMachine : RadarStates;
    }

}

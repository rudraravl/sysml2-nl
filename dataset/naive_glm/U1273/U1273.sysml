package BelkinWemoSmartPlug {

    public import ScalarValues::*;
    public import Collections::*;

    package Units {
        attribute def VoltageValue :> Real { doc /* Voltage in volts (V) */ }
        attribute def CurrentValue :> Real { doc /* Current in amperes (A) */ }
        attribute def PowerValue :> Real { doc /* Active power in watts (W) */ }
        attribute def EnergyValue :> Real { doc /* Energy in watt-hours (Wh) */ }
        attribute def TimeValue :> Real { doc /* Time in seconds (s) */ }
        attribute def FrequencyValue :> Real { doc /* Frequency in hertz (Hz) */ }
    }

    package Enums {
        enum def CommandType {
            TurnOn;
            TurnOff;
            Toggle;
            SetSchedule;
            QueryStatus;
            Reset;
        }

        enum def PlugState {
            Off;
            On;
            Connecting;
            Fault;
            Maintenance;
        }

        enum def RelayState {
            Open;
            Closed;
        }

        enum def LEDColor {
            Off;
            Blue;
            Green;
            Amber;
            Red;
            BlinkingBlue;
            BlinkingRed;
        }

        enum def MeasurementMode {
            Idle;
            Continuous;
            Periodic;
        }

        enum def WiFiLinkState {
            Unprovisioned;
            Associating;
            Connected;
            Disconnected;
            Failed;
        }

        enum def ApplianceClass {
            Lamp;
            Fan;
            Heater;
            Unknown;
        }
    }

    package Items {
        import Units::*;
        import Enums::*;

        item def ACPower {
            attribute voltage : VoltageValue;
            attribute frequency : FrequencyValue;
        }

        item def ScheduleItem {
            attribute id : String;
            attribute startTime : TimeValue;
            attribute duration : TimeValue;
            attribute action : CommandType;
            attribute enabled : Boolean;
            attribute recurrence : String;
        }

        item def ControlCommand {
            attribute commandId : String;
            attribute commandType : CommandType;
            attribute scheduleItems : ScheduleItem[0..8];
            attribute timestamp : TimeValue;
            attribute source : String;
        }

        item def StatusReport {
            attribute reportId : String;
            attribute plugState : PlugState;
            attribute relayState : RelayState;
            attribute isPoweredOn : Boolean;
            attribute instantVoltage : VoltageValue;
            attribute instantCurrent : CurrentValue;
            attribute instantPower : PowerValue;
            attribute totalEnergy : EnergyValue;
            attribute uptime : TimeValue;
            attribute timestamp : TimeValue;
            attribute deviceId : String;
            attribute rssi : Real;
        }

        item def RelayCommand {
            attribute relayState : RelayState;
        }

        item def RelayStatus {
            attribute relayState : RelayState;
            attribute faultDetected : Boolean;
        }

        item def PowerMeasurement {
            attribute voltage : VoltageValue;
            attribute current : CurrentValue;
            attribute power : PowerValue;
            attribute energyDelta : EnergyValue;
            attribute timestamp : TimeValue;
        }

        item def EnergyData {
            attribute instantaneousPower : PowerValue;
            attribute cumulativeEnergy : EnergyValue;
            attribute measurementStartTime : TimeValue;
            attribute lastUpdate : TimeValue;
        }

        item def LEDCommand {
            attribute color : LEDColor;
            attribute blinkPeriod : TimeValue;
        }

        item def WiFiConfig {
            attribute ssid : String;
            attribute password : String;
            attribute securityProtocol : String;
            attribute configured : Boolean;
        }

        item def WiFiFrame {
            attribute destination : String;
            attribute payload : ControlCommand | StatusReport;
            attribute quality : Real;
            attribute timestamp : TimeValue;
        }
    }

    package Ports {
        import Items::*;

        port def ACInPort {
            in flow acPower : ACPower;
        }

        port def ACOutPort {
            out flow acPower : ACPower;
        }

        port def CommandPort {
            in flow command : ControlCommand;
            out flow status : StatusReport;
        }

        port def RelayControlPort {
            out flow relayCommand : RelayCommand;
            in flow relayStatus : RelayStatus;
        }

        port def MeasurementPort {
            in flow measurement : PowerMeasurement;
        }

        port def LEDControlPort {
            out flow ledCommand : LEDCommand;
        }

        port def AppliancePort {
            in flow appliancePower : ACPower;
        }

        port def SupplyPort {
            out flow suppliedPower : ACPower;
        }

        port def WiFiRadioPort {
            in flow inbound : WiFiFrame;
            out flow outbound : WiFiFrame;
        }
    }

    package Parts {
        import Ports::*;
        import Items::*;
        import Enums::*;
        import Units::*;

        part def WiFiModule {
            attribute moduleModel : String = "WEMO-WIFI";
            attribute supportedFrequency : FrequencyValue = 2400;
            attribute configuredSsid : String;
            attribute configuredPassword : String;
            attribute rssi : Real;
            attribute provisioned : Boolean = false;
            attribute connected : Boolean = false;
            attribute linkState : WiFiLinkState = Unprovisioned;

            port radioPort : WiFiRadioPort;
            port localPort : CommandPort;

            state def Operation {
                initial state Unprovisioned;
                state Associating;
                state Connected;
                state Disconnected;
                state Failed;

                transition Unprovisioned -> Associating when (configuredSsid != "" && configuredPassword != "");
                transition Associating -> Connected when (connected);
                transition Associating -> Failed when (rssi < -85);
                transition Connected -> Disconnected when (!connected);
                transition Disconnected -> Associating when (configuredSsid != "" && !connected);
                transition Failed -> Unprovisioned on radioPort.inbound[payload : ControlCommand][commandType == Reset];
            }

            exhibit Operation;

            action def ReceiveFrame {
                in frame : WiFiFrame;
                out command : ControlCommand;
            }

            action def EncodeStatus {
                in status : StatusReport;
                out frame : WiFiFrame;
            }

            action def ProcessFrame {
                in frame : WiFiFrame;
                out command : ControlCommand;
            }
        }

        part def ControlProcessor {
            attribute processorModel : String = "WEMO-PROC";
            attribute deviceId : String;
            attribute firmwareVersion : String = "1.0.0";
            attribute currentState : PlugState = Off;
            attribute lastStatus : StatusReport;
            attribute schedules : ScheduleItem[0..16];
            attribute energyAccumulator : EnergyData;
            attribute lastMeasurement : PowerMeasurement;
            attribute faultFlags : String[0..*];
            attribute uptime : TimeValue = 0;

            port wifiPort : CommandPort;
            port relayPort : RelayControlPort;
            port measurementPort : MeasurementPort;
            port ledPort : LEDControlPort;

            state def Operation {
                initial state Off;
                state On;
                state Connecting;
                state Fault;
                state Maintenance;

                transition Off -> On on wifiPort.command[commandType == TurnOn];
                transition On -> Off on wifiPort.command[commandType == TurnOff];
                transition Off -> On on wifiPort.command[commandType == Toggle];
                transition On -> Off on wifiPort.command[commandType == Toggle];
                transition Off -> Connecting when (currentState == Off && schedules.size() > 0);
                transition Connecting -> On when (relayStatus.relayState == Closed);
                transition On -> Off on wifiPort.command[commandType == Reset];
                transition Off -> Fault when (faultFlags.size() > 0);
                transition On -> Fault when (faultFlags.size() > 0);
                transition Fault -> Maintenance on wifiPort.command[commandType == Reset];
                transition Maintenance -> Off when (faultFlags.size() == 0);
            }

            exhibit Operation;

            action def ProcessCommand {
                in command : ControlCommand;
                out relayCmd : RelayCommand;
                out ledCmd : LEDCommand;
                out status : StatusReport;
            }

            action def EvaluateSchedule {
                in schedule : ScheduleItem[0..*];
                out relayCmd : RelayCommand;
            }

            action def GenerateStatus {
                out status : StatusReport;
            }

            action def AccumulateEnergy {
                in measurement : PowerMeasurement;
                out energyData : EnergyData;
            }

            action def ReportFault {
                in fault : String;
                out ledCmd : LEDCommand;
                out status : StatusReport;
            }
        }

        part def RelaySwitch {
            attribute modelId : String = "WEMO-RELAY";
            attribute state : RelayState = Open;
            attribute maxCurrentRating : CurrentValue = 16;
            attribute maxVoltageRating : VoltageValue = 250;
            attribute faultDetected : Boolean = false;

            port controlPort : RelayControlPort;
            port inputPort : ACInPort;
            port outputPort : ACOutPort;

            state def Behavior {
                initial state Open;
                state Closed;
                state Faulted;

                transition Open -> Closed on controlPort.relayCommand[relayState == Closed];
                transition Closed -> Open on controlPort.relayCommand[relayState == Open];
                transition Open -> Faulted when (faultDetected);
                transition Closed -> Faulted when (faultDetected);
                transition Faulted -> Open on controlPort.relayCommand[relayState == Open];
            }

            exhibit Behavior;

            action def Switch {
                in command : RelayCommand;
                out state : RelayState;
            }

            action def MonitorSafety {
                in voltage : VoltageValue;
                in current : CurrentValue;
                out fault : Boolean;
            }
        }

        part def PowerMeter {
            attribute modelId : String = "WEMO-METER";
            attribute samplingRate : FrequencyValue = 60;
            attribute mode : MeasurementMode = Idle;
            attribute lastVoltage : VoltageValue = 0;
            attribute lastCurrent : CurrentValue = 0;
            attribute lastPower : PowerValue = 0;
            attribute cumulativeEnergy : EnergyValue = 0;
            attribute lastSampleTime : TimeValue = 0;
            attribute measurementWindowMs : TimeValue = 100;
            attribute accuracyClass : String = "Class 1";

            port inputPort : ACInPort;
            port outputPort : ACOutPort;
            port measurementPort : MeasurementPort;

            state def Behavior {
                initial state Idle;
                state Continuous;
                state Periodic;

                transition Idle -> Continuous when (mode == Continuous);
                transition Continuous -> Idle when (mode == Idle);
                transition Idle -> Periodic when (mode == Periodic);
                transition Periodic -> Idle when (mode == Idle);
            }

            exhibit Behavior;

            action def MeasureVoltage {
                out voltage : VoltageValue;
            }

            action def MeasureCurrent {
                out current : CurrentValue;
            }

            action def CalculatePower {
                in voltage : VoltageValue;
                in current : CurrentValue;
                out power : PowerValue;
            }

            action def IntegrateEnergy {
                in power : PowerValue;
                in dt : TimeValue;
                out energyDelta : EnergyValue;
            }

            action def Sample {
                out measurement : PowerMeasurement;
            }
        }

        part def LEDIndicator {
            attribute modelId : String = "WEMO-LED";
            attribute currentColor : LEDColor = Off;
            attribute blinkPeriod : TimeValue = 500;
            attribute supportedColors : LEDColor[1..*] = [Blue, Green, Amber, Red, BlinkingBlue, BlinkingRed];

            port controlPort : LEDControlPort;

            state def Behavior {
                initial state Off;
                state Solid;
                state Blinking;

                transition Off -> Solid on controlPort.ledCommand[color == Blue | Green | Amber | Red];
                transition Off -> Blinking on controlPort.ledCommand[color == BlinkingBlue | BlinkingRed];
                transition Solid -> Off on controlPort.ledCommand[color == Off];
                transition Blinking -> Off on controlPort.ledCommand[color == Off];
                transition Solid -> Solid on controlPort.ledCommand;
                transition Blinking -> Blinking on controlPort.ledCommand;
            }

            exhibit Behavior;

            action def SetColor {
                in command : LEDCommand;
                out newColor : LEDColor;
            }
        }

        part def PowerSocket {
            attribute standard : String = "NEMA 5-15";
            attribute ratedVoltage : VoltageValue = 120;
            attribute ratedCurrent : CurrentValue = 15;
            port supplyPort : SupplyPort;
        }

        part def WallOutlet {
            attribute standard : String = "NEMA 5-15";
            attribute nominalVoltage : VoltageValue = 120;
            attribute nominalFrequency : FrequencyValue = 60;
            port outputPort : ACOutPort;
        }

        part def Appliance {
            attribute name : String;
            attribute applianceClass : ApplianceClass = Unknown;
            attribute ratedPower : PowerValue;
            port powerPort : AppliancePort;
        }

        part def UserApp {
            attribute appVersion : String;
            attribute userId : String;
            attribute preferredSchedule : ScheduleItem[0..*];
            port interfacePort : CommandPort;
        }

        part def VoiceAssistant {
            attribute platform : String;
            attribute supportedCommands : CommandType[1..*] = [TurnOn, TurnOff, QueryStatus];
            port interfacePort : CommandPort;
        }
    }

    package Assembly {
        import Parts::*;
        import Ports::*;
        import Items::*;
        import Enums::*;
        import Units::*;

        part def SmartPlug {
            attribute productModel : String = "Belkin F7C027";
            attribute deviceId : String;
            attribute serialNumber : String;
            attribute firmwareVersion : String = "1.0.0";

            port acInPort : ACInPort;
            port appliancePort : AppliancePort;
            port wifiInterface : CommandPort;

            part wifiModule : WiFiModule;
            part controlProcessor : ControlProcessor;
            part relaySwitch : RelaySwitch;
            part powerMeter : PowerMeter;
            part ledIndicator : LEDIndicator;
            part powerSocket : PowerSocket;

            connection powerIn pass acInPort.acPower to relaySwitch.inputPort.acPower;
            connection relayOut pass relaySwitch.outputPort.acPower to powerSocket.supplyPort.suppliedPower;
            connection socketOut pass powerSocket.supplyPort.suppliedPower to appliancePort.appliancePower;
            connection acToMeter pass acInPort.acPower to powerMeter.inputPort.acPower;
            connection meterToRelay pass powerMeter.outputPort.acPower to relaySwitch.inputPort.acPower;
            connection radioIn pass wifiInterface.command to wifiModule.radioPort.inbound;
            connection radioOut pass wifiModule.radioPort.outbound to wifiInterface.status;
            connection moduleCmd pass wifiModule.localPort.command to controlProcessor.wifiPort.command;
            connection moduleStat pass controlProcessor.wifiPort.status to wifiModule.localPort.status;
            connection procRelayCmd pass controlProcessor.relayPort.relayCommand to relaySwitch.controlPort.relayCommand;
            connection relayStat pass relaySwitch.controlPort.relayStatus to controlProcessor.relayPort.relayStatus;
            connection procLED pass controlProcessor.ledPort.ledCommand to ledIndicator.controlPort.ledCommand;
            connection meterData pass powerMeter.measurementPort.measurement to controlProcessor.measurementPort.measurement;
        }

        part def SmartPlugSystem {
            part wallOutlet : WallOutlet;
            part smartPlug : SmartPlug;
            part appliance : Appliance;
            part userApp : UserApp;
            part voiceAssistant : VoiceAssistant;

            connection outletPower pass wallOutlet.outputPort.acPower to smartPlug.acInPort.acPower;
            connection plugToAppliance pass smartPlug.appliancePort.appliancePower to appliance.powerPort.appliancePower;
            connection appCmd pass userApp.interfacePort.command to smartPlug.wifiInterface.command;
            connection plugStatus pass smartPlug.wifiInterface.status to userApp.interfacePort.status;
            connection voiceCmd pass voiceAssistant.interfacePort.command to smartPlug.wifiInterface.command;
        }
    }

    package Requirements {
        import Assembly::*;
        import Enums::*;
        import Items::*;

        requirement def ProvideRemoteControl {
            doc /* The smart plug shall allow remote control of appliance power state */;
            subject smartPlug : SmartPlug;
        }

        requirement def ControlViaWiFi {
            doc /* The smart plug shall accept commands over a WiFi network from a user's mobile app or voice assistant */;
            subject smartPlug : SmartPlug;
        }

        requirement def ActuateRelay {
            doc /* The smart plug shall actuate an internal relay switch to open or close the AC circuit to the appliance */;
            subject smartPlug : SmartPlug;
            attribute supportedCommands : CommandType[1..*] = [TurnOn, TurnOff, Toggle];
        }

        requirement def MeasurePower {
            doc /* The smart plug shall measure voltage and current to calculate real-time power consumption */;
            subject smartPlug : SmartPlug;
            attribute samplingRate : FrequencyValue = 60;
        }

        requirement def TrackEnergy {
            doc /* The smart plug shall track total energy usage over time and persist it across power cycles */;
            subject smartPlug : SmartPlug;
        }

        requirement def ReportStatus {
            doc /* The smart plug shall send status reports containing power, energy, and state data over WiFi */;
            subject smartPlug : SmartPlug;
            attribute reportContent : String[1..*] = [instantPower, totalEnergy, plugState];
        }

        requirement def LEDIndicate {
            doc /* The smart plug shall provide an LED indicator that visualizes its current state */;
            subject smartPlug : SmartPlug;
        }

        requirement def SupportScheduling {
            doc /* The smart plug shall support scheduled on/off operations based on user-defined schedules */;
            subject smartPlug : SmartPlug;
            attribute maxSchedules : Integer = 16;
        }

        requirement def HandleReset {
            doc /* The smart plug shall turn off the appliance and clear faults on a reset command */;
            subject smartPlug : SmartPlug;
        }

        requirement def ContinuousMeasurement {
            doc /* The power meter shall continuously measure voltage and current while the plug is energized */;
            subject powerMeter : PowerMeter;
            attribute mode : MeasurementMode = Continuous;
        }

        requirement def SafeRelayRating {
            doc /* The relay shall be rated for at least 15 A and 120 VAC continuous duty */;
            subject relaySwitch : RelaySwitch;
            attribute minCurrentRating : CurrentValue = 15;
            attribute minVoltageRating : VoltageValue = 120;
        }

        requirement def ConnectWiFi2_4GHz {
            doc /* The WiFi module shall operate on the 2.4 GHz band */;
            subject wifiModule : WiFiModule;
            attribute operatingFrequency : FrequencyValue = 2400;
        }

        requirement def AppliancePowerPassThrough {
            doc /* The appliance power port shall provide the AC power to the plugged-in appliance when the relay is closed */;
            subject smartPlug : SmartPlug;
        }
    }

    package Verification {
        import Requirements::*;
        import Assembly::*;
        import Items::*;
        import Units::*;

        action def VerifyRemoteControl {
            in plug : SmartPlug;
            in commands : ControlCommand[1..*];
            doc /* Send a sequence of commands and confirm the plug's state transitions match the expected results */;
        }

        action def VerifyPowerMeasurement {
            in plug : SmartPlug;
            in expectedLoad : PowerValue;
            out measuredPower : PowerValue;
            out tolerance : PowerValue = 5;
        }

        action def VerifyEnergyTracking {
            in plug : SmartPlug;
            in duration : TimeValue;
            out initialEnergy : EnergyValue;
            out finalEnergy : EnergyValue;
            doc /* Run the plug under load for a known duration and confirm cumulative energy increases by the expected amount */;
        }

        action def VerifyStatusReport {
            in plug : SmartPlug;
            out report : StatusReport;
            doc /* Verify the status report contains power, energy, state, and timestamp fields */;
        }

        action def VerifyLEDStates {
            in plug : SmartPlug;
            doc /* Cycle the plug through Off, On, Connecting, and Fault states and verify the LED indicates each */;
        }

        action def VerifyScheduling {
            in plug : SmartPlug;
            in schedule : ScheduleItem[1..*];
            doc /* Set a schedule and verify that the relay state changes at the scheduled times */;
        }
    }

    package Configuration {
        import Assembly::*;
        import Items::*;

        part def WemoF7C027 :> SmartPlug {
            attribute productModel = "Belkin F7C027";
            attribute firmwareVersion = "1.0.0";
        }

        attribute def DefaultSchedule {
            attribute startTime : TimeValue = 28800;
            attribute duration : TimeValue = 3600;
            attribute action : CommandType = TurnOn;
            attribute enabled : Boolean = true;
            attribute recurrence : String = "Daily";
        }
    }

}

package 'Autonomous Environmental Monitor' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def TemperatureValue :> Real;
    attribute def BatteryLevel :> Real;
    attribute def MotionDetected :> Boolean;

    item def TemperatureReading;
    item def MotionReading;
    item def ProcessedData;
    item def NetworkCommand;
    item def PowerConnected;
    item def PowerDisconnected;

    port def TempSensorPort {
        out reading : TemperatureReading;
    }
    port def MotionSensorPort {
        out reading : MotionReading;
    }
    port def WirelessPort {
        in incoming : NetworkCommand;
        out outgoing : ProcessedData;
    }
    port def PowerPort {
        in connected : PowerConnected;
        in disconnected : PowerDisconnected;
    }
    port def DisplayPort {
        in status : String;
        in data : ProcessedData;
    }

    action def SenseTemperature {
        out temp : TemperatureValue;
    }
    action def SenseMotion {
        out motion : MotionDetected;
    }
    action def ProcessData {
        in temp : TemperatureValue;
        in motion : MotionDetected;
        out data : ProcessedData;
    }
    action def TransmitData {
        in data : ProcessedData;
    }
    action def ExecuteCommand {
        in cmd : NetworkCommand;
    }
    action def MonitorBattery {
        out level : BatteryLevel;
    }
    action def UpdateDisplay {
        in status : String;
        in data : ProcessedData;
    }

    part def TemperatureSensor {
        port sensorOut : TempSensorPort;
        perform action sense : SenseTemperature;
    }
    part def MotionDetector {
        port sensorOut : MotionSensorPort;
        perform action detect : SenseMotion;
    }
    part def WirelessModule {
        port netPort : WirelessPort;
        perform action transmit : TransmitData;
        perform action execute : ExecuteCommand;
    }
    part def RechargeableBattery {
        attribute currentLevel : BatteryLevel = 100;
        port powerIn : PowerPort;
        perform action monitor : MonitorBattery;
    }
    part def Display {
        port displayIn : DisplayPort;
        perform action update : UpdateDisplay;
    }
    part def CentralProcessor {
        port tempIn : TempSensorPort;
        port motionIn : MotionSensorPort;
        port wirelessLink : WirelessPort;
        port displayLink : DisplayPort;
        perform action process : ProcessData;
    }

    part def SmartDevice {
        part processor : CentralProcessor;
        part tempSensor : TemperatureSensor;
        part motionSensor : MotionDetector;
        part wireless : WirelessModule;
        part battery : RechargeableBattery;
        part display : Display;

        port powerPort : PowerPort;

        attribute batteryThresholdIdle : BatteryLevel = 30;
        attribute batteryThresholdSleep : BatteryLevel = 15;
        attribute batteryThresholdActive : BatteryLevel = 80;

        connect tempSensor.sensorOut to processor.tempIn;
        connect motionSensor.sensorOut to processor.motionIn;
        connect processor.wirelessLink to wireless.netPort;
        connect processor.displayLink to display.displayIn;
        connect powerPort to battery.powerIn;

        action senseTemp : SenseTemperature { out temp; }
        action senseMotion : SenseMotion { out motion; }
        action processData : ProcessData {
            in temp = senseTemp.temp;
            in motion = senseMotion.motion;
            out data;
        }
        action transmit : TransmitData { in data = processData.data; }
        action monitorBatt : MonitorBattery { out level; }
        action updateDisplay : UpdateDisplay {
            in status = "Monitoring";
            in data = processData.data;
        }

        state deviceStates parallel {
            state operationalStates {
                entry; then sensing;
                state sensing {
                    entry senseTemp;
                    do senseMotion;
                }
                accept after 1 [SI::s] then processing;
                state processing {
                    entry processData;
                    do transmit;
                    exit updateDisplay;
                }
                accept after 1 [SI::s] then sensing;
                accept cmd : NetworkCommand via wireless.netPort
                    do action execCmd : ExecuteCommand { in cmd = cmd; }
                    then processing;
            }

            state powerStates {
                entry; then active;
                state active {
                    do monitorBatt;
                }
                accept when monitorBatt.level < batteryThresholdIdle then idle;
                accept PowerConnected via powerPort then charging;

                state idle {
                    do monitorBatt;
                }
                accept when monitorBatt.level < batteryThresholdSleep then sleep;
                accept when monitorBatt.level >= batteryThresholdIdle then active;
                accept PowerConnected via powerPort then charging;

                state sleep {
                    do monitorBatt;
                }
                accept when monitorBatt.level >= batteryThresholdIdle then idle;
                accept PowerConnected via powerPort then charging;

                state charging {
                    do monitorBatt;
                }
                accept when monitorBatt.level >= batteryThresholdActive then active;
                accept PowerDisconnected via powerPort then active;
            }
        }
    }

    requirement def PowerManagementRequirement {
        doc /* The device shall automatically transition between active, idle, sleep, and charging states based on battery level and power connection. */
        subject device : SmartDevice;
    }

    requirement def EnvironmentalMonitoringRequirement {
        doc /* The device shall continuously sense temperature and motion, process the data, and transmit it wirelessly. */
        subject device : SmartDevice;
    }

    requirement def RemoteInteractionRequirement {
        doc /* The device shall receive and execute commands sent over the network through its wireless module. */
        subject device : SmartDevice;
    }
}

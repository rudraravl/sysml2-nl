package SmartGarmentHealthMonitoring {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        value type HeartRate :> Real;
        value type Impedance :> Real;
        value type BatteryLevel :> Real;

        item def Vector3D {
            attribute x : Real;
            attribute y : Real;
            attribute z : Real;
        }

        item def HealthDataPacket {
            attribute heartRate : HeartRate;
            attribute skinTemp : TemperatureValue;
            attribute acceleration : Vector3D;
            attribute hydration : Real;
            attribute batteryLevel : BatteryLevel;
        }

        attribute def PowerOnSignal;
        attribute def SelfTestComplete;
        attribute def ShutdownComplete;

        part def FabricSubstrate;
        part def ConductiveFiber;

        part def ECGSensor {
            port dataOut { out reading : Real; }
        }
        part def Thermistor {
            port dataOut { out reading : TemperatureValue; }
        }
        part def IMU {
            port dataOut { out reading : Vector3D; }
        }
        part def ImpedanceSensor {
            port dataOut { out reading : Impedance; }
        }
        part def FlexibleBattery {
            attribute level : BatteryLevel;
            port battOut { out level : BatteryLevel; }
        }
        part def SignalProcessingUnit {
            port ecgIn { in ecgData : Real; }
            port tempIn { in tempData : TemperatureValue; }
            port imuIn { in imuData : Vector3D; }
            port impIn { in impData : Impedance; }
            port battIn { in level : BatteryLevel; }
            port dataOut { out packet : HealthDataPacket; }
        }
        part def BluetoothTransceiver {
            port btIn { in packet : HealthDataPacket; }
        }

        action def 'Perform Self Test';
        action def 'Calibrate Sensors';
        action def 'Collect Sensor Data';
        action def 'Analyze Health Data';
        action def 'Assemble Health Packet';
        action def 'Transmit Data';
        action def 'Save Readings';
        action def 'Safe Shutdown';

        state def GarmentStates;

        requirement def 'WashableFabric' {
            doc /* The fabric substrate shall be machine washable and retain conductivity after 50 wash cycles. */
        }
        requirement def 'ContinuousMonitoring' {
            doc /* The system shall continuously monitor vital signs with a sampling rate of at least 100 Hz. */
        }
        requirement def 'WirelessTransmission' {
            doc /* Health data packets shall be transmitted via Bluetooth within 500 ms of assembly. */
        }
        requirement def 'PowerManagement' {
            doc /* The system shall enter reduced monitoring mode below 20% battery and safely shut down below 5%. */
        }

        part def SmartGarment {
            attribute lowBatteryThreshold : Real = 20.0;
            attribute criticalBatteryThreshold : Real = 5.0;

            part fabric : FabricSubstrate;
            part wiring : ConductiveFiber;
            part ecgSensor : ECGSensor;
            part thermistor : Thermistor;
            part imu : IMU;
            part impedanceSensor : ImpedanceSensor;
            part battery : FlexibleBattery;
            part spu : SignalProcessingUnit;
            part bluetooth : BluetoothTransceiver;

            connect ecgSensor.dataOut to spu.ecgIn;
            connect thermistor.dataOut to spu.tempIn;
            connect imu.dataOut to spu.imuIn;
            connect impedanceSensor.dataOut to spu.impIn;
            connect battery.battOut to spu.battIn;
            connect spu.dataOut to bluetooth.btIn;

            perform action 'perform self test' : 'Perform Self Test';
            perform action 'calibrate sensors' : 'Calibrate Sensors';
            perform action 'collect sensor data' : 'Collect Sensor Data';
            perform action 'analyze health data' : 'Analyze Health Data';
            perform action 'assemble health packet' : 'Assemble Health Packet';
            perform action 'transmit data' : 'Transmit Data';
            perform action 'save readings' : 'Save Readings';
            perform action 'safe shutdown' : 'Safe Shutdown';

            exhibit state 'garment states' : GarmentStates {
                entry; then off;
                state off;
                accept PowerOnSignal then selfTest;
                state selfTest {
                    do 'perform self test';
                    do 'calibrate sensors';
                }
                accept SelfTestComplete then normal;
                state normal {
                    do 'collect sensor data';
                    do 'analyze health data';
                    do 'assemble health packet';
                    do 'transmit data';
                }
                accept when battery.level < lowBatteryThreshold then reduced;
                state reduced {
                    do 'collect sensor data';
                    do 'analyze health data';
                    do 'assemble health packet';
                    do 'transmit data';
                }
                accept when battery.level < criticalBatteryThreshold then criticalLow;
                state criticalLow {
                    do 'assemble health packet';
                    do 'transmit data';
                    do 'save readings';
                    do 'safe shutdown';
                }
                accept ShutdownComplete then off;
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part smartGarment : SmartGarment;

        requirement 'washable fabric' : 'WashableFabric' {
            subject: smartGarment.fabric;
        }
        requirement 'continuous monitoring' : 'ContinuousMonitoring' {
            subject: smartGarment.spu;
        }
        requirement 'wireless transmission' : 'WirelessTransmission' {
            subject: smartGarment.bluetooth;
        }
        requirement 'power management' : 'PowerManagement' {
            subject: smartGarment.battery;
        }
    }
}

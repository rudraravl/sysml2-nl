package AndroidSmartphoneModel {
    item def Data;
    item def AudioData;
    item def Packet;
    item def TouchEvent;
    item def SensorData;
    item def Power;
    
    attribute def ChargeLevel :> ScalarValues::Real;
    attribute def ProcessorSpeed :> ScalarValues::Real;
    attribute def Brightness :> ScalarValues::Real;
    
    port def PowerPort { out item pwr : Power; }
    port def DataPort { in item inData : Data; out item outData : Data; }
    port def TouchPort { out item evt : TouchEvent; }
    port def SensorPort { out item sData : SensorData; }
    port def NetPort { in item rx : Packet; out item tx : Packet; }
    port def AudioPort { in item inAudio : AudioData; out item outAudio : AudioData; }
    port def DisplayPort { in item vis : Data; }
    port def StatusPort { out attribute charge : ChargeLevel; }
    
    part def ApplicationProcessor {
        attribute speed : ProcessorSpeed;
        port powerIn : ~PowerPort;
        port memPort : ~DataPort;
    }
    part def GraphicsProcessor {
        port powerIn : ~PowerPort;
        port renderPort : DataPort;
    }
    part def SystemMemory {
        port powerIn : ~PowerPort;
        port memPort : DataPort;
    }
    part def DisplayPanel {
        attribute brightness : Brightness;
        port powerIn : ~PowerPort;
        port displayIn : ~DisplayPort;
    }
    part def TouchSensor {
        port powerIn : ~PowerPort;
        port touchOut : TouchPort;
    }
    part def SensorHub {
        port powerIn : ~PowerPort;
        port sensorIn : ~SensorPort;
        port sensorOut : SensorPort;
    }
    part def Accelerometer {
        port powerIn : ~PowerPort;
        port accelOut : SensorPort;
    }
    part def WirelessModem {
        port powerIn : ~PowerPort;
        port netPort : NetPort;
    }
    part def AudioCodec {
        port powerIn : ~PowerPort;
        port audioPort : AudioPort;
    }
    part def BatteryPack {
        attribute charge : ChargeLevel;
        port powerOut : PowerPort;
        port statusOut : StatusPort;
    }
    part def AndroidOS {
        port touchIn : ~TouchPort;
        port sensorIn : ~SensorPort;
        port netPort : ~NetPort;
        port displayOut : DisplayPort;
        port audioOut : AudioPort;
        port statusIn : ~StatusPort;
    }
    part def ApplicationFramework;
    
    action def OperationLoop {
        first start;
        then merge m;
        then action captureInput;
        then action processNetwork;
        then action readSensors;
        then action updateDisplay;
        then m;
    }
    
    state def PowerManagement {
        state Normal;
        state PowerSaving;
        state Shutdown;
        transition from Normal to PowerSaving when battery.charge < 20;
        transition from PowerSaving to Shutdown when battery.charge < 5;
        transition from PowerSaving to Normal when battery.charge > 30;
    }
    
    part def Smartphone {
        part cpu : ApplicationProcessor;
        part gpu : GraphicsProcessor;
        part ram : SystemMemory;
        part display : DisplayPanel;
        part touchSensor : TouchSensor;
        part sensorHub : SensorHub;
        part accelerometer : Accelerometer;
        part modem : WirelessModem;
        part audioCodec : AudioCodec;
        part battery : BatteryPack;
        part os : AndroidOS;
        part appFramework : ApplicationFramework;
        
        connect battery.powerOut to cpu.powerIn;
        connect battery.powerOut to gpu.powerIn;
        connect battery.powerOut to ram.powerIn;
        connect battery.powerOut to display.powerIn;
        connect battery.powerOut to touchSensor.powerIn;
        connect battery.powerOut to sensorHub.powerIn;
        connect battery.powerOut to accelerometer.powerIn;
        connect battery.powerOut to modem.powerIn;
        connect battery.powerOut to audioCodec.powerIn;
        
        connect battery.statusOut to os.statusIn;
        connect touchSensor.touchOut to os.touchIn;
        connect sensorHub.sensorOut to os.sensorIn;
        connect accelerometer.accelOut to sensorHub.sensorIn;
        connect modem.netPort to os.netPort;
        
        connect os.displayOut to display.displayIn;
        connect os.audioOut to audioCodec.audioPort;
        
        perform OperationLoop;
        perform PowerManagement;
    }
    
    requirement def SmartphoneRequirement {
        doc /* The smartphone shall provide mobile computing capabilities for communication, productivity, and entertainment. */
    }
    
    requirement def PowerManagementRequirement {
        doc /* The system shall manage power consumption based on battery charge level, transitioning to power-saving mode when low and performing controlled shutdown when critical. */
    }
    
    requirement def ConnectivityRequirement {
        doc /* The system shall provide cellular and Wi-Fi connectivity for data transmission and reception. */
    }
}

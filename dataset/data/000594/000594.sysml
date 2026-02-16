package 'E-Textiles Wearable Health Monitoring System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def BiometricReading {
        attribute timestamp : TimeValue;
        attribute sensorId : String;
        attribute rawValue : Real;
    }
    
    attribute def HeartRateReading :> BiometricReading {
        attribute beatsPerMinute : Real;
        attribute confidence : Real;
    }
    
    attribute def SkinTemperatureReading :> BiometricReading {
        attribute temperature : TemperatureValue;
    }
    
    attribute def MovementReading :> BiometricReading {
        attribute accelerationX : Real;
        attribute accelerationY : Real;
        attribute accelerationZ : Real;
    }
    
    attribute def HydrationLevel :> BiometricReading {
        attribute impedance : Real;
        attribute hydrationPercent : Real;
    }
    
    item def SensorSignal {
        attribute voltage : ElectricPotentialValue;
        attribute frequency : FrequencyValue;
    }
    
    item def HealthDataPacket {
        attribute heartRate : HeartRateReading;
        attribute temperature : SkinTemperatureReading;
        attribute movement : MovementReading;
        attribute hydration : HydrationLevel;
        attribute batteryLevel : Real;
    }
    
    item def PowerSupply {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }
    
    item def PowerButtonPressed;
    item def CalibrationComplete;
    item def LowBatteryWarning;
    item def BatteryCharged;
    item def BatteryCritical;
    item def DataSaved;
    item def PowerButtonHeld;
    
    port def SensorOutputPort {
        out item signal : SensorSignal;
    }
    
    port def ProcessorInputPort {
        in item signal : SensorSignal;
    }
    
    port def DataTransmissionPort {
        out item dataPacket : HealthDataPacket;
    }
    
    port def PowerInputPort {
        in item power : PowerSupply;
    }
    
    port def PowerOutputPort {
        out item power : PowerSupply;
    }
    
    part def ConductiveFiber {
        attribute resistivity : Real;
        attribute conductivity : Real;
        attribute flexibility : Real;
        attribute washCycles : Integer;
    }
    
    part def TextileSensor {
        port sensorOut : SensorOutputPort;
        port powerIn : PowerInputPort;
        attribute samplingRate : FrequencyValue;
        attribute sensitivity : Real;
        attribute operatingTemperature : TemperatureValue;
    }
    
    part def ECGSensor :> TextileSensor {
        attribute electrodeSpacing : LengthValue;
        attribute signalAmplification : Real;
    }
    
    part def ThermistorSensor :> TextileSensor {
        attribute temperatureRange : TemperatureValue[2];
        attribute accuracy : TemperatureValue;
    }
    
    part def IMUSensor :> TextileSensor {
        attribute axes : Integer = 3;
        attribute gyroscopeRange : Real;
        attribute accelerometerRange : Real;
    }
    
    part def ImpedanceSensor :> TextileSensor {
        attribute measurementFrequency : FrequencyValue;
        attribute impedanceRange : Real;
    }
    
    part def SignalProcessingUnit {
        port ecgInput : ProcessorInputPort;
        port tempInput : ProcessorInputPort;
        port imuInput : ProcessorInputPort;
        port hydrationInput : ProcessorInputPort;
        port dataOutput : DataTransmissionPort;
        port powerIn : PowerInputPort;
        attribute processingCapacity : Real;
        attribute memorySize : Real;
    }
    
    part def FlexibleBatteryModule {
        port powerOut : PowerOutputPort;
        attribute capacity : Real;
        attribute voltage : ElectricPotentialValue;
        attribute currentCharge : Real;
        attribute cycleCount : Integer;
    }
    
    part def BluetoothTransceiver {
        port dataIn : DataTransmissionPort;
        port powerIn : PowerInputPort;
        attribute transmissionRange : LengthValue;
        attribute dataRate : Real;
        attribute protocol : String;
    }
    
    part def SmartTextileSubstrate {
        part fibers : ConductiveFiber[*];
        attribute weavePattern : String;
        attribute stretchability : Real;
        attribute breathability : Real;
        attribute waterResistance : Real;
    }
    
    action def AcquireBiometricData {
        in attribute sensorType : String;
        in attribute samplingInterval : TimeValue;
        out attribute reading : BiometricReading;
    }
    
    action def FilterSignal {
        in attribute rawSignal : SensorSignal;
        in attribute filterType : String;
        out attribute filteredSignal : SensorSignal;
    }
    
    action def CalculateHeartRate {
        in attribute ecgSignal : SensorSignal;
        out attribute heartRate : HeartRateReading;
    }
    
    action def AssembleDataPacket {
        in attribute hrData : HeartRateReading;
        in attribute tempData : SkinTemperatureReading;
        in attribute motionData : MovementReading;
        in attribute hydrationData : HydrationLevel;
        in attribute batteryStatus : Real;
        out attribute packet : HealthDataPacket;
    }
    
    action def TransmitWirelessly {
        in attribute dataPacket : HealthDataPacket;
        out attribute transmissionSuccess : Boolean;
    }
    
    action def CalibrateSensors {
        doc /* Calibrate all sensors to baseline values */
    }
    
    action def SelfTest {
        doc /* Perform system self-test */
    }
    
    action def SaveData {
        doc /* Save current data to non-volatile memory */
    }
    
    action def EmergencyDataTransmit {
        doc /* Transmit critical data before shutdown */
    }
    
    action def MonitorVitalSigns {
        first start;
        then merge continuousMonitoring;
        
        action acquireECG : AcquireBiometricData {
            in sensorType = "ECG";
            in samplingInterval = 0.01;
            out ecgReading : BiometricReading;
        }
        
        then action acquireTemp : AcquireBiometricData {
            in sensorType = "Temperature";
            in samplingInterval = 1.0;
            out tempReading : BiometricReading;
        }
        
        then action acquireMotion : AcquireBiometricData {
            in sensorType = "IMU";
            in samplingInterval = 0.05;
            out motionReading : BiometricReading;
        }
        
        then action acquireHydration : AcquireBiometricData {
            in sensorType = "Impedance";
            in samplingInterval = 5.0;
            out hydrationReading : BiometricReading;
        }
        
        then action processECG : CalculateHeartRate {
            in ecgSignal;
            out heartRate : HeartRateReading;
        }
        
        then action assemblePacket : AssembleDataPacket {
            in hrData = processECG.heartRate;
            in tempData;
            in motionData;
            in hydrationData;
            in batteryStatus;
            out packet : HealthDataPacket;
        }
        
        then decide;
            if assemblePacket.packet.batteryLevel > 10.0 then transmit;
            else lowPowerMode;
        
        action transmit : TransmitWirelessly {
            in dataPacket = assemblePacket.packet;
            out transmissionSuccess;
        }
        
        then continuousMonitoring;
        
        action lowPowerMode {
            doc /* Enter low power state to preserve battery */
        }
        
        then done;
    }
    
    state def WearableSystemStates {
        entry; then off;
        
        state off {
            doc /* System is powered down */
        }
        
        transition powerOn
            first off
            accept at powerButtonPressed : PowerButtonPressed
            then initializing;
        
        state initializing {
            entry; then selfTest;
            do action calibrateSensors : CalibrateSensors;
            action selfTest : SelfTest;
        }
        
        transition initComplete
            first initializing
            accept at calibrationComplete : CalibrationComplete
            then monitoring;
        
        state monitoring {
            entry; then activeMonitoring;
            do action continuousDataCollection : MonitorVitalSigns;
            
            state activeMonitoring {
                doc /* All sensors actively collecting data */
            }
            
            state reducedMonitoring {
                doc /* Reduced sampling to conserve power */
            }
            
            transition toReduced
                first activeMonitoring
                accept at lowBatteryWarning : LowBatteryWarning
                then reducedMonitoring;
            
            transition toActive
                first reducedMonitoring
                accept at batteryCharged : BatteryCharged
                then activeMonitoring;
        }
        
        transition criticalBattery
            first monitoring
            accept at batteryCritical : BatteryCritical
            then shutdown;
        
        state shutdown {
            entry; then saveData;
            do action emergencyDataTransmit : EmergencyDataTransmit;
            action saveData : SaveData;
        }
        
        transition shutdownComplete
            first shutdown
            accept at dataSaved : DataSaved
            then off;
        
        transition userPowerOff
            first monitoring
            accept at powerButtonHeld : PowerButtonHeld
            then shutdown;
    }
    
    requirement def SystemRequirement;
    
    requirement def <'REQ-ETEX-001'> SystemLevelRequirements : SystemRequirement {
        doc /* 
            The E-Textile Wearable Health Monitoring System shall continuously monitor 
            user vital signs including heart rate, skin temperature, movement, and 
            hydration level, and wirelessly transmit this data to external devices 
            for health tracking and analysis.
        */
        
        requirement <'REQ-ETEX-001.1'> continuousMonitoring {
            doc /* 
                The system shall continuously monitor vital signs with minimum 
                sampling rates: ECG at 100 Hz, temperature at 1 Hz, motion at 20 Hz, 
                and hydration at 0.2 Hz.
            */
        }
        
        requirement <'REQ-ETEX-001.2'> dataAccuracy {
            doc /* 
                Heart rate measurements shall be accurate within ±3 bpm, temperature 
                within ±0.2°C, and hydration level within ±5%.
            */
        }
        
        requirement <'REQ-ETEX-001.3'> wirelessCommunication {
            doc /* 
                The system shall transmit health data packets via Bluetooth Low Energy 
                with minimum range of 10 meters and data rate of 1 Mbps.
            */
        }
        
        requirement <'REQ-ETEX-001.4'> wearability {
            doc /* 
                The textile substrate shall maintain flexibility with minimum 80% 
                stretchability, breathability rating of 5000 g/m²/24h, and withstand 
                minimum 50 wash cycles.
            */
        }
        
        requirement <'REQ-ETEX-001.5'> batteryLife {
            doc /* 
                The system shall operate continuously for minimum 48 hours on a 
                single charge under normal monitoring conditions.
            */
        }
        
        requirement <'REQ-ETEX-001.6'> biocompatibility {
            doc /* 
                All materials in contact with skin shall be hypoallergenic and 
                maintain skin temperature below 38°C during operation.
            */
        }
    }
    
    part eTextileHealthMonitor : SmartTextileSubstrate {
        doc /* 
            Smart E-Textile Wearable Health Monitoring System integrates conductive 
            fibers, embedded biometric sensors, signal processing electronics, and 
            wireless communication into a flexible, washable fabric garment. The 
            system continuously monitors wearer's vital signs including heart rate 
            via ECG, skin temperature, body movement, and hydration levels, processing 
            this data in real-time and transmitting comprehensive health metrics to 
            companion devices for medical monitoring, fitness tracking, and wellness 
            management applications.
        */
        
        part ecgSensor : ECGSensor {
            port :>> sensorOut;
            port :>> powerIn;
            attribute :>> samplingRate = 100.0;
            attribute :>> electrodeSpacing = 0.05;
            attribute :>> signalAmplification = 1000.0;
        }
        
        part temperatureSensor : ThermistorSensor {
            port :>> sensorOut;
            port :>> powerIn;
            attribute :>> samplingRate = 1.0;
            attribute :>> accuracy = 0.2;
        }
        
        part motionSensor : IMUSensor {
            port :>> sensorOut;
            port :>> powerIn;
            attribute :>> samplingRate = 20.0;
            attribute :>> gyroscopeRange = 2000.0;
            attribute :>> accelerometerRange = 16.0;
        }
        
        part hydrationSensor : ImpedanceSensor {
            port :>> sensorOut;
            port :>> powerIn;
            attribute :>> samplingRate = 0.2;
            attribute :>> measurementFrequency = 50000.0;
        }
        
        part processor : SignalProcessingUnit {
            port ecgIn :>> ecgInput;
            port tempIn :>> tempInput;
            port imuIn :>> imuInput;
            port hydrationIn :>> hydrationInput;
            port dataOut :>> dataOutput;
            port processorPower :>> powerIn;
            attribute :>> processingCapacity = 120.0;
            attribute :>> memorySize = 512.0;
        }
        
        part battery : FlexibleBatteryModule {
            port batteryPower :>> powerOut;
            attribute :>> capacity = 2000.0;
            attribute :>> voltage = 3.7;
            attribute :>> currentCharge = 2000.0;
            attribute :>> cycleCount = 0;
        }
        
        part wireless : BluetoothTransceiver {
            port wirelessData :>> dataIn;
            port wirelessPower :>> powerIn;
            attribute :>> transmissionRange = 15.0;
            attribute :>> dataRate = 1000000.0;
            attribute :>> protocol = "Bluetooth 5.0 LE";
        }
        
        part conductiveThreads : ConductiveFiber[24] {
            attribute :>> resistivity = 0.05;
            attribute :>> conductivity = 20.0;
            attribute :>> flexibility = 0.95;
            attribute :>> washCycles = 100;
        }
        
        connection ecgPower connect battery.batteryPower to ecgSensor.powerIn;
        connection tempPower connect battery.batteryPower to temperatureSensor.powerIn;
        connection motionPower connect battery.batteryPower to motionSensor.powerIn;
        connection hydrationPower connect battery.batteryPower to hydrationSensor.powerIn;
        connection processorPower connect battery.batteryPower to processor.processorPower;
        connection wirelessPower connect battery.batteryPower to wireless.wirelessPower;
        
        connection ecgData connect ecgSensor.sensorOut to processor.ecgIn;
        connection tempData connect temperatureSensor.sensorOut to processor.tempIn;
        connection motionData connect motionSensor.sensorOut to processor.imuIn;
        connection hydrationData connect hydrationSensor.sensorOut to processor.hydrationIn;
        connection wirelessLink connect processor.dataOut to wireless.wirelessData;
        
        perform action vitalSignsMonitoring : MonitorVitalSigns;
        
        exhibit state operationalStates : WearableSystemStates;
        
        satisfy SystemLevelRequirements;
    }
}

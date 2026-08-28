package TideGaugeSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    value type Pressure :> Real { unit "Pa"; }
    value type Temperature :> Real { unit "degC"; }
    value type WaterLevel :> Real { unit "m"; }
    value type RateOfChange :> Real { unit "m/s"; }
    value type Voltage :> Real { unit "V"; }
    value type Current :> Real { unit "A"; }
    value type TimeDuration :> Real { unit "s"; }
    value type Frequency :> Real { unit "Hz"; }
    
    item def RawPressureData {
        attribute value : Pressure;
        attribute timestamp : TimeDuration;
    }
    item def RawTemperatureData {
        attribute value : Temperature;
        attribute timestamp : TimeDuration;
    }
    item def ProcessedWaterLevel {
        attribute level : WaterLevel;
        attribute timestamp : TimeDuration;
    }
    item def TideAnalysis {
        attribute currentLevel : WaterLevel;
        attribute rateOfChange : RateOfChange;
        attribute predictedHighTideTime : TimeDuration;
        attribute predictedHighTideLevel : WaterLevel;
        attribute predictedLowTideTime : TimeDuration;
        attribute predictedLowTideLevel : WaterLevel;
    }
    item def AlertStatus {
        attribute floodWarning : Boolean;
        attribute lowWaterWarning : Boolean;
    }
    item def PowerFlow {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    
    port def PressureOutPort {
        out rawPressure : RawPressureData;
    }
    port def TemperatureOutPort {
        out rawTemperature : RawTemperatureData;
    }
    port def DataInPort {
        in rawPressure : RawPressureData;
        in rawTemperature : RawTemperatureData;
    }
    port def DataOutPort {
        out waterLevel : ProcessedWaterLevel;
        out tideAnalysis : TideAnalysis;
        out alertStatus : AlertStatus;
    }
    port def TelemetryInPort {
        in waterLevel : ProcessedWaterLevel;
        in tideAnalysis : TideAnalysis;
        in alertStatus : AlertStatus;
    }
    port def PowerOutPort {
        out power : PowerFlow;
    }
    port def PowerInPort {
        in power : PowerFlow;
    }
    
    part def PressureTransducer {
        port pressureOut : PressureOutPort;
        attribute samplingRate : Frequency = 10;
    }
    
    part def TemperatureSensor {
        port tempOut : TemperatureOutPort;
        attribute samplingRate : Frequency = 1;
    }
    
    part def SubmergedSensorPackage {
        part pressureTransducer : PressureTransducer;
        part temperatureSensor : TemperatureSensor;
    }
    
    part def DataAcquisitionUnit {
        port dataIn : DataInPort;
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;
        
        attribute highTideThreshold : WaterLevel = 5.0;
        attribute lowTideThreshold : WaterLevel = 0.5;
        attribute floodRateThreshold : RateOfChange = 0.05;
        
        state machine AcquisitionStateMachine {
            state Sampling;
            state Processing;
            state Analyzing;
            state Alerting;
            
            transition initial to Sampling;
            transition Sampling to Processing;
            transition Processing to Analyzing;
            transition Analyzing to Alerting;
            transition Alerting to Sampling;
        }
        
        action def ConvertPressureToLevel {
            in rawPressure : RawPressureData;
            in rawTemp : RawTemperatureData;
            out waterLevel : ProcessedWaterLevel;
        }
        action def AnalyzeTrends {
            in buffer : ProcessedWaterLevel[*];
            out analysis : TideAnalysis;
        }
        action def CheckAlarms {
            in currentLevel : WaterLevel;
            in rateOfChange : RateOfChange;
            out alert : AlertStatus;
        }
    }
    
    part def TelemetrySystem {
        port telemetryIn : TelemetryInPort;
        port powerIn : PowerInPort;
        attribute transmissionInterval : TimeDuration = 300;
        
        action def TransmitData {
            in analysis : TideAnalysis;
            in alerts : AlertStatus;
        }
    }
    
    part def Battery {
        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;
        attribute capacity : Real = 100;
        attribute currentVoltage : Voltage;
    }
    
    part def SolarPanel {
        port powerOut : PowerOutPort;
        attribute maxPower : Real = 50;
    }
    
    part def PowerManagementUnit {
        part battery : Battery;
        part solarPanel : SolarPanel;
        port systemPowerOut : PowerOutPort;
        
        flow connection solarPanelToBattery : solarPanel.powerOut.power to battery.powerIn.power;
        flow connection batteryToSystem : battery.powerOut.power to systemPowerOut.power;
    }
    
    part def MountingStructure {
        attribute material : String = "Marine-grade stainless steel";
        attribute maxDepth : WaterLevel = 50.0;
    }
    
    part def TideGaugeSystem {
        part sensorPackage : SubmergedSensorPackage;
        part dau : DataAcquisitionUnit;
        part telemetry : TelemetrySystem;
        part pmu : PowerManagementUnit;
        part structure : MountingStructure;
        
        flow connection pressureToDAU : sensorPackage.pressureTransducer.pressureOut.rawPressure to dau.dataIn.rawPressure;
        flow connection tempToDAU : sensorPackage.temperatureSensor.tempOut.rawTemperature to dau.dataIn.rawTemperature;
        
        flow connection dauToTelemetryLevel : dau.dataOut.waterLevel to telemetry.telemetryIn.waterLevel;
        flow connection dauToTelemetryAnalysis : dau.dataOut.tideAnalysis to telemetry.telemetryIn.tideAnalysis;
        flow connection dauToTelemetryAlerts : dau.dataOut.alertStatus to telemetry.telemetryIn.alertStatus;
        
        flow connection pmuToDAU : pmu.systemPowerOut.power to dau.powerIn.power;
        flow connection pmuToTelemetry : pmu.systemPowerOut.power to telemetry.powerIn.power;
    }
    
    requirement def MeasureWaterLevelRequirement {
        doc "The system shall continuously monitor and record water level changes.";
    }
    requirement def AnalyzeTrendsRequirement {
        doc "The system shall calculate the rate of tide changes and predict the times and levels of the next high and low tides.";
    }
    requirement def DetectAlarmsRequirement {
        doc "The system shall compare current water level and rate of change against configurable alarm thresholds for flooding or unusually low water levels.";
    }
    requirement def TransmitDataRequirement {
        doc "The system shall transmit tide analysis and alerts to a remote monitoring station at regular intervals, typically every five minutes.";
    }
    requirement def AutonomousOperationRequirement {
        doc "The system shall function autonomously for long periods without maintenance, powered by a high-capacity battery and solar panel.";
    }
    requirement def DurableConstructionRequirement {
        doc "The system shall be protected by a durable mounting structure built from corrosion-resistant materials, designed to be installed at significant depths and withstand ocean forces.";
    }
    
    requirement r1 : MeasureWaterLevelRequirement;
    requirement r2 : AnalyzeTrendsRequirement;
    requirement r3 : DetectAlarmsRequirement;
    requirement r4 : TransmitDataRequirement;
    requirement r5 : AutonomousOperationRequirement;
    requirement r6 : DurableConstructionRequirement;
}

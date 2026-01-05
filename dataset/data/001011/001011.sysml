package ChemiresistorGasDetectionSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def GasConcentration :> Real {
        doc /* Concentration of target gas in parts per million (ppm) */
    }
    
    attribute def ResistanceValue :> Real {
        doc /* Electrical resistance in ohms */
    }
    
    attribute def SensitivityCoefficient :> Real {
        doc /* Sensor sensitivity relating gas concentration to resistance change */
    }
    
    item def GasSample {
        attribute concentration : GasConcentration;
        attribute temperature : TemperatureValue;
        attribute humidity : Real;
    }
    
    item def ElectricalSignal {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
        attribute resistance : ResistanceValue;
    }
    
    item def AlarmSignal {
        attribute isActive : Boolean;
        attribute severity : Real;
    }
    
    item def MeasurementData {
        attribute gasConcentration : GasConcentration;
        attribute timestamp : TimeValue;
        attribute alarmStatus : Boolean;
    }
    
    port def GasInputPort {
        in item sample : GasSample;
    }
    
    port def ElectricalPort {
        out item signal : ElectricalSignal;
    }
    
    port def DataPort {
        out item data : MeasurementData;
    }
    
    port def AlarmPort {
        out item alarm : AlarmSignal;
    }
    
    part def ChemiresistiveSensor {
        doc /* Sensing element with chemically sensitive material that changes resistance upon gas exposure */
        
        attribute baselineResistance : ResistanceValue = 10000.0;
        attribute currentResistance : ResistanceValue;
        attribute sensitivity : SensitivityCoefficient = 0.25;
        attribute operatingTemperature : TemperatureValue = 150.0 [K];
        
        port gasInput : GasInputPort;
        port electricalOutput : ElectricalPort;
        
        action respondToGas {
            in gasConcentration : GasConcentration;
            in baseResistance : ResistanceValue;
            in sensitivityFactor : SensitivityCoefficient;
            out newResistance : ResistanceValue;
            
            doc /* Calculate resistance change based on gas concentration exposure */
        }
    }
    
    part def SignalProcessor {
        doc /* Converts resistance changes to voltage signals and filters noise */
        
        attribute referenceVoltage : ElectricPotentialValue = 5.0 [V];
        attribute gain : Real = 100.0;
        
        port electricalInput : ~ElectricalPort;
        port processedOutput : ElectricalPort;
        
        action amplifySignal {
            in inputVoltage : ElectricPotentialValue;
            in amplificationGain : Real;
            out outputVoltage : ElectricPotentialValue;
        }
        
        action filterSignal {
            in rawSignal : ElectricalSignal;
            out cleanSignal : ElectricalSignal;
        }
    }
    
    part def AnalogDigitalConverter {
        doc /* Converts analog electrical signals to digital values */
        
        attribute resolution : Real = 12.0;
        attribute samplingRate : Real = 1000.0;
        
        port analogInput : ~ElectricalPort;
        port digitalOutput : DataPort;
        
        action convertToDigital {
            in analogVoltage : ElectricPotentialValue;
            in resolutionBits : Real;
            out digitalValue : Real;
        }
    }
    
    part def Microcontroller {
        doc /* Processes digital data, calculates gas concentration, and manages alarm logic */
        
        attribute calibrationCurve : Real[*];
        attribute alarmThreshold : GasConcentration = 100.0;
        
        port dataInput : ~DataPort;
        port measurementOutput : DataPort;
        port alarmOutput : AlarmPort;
        
        action calculateConcentration {
            in digitalValue : Real;
            in calibration : Real[*];
            out concentration : GasConcentration;
        }
        
        action evaluateAlarmCondition {
            in measuredConcentration : GasConcentration;
            in threshold : GasConcentration;
            out shouldAlarm : Boolean;
        }
        
        action generateMeasurement {
            in concentration : GasConcentration;
            in alarmActive : Boolean;
            out measurement : MeasurementData;
        }
        
        action performCalibration {
            doc /* Establish baseline resistance in clean air */
        }
    }
    
    part def AlarmIndicator {
        doc /* Provides visual and audible alerts when hazardous gas levels detected */
        
        port alarmInput : ~AlarmPort;
    }
    
    part def PowerManagement {
        doc /* Regulates power supply to all system components */
        
        attribute inputVoltage : ElectricPotentialValue = 12.0 [V];
        attribute outputVoltage : ElectricPotentialValue = 5.0 [V];
        attribute maxCurrent : ElectricCurrentValue = 2.0 [A];
    }
    
    part def ChemiresistorSystem {
        doc /* 
            Complete gas detection system using chemiresistive sensing technology.
            Continuously monitors environmental gas concentrations by measuring
            resistance changes in a chemically sensitive material, processes the
            signal to determine gas concentration, and activates alarms when
            hazardous levels are detected.
        */
        
        attribute targetGas : String = "Carbon Monoxide";
        attribute detectionRangeLow : GasConcentration = 1.0;
        attribute detectionRangeHigh : GasConcentration = 1000.0;
        attribute responseTime : TimeValue = 30.0 [s];
        
        part sensor : ChemiresistiveSensor;
        part signalProcessor : SignalProcessor;
        part adc : AnalogDigitalConverter;
        part controller : Microcontroller;
        part alarmUnit : AlarmIndicator;
        part powerSupply : PowerManagement;
        
        port environmentalInput : GasInputPort;
        port dataOutput : DataPort;
        port alarmOutput : AlarmPort;
        
        connection sensorToProcessor
            connect sensor.electricalOutput to signalProcessor.electricalInput;
        
        connection processorToADC
            connect signalProcessor.processedOutput to adc.analogInput;
        
        connection adcToController
            connect adc.digitalOutput to controller.dataInput;
        
        connection controllerToAlarm
            connect controller.alarmOutput to alarmUnit.alarmInput;
        
        connection environmentToSensor
            connect environmentalInput to sensor.gasInput;
        
        connection controllerToOutput
            connect controller.measurementOutput to dataOutput;
        
        connection alarmToOutput
            connect controller.alarmOutput to alarmOutput;
    }
    
    action def MonitorGasEnvironment {
        doc /* Primary system function: continuously detect and quantify target gas concentration */
        
        in gasSample : GasSample;
        out measurementResult : MeasurementData;
        out alarmSignal : AlarmSignal;
        
        first start;
        then merge continuousMonitoring;
        
        then action exposeSensor {
            in sample : GasSample;
            out resistanceChange : ResistanceValue;
        }
        
        then action processSignal {
            in resistance : ResistanceValue;
            out voltage : ElectricPotentialValue;
        }
        
        then action convertSignal {
            in analogVoltage : ElectricPotentialValue;
            out digitalData : Real;
        }
        
        then action analyzeData {
            in data : Real;
            out concentration : GasConcentration;
        }
        
        then action checkThreshold {
            in concentration : GasConcentration;
            out alarmNeeded : Boolean;
        }
        
        then decide;
            if checkThreshold.alarmNeeded = true then activateAlarm;
            if checkThreshold.alarmNeeded = false then recordMeasurement;
        
        action activateAlarm {
            in concentration : GasConcentration;
            out alarm : AlarmSignal;
        }
        then recordMeasurement;
        
        action recordMeasurement {
            in concentration : GasConcentration;
            out measurement : MeasurementData;
        }
        
        then continuousMonitoring;
    }
    
    part chemiresistorSystem : ChemiresistorSystem {
        attribute :>> targetGas = "Carbon Monoxide";
        
        perform action monitorGas[*] ordered references MonitorGasEnvironment {
            in gasSample;
            out measurementResult;
            out alarmSignal;
        }
        
        part :>> sensor {
            perform monitorGas.exposeSensor;
        }
        
        part :>> signalProcessor {
            perform monitorGas.processSignal;
        }
        
        part :>> adc {
            perform monitorGas.convertSignal;
        }
        
        part :>> controller {
            perform monitorGas.analyzeData;
            perform monitorGas.checkThreshold;
            perform monitorGas.recordMeasurement;
        }
        
        part :>> alarmUnit {
            perform monitorGas.activateAlarm;
        }
    }
    
    requirement def DetectionPerformanceRequirement {
        doc /* Requirements for gas detection performance characteristics */
        
        subject system : ChemiresistorSystem;
        
        require constraint detectionRange {
            doc /* System shall detect gas concentrations from 1 to 1000 ppm */
        }
        
        require constraint responseTime {
            doc /* System shall respond within 30 seconds of gas exposure */
        }
        
        require constraint sensitivity {
            doc /* System shall detect concentration changes of 1 ppm or greater */
        }
    }
    
    requirement def AccuracyRequirement {
        doc /* Requirements for measurement accuracy and reliability */
        
        subject system : ChemiresistorSystem;
        
        require constraint measurementAccuracy {
            doc /* Concentration measurements shall be accurate within ±5% of actual value */
        }
        
        require constraint repeatability {
            doc /* Repeated measurements under identical conditions shall vary by no more than ±2% */
        }
        
        require constraint stability {
            doc /* Baseline drift shall not exceed 1% over 24 hours of continuous operation */
        }
    }
    
    requirement def SafetyRequirement {
        doc /* Requirements for alarm functionality and safety features */
        
        subject system : ChemiresistorSystem;
        
        require constraint alarmActivation {
            doc /* Alarm shall activate within 5 seconds when concentration exceeds threshold */
        }
        
        require constraint alarmReliability {
            doc /* Alarm shall not produce false positives more than once per 1000 hours */
        }
    }
    
    requirement <'SYS-REQ-001'> detectionPerformance : DetectionPerformanceRequirement {
        subject systemUnderTest = chemiresistorSystem;
    }
    
    requirement <'SYS-REQ-002'> measurementAccuracy : AccuracyRequirement {
        subject systemUnderTest = chemiresistorSystem;
    }
    
    requirement <'SYS-REQ-003'> safetyCompliance : SafetyRequirement {
        subject systemUnderTest = chemiresistorSystem;
    }
    
    requirement <'SYS-REQ-MAIN'> primarySystemFunction {
        doc /* 
            The chemiresistor-based gas detection system shall continuously monitor
            the surrounding environment for the presence of target gases by measuring
            resistance changes in a chemically sensitive material. Upon detecting gas
            concentrations, the system shall process the sensor signal through analog
            and digital stages to accurately quantify the concentration level. When
            measured concentrations exceed predefined safety thresholds, the system
            shall immediately activate alarm indicators to warn personnel of hazardous
            conditions, thereby providing reliable early detection and protection
            against toxic or combustible gas exposure.
        */
        
        assume constraint operatingEnvironment {
            doc /* System operates within specified temperature and humidity ranges */
        }
        
        require detectionPerformance;
        require measurementAccuracy;
        require safetyCompliance;
    }
}

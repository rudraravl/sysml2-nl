package TemperatureGaugeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def TemperatureValue :> ThermodynamicTemperatureValue;
    
    enum def OperatingMode {
        standby;
        active;
        calibration;
    }
    
    enum def AlertStatus {
        normal;
        warning;
        critical;
    }
    
    item def TemperatureReading {
        attribute value : TemperatureValue;
        attribute timestamp : TimeInstantValue;
        attribute quality : Real;
    }
    
    port def SensorPort {
        out item reading : TemperatureReading;
    }
    
    port def DisplayPort {
        in item data : TemperatureReading;
    }
    
    port def ControlPort {
        in item command : String;
        out item status : String;
    }
    
    part def Sensor {
        attribute sensorId : String;
        attribute measurementRangeLow : TemperatureValue;
        attribute measurementRangeHigh : TemperatureValue;
        attribute accuracy : TemperatureValue;
        attribute currentTemp : TemperatureValue;
        
        port sensorOut : SensorPort;
        
        action def MeasureTemperature {
            out reading : TemperatureReading;
        }
        
        perform action continuousSensing {
            first start;
            then merge measureLoop;
            
            then action measure : MeasureTemperature {
                out tempReading : TemperatureReading;
            }
            
            then action transmit {
                in data = measure.tempReading;
            }
            
            then measureLoop;
        }
    }
    
    part def Processor {
        attribute calibrationFactor : Real;
        attribute samplingInterval : DurationValue;
        attribute warningLimit : TemperatureValue;
        attribute criticalLimit : TemperatureValue;
        attribute processedValue : TemperatureValue;
        
        action def ProcessReading {
            in rawReading : TemperatureReading;
            out processedReading : TemperatureReading;
            out alert : AlertStatus;
        }
        
        action def EvaluateThresholds {
            in temperature : TemperatureValue;
            in warningThreshold : TemperatureValue;
            in criticalThreshold : TemperatureValue;
            out alertLevel : AlertStatus;
        }
        
        perform action dataProcessing {
            first start;
            then merge processingLoop;
            
            then action process : ProcessReading {
                in rawReading : TemperatureReading;
                out processedReading : TemperatureReading;
                out alert : AlertStatus;
            }
            
            then action evaluate : EvaluateThresholds {
                in temperature = process.processedReading.value;
                in warningThreshold : TemperatureValue;
                in criticalThreshold : TemperatureValue;
                out alertLevel : AlertStatus;
            }
            
            then processingLoop;
        }
    }
    
    part def Display {
        attribute displayMode : OperatingMode;
        attribute brightness : Real;
        attribute displayedTemperature : TemperatureValue;
        attribute currentAlert : AlertStatus;
        
        port displayIn : DisplayPort;
        
        action def UpdateDisplay {
            in reading : TemperatureReading;
            in alertStatus : AlertStatus;
        }
        
        action def RenderValue {
            in temperature : TemperatureValue;
            in mode : OperatingMode;
        }
        
        perform action displayOperation {
            first start;
            then merge displayLoop;
            
            then action update : UpdateDisplay {
                in reading : TemperatureReading;
                in alertStatus : AlertStatus;
            }
            
            then displayLoop;
        }
    }
    
    part def TemperatureGauge {
        attribute gaugeId : String;
        attribute operatingVoltage : Real;
        attribute currentMode : OperatingMode;
        
        part sensor : Sensor {
            attribute :>> sensorId = "TEMP-SENSOR-001";
            attribute :>> measurementRangeLow = -40.0 [°C];
            attribute :>> measurementRangeHigh = 150.0 [°C];
            attribute :>> accuracy = 0.5 [°C];
            attribute :>> currentTemp = 25.0 [°C];
        }
        
        part processor : Processor {
            attribute :>> calibrationFactor = 1.0;
            attribute :>> samplingInterval = 1.0 [s];
            attribute :>> warningLimit = 80.0 [°C];
            attribute :>> criticalLimit = 100.0 [°C];
            attribute :>> processedValue = 25.0 [°C];
        }
        
        part display : Display {
            attribute :>> displayMode = OperatingMode::active;
            attribute :>> brightness = 75.0;
            attribute :>> displayedTemperature = 25.0 [°C];
            attribute :>> currentAlert = AlertStatus::normal;
        }
        
        connection sensorToProcessor {
            end sensor.sensorOut;
            end processor;
        }
        
        connection processorToDisplay {
            end processor;
            end display.displayIn;
        }
        
        perform action operateGauge references gaugeOperation;
    }
    
    action gaugeOperation {
        first start;
        then fork;
        
        then action sense : Sensor::MeasureTemperature {
            out sensorReading : TemperatureReading;
        }
        
        then action process : Processor::ProcessReading {
            in rawReading = sense.sensorReading;
            out processedReading : TemperatureReading;
            out alert : AlertStatus;
        }
        
        then action show : Display::UpdateDisplay {
            in reading = process.processedReading;
            in alertStatus = process.alert;
        }
        
        then join;
        then done;
    }
    
    state def GaugeStateMachine {
        entry; then standbyState;
        
        state standbyState;
        
        transition standby_to_active
            first standbyState
            accept PowerOn
            then activeState;
        
        state activeState {
            entry; then monitoring;
            
            state monitoring {
                state normalMonitoring;
                state warningMonitoring;
                state criticalMonitoring;
                
                entry; then normalMonitoring;
                
                transition normal_to_warning
                    first normalMonitoring
                    then warningMonitoring;
                
                transition warning_to_critical
                    first warningMonitoring
                    then criticalMonitoring;
                
                transition critical_to_warning
                    first criticalMonitoring
                    then warningMonitoring;
                
                transition warning_to_normal
                    first warningMonitoring
                    then normalMonitoring;
            }
        }
        
        transition active_to_calibration
            first activeState
            accept StartCalibration
            then calibrationState;
        
        state calibrationState;
        
        transition calibration_to_active
            first calibrationState
            accept CalibrationComplete
            then activeState;
        
        transition active_to_standby
            first activeState
            accept PowerOff
            then standbyState;
    }
    
    requirement def AccuracyRequirement {
        doc /* The temperature gauge shall measure temperature 
             * with accuracy within the specified tolerance.
             */
        subject gauge : TemperatureGauge;
        require constraint {
            gauge.sensor.accuracy <= 1.0 [°C]
        }
    }
    
    requirement def RangeRequirement {
        doc /* The temperature gauge shall operate over the 
             * specified temperature range.
             */
        subject gauge : TemperatureGauge;
        require constraint {
            gauge.sensor.measurementRangeLow >= -40.0 [°C] and
            gauge.sensor.measurementRangeHigh <= 150.0 [°C]
        }
    }
    
    requirement def ResponseRequirement {
        doc /* The temperature gauge shall update the display 
             * within the specified sampling interval.
             */
        subject gauge : TemperatureGauge;
        require constraint {
            gauge.processor.samplingInterval <= 2.0 [s]
        }
    }
    
    requirement def AlertRequirement {
        doc /* The temperature gauge shall provide visual alerts 
             * when temperature exceeds warning or critical thresholds.
             */
        subject gauge : TemperatureGauge;
        require constraint {
            gauge.processor.warningLimit < gauge.processor.criticalLimit
        }
    }
    
    requirement <'REQ-TG-PRIMARY'> primaryFunction {
        doc /* The temperature gauge system shall continuously measure 
             * ambient or process temperature using a calibrated sensor, 
             * process the measurement data to ensure accuracy and quality, 
             * evaluate the temperature against configurable warning and 
             * critical thresholds, and display the current temperature 
             * value with appropriate visual alert indicators to inform 
             * the operator of system status.
             */
        subject gauge : TemperatureGauge;
        
        assume constraint operationalEnvironment {
            gauge.sensor.currentTemp >= gauge.sensor.measurementRangeLow and
            gauge.sensor.currentTemp <= gauge.sensor.measurementRangeHigh
        }
        
        assume constraint powerAvailable {
            gauge.operatingVoltage >= 10.0 and
            gauge.operatingVoltage <= 14.0
        }
        
        require accuracy : AccuracyRequirement {
            subject gauge = primaryFunction.gauge;
        }
        
        require range : RangeRequirement {
            subject gauge = primaryFunction.gauge;
        }
        
        require response : ResponseRequirement {
            subject gauge = primaryFunction.gauge;
        }
        
        require alerting : AlertRequirement {
            subject gauge = primaryFunction.gauge;
        }
    }
    
    part temperatureGaugeInstance : TemperatureGauge {
        attribute :>> gaugeId = "TG-MAIN-001";
        attribute :>> operatingVoltage = 12.0;
        attribute :>> currentMode = OperatingMode::active;
        
        part :>> sensor {
            attribute :>> currentTemp = 25.0 [°C];
        }
        
        part :>> processor {
            attribute :>> processedValue = 25.0 [°C];
        }
        
        part :>> display {
            attribute :>> displayedTemperature = 25.0 [°C];
            attribute :>> currentAlert = AlertStatus::normal;
        }
    }
    
    satisfy primaryFunction by temperatureGaugeInstance;
}

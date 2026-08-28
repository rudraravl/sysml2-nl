package SuddenMotionSensingUnit {
    import ScalarValues::*;
    import ISQ::*;
    import ISQAcceleration::*;
    import ISQTime::*;

    // ---- Value types ----
    def type AccelerationMagnitude :> Real { 
        value :>> unit = AccelerationUnit { 
            redefines name = "m/s^2"; 
        } 
    }
    def type ThresholdValue :> AccelerationMagnitude;
    def type SeverityValue :> Real;
    def type TimestampValue :> Real {
        value :>> unit = TimeUnit {
            redefines name = "ms";
        }
    }
    def type PowerLevel :> Real {
        value :>> unit = PowerUnit {
            redefines name = "mW";
        }
    }

    // ---- Item types ----
    item def AnalogAccelerationSample {
        attribute x : Real; // volts
        attribute y : Real;
        attribute z : Real;
    }
    item def DigitalAccelerationSample {
        attribute x : AccelerationMagnitude;
        attribute y : AccelerationMagnitude;
        attribute z : AccelerationMagnitude;
        attribute timestamp : TimestampValue;
    }
    item def CalibratedAccelerationSample {
        attribute x : AccelerationMagnitude;
        attribute y : AccelerationMagnitude;
        attribute z : AccelerationMagnitude;
        attribute timestamp : TimestampValue;
        attribute calibrated : Boolean = true;
    }
    item def MotionEvent {
        attribute timestamp : TimestampValue;
        attribute magnitude : AccelerationMagnitude;
        attribute severity : SeverityValue;
        attribute axis : String;
    }
    item def PowerCommand {
        attribute command : String;
    }
    item def ThresholdConfig {
        attribute threshold : ThresholdValue;
    }

    // ---- Ports ----
    port def AnalogSamplePort {
        out item : AnalogAccelerationSample;
    }
    port def DigitalSamplePort {
        out item : DigitalAccelerationSample;
    }
    port def CalibratedSamplePort {
        out item : CalibratedAccelerationSample;
    }
    port def MotionEventPort {
        out item : MotionEvent;
    }
    port def CommandPort {
        in item : PowerCommand;
        in item : ThresholdConfig;
    }

    // ---- Parts ----
    part def MEMSAccelerometer {
        attribute sampleRate : Real = 1000.0; // Hz
        port rawOut : AnalogSamplePort;
        
        action def GenerateAnalogSample {
            out sample : AnalogAccelerationSample;
        }
        action generate : GenerateAnalogSample {
            // Simulate continuous measurement
        }
    }

    part def SignalConditioner {
        attribute gain : Real = 100.0;
        attribute noiseFloor : Real = 0.001;
        port analogIn : AnalogSamplePort;
        port conditionedOut : AnalogSamplePort;
        
        action def Condition {
            in raw : AnalogAccelerationSample;
            out conditioned : AnalogAccelerationSample;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 16;
        attribute samplingRate : Real = 1000.0;
        port analogIn : AnalogSamplePort;
        port digitalOut : DigitalSamplePort;
        
        action def Convert {
            in analog : AnalogAccelerationSample;
            out digital : DigitalAccelerationSample;
        }
    }

    part def DataProcessor {
        attribute offsetX : AccelerationMagnitude = 0.0;
        attribute offsetY : AccelerationMagnitude = 0.0;
        attribute offsetZ : AccelerationMagnitude = 0.0;
        attribute scaleX : Real = 1.0;
        attribute scaleY : Real = 1.0;
        attribute scaleZ : Real = 1.0;
        port digitalIn : DigitalSamplePort;
        port calibratedOut : CalibratedSamplePort;
        
        action def Calibrate {
            in raw : DigitalAccelerationSample;
            out calibrated : CalibratedAccelerationSample;
        }
    }

    part def EventAnalyzer {
        attribute defaultThreshold : ThresholdValue = 9.81 * 3.0; // ~3g
        attribute currentThreshold : ThresholdValue = defaultThreshold;
        port calibratedIn : CalibratedSamplePort;
        port eventOut : MotionEventPort;
        port configIn : CommandPort;
        
        action def Analyze {
            in sample : CalibratedAccelerationSample;
            out event : MotionEvent[0..1];
            
            // Compute magnitude
            attribute mag : AccelerationMagnitude = 
                (sample.x^2 + sample.y^2 + sample.z^2)^0.5;
            
            if mag > currentThreshold {
                // Determine dominant axis
                attribute axisStr : String;
                if sample.x.abs >= sample.y.abs and sample.x.abs >= sample.z.abs {
                    axisStr = "x";
                } else if sample.y.abs >= sample.z.abs {
                    axisStr = "y";
                } else {
                    axisStr = "z";
                }
                
                event = MotionEvent {
                    timestamp = sample.timestamp;
                    magnitude = mag;
                    severity = mag / currentThreshold;
                    axis = axisStr;
                };
            }
        }
    }

    part def PowerController {
        attribute supplyVoltage : Real = 3.3; // V
        attribute activePower : PowerLevel = 5.0;
        attribute standbyPower : PowerLevel = 0.1;
        attribute initPower : PowerLevel = 8.0;
        attribute alertPower : PowerLevel = 12.0;
        port commandIn : CommandPort;
    }

    part def ReportingInterface {
        port eventIn : MotionEventPort;
        port externalOut : MotionEventPort;
        
        action def ReportEvent {
            in event : MotionEvent;
            out reported : MotionEvent;
        }
    }

    // ---- Top-level part ----
    part def SuddenMotionSensor {
        attribute deviceId : String;
        attribute responseTimeMs : Real = 5.0;
        attribute batteryOperated : Boolean = true;
        
        port externalCommand : CommandPort;
        port externalEventOut : MotionEventPort;
        
        part memsAccelerometer : MEMSAccelerometer;
        part signalConditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter;
        part dataProcessor : DataProcessor;
        part eventAnalyzer : EventAnalyzer;
        part powerController : PowerController;
        part reportingInterface : ReportingInterface;
        
        connection memsToConditioner : AnalogSamplePort 
            connect memsAccelerometer.rawOut to signalConditioner.analogIn;
        connection conditionerToADC : AnalogSamplePort 
            connect signalConditioner.conditionedOut to adc.analogIn;
        connection adcToProcessor : DigitalSamplePort 
            connect adc.digitalOut to dataProcessor.digitalIn;
        connection processorToAnalyzer : CalibratedSamplePort 
            connect dataProcessor.calibratedOut to eventAnalyzer.calibratedIn;
        connection analyzerToReporting : MotionEventPort 
            connect eventAnalyzer.eventOut to reportingInterface.eventIn;
        connection reportingToExternal : MotionEventPort 
            connect reportingInterface.externalOut to externalEventOut;
        connection commandToPower : CommandPort 
            connect externalCommand to powerController.commandIn;
        connection commandToAnalyzer : CommandPort 
            connect externalCommand to eventAnalyzer.configIn;
        
        // ---- State machine ----
        state def MotionSensorStates {
            entry action initSelfChecks {
                // Perform power-on self-test
            }
            
            state initialization {
                entry action startInit {
                    // Run diagnostics on MEMS, ADC, processor
                }
                do action runDiagnostics {
                    // Verify sensor integrity
                }
                transition to standby 
                    when powerController.commandIn.command == "standby" 
                    or true;
            }
            
            state standby {
                entry action enterLowPower {
                    // Reduce clock, disable ADC sampling
                }
                do action maintainStandby {
                    // Minimal power draw
                }
                transition to active 
                    when powerController.commandIn.command == "activate";
            }
            
            state active {
                entry action activateMonitoring {
                    // Enable full sampling pipeline
                }
                do action monitorLoop {
                    // Continuous: measure -> condition -> convert -> calibrate -> analyze
                    send memsAccelerometer.generate.sample to signalConditioner.analogIn;
                }
                transition to alert 
                    when eventAnalyzer.eventOut.item->notEmpty();
            }
            
            state alert {
                entry action raiseAlert {
                    // Package and transmit motion event
                }
                do action reportAlert {
                    // Send event through reporting interface
                }
                transition to active 
                    after 2 [ms];
            }
            
            transition initialization to standby;
            transition standby to active;
            transition active to alert;
            transition alert to active;
        }
        
        exhibit state sensorStateMachine : MotionSensorStates;
    }

    // ---- Requirements ----
    requirement def ThreeAxisDetectionRequirement {
        subject sensor : SuddenMotionSensor;
        requirement 
            "The sensor shall measure acceleration in three orthogonal axes (x, y, z).";
    }
    
    requirement def ThresholdDetectionRequirement {
        subject sensor : SuddenMotionSensor;
        attribute minThreshold : ThresholdValue = 9.81 * 2.0; // 2g
        requirement 
            "The sensor shall generate a motion event when acceleration magnitude exceeds the configured threshold.";
    }
    
    requirement def ResponseTimeRequirement {
        subject sensor : SuddenMotionSensor;
        attribute maxResponseTime : TimestampValue = 10.0; // ms
        requirement 
            "The sensor shall detect and report a motion event within {maxResponseTime} milliseconds of occurrence.";
    }
    
    requirement def PowerEfficiencyRequirement {
        subject sensor : SuddenMotionSensor;
        attribute maxStandbyPower : PowerLevel = 0.5;
        attribute maxActivePower : PowerLevel = 10.0;
        requirement 
            "The sensor shall consume no more than {maxStandbyPower} in standby and {maxActivePower} in active mode.";
    }
    
    requirement def StateTransitionRequirement {
        subject sensor : SuddenMotionSensor;
        requirement 
            "The sensor shall transition through initialization, standby, active, and alert states as defined by the state machine.";
    }
    
    requirement def CalibrationRequirement {
        subject sensor : SuddenMotionSensor;
        requirement 
            "The data processor shall apply calibration offsets and scale factors to digitized acceleration samples before analysis.";
    }
    
    package SensorRequirements {
        requirement threeAxisReq : ThreeAxisDetectionRequirement;
        requirement thresholdReq : ThresholdDetectionRequirement;
        requirement responseTimeReq : ResponseTimeRequirement;
        requirement powerReq : PowerEfficiencyRequirement;
        requirement stateReq : StateTransitionRequirement;
        requirement calibrationReq : CalibrationRequirement;
    }
}

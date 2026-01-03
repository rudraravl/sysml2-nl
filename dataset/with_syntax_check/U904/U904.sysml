package TachometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def RPMValue :> ISQ::AngularVelocityValue {
        attribute :>> num : Real;
        attribute :>> mRef : AngularVelocityUnit;
    }
    
    attribute def PulseSignal {
        attribute pulseCount : Integer;
        attribute timeWindow : DurationValue;
    }
    
    attribute def CalibrationData {
        attribute pulsesPerRevolution : Integer;
        attribute correctionFactor : Real;
    }
    
    port def RotationalInputPort {
        in shaftSpeed : RPMValue;
    }
    
    port def SensorOutputPort {
        out pulseData : PulseSignal;
    }
    
    port def ProcessorInputPort {
        in pulseData : PulseSignal;
    }
    
    port def ProcessorOutputPort {
        out calculatedRPM : RPMValue;
    }
    
    port def DisplayInputPort {
        in rpmValue : RPMValue;
    }
    
    port def PowerSupplyPort {
        in voltage : ISQ::ElectricPotentialValue;
        in current : ISQ::ElectricCurrentValue;
    }
    
    part def MagneticSensor {
        attribute calibration : CalibrationData {
            :>> pulsesPerRevolution = 60;
            :>> correctionFactor = 1.0;
        }
        
        port shaftInput : RotationalInputPort;
        port sensorOut : SensorOutputPort;
        port power : PowerSupplyPort;
        
        action detectPulses {
            in rotationSpeed : RPMValue;
            out pulses : PulseSignal;
            
            first start;
            then action generatePulses {
                in speed = rotationSpeed;
                out signal : PulseSignal;
            }
            then done;
        }
        
        perform action sensing {
            in speed = shaftInput.shaftSpeed;
            out output = sensorOut.pulseData;
            
            loop {
                perform detectPulses;
            }
        }
    }
    
    part def SignalProcessor {
        attribute calibrationSettings : CalibrationData;
        
        port processorIn : ProcessorInputPort;
        port processorOut : ProcessorOutputPort;
        port power : PowerSupplyPort;
        
        action computeRPM {
            in rawPulses : PulseSignal;
            in calibration : CalibrationData;
            out rpm : RPMValue;
            
            first start;
            then action countPulses {
                in pulseData = rawPulses;
                out count : Integer;
            }
            then action calculateFrequency {
                in pulseCount = countPulses.count;
                in timeInterval = rawPulses.timeWindow;
                out frequency : Real;
            }
            then action convertToRPM {
                in freq = calculateFrequency.frequency;
                in pulsesPerRev = calibration.pulsesPerRevolution;
                in correction = calibration.correctionFactor;
                out rotationalSpeed : RPMValue;
            }
            then done;
        }
        
        perform action processing {
            in inputSignal = processorIn.pulseData;
            out outputRPM = processorOut.calculatedRPM;
            
            loop {
                perform computeRPM;
            }
        }
    }
    
    part def DigitalDisplay {
        attribute maxDisplayRange : Real = 10000.0;
        attribute updateFrequency : FrequencyValue;
        attribute displayResolution : Real = 1.0;
        
        port displayIn : DisplayInputPort;
        port power : PowerSupplyPort;
        
        state def DisplayStates {
            entry; then off;
            
            state off;
            state idle;
            state active;
            state warning;
            
            transition off_to_idle
                first off
                accept powerVoltage : ISQ::ElectricPotentialValue
                then idle;
            
            transition idle_to_active
                first idle
                accept rpmInput : RPMValue
                then active;
            
            transition active_normal
                first active
                accept normalRPM : RPMValue
                then active;
            
            transition active_to_warning
                first active
                accept highRPM : RPMValue
                then warning;
            
            transition warning_to_active
                first warning
                accept normalRPM : RPMValue
                then active;
            
            transition active_to_idle
                first active
                accept zeroRPM : RPMValue
                then idle;
            
            transition idle_to_off
                first idle
                accept powerOff : ISQ::ElectricPotentialValue
                then off;
        }
        
        perform action displayOperation {
            in inputValue = displayIn.rpmValue;
        }
    }
    
    part def Tachometer {
        doc /* 
            A tachometer system that continuously measures and displays 
            the rotational speed of a shaft in revolutions per minute (RPM).
        */
        
        port rotationalInput : RotationalInputPort;
        port powerSupply : PowerSupplyPort;
        
        part sensor : MagneticSensor {
            :>> calibration.pulsesPerRevolution = 60;
            :>> calibration.correctionFactor = 0.98;
        }
        
        part processor : SignalProcessor {
            :>> calibrationSettings.pulsesPerRevolution = 60;
            :>> calibrationSettings.correctionFactor = 0.98;
        }
        
        part display : DigitalDisplay {
            :>> maxDisplayRange = 8000.0;
            :>> displayResolution = 10.0;
        }
        
        connection sensorToProcessor connect 
            sensor.sensorOut to processor.processorIn;
        
        connection processorToDisplay connect 
            processor.processorOut to display.displayIn;
        
        connection inputToSensor connect 
            rotationalInput to sensor.shaftInput;
        
        connection powerToSensor connect 
            powerSupply to sensor.power;
        
        connection powerToProcessor connect 
            powerSupply to processor.power;
        
        connection powerToDisplay connect 
            powerSupply to display.power;
        
        perform action measureAndDisplay {
            doc /* 
                Primary function: Continuously sense shaft rotation, 
                process the signal to calculate RPM, and display the result.
            */
            
            first start;
            then action senseRotation {
                perform sensor.sensing;
            }
            flow senseRotation.output to processSignal.inputSignal;
            then action processSignal {
                perform processor.processing;
            }
            flow processSignal.outputRPM to showSpeed.value;
            then action showSpeed {
                in value : RPMValue;
            }
            then done;
        }
    }
    
    action def MeasureRotationalSpeed {
        in shaftRotation : RPMValue;
        out displayedSpeed : RPMValue;
    }
    
    part vehicleTachometer : Tachometer;
    
    requirement def AccuracyRequirement {
        doc /* The tachometer shall measure rotational speed within specified accuracy. */
        
        attribute tolerancePercent : Real;
        attribute operatingRangeMin : RPMValue;
        attribute operatingRangeMax : RPMValue;
        
        require constraint accuracyBound {
            doc /* Measurement error shall not exceed tolerance across operating range. */
        }
    }
    
    requirement def ResponseRequirement {
        doc /* The tachometer shall update display within specified response time. */
        
        attribute maxResponseTime : DurationValue;
        attribute minUpdateRate : FrequencyValue;
        
        require constraint responseTimeBound {
            doc /* Display update shall occur within maximum response time. */
        }
    }
    
    requirement def ReliabilityRequirement {
        doc /* The tachometer shall operate reliably under specified conditions. */
        
        attribute operatingTemperatureMin : ISQ::ThermodynamicTemperatureValue;
        attribute operatingTemperatureMax : ISQ::ThermodynamicTemperatureValue;
        attribute meanTimeBetweenFailures : DurationValue;
        
        require constraint environmentalTolerance {
            doc /* System shall function within environmental limits. */
        }
    }
    
    requirement <'TACH-SYS-001'> primaryFunction {
        doc /* 
            The tachometer system shall continuously measure the rotational speed 
            of a rotating shaft and display the speed in revolutions per minute (RPM) 
            with high accuracy and minimal latency for real-time monitoring.
        */
        
        subject vehicleTachometer;
        
        require accuracyReq : AccuracyRequirement {
            :>> tolerancePercent = 1.5;
        }
        
        require responseReq : ResponseRequirement {
            :>> minUpdateRate = 10.0 [Hz];
        }
        
        require reliabilityReq : ReliabilityRequirement;
        
        assume constraint powerAvailable {
            doc /* Stable electrical power supply is available to the system. */
        }
        
        assume constraint mechanicalCoupling {
            doc /* Sensor is properly mounted and coupled to rotating shaft. */
        }
    }
}

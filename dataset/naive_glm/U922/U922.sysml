package IndustrialPressureTransducer {
    import ScalarValues::*;

    // Value Types
    value type PressureValue :> Real;
    value type VoltageValue :> Real;
    value type TemperatureValue :> Real;
    value type TimeValue :> Real;
    value type EfficiencyValue :> Real;
    value type FrequencyValue :> Real;
    value type CurrentValue :> Real;

    // Item Definitions
    item def MechanicalPressureFlow {
        attribute pressure : PressureValue;
    }
    item def DisplacementFlow {
        attribute displacement : Real;
    }
    item def RawElectricalSignal {
        attribute voltage : VoltageValue;
    }
    item def ConditionedVoltageSignal {
        attribute voltage : VoltageValue;
    }
    item def DCPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    // Port Definitions
    port def PressureInputPort {
        in pressure : MechanicalPressureFlow;
    }
    port def DisplacementInPort {
        in displacement : DisplacementFlow;
    }
    port def DisplacementOutPort {
        out displacement : DisplacementFlow;
    }
    port def RawSignalInPort {
        in signal : RawElectricalSignal;
    }
    port def RawSignalOutPort {
        out signal : RawElectricalSignal;
    }
    port def ConditionedSignalInPort {
        in signal : ConditionedVoltageSignal;
    }
    port def ConditionedSignalOutPort {
        out signal : ConditionedVoltageSignal;
    }
    port def DCPowerInPort {
        in power : DCPower;
    }
    port def DCPowerOutPort {
        out power : DCPower;
    }

    // Component Definitions
    part def SensingElement {
        attribute responseTime : TimeValue = 0.5;
        in port pressureIn : PressureInputPort;
        out port mechanicalOut : DisplacementOutPort;
        
        action def SensePressure {
            in pressure : MechanicalPressureFlow;
            out displacement : DisplacementFlow;
        }
    }

    part def ConversionElement {
        attribute sensitivity : Real = 0.01;
        in port mechanicalIn : DisplacementInPort;
        out port rawSignalOut : RawSignalOutPort;
        
        action def ConvertToSignal {
            in displacement : DisplacementFlow;
            out rawSignal : RawElectricalSignal;
        }
    }

    part def SignalProcessor {
        attribute gain : Real = 10.0;
        attribute bandwidth : FrequencyValue = 5000.0;
        in port rawSignalIn : RawSignalInPort;
        in port powerIn : DCPowerInPort;
        out port processedSignalOut : ConditionedSignalOutPort;
        
        action def ProcessSignal {
            in rawSignal : RawElectricalSignal;
            out processedSignal : ConditionedVoltageSignal;
        }
    }

    part def PowerSupply {
        attribute outputVoltage : VoltageValue = 24.0;
        in port mainPowerIn : DCPowerInPort;
        out port regulated24VOut : DCPowerOutPort;
        
        action def RegulatePower {
            in inputPower : DCPower;
            out regulatedPower : DCPower;
        }
    }

    // Main System
    part def PressureTransducerSystem {
        attribute operatingTempMin : TemperatureValue = -40.0;
        attribute operatingTempMax : TemperatureValue = 125.0;
        attribute efficiency : EfficiencyValue = 90.0;
        attribute calibrationComplete : Boolean = false;
        
        in port systemPressureIn : PressureInputPort;
        in port systemPowerIn : DCPowerInPort;
        out port systemVoltageOut : ConditionedSignalOutPort;
        
        part diaphragm : SensingElement;
        part coreConverter : ConversionElement;
        part processor : SignalProcessor;
        part powerSupply : PowerSupply;
        
        connection pressureToDiaphragm connect systemPressureIn to diaphragm.pressureIn;
        connection diaphragmToConverter connect diaphragm.mechanicalOut to coreConverter.mechanicalIn;
        connection converterToProcessor connect coreConverter.rawSignalOut to processor.rawSignalIn;
        connection processorToOutput connect processor.processedSignalOut to systemVoltageOut;
        connection powerToProcessor connect powerSupply.regulated24VOut to processor.powerIn;
        connection powerInToSupply connect systemPowerIn to powerSupply.mainPowerIn;
        
        state machine TransducerLifecycle {
            state off;
            state initializing {
                entry action initializeComponents {
                    // initialize internal components
                }
            }
            state calibrating {
                entry action performSelfCalibration {
                    // perform self-calibration to ensure readings are accurate
                    calibrationComplete = true;
                }
            }
            state operational {
                do action continuousSensing {
                    // continuous cycle of sensing, converting, processing, transmitting
                }
            }
            transition off_to_initializing off -> initializing when systemPowerIn.power.voltage > 0.0;
            transition init_to_calib initializing -> calibrating after 100.0;
            transition calib_to_op calibrating -> operational when calibrationComplete == true;
        }
    }

    // Requirements
    requirement def PressureMeasurementRequirement {
        subject transducer : PressureTransducerSystem;
        doc /* The transducer shall measure mechanical pressure and convert it into a proportional electrical voltage signal. */;
    }

    requirement def ResponseTimeRequirement {
        subject sensingElement : SensingElement;
        doc /* The sensing element shall detect changes in pressure with a response time of less than 1 ms. */;
        attribute maxResponseTime : TimeValue = 1.0;
    }

    requirement def EnvironmentalRequirement {
        subject transducer : PressureTransducerSystem;
        doc /* The transducer shall function across a wide temperature range from -40 C to +125 C. */;
        attribute minOperatingTemp : TemperatureValue = -40.0;
        attribute maxOperatingTemp : TemperatureValue = 125.0;
    }

    requirement def EfficiencyRequirement {
        subject transducer : PressureTransducerSystem;
        doc /* The transducer shall be highly sensitive and efficient (over 88% efficiency). */;
        attribute minEfficiency : EfficiencyValue = 88.0;
    }

    requirement def PowerRequirement {
        subject powerSupply : PowerSupply;
        doc /* The power supply shall provide a regulated 24-volt DC to its components. */;
        attribute outputVoltage : VoltageValue = 24.0;
    }
}

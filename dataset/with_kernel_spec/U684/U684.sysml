package DigitalForceGauge {
    private import ScalarValues::*;
    
    value def ForceValue :> Real;
    value def VoltageValue :> Real;
    value def DigitalValue :> Integer;
    
    port def ForceInPort {
        in appliedForce : ForceValue;
    }
    port def VoltageOutPort {
        out voltage : VoltageValue;
    }
    port def VoltageInPort {
        in voltage : VoltageValue;
    }
    port def DigitalOutPort {
        out digitalValue : DigitalValue;
    }
    port def DigitalInPort {
        in digitalValue : DigitalValue;
    }
    port def ForceOutPort {
        out calculatedForce : ForceValue;
    }
    port def ForceInReadingPort {
        in calculatedForce : ForceValue;
    }
    port def PowerOutPort {
        out power : VoltageValue;
    }
    port def PowerInPort {
        in power : VoltageValue;
    }
    
    action def SenseForce {
        in appliedForce : ForceValue;
        out rawVoltage : VoltageValue;
    }
    action def AmplifySignal {
        in rawVoltage : VoltageValue;
        out amplifiedVoltage : VoltageValue;
    }
    action def ConvertSignal {
        in amplifiedVoltage : VoltageValue;
        out digitalValue : DigitalValue;
    }
    action def ProcessData {
        in digitalValue : DigitalValue;
        in calibrationFactor : Real;
        in zeroOffset : Real;
        out calculatedForce : ForceValue;
    }
    action def Calibrate {
        in referenceForce : ForceValue;
        in digitalValue : DigitalValue;
        out factor : Real;
        out offset : Real;
    }
    action def DisplayForce {
        in calculatedForce : ForceValue;
    }
    
    part def StrainGaugeSensor {
        port forceIn : ForceInPort;
        port voltageOut : VoltageOutPort;
        perform SenseForce {
            in appliedForce = forceIn.appliedForce;
            out rawVoltage = voltageOut.voltage;
        }
    }
    
    part def SignalAmplifier {
        port voltageIn : VoltageInPort;
        port voltageOut : VoltageOutPort;
        perform AmplifySignal {
            in rawVoltage = voltageIn.voltage;
            out amplifiedVoltage = voltageOut.voltage;
        }
    }
    
    part def ADC {
        port analogIn : VoltageInPort;
        port digitalOut : DigitalOutPort;
        perform ConvertSignal {
            in amplifiedVoltage = analogIn.voltage;
            out digitalValue = digitalOut.digitalValue;
        }
    }
    
    part def Microprocessor {
        attribute calibrationFactor : Real = 1.0;
        attribute zeroOffset : Real = 0.0;
        
        port digitalIn : DigitalInPort;
        port forceOut : ForceOutPort;
        port calibrationIn : ForceInPort;
        port powerIn : PowerInPort;
        
        action processData : ProcessData {
            in digitalValue = digitalIn.digitalValue;
            in calibrationFactor = calibrationFactor;
            in zeroOffset = zeroOffset;
            out calculatedForce = forceOut.calculatedForce;
        }
        
        action calibrate : Calibrate {
            in referenceForce = calibrationIn.appliedForce;
            in digitalValue = digitalIn.digitalValue;
            out factor = calibrationFactor;
            out offset = zeroOffset;
        }
        
        state def GaugeStates {
            state idle;
            state measuring {
                perform processData;
            }
            state calibrating {
                perform calibrate;
            }
            transition initial to idle;
            transition idle to measuring;
            transition measuring to idle;
            transition idle to calibrating;
            transition calibrating to idle;
        }
        
        exhibit GaugeStates;
    }
    
    part def DisplayUnit {
        port forceIn : ForceInReadingPort;
        port powerIn : PowerInPort;
        perform DisplayForce {
            in calculatedForce = forceIn.calculatedForce;
        }
    }
    
    part def PowerSupply {
        port powerOut : PowerOutPort;
    }
    
    part def DigitalForceGaugeSystem {
        attribute maxForce : ForceValue = 5000;
        attribute accuracy : Real = 0.01;
        
        part strainGaugeSensor : StrainGaugeSensor;
        part signalAmplifier : SignalAmplifier;
        part adc : ADC;
        part microprocessor : Microprocessor;
        part displayUnit : DisplayUnit;
        part powerSupply : PowerSupply;
        
        connect strainGaugeSensor.voltageOut to signalAmplifier.voltageIn;
        connect signalAmplifier.voltageOut to adc.analogIn;
        connect adc.digitalOut to microprocessor.digitalIn;
        connect microprocessor.forceOut to displayUnit.forceIn;
        connect powerSupply.powerOut to microprocessor.powerIn;
        connect powerSupply.powerOut to displayUnit.powerIn;
    }
    
    requirement def MaxForceRange {
        doc /* The gauge shall measure forces up to 5000 Newtons. */
    }
    
    requirement def AccuracySpec {
        doc /* The gauge shall have an accuracy of at least 1%. */
    }
    
    requirement maxForceRange : MaxForceRange;
    requirement accuracySpec : AccuracySpec;
    
    part digitalForceGauge : DigitalForceGaugeSystem;
    
    satisfy maxForceRange by digitalForceGauge;
    satisfy accuracySpec by digitalForceGauge;
}

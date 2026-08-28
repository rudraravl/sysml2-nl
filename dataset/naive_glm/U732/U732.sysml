package PiezoelectricSensingUnitModel {
    import ScalarValues::*;

    // Value Types
    value def PressureValue :> Real {
        unit : PressureUnit;
    }
    unit def PressureUnit {
        :>> definition = "Pascal";
        :>> symbol = "Pa";
    }

    value def ChargeValue :> Real {
        unit : ChargeUnit;
    }
    unit def ChargeUnit {
        :>> definition = "Coulomb";
        :>> symbol = "C";
    }

    value def VoltageValue :> Real {
        unit : VoltageUnit;
    }
    unit def VoltageUnit {
        :>> definition = "Volt";
        :>> symbol = "V";
    }

    value def TemperatureValue :> Real {
        unit : TemperatureUnit;
    }
    unit def TemperatureUnit {
        :>> definition = "Kelvin";
        :>> symbol = "K";
    }

    // Items
    item def PressureMeasurement {
        :>> magnitude : PressureValue;
    }
    item def Charge {
        :>> magnitude : ChargeValue;
    }
    item def AnalogVoltage {
        :>> magnitude : VoltageValue;
    }
    item def DigitalSample {
        :>> value : Integer;
    }
    item def ControlCommand {
        :>> commandType : String;
    }
    item def StatusReport {
        :>> healthStatus : String;
    }

    // Ports
    port def PressureInPort {
        in item pressure : PressureMeasurement;
    }
    port def ChargeOutPort {
        out item charge : Charge;
    }
    port def ChargeInPort {
        in item charge : Charge;
    }
    port def VoltageOutPort {
        out item voltage : AnalogVoltage;
    }
    port def VoltageInPort {
        in item voltage : AnalogVoltage;
    }
    port def DigitalOutPort {
        out item sample : DigitalSample;
    }
    port def DigitalInPort {
        in item sample : DigitalSample;
    }
    port def CommandInPort {
        in item command : ControlCommand;
    }
    port def DataOutPort {
        out item data : PressureMeasurement;
    }
    port def StatusOutPort {
        out item status : StatusReport;
    }

    // Component Parts
    part def PiezoelectricCrystal {
        in port pressureIn : PressureInPort;
        out port chargeOut : ChargeOutPort;
        
        attribute sensitivity : Real = 100.0; // pC/Pa
        
        action def GenerateCharge {
            in pressure : PressureMeasurement;
            out charge : Charge;
        }
    }

    part def ChargeAmplifier {
        in port chargeIn : ChargeInPort;
        out port voltageOut : VoltageOutPort;
        
        attribute gain : Real = 1.0e6; // V/C
        
        action def AmplifyCharge {
            in charge : Charge;
            out voltage : AnalogVoltage;
        }
    }

    part def SignalFilter {
        in port voltageIn : VoltageInPort;
        out port voltageOut : VoltageOutPort;
        
        attribute cutoffFrequency : Real = 1000.0; // Hz
        
        action def FilterNoise {
            in voltageIn : AnalogVoltage;
            out voltageOut : AnalogVoltage;
        }
    }

    part def AnalogToDigitalConverter {
        in port voltageIn : VoltageInPort;
        out port digitalOut : DigitalOutPort;
        
        attribute resolution : Integer = 16; // bits
        attribute samplingRate : Real = 5000.0; // SPS
        
        action def ConvertAnalogToDigital {
            in voltage : AnalogVoltage;
            out sample : DigitalSample;
        }
    }

    part def SignalProcessor {
        in port digitalIn : DigitalInPort;
        in port commandIn : CommandInPort;
        out port dataOut : DataOutPort;
        out port statusOut : StatusOutPort;
        
        attribute calibrationFactor : Real = 1.0;
        
        action def ProcessData {
            in sample : DigitalSample;
            out data : PressureMeasurement;
        }
        
        action def HandleCommand {
            in command : ControlCommand;
        }
    }

    // Main System
    part def IntegratedPiezoelectricSensor {
        in port pressurePort : PressureInPort;
        in port commandPort : CommandInPort;
        out port dataPort : DataOutPort;
        out port statusPort : StatusOutPort;
        
        attribute operatingTemperatureMin : TemperatureValue = 233.15; // -40 C
        attribute operatingTemperatureMax : TemperatureValue = 398.15; // +125 C
        attribute hermeticallySealed : Boolean = true;
        
        part crystal : PiezoelectricCrystal;
        part amplifier : ChargeAmplifier;
        part filter : SignalFilter;
        part adc : AnalogToDigitalConverter;
        part processor : SignalProcessor;
        
        connection pressureConn connect pressurePort to crystal.pressureIn;
        connection chargeConn connect crystal.chargeOut to amplifier.chargeIn;
        connection ampToFilterConn connect amplifier.voltageOut to filter.voltageIn;
        connection filterToAdcConn connect filter.voltageOut to adc.voltageIn;
        connection adcToProcConn connect adc.digitalOut to processor.digitalIn;
        connection cmdConn connect commandPort to processor.commandIn;
        connection dataConn connect processor.dataOut to dataPort;
        connection statusConn connect processor.statusOut to statusPort;

        // State Machine
        state SensorLifecycle {
            attribute selfTestPassed : Boolean = false;
            attribute initComplete : Boolean = false;
            attribute errorDetected : Boolean = false;
            attribute startCommandReceived : Boolean = false;
            attribute stopCommandReceived : Boolean = false;
            attribute resetCommandReceived : Boolean = false;
            
            state PowerUp {
                entry { /* initiate self-test */ }
            }
            state Initialization {
                entry { /* load calibration, setup components */ }
            }
            state Ready {
                entry { /* idle, waiting for commands */ }
            }
            state ActiveMeasuring {
                entry { /* continuous sampling and processing */ }
            }
            state Fault {
                entry { /* report error, halt operations */ }
            }
            
            transition powerUp_to_init from PowerUp to Initialization when selfTestPassed == true;
            transition init_to_ready from Initialization to Ready when initComplete == true;
            transition ready_to_active from Ready to ActiveMeasuring when startCommandReceived == true;
            transition active_to_ready from ActiveMeasuring to Ready when stopCommandReceived == true;
            transition any_to_fault from * to Fault when errorDetected == true;
            transition fault_to_ready from Fault to Ready when resetCommandReceived == true;
        }
    }

    // Requirements
    req def HighPrecisionMeasurement {
        doc /* The sensor shall accurately measure pressure with an error less than 0.1%. */
        attribute maxError : Real = 0.001;
    }
    
    req def WideTemperatureRange {
        doc /* The sensor shall operate across a wide range of temperatures. */
        attribute minTemp : TemperatureValue = 233.15; // -40 C
        attribute maxTemp : TemperatureValue = 398.15; // +125 C
    }
    
    req def FastResponseTime {
        doc /* The sensor shall provide fast and accurate pressure readings. */
        attribute maxLatency : Real = 0.002; // seconds
    }
    
    req def SelfContainedComponent {
        doc /* The sensor shall be a compact, self-contained, hermetically sealed electronic component. */
        attribute sealed : Boolean = true;
    }
    
    requirement sensorRequirements {
        requirement req1 : HighPrecisionMeasurement;
        requirement req2 : WideTemperatureRange;
        requirement req3 : FastResponseTime;
        requirement req4 : SelfContainedComponent;
        
        satisfy req1 by IntegratedPiezoelectricSensor;
        satisfy req2 by IntegratedPiezoelectricSensor;
        satisfy req3 by IntegratedPiezoelectricSensor;
        satisfy req4 by IntegratedPiezoelectricSensor;
    }
}

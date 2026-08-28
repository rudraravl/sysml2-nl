package 'Digital pH Measurement System' {
    private import ScalarValues::*;
    private import ScalarFunctions::*;

    package Definitions {

        value def Voltage :> Real;
        value def Temperature :> Real;
        value def pHValue :> Real;
        value def DigitalValue :> Real;
        value def ResistanceValue :> Real;

        item def TestSample;
        item def BufferSolution {
            attribute pH : pHValue;
        }
        item def StorageSolution;

        attribute def StartPreparationSignal;
        attribute def CompletePreparationSignal;
        attribute def SelectCalibrationSignal;
        attribute def CalibrationDoneSignal;
        attribute def StartMeasurementSignal;
        attribute def MeasurementDoneSignal;
        attribute def MaintenanceRequiredSignal;
        attribute def MaintenanceDoneSignal;
        attribute def FaultDetectedSignal;
        attribute def FaultResolvedSignal;

        port def VoltageOutPort {
            out attribute voltage : Voltage;
        }
        port def VoltageInPort {
            in attribute voltage : Voltage;
        }
        port def TemperatureOutPort {
            out attribute temp : Temperature;
        }
        port def TemperatureInPort {
            in attribute temp : Temperature;
        }
        port def DigitalOutPort {
            out attribute digitalValue : DigitalValue;
        }
        port def DigitalInPort {
            in attribute digitalValue : DigitalValue;
        }
        port def pHOutPort {
            out attribute pH : pHValue;
        }

        part def GlassMembrane {
            attribute hydrogenIonResponse : Real;
            port voltageOutPort : VoltageOutPort;
            exhibit state 'membrane states' {
                entry; then hydrated;
                state hydrated;
                state dry;
            }
        }

        part def InternalReferenceElement {
            attribute bufferpH : pHValue = 7.0;
            item buffer : BufferSolution;
            port voltageOutPort : VoltageOutPort;
        }

        part def ExternalReferenceElectrode {
            attribute baselinePotential : Voltage;
            port voltageOutPort : VoltageOutPort;
        }

        part def GlassElectrode {
            port voltageOutPort : VoltageOutPort;
            part glassMembrane : GlassMembrane;
            part internalRef : InternalReferenceElement;
            action def SumVoltages {
                in v1 : Voltage;
                in v2 : Voltage;
                out result : Voltage;
            }
            perform action sumVoltages : SumVoltages {
                in v1 = glassMembrane.voltageOutPort.voltage;
                in v2 = internalRef.voltageOutPort.voltage;
                out result = voltageOutPort.voltage;
            }
        }

        part def CombinationProbe {
            port rawVoltageOutPort : VoltageOutPort;
            part glassElectrode : GlassElectrode;
            part refElectrode : ExternalReferenceElectrode;
            action def ComputeDifference {
                in vGlass : Voltage;
                in vRef : Voltage;
                out result : Voltage;
            }
            perform action computeDifference : ComputeDifference {
                in vGlass = glassElectrode.voltageOutPort.voltage;
                in vRef = refElectrode.voltageOutPort.voltage;
                out result = rawVoltageOutPort.voltage;
            }
        }

        part def HighImpedanceAmplifier {
            attribute gain : Real = 1.0;
            attribute inputImpedance : ResistanceValue;
            port voltageInPort : VoltageInPort;
            port voltageOutPort : VoltageOutPort;
            action def Amplify {
                in inV : Voltage;
                out outV : Voltage;
            }
            perform action amplify : Amplify {
                in inV = voltageInPort.voltage;
                out outV = voltageOutPort.voltage;
            }
        }

        part def TemperatureSensor {
            port tempOutPort : TemperatureOutPort;
            action def SenseTemperature {
                out temp : Temperature;
            }
            perform action senseTemperature : SenseTemperature {
                out temp = tempOutPort.temp;
            }
        }

        part def TemperatureCompensator {
            attribute referenceTemp : Temperature = 298.15;
            port voltageInPort : VoltageInPort;
            port tempInPort : TemperatureInPort;
            port voltageOutPort : VoltageOutPort;
            part tempSensor : TemperatureSensor;
            action def Compensate {
                in inV : Voltage;
                in inT : Temperature;
                out outV : Voltage;
            }
            perform action compensate : Compensate {
                in inV = voltageInPort.voltage;
                in inT = tempInPort.temp;
                out outV = voltageOutPort.voltage;
            }
        }

        part def ADC {
            attribute resolution : Real = 0.001;
            port voltageInPort : VoltageInPort;
            port digitalOutPort : DigitalOutPort;
            action def Convert {
                in inV : Voltage;
                out outD : DigitalValue;
            }
            perform action convert : Convert {
                in inV = voltageInPort.voltage;
                out outD = digitalOutPort.digitalValue;
            }
        }

        part def SignalProcessor {
            attribute slope : Real = 1.0;
            attribute intercept : Real = 0.0;
            port digitalInPort : DigitalInPort;
            port pHOutPort : pHOutPort;
            action def ComputePH {
                in inD : DigitalValue;
                out pHResult : pHValue;
            }
            perform action computePH : ComputePH {
                in inD = digitalInPort.digitalValue;
                out pHResult = pHOutPort.pH;
            }
        }

        action def RinseProbe;
        action def Calibrate {
            in buffer1pH : pHValue;
            in buffer2pH : pHValue;
        }
        action def TakeMeasurement;
        action def PerformMaintenance;

        part def DigitalPHMeasurementSystem {
            port pHOutputPort : pHOutPort;
            part probe : CombinationProbe;
            part amplifier : HighImpedanceAmplifier;
            part compensator : TemperatureCompensator;
            part adc : ADC;
            part processor : SignalProcessor;

            flow of voltage : Voltage
                from probe.rawVoltageOutPort.voltage to amplifier.voltageInPort.voltage;
            flow of voltage : Voltage
                from amplifier.voltageOutPort.voltage to compensator.voltageInPort.voltage;
            flow of temperature : Temperature
                from compensator.tempSensor.tempOutPort.temp to compensator.tempInPort.temp;
            flow of voltage : Voltage
                from compensator.voltageOutPort.voltage to adc.voltageInPort.voltage;
            flow of digitalValue : DigitalValue
                from adc.digitalOutPort.digitalValue to processor.digitalInPort.digitalValue;
            flow of pHResult : pHValue
                from processor.pHOutPort.pH to pHOutputPort.pH;

            exhibit state 'pH lifecycle' : pHMeasurementStates;
        }

        state def pHMeasurementStates {
            entry; then storage;
            state storage;
            accept StartPreparationSignal
                then preparation;
            state preparation {
                do action rinseProbe : RinseProbe;
            }
            accept CompletePreparationSignal
                then ready;
            state ready;
            accept SelectCalibrationSignal
                then calibration;
            state calibration {
                do action calibrate : Calibrate {
                    in buffer1pH = 4.01;
                    in buffer2pH = 7.00;
                }
            }
            accept CalibrationDoneSignal
                then ready;
            accept StartMeasurementSignal
                then measurement;
            state measurement {
                do action takeMeasurement : TakeMeasurement;
            }
            accept MeasurementDoneSignal
                then ready;
            accept MaintenanceRequiredSignal
                then maintenance;
            state maintenance {
                do action performMaintenance : PerformMaintenance;
            }
            accept MaintenanceDoneSignal
                then ready;
            accept FaultDetectedSignal
                then fault;
            state fault;
            accept FaultResolvedSignal
                then ready;
        }

        requirement def AccuracyRequirement {
            subject phSystem : DigitalPHMeasurementSystem;
            doc /* The pH measurement shall be accurate within +/- 0.01 pH units under standard conditions. */
        }

        requirement def CalibrationRequirement {
            subject phSystem : DigitalPHMeasurementSystem;
            doc /* The system shall be calibrated using at least two standard buffer solutions (e.g., pH 4.01 and pH 7.00). */
        }

        requirement def TemperatureCompensationRequirement {
            subject compensator : TemperatureCompensator;
            doc /* The system shall compensate for temperature variations from 0 to 50 degrees Celsius to maintain accuracy. */
        }

        requirement def HighImpedanceInputRequirement {
            subject amplifier : HighImpedanceAmplifier;
            doc /* The amplifier shall have an input impedance of at least 10^12 ohms to avoid loading the electrode. */
        }
    }

    package Usages {
        private import Definitions::*;

        part phSystem : DigitalPHMeasurementSystem;

        part testContext {
            part system : DigitalPHMeasurementSystem;
            item sample : TestSample;
        }

        requirement accurateMeasurement : AccuracyRequirement {
            subject phSystem = phSystem;
        }

        requirement properCalibration : CalibrationRequirement {
            subject phSystem = phSystem;
        }

        requirement tempCompensation : TemperatureCompensationRequirement {
            subject compensator = phSystem.compensator;
        }

        requirement highImpedance : HighImpedanceInputRequirement {
            subject amplifier = phSystem.amplifier;
        }
    }
}

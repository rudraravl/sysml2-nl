package ElectrochemicalGasSensingUnit {
    public import ScalarValues::*;

    package Units {
        value type Ppm;
        value type Celsius;
        value type Volt;
        value type Ampere;
        value type MicroAmpere;
        value type MilliVolt;
        value type Seconds;
        value type Pascals;
        value type Dimensionless;
    }

    package ValueTypes {
        import Units::*;

        value type Concentration :> Real {
            unit : Ppm;
        }
        value type Temperature :> Real {
            unit : Celsius;
        }
        value type ElectricCurrent :> Real {
            unit : Ampere;
        }
        value type SensorCurrent :> Real {
            unit : MicroAmpere;
        }
        value type ElectricPotential :> Real {
            unit : Volt;
        }
        value type SensorVoltage :> Real {
            unit : MilliVolt;
        }
        value type Duration :> Real {
            unit : Seconds;
        }
        value type BiasVoltage :> Real {
            unit : MilliVolt;
        }
        value type Pressure :> Real {
            unit : Pascals;
        }
        value type DigitalValue :> Integer;
        value type RawDigitalValue :> DigitalValue;
        value type CompensatedValue :> DigitalValue;

        enum def GasKind {
            CO;
            Ozone;
            Oxygen;
            SulfurDioxide;
        }

        enum def SensorState {
            Off;
            WarmingUp;
            Ready;
            Calibrating;
            Fault;
        }

        item def CalibrationCoefficients {
            attribute slope : Real;
            attribute offset : Real;
            attribute tempCoefficient : Real;
            attribute referenceConcentration : Concentration;
            attribute validAtTemperature : Temperature;
        }

        item def MeasurementResult {
            attribute gasType : GasKind;
            attribute concentration : Concentration;
            attribute temperature : Temperature;
            attribute timestamp : Duration;
            attribute isValid : Boolean;
        }

        item def StatusMessage {
            attribute state : String;
            attribute errorCode : Integer;
            attribute message : String;
        }
    }

    package Items {
        import ValueTypes::*;

        item def GasSample {
            attribute gasType : GasKind;
            attribute concentration : Concentration;
            attribute temperature : Temperature;
            attribute humidity : Real;
        }

        item def AirMixture {
            attribute ambientTemperature : Temperature;
            attribute ambientPressure : Pressure;
            attribute humidity : Real;
            attribute gasContent : GasSample;
        }

        item def ElectricSignal {
            attribute current : SensorCurrent;
            attribute biasVoltage : SensorVoltage;
            attribute referenceVoltage : SensorVoltage;
        }

        item def AmplifiedSignal {
            attribute voltage : SensorVoltage;
            attribute current : ElectricCurrent;
        }

        item def DigitalSample {
            attribute rawValue : RawDigitalValue;
            attribute gain : Real;
            attribute biasSetting : BiasVoltage;
        }

        item def TemperatureReading {
            attribute value : Temperature;
        }

        item def PowerInput {
            attribute voltage : ElectricPotential;
            attribute current : ElectricCurrent;
        }

        item def DataOutput {
            attribute result : MeasurementResult;
            attribute status : StatusMessage;
        }

        item def CalibrationReference {
            attribute referenceGas : GasKind;
            attribute referenceConcentration : Concentration;
            attribute referenceTemperature : Temperature;
        }

        item def PowerOn;
        item def StabilizationComplete;
        item def CalibrateCommand;
        item def CalibrationComplete;
        item def InternalError;
        item def ResetCommand;
        item def MeasureCommand;
    }

    package Ports {
        import Items::*;

        port def GasInPort {
            in item air : AirMixture;
        }

        port def GasOutPort {
            out item gas : GasSample;
        }

        port def GasSampleInPort {
            in item gas : GasSample;
        }

        port def RawSignalOutPort {
            out item signal : ElectricSignal;
        }

        port def RawSignalInPort {
            in item signal : ElectricSignal;
        }

        port def AmplifiedSignalOutPort {
            out item amplified : AmplifiedSignal;
        }

        port def AmplifiedSignalInPort {
            in item amplified : AmplifiedSignal;
        }

        port def DigitalSampleOutPort {
            out item sample : DigitalSample;
        }

        port def DigitalSampleInPort {
            in item sample : DigitalSample;
        }

        port def TemperatureOutPort {
            out item reading : TemperatureReading;
        }

        port def TemperatureInPort {
            in item reading : TemperatureReading;
        }

        port def DataOutPort {
            out item data : DataOutput;
        }

        port def PowerInPort {
            in item power : PowerInput;
        }

        port def CalibrationInPort {
            in item reference : CalibrationReference;
        }

        port def BiasControlOutPort {
            out item bias : BiasVoltage;
        }

        port def BiasControlInPort {
            in item bias : BiasVoltage;
        }
    }

    package ChemicalCell {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;

        part def GasPermeableMembrane {
            attribute permeability : Real;
            attribute poreSize : Real;
            attribute material : String;

            port gasIn : GasInPort;
            port gasOut : GasOutPort;

            action def FilterGas {
                in air : AirMixture;
                out gas : GasSample;
            }
        }

        part def WorkingElectrode {
            attribute surfaceArea : Real;
            attribute catalystMaterial : String;
            attribute activeArea : Real;

            port gasIn : GasSampleInPort;
            port signalOut : RawSignalOutPort;

            action def ElectrochemicalReaction {
                in gas : GasSample;
                in electrolyte : Real;
                out current : SensorCurrent;
            }
        }

        part def CounterElectrode {
            attribute material : String;
            attribute surfaceArea : Real;

            action def CounterReaction {
                in gas : GasSample;
                out current : SensorCurrent;
            }
        }

        part def ReferenceElectrode {
            attribute material : String;
            attribute baselineVoltage : SensorVoltage;
            attribute stability : Real;

            action def ProvideBaseline {
                out reference : SensorVoltage;
            }
        }

        part def Electrolyte {
            attribute composition : String;
            attribute pH : Real;
            attribute volume : Real;
        }

        part def SensingCell {
            attribute targetGas : GasKind;
            attribute biasVoltage : BiasVoltage;
            attribute cellType : String;

            part membrane : GasPermeableMembrane;
            part workingElectrode : WorkingElectrode;
            part counterElectrode : CounterElectrode;
            part referenceElectrode : ReferenceElectrode;
            part electrolyte : Electrolyte;

            port gasIn : GasInPort;
            port rawSignalOut : RawSignalOutPort;
            port biasControlIn : BiasControlInPort;

            connect gasIn to membrane.gasIn;
            connect membrane.gasOut to workingElectrode.gasIn;

            action def PerformSensing {
                in air : AirMixture;
                out signal : ElectricSignal;
            }

            action def StabilizeElectrolyte {
                out ready : Boolean;
            }
        }
    }

    package Electronics {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;

        part def Potentiostat {
            attribute gain : Real;
            attribute referenceBias : BiasVoltage;
            attribute stabilityFactor : Real;
            attribute bandwidth : Real;

            port powerIn : PowerInPort;
            port signalIn : RawSignalInPort;
            port amplifiedSignalOut : AmplifiedSignalOutPort;
            port biasControlOut : BiasControlOutPort;

            action def AmplifySignal {
                in raw : ElectricSignal;
                out amplified : AmplifiedSignal;
            }

            action def MaintainBias {
                in reference : SensorVoltage;
                out bias : BiasVoltage;
            }
        }

        part def AnalogToDigitalConverter {
            attribute resolutionBits : Integer;
            attribute sampleRate : Real;
            attribute referenceVoltage : ElectricPotential;

            port powerIn : PowerInPort;
            port analogIn : AmplifiedSignalInPort;
            port digitalOut : DigitalSampleOutPort;

            action def Convert {
                in analog : AmplifiedSignal;
                out digital : DigitalSample;
            }
        }

        part def TemperatureSensor {
            attribute accuracy : Real;
            attribute rangeMin : Temperature;
            attribute rangeMax : Temperature;
            attribute responseTime : Duration;

            port powerIn : PowerInPort;
            port tempOut : TemperatureOutPort;

            action def MeasureTemperature {
                out reading : TemperatureReading;
            }
        }
    }

    package SignalProcessing {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;

        part def SignalProcessor {
            attribute processingRate : Real;
            attribute storedCoefficients : CalibrationCoefficients;
            attribute activeGasType : GasKind;
            attribute firmwareVersion : String;

            port powerIn : PowerInPort;
            port digitalIn : DigitalSampleInPort;
            port tempIn : TemperatureInPort;
            port dataOut : DataOutPort;
            port calibrationIn : CalibrationInPort;

            action def ProcessSignal {
                in raw : DigitalSample;
                in temp : TemperatureReading;
                out result : MeasurementResult;
            }

            action def Calibrate {
                in reference : CalibrationReference;
                in raw : DigitalSample;
                in temp : TemperatureReading;
            }

            action def CompensateTemperature {
                in raw : RawDigitalValue;
                in temp : Temperature;
                in coeff : CalibrationCoefficients;
                out compensated : CompensatedValue;
            }

            action def ComputeConcentration {
                in compensated : CompensatedValue;
                in coeff : CalibrationCoefficients;
                out concentration : Concentration;
            }
        }
    }

    package States {
        import Items::*;
        import ValueTypes::*;

        state machine def SensorStateMachine {
            state Off {
                accept PowerOn then WarmingUp;
            }
            state WarmingUp {
                accept StabilizationComplete then Ready;
                accept InternalError then Fault;
            }
            state Ready {
                accept CalibrateCommand then Calibrating;
                accept InternalError then Fault;
            }
            state Calibrating {
                accept CalibrationComplete then Ready;
                accept InternalError then Fault;
            }
            state Fault {
                accept ResetCommand then Off;
            }
        }
    }

    package System {
        import ChemicalCell::*;
        import Electronics::*;
        import SignalProcessing::*;
        import States::*;
        import Items::*;
        import Ports::*;
        import ValueTypes::*;

        part def ElectrochemicalGasSensor {
            attribute sensorId : String;
            attribute manufacturer : String;
            attribute targetGas : GasKind;
            attribute firmwareVersion : String;
            attribute warmupDuration : Duration;
            attribute maxRange : Concentration;
            attribute accuracy : Real;

            part sensingCell : SensingCell;
            part potentiostat : Potentiostat;
            part adc : AnalogToDigitalConverter;
            part temperatureSensor : TemperatureSensor;
            part signalProcessor : SignalProcessor;

            attribute currentState : SensorState;
            attribute stabilizationTimer : Duration;

            port gasInput : GasInPort;
            port powerInput : PowerInPort;
            port dataOutput : DataOutPort;
            port calibrationInput : CalibrationInPort;

            state machine operationStates :> SensorStateMachine;

            connect gasInput to sensingCell.gasIn;
            connect sensingCell.rawSignalOut to potentiostat.signalIn;
            connect potentiostat.amplifiedSignalOut to adc.analogIn;
            connect adc.digitalOut to signalProcessor.digitalIn;
            connect temperatureSensor.tempOut to signalProcessor.tempIn;
            connect potentiostat.biasControlOut to sensingCell.biasControlIn;
            connect signalProcessor.dataOut to dataOutput;
            connect calibrationInput to signalProcessor.calibrationIn;
            connect powerInput to potentiostat.powerIn;
            connect powerInput to adc.powerIn;
            connect powerInput to temperatureSensor.powerIn;
            connect powerInput to signalProcessor.powerIn;

            action def Initialize {
                out state : SensorState;
            }

            action def PerformMeasurement {
                in air : AirMixture;
                in power : PowerInput;
                out data : DataOutput;
            }

            action def PerformCalibration {
                in reference : CalibrationReference;
                out data : DataOutput;
            }

            action def HandleFault {
                in errorCode : Integer;
                out status : StatusMessage;
            }

            action def WarmUp {
                out stabilized : Boolean;
            }
        }

        part coSensor : ElectrochemicalGasSensor {
            attribute sensorId = "CO-SENSOR-001";
            attribute targetGas = GasKind::CO;
            attribute warmupDuration = 60;
            attribute maxRange = 2000;
            attribute accuracy = 2.0;
        }
    }

    package Requirements {
        import System::*;
        import ValueTypes::*;
        import States::*;
        import Items::*;

        requirement def GasDetectionRequirement {
            doc /* The sensor shall detect and measure the concentration of a target gas in ambient air and output the result as a digital data stream. */;
            subject sensor : ElectrochemicalGasSensor;
        }

        requirement r1 :> GasDetectionRequirement {
            doc /* The sensor shall detect Carbon Monoxide (CO) in the range of 0 to 2000 ppm with an accuracy of plus or minus 2 ppm. */;
            attribute targetGas : GasKind = GasKind::CO;
            attribute measurementRange : Concentration = 2000;
            attribute accuracy : Real = 2.0;
        }

        requirement r2 :> GasDetectionRequirement {
            doc /* The overall design shall be applicable to other gases including ozone, oxygen, and sulfur dioxide without hardware modification beyond the sensing cell chemistry. */;
            attribute supportedGases : GasKind = GasKind::Ozone;
        }

        requirement def ElectrochemicalReactionRequirement {
            doc /* The sensing cell shall use an electrochemical reaction at a working electrode to generate an electrical current proportional to the target gas concentration. */;
            subject sensor : ElectrochemicalGasSensor;
        }

        requirement r3 :> ElectrochemicalReactionRequirement {
            doc /* The working electrode shall react with the target gas facilitated by an electrolyte solution. The counter electrode shall balance the reaction. The generated current shall be directly proportional to the gas concentration. */;
        }

        requirement def ReferenceElectrodeRequirement {
            doc /* A reference electrode shall provide a stable voltage baseline to ensure the measurement is accurate. */;
            subject sensor : ElectrochemicalGasSensor;
        }

        requirement r4 :> ReferenceElectrodeRequirement {
            doc /* The reference electrode shall maintain a stable voltage baseline throughout the operational temperature range for accurate measurement comparison against the working electrode signal. */;
        }

        requirement def GasPermeableMembraneRequirement {
            doc /* A gas-permeable membrane shall allow ambient air containing the target gas to pass through into the sensing cell. */;
            subject sensor : ElectrochemicalGasSensor;
        }

        requirement r5 :> GasPermeableMembraneRequirement {
            doc /* The gas-permeable membrane shall permit the target gas to diffuse into the sensing cell while preventing contamination of the internal electrolyte. */;
        }

        requirement def SignalProcessingChainRequirement {
            doc /* The raw electrical signal from the sensing cell shall be processed through a potentiostat, ADC, and signal processor to produce an accurate digital concentration measurement. */;
            subject sensor : ElectrochemicalGasSensor;
        }

        requirement r6 :> SignalProcessingChainRequirement {
            doc /* The potentiostat shall amplify the raw signal from the sensing cell and maintain a stable bias voltage across the working and reference electrodes. */;
        }

        requirement r7 :> SignalProcessingChainRequirement {
            doc /* The analog-to-digital converter shall sample the amplified signal and convert it into a digital value with a minimum resolution of 16 bits. */;
            attribute minResolutionBits : Integer = 16;
        }

        requirement r8 :> SignalProcessingChainRequirement {
            doc /* The signal processor shall use stored calibration coefficients to correct the digital reading, compensating for temperature fluctuations to produce a final accurate measurement in parts-per-million. */;
        }

        requirement def TemperatureCompensationRequirement {
            doc /* The signal processor shall compensate for temperature fluctuations using readings from an integrated temperature sensor and stored calibration coefficients. */;
            subject sensor : ElectrochemicalGasSensor;
        }

        requirement r9 :> TemperatureCompensationRequirement {
            doc /* The integrated temperature sensor shall provide temperature readings to the signal processor over the operating range of negative 20 degrees Celsius to positive 50 degrees Celsius. */;
            attribute operatingRangeMin : Temperature = -20;
            attribute operatingRangeMax : Temperature = 50;
        }

        requirement def StateMachineRequirement {
            doc /* The sensor shall operate through the following states: Off, WarmingUp, Ready, Calibrating, and Fault. */;
            subject sensor : ElectrochemicalGasSensor;
        }

        requirement r10 :> StateMachineRequirement {
            doc /* Upon power on, the sensor shall enter a WarmingUp state for a minimum duration to allow the chemical components to stabilize before transitioning to the Ready state. */;
            attribute minimumWarmUpTime : Duration = 60;
        }

        requirement r11 :> StateMachineRequirement {
            doc /* If an internal error is detected in any state other than Fault, the sensor shall enter a Fault state and cease normal operation until a reset command is received. */;
        }

        requirement r12 :> StateMachineRequirement {
            doc /* The sensor shall support a Calibrating state for periodic adjustment using a known reference gas. Upon completion of calibration, the sensor shall return to the Ready state. */;
        }

        requirement def DigitalOutputRequirement {
            doc /* The sensor shall output a clean, self-contained digital data stream indicating the precise concentration of the target gas in parts-per-million. */;
            subject sensor : ElectrochemicalGasSensor;
        }

        requirement r13 :> DigitalOutputRequirement {
            doc /* The output data stream shall include the gas type, concentration in ppm, temperature at the time of measurement, a timestamp, and a validity flag. */;
        }

        requirement def PowerInputRequirement {
            doc /* The sensor shall accept electrical power input and distribute it to all internal electronic components. */;
            subject sensor : ElectrochemicalGasSensor;
        }

        requirement r14 :> PowerInputRequirement {
            doc /* The sensor shall operate from a standard power input and distribute power to the potentiostat, ADC, temperature sensor, and signal processor. */;
        }

        requirement def SelfContainedRequirement {
            doc /* The sensor shall be a complete, self-contained system that takes in ambient gas and electrical power and outputs a digital data stream indicating gas concentration. */;
            subject sensor : ElectrochemicalGasSensor;
        }

        requirement r15 :> SelfContainedRequirement {
            doc /* All sensing, signal conditioning, digitization, temperature compensation, and output formatting shall be performed within the single sensor unit without external processing equipment. */;
        }
    }
}

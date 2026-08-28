package MEMSAccelerometerModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Time::*;
    
    package ValueTypes {
        unit def g :> ISQ::acceleration;
        unit def Hz :> ISQ::frequency;
        unit def V :> ISQ::electricPotentialDifference;
        
        value def AccelerationValue :> ISQ::acceleration;
        value def CapacitanceValue :> ISQ::capacitance;
        value def VoltageValue :> ISQ::electricPotentialDifference;
        value def DisplacementValue :> ISQ::length;
        value def AreaValue :> ISQ::area;
        value def FrequencyValue :> ISQ::frequency;
        value def PowerValue :> ISQ::power;
        value def TemperatureValue :> ISQ::temperature;
        value def MassValue :> ISQ::mass;
        value def CurrentValue :> ISQ::electricCurrent;
        value def DigitalValue :> ScalarValues::Integer;
    }
    
    package Definitions {
        private import ValueTypes::*;
        
        attribute def PowerOnSignal;
        attribute def StartMeasurementSignal;
        attribute def StopMeasurementSignal;
        attribute def EnterLowPowerSignal;
        attribute def ResetSignal;
        attribute def FaultSignal;
        attribute def SelfTestCompleteSignal;
        attribute def SelfTestFailSignal;
        
        item def CapacitanceChange {
            attribute deltaC : CapacitanceValue;
            attribute axisId : String;
        }
        item def AnalogVoltageSignal {
            attribute voltage : VoltageValue;
            attribute axisId : String;
        }
        item def FilteredAnalogSignal {
            attribute voltage : VoltageValue;
            attribute axisId : String;
        }
        item def RawDigitalSample {
            attribute rawValue : DigitalValue;
            attribute axisId : String;
        }
        item def CalibratedAccelerationData {
            attribute x : AccelerationValue;
            attribute y : AccelerationValue;
            attribute z : AccelerationValue;
            attribute timestamp : Integer;
        }
        item def CalibrationParameters {
            attribute offset : Real;
            attribute scaleFactor : Real;
        }
        
        port def MechanicalInputPort {
            in appliedAcceleration : AccelerationValue;
        }
        port def CapChangeOutPort {
            out capChange : CapacitanceChange;
        }
        port def CapChangeInPort {
            in capChange : CapacitanceChange;
        }
        port def AnalogSignalOutPort {
            out analogSignal : AnalogVoltageSignal;
        }
        port def AnalogSignalInPort {
            in analogSignal : AnalogVoltageSignal;
        }
        port def FilteredSignalOutPort {
            out filteredSignal : FilteredAnalogSignal;
        }
        port def FilteredSignalInPort {
            in filteredSignal : FilteredAnalogSignal;
        }
        port def DigitalSampleOutPort {
            out rawSample : RawDigitalSample;
        }
        port def DigitalSampleInPort {
            in rawSample : RawDigitalSample;
        }
        port def DigitalDataOutputPort {
            out calibratedData : CalibratedAccelerationData;
        }
        port def PowerInputPort {
            in supplyVoltage : VoltageValue;
        }
        port def PowerOutputPort {
            out regulatedVoltage : VoltageValue;
        }
        port def ControlPort {
            in command : String;
        }
        
        action def Initialize;
        action def PerformSelfTest;
        action def SenseCapacitance;
        action def AmplifyCharge;
        action def FilterSignal;
        action def ConvertAnalogToDigital;
        action def CalibrateData;
        action def PackageData;
        action def TransmitData;
        action def RegulatePower;
        action def EnterLowPowerMode;
        action def HandleFault;
        action def PerformReset;
        action def MeasureAllAxes;
        action def ProcessAllAxes;
        
        state def AccelerometerStates;
        
        part def ProofMass {
            attribute massValue : MassValue;
            attribute restPosition : DisplacementValue;
            attribute currentDisplacement : DisplacementValue;
            attribute springConstant : Real;
            attribute dampingCoefficient : Real;
        }
        
        part def CapacitiveSensingElement {
            attribute nominalGap : DisplacementValue;
            attribute nominalCapacitance : CapacitanceValue;
            attribute plateArea : AreaValue;
            attribute permittivity : Real;
            attribute axisId : String;
            attribute maxRange : AccelerationValue;
            
            part proofMass : ProofMass;
            
            port mechanicalIn : MechanicalInputPort;
            port capOut : CapChangeOutPort;
            port powerIn : PowerInputPort;
            
            perform action senseCapacitance : SenseCapacitance;
        }
        
        part def ChargeAmplifier {
            attribute gain : Real;
            attribute bandwidth : FrequencyValue;
            attribute noiseFloor : VoltageValue;
            
            port capIn : CapChangeInPort;
            port analogOut : AnalogSignalOutPort;
            port powerIn : PowerInputPort;
            
            perform action amplifyCharge : AmplifyCharge;
        }
        
        part def LowPassFilter {
            attribute cutoffFrequency : FrequencyValue;
            attribute filterOrder : Integer;
            
            port analogIn : AnalogSignalInPort;
            port filteredOut : FilteredSignalOutPort;
            port powerIn : PowerInputPort;
            
            perform action filterSignal : FilterSignal;
        }
        
        part def AnalogDigitalConverter {
            attribute sampleRate : FrequencyValue;
            attribute resolutionBits : Integer;
            attribute referenceVoltage : VoltageValue;
            
            port analogIn : FilteredSignalInPort;
            port digitalOut : DigitalSampleOutPort;
            port powerIn : PowerInputPort;
            
            perform action convertAnalogToDigital : ConvertAnalogToDigital;
        }
        
        part def DigitalSignalProcessor {
            attribute xCalibration : CalibrationParameters;
            attribute yCalibration : CalibrationParameters;
            attribute zCalibration : CalibrationParameters;
            attribute clockFrequency : FrequencyValue;
            
            port digitalIn : DigitalSampleInPort;
            port dataOut : DigitalDataOutputPort;
            port powerIn : PowerInputPort;
            
            perform action calibrateData : CalibrateData;
            perform action packageData : PackageData;
        }
        
        part def VoltageRegulator {
            attribute inputVoltageMin : VoltageValue;
            attribute inputVoltageMax : VoltageValue;
            attribute outputVoltage : VoltageValue;
            attribute lineRegulation : Real;
            attribute loadRegulation : Real;
            attribute maxOutputCurrent : CurrentValue;
            
            port powerIn : PowerInputPort;
            port regulatedOut : PowerOutputPort;
            
            perform action regulatePower : RegulatePower;
        }
        
        part def PowerSystem {
            part voltageRegulator : VoltageRegulator;
            port powerInput : PowerInputPort;
            port regulatedOut : PowerOutputPort;
            
            connection powerToRegulator connect powerInput to voltageRegulator.powerIn;
            connection regulatorToOutput connect voltageRegulator.regulatedOut to regulatedOut;
        }
        
        part def SensingChannel {
            attribute axisId : String;
            attribute maxRange : AccelerationValue;
            attribute sensitivity : Real;
            
            part sensingElement : CapacitiveSensingElement;
            part chargeAmplifier : ChargeAmplifier;
            part lowPassFilter : LowPassFilter;
            part adc : AnalogDigitalConverter;
            
            port mechanicalIn : MechanicalInputPort;
            port digitalOut : DigitalSampleOutPort;
            port powerIn : PowerInputPort;
            
            connection mechToSensing connect mechanicalIn to sensingElement.mechanicalIn;
            connection sensingToAmp connect sensingElement.capOut to chargeAmplifier.capIn;
            connection ampToFilter connect chargeAmplifier.analogOut to lowPassFilter.analogIn;
            connection filterToADC connect lowPassFilter.filteredOut to adc.analogIn;
            connection adcToDigitalOut connect adc.digitalOut to digitalOut;
            connection powerToSensing connect powerIn to sensingElement.powerIn;
            connection powerToAmp connect powerIn to chargeAmplifier.powerIn;
            connection powerToFilter connect powerIn to lowPassFilter.powerIn;
            connection powerToADC connect powerIn to adc.powerIn;
        }
        
        part def MEMSAccelerometer {
            attribute maxRange : AccelerationValue;
            attribute operatingBandwidth : FrequencyValue;
            attribute operatingTempMin : TemperatureValue;
            attribute operatingTempMax : TemperatureValue;
            attribute supplyVoltageMin : VoltageValue;
            attribute supplyVoltageMax : VoltageValue;
            attribute powerConsumption : PowerValue;
            
            part xChannel : SensingChannel {
                attribute axisId = "X";
            }
            part yChannel : SensingChannel {
                attribute axisId = "Y";
            }
            part zChannel : SensingChannel {
                attribute axisId = "Z";
            }
            part dsp : DigitalSignalProcessor;
            part powerSystem : PowerSystem;
            
            port dataOutput : DigitalDataOutputPort;
            port powerInput : PowerInputPort;
            port control : ControlPort;
            
            connection xDigitalToDSP connect xChannel.digitalOut to dsp.digitalIn;
            connection yDigitalToDSP connect yChannel.digitalOut to dsp.digitalIn;
            connection zDigitalToDSP connect zChannel.digitalOut to dsp.digitalIn;
            connection powerToSystem connect powerInput to powerSystem.powerInput;
            connection powerToXChannel connect powerSystem.regulatedOut to xChannel.powerIn;
            connection powerToYChannel connect powerSystem.regulatedOut to yChannel.powerIn;
            connection powerToZChannel connect powerSystem.regulatedOut to zChannel.powerIn;
            connection powerToDSP connect powerSystem.regulatedOut to dsp.powerIn;
            connection dspToOutput connect dsp.dataOut to dataOutput;
            
            perform action initialize : Initialize;
            perform action performSelfTest : PerformSelfTest;
            perform action measureAllAxes : MeasureAllAxes;
            perform action processAllAxes : ProcessAllAxes;
            perform action transmitData : TransmitData;
            perform action enterLowPowerMode : EnterLowPowerMode;
            perform action handleFault : HandleFault;
            perform action performReset : PerformReset;
            
            exhibit state operationalState : AccelerometerStates;
        }
        
        requirement def ThreeAxisMeasurementRequirement {
            doc /* The accelerometer shall measure linear acceleration in three orthogonal axes (X, Y, Z). */
            attribute measurementRange : AccelerationValue;
            attribute measurementAccuracy : AccelerationValue;
            attribute bandwidth : FrequencyValue;
        }
        
        requirement def PowerStabilityRequirement {
            doc /* The voltage regulator shall maintain stable power to all internal components. */
            attribute regulatedVoltage : VoltageValue;
            attribute maxLineRegulation : Real;
            attribute maxLoadRegulation : Real;
        }
        
        requirement def DigitalOutputRequirement {
            doc /* The DSP shall output calibrated acceleration data for X, Y, Z with timestamp. */
            attribute outputDataRate : FrequencyValue;
            attribute calibrationError : AccelerationValue;
        }
        
        requirement def OperationalLifecycleRequirement {
            doc /* The accelerometer shall support power-on, self-test, idle, measuring, low-power, fault, and reset states. */
        }
        
        requirement def SignalProcessingChainRequirement {
            doc /* The signal processing chain shall convert capacitance changes to calibrated digital data. */
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        action initialize : Initialize;
        action performSelfTest : PerformSelfTest;
        action measureAllAxes : MeasureAllAxes;
        action processAllAxes : ProcessAllAxes;
        action transmitData : TransmitData;
        action enterLowPowerMode : EnterLowPowerMode;
        action handleFault : HandleFault;
        action performReset : PerformReset;
        
        state operationalState : AccelerometerStates {
            entry; then poweredOff;
            
            state poweredOff;
            accept PowerOnSignal
                do initialize
                then initializing;
            
            state initializing;
            accept SelfTestCompleteSignal
                then idle;
            accept SelfTestFailSignal
                then fault;
            accept FaultSignal
                then fault;
            
            state idle;
            accept StartMeasurementSignal
                then measuring;
            accept EnterLowPowerSignal
                then lowPower;
            accept FaultSignal
                then fault;
            
            state measuring {
                entry measureAllAxes;
                do processAllAxes;
                exit transmitData;
            }
            accept StopMeasurementSignal
                then idle;
            accept EnterLowPowerSignal
                do enterLowPowerMode
                then lowPower;
            accept FaultSignal
                then fault;
            
            state lowPower;
            accept StartMeasurementSignal
                then measuring;
            accept ResetSignal
                then idle;
            
            state fault;
            accept ResetSignal
                do performReset
                then idle;
        }
        
        part accelSensor : MEMSAccelerometer;
        
        requirement threeAxisReq : ThreeAxisMeasurementRequirement {
            attribute measurementRange = 16.0 [g];
            attribute measurementAccuracy = 0.002 [g];
            attribute bandwidth = 500.0 [Hz];
        }
        
        requirement powerStabilityReq : PowerStabilityRequirement {
            attribute regulatedVoltage = 3.3 [V];
            attribute maxLineRegulation = 0.01;
            attribute maxLoadRegulation = 0.02;
        }
        
        requirement digitalOutputReq : DigitalOutputRequirement {
            attribute outputDataRate = 1000.0 [Hz];
            attribute calibrationError = 0.001 [g];
        }
        
        requirement lifecycleReq : OperationalLifecycleRequirement;
        requirement signalChainReq : SignalProcessingChainRequirement;
        
        satisfy threeAxisReq by accelSensor;
        satisfy powerStabilityReq by accelSensor.powerSystem.voltageRegulator;
        satisfy digitalOutputReq by accelSensor.dsp;
        satisfy lifecycleReq by accelSensor;
        satisfy signalChainReq by accelSensor;
    }
}

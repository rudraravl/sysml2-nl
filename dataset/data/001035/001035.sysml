package 'EIS Sensing Unit Model' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Measurement::*;
    
    attribute def pHUnit :> SimpleUnit {
        attribute :>> unitPowerFactor[1] {
            attribute :>> unit = pHUnit::self;
            attribute :>> exponent = 1;
        }
    }
    
    attribute def pHValue :> ScalarQuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : pHUnit;
    }
    
    attribute pH : pHValue :> quantity;
    
    attribute def CapacitanceUnit :> DerivedUnit;
    
    attribute def CapacitanceValue :> ScalarQuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : CapacitanceUnit;
    }
    
    attribute def VoltageUnit :> SimpleUnit {
        attribute :>> unitPowerFactor[1] {
            attribute :>> unit = VoltageUnit::self;
            attribute :>> exponent = 1;
        }
    }
    
    attribute def VoltageValue :> ScalarQuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : VoltageUnit;
    }
    
    attribute def ConcentrationUnit :> DerivedUnit;
    
    attribute def ConcentrationValue :> ScalarQuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : ConcentrationUnit;
    }
    
    item def ElectrolyteSolution {
        attribute ionicStrength : ConcentrationValue;
        attribute pH : pHValue;
        attribute temperature : TemperatureValue;
    }
    
    item def ElectricalSignal {
        attribute voltage : VoltageValue;
        attribute capacitance : CapacitanceValue;
        attribute frequency : Real;
    }
    
    item def MeasurementResult {
        attribute measuredpH : pHValue;
        attribute rawCapacitance : CapacitanceValue;
        attribute timestamp : TimeValue;
        attribute temperature : TemperatureValue;
    }
    
    port def SolutionPort {
        in item solution : ElectrolyteSolution;
    }
    
    port def SignalPort {
        out item signal : ElectricalSignal;
    }
    
    port def DataPort {
        out item data : MeasurementResult;
    }
    
    port def PowerPort {
        in voltage : VoltageValue;
    }
    
    part def InsulatorLayer {
        attribute thickness : LengthValue;
        attribute dielectricConstant : Real;
        attribute material : String;
    }
    
    part def SemiconductorSubstrate {
        attribute dopingLevel : ConcentrationValue;
        attribute carrierMobility : Real;
        attribute substrateMaterial : String;
    }
    
    part def ReferenceElectrode {
        attribute electrodePotential : VoltageValue;
        attribute electrodeMaterial : String;
    }
    
    part def EISCapacitor {
        part insulator : InsulatorLayer[1];
        part semiconductor : SemiconductorSubstrate[1];
        part reference : ReferenceElectrode[1];
        
        attribute interfaceCapacitance : CapacitanceValue;
        attribute depletionWidth : LengthValue;
        attribute surfacePotential : VoltageValue;
    }
    
    part def SignalConditioner {
        attribute amplifierGain : Real;
        attribute filterCutoff : Real;
        attribute adcResolution : Real;
        
        port signalIn : SignalPort;
        port dataOut : DataPort;
    }
    
    part def TemperatureSensor {
        attribute accuracy : TemperatureValue;
        
        port tempOut {
            out temperature : TemperatureValue;
        }
    }
    
    action def MeasureCapacitance {
        in item solution : ElectrolyteSolution;
        in part capacitor : EISCapacitor;
        in attribute biasVoltage : VoltageValue;
        out item signal : ElectricalSignal;
    }
    
    action def CalculatepH {
        in item signal : ElectricalSignal;
        in attribute sensitivity : Real;
        in attribute referenceCapacitance : CapacitanceValue;
        in attribute temperature : TemperatureValue;
        out attribute pH : pHValue;
    }
    
    action def CalibrateSignal {
        in item rawSignal : ElectricalSignal;
        in attribute calibrationCoefficients : Real[3];
        out item calibratedSignal : ElectricalSignal;
    }
    
    action def PerformMeasurement {
        in item inputSolution : ElectrolyteSolution;
        out item result : MeasurementResult;
        
        fork;
            action measureCap : MeasureCapacitance {
                in item :>> solution = inputSolution;
                out item rawSignal : ElectricalSignal;
            }
            then joinNode;
            
            action measureTemp {
                out attribute currentTemp : TemperatureValue;
            }
            then joinNode;
        join joinNode;
        
        flow from measureCap.rawSignal to calibrate.rawSignal;
        flow from measureTemp.currentTemp to calculate.temperature;
        
        action calibrate : CalibrateSignal {
            in item rawSignal;
            out item calibratedSignal : ElectricalSignal;
        }
        
        then action calculate : CalculatepH {
            in item signal = calibrate.calibratedSignal;
            out attribute :>> pH;
        }
        
        bind result.measuredpH = calculate.pH;
        bind result.rawCapacitance = measureCap.rawSignal.capacitance;
        bind result.temperature = measureTemp.currentTemp;
    }
    
    state def SensorOperatingStates {
        attribute status : String;
        
        entry; then idle;
        
        state idle;
        
        transition idle_to_warmup
            first idle
            accept PowerOn
            then warmup;
        
        state warmup;
        
        transition warmup_to_ready
            first warmup
            accept StabilizationComplete
            then ready;
        
        state ready;
        
        transition ready_to_measuring
            first ready
            accept SolutionIntroduced
            then measuring;
        
        state measuring;
        
        transition measuring_to_processing
            first measuring
            accept MeasurementComplete
            then processing;
        
        state processing;
        
        transition processing_to_ready
            first processing
            accept ProcessingComplete
            then ready;
        
        state error;
        
        transition any_to_error
            accept SensorFault
            then error;
        
        transition error_to_idle
            first error
            accept Reset
            then idle;
    }
    
    part def EISSensorElement {
        part eisCapacitor : EISCapacitor[1] {
            part :>> insulator {
                attribute :>> thickness = 50.0[nm];
                attribute :>> dielectricConstant = 3.9;
                attribute :>> material = "Silicon Dioxide";
            }
            part :>> semiconductor {
                attribute :>> substrateMaterial = "p-type Silicon";
                attribute :>> carrierMobility = 450.0;
            }
            part :>> reference {
                attribute :>> electrodeMaterial = "Ag/AgCl";
            }
        }
        
        port solutionInterface : SolutionPort;
        port signalOutput : SignalPort;
        port powerInput : PowerPort;
        
        attribute sensitivity : Real;
        attribute responseTime : TimeValue;
        attribute operatingTemperature : TemperatureValue;
    }
    
    part def SensingUnit {
        part eisSensor : EISSensorElement[1] {
            attribute :>> sensitivity = 0.059;
            attribute :>> responseTime = 5.0[s];
            attribute :>> operatingTemperature = 298.0[K];
        }
        
        part signalProcessor : SignalConditioner[1] {
            attribute :>> amplifierGain = 100.0;
            attribute :>> filterCutoff = 1000.0;
            attribute :>> adcResolution = 16.0;
        }
        
        part tempSensor : TemperatureSensor[1];
        
        part powerSupply {
            attribute outputVoltage : VoltageValue;
        }
        
        port sampleInput : SolutionPort;
        port measurementOutput : DataPort;
        
        connection solutionPath
            connect sampleInput to eisSensor.solutionInterface;
        
        connection signalPath
            connect eisSensor.signalOutput to signalProcessor.signalIn;
        
        connection dataPath
            connect signalProcessor.dataOut to measurementOutput;
        
        connection powerPath
            connect powerSupply to eisSensor.powerInput;
        
        attribute calibrationCoefficients : Real[3] = (1.0, 0.0, 0.0);
        attribute measurementRange : pHValue[2];
        attribute detectionLimit : pHValue;
        
        perform action sensingOperation : PerformMeasurement {
            in item :>> inputSolution;
            out item :>> result;
        }
        
        exhibit state sensorBehavior : SensorOperatingStates;
    }
    
    requirement def AccuracyRequirement {
        doc /* The sensing unit shall measure pH with accuracy within ±0.05 pH units 
               across the range of 2 to 12. */
        
        subject unit : SensingUnit;
        
        require constraint {
            unit.measurementOutput.data.measuredpH.num >= 2.0 and
            unit.measurementOutput.data.measuredpH.num <= 12.0
        }
        
        attribute maxError : pHValue;
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The sensing unit shall provide a stable measurement output 
               within 10 seconds of sample introduction. */
        
        subject unit : SensingUnit;
        
        require constraint {
            unit.eisSensor.responseTime.num <= 10.0
        }
    }
    
    requirement def OperatingRangeRequirement {
        doc /* The EIS sensor shall operate effectively over a temperature range 
               of 273 K to 323 K (0°C to 50°C). */
        
        subject sensor : EISSensorElement;
        
        require constraint {
            sensor.operatingTemperature.num >= 273.0 and
            sensor.operatingTemperature.num <= 323.0
        }
    }
    
    requirement def SensitivityRequirement {
        doc /* The EIS sensor shall exhibit a sensitivity of at least 
               55 mV per pH unit at 298 K. */
        
        subject sensor : EISSensorElement;
        
        require constraint {
            sensor.sensitivity >= 0.055
        }
    }
    
    part sensingUnit : SensingUnit {
        satisfy accuracyReq : AccuracyRequirement {
            subject unit = sensingUnit;
        }
        
        satisfy responseReq : ResponseTimeRequirement {
            subject unit = sensingUnit;
        }
        
        satisfy rangeReq : OperatingRangeRequirement {
            subject sensor = sensingUnit.eisSensor;
        }
        
        satisfy sensitivityReq : SensitivityRequirement {
            subject sensor = sensingUnit.eisSensor;
        }
    }
    
    individual def TestSolution1 : ElectrolyteSolution {
        attribute :>> temperature = 298.0[K];
    }
    
    individual def TestSolution2 : ElectrolyteSolution {
        attribute :>> temperature = 298.0[K];
    }
    
    individual testSequence {
        timeslice test1 {
            perform action :>> sensingUnit.sensingOperation {
                in item :>> inputSolution : TestSolution1;
                out item :>> result : MeasurementResult;
            }
        }
        then timeslice test2 {
            perform action :>> sensingUnit.sensingOperation {
                in item :>> inputSolution : TestSolution2;
                out item :>> result : MeasurementResult;
            }
        }
    }
}

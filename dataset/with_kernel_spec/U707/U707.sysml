package HeatFluxSensingUnitModel {
    private import ScalarValues::*;
    
    item def HeatFlow;
    item def RawVoltage;
    item def ConditionedVoltage;
    item def DigitalValue;
    item def CalibrationData {
        attribute sensitivity : Real;
        attribute voltageOffset : Real;
        attribute tempCoefficient : Real;
    }
    item def DataPacket {
        attribute heatFlux : Real;
        attribute timestamp : Real;
        attribute temperature : Real;
        attribute qualityIndicator : Integer;
    }
    
    port def HeatFlowPort {
        in item heatFlow : HeatFlow;
    }
    port def AnalogSignalPort {
        out item voltage : RawVoltage;
    }
    port def ConditionedSignalPort {
        out item voltage : ConditionedVoltage;
    }
    port def DigitalSignalPort {
        out item value : DigitalValue;
    }
    port def DataPort {
        out item data : DataPacket;
    }
    port def CalibrationPort {
        out item calData : CalibrationData;
    }
    
    action def Amplify {
        in raw : RawVoltage;
        out amplified : ConditionedVoltage;
    }
    action def FilterSignal {
        in noisy : ConditionedVoltage;
        out clean : ConditionedVoltage;
    }
    action def SampleAndConvert {
        in analog : ConditionedVoltage;
        out digital : DigitalValue;
    }
    action def CalculateHeatFlux {
        in digitalValue : DigitalValue;
        in calData : CalibrationData;
        in temp : Real;
        out packet : DataPacket;
    }
    action def LogData {
        in logEntry : DataPacket;
    }
    
    part def ThermopileSensor {
        port heatInPort : ~HeatFlowPort;
        port signalOutPort : AnalogSignalPort;
        attribute sensitivity : Real;
        attribute temperature : Real;
        perform action generateVoltage;
    }
    part def SignalConditioner {
        port signalInPort : ~AnalogSignalPort;
        port signalOutPort : ConditionedSignalPort;
        attribute gain : Real;
        attribute filterCutoff : Real;
        perform action amplify : Amplify;
        perform action filterSignal : FilterSignal;
    }
    part def ADC {
        port signalInPort : ~ConditionedSignalPort;
        port signalOutPort : DigitalSignalPort;
        attribute resolutionBits : Integer;
        perform action sampleAndConvert : SampleAndConvert;
    }
    part def CPU {
        port dataInPort : ~DigitalSignalPort;
        port calDataInPort : ~CalibrationPort;
        port dataOutPort : DataPort;
        attribute clockSpeed : Real;
        perform action calculateHeatFlux : CalculateHeatFlux;
    }
    part def DataStorage {
        port dataInPort : ~DataPort;
        attribute capacityRecords : Integer;
        perform action logData : LogData;
    }
    part def CalibrationMemory {
        port calDataOutPort : CalibrationPort;
        ref item calData : CalibrationData;
    }
    
    attribute def PowerOnSignal;
    attribute def InitCompleteSignal;
    attribute def WarmupCompleteSignal;
    attribute def StartMeasurementSignal;
    attribute def StopMeasurementSignal;
    attribute def EnterCalibrationSignal;
    attribute def CalibrationCompleteSignal;
    attribute def FaultDetectedSignal;
    attribute def RecoverySuccessSignal;
    
    state def UnitStates {
        entry; then off;
        state off;
        accept PowerOnSignal then initializing;
        state initializing;
        accept InitCompleteSignal then warmingUp;
        state warmingUp;
        accept WarmupCompleteSignal then ready;
        state ready;
        accept StartMeasurementSignal then measuring;
        accept EnterCalibrationSignal then calibrating;
        accept FaultDetectedSignal then fault;
        state measuring;
        accept StopMeasurementSignal then ready;
        accept FaultDetectedSignal then fault;
        state calibrating;
        accept CalibrationCompleteSignal then ready;
        accept FaultDetectedSignal then fault;
        state fault;
        accept RecoverySuccessSignal then ready;
    }
    
    part def HeatFluxSensingUnit {
        port heatInPort : ~HeatFlowPort;
        port dataOutPort : DataPort;
        
        part thermopile : ThermopileSensor;
        part conditioner : SignalConditioner;
        part adc : ADC;
        part cpu : CPU;
        part storage : DataStorage;
        part calMemory : CalibrationMemory;
        
        flow of heatFlow : HeatFlow
            from heatInPort.heatFlow to thermopile.heatInPort.heatFlow;
        flow of voltage : RawVoltage
            from thermopile.signalOutPort.voltage to conditioner.signalInPort.voltage;
        flow of voltage : ConditionedVoltage
            from conditioner.signalOutPort.voltage to adc.signalInPort.voltage;
        flow of value : DigitalValue
            from adc.signalOutPort.value to cpu.dataInPort.value;
        flow of calData : CalibrationData
            from calMemory.calDataOutPort.calData to cpu.calDataInPort.calData;
        flow of data : DataPacket
            from cpu.dataOutPort.data to dataOutPort.data;
        flow of data : DataPacket
            from cpu.dataOutPort.data to storage.dataInPort.data;
        
        exhibit state unitStates : UnitStates;
    }
    
    requirement def Req_HeatFluxMeasurement {
        text "The unit shall measure the rate of thermal energy transfer through a surface and output a calibrated digital measurement.";
    }
    requirement def Req_SignalProcessing {
        text "The raw analog voltage from the thermopile shall be amplified, filtered, and converted to a digital value by the ADC.";
    }
    requirement def Req_Calibration {
        text "The CPU shall apply stored calibration data including sensitivity, voltage offsets, and temperature variations to calculate the final heat flux.";
    }
    requirement def Req_DataOutput {
        text "The output data packet shall contain heat flux value, timestamp, sensor temperature, and quality indicator.";
    }
    requirement def Req_StateManagement {
        text "The unit shall transition through initialization, warm-up, ready, measuring, calibration, and fault states based on commands and internal conditions.";
    }
    
    part sensingUnit : HeatFluxSensingUnit;
}

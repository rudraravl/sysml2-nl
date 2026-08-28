package OscillatingUTubeDensitometer {
    private import ISQ::*;
    private import ScalarValues::*;
    private import Time::*;

    item def ProcessFluid {
        attribute density : MassDensityValue;
        attribute massFlowRate : MassFlowRateValue;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute pressure : PressureValue;
    }

    item def DriveSignal {
        attribute voltage : ElectricPotentialValue;
        attribute frequency : FrequencyValue;
    }

    item def SensorSignal {
        attribute displacement : LengthValue;
    }

    item def TemperatureSignal {
        attribute temperature : ThermodynamicTemperatureValue;
    }

    item def PressureSignal {
        attribute pressure : PressureValue;
    }

    item def MeasurementData {
        attribute density : MassDensityValue;
        attribute massFlowRate : MassFlowRateValue;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute pressure : PressureValue;
    }

    attribute def CalibrationConstants {
        attribute k0 : ScalarValues::Real;
        attribute k1 : ScalarValues::Real;
        attribute k2 : ScalarValues::Real;
    }

    port def FluidInPort {
        in fluid : ProcessFluid;
    }

    port def FluidOutPort {
        out fluid : ProcessFluid;
    }

    port def DriveOutPort {
        out driveSignal : DriveSignal;
    }

    port def DriveInPort {
        in driveSignal : DriveSignal;
    }

    port def SensorOutPort {
        out sensorSignal : SensorSignal;
    }

    port def SensorInPort {
        in sensorSignal : SensorSignal;
    }

    port def TempOutPort {
        out tempSignal : TemperatureSignal;
    }

    port def TempInPort {
        in tempSignal : TemperatureSignal;
    }

    port def PressureOutPort {
        out pressureSignal : PressureSignal;
    }

    port def PressureInPort {
        in pressureSignal : PressureSignal;
    }

    port def DataOutPort {
        out data : MeasurementData;
    }

    part def UTube {
        attribute material : ScalarValues::String = "Hastelloy C-276";
        attribute tubeMass : MassValue;
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port driveIn : DriveInPort;
        port sensorOut : SensorOutPort;
    }

    part def ElectromagneticDriver {
        port driveOut : DriveOutPort;
    }

    part def OpticalSensor {
        port sensorIn : SensorInPort;
        port sensorOut : SensorOutPort;
    }

    part def TemperatureTransducer {
        port tempOut : TempOutPort;
    }

    part def PressureTransducer {
        port pressureOut : PressureOutPort;
    }

    part def DSP {
        attribute calibrationConstants : CalibrationConstants;
        port sensorIn1 : SensorInPort;
        port sensorIn2 : SensorInPort;
        port tempIn : TempInPort;
        port pressureIn : PressureInPort;
        port dataOut : DataOutPort;
        perform action calculateDensity : CalculateDensity;
        perform action calculateMassFlowRate : CalculateMassFlowRate;
        exhibit state dspStates : DSPStates;
    }

    part def Densitometer {
        port processFluidIn : FluidInPort;
        port processFluidOut : FluidOutPort;
        port dataOutput : DataOutPort;
        
        part uTube : UTube;
        part driver : ElectromagneticDriver;
        part sensor1 : OpticalSensor;
        part sensor2 : OpticalSensor;
        part tempTransducer : TemperatureTransducer;
        part pressureTransducer : PressureTransducer;
        part dsp : DSP;
        
        flow fluidInFlow of ProcessFluid from processFluidIn.fluid to uTube.fluidIn.fluid;
        flow fluidOutFlow of ProcessFluid from uTube.fluidOut.fluid to processFluidOut.fluid;
        flow driveFlow of DriveSignal from driver.driveOut.driveSignal to uTube.driveIn.driveSignal;
        flow sensor1InFlow of SensorSignal from uTube.sensorOut.sensorSignal to sensor1.sensorIn.sensorSignal;
        flow sensor2InFlow of SensorSignal from uTube.sensorOut.sensorSignal to sensor2.sensorIn.sensorSignal;
        flow sensor1OutFlow of SensorSignal from sensor1.sensorOut.sensorSignal to dsp.sensorIn1.sensorSignal;
        flow sensor2OutFlow of SensorSignal from sensor2.sensorOut.sensorSignal to dsp.sensorIn2.sensorSignal;
        flow tempFlow of TemperatureSignal from tempTransducer.tempOut.tempSignal to dsp.tempIn.tempSignal;
        flow pressureFlow of PressureSignal from pressureTransducer.pressureOut.pressureSignal to dsp.pressureIn.pressureSignal;
        
        bind dataOutput = dsp.dataOut;
        
        exhibit state systemStates : DensitometerStates;
    }

    state def DensitometerStates {
        entry; then idle;
        state idle;
        transition idle_to_warmup first idle then warmup;
        state warmup;
        transition warmup_to_calibrating first warmup then calibrating;
        state calibrating;
        transition calibrating_to_measuring first calibrating then measuring;
        state measuring;
        transition measuring_to_maintenance first measuring then maintenance;
        state maintenance;
        transition maintenance_to_idle first maintenance then idle;
        transition measuring_to_fault first measuring then fault;
        state fault;
        transition fault_to_maintenance first fault then maintenance;
    }

    state def DSPStates {
        entry; then processing;
        state processing;
    }

    action def CalculateDensity {
        in sensor1Signal : SensorSignal;
        in sensor2Signal : SensorSignal;
        in tempSignal : TemperatureSignal;
        in pressureSignal : PressureSignal;
        in constants : CalibrationConstants;
        out density : MassDensityValue;
    }

    action def CalculateMassFlowRate {
        in density : MassDensityValue;
        out massFlowRate : MassFlowRateValue;
    }

    requirement def DensityMeasurementRequirement {
        doc /* The system shall continuously measure fluid density with high accuracy. */
        attribute requiredAccuracy : MassDensityValue;
    }

    requirement def MassFlowRateRequirement {
        doc /* The system shall calculate mass flow rate from measured density. */
        attribute requiredAccuracy : ScalarValues::Real;
    }

    requirement densityReq : DensityMeasurementRequirement;
    requirement flowRateReq : MassFlowRateRequirement;

    part densitometer : Densitometer {
        part :>> uTube {
            attribute ::> tubeMass = 0.05 [kg];
        }
        satisfy densityReq;
        satisfy flowRateReq;
    }
}

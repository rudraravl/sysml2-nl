package GasSensorSystem {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    package Definitions {
        attribute def ConcentrationValue :> Real;
        attribute def ResistanceValue :> ISQ::electricResistance;
        attribute def VoltageValue :> ISQ::voltage;
        attribute def TemperatureValue :> ISQ::temperature;
        attribute def TimeValue :> ISQ::time;
        attribute def CurrentValue :> ISQ::electricCurrent;

        item def GasEnvironment {
            attribute concentration : ConcentrationValue;
        }

        item def PowerLine {
            attribute voltage : VoltageValue;
            attribute current : CurrentValue;
        }

        item def HeatCommand {
            attribute targetTemp : TemperatureValue;
        }

        item def TempReached {
            attribute measuredTemp : TemperatureValue;
        }

        item def RawSignal {
            attribute resistance : ResistanceValue;
            attribute voltage : VoltageValue;
        }

        item def ConditionedSignal {
            attribute voltage : VoltageValue;
        }

        item def DigitalData {
            attribute value : Integer;
            attribute timestamp : TimeValue;
        }

        item def DataOutput {
            attribute concentration : ConcentrationValue;
            attribute resistance : ResistanceValue;
            attribute timestamp : TimeValue;
        }

        item def StartCommand;
        item def StartConversion;
        item def ConversionDone;

        item def CalibrationEntry {
            attribute resistance : ResistanceValue;
            attribute concentration : ConcentrationValue;
        }

        port def PowerInPort {
            in power : PowerLine;
        }

        port def PowerOutPort {
            out power : PowerLine;
        }

        port def GasInPort {
            in gas : GasEnvironment;
        }

        port def HeatCmdInPort {
            in heatCmd : HeatCommand;
        }

        port def HeatCmdOutPort {
            out heatCmd : HeatCommand;
        }

        port def TempReachedOutPort {
            out tempReached : TempReached;
        }

        port def TempReachedInPort {
            in tempReached : TempReached;
        }

        port def RawSignalOutPort {
            out rawSignal : RawSignal;
        }

        port def RawSignalInPort {
            in rawSignal : RawSignal;
        }

        port def ConditionedSignalOutPort {
            out conditionedSignal : ConditionedSignal;
        }

        port def ConditionedSignalInPort {
            in conditionedSignal : ConditionedSignal;
        }

        port def DigitalDataOutPort {
            out digitalData : DigitalData;
        }

        port def DigitalDataInPort {
            in digitalData : DigitalData;
        }

        port def DataOutputOutPort {
            out data : DataOutput;
        }

        port def StartConvOutPort {
            out startConv : StartConversion;
        }

        port def StartConvInPort {
            in startConv : StartConversion;
        }

        port def ConvDoneOutPort {
            out convDone : ConversionDone;
        }

        port def ConvDoneInPort {
            in convDone : ConversionDone;
        }

        port def CommandInPort {
            in cmd : StartCommand;
        }

        action def ActivateHeater;
        action def SampleEnvironment;
        action def AmplifyAndFilter;
        action def ConvertToDigital;
        action def CalculateConcentration {
            in digitalData : DigitalData;
            in calibration : CalibrationEntry[1..*];
            out concentration : ConcentrationValue;
        }
        action def PackageOutput {
            in concentration : ConcentrationValue;
            in resistance : ResistanceValue;
            in timestamp : TimeValue;
            out data : DataOutput;
        }

        state def McStates {
            entry; then idle;
            state idle;
            state warmingUp;
            state measurement;
            state processing;
            transition first idle then warmingUp;
            transition first warmingUp then measurement;
            transition first measurement then processing;
            transition first processing then idle;
        }

        part def PowerSupply {
            port powerOut : PowerOutPort;
            perform action supplyPower;
        }

        part def TemperatureController {
            port powerIn : PowerInPort;
            port heatCmdIn : HeatCmdInPort;
            port tempReachedOut : TempReachedOutPort;
            port heaterOut : HeatCmdOutPort;
            attribute measuredTemp : TemperatureValue;
            attribute targetTemp : TemperatureValue;
            perform action controlTemperature;
        }

        part def ZnONanorodSensor {
            port powerIn : PowerInPort;
            port gasIn : GasInPort;
            port heatCmdIn : HeatCmdInPort;
            port rawSignalOut : RawSignalOutPort;
            attribute operatingTemp : TemperatureValue;
            attribute resistance : ResistanceValue;
            perform action detectGas;
        }

        part def SignalConditioner {
            port powerIn : PowerInPort;
            port rawSignalIn : RawSignalInPort;
            port conditionedSignalOut : ConditionedSignalOutPort;
            perform action AmplifyAndFilter;
        }

        part def ADC {
            port powerIn : PowerInPort;
            port analogIn : ConditionedSignalInPort;
            port startConvIn : StartConvInPort;
            port digitalOut : DigitalDataOutPort;
            port convDoneOut : ConvDoneOutPort;
            perform action ConvertToDigital;
        }

        part def Microcontroller {
            port powerIn : PowerInPort;
            port digitalIn : DigitalDataInPort;
            port dataOut : DataOutputOutPort;
            port heatStartOut : HeatCmdOutPort;
            port tempReachedIn : TempReachedInPort;
            port adcStartOut : StartConvOutPort;
            port convDoneIn : ConvDoneInPort;
            attribute calibrationTable : CalibrationEntry[0..*];
            perform action CalculateConcentration;
            perform action PackageOutput;
            exhibit state mcState : McStates;
        }

        state def OperationalCycle {
            in mcu : Microcontroller;
            in outPort : DataOutputOutPort;
            entry; then idle;
            state idle;
            state warmingUp {
                do send new HeatCommand() to mcu.heatStartOut;
            }
            state measurement {
                do send new StartConversion() to mcu.adcStartOut;
            }
            state processing {
                do send new DataOutput() to outPort;
            }
            transition first idle accept cmd : StartCommand then warmingUp;
            transition first warmingUp accept tempReached : TempReached then measurement;
            transition first measurement accept convDone : ConversionDone then processing;
            transition first processing then idle;
        }

        part def GasSensorUnit {
            port commandIn : CommandInPort;
            port dataOut : DataOutputOutPort;
            port gasIn : GasInPort;
        }

        requirement HeatingRequirement {
            doc /* The zinc oxide nanorod sensing element must be heated to a specific high operating temperature to function correctly. */
            subject sensor : ZnONanorodSensor;
            attribute minOperatingTemp : TemperatureValue = 573 [K];
            constraint { sensor.operatingTemp >= minOperatingTemp }
        }

        requirement SignalConditioningRequirement {
            doc /* The raw electrical signal must be amplified and filtered before digitization. */
            subject conditioner : SignalConditioner;
        }

        requirement DataOutputRequirement {
            doc /* The final output must include gas concentration, measured resistance, and a timestamp. */
            subject output : DataOutput;
        }

        requirement PowerSupplyRequirement {
            doc /* A central power supply must provide stable regulated power to all electronic components. */
            subject psu : PowerSupply;
        }
    }

    package Usages {
        private import Definitions::*;

        part gasSensorUnit : GasSensorUnit {
            part powerSupply : PowerSupply;
            part tempController : TemperatureController;
            part nanorodSensor : ZnONanorodSensor;
            part signalConditioner : SignalConditioner;
            part adc : ADC;
            part microcontroller : Microcontroller;

            flow powerToTempCtrl of PowerLine
                from powerSupply.powerOut.power to tempController.powerIn.power;
            flow powerToSensor of PowerLine
                from powerSupply.powerOut.power to nanorodSensor.powerIn.power;
            flow powerToSignalCond of PowerLine
                from powerSupply.powerOut.power to signalConditioner.powerIn.power;
            flow powerToAdc of PowerLine
                from powerSupply.powerOut.power to adc.powerIn.power;
            flow powerToMicroctrl of PowerLine
                from powerSupply.powerOut.power to microcontroller.powerIn.power;

            flow gasFlow of GasEnvironment
                from gasIn.gas to nanorodSensor.gasIn.gas;

            flow heatStartFlow of HeatCommand
                from microcontroller.heatStartOut.heatCmd to tempController.heatCmdIn.heatCmd;

            flow heaterFlow of HeatCommand
                from tempController.heaterOut.heatCmd to nanorodSensor.heatCmdIn.heatCmd;

            flow tempReachedFlow of TempReached
                from tempController.tempReachedOut.tempReached to microcontroller.tempReachedIn.tempReached;

            flow rawSignalFlow of RawSignal
                from nanorodSensor.rawSignalOut.rawSignal to signalConditioner.rawSignalIn.rawSignal;

            flow conditionedSignalFlow of ConditionedSignal
                from signalConditioner.conditionedSignalOut.conditionedSignal to adc.analogIn.conditionedSignal;

            flow adcStartFlow of StartConversion
                from microcontroller.adcStartOut.startConv to adc.startConvIn.startConv;

            flow convDoneFlow of ConversionDone
                from adc.convDoneOut.convDone to microcontroller.convDoneIn.convDone;

            flow digitalDataFlow of DigitalData
                from adc.digitalOut.digitalData to microcontroller.digitalIn.digitalData;

            flow dataOutputFlow of DataOutput
                from microcontroller.dataOut.data to dataOut.data;

            exhibit OperationalCycle {
                in mcu = microcontroller;
                in outPort = dataOut;
            }
        }

        satisfy HeatingRequirement by gasSensorUnit.nanorodSensor;
        satisfy SignalConditioningRequirement by gasSensorUnit.signalConditioner;
        satisfy DataOutputRequirement by gasSensorUnit.microcontroller;
        satisfy PowerSupplyRequirement by gasSensorUnit.powerSupply;
    }
}

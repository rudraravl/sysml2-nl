package KnudsenPumpSubsystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====
    def PressureValue :> Real {
        :>> unit = 'Pa';
    }
    def TemperatureValue :> Real {
        :>> unit = 'K';
    }
    def FlowRateValue :> Real {
        :>> unit = 'm^3/s';
    }
    def VoltageValue :> Real {
        :>> unit = 'V';
    }
    def CurrentValue :> Real {
        :>> unit = 'A';
    }
    def PowerValue :> Real {
        :>> unit = 'W';
    }
    def LengthValue :> Real {
        :>> unit = 'm';
    }
    def AreaValue :> Real {
        :>> unit = 'm^2';
    }

    // ===== Item Definitions =====
    item def Gas;
    item def ElectricPower;

    // ===== Port Definitions =====
    port def GasPort {
        out item gas : Gas;
        ref attribute pressure : PressureValue;
    }
    port def PowerPort {
        in item power : ElectricPower;
        ref attribute voltage : VoltageValue;
        ref attribute current : CurrentValue;
    }
    port def PressureSignalPort {
        out attribute pressure : PressureValue;
    }
    port def TemperatureSignalPort {
        out attribute temperature : TemperatureValue;
    }
    port def FlowSignalPort {
        out attribute flowRate : FlowRateValue;
    }
    port def ControlPort {
        in attribute command : String;
        out attribute status : String;
    }

    // ===== Requirements =====
    requirement def PumpingRequirement {
        subject pump : KnudsenPump;
        attribute targetPressureDiff : PressureValue = 100.0;
        require pump.outletPressure - pump.inletPressure >= targetPressureDiff;
    }

    requirement def TemperatureGradientRequirement {
        subject pumpUnit : PumpingUnit;
        attribute minGradient : TemperatureValue = 200.0;
        require pumpUnit.hotSideTemp - pumpUnit.coldSideTemp >= minGradient;
    }

    requirement def LowPressureOperationRequirement {
        subject pump : KnudsenPump;
        attribute maxOperatingPressure : PressureValue = 1000.0;
        require pump.inletPressure <= maxOperatingPressure;
    }

    requirement def FlowRateRequirement {
        subject pump : KnudsenPump;
        attribute minFlowRate : FlowRateValue = 1.0e-6;
        require pump.outletFlowRate >= minFlowRate;
    }

    // ===== Part Definitions =====
    part def KnudsenPump {
        attribute inletPressure : PressureValue;
        attribute outletPressure : PressureValue;
        attribute outletFlowRate : FlowRateValue;

        port gasIn : GasPort;
        port gasOut : GasPort;
        port powerIn : PowerPort;
        port control : ControlPort;

        part sourceReservoir : SourceReservoir;
        part destinationReservoir : DestinationReservoir;
        part powerSupply : PowerSupply;
        part pumpingUnit : PumpingUnit;
        part inletPressureSensor : PressureSensor;
        part outletPressureSensor : PressureSensor;
        part hotSideTempSensor : TemperatureSensor;
        part coldSideTempSensor : TemperatureSensor;
        part outletFlowMeter : FlowMeter;
        part controller : PumpController;

        connection gasSourceToPump connect sourceReservoir.gasOut to pumpingUnit.gasIn;
        connection gasPumpToDest connect pumpingUnit.gasOut to destinationReservoir.gasIn;
        connection powerToHeater connect powerSupply.powerOut to pumpingUnit.powerIn;
        connection powerToController connect powerSupply.powerOut to controller.powerIn;

        connection inletPressureFeedback connect inletPressureSensor.signalOut to controller.inletPressureIn;
        connection outletPressureFeedback connect outletPressureSensor.signalOut to controller.outletPressureIn;
        connection hotTempFeedback connect hotSideTempSensor.signalOut to controller.hotTempIn;
        connection coldTempFeedback connect coldSideTempSensor.signalOut to controller.coldTempIn;
        connection flowFeedback connect outletFlowMeter.signalOut to controller.flowIn;

        connection heaterControl connect controller.heaterControlOut to pumpingUnit.heaterControlIn;
        connection coolerControl connect controller.coolerControlOut to pumpingUnit.coolerControlIn;

        satisfy PumpingRequirement by self;
        satisfy LowPressureOperationRequirement by self;
        satisfy FlowRateRequirement by self;

        exhibit state PumpStateMachine {
            entry; then Off;
            state Off;
            state Warmup;
            state Operating;
            state Cooldown;
            state Fault;

            transition Off_to_Warmup first Off if control.command == "start" then Warmup;
            transition Warmup_to_Operating first Warmup if hotSideTempSensor.temperature >= controller.targetHotTemp then Operating;
            transition Warmup_to_Fault first Warmup if hotSideTempSensor.temperature > controller.maxSafeTemp then Fault;
            transition Operating_to_Cooldown first Operating if control.command == "stop" then Cooldown;
            transition Operating_to_Fault first Operating if controller.faultDetected then Fault;
            transition Cooldown_to_Off first Cooldown if hotSideTempSensor.temperature <= controller.safeCooldownTemp then Off;
            transition Fault_to_Off first Fault if control.command == "reset" then Off;
        }
    }

    part def SourceReservoir {
        attribute initialPressure : PressureValue = 10.0;
        port gasOut : GasPort;
    }

    part def DestinationReservoir {
        attribute targetPressure : PressureValue = 100.0;
        port gasIn : GasPort;
    }

    part def PowerSupply {
        attribute outputVoltage : VoltageValue = 24.0;
        attribute maxCurrent : CurrentValue = 5.0;
        attribute outputPower : PowerValue = 120.0;
        port powerOut : PowerPort;
    }

    part def PumpingUnit {
        attribute channelDiameter : LengthValue = 1.0e-6;
        attribute channelLength : LengthValue = 5.0e-3;
        attribute channelCount : Integer = 10000;
        attribute hotSideTemp : TemperatureValue;
        attribute coldSideTemp : TemperatureValue;
        attribute thermalGradient : TemperatureValue = hotSideTemp - coldSideTemp;

        port gasIn : GasPort;
        port gasOut : GasPort;
        port powerIn : PowerPort;
        port heaterControlIn : ControlPort;
        port coolerControlIn : ControlPort;

        part channelArray : ChannelArray;
        part heatingElement : HeatingElement;
        part coolingElement : CoolingElement;

        connection powerToHeaterElement connect powerIn to heatingElement.powerIn;
        connection heaterToChannels connect heatingElement.thermalOut to channelArray.hotSide;
        connection coolerToChannels connect coolingElement.thermalOut to channelArray.coldSide;
        connection gasThroughChannels connect channelArray.gasIn to channelArray.gasOut;

        satisfy TemperatureGradientRequirement by self;
    }

    part def ChannelArray {
        attribute totalChannels : Integer = 10000;
        attribute channelRadius : LengthValue = 5.0e-7;
        attribute effectiveArea : AreaValue = totalChannels * 3.14159 * channelRadius * channelRadius;

        port gasIn : GasPort;
        port gasOut : GasPort;
        port hotSide : ControlPort;
        port coldSide : ControlPort;
    }

    part def HeatingElement {
        attribute maxPower : PowerValue = 80.0;
        attribute currentPower : PowerValue;
        attribute targetTemp : TemperatureValue = 450.0;
        port powerIn : PowerPort;
        port thermalOut : ControlPort;
    }

    part def CoolingElement {
        attribute coolingCapacity : PowerValue = 40.0;
        attribute targetTemp : TemperatureValue = 300.0;
        port thermalOut : ControlPort;
    }

    part def PressureSensor {
        attribute pressure : PressureValue;
        attribute accuracy : PressureValue = 0.5;
        port signalOut : PressureSignalPort;
    }

    part def TemperatureSensor {
        attribute temperature : TemperatureValue;
        attribute accuracy : TemperatureValue = 0.5;
        port signalOut : TemperatureSignalPort;
    }

    part def FlowMeter {
        attribute flowRate : FlowRateValue;
        attribute accuracy : FlowRateValue = 1.0e-8;
        port signalOut : FlowSignalPort;
    }

    part def PumpController {
        attribute targetHotTemp : TemperatureValue = 450.0;
        attribute maxSafeTemp : TemperatureValue = 500.0;
        attribute safeCooldownTemp : TemperatureValue = 310.0;
        attribute faultDetected : Boolean = false;
        attribute currentStatus : String = "off";

        port powerIn : PowerPort;
        port inletPressureIn : PressureSignalPort;
        port outletPressureIn : PressureSignalPort;
        port hotTempIn : TemperatureSignalPort;
        port coldTempIn : TemperatureSignalPort;
        port flowIn : FlowSignalPort;
        port heaterControlOut : ControlPort;
        port coolerControlOut : ControlPort;

        action regulateHeater {
            in hotTemp : TemperatureValue;
            in targetTemp : TemperatureValue;
            out heaterCommand : String;
        }
        action monitorPerformance {
            in inletP : PressureValue;
            in outletP : PressureValue;
            in flow : FlowRateValue;
            out status : String;
        }
        action detectFault {
            in hotTemp : TemperatureValue;
            in maxTemp : TemperatureValue;
            out fault : Boolean;
        }
    }
}

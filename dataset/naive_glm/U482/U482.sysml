package CoolingSystem {

    // ===== Value Types with Units =====

    attribute def Pressure {
        value :> value : Real;
        unit :> unit = 'Pa';
    }

    attribute def FlowRate {
        value :> value : Real;
        unit :> unit = 'm3/s';
    }

    attribute def Temperature {
        value :> value : Real;
        unit :> unit = 'K';
    }

    attribute def RotationalSpeed {
        value :> value : Real;
        unit :> unit = 'rad/s';
    }

    attribute def Voltage {
        value :> value : Real;
        unit :> unit = 'V';
    }

    attribute def Current {
        value :> value : Real;
        unit :> unit = 'A';
    }

    attribute def Torque {
        value :> value : Real;
        unit :> unit = 'N*m';
    }

    attribute def Power {
        value :> value : Real;
        unit :> unit = 'W';
    }

    attribute def Volume {
        value :> value : Real;
        unit :> unit = 'm3';
    }

    attribute def Length {
        value :> value : Real;
        unit :> unit = 'm';
    }

    // ===== Item Types =====

    item def Coolant {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute density : Real = 1000.0;
    }

    // ===== Port Definitions =====

    port def FluidPort {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute flowRate : FlowRate;
        flow of Coolant;
    }

    port def ElectricalPort {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    port def ShaftPort {
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
    }

    port def SignalPort {
        attribute signalValue : Real;
    }

    // ===== Requirements =====

    requirement def MaintainFlowRate {
        doc { The system shall maintain the coolant flow rate at or above the target flow rate during normal operation. }
        attribute targetFlow : FlowRate;
        attribute measuredFlow : FlowRate;
        constraint { measuredFlow >= targetFlow }
    }

    requirement def PreventDryRun {
        doc { The pump shall not operate when inlet pressure is below the minimum threshold to prevent dry running damage. }
        attribute inletPressure : Pressure;
        attribute minInletPressure : Pressure;
        constraint { inletPressure >= minInletPressure }
    }

    requirement def PreventOverheat {
        doc { The system shall trigger emergency shutdown when fluid temperature exceeds the maximum threshold. }
        attribute fluidTemperature : Temperature;
        attribute maxTemperature : Temperature;
        constraint { fluidTemperature <= maxTemperature }
    }

    requirement def CoolFluid {
        doc { The heat exchanger shall reduce fluid temperature by at least the specified delta before returning to reservoir. }
        attribute inletTemp : Temperature;
        attribute outletTemp : Temperature;
        attribute requiredDeltaT : Temperature;
        constraint { inletTemp - outletTemp >= requiredDeltaT }
    }

    requirement def EmergencyResponse {
        doc { The system shall enter a fault state and perform emergency shutdown within 2 seconds of detecting a critical condition. }
        attribute responseTime : Real = 2.0;
    }

    // ===== State Machine for Pump Operation =====

    state def PumpOperatingStates {
        entry; then Idle;

        state Idle {
            doc { Pump is in standby with zero rotational speed. }
            entry { pumpSpeed = 0.0; }
        }

        transition Idle_to_Starting
            first Idle
            then Starting
            if { startCommand == true };

        state Starting {
            doc { Pump is ramping up from zero to nominal speed. }
            entry { pumpSpeed = 0.0; }
            do action rampUpSpeed();
        }

        transition Starting_to_Running
            first Starting
            then Running
            if { pumpSpeed >= nominalSpeed };

        state Running {
            doc { Pump is operating at nominal speed with active flow regulation. }
            do action regulateFlow();
        }

        transition Running_to_ReducedFlow
            first Running
            then ReducedFlow
            if { reducedFlowCommand == true };

        transition ReducedFlow_to_Running
            first ReducedFlow
            then Running
            if { reducedFlowCommand == false };

        state ReducedFlow {
            doc { Pump is operating at reduced speed to conserve energy or respond to demand changes. }
            do action regulateFlow();
        }

        transition Running_to_Fault_DryRun
            first Running
            then Fault
            if { inletPressure < minInletPressure };

        transition Running_to_Fault_Overheat
            first Running
            then Fault
            if { fluidTemperature > maxTemperature };

        transition ReducedFlow_to_Fault_DryRun
            first ReducedFlow
            then Fault
            if { inletPressure < minInletPressure };

        transition ReducedFlow_to_Fault_Overheat
            first ReducedFlow
            then Fault
            if { fluidTemperature > maxTemperature };

        state Fault {
            doc { Critical condition detected; emergency shutdown initiated. }
            entry { triggerEmergencyShutdown(); }
        }

        transition Running_to_ShuttingDown
            first Running
            then ShuttingDown
            if { stopCommand == true };

        transition Fault_to_ShuttingDown
            first Fault
            then ShuttingDown;

        state ShuttingDown {
            doc { Pump is ramping down to zero speed. }
            do action rampDownSpeed();
        }

        transition ShuttingDown_to_Idle
            first ShuttingDown
            then Idle
            if { pumpSpeed == 0.0 };
    }

    // ===== Part Definitions =====

    part def ElectricMotor {
        port electricalIn : ElectricalPort;
        port shaftOut : ShaftPort;

        attribute supplyVoltage : Voltage = 230.0;
        attribute ratedPower : Power = 1500.0;
        attribute shaftSpeed : RotationalSpeed;
        attribute shaftTorque : Torque;
        attribute efficiency : Real = 0.92;

        action def convertElectricalToMechanical {
            in electricalEnergy : Real;
            out mechanicalEnergy : Real;
        }

        action def energize {
            in voltage : Voltage;
            out speed : RotationalSpeed;
            out torque : Torque;
        }
    }

    part def Impeller {
        port shaftIn : ShaftPort;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;

        attribute bladeCount : Integer = 7;
        attribute diameter : Length = 0.15;
        attribute ratedSpeed : RotationalSpeed;

        action def pressurizeFluid {
            in incomingFluid : Coolant;
            in shaftSpeed : RotationalSpeed;
            out pressurizedFluid : Coolant;
        }
    }

    part def PumpHousing {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute material : String = "Cast Iron";
        attribute maxPressure : Pressure = 1000000.0;
        attribute wallThickness : Length = 0.012;
    }

    part def CirculatorPump {
        part motor : ElectricMotor {
            port electricalIn : ElectricalPort;
            port shaftOut : ShaftPort;
        }

        part impeller : Impeller {
            port shaftIn : ShaftPort;
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
        }

        part housing : PumpHousing {
            port inlet : FluidPort;
            port outlet : FluidPort;
        }

        port electricalInput : ElectricalPort;
        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
        port controlSignal : SignalPort;
        port sensorFeedback : SignalPort;

        attribute nominalSpeed : RotationalSpeed = 314.0;
        attribute pumpSpeed : RotationalSpeed = 0.0;
        attribute startCommand : Boolean = false;
        attribute stopCommand : Boolean = false;
        attribute reducedFlowCommand : Boolean = false;
        attribute inletPressure : Pressure;
        attribute fluidTemperature : Temperature;
        attribute minInletPressure : Pressure = 50000.0;
        attribute maxTemperature : Temperature = 350.0;

        exhibit state operatingBehavior : PumpOperatingStates;

        action def rampUpSpeed {
            doc { Gradually increase pump speed from zero to nominal over a safe time interval. }
            in currentSpeed : RotationalSpeed;
            out newSpeed : RotationalSpeed;
        }

        action def rampDownSpeed {
            doc { Gradually decrease pump speed to zero. }
            in currentSpeed : RotationalSpeed;
            out newSpeed : RotationalSpeed;
        }

        action def regulateFlow {
            doc { Adjust pump speed based on control signal to maintain target flow rate. }
            in controlValue : Real;
            out adjustedSpeed : RotationalSpeed;
        }

        action def triggerEmergencyShutdown {
            doc { Immediately set pump speed to zero and issue fault alert. }
            out faultSignal : Boolean;
        }

        connection motorShaftToImpeller : ShaftPort connect motor.shaftOut to impeller.shaftIn;

        connection electricalToMotor : ElectricalPort connect electricalInput to motor.electricalIn;

        connection fluidInletToHousing : FluidPort connect fluidInlet to housing.inlet;
        connection housingToImpellerIn : FluidPort connect housing.inlet to impeller.fluidIn;
        connection impellerOutToHousing : FluidPort connect impeller.fluidOut to housing.outlet;
        connection housingOutletToPort : FluidPort connect housing.outlet to fluidOutlet;
    }

    part def Reservoir {
        port fluidReturn : FluidPort;
        port fluidSupply : FluidPort;

        attribute capacity : Volume = 0.05;
        attribute currentVolume : Volume;
        attribute fluidLevel : Real;
        attribute ventPressure : Pressure = 101325.0;
    }

    part def Pipe {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute length : Length;
        attribute innerDiameter : Length;
        attribute pressureDrop : Pressure;
        attribute material : String = "Stainless Steel";
    }

    part def HeatExchanger {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port coolantIn : FluidPort;
        port coolantOut : FluidPort;

        attribute heatTransferRate : Power = 5000.0;
        attribute effectiveness : Real = 0.85;
        attribute surfaceArea : Real = 2.5;

        action def transferHeat {
            in hotFluid : Coolant;
            in coolingMedium : Coolant;
            out cooledFluid : Coolant;
            out warmedMedium : Coolant;
        }
    }

    part def PressureSensor {
        port fluidConnection : FluidPort;
        port signalOut : SignalPort;

        attribute measuredPressure : Pressure;
        attribute minThreshold : Pressure = 50000.0;
        attribute samplingRate : Real = 10.0;

        action def measurePressure {
            in fluidPort : FluidPort;
            out pressureReading : Pressure;
        }
    }

    part def FlowSensor {
        port fluidConnection : FluidPort;
        port signalOut : SignalPort;

        attribute measuredFlowRate : FlowRate;
        attribute targetFlowRate : FlowRate = 0.002;
        attribute samplingRate : Real = 10.0;

        action def measureFlow {
            in fluidPort : FluidPort;
            out flowReading : FlowRate;
        }
    }

    part def TemperatureSensor {
        port fluidConnection : FluidPort;
        port signalOut : SignalPort;

        attribute measuredTemperature : Temperature;
        attribute maxThreshold : Temperature = 350.0;
        attribute samplingRate : Real = 5.0;

        action def measureTemperature {
            in fluidPort : FluidPort;
            out temperatureReading : Temperature;
        }
    }

    part def ControlSystem {
        port pressureSignalIn : SignalPort;
        port flowSignalIn : SignalPort;
        port temperatureSignalIn : SignalPort;
        port pumpControlOut : SignalPort;

        attribute targetFlowRate : FlowRate = 0.002;
        attribute currentFlowRate : FlowRate;
        attribute currentPressure : Pressure;
        attribute currentTemperature : Temperature;
        attribute proportionalGain : Real = 0.5;
        attribute integralGain : Real = 0.1;
        attribute flowError : Real;
        attribute controlOutput : Real;

        action def processSensorData {
            in pressureReading : Real;
            in flowReading : Real;
            in temperatureReading : Real;
            out controlCommand : Real;
        }

        action def adjustPumpSpeed {
            in flowError : Real;
            out speedCommand : Real;
        }

        action def evaluateSafety {
            in pressure : Pressure;
            in temperature : Temperature;
            out emergencyStop : Boolean;
        }
    }

    // ===== Top-Level System =====

    part def CoolingSystem {
        part reservoir : Reservoir {
            port fluidReturn : FluidPort;
            port fluidSupply : FluidPort;
        }

        part supplyPipe : Pipe {
            port inlet : FluidPort;
            port outlet : FluidPort;
            attribute length : Length = 1.5;
            attribute innerDiameter : Length = 0.025;
        }

        part pump : CirculatorPump {
            port electricalInput : ElectricalPort;
            port fluidInlet : FluidPort;
            port fluidOutlet : FluidPort;
            port controlSignal : SignalPort;
        }

        part dischargePipe : Pipe {
            port inlet : FluidPort;
            port outlet : FluidPort;
            attribute length : Length = 2.0;
            attribute innerDiameter : Length = 0.025;
        }

        part heatExchanger : HeatExchanger {
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
            port coolantIn : FluidPort;
            port coolantOut : FluidPort;
        }

        part returnPipe : Pipe {
            port inlet : FluidPort;
            port outlet : FluidPort;
            attribute length : Length = 3.0;
            attribute innerDiameter : Length = 0.025;
        }

        part pressureSensor : PressureSensor {
            port fluidConnection : FluidPort;
            port signalOut : SignalPort;
        }

        part flowSensor : FlowSensor {
            port fluidConnection : FluidPort;
            port signalOut : SignalPort;
        }

        part temperatureSensor : TemperatureSensor {
            port fluidConnection : FluidPort;
            port signalOut : SignalPort;
        }

        part controller : ControlSystem {
            port pressureSignalIn : SignalPort;
            port flowSignalIn : SignalPort;
            port temperatureSignalIn : SignalPort;
            port pumpControlOut : SignalPort;
        }

        // Fluid circuit connections
        connection reservoirToSupplyPipe : FluidPort
            connect reservoir.fluidSupply to supplyPipe.inlet;

        connection supplyPipeToPump : FluidPort
            connect supplyPipe.outlet to pump.fluidInlet;

        connection pumpToDischargePipe : FluidPort
            connect pump.fluidOutlet to dischargePipe.inlet;

        connection dischargePipeToHeatExchanger : FluidPort
            connect dischargePipe.outlet to heatExchanger.fluidIn;

        connection heatExchangerToReturnPipe : FluidPort
            connect heatExchanger.fluidOut to returnPipe.inlet;

        connection returnPipeToReservoir : FluidPort
            connect returnPipe.outlet to reservoir.fluidReturn;

        // Sensor fluid connections
        connection pumpInletToPressureSensor : FluidPort
            connect pump.fluidInlet to pressureSensor.fluidConnection;

        connection pumpOutletToFlowSensor : FluidPort
            connect pump.fluidOutlet to flowSensor.fluidConnection;

        connection heatExchangerOutletToTempSensor : FluidPort
            connect heatExchanger.fluidOut to temperatureSensor.fluidConnection;

        // Signal connections from sensors to controller
        connection pressureToController : SignalPort
            connect pressureSensor.signalOut to controller.pressureSignalIn;

        connection flowToController : SignalPort
            connect flowSensor.signalOut to controller.flowSignalIn;

        connection tempToController : SignalPort
            connect temperatureSensor.signalOut to controller.temperatureSignalIn;

        // Control signal from controller to pump
        connection controllerToPump : SignalPort
            connect controller.pumpControlOut to pump.controlSignal;

        // Requirements satisfaction
        satisfy MaintainFlowRate by controller.targetFlowRate;
        satisfy PreventDryRun by pressureSensor.minThreshold;
        satisfy PreventOverheat by temperatureSensor.maxThreshold;
        satisfy CoolFluid by heatExchanger.heatTransferRate;
        satisfy EmergencyResponse by pump;
    }
}

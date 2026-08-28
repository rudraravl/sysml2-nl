package BohnertIrrigationSystem {
    private import ScalarValues::*;

    item def Water;

    attribute def StartSignal;
    attribute def StopSignal;
    attribute def MotorUpToSpeed;
    attribute def MotorStopped;

    attribute def PowerValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def SpeedValue :> Real;
    attribute def PressureValue :> Real;
    attribute def FlowRateValue :> Real;
    attribute def TorqueValue :> Real;

    port def WaterInPort {
        in item water : Water;
    }
    port def WaterOutPort {
        out item water : Water;
    }
    port def PressurePort {
        out pressure : PressureValue;
    }
    port def PressureInPort {
        in pressure : PressureValue;
    }
    port def ShaftPort {
        out speed : SpeedValue;
        out torque : TorqueValue;
    }
    port def ShaftInPort {
        in speed : SpeedValue;
        in torque : TorqueValue;
    }
    port def ControlPort {
        out startCmd : StartSignal;
        out stopCmd : StopSignal;
    }
    port def ControlInPort {
        in startCmd : StartSignal;
        in stopCmd : StopSignal;
    }

    part def Strainer;
    part def FootValve;
    part def CheckValve;
    part def GateValve;
    part def MotorStarter;
    part def OverloadRelay;

    part def IrrigationSystem {
        part pump : CentrifugalPump;
        part motor : ElectricMotor;
        part piping : PipingNetwork;
        part controlPanel : ControlPanel;
        part field : RiceField;
        part source : WaterSource;
    }

    part def CentrifugalPump {
        attribute material : String = "Cast Iron";
        attribute manufacturer : String = "A.M. Bohnert";
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        port pressureOut : PressurePort;
        port shaftIn : ShaftInPort;
        part impeller {
            attribute vanes : Integer = 6;
        }
        part shaft {
            attribute material : String = "Stainless Steel";
            attribute speed : SpeedValue;
        }
        part bearing {
            attribute lubrication : String = "Grease";
            attribute type : String = "Ball";
        }
        part seal {
            attribute material : String = "Silicon Carbide";
            attribute type : String = "Mechanical";
        }
        exhibit state pumpStates : PumpOperationStates;
    }

    part def ElectricMotor {
        attribute power : PowerValue = 7.5;
        attribute voltage : VoltageValue = 480;
        attribute nominalSpeed : SpeedValue = 1750;
        port controlIn : ControlInPort;
        port shaftOut : ShaftPort;
        exhibit state motorStates : MotorOperationStates;
    }

    part def PipingNetwork {
        part suctionPipe : Pipe;
        part dischargePipe : Pipe;
    }

    part def Pipe {
        attribute material : String = "PVC";
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
    }

    part def ControlPanel {
        port pressureIn : PressureInPort;
        port controlOut : ControlPort;
        part motorStarter : MotorStarter;
        part overloadRelay : OverloadRelay;
        part pressureSwitch {
            port pressureIn : PressureInPort;
            attribute lowerLimit : PressureValue;
            attribute upperLimit : PressureValue;
            port controlOut : ControlPort;
        }
        exhibit state controllerStates : ControllerStates;
    }

    part def WaterSource {
        port waterOut : WaterOutPort;
    }

    part def RiceField {
        port waterIn : WaterInPort;
        attribute waterRequirement : FlowRateValue;
    }

    action def MonitorPressure {
        in pressure : PressureValue;
        in lowerLimit : PressureValue;
        in upperLimit : PressureValue;
        out startCmd : StartSignal;
        out stopCmd : StopSignal;
    }

    action def PumpWater {
        in inWater : Water;
        out outWater : Water;
    }

    state def PumpOperationStates {
        state off;
        state starting;
        state running;
        state stopping;
        transition off_to_starting first off then starting accept StartSignal;
        transition starting_to_running first starting then running accept MotorUpToSpeed;
        transition running_to_stopping first running then stopping accept StopSignal;
        transition stopping_to_off first stopping then off accept MotorStopped;
    }

    state def MotorOperationStates {
        state off;
        state starting;
        state running;
        state stopping;
        transition off_to_starting first off then starting accept StartSignal;
        transition starting_to_running first starting then running accept MotorUpToSpeed;
        transition running_to_stopping first running then stopping accept StopSignal;
        transition stopping_to_off first stopping then off accept MotorStopped;
    }

    state def ControllerStates {
        state monitoring;
        state startingMotor;
        state stoppingMotor;
        transition monitor_to_start first monitoring then startingMotor accept StartSignal;
        transition start_to_monitor first startingMotor then monitoring;
        transition monitor_to_stop first monitoring then stoppingMotor accept StopSignal;
        transition stop_to_monitor first stoppingMotor then monitoring;
    }

    requirement def IrrigationRequirement {
        subject system : IrrigationSystem;
        objective {
            doc "The system shall deliver water to the rice field to meet crop water requirements.";
        }
    }

    requirement def MotorPowerRequirement {
        subject motor : ElectricMotor;
        objective {
            doc "The motor shall have a power of 7.5 kW and voltage of 480 V.";
        }
    }

    requirement def PumpSpeedRequirement {
        subject pump : CentrifugalPump;
        objective {
            doc "The pump shall spin at a nominal speed of 1750 RPM.";
        }
    }

    part bohnertPlantationSystem : IrrigationSystem {
        part source : WaterSource;
        part piping : PipingNetwork {
            part suctionPipe : Pipe {
                part strainer : Strainer;
                part footValve : FootValve;
            }
            part dischargePipe : Pipe {
                part checkValve : CheckValve;
                part gateValve : GateValve;
            }
        }
        part pump : CentrifugalPump {
            perform action pumpWater : PumpWater {
                in inWater = waterIn.water;
                out outWater = waterOut.water;
            }
        }
        part field : RiceField;
        part motor : ElectricMotor;
        part controlPanel : ControlPanel {
            part pressureSwitch {
                attribute lowerLimit : PressureValue = 2.0;
                attribute upperLimit : PressureValue = 4.0;
            }
            connect pressureIn to pressureSwitch.pressureIn;
            connect pressureSwitch.controlOut to controlOut;
        }

        flow of water : Water from source.waterOut.water to piping.suctionPipe.waterIn.water;
        flow of water : Water from piping.suctionPipe.waterOut.water to pump.waterIn.water;
        flow of water : Water from pump.waterOut.water to piping.dischargePipe.waterIn.water;
        flow of water : Water from piping.dischargePipe.waterOut.water to field.waterIn.water;

        connect motor.shaftOut to pump.shaftIn;
        connect pump.pressureOut to controlPanel.pressureIn;
        connect controlPanel.controlOut to motor.controlIn;

        satisfy IrrigationRequirement by bohnertPlantationSystem;
        satisfy MotorPowerRequirement by motor;
        satisfy PumpSpeedRequirement by pump;
    }
}

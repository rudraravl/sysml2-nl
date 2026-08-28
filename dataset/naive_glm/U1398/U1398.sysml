package IndustrialCoolingTower {
    import ScalarValues::*;

    unit degC;
    unit kW;
    unit m3s;
    unit rpm;
    unit percent;

    attribute def Temperature :> Real { unit degC; }
    attribute def Power :> Real { unit kW; }
    attribute def VolumeFlowRate :> Real { unit m3s; }
    attribute def RotationalSpeed :> Real { unit rpm; }
    attribute def Percentage :> Real { unit percent; }

    item def Water;
    item def Air;
    item def WaterVapor;
    item def Heat;
    item def ControlSignal;
    item def StartSignal :> ControlSignal;
    item def StopSignal :> ControlSignal;
    item def EmergencySignal :> ControlSignal;
    item def ResetSignal :> ControlSignal;
    item def TemperatureReading :> ControlSignal {
        attr temperature : Temperature;
    }
    item def FanSpeedCommand :> ControlSignal {
        attr speed : RotationalSpeed;
    }

    port def WaterInPort {
        in item Water;
    }
    port def WaterOutPort {
        out item Water;
    }
    port def AirInPort {
        in item Air;
    }
    port def AirOutPort {
        out item Air;
    }
    port def TempSignalOutPort {
        out item TemperatureReading;
    }
    port def TempSignalInPort {
        in item TemperatureReading;
    }
    port def CmdSignalOutPort {
        out item FanSpeedCommand;
    }
    port def CmdSignalInPort {
        in item FanSpeedCommand;
    }
    port def ControlSignalInPort {
        in item ControlSignal;
    }

    part def Nozzle {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
    }

    part def WaterDistributionSystem {
        port hotWaterIn : WaterInPort;
        port sprayOut : WaterOutPort;
        attr nozzleCount : Integer = 24;
        part nozzles : Nozzle[1..*];
        connection distribute connect hotWaterIn to nozzles.waterIn;
        connection spray connect nozzles.waterOut to sprayOut;
    }

    part def FillMedia {
        port waterIn : WaterInPort;
        port airIn : AirInPort;
        port waterOut : WaterOutPort;
        port airOut : AirOutPort;
        attr surfaceArea : Real = 5000;
        action def Evaporate {
            in item hotWater : Water;
            in item air : Air;
            out item cooledWater : Water;
            out item moistAir : Air;
            out item vapor : WaterVapor;
            out item heat : Heat;
        }
        action evaporate : Evaporate;
        flow from waterIn to evaporate.hotWater;
        flow from airIn to evaporate.air;
        flow from evaporate.cooledWater to waterOut;
        flow from evaporate.moistAir to airOut;
    }

    part def InducedDraftFan {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port cmdIn : CmdSignalInPort;
        attr currentSpeed : RotationalSpeed = 0 [rpm];
        attr maxSpeed : RotationalSpeed = 1000 [rpm];
        action def AdjustSpeed {
            in item cmd : FanSpeedCommand;
            out item speed : RotationalSpeed;
        }
        action adjust : AdjustSpeed;
        flow from cmdIn to adjust.cmd;
        flow from adjust.speed to currentSpeed;
    }

    part def ColdWaterBasin {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        attr level : Real = 0;
        attr capacity : Real = 10000;
    }

    part def CirculationPump {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        attr flowRate : VolumeFlowRate = 50 [m3s];
        attr power : Power = 15 [kW];
    }

    part def TemperatureSensor {
        port waterIn : WaterInPort;
        port signalOut : TempSignalOutPort;
        attr measuredTemp : Temperature = 20 [degC];
        action def Measure {
            in item water : Water;
            out item reading : TemperatureReading;
        }
        action measure : Measure;
        flow from waterIn to measure.water;
        flow from measure.reading to signalOut;
    }

    part def ControlSystem {
        port hotTempIn : TempSignalInPort;
        port coldTempIn : TempSignalInPort;
        port fanCmdOut : CmdSignalOutPort;
        port controlIn : ControlSignalInPort;

        attr setpoint : Temperature = 25 [degC];
        attr hotWaterTemp : Temperature = 30 [degC];
        attr coldWaterTemp : Temperature = 25 [degC];
        attr fanCommandSpeed : RotationalSpeed = 0 [rpm];
        attr startCommand : Boolean = false;
        attr stopCommand : Boolean = false;
        attr emergencyCommand : Boolean = false;
        attr resetCommand : Boolean = false;

        action def UpdateTemperatures {
            in hotReading : TemperatureReading;
            in coldReading : TemperatureReading;
            out hotTemp : Temperature;
            out coldTemp : Temperature;
        }
        action update : UpdateTemperatures;
        flow from hotTempIn to update.hotReading;
        flow from coldTempIn to update.coldReading;
        flow from update.hotTemp to hotWaterTemp;
        flow from update.coldTemp to coldWaterTemp;

        action def DecodeControlSignal {
            in item signal : ControlSignal;
            out start : Boolean;
            out stop : Boolean;
            out emergency : Boolean;
            out reset : Boolean;
        }
        action decode : DecodeControlSignal;
        flow from controlIn to decode.signal;
        flow from decode.start to startCommand;
        flow from decode.stop to stopCommand;
        flow from decode.emergency to emergencyCommand;
        flow from decode.reset to resetCommand;

        action def ComputeFanSpeed {
            in coldTemp : Temperature;
            in setpoint : Temperature;
            out cmd : FanSpeedCommand;
        }
        action compute : ComputeFanSpeed;
        flow from coldWaterTemp to compute.coldTemp;
        flow from setpoint to compute.setpoint;
        flow from compute.cmd to fanCmdOut;
        bind fanCommandSpeed = compute.cmd.speed;

        state machine ControlStateMachine {
            state idle;
            state startup;
            state normalOperation;
            state highLoad;
            state controlledShutdown;
            state emergencyStop;

            transition initial to idle;
            transition idle to startup when startCommand;
            transition startup to normalOperation when fanCommandSpeed > 0;
            transition normalOperation to highLoad when coldWaterTemp > setpoint + 5 [degC];
            transition highLoad to normalOperation when coldWaterTemp <= setpoint + 2 [degC];
            transition normalOperation to controlledShutdown when stopCommand;
            transition highLoad to controlledShutdown when stopCommand;
            transition controlledShutdown to idle when fanCommandSpeed == 0;
            transition any to emergencyStop when emergencyCommand;
            transition emergencyStop to idle when resetCommand;
        }
    }

    part def CoolingTowerSystem {
        port hotWaterIn : WaterInPort;
        port coldWaterOut : WaterOutPort;
        port ambientAirIn : AirInPort;
        port exhaustAirOut : AirOutPort;
        port controlIn : ControlSignalInPort;

        attr hotWaterTemp : Temperature = 35 [degC];
        attr coldWaterTemp : Temperature = 25 [degC];
        attr setpoint : Temperature = 25 [degC];

        part waterDistribution : WaterDistributionSystem;
        part fillMedia : FillMedia;
        part fan : InducedDraftFan;
        part basin : ColdWaterBasin;
        part pump : CirculationPump;
        part controller : ControlSystem;
        part hotWaterSensor : TemperatureSensor;
        part coldWaterSensor : TemperatureSensor;

        connection hotWaterToDistribution connect hotWaterIn to waterDistribution.hotWaterIn;
        connection distributionToFill connect waterDistribution.sprayOut to fillMedia.waterIn;
        connection fillToBasin connect fillMedia.waterOut to basin.waterIn;
        connection basinToPump connect basin.waterOut to pump.waterIn;
        connection pumpToOut connect pump.waterOut to coldWaterOut;

        connection ambientAirToFill connect ambientAirIn to fillMedia.airIn;
        connection fillToFan connect fillMedia.airOut to fan.airIn;
        connection fanToExhaust connect fan.airOut to exhaustAirOut;

        connection hotWaterToSensor connect hotWaterIn to hotWaterSensor.waterIn;
        connection coldWaterToSensor connect coldWaterOut to coldWaterSensor.waterIn;
        connection hotSensorToController connect hotWaterSensor.signalOut to controller.hotTempIn;
        connection coldSensorToController connect coldWaterSensor.signalOut to controller.coldTempIn;

        connection controllerToFan connect controller.fanCmdOut to fan.cmdIn;
        connection externalControlToController connect controlIn to controller.controlIn;
    }

    requirement def CoolingFunction {
        subject tower : CoolingTowerSystem;
        objective {
            tower.coldWaterTemp < tower.hotWaterTemp;
        }
    }

    requirement def WaterDistributionRequirement {
        subject dist : WaterDistributionSystem;
        objective {
            dist.nozzleCount > 0;
        }
    }

    requirement def FillMediaRequirement {
        subject fill : FillMedia;
        objective {
            fill.surfaceArea > 1000;
        }
    }

    requirement def AirFlowRequirement {
        subject fan : InducedDraftFan;
        objective {
            fan.maxSpeed > 0;
        }
    }

    requirement def EvaporativeCoolingRequirement {
        subject fill : FillMedia;
        objective {
            fill.evaporate.vapor == WaterVapor;
        }
    }

    requirement def WaterCollectionRequirement {
        subject basin : ColdWaterBasin;
        objective {
            basin.capacity > 0;
        }
    }

    requirement def CirculationRequirement {
        subject pump : CirculationPump;
        objective {
            pump.flowRate > 0;
        }
    }

    requirement def ControlSystemRequirement {
        subject controller : ControlSystem;
        objective {
            controller.setpoint == 25 [degC];
        }
    }

    requirement def OperatingStatesRequirement {
        subject controller : ControlSystem;
        objective {
            controller.ControlStateMachine.idle != null;
        }
    }

    requirement def SafetyProceduresRequirement {
        subject controller : ControlSystem;
        objective {
            controller.ControlStateMachine.emergencyStop != null;
        }
    }
}

package AutomatedLiquidCoolingSystem {
    import ScalarValues::*;
    import SI::*;

    value type TemperatureC :> Real { unit = 'degC'; }
    value type FlowRateLmin :> Real { unit = 'L/min'; }
    value type RotationalSpeed :> Real { unit = 'rpm'; }
    value type Percent :> Real { unit = '%'; }
    value type PowerW :> Real { unit = 'W'; }
    value type AreaM2 :> Real { unit = 'm^2'; }

    item def Coolant;
    item def AmbientAir;

    attribute def TempSignal { value : TemperatureC; }
    attribute def FlowSignal { value : FlowRateLmin; }
    attribute def LevelSignal { value : Percent; }
    attribute def SpeedSignal { value : RotationalSpeed; }

    port def LiquidInPort { in flow : Coolant; }
    port def LiquidOutPort { out flow : Coolant; }
    port def AirInPort { in flow : AmbientAir; }
    port def AirOutPort { out flow : AmbientAir; }
    port def TempOutPort { out signal : TempSignal; }
    port def FlowOutPort { out signal : FlowSignal; }
    port def LevelOutPort { out signal : LevelSignal; }
    port def SpeedInPort { in signal : SpeedSignal; }
    port def SpeedOutPort { out signal : SpeedSignal; }

    part def HeatGeneratingComponent {
        attribute heatOutput : PowerW;
        port thermalOut;
    }

    part def WaterBlock {
        port liquidIn : LiquidInPort;
        port liquidOut : LiquidOutPort;
        attribute thermalConductivity : Real;
    }

    part def CoolantPump {
        port liquidIn : LiquidInPort;
        port liquidOut : LiquidOutPort;
        port speedIn : SpeedInPort;
        attribute currentSpeed : RotationalSpeed;
        action def setSpeed {
            in targetSpeed : RotationalSpeed;
            then assign currentSpeed = targetSpeed;
        }
    }

    part def Radiator {
        port liquidIn : LiquidInPort;
        port liquidOut : LiquidOutPort;
        port airIn : AirInPort;
        port airOut : AirOutPort;
        attribute surfaceArea : AreaM2;
    }

    part def CoolingFan {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port speedIn : SpeedInPort;
        attribute currentSpeed : RotationalSpeed;
    }

    part def CoolantReservoir {
        port liquidIn : LiquidInPort;
        port liquidOut : LiquidOutPort;
        port levelOut : LevelOutPort;
        attribute currentLevel : Percent;
        action def monitorLevel {
            then assign levelOut.signal.value = currentLevel;
        }
    }

    part def TemperatureSensor {
        port tempOut : TempOutPort;
        attribute measuredTemp : TemperatureC;
        action def readTemp {
            then assign tempOut.signal.value = measuredTemp;
        }
    }

    part def FlowSensor {
        port flowOut : FlowOutPort;
        attribute measuredFlow : FlowRateLmin;
        action def readFlow {
            then assign flowOut.signal.value = measuredFlow;
        }
    }

    part def SystemController {
        port tempIn : TempOutPort;
        port flowIn : FlowOutPort;
        port levelIn : LevelOutPort;
        port pumpCmdOut : SpeedOutPort;
        port fanCmdOut : SpeedOutPort;

        attribute targetTemp : TemperatureC = 60.0;
        attribute criticalTemp : TemperatureC = 85.0;
        attribute minLevel : Percent = 10.0;

        state machine ControllerStates {
            state standby {
                entry {
                    assign pumpCmdOut.signal.value = 0.0;
                    assign fanCmdOut.signal.value = 0.0;
                }
            }
            state activeCooling {
                entry {
                    assign pumpCmdOut.signal.value = 3000.0;
                    assign fanCmdOut.signal.value = 1500.0;
                }
            }
            state faultMode {
                entry {
                    assign pumpCmdOut.signal.value = 0.0;
                    assign fanCmdOut.signal.value = 3000.0;
                }
            }

            transition standby to activeCooling {
                when tempIn.signal.value > targetTemp
            }
            transition activeCooling to standby {
                when tempIn.signal.value <= targetTemp
            }
            transition standby to faultMode {
                when levelIn.signal.value < minLevel or tempIn.signal.value > criticalTemp
            }
            transition activeCooling to faultMode {
                when levelIn.signal.value < minLevel or tempIn.signal.value > criticalTemp
            }
            transition faultMode to standby {
                when levelIn.signal.value >= minLevel and tempIn.signal.value <= targetTemp
            }
        }
    }

    requirement def SafeOperationRequirement {
        subject sys : AutomatedLiquidCoolingSystem;
        constraint { sys.controller.tempIn.signal.value <= sys.controller.criticalTemp }
    }

    requirement def FlowRequirement {
        subject sys : AutomatedLiquidCoolingSystem;
        constraint { sys.flowSensor.measuredFlow > 0.0 }
    }

    part def AutomatedLiquidCoolingSystem {
        part heatSource : HeatGeneratingComponent {
            attribute heatOutput = 250.0 [W];
        }
        part waterBlock : WaterBlock;
        part pump : CoolantPump;
        part radiator : Radiator;
        part fan : CoolingFan;
        part reservoir : CoolantReservoir {
            attribute currentLevel = 95.0;
        }
        part controller : SystemController;
        part tempSensor : TemperatureSensor {
            attribute measuredTemp = 55.0 [degC];
        }
        part flowSensor : FlowSensor {
            attribute measuredFlow = 2.5 [L/min];
        }

        connect waterBlock.liquidOut to pump.liquidIn;
        connect pump.liquidOut to radiator.liquidIn;
        connect radiator.liquidOut to reservoir.liquidIn;
        connect reservoir.liquidOut to waterBlock.liquidIn;

        connect fan.airOut to radiator.airIn;

        connect tempSensor.tempOut to controller.tempIn;
        connect flowSensor.flowOut to controller.flowIn;
        connect reservoir.levelOut to controller.levelIn;
        connect controller.pumpCmdOut to pump.speedIn;
        connect controller.fanCmdOut to fan.speedIn;
    }
}

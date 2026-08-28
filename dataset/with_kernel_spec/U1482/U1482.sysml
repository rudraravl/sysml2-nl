package RefrigerationSystem {
    private import ScalarValues::Real;

    attribute def Temperature :> Real { unit K; }
    attribute def Pressure :> Real { unit Pa; }
    attribute def Power :> Real { unit W; }
    attribute def Speed :> Real { unit rpm; }
    attribute def HeatFlowRate :> Real { unit W; }
    attribute def Duration :> Real { unit h; }

    enum def Phase {
        enum vapor;
        enum liquid;
        enum mixture;
    }

    item def Refrigerant {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute phase : Phase;
    }
    item def TempReading {
        attribute value : Temperature;
    }
    item def SpeedCommand {
        attribute targetSpeed : Speed;
    }
    item def HeaterCommand {
        attribute powerLevel : Power;
    }
    item def PowerOn;
    item def PowerOff;

    port def RefrigerantPort {
        inout refrigerant : Refrigerant;
    }
    port def PowerPort {
        inout power : Power;
    }
    port def ControlPort {
        inout command : SpeedCommand;
    }
    port def HeaterControlPort {
        inout command : HeaterCommand;
    }
    port def TempSensorPort {
        inout reading : TempReading;
    }
    port def HeatPort {
        inout heatFlow : HeatFlowRate;
    }

    part def Compressor {
        port refrigerantIn : RefrigerantPort;
        port refrigerantOut : RefrigerantPort;
        port powerIn : PowerPort;
        port controlIn : ControlPort;
    }

    part def Condenser {
        port refrigerantIn : RefrigerantPort;
        port refrigerantOut : RefrigerantPort;
        port heatOut : HeatPort;
    }

    part def ExpansionValve {
        port refrigerantIn : RefrigerantPort;
        port refrigerantOut : RefrigerantPort;
    }

    part def Evaporator {
        port refrigerantIn : RefrigerantPort;
        port refrigerantOut : RefrigerantPort;
        port heatIn : HeatPort;
    }

    part def TemperatureSensor {
        port readingOut : TempSensorPort;
    }

    part def DefrostHeater {
        port controlIn : HeaterControlPort;
    }

    part def Controller {
        port sensorIn : TempSensorPort;
        port compressorOut : ControlPort;
        port heaterOut : HeaterControlPort;
        port powerIn : PowerPort;

        attribute setpoint : Temperature = 277.15;
        attribute hysteresis : Temperature = 1.0;
        attribute nominalSpeed : Speed = 1500.0;
        attribute defrostInterval : Duration = 6.0;
        attribute defrostDuration : Duration = 0.5;

        state def controllerState {
            entry; then Off;

            state Off {
                entry send new SpeedCommand(0.0) to compressorOut;
            }
            state Idle {
                entry send new SpeedCommand(0.0) to compressorOut;
            }
            state Cooling {
                do send new SpeedCommand(nominalSpeed) to compressorOut;
            }
            state Defrost {
                entry send new SpeedCommand(0.0) to compressorOut;
                entry send new HeaterCommand(100.0) to heaterOut;
                exit send new HeaterCommand(0.0) to heaterOut;
            }

            transition first Off accept PowerOn then Idle;
            transition first Idle accept t : TempReading via sensorIn if t.value > setpoint + hysteresis then Cooling;
            transition first Cooling accept t : TempReading via sensorIn if t.value <= setpoint then Idle;
            transition first Cooling after defrostInterval then Defrost;
            transition first Defrost after defrostDuration then Idle;
            transition first Off accept PowerOff then Off;
            transition first Idle accept PowerOff then Off;
            transition first Cooling accept PowerOff then Off;
            transition first Defrost accept PowerOff then Off;
        }
    }

    part def Compartment {
        port heatOut : HeatPort;
        attribute interiorTemp : Temperature;
    }

    part def Environment {
        port heatIn : HeatPort;
    }

    part def PowerSource {
        port powerOut : PowerPort;
    }

    part def RefrigerationSystem {
        part compressor : Compressor;
        part condenser : Condenser;
        part expansionValve : ExpansionValve;
        part evaporator : Evaporator;
        part tempSensor : TemperatureSensor;
        part controller : Controller;
        part defrostHeater : DefrostHeater;
        part compartment : Compartment;
        part environment : Environment;
        part powerSource : PowerSource;

        flow compToCond of Refrigerant
            from compressor.refrigerantOut.refrigerant to condenser.refrigerantIn.refrigerant;
        flow condToValve of Refrigerant
            from condenser.refrigerantOut.refrigerant to expansionValve.refrigerantIn.refrigerant;
        flow valveToEvap of Refrigerant
            from expansionValve.refrigerantOut.refrigerant to evaporator.refrigerantIn.refrigerant;
        flow evapToComp of Refrigerant
            from evaporator.refrigerantOut.refrigerant to compressor.refrigerantIn.refrigerant;

        flow compartmentToEvap of HeatFlowRate
            from compartment.heatOut.heatFlow to evaporator.heatIn.heatFlow;
        flow condToEnv of HeatFlowRate
            from condenser.heatOut.heatFlow to environment.heatIn.heatFlow;

        flow sensorToCtrl of TempReading
            from tempSensor.readingOut.reading to controller.sensorIn.reading;
        flow ctrlToComp of SpeedCommand
            from controller.compressorOut.command to compressor.controlIn.command;
        flow ctrlToHeater of HeaterCommand
            from controller.heaterOut.command to defrostHeater.controlIn.command;

        flow powerToComp of Power
            from powerSource.powerOut.power to compressor.powerIn.power;
        flow powerToCtrl of Power
            from powerSource.powerOut.power to controller.powerIn.power;
    }

    requirement def CoolingCapacity {
        subject system : RefrigerationSystem;
        attribute requiredCapacity : HeatFlowRate = 500.0;
        attribute actualCapacity : HeatFlowRate;
        require actualCapacity >= requiredCapacity;
    }

    requirement def TemperatureControl {
        subject system : RefrigerationSystem;
        attribute targetSetpoint : Temperature = 277.15;
        attribute tolerance : Temperature = 1.0;
        attribute actualTemp : Temperature;
        require actualTemp >= targetSetpoint - tolerance and actualTemp <= targetSetpoint + tolerance;
    }

    requirement def EnergyEfficiency {
        subject system : RefrigerationSystem;
        attribute minCOP : Real = 3.0;
        attribute actualCOP : Real;
        require actualCOP >= minCOP;
    }

    requirement def SafeOperatingLimits {
        subject system : RefrigerationSystem;
        attribute maxPressure : Pressure = 2500000.0;
        attribute minTemp : Temperature = 233.15;
        attribute maxTemp : Temperature = 393.15;
        attribute actualPressure : Pressure;
        attribute actualRefrigerantTemp : Temperature;
        require actualPressure <= maxPressure;
        require actualRefrigerantTemp >= minTemp and actualRefrigerantTemp <= maxTemp;
    }

    part refrigerationSystem : RefrigerationSystem;

    satisfy CoolingCapacity by refrigerationSystem;
    satisfy TemperatureControl by refrigerationSystem;
    satisfy EnergyEfficiency by refrigerationSystem;
    satisfy SafeOperatingLimits by refrigerationSystem;
}

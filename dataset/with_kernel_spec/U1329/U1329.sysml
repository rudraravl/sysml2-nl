package DaikinInverterAC {
    
    attribute def Temperature :> Real;
    attribute def Humidity :> Real;
    attribute def FanSpeed :> Real;
    attribute def CompressorFrequency :> Real;
    
    enum def OperatingMode { cooling; heating; dehumidifying; fanOnly; auto; }
    
    item def Air {
        attribute temperature : Temperature;
        attribute humidity : Humidity;
    }
    item def Refrigerant;
    
    item def UserCommand {
        attribute setTemperature : Temperature;
        attribute mode : OperatingMode;
        attribute setFanSpeed : FanSpeed;
    }
    
    item def ControlSignal {
        attribute compressorFrequency : CompressorFrequency;
        attribute indoorFanSpeed : FanSpeed;
        attribute outdoorFanSpeed : FanSpeed;
        attribute expansionValvePosition : Real;
        attribute reversingValveEngaged : Boolean;
    }
    
    part def User {
        port cmdPort {
            out cmd : UserCommand;
        }
    }
    
    part def Compressor {
        port inPort {
            in refrigerant : Refrigerant;
        }
        port outPort {
            out refrigerant : Refrigerant;
        }
        attribute frequency : CompressorFrequency;
    }
    
    part def HeatExchanger {
        port refIn {
            in refrigerant : Refrigerant;
        }
        port refOut {
            out refrigerant : Refrigerant;
        }
        port airIn {
            in air : Air;
        }
        port airOut {
            out air : Air;
        }
    }
    
    part def ExpansionValve {
        port refIn {
            in refrigerant : Refrigerant;
        }
        port refOut {
            out refrigerant : Refrigerant;
        }
        attribute position : Real;
    }
    
    part def Fan {
        port airIn {
            in air : Air;
        }
        port airOut {
            out air : Air;
        }
        attribute speed : FanSpeed;
    }
    
    part def Blower :> Fan {
        attribute speedLevels : Integer;
    }
    
    part def Sensor {
        port airIn {
            in air : Air;
        }
        port airOut {
            out air : Air;
        }
        attribute temperature : Temperature;
        attribute humidity : Humidity;
    }
    
    part def OutdoorUnit {
        port ctrlPort {
            in signal : ControlSignal;
        }
        port liquidPort {
            out liquid : Refrigerant;
        }
        port gasPort {
            in gas : Refrigerant;
        }
        port airInPort {
            in outsideAirIn : Air;
        }
        port airOutPort {
            out outsideAirOut : Air;
        }
        
        part compressor : Compressor;
        part condenser : HeatExchanger;
        part outdoorFan : Fan;
        
        flow gasToComp of Refrigerant from gasPort.gas to compressor.inPort.refrigerant;
        flow compToCondenser of Refrigerant from compressor.outPort.refrigerant to condenser.refIn.refrigerant;
        flow condToLiquid of Refrigerant from condenser.refOut.refrigerant to liquidPort.liquid;
        
        flow airToFan of Air from airInPort.outsideAirIn to outdoorFan.airIn.air;
        flow airToCondenser of Air from outdoorFan.airOut.air to condenser.airIn.air;
        flow airToOutside of Air from condenser.airOut.air to airOutPort.outsideAirOut;
    }
    
    part def IndoorUnit {
        port ctrlPort {
            in signal : ControlSignal;
        }
        port liquidPort {
            in liquid : Refrigerant;
        }
        port gasPort {
            out gas : Refrigerant;
        }
        port airInPort {
            in roomAirIn : Air;
        }
        port airOutPort {
            out roomAirOut : Air;
        }
        port sensorPort {
            out roomAir : Air;
        }
        
        part expansionValve : ExpansionValve;
        part evaporator : HeatExchanger;
        part indoorFan : Blower;
        part sensor : Sensor;
        
        flow liquidToValve of Refrigerant from liquidPort.liquid to expansionValve.refIn.refrigerant;
        flow valveToEvap of Refrigerant from expansionValve.refOut.refrigerant to evaporator.refIn.refrigerant;
        flow evapToGas of Refrigerant from evaporator.refOut.refrigerant to gasPort.gas;
        
        flow airToEvap of Air from airInPort.roomAirIn to evaporator.airIn.air;
        flow airToFan of Air from evaporator.airOut.air to indoorFan.airIn.air;
        flow airToRoom of Air from indoorFan.airOut.air to airOutPort.roomAirOut;
        
        flow airToSensor of Air from airInPort.roomAirIn to sensor.airIn.air;
        flow sensedAir of Air from sensor.airOut.air to sensorPort.roomAir;
    }
    
    part def InverterController {
        port cmdPort {
            in cmd : UserCommand;
        }
        port sensorPort {
            in roomAir : Air;
        }
        port indoorCtrlPort {
            out signal : ControlSignal;
        }
        port outdoorCtrlPort {
            out signal : ControlSignal;
        }
        
        action computeControl {
            in cmd : UserCommand;
            in roomAir : Air;
            out signal : ControlSignal;
        }
        
        state def ControllerStates {
            state idle;
            state active;
            state cooling;
            state heating;
            state dehumidifying;
            state fanOnly;
            state auto;
            
            transition t1 from idle to active guard { cmd.setTemperature > 0 };
            transition t2 from active to cooling guard { cmd.mode == OperatingMode::cooling };
            transition t3 from active to heating guard { cmd.mode == OperatingMode::heating };
            transition t4 from active to dehumidifying guard { cmd.mode == OperatingMode::dehumidifying };
            transition t5 from active to fanOnly guard { cmd.mode == OperatingMode::fanOnly };
            transition t6 from active to auto guard { cmd.mode == OperatingMode::auto };
        }
    }
    
    part def DaikinInverterACSystem {
        attribute desiredTemp : Temperature;
        attribute desiredMode : OperatingMode;
        attribute desiredFanSpeed : FanSpeed;
        
        part user : User;
        part controller : InverterController;
        part outdoorUnit : OutdoorUnit;
        part indoorUnit : IndoorUnit;
        
        flow userCmdFlow of UserCommand from user.cmdPort.cmd to controller.cmdPort.cmd;
        flow sensorFlow of Air from indoorUnit.sensorPort.roomAir to controller.sensorPort.roomAir;
        flow indoorCtrlFlow of ControlSignal from controller.indoorCtrlPort.signal to indoorUnit.ctrlPort.signal;
        flow outdoorCtrlFlow of ControlSignal from controller.outdoorCtrlPort.signal to outdoorUnit.ctrlPort.signal;
        
        flow liquidLine of Refrigerant from outdoorUnit.liquidPort.liquid to indoorUnit.liquidPort.liquid;
        flow gasLine of Refrigerant from indoorUnit.gasPort.gas to outdoorUnit.gasPort.gas;
    }
    
    requirement def TempControlReq {
        doc /* The system shall maintain room temperature within +/- 1 degree of the set temperature. */
        attribute setTemp : Temperature;
        attribute actualTemp : Temperature;
        require constraint { abs(actualTemp - setTemp) <= 1 }
    }
    
    requirement def DehumidificationReq {
        doc /* The system shall remove moisture from the air in dehumidifying mode. */
        attribute actualHumidity : Humidity;
        attribute targetHumidity : Humidity;
        require constraint { actualHumidity <= targetHumidity }
    }
    
    requirement def EnergyEfficiencyReq {
        doc /* The inverter compressor shall adjust speed to match demand for energy efficiency. */
        attribute frequency : CompressorFrequency;
        attribute demand : Real;
        require constraint { frequency == demand }
    }
}

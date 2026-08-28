package PapooseBoard {
    attribute def Voltage :> ScalarValues::Real;
    attribute def Current :> ScalarValues::Real;
    attribute def Temperature :> ScalarValues::Real;
    attribute def Pressure :> ScalarValues::Real;
    attribute def Position :> ScalarValues::Real;
    attribute def MotorSpeed :> ScalarValues::Real;
    attribute def ValvePosition :> ScalarValues::Real;

    attribute def StartCommand;
    attribute def ResetCommand;
    attribute def OverloadSignal;
    attribute def FaultSignal;

    attribute def SensorData {
        temp : Temperature;
        pres : Pressure;
        pos : Position;
    }
    attribute def ActuatorCommand {
        speed : MotorSpeed;
        valve : ValvePosition;
    }
    attribute def StatusPacket {
        currentState : ScalarValues::String;
        data : SensorData;
        cmd : ActuatorCommand;
    }
    attribute def ControlCommand {
        target : ScalarValues::String;
        param : ScalarValues::Real;
    }

    port def PowerInPort { in voltage : Voltage; }
    port def PowerOutPort { out voltage : Voltage; }
    port def DataInPort { in data : ScalarValues::Any; }
    port def DataOutPort { out data : ScalarValues::Any; }

    action def AcquireData {
        out data : SensorData;
    }
    action def ProcessData {
        in raw : SensorData;
        out command : ActuatorCommand;
        out status : StatusPacket;
    }
    action def DriveActuator {
        in cmd : ActuatorCommand;
    }
    action def TransmitStatus {
        in status : StatusPacket;
    }
    action def ControlLoop {
        first start;
        then merge loopStart;
        then action acquire : AcquireData;
        then action process : ProcessData {
            in raw = acquire.data;
        }
        then action drive : DriveActuator {
            in cmd = process.command;
        }
        then action transmit : TransmitStatus {
            in status = process.status;
        }
        then loopStart;
    }

    part def Microcontroller {
        port sensorDataIn : DataInPort;
        port actuatorCmdOut : DataOutPort;
        port commDataIn : DataInPort;
        port commDataOut : DataOutPort;
        port powerIn : PowerInPort;
    }

    part def PowerRegulator {
        port extPowerIn : PowerInPort;
        port mcuPowerOut : PowerOutPort;
        port sensorPowerOut : PowerOutPort;
        port actuatorPowerOut : PowerOutPort;
        port commPowerOut : PowerOutPort;
        
        attribute outputVoltage : Voltage = 3.3;
        attribute maxCurrent : Current = 5.0;
        attribute current : Current;
        attribute overload : ScalarValues::Boolean = false;
        
        state def RegulatorStates {
            entry; then off;
            state off;
            accept StartCommand then starting;
            state starting;
            transition first starting then on;
            state on;
            accept OverloadSignal then protection;
            state protection;
            accept ResetCommand then off;
        }
        
        state regState : RegulatorStates;
    }

    part def SensorArray {
        port powerIn : PowerInPort;
        port dataOut : DataOutPort;
    }

    part def ActuatorController {
        port powerIn : PowerInPort;
        port commandIn : DataInPort;
        port hardwareOut : DataOutPort;
    }

    part def CommunicationModule {
        port powerIn : PowerInPort;
        port mcuDataIn : DataInPort;
        port mcuDataOut : DataOutPort;
        port extDataIn : DataInPort;
        port extDataOut : DataOutPort;
    }

    part def PapooseBoard {
        port extPower : PowerInPort;
        port extCommIn : DataInPort;
        port extCommOut : DataOutPort;
        
        part powerRegulator : PowerRegulator;
        part microcontroller : Microcontroller;
        part sensorArray : SensorArray;
        part actuatorController : ActuatorController;
        part commModule : CommunicationModule;
        
        connect extPower to powerRegulator.extPowerIn;
        connect powerRegulator.mcuPowerOut to microcontroller.powerIn;
        connect powerRegulator.sensorPowerOut to sensorArray.powerIn;
        connect powerRegulator.actuatorPowerOut to actuatorController.powerIn;
        connect powerRegulator.commPowerOut to commModule.powerIn;
        
        connect sensorArray.dataOut to microcontroller.sensorDataIn;
        connect microcontroller.actuatorCmdOut to actuatorController.commandIn;
        connect microcontroller.commDataOut to commModule.mcuDataIn;
        connect commModule.mcuDataOut to microcontroller.commDataIn;
        
        connect extCommIn to commModule.extDataIn;
        connect commModule.extDataOut to extCommOut;
        
        state def SystemStates {
            entry; then off;
            state off;
            accept StartCommand then active;
            state active {
                do action controlLoop : ControlLoop;
            }
            accept OverloadSignal then fault;
            accept FaultSignal then fault;
            state fault;
            accept ResetCommand then off;
        }
        
        state boardState : SystemStates;
    }

    requirement def RealTimeControl {
        doc /* The board shall process sensor data and send actuator commands within 10 ms. */
    }
    requirement def OverloadProtection {
        doc /* The power regulator shall enter overload protection if current exceeds 5 A. */
    }
    requirement def FaultRecovery {
        doc /* The system shall enter a fault state upon error detection and halt the control loop until reset. */
    }
    
    satisfy RealTimeControl by PapooseBoard;
    satisfy OverloadProtection by PowerRegulator;
    satisfy FaultRecovery by PapooseBoard;
}

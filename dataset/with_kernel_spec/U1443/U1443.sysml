package 'LiquidMetalThermalManagementSystem' {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    
    unit def Kelvin;
    unit def Watt;
    unit def RPM;
    unit def Liter;
    
    value def Temperature : Real { unit :>> Kelvin; }
    value def PumpSpeed : Real { unit :>> RPM; }
    value def HeatPower : Real { unit :>> Watt; }
    value def Volume : Real { unit :>> Liter; }
    value def Setpoint : Temperature;
    
    item def NaK;
    item def Heat;
    item def TempReading {
        attribute temp : Temperature;
    }
    item def SpeedCommand {
        attribute speed : PumpSpeed;
    }
    
    port def CoolantOutPort {
        out item naK : NaK;
    }
    port def CoolantInPort {
        in item naK : NaK;
    }
    port def HeatOutPort {
        out item heat : Heat;
    }
    port def HeatInPort {
        in item heat : Heat;
    }
    port def DataOutPort {
        out item reading : TempReading;
    }
    port def DataInPort {
        in item reading : TempReading;
    }
    port def ControlOutPort {
        out item command : SpeedCommand;
    }
    port def ControlInPort {
        in item command : SpeedCommand;
    }
    
    part def HeatSource {
        port heatOut : HeatOutPort;
        attribute power : HeatPower;
    }
    
    part def ColdPlate {
        port heatIn : HeatInPort;
        port coolIn : CoolantInPort;
        port coolOut : CoolantOutPort;
    }
    
    part def ElectromagneticPump {
        port pumpIn : CoolantInPort;
        port pumpOut : CoolantOutPort;
        port controlIn : ControlInPort;
        attribute currentSpeed : PumpSpeed;
        
        action def CirculateCoolant {
            in naKIn : NaK;
            in command : SpeedCommand;
            out naKOut : NaK;
        }
        
        action circulate : CirculateCoolant {
            in naKIn = pumpIn.naK;
            in command = controlIn.command;
            out naKOut = pumpOut.naK;
        }
    }
    
    part def Radiator {
        port radIn : CoolantInPort;
        port radOut : CoolantOutPort;
        port ambientOut : HeatOutPort;
    }
    
    part def ExpansionTank {
        port tankIn : CoolantInPort;
        port tankOut : CoolantOutPort;
        attribute maxVolume : Volume;
    }
    
    part def TemperatureSensor {
        port sensorIn : CoolantInPort;
        port sensorOut : CoolantOutPort;
        port dataOut : DataOutPort;
        
        action def ReadTemp {
            in naKIn : NaK;
            out naKOut : NaK;
            out reading : TempReading;
        }
        
        action read : ReadTemp {
            in naKIn = sensorIn.naK;
            out naKOut = sensorOut.naK;
            out reading = dataOut.reading;
        }
    }
    
    part def SystemController {
        port dataIn : DataInPort;
        port controlOut : ControlOutPort;
        attribute targetTemp : Setpoint;
        attribute criticalTemp : Temperature;
        attribute highLoadTemp : Temperature;
        
        action def RegulateTemp {
            in currentReading : TempReading;
            out command : SpeedCommand;
        }
        
        action regulate : RegulateTemp {
            in currentReading = dataIn.reading;
            out command = controlOut.command;
        }
    }
    
    part def AmbientEnvironment {
        port ambientIn : HeatInPort;
    }
    
    state machine def ThermalControlSM {
        state standby;
        state startup;
        state normalOperation;
        state highLoad;
        state emergency;
        state controlledShutdown;
        
        transition standby to startup when startSignal;
        transition startup to normalOperation when flowStable;
        transition normalOperation to highLoad when currentTemp >= controller.highLoadTemp;
        transition highLoad to normalOperation when currentTemp < controller.highLoadTemp;
        transition normalOperation to emergency when currentTemp >= controller.criticalTemp;
        transition highLoad to emergency when currentTemp >= controller.criticalTemp;
        transition emergency to controlledShutdown when systemSafe;
        transition controlledShutdown to standby when resetSignal;
    }
    
    part def ThermalSystem {
        attribute currentTemp : Temperature;
        attribute startSignal : Boolean;
        attribute flowStable : Boolean;
        attribute systemSafe : Boolean;
        attribute resetSignal : Boolean;
        
        part heatSource : HeatSource;
        part coldPlate : ColdPlate;
        part emPump : ElectromagneticPump;
        part radiator : Radiator;
        part expansionTank : ExpansionTank;
        part tempSensor : TemperatureSensor;
        part controller : SystemController;
        part environment : AmbientEnvironment;
        
        flow of NaK from emPump.pumpOut.naK to coldPlate.coolIn.naK;
        flow of NaK from coldPlate.coolOut.naK to tempSensor.sensorIn.naK;
        flow of NaK from tempSensor.sensorOut.naK to radiator.radIn.naK;
        flow of NaK from radiator.radOut.naK to expansionTank.tankIn.naK;
        flow of NaK from expansionTank.tankOut.naK to emPump.pumpIn.naK;
        
        flow of Heat from heatSource.heatOut.heat to coldPlate.heatIn.heat;
        flow of Heat from radiator.ambientOut.heat to environment.ambientIn.heat;
        
        flow of TempReading from tempSensor.dataOut.reading to controller.dataIn.reading;
        flow of SpeedCommand from controller.controlOut.command to emPump.controlIn.command;
        
        state machine thermalStates : ThermalControlSM;
    }
    
    requirement def CoolingRequirement {
        doc "Maintain heat source temperature below critical limits using liquid metal.";
        subject system : ThermalSystem;
    }
    
    requirement def SafetyRequirement {
        doc "Enter emergency state and controlled shutdown if temperatures exceed safe limits.";
        subject system : ThermalSystem;
    }
    
    requirement coolingReq : CoolingRequirement;
    requirement safetyReq : SafetyRequirement;
}

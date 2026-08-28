package 'Automated Window Blind System' {
    private import ScalarValues::*;
    
    enum def DirectionKind { up; down; stop; }
    enum def ActionKind { raise; lower; stop; setTarget; toggleMode; }
    
    item def MotorCommand {
        attribute direction : DirectionKind;
    }
    
    item def UserCommand {
        attribute cmdAction : ActionKind;
        attribute targetLight : Real;
    }
    
    item def SmartHomeCommand {
        attribute cmdAction : ActionKind;
        attribute targetLight : Real;
    }
    
    item def ObstructionSignal {
        attribute detected : Boolean;
    }
    
    item def PowerStatus {
        attribute voltage : Real;
    }
    
    item def LightReading {
        attribute illuminance : Real;
    }
    
    part def PowerSupply {
        port powerOutController { out power : PowerStatus; }
        port powerOutMotor { out power : PowerStatus; }
        port powerOutSensor { out power : PowerStatus; }
    }
    
    part def AmbientLightSensor {
        port powerIn { in power : PowerStatus; }
        port lightOut { out lightReading : LightReading; }
        action senseLight {
            send new LightReading() to lightOut;
        }
    }
    
    part def Controller {
        attribute targetLightLevel : Real = 500;
        attribute mode : String = "auto";
        
        port powerIn { in power : PowerStatus; }
        port lightIn { in lightReading : LightReading; }
        port userIn { in userCommand : UserCommand; }
        port smartHomeIn { in smartHomeCommand : SmartHomeCommand; }
        port motorOut { out motorCommand : MotorCommand; }
        port obstructionIn { in obstruction : ObstructionSignal; }
        
        state machine {
            state idle;
            state raising;
            state lowering;
            state obstruction;
            
            transition idle_to_raising first idle 
                if (self.lightIn.lightReading.illuminance < self.targetLightLevel * 0.9 and self.mode == "auto")
                then raising;
            transition idle_to_lowering first idle 
                if (self.lightIn.lightReading.illuminance > self.targetLightLevel * 1.1 and self.mode == "auto")
                then lowering;
            transition raising_to_idle first raising 
                if (self.lightIn.lightReading.illuminance >= self.targetLightLevel * 0.95)
                then idle;
            transition lowering_to_idle first lowering 
                if (self.lightIn.lightReading.illuminance <= self.targetLightLevel * 1.05)
                then idle;
            transition raising_to_obstruction first raising 
                if (self.obstructionIn.obstruction.detected == true)
                then obstruction;
            transition lowering_to_obstruction first lowering 
                if (self.obstructionIn.obstruction.detected == true)
                then obstruction;
            transition obstruction_to_idle first obstruction 
                if (self.userIn.userCommand.cmdAction == ActionKind::stop)
                then idle;
            transition manual_raise first idle 
                if (self.userIn.userCommand.cmdAction == ActionKind::raise)
                then raising;
            transition manual_lower first idle 
                if (self.userIn.userCommand.cmdAction == ActionKind::lower)
                then lowering;
            transition manual_stop_raising first raising 
                if (self.userIn.userCommand.cmdAction == ActionKind::stop)
                then idle;
            transition manual_stop_lowering first lowering 
                if (self.userIn.userCommand.cmdAction == ActionKind::stop)
                then idle;
        }
    }
    
    part def ElectricMotor {
        port powerIn { in power : PowerStatus; }
        port motorIn { in motorCommand : MotorCommand; }
        port torqueOut { out torque : Real; }
        port obstructionOut { out obstruction : ObstructionSignal; }
        attribute maxTorque : Real = 5;
        
        action drive {
            accept MotorCommand via motorIn;
        }
    }
    
    part def MechanicalLiftMechanism {
        port torqueIn { in torque : Real; }
        port forceOut { out liftingForce : Real; }
        part drum;
        part cord;
        part gear;
    }
    
    part def SlatAssembly {
        port forceIn { in liftingForce : Real; }
        attribute position : Real = 0;
    }
    
    part def User {
        port commandOut { out userCommand : UserCommand; }
    }
    
    part def SmartHomeSystem {
        port commandOut { out smartHomeCommand : SmartHomeCommand; }
    }
    
    part def AutomatedWindowBlindSystem {
        part powerSupply : PowerSupply;
        part sensor : AmbientLightSensor;
        part controller : Controller;
        part motor : ElectricMotor;
        part liftMechanism : MechanicalLiftMechanism;
        part slatAssembly : SlatAssembly;
        part user : User;
        part smartHome : SmartHomeSystem;
        
        interface powerInterfaceController connect powerSupply.powerOutController to controller.powerIn;
        interface powerInterfaceMotor connect powerSupply.powerOutMotor to motor.powerIn;
        interface powerInterfaceSensor connect powerSupply.powerOutSensor to sensor.powerIn;
        interface sensorInterface connect sensor.lightOut to controller.lightIn;
        interface userInterface connect user.commandOut to controller.userIn;
        interface smartHomeInterface connect smartHome.commandOut to controller.smartHomeIn;
        interface motorInterface connect controller.motorOut to motor.motorIn;
        interface obstructionInterface connect motor.obstructionOut to controller.obstructionIn;
        interface liftInterface connect motor.torqueOut to liftMechanism.torqueIn;
        interface slatInterface connect liftMechanism.forceOut to slatAssembly.forceIn;
    }
    
    requirement def MaintainAmbientLight {
        doc /* The system shall automatically adjust the blind slats to maintain the ambient light level within +/- 10% of the user-defined target illuminance. */
        subject system : AutomatedWindowBlindSystem;
    }
    
    requirement def ManualOverride {
        doc /* The user shall be able to manually raise or lower the blinds at any time, overriding automatic control. */
        subject system : AutomatedWindowBlindSystem;
    }
    
    requirement def SafetyFeatures {
        doc /* The system shall detect an obstruction during movement and immediately stop the motor, limiting force to 150 N. */
        subject system : AutomatedWindowBlindSystem;
    }
    
    requirement def PerformanceGoals {
        doc /* The blind shall move from fully open to fully closed in under 10 seconds. */
        subject system : AutomatedWindowBlindSystem;
    }
    
    requirement def SmartHomeIntegration {
        doc /* The system shall provide a network interface for integration with building automation systems. */
        subject system : AutomatedWindowBlindSystem;
    }
}

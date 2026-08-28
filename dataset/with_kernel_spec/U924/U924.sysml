package TransmissionControlSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    enum def DriveMode { Eco; Sport; }
    enum def Gear { Park; Reverse; Neutral; D1; D2; D3; D4; D5; D6; D7; D8; }
    
    attribute def VehicleSpeed :> ISQ::speed;
    attribute def EngineRPM :> Real;
    attribute def ThrottlePosition :> Real;
    attribute def FluidTemp :> ISQ::temperature;
    
    item def SensorUpdate;
    
    item def ShiftCommand {
        attribute targetGear : Gear;
        attribute hydraulicPressure : ISQ::pressure;
        attribute clutchTiming : ISQ::time;
    }
    
    item def ShiftFeedback {
        attribute shiftComplete : Boolean;
        attribute actualGear : Gear;
    }
    
    port def SpeedOutPort { out speed : VehicleSpeed; }
    port def RPMOutPort { out rpm : EngineRPM; }
    port def ThrottleOutPort { out throttle : ThrottlePosition; }
    port def GearOutPort { out gear : Gear; }
    port def TempOutPort { out temp : FluidTemp; }
    
    port def CommandOutPort { out command : ShiftCommand; }
    port def FeedbackOutPort { out feedback : ShiftFeedback; }
    
    part def SpeedSensor {
        port outPort : SpeedOutPort;
    }
    part def RPMSensor {
        port outPort : RPMOutPort;
    }
    part def ThrottleSensor {
        port outPort : ThrottleOutPort;
    }
    part def GearSensor {
        port outPort : GearOutPort;
    }
    part def TempSensor {
        port outPort : TempOutPort;
    }
    
    part def ClutchActuator {
        port inPort { in command : ShiftCommand; }
    }
    
    part def HydraulicSystem {
        port inPort { in command : ShiftCommand; }
    }
    
    part def TransmissionAssembly {
        port cmdInPort { in command : ShiftCommand; }
        port fbOutPort : FeedbackOutPort;
        part hydraulic : HydraulicSystem;
        part clutch : ClutchActuator;
    }
    
    part def TransmissionControlUnit {
        attribute selectedMode : DriveMode;
        
        port speedInPort { in speed : VehicleSpeed; }
        port rpmInPort { in rpm : EngineRPM; }
        port throttleInPort { in throttle : ThrottlePosition; }
        port gearInPort { in gear : Gear; }
        port tempInPort { in temp : FluidTemp; }
        
        port cmdOutPort : CommandOutPort;
        port fbInPort { in feedback : ShiftFeedback; }
        
        perform action readSensors;
        perform action analyzeDriving;
        perform action calculateShiftParams;
        perform action executeShift;
        perform action confirmCompletion;
        
        exhibit state tcuStates {
            entry; then monitoring;
            
            state monitoring {
                do readSensors;
            }
            state analyzing {
                do analyzeDriving;
            }
            state calculating {
                do calculateShiftParams;
            }
            state executing {
                do executeShift;
            }
            state confirming {
                do confirmCompletion;
            }
            
            transition monitoring_to_analyzing
                first monitoring
                accept speed : VehicleSpeed via speedInPort
                then analyzing;
                
            transition analyzing_to_calculating
                first analyzing
                then calculating;
                
            transition calculating_to_executing
                first calculating
                then executing;
                
            transition executing_to_confirming
                first executing
                then confirming;
                
            transition confirming_to_monitoring
                first confirming
                accept feedback : ShiftFeedback via fbInPort
                if feedback.shiftComplete
                then monitoring;
        }
    }
    
    part def Vehicle {
        part tcu : TransmissionControlUnit;
        part speedSensor : SpeedSensor;
        part rpmSensor : RPMSensor;
        part throttleSensor : ThrottleSensor;
        part gearSensor : GearSensor;
        part tempSensor : TempSensor;
        part transmission : TransmissionAssembly;
        
        flow speedFlow of VehicleSpeed from speedSensor.outPort.speed to tcu.speedInPort.speed;
        flow rpmFlow of EngineRPM from rpmSensor.outPort.rpm to tcu.rpmInPort.rpm;
        flow throttleFlow of ThrottlePosition from throttleSensor.outPort.throttle to tcu.throttleInPort.throttle;
        flow gearFlow of Gear from gearSensor.outPort.gear to tcu.gearInPort.gear;
        flow tempFlow of FluidTemp from tempSensor.outPort.temp to tcu.tempInPort.temp;
        
        flow cmdFlow of ShiftCommand from tcu.cmdOutPort.command to transmission.cmdInPort.command;
        flow fbFlow of ShiftFeedback from transmission.fbOutPort.feedback to tcu.fbInPort.feedback;
    }
    
    requirement def ShiftPerformanceRequirement {
        doc /* The gear shift must be completed within 0.8 seconds to minimize power interruption. */
        attribute maxShiftDuration : ISQ::time = 0.8[s];
        constraint { shiftDuration <= maxShiftDuration }
    }
    
    requirement shiftTimeReq : ShiftPerformanceRequirement;
}

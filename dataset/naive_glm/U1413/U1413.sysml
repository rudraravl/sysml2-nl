package AircraftFlapSystem {
    import ScalarValues::*;
    
    value def Angle :> Real { unit "deg"; }
    value def Area :> Real { unit "m^2"; }
    value def AngularSpeed :> Real { unit "deg/s"; }
    value def Frequency :> Real { unit "Hz"; }
    value def Pressure :> Real { unit "Pa"; }
    
    enum def FlapCommand { extend; retract; hold; }
    
    item def CommandSignal {
        attribute command : FlapCommand;
        attribute targetAngle : Angle;
    }
    
    item def PositionFeedback {
        attribute actualAngle : Angle;
    }
    
    item def HydraulicFluid;
    
    port def CommandPort {
        out item commandSignal : CommandSignal;
    }
    
    port def FeedbackPort {
        out item positionFeedback : PositionFeedback;
    }
    
    port def HydraulicPort {
        in item fluid : HydraulicFluid;
    }
    
    port def MechanicalPort {
        out attribute angle : Angle;
    }
    
    requirement def FlapSystemRequirements {
        doc "The hydraulically-powered flap system shall control the movable aerodynamic surface."
        requirement def SurfaceAreaRequirement {
            doc "The flap surface shall have an area of 8.5 square meters."
            attribute requiredArea : Area = 8.5;
        }
        requirement def DeflectionRangeRequirement {
            doc "The flap shall deflect from 0 to 40 degrees."
            attribute minDeflection : Angle = 0;
            attribute maxDeflection : Angle = 40;
        }
        requirement def ActuatorSpeedRequirement {
            doc "The actuator shall operate at speeds up to 15 degrees per second."
            attribute maxSpeed : AngularSpeed = 15;
        }
        requirement def SensorAccuracyRequirement {
            doc "The sensor shall measure angle with an accuracy of 0.5 degrees."
            attribute accuracy : Angle = 0.5;
        }
        requirement def SensorRateRequirement {
            doc "The sensor shall send feedback 50 times per second."
            attribute updateRate : Frequency = 50;
        }
    }
    
    part def FlapSurface {
        attribute area : Area = 8.5;
        attribute minDeflection : Angle = 0;
        attribute maxDeflection : Angle = 40;
        attribute currentAngle : Angle = 0;
        
        port mechanicalInterface : MechanicalPort;
        
        action def Deflect {
            in targetAngle : Angle;
            out newAngle : Angle;
        }
    }
    
    part def HydraulicActuator {
        attribute maxSpeed : AngularSpeed = 15;
        attribute operatingPressure : Pressure = 2.1e7;
        
        port hydraulicSupply : HydraulicPort;
        port commandInterface : CommandPort;
        port mechanicalOutput : MechanicalPort;
        
        action def Actuate {
            in command : CommandSignal;
            out actuationAngle : Angle;
        }
    }
    
    part def PositionSensor {
        attribute accuracy : Angle = 0.5;
        attribute updateRate : Frequency = 50;
        
        port mechanicalInput : MechanicalPort;
        port feedbackOutput : FeedbackPort;
        
        action def Measure {
            in mechanicalAngle : Angle;
            out feedback : PositionFeedback;
        }
    }
    
    part def FlapController {
        attribute updateRate : Frequency = 50;
        attribute commandedAngle : Angle;
        attribute actualAngle : Angle;
        attribute maxDeflection : Angle = 40;
        attribute minDeflection : Angle = 0;
        
        port pilotCommand : CommandPort;
        port sensorFeedback : FeedbackPort;
        port actuatorCommand : CommandPort;
        
        state machine def ControllerStateMachine {
            state retracted;
            state extending;
            state extended;
            state retracting;
            state holding;
            
            transition first Initial then retracted;
            
            transition first retracted 
                if pilotCommand.commandSignal.command == FlapCommand::extend 
                then extending;
                
            transition first extending 
                if actualAngle >= maxDeflection 
                then extended;
                
            transition first extending 
                if actualAngle >= commandedAngle 
                then holding;
                
            transition first extended 
                if pilotCommand.commandSignal.command == FlapCommand::retract 
                then retracting;
                
            transition first holding 
                if pilotCommand.commandSignal.command == FlapCommand::extend 
                then extending;
                
            transition first holding 
                if pilotCommand.commandSignal.command == FlapCommand::retract 
                then retracting;
                
            transition first retracting 
                if actualAngle <= minDeflection 
                then retracted;
                
            transition first retracting 
                if actualAngle <= commandedAngle 
                then holding;
        }
    }
    
    part def AircraftFlapSystem {
        part flapSurface : FlapSurface;
        part actuator : HydraulicActuator;
        part controller : FlapController;
        part sensor : PositionSensor;
        
        connection actuatorToFlap connect actuator.mechanicalOutput to flapSurface.mechanicalInterface;
        connection flapToSensor connect flapSurface.mechanicalInterface to sensor.mechanicalInput;
        connection sensorToController connect sensor.feedbackOutput to controller.sensorFeedback;
        connection controllerToActuator connect controller.actuatorCommand to actuator.commandInterface;
    }
    
    satisfy FlapSystemRequirements by AircraftFlapSystem;
}

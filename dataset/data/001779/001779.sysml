package 'Flap System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FlapPosition :> Real;
    attribute def FlapAngle :> ISQ::PlaneAngleValue;
    attribute def FlapSpeed :> ISQ::AngularVelocityValue;
    attribute def FlapLoad :> ISQ::ForceValue;
    attribute def FlapCommand;
    attribute def ExtendCommand :> FlapCommand;
    attribute def RetractCommand :> FlapCommand;
    attribute def HoldCommand :> FlapCommand;
    
    item def HydraulicFluid {
        attribute pressure : ISQ::PressureValue;
        attribute flowRate : ISQ::VolumeFlowRateValue;
    }
    
    port def HydraulicPort {
        in item hydraulicSupply : HydraulicFluid;
        out item hydraulicReturn : HydraulicFluid;
    }
    
    port def ControlPort {
        in flapCmd : FlapCommand;
        out flapPosition : FlapPosition;
        out flapAngle : FlapAngle;
    }
    
    part def FlapActuator {
        attribute maxExtensionRate : ISQ::AngularVelocityValue;
        attribute maxRetractionRate : ISQ::AngularVelocityValue;
        attribute maxLoad : ISQ::ForceValue;
        
        port hydraulicInterface : HydraulicPort;
        port controlInterface : ControlPort;
        
        perform action actuate {
            in command : FlapCommand;
            in hydraulicPower : HydraulicFluid;
            out position : FlapPosition;
            out angle : FlapAngle;
        }
    }
    
    part def FlapSurface {
        attribute surfaceArea : ISQ::AreaValue;
        attribute maxDeflection : FlapAngle;
        attribute minDeflection : FlapAngle;
        attribute currentAngle : FlapAngle;
        
        perform action deflect {
            in targetAngle : FlapAngle;
            in aerodynamicLoad : ISQ::ForceValue;
            out actualAngle : FlapAngle;
        }
    }
    
    part def PositionSensor {
        attribute accuracy : ISQ::PlaneAngleValue;
        attribute updateRate : ISQ::FrequencyValue;
        
        perform action sense {
            in physicalAngle : FlapAngle;
            out measuredAngle : FlapAngle;
            out measuredPosition : FlapPosition;
        }
    }
    
    part def FlapController {
        attribute commandedPosition : FlapPosition;
        attribute currentPosition : FlapPosition;
        attribute positionTolerance : Real;
        
        port commandInput : ControlPort;
        
        perform action controlFlap {
            in cmd : FlapCommand;
            in feedback : FlapPosition;
            out actuatorCommand : FlapCommand;
            out status : FlapPosition;
        }
    }
    
    action def ExtendFlap {
        in targetPosition : FlapPosition;
        in currentPosition : FlapPosition;
        out newPosition : FlapPosition;
    }
    
    action def RetractFlap {
        in targetPosition : FlapPosition;
        in currentPosition : FlapPosition;
        out newPosition : FlapPosition;
    }
    
    action def HoldFlap {
        in currentPosition : FlapPosition;
        out maintainedPosition : FlapPosition;
    }
    
    action def MonitorFlapPosition {
        in sensorReading : FlapPosition;
        out positionStatus : FlapPosition;
    }
    
    state def FlapOperationalStates {
        entry; then retracted;
        
        state retracted;
        
        state extending {
            do action extend : ExtendFlap;
        }
        
        state extended;
        
        state retracting {
            do action retract : RetractFlap;
        }
        
        state holding {
            do action hold : HoldFlap;
        }
        
        transition retracted_to_extending
            first retracted
            accept extendCmd : ExtendCommand
            then extending;
            
        transition extending_to_extended
            first extending
            if extend.newPosition >= 100.0
            then extended;
            
        transition extended_to_retracting
            first extended
            accept retractCmd : RetractCommand
            then retracting;
            
        transition retracting_to_retracted
            first retracting
            if retract.newPosition <= 0.0
            then retracted;
            
        transition any_to_holding
            first retracted
            accept holdCmd : HoldCommand
            then holding;
            
        transition holding_to_extending
            first holding
            accept extendCmd : ExtendCommand
            then extending;
            
        transition holding_to_retracting
            first holding
            accept retractCmd : RetractCommand
            then retracting;
    }
    
    part def FlapSystem {
        doc /*
            A flap system controls the deflection of aerodynamic control surfaces
            to modify lift and drag during takeoff, landing, and maneuvering.
        */
        
        part controller : FlapController;
        part actuator : FlapActuator;
        part surface : FlapSurface;
        part sensor : PositionSensor;
    }
    
    part flapSystem : FlapSystem {
        doc /* 
            The flap system provides controlled aerodynamic surface deflection
            to modify aircraft lift and drag characteristics during different
            flight phases. The system extends and retracts the flap surface
            through hydraulic actuation based on pilot commands.
        */
        
        part controller : FlapController {
            attribute :>> commandedPosition = 0.0;
            attribute :>> currentPosition = 0.0;
            attribute :>> positionTolerance = 2.0;
        }
        
        part actuator : FlapActuator {
            attribute :>> maxExtensionRate = 15.0 [SI::'°/s'];
            attribute :>> maxRetractionRate = 15.0 [SI::'°/s'];
            attribute :>> maxLoad = 50000.0 [SI::N];
        }
        
        part surface : FlapSurface {
            attribute :>> surfaceArea = 8.5 [SI::m^2];
            attribute :>> maxDeflection = 40.0 [SI::'°'];
            attribute :>> minDeflection = 0.0 [SI::'°'];
            attribute :>> currentAngle = 0.0 [SI::'°'];
        }
        
        part sensor : PositionSensor {
            attribute :>> accuracy = 0.5 [SI::'°'];
            attribute :>> updateRate = 50.0 [SI::Hz];
        }
        
        part hydraulicSupply {
            attribute supplyPressure : ISQ::PressureValue = 3000.0 [SI::psi];
        }
        
        connect controller.commandInput to actuator.controlInterface;
        connect actuator.hydraulicInterface to hydraulicSupply;
        
        perform action operateFlap {
            first start;
            then merge checkCommand;
            
            action monitor : MonitorFlapPosition {
                in sensorReading = sensor.sense.measuredPosition;
                out positionStatus;
            }
            
            then checkCommand;
            then decide;
                if monitor.positionStatus < controller.commandedPosition then extending;
                if monitor.positionStatus > controller.commandedPosition then retracting;
                if monitor.positionStatus == controller.commandedPosition then holding;
            
            action extending : ExtendFlap {
                in targetPosition = controller.commandedPosition;
                in currentPosition = monitor.positionStatus;
                out newPosition;
            }
            then checkCommand;
            
            action retracting : RetractFlap {
                in targetPosition = controller.commandedPosition;
                in currentPosition = monitor.positionStatus;
                out newPosition;
            }
            then checkCommand;
            
            action holding : HoldFlap {
                in currentPosition = monitor.positionStatus;
                out maintainedPosition;
            }
            then checkCommand;
        }
        
        exhibit state flapStates : FlapOperationalStates;
    }
    
    requirement def FlapPerformanceRequirement {
        doc /* The flap system shall meet specified performance criteria. */
        
        subject flapSubject : FlapSystem;
        
        require constraint extensionTime {
            doc /* The flap shall extend from 0 to maximum deflection within specified time. */
        }
        
        require constraint retractionTime {
            doc /* The flap shall retract from maximum to 0 deflection within specified time. */
        }
        
        require constraint positionAccuracy {
            doc /* The flap position shall be maintained within tolerance of commanded position. */
        }
    }
    
    requirement <'FLAP-001'> flapSystemRequirement : FlapPerformanceRequirement {
        doc /* 
            The flap system shall provide controlled aerodynamic surface deflection
            with specified accuracy and response time to support safe aircraft operations.
        */
        
        subject flapSubject = flapSystem;
        
        require constraint :>> extensionTime {
            0.0 <= flapSystem.surface.currentAngle and 
            flapSystem.surface.currentAngle <= flapSystem.surface.maxDeflection
        }
        
        require constraint :>> positionAccuracy {
            abs(flapSystem.controller.currentPosition - flapSystem.controller.commandedPosition) 
                <= flapSystem.controller.positionTolerance
        }
    }
}

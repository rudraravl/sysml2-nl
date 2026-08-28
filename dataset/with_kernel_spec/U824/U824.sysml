package PitometerLog {
    private import ScalarValues::*;
    private import ISQ::*;
    
    item def PressureDifference :> PressureValue;
    item def ElectricalSignal :> Real;
    item def SpeedThroughWater :> SpeedValue;
    item def AccumulatedDistance :> LengthValue;
    
    calc def BernoulliSpeed {
        in deltaP : PressureDifference;
        in rho : Real;
        in k : Real;
        return speed : SpeedThroughWater;
    }
    
    calc def IntegrateDistance {
        in speed : SpeedThroughWater;
        in dt : DurationValue;
        in prevDistance : AccumulatedDistance;
        return newDistance : AccumulatedDistance;
    }
    
    requirement def SpeedMeasurement {
        doc /* The system shall measure the vessel's speed through water. */
        attribute requiredAccuracy : Real = 0.1;
    }
    
    requirement def DistanceIntegration {
        doc /* The system shall continuously integrate speed over time to calculate total distance traveled. */
    }
    
    requirement def RealTimeDisplay {
        doc /* The system shall provide real-time speed and distance information to the crew. */
    }
    
    part def PitotTube {
        doc /* Hydrodynamic sensor extending through the hull to measure dynamic and static pressure difference. */
        attribute dynamicPressure : PressureValue;
        attribute staticPressure : PressureValue;
        out port pressureOut : PressureDifference;
        action sensePressure {
            out deltaP : PressureDifference;
        }
    }
    
    part def PressureTransducer {
        doc /* Converts pressure difference into a calibrated electrical signal. */
        attribute sensitivity : Real = 1.0;
        in port pressureIn : PressureDifference;
        out port signalOut : ElectricalSignal;
        action convertToSignal {
            in deltaP : PressureDifference;
            out signal : ElectricalSignal;
        }
    }
    
    part def VelocityComputer {
        doc /* Calculates instantaneous speed from pressure signal using fluid dynamics. */
        attribute waterDensity : Real = 1025;
        attribute calibrationConstant : Real = 1.0;
        in port signalIn : ElectricalSignal;
        out port speedOut : SpeedThroughWater;
        action calculateSpeed {
            in signal : ElectricalSignal;
            out speed : SpeedThroughWater;
        }
    }
    
    part def DistanceIntegrator {
        doc /* Accumulates distance traveled by integrating speed over time. */
        attribute accumulatedDistance : AccumulatedDistance = 0;
        attribute timeStep : DurationValue;
        in port speedIn : SpeedThroughWater;
        out port distanceOut : AccumulatedDistance;
        action integrateDistance {
            in speed : SpeedThroughWater;
            in dt : DurationValue;
            out distance : AccumulatedDistance;
        }
    }
    
    part def DisplayUnit {
        doc /* Displays current speed and total distance to the crew. */
        in port speedIn : SpeedThroughWater;
        in port distanceIn : AccumulatedDistance;
        action updateDisplay {
            in speed : SpeedThroughWater;
            in distance : AccumulatedDistance;
        }
    }
    
    part def PitometerLogSystem {
        doc /* Complete Pitometer Log system integrating all components. */
        part pitot : PitotTube;
        part transducer : PressureTransducer;
        part computer : VelocityComputer;
        part integrator : DistanceIntegrator;
        part display : DisplayUnit;
        
        connect pitot.pressureOut to transducer.pressureIn;
        connect transducer.signalOut to computer.signalIn;
        connect computer.speedOut to integrator.speedIn;
        connect computer.speedOut to display.speedIn;
        connect integrator.distanceOut to display.distanceIn;
        
        action continuousOperation {
            perform pitot.sensePressure;
            perform transducer.convertToSignal;
            perform computer.calculateSpeed;
            perform integrator.integrateDistance;
            perform display.updateDisplay;
        }
        
        satisfy SpeedMeasurement by computer;
        satisfy DistanceIntegration by integrator;
        satisfy RealTimeDisplay by display;
    }
}

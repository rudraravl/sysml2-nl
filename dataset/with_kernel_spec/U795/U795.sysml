package 'Optical Position Sensor System' {
    private import ISQ::*;
    private import ScalarValues::*;
    private import Time::*;

    item def LaserBeam {
        attribute wavelength : Real = 650;
        attribute power : Real = 5;
    }
    
    item def ReflectedLight;
    
    item def PositionData {
        attribute position : Real;
        attribute timestamp : Real;
    }
    
    item def PowerSupply {
        attribute voltage : Real = 24;
    }
    
    item def StartMeasurement;
    item def StopMeasurement;
    item def CalibrateCommand;
    item def FaultSignal;
    
    port def PowerPort {
        in power : PowerSupply;
    }
    
    port def DataPort {
        out data : PositionData;
    }
    
    port def OpticalEmissionPort {
        out beam : LaserBeam;
    }
    
    port def OpticalReceptionPort {
        in light : ReflectedLight;
    }
    
    part def ThreadedHole {
        attribute diameter : Real = 6;
    }
    
    part def MountingInterface {
        part holes : ThreadedHole[4];
    }
    
    part def OpticalWindow {
        port emissionPort : OpticalEmissionPort;
        port receptionPort : OpticalReceptionPort;
    }
    
    part def Housing {
        part mount : MountingInterface;
        part window : OpticalWindow;
    }
    
    part def LaserEmitter {
        port emissionPort : OpticalEmissionPort;
        port powerIn : PowerPort;
        attribute wavelength : Real = 650;
    }
    
    part def PhotodetectorArray {
        port receptionPort : OpticalReceptionPort;
        port dataOut : DataPort;
        attribute pixelCount : Integer = 2048;
    }
    
    part def PositionCalculator {
        port dataIn : DataPort;
        port dataOut : DataPort;
        port powerIn : PowerPort;
        
        action def CalculateCentroid {
            in pixelData : PositionData;
            out positionData : PositionData;
        }
        
        action centroidCalc : CalculateCentroid;
    }
    
    state def SensorStates {
        entry; then idle;
        
        state idle;
        state active;
        state calibration;
        state fault;
        
        transition idle_to_active
            first idle
            accept StartMeasurement
            then active;
            
        transition active_to_idle
            first active
            accept StopMeasurement
            then idle;
            
        transition idle_to_calibration
            first idle
            accept CalibrateCommand
            then calibration;
            
        transition calibration_to_idle
            first calibration
            accept StopMeasurement
            then idle;
            
        transition any_to_fault
            first idle | active | calibration
            accept FaultSignal
            then fault;
            
        transition fault_to_idle
            first fault
            accept StopMeasurement
            then idle;
    }
    
    part def OpticalPositionSensor {
        port powerIn : PowerPort;
        port dataOut : DataPort;
        
        exhibit state : SensorStates;
        
        part housing : Housing;
        part laser : LaserEmitter;
        part detector : PhotodetectorArray;
        part calculator : PositionCalculator;
        
        connect powerIn to laser.powerIn;
        connect powerIn to calculator.powerIn;
        connect laser.emissionPort to housing.window.emissionPort;
        connect housing.window.receptionPort to detector.receptionPort;
        connect detector.dataOut to calculator.dataIn;
        connect calculator.dataOut to dataOut;
    }
    
    requirement def MeasurementPerformance {
        attribute updateRate : Real = 1000;
        attribute resolution : Real = 0.05;
        attribute range : Real = 2;
    }
    
    requirement def LaserSpecification {
        attribute wavelength : Real = 650;
    }
    
    requirement def MountingSpecification {
        attribute holeCount : Integer = 4;
    }
    
    part sensorUnit : OpticalPositionSensor {
        requirement measurementPerformance : MeasurementPerformance;
        requirement laserSpecification : LaserSpecification;
        requirement mountingSpecification : MountingSpecification;
        
        satisfy measurementPerformance by calculator;
        satisfy laserSpecification by laser;
        satisfy mountingSpecification by housing.mount;
    }
}

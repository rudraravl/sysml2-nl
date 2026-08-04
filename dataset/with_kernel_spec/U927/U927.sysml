package 'Triangulation Sensing Unit' {
    private import ScalarValues::*;
    private import SI::*;
    
    item def Target;
    item def LaserBeam;
    item def ReflectedSignal;
    
    attribute def AngleMeasurement :> Real;
    attribute def PowerMeasurement :> Real;
    attribute def FrequencyMeasurement :> Real;
    
    port def OpticalOutputPort {
        out item beam : LaserBeam;
    }
    
    port def OpticalInputPort {
        in item reflection : ReflectedSignal;
    }
    
    port def MeasurementOutputPort {
        out distance : LengthValue;
    }
    
    action def EmitLaser {
        out beam : LaserBeam;
    }
    
    action def MeasureAngle {
        in target : Target;
        in reflection : ReflectedSignal;
        out angle : AngleMeasurement;
    }
    
    action def ComputeDistance {
        in angle1 : AngleMeasurement;
        in angle2 : AngleMeasurement;
        in baseline : LengthValue;
        out distance : LengthValue;
    }
    
    part def LaserEmitter {
        attribute wavelength : LengthValue;
        attribute outputPower : PowerMeasurement;
        port beamOut : OpticalOutputPort;
    }
    
    part def AngleDetector {
        attribute angularResolution : AngleMeasurement;
        attribute detectionRange : AngleMeasurement;
        attribute sensorPosition : LengthValue;
        port reflectionIn : OpticalInputPort;
    }
    
    part def ComputationUnit {
        attribute processingFrequency : FrequencyMeasurement;
    }
    
    part def TriangulationSensor {
        attribute baselineDistance : LengthValue;
        attribute measurementAccuracy : LengthValue;
        attribute minRange : LengthValue;
        attribute maxRange : LengthValue;
        
        part emitter : LaserEmitter[1];
        part detector1 : AngleDetector[1];
        part detector2 : AngleDetector[1];
        part processor : ComputationUnit[1];
        
        port laserOut : OpticalOutputPort;
        port reflectionIn : OpticalInputPort;
        port measurementOut : MeasurementOutputPort;
        
        connect emitter.beamOut to laserOut;
        connect reflectionIn to detector1.reflectionIn;
        connect reflectionIn to detector2.reflectionIn;
        
        action triangulate {
            in item targetObject : Target;
            in item reflectedSignal : ReflectedSignal;
            out measuredDistance : LengthValue;
            
            action emit : EmitLaser {
                out beam;
            }
            
            then fork;
                then measureAngle1;
                then measureAngle2;
            
            action measureAngle1 : MeasureAngle {
                in target = targetObject;
                in reflection = reflectedSignal;
                out angle;
            }
            then joinNode;
            
            action measureAngle2 : MeasureAngle {
                in target = targetObject;
                in reflection = reflectedSignal;
                out angle;
            }
            then joinNode;
            
            join joinNode;
            then computeDistance;
            
            flow from measureAngle1.angle to computeDistance.angle1;
            flow from measureAngle2.angle to computeDistance.angle2;
            
            action computeDistance : ComputeDistance {
                in angle1;
                in angle2;
                in baseline = baselineDistance;
                out distance;
            }
            
            bind computeDistance.distance = measuredDistance;
        }
    }
    
    part def SensingUnit {
        attribute relevantQuantity : LengthValue;
        
        part sensor : TriangulationSensor[1];
        
        port opticalTransmit : OpticalOutputPort;
        port opticalReceive : OpticalInputPort;
        port quantityOutput : MeasurementOutputPort;
        
        connect sensor.laserOut to opticalTransmit;
        connect opticalReceive to sensor.reflectionIn;
        connect sensor.measurementOut to quantityOutput;
        
        perform action measure {
            in item target : Target;
            in item reflection : ReflectedSignal;
            out result : LengthValue;
            
            action performMeasurement references sensor.triangulate {
                in :>> targetObject = target;
                in :>> reflectedSignal = reflection;
                out :>> measuredDistance = result;
            }
        }
    }
    
    part sensingSystem : SensingUnit {
        attribute :>> relevantQuantity = 500[mm];
        
        part :>> sensor {
            attribute :>> baselineDistance = 100[mm];
            attribute :>> measurementAccuracy = 0.3[mm];
            attribute :>> minRange = 50[mm];
            attribute :>> maxRange = 2000[mm];
            
            part :>> emitter {
                attribute :>> wavelength = 650e-9[m];
                attribute :>> outputPower = 0.005;
            }
            
            part :>> detector1 {
                attribute :>> angularResolution = 0.001745;
                attribute :>> detectionRange = 0.7854;
                attribute :>> sensorPosition = 0[mm];
            }
            
            part :>> detector2 {
                attribute :>> angularResolution = 0.001745;
                attribute :>> detectionRange = 0.7854;
                attribute :>> sensorPosition = 100[mm];
            }
            
            part :>> processor {
                attribute :>> processingFrequency = 1000;
            }
        }
    }
}

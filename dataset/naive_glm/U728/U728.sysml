package IRU {
    import SI::*
    import ScalarValues::*
    
    // ===== Value Types with Units =====
    
    value def AccelerationUnit > Real { unit "m/s^2"; }
    value def AngularVelocityUnit > Real { unit "rad/s"; }
    value def VelocityUnit > Real { unit "m/s"; }
    value def PositionUnit > Real { unit "m"; }
    value def AngleUnit > Real { unit "rad"; }
    value def TemperatureUnit > Real { unit "K"; }
    value def FrequencyUnit > Real { unit "Hz"; }
    value def TimeStampUnit > Real { unit "s"; }
    value def QualityMetric > Real { /* dimensionless 0..1 */ }
    
    value def Vector3 {
        x: Real;
        y: Real;
        z: Real;
    }
    
    value def AccelerationVector {
        x: AccelerationUnit;
        y: AccelerationUnit;
        z: AccelerationUnit;
    }
    
    value def AngularVelocityVector {
        x: AngularVelocityUnit;
        y: AngularVelocityUnit;
        z: AngularVelocityUnit;
    }
    
    value def VelocityVector {
        x: VelocityUnit;
        y: VelocityUnit;
        z: VelocityUnit;
    }
    
    value def PositionVector {
        x: PositionUnit;
        y: PositionUnit;
        z: PositionUnit;
    }
    
    value def Attitude {
        roll: AngleUnit;
        pitch: AngleUnit;
        yaw: AngleUnit;
    }
    
    value def CalibrationData {
        bias: Vector3;
        scaleFactor: Vector3;
        misalignment: Vector3;
    }
    
    value def SensorSample {
        value: Real;
        temperature: TemperatureUnit;
        timestamp: TimeStampUnit;
    }
    
    value def NavigationState {
        position: PositionVector;
        velocity: VelocityVector;
        attitude: Attitude;
        quality: QualityMetric;
        timestamp: TimeStampUnit;
    }
    
    // ===== Ports =====
    
    port def SensorOutputPort {
        out sample: SensorSample;
    }
    
    port def IMUOutputPort {
        out accelX: SensorSample;
        out accelY: SensorSample;
        out accelZ: SensorSample;
        out gyroX: SensorSample;
        out gyroY: SensorSample;
        out gyroZ: SensorSample;
    }
    
    port def NavigationStatePort {
        out navState: NavigationState;
    }
    
    port def CommandPort {
        in initialize: Boolean;
        in reset: Boolean;
    }
    
    // ===== Requirements =====
    
    requirement def IRURequirement {
        doc "The IRU shall autonomously compute position, velocity, and attitude without external signals."
    }
    
    requirement def AutonomyRequirement :> IRURequirement {
        doc "The IRU shall operate without GPS or other external navigation aids."
        constraint { self.externalDependency == false }
    }
    
    requirement def SensorSuiteRequirement :> IRURequirement {
        doc "The IMU shall contain three accelerometers and three gyroscopes aligned to orthogonal X, Y, Z axes."
    }
    
    requirement def NavigationAccuracyRequirement :> IRURequirement {
        doc "The Navigation Computer shall apply calibration data to correct sensor biases."
        constraint { self.calibrationApplied == true }
    }
    
    requirement def OutputRateRequirement :> IRURequirement {
        doc "The IRU shall output NavigationState at a minimum rate of 100 Hz."
        constraint { self.outputRate >= 100.0 [Hz] }
    }
    
    // ===== Sensor Part Definitions =====
    
    part def InertialSensor {
        abstract attribute sensorType: String;
        attribute axis: String;
        attribute calibration: CalibrationData;
        
        port sensorOut: SensorOutputPort;
        
        attribute rawValue: Real;
        attribute compensatedValue: Real;
        attribute filteredValue: Real;
        attribute currentTemperature: TemperatureUnit;
        
        action compensate {
            in raw: Real;
            in temp: TemperatureUnit;
            in cal: CalibrationData;
            return compensated: Real;
        }
        
        action filter {
            in input: Real;
            return filtered: Real;
        }
        
        action packageSample {
            in value: Real;
            in temp: TemperatureUnit;
            in time: TimeStampUnit;
            return sample: SensorSample;
        }
        
        action sampleCycle {
            // Internal processing: compensate, filter, package
            then compensate;
            then filter;
            then packageSample;
        }
        
        state sensorStateBehavior {
            entry; then Operational;
            
            state Operational {
                entry action { send sensorOut.sample; }
                do action sampleCycle;
                transition Operational -> Operational;
            }
            
            state Faulted;
            transition Operational -> Faulted
                if (currentTemperature > 358.0 [K]);
        }
    }
    
    part def Accelerometer :> InertialSensor {
        attribute sensorType := "Accelerometer";
        attribute measuredAcceleration: AccelerationUnit;
    }
    
    part def Gyroscope :> InertialSensor {
        attribute sensorType := "Gyroscope";
        attribute measuredAngularVelocity: AngularVelocityUnit;
    }
    
    // ===== IMU Part Definition =====
    
    part def IMU {
        port imuOut: IMUOutputPort;
        
        part accelX: Accelerometer {
            attribute axis := "X";
            binding imuOut.accelx = sensorOut.sample;
        }
        part accelY: Accelerometer {
            attribute axis := "Y";
            binding imuOut.accely = sensorOut.sample;
        }
        part accelZ: Accelerometer {
            attribute axis := "Z";
            binding imuOut.accelz = sensorOut.sample;
        }
        part gyroX: Gyroscope {
            attribute axis := "X";
            binding imuOut.gyrox = sensorOut.sample;
        }
        part gyroY: Gyroscope {
            attribute axis := "Y";
            binding imuOut.gyroy = sensorOut.sample;
        }
        part gyroZ: Gyroscope {
            attribute axis := "Z";
            binding imuOut.gyroz = sensorOut.sample;
        }
        
        // Mounting frame ensures orthogonal alignment
        attribute mountingFrameAlignment: Vector3 := (x=1.0, y=0.0, z=0.0);
    }
    
    // ===== Navigation Computer Part Definition =====
    
    part def NavigationComputer {
        port imuIn: IMUOutputPort ~ IMUOutputPort;
        port navOut: NavigationStatePort;
        port command: CommandPort;
        
        attribute cycleRate: FrequencyUnit := 200.0 [Hz];
        attribute calibrationData: CalibrationData[6];
        
        attribute currentAttitude: Attitude;
        attribute currentVelocity: VelocityVector;
        attribute currentPosition: PositionVector;
        attribute gravityVector: AccelerationVector := (x=0.0, y=0.0, z=-9.80665);
        attribute quality: QualityMetric := 1.0;
        attribute lastTimestamp: TimeStampUnit := 0.0;
        
        action acquireSensorData {
            in accelX: SensorSample;
            in accelY: SensorSample;
            in accelZ: SensorSample;
            in gyroX: SensorSample;
            in gyroY: SensorSample;
            in gyroZ: SensorSample;
            return raw: IMUOutputPort;
        }
        
        action applyCalibration {
            in raw: IMUOutputPort;
            in cal: CalibrationData[6];
            return corrected: IMUOutputPort;
        }
        
        action updateAttitude {
            in gyro: AngularVelocityVector;
            in prevAttitude: Attitude;
            in dt: TimeStampUnit;
            return attitude: Attitude;
        }
        
        action resolveGravity {
            in attitude: Attitude;
            in rawAccel: AccelerationVector;
            return trueAccel: AccelerationVector;
        }
        
        action integrateVelocity {
            in accel: AccelerationVector;
            in prevVelocity: VelocityVector;
            in dt: TimeStampUnit;
            return velocity: VelocityVector;
        }
        
        action integratePosition {
            in velocity: VelocityVector;
            in prevPosition: PositionVector;
            in dt: TimeStampUnit;
            return position: PositionVector;
        }
        
        action assembleNavigationState {
            in pos: PositionVector;
            in vel: VelocityVector;
            in att: Attitude;
            in qual: QualityMetric;
            in time: TimeStampUnit;
            return state: NavigationState;
        }
        
        action computeCycle {
            // 1. Acquire latest sensor readings
            action acquireSensorData;
            // 2. Apply calibration
            then applyCalibration;
            // 3. Update attitude from gyroscopes
            then updateAttitude;
            // 4. Resolve gravity vs true acceleration
            then resolveGravity;
            // 5. Integrate acceleration to velocity
            then integrateVelocity;
            // 6. Integrate velocity to position
            then integratePosition;
            // Bundle into NavigationState
            then assembleNavigationState;
        }
        
        state navComputerState {
            entry; then Initializing;
            
            state Initializing {
                entry action {
                    currentAttitude := (roll=0.0, pitch=0.0, yaw=0.0);
                    currentVelocity := (x=0.0, y=0.0, z=0.0);
                    currentPosition := (x=0.0, y=0.0, z=0.0);
                }
                transition Initializing -> Running
                    if (command.initialize == true);
            }
            
            state Running {
                do action computeCycle;
                entry action { send navOut.navState; }
                transition Running -> Initializing
                    if (command.reset == true);
            }
        }
    }
    
    // ===== IRU Top-Level Part Definition =====
    
    part def InertialReferenceUnit {
        doc "Self-contained navigation system tracking position, velocity, and orientation autonomously."
        
        satisfy IRURequirement;
        satisfy AutonomyRequirement;
        satisfy SensorSuiteRequirement;
        satisfy NavigationAccuracyRequirement;
        satisfy OutputRateRequirement;
        
        port navStateOut: NavigationStatePort;
        port commandIn: CommandPort;
        
        attribute externalDependency: Boolean := false;
        attribute outputRate: FrequencyUnit := 200.0 [Hz];
        attribute calibrationApplied: Boolean := true;
        
        part imu: IMU {
            doc "Sensory core: three accelerometers and three gyroscopes on orthogonal axes.";
        }
        
        part navComputer: NavigationComputer {
            doc "Brain of the IRU: executes continuous high-speed navigation calculation cycle.";
        }
        
        // Connect IMU output to Navigation Computer input
        connection imu.imuOut to navComputer.imuIn;
        
        // Expose Navigation Computer output as IRU output
        binding navStateOut.navState = navComputer.navOut.navState;
        
        // Forward commands to navigation computer
        binding commandIn.initialize = navComputer.command.initialize;
        binding commandIn.reset = navComputer.command.reset;
    }
    
    // ===== Example Configuration =====
    
    part iruInstance : InertialReferenceUnit {
        part imu redefines imu {
            part accelX redefines accelX {
                attribute calibration := (bias=(x=0.01, y=0.0, z=0.0), scaleFactor=(x=1.0, y=1.0, z=1.0), misalignment=(x=0.0, y=0.0, z=0.0));
            }
            part accelY redefines accelY {
                attribute calibration := (bias=(x=0.0, y=0.012, z=0.0), scaleFactor=(x=1.0, y=1.0, z=1.0), misalignment=(x=0.0, y=0.0, z=0.0));
            }
            part accelZ redefines accelZ {
                attribute calibration := (bias=(x=0.0, y=0.0, z=0.015), scaleFactor=(x=1.0, y=1.0, z=1.0), misalignment=(x=0.0, y=0.0, z=0.0));
            }
            part gyroX redefines gyroX {
                attribute calibration := (bias=(x=0.0005, y=0.0, z=0.0), scaleFactor=(x=1.0, y=1.0, z=1.0), misalignment=(x=0.0, y=0.0, z=0.0));
            }
            part gyroY redefines gyroY {
                attribute calibration := (bias=(x=0.0, y=0.0006, z=0.0), scaleFactor=(x=1.0, y=1.0, z=1.0), misalignment=(x=0.0, y=0.0, z=0.0));
            }
            part gyroZ redefines gyroZ {
                attribute calibration := (bias=(x=0.0, y=0.0, z=0.0007), scaleFactor=(x=1.0, y=1.0, z=1.0), misalignment=(x=0.0, y=0.0, z=0.0));
            }
        }
    }
}

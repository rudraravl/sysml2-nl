package 'Inertial Reference Unit Model' {
    private import ISQ::*;
    private import ScalarValues::*;
    
    item def AccelerometerData {
        attribute acceleration : ISQ::AccelerationValue;
        attribute temperature : ISQ::TemperatureValue;
    }
    
    item def GyroscopeData {
        attribute angularVelocity : ISQ::AngularVelocityValue;
        attribute temperature : ISQ::TemperatureValue;
    }
    
    item def NavigationState {
        attribute position : ISQ::LengthValue;
        attribute velocity : ISQ::SpeedValue;
        attribute roll : ISQ::AngleValue;
        attribute pitch : ISQ::AngleValue;
        attribute yaw : ISQ::AngleValue;
        attribute quality : Real;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def CalibrationData {
        attribute accelBias : ISQ::AccelerationValue;
        attribute gyroBias : ISQ::AngularVelocityValue;
    }
    
    action def ProcessAccelerometer {
        in rawAccel : ISQ::AccelerationValue;
        in temp : ISQ::TemperatureValue;
        out data : AccelerometerData;
    }
    
    action def ProcessGyroscope {
        in rawGyro : ISQ::AngularVelocityValue;
        in temp : ISQ::TemperatureValue;
        out data : GyroscopeData;
    }
    
    part def Accelerometer {
        attribute axis : String;
        out port dataOut : AccelerometerData;
        action process : ProcessAccelerometer;
    }
    
    part def Gyroscope {
        attribute axis : String;
        out port dataOut : GyroscopeData;
        action process : ProcessGyroscope;
    }
    
    part def IMU {
        part accelX : Accelerometer { attribute axis = "X"; }
        part accelY : Accelerometer { attribute axis = "Y"; }
        part accelZ : Accelerometer { attribute axis = "Z"; }
        part gyroX : Gyroscope { attribute axis = "X"; }
        part gyroY : Gyroscope { attribute axis = "Y"; }
        part gyroZ : Gyroscope { attribute axis = "Z"; }
        
        out port accelXOut : AccelerometerData;
        out port accelYOut : AccelerometerData;
        out port accelZOut : AccelerometerData;
        out port gyroXOut : GyroscopeData;
        out port gyroYOut : GyroscopeData;
        out port gyroZOut : GyroscopeData;
        
        connect accelX.dataOut to accelXOut;
        connect accelY.dataOut to accelYOut;
        connect accelZ.dataOut to accelZOut;
        connect gyroX.dataOut to gyroXOut;
        connect gyroY.dataOut to gyroYOut;
        connect gyroZ.dataOut to gyroZOut;
    }
    
    action def AcquireData {
        in accelX : AccelerometerData;
        in accelY : AccelerometerData;
        in accelZ : AccelerometerData;
        in gyroX : GyroscopeData;
        in gyroY : GyroscopeData;
        in gyroZ : GyroscopeData;
        out accelXData : AccelerometerData;
        out accelYData : AccelerometerData;
        out accelZData : AccelerometerData;
        out gyroXData : GyroscopeData;
        out gyroYData : GyroscopeData;
        out gyroZData : GyroscopeData;
    }
    
    action def ApplyCalibration {
        in accelXData : AccelerometerData;
        in accelYData : AccelerometerData;
        in accelZData : AccelerometerData;
        in gyroXData : GyroscopeData;
        in gyroYData : GyroscopeData;
        in gyroZData : GyroscopeData;
        in cal : CalibrationData;
        out correctedAccelX : ISQ::AccelerationValue;
        out correctedAccelY : ISQ::AccelerationValue;
        out correctedAccelZ : ISQ::AccelerationValue;
        out correctedGyroX : ISQ::AngularVelocityValue;
        out correctedGyroY : ISQ::AngularVelocityValue;
        out correctedGyroZ : ISQ::AngularVelocityValue;
    }
    
    action def UpdateAttitude {
        in correctedGyroX : ISQ::AngularVelocityValue;
        in correctedGyroY : ISQ::AngularVelocityValue;
        in correctedGyroZ : ISQ::AngularVelocityValue;
        in deltaT : ISQ::TimeValue;
        out rollOut : ISQ::AngleValue;
        out pitchOut : ISQ::AngleValue;
        out yawOut : ISQ::AngleValue;
    }
    
    action def ResolveGravity {
        in rollIn : ISQ::AngleValue;
        in pitchIn : ISQ::AngleValue;
        in yawIn : ISQ::AngleValue;
        in correctedAccelX : ISQ::AccelerationValue;
        in correctedAccelY : ISQ::AccelerationValue;
        in correctedAccelZ : ISQ::AccelerationValue;
        out trueAccelX : ISQ::AccelerationValue;
        out trueAccelY : ISQ::AccelerationValue;
        out trueAccelZ : ISQ::AccelerationValue;
    }
    
    action def IntegrateVelocity {
        in trueAccelX : ISQ::AccelerationValue;
        in trueAccelY : ISQ::AccelerationValue;
        in trueAccelZ : ISQ::AccelerationValue;
        in deltaT : ISQ::TimeValue;
        out velocityOut : ISQ::SpeedValue;
    }
    
    action def IntegratePosition {
        in velocityIn : ISQ::SpeedValue;
        in deltaT : ISQ::TimeValue;
        out positionOut : ISQ::LengthValue;
    }
    
    action def GenerateReport {
        in positionIn : ISQ::LengthValue;
        in velocityIn : ISQ::SpeedValue;
        in rollIn : ISQ::AngleValue;
        in pitchIn : ISQ::AngleValue;
        in yawIn : ISQ::AngleValue;
        out stateOut : NavigationState;
    }
    
    action def NavigationCycle {
        in accelX : AccelerometerData;
        in accelY : AccelerometerData;
        in accelZ : AccelerometerData;
        in gyroX : GyroscopeData;
        in gyroY : GyroscopeData;
        in gyroZ : GyroscopeData;
        in calibration : CalibrationData;
        in dt : ISQ::TimeValue;
        out state : NavigationState;
        
        perform action acquire : AcquireData {
            in accelX = accelX;
            in accelY = accelY;
            in accelZ = accelZ;
            in gyroX = gyroX;
            in gyroY = gyroY;
            in gyroZ = gyroZ;
        }
        then perform action calibrate : ApplyCalibration {
            in accelXData = acquire.accelXData;
            in accelYData = acquire.accelYData;
            in accelZData = acquire.accelZData;
            in gyroXData = acquire.gyroXData;
            in gyroYData = acquire.gyroYData;
            in gyroZData = acquire.gyroZData;
            in cal = calibration;
        }
        then perform action attitude : UpdateAttitude {
            in correctedGyroX = calibrate.correctedGyroX;
            in correctedGyroY = calibrate.correctedGyroY;
            in correctedGyroZ = calibrate.correctedGyroZ;
            in deltaT = dt;
        }
        then perform action gravity : ResolveGravity {
            in rollIn = attitude.rollOut;
            in pitchIn = attitude.pitchOut;
            in yawIn = attitude.yawOut;
            in correctedAccelX = calibrate.correctedAccelX;
            in correctedAccelY = calibrate.correctedAccelY;
            in correctedAccelZ = calibrate.correctedAccelZ;
        }
        then perform action velocity : IntegrateVelocity {
            in trueAccelX = gravity.trueAccelX;
            in trueAccelY = gravity.trueAccelY;
            in trueAccelZ = gravity.trueAccelZ;
            in deltaT = dt;
        }
        then perform action position : IntegratePosition {
            in velocityIn = velocity.velocityOut;
            in deltaT = dt;
        }
        then perform action report : GenerateReport {
            in positionIn = position.positionOut;
            in velocityIn = velocity.velocityOut;
            in rollIn = attitude.rollOut;
            in pitchIn = attitude.pitchOut;
            in yawIn = attitude.yawOut;
        }
        then assign state := report.stateOut;
    }
    
    part def NavigationComputer {
        attribute calibrationData : CalibrationData;
        attribute cycleTime : ISQ::TimeValue;
        in port accelXIn : AccelerometerData;
        in port accelYIn : AccelerometerData;
        in port accelZIn : AccelerometerData;
        in port gyroXIn : GyroscopeData;
        in port gyroYIn : GyroscopeData;
        in port gyroZIn : GyroscopeData;
        out port navStateOut : NavigationState;
        
        perform action runCycle : NavigationCycle {
            in accelX = accelXIn;
            in accelY = accelYIn;
            in accelZ = accelZIn;
            in gyroX = gyroXIn;
            in gyroY = gyroYIn;
            in gyroZ = gyroZIn;
            in calibration = calibrationData;
            in dt = cycleTime;
            out state to navStateOut;
        }
    }
    
    part def IRU {
        part imu : IMU;
        part navComputer : NavigationComputer;
        
        out port iruStateOut : NavigationState;
        
        connect imu.accelXOut to navComputer.accelXIn;
        connect imu.accelYOut to navComputer.accelYIn;
        connect imu.accelZOut to navComputer.accelZIn;
        connect imu.gyroXOut to navComputer.gyroXIn;
        connect imu.gyroYOut to navComputer.gyroYIn;
        connect imu.gyroZOut to navComputer.gyroZIn;
        
        connect navComputer.navStateOut to iruStateOut;
    }
    
    requirement def IRURequirement {
        doc /* The IRU shall autonomously calculate position, velocity, and orientation using only internal sensors without external signals. */
        subject iru : IRU;
    }
    
    requirement def ContinuousOutputRequirement {
        doc /* The IRU shall provide a continuous Navigation State output. */
        subject iru : IRU;
    }
}

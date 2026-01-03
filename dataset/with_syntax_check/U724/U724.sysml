package InclinometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def AngleDegrees :> Real;
    
    attribute def CalibrationData {
        attribute xOffset : AngleDegrees;
        attribute yOffset : AngleDegrees;
        attribute zOffset : AngleDegrees;
        attribute timestamp : String;
    }
    
    item def SensorReading {
        attribute xAcceleration : AccelerationValue;
        attribute yAcceleration : AccelerationValue;
        attribute zAcceleration : AccelerationValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }
    
    item def TiltMeasurement {
        attribute pitchAngle : AngleDegrees;
        attribute rollAngle : AngleDegrees;
        attribute isValid : Boolean;
        attribute confidence : Real;
    }
    
    item def PowerOnCommand;
    item def PowerOffCommand;
    item def RecalibrateCommand;
    item def ResetCommand;
    
    port def SensorDataPort {
        out reading : SensorReading;
    }
    
    port def TiltOutputPort {
        out measurement : TiltMeasurement;
    }
    
    port def PowerInputPort {
        in voltage : ISQ::ElectricPotentialValue;
        in current : ISQ::ElectricCurrentValue;
    }
    
    port def CalibrationPort {
        in calibrationData : CalibrationData;
        out calibrationStatus : Boolean;
    }
    
    part def MEMSAccelerometer {
        doc /* Three-axis MEMS accelerometer sensor for gravity vector measurement */
        
        attribute sensitivity : Real;
        attribute noiseFloor : AccelerationValue;
        attribute operatingRange : AccelerationValue;
        
        port sensorOut : SensorDataPort;
        port powerIn : PowerInputPort;
        
        perform action acquireSensorData : AcquireAcceleration;
    }
    
    part def SignalProcessor {
        doc /* Digital signal processor for filtering and angle calculation */
        
        attribute filterCutoffFrequency : FrequencyValue;
        attribute processingRate : FrequencyValue;
        
        port sensorIn : SensorDataPort;
        port tiltOut : TiltOutputPort;
        port powerIn : PowerInputPort;
        port calibrationIn : CalibrationPort;
        
        perform action processSensorData : CalculateTiltAngles;
    }
    
    part def DisplayController {
        doc /* Controls visual display of tilt measurements */
        
        attribute refreshRate : FrequencyValue;
        attribute displayResolution : Real;
        
        port dataIn : TiltOutputPort;
        port powerIn : PowerInputPort;
        
        perform action updateDisplay : ShowTiltData;
    }
    
    part def PowerRegulator {
        doc /* Provides stable regulated power to all subsystems */
        
        attribute inputVoltageRange : ISQ::ElectricPotentialValue;
        attribute outputVoltage : ISQ::ElectricPotentialValue;
        attribute efficiency : Real;
        
        port externalPower : PowerInputPort;
        port sensorPower : PowerInputPort;
        port processorPower : PowerInputPort;
        port displayPower : PowerInputPort;
    }
    
    part def Inclinometer {
        doc /* 
            An inclinometer measures the angle of tilt or inclination relative to 
            Earth's gravitational field. The system uses a MEMS accelerometer to 
            detect the gravity vector, processes the sensor data to calculate pitch 
            and roll angles, and displays the results for applications such as 
            construction leveling, vehicle stability monitoring, and platform alignment.
        */
        
        attribute measurementRange : AngleDegrees = 90.0;
        attribute accuracy : AngleDegrees = 0.1;
        attribute updateRate : FrequencyValue;
        attribute currentCalibration : CalibrationData;
        
        port externalPowerPort : PowerInputPort;
        port tiltDataPort : TiltOutputPort;
        port calibrationPort : CalibrationPort;
        
        part sensor : MEMSAccelerometer {
            sensitivity = 0.001;
            operatingRange = 2.0 * 9.81[m/s^2];
        }
        
        part processor : SignalProcessor {
            filterCutoffFrequency = 10.0[Hz];
            processingRate = 100.0[Hz];
        }
        
        part display : DisplayController {
            refreshRate = 30.0[Hz];
            displayResolution = 0.01;
        }
        
        part power : PowerRegulator {
            outputVoltage = 3.3[V];
            efficiency = 0.85;
        }
        
        connect externalPowerPort to power.externalPower;
        connect power.sensorPower to sensor.powerIn;
        connect power.processorPower to processor.powerIn;
        connect power.displayPower to display.powerIn;
        connect sensor.sensorOut to processor.sensorIn;
        connect processor.tiltOut to display.dataIn;
        connect processor.tiltOut to tiltDataPort;
        connect calibrationPort to processor.calibrationIn;
        
        perform action measureTilt : MeasureInclination;
    }
    
    action def AcquireAcceleration {
        out xAccel : AccelerationValue;
        out yAccel : AccelerationValue;
        out zAccel : AccelerationValue;
        out temp : ThermodynamicTemperatureValue;
    }
    
    action def FilterSignal {
        in rawValue : AccelerationValue;
        in cutoffFreq : FrequencyValue;
        out filteredValue : AccelerationValue;
    }
    
    action def ComputePitchAngle {
        in xAccel : AccelerationValue;
        in yAccel : AccelerationValue;
        in zAccel : AccelerationValue;
        in xOffset : AngleDegrees;
        out pitch : AngleDegrees;
    }
    
    action def ComputeRollAngle {
        in xAccel : AccelerationValue;
        in yAccel : AccelerationValue;
        in zAccel : AccelerationValue;
        in yOffset : AngleDegrees;
        out roll : AngleDegrees;
    }
    
    action def ValidateReading {
        in pitch : AngleDegrees;
        in roll : AngleDegrees;
        in maxRange : AngleDegrees;
        out isValid : Boolean;
        out confidence : Real;
    }
    
    action def ApplyCalibrationOffset {
        in rawAngle : AngleDegrees;
        in offset : AngleDegrees;
        out calibratedAngle : AngleDegrees;
    }
    
    action def CalculateTiltAngles {
        in rawX : AccelerationValue;
        in rawY : AccelerationValue;
        in rawZ : AccelerationValue;
        in cutoff : FrequencyValue;
        in calibData : CalibrationData;
        in range : AngleDegrees;
        out finalPitch : AngleDegrees;
        out finalRoll : AngleDegrees;
        out valid : Boolean;
        out conf : Real;
        
        first start;
        then action filterX : FilterSignal {
            in rawValue = rawX;
            in cutoffFreq = cutoff;
            out filteredValue;
        }
        then action filterY : FilterSignal {
            in rawValue = rawY;
            in cutoffFreq = cutoff;
            out filteredValue;
        }
        then action filterZ : FilterSignal {
            in rawValue = rawZ;
            in cutoffFreq = cutoff;
            out filteredValue;
        }
        then action calcPitch : ComputePitchAngle {
            in xAccel = filterX.filteredValue;
            in yAccel = filterY.filteredValue;
            in zAccel = filterZ.filteredValue;
            in xOffset = calibData.xOffset;
            out pitch;
        }
        then action calcRoll : ComputeRollAngle {
            in xAccel = filterX.filteredValue;
            in yAccel = filterY.filteredValue;
            in zAccel = filterZ.filteredValue;
            in yOffset = calibData.yOffset;
            out roll;
        }
        then action applyPitchCal : ApplyCalibrationOffset {
            in rawAngle = calcPitch.pitch;
            in offset = calibData.xOffset;
            out calibratedAngle;
        }
        then action applyRollCal : ApplyCalibrationOffset {
            in rawAngle = calcRoll.roll;
            in offset = calibData.yOffset;
            out calibratedAngle;
        }
        then action validate : ValidateReading {
            in pitch = applyPitchCal.calibratedAngle;
            in roll = applyRollCal.calibratedAngle;
            in maxRange = range;
            out isValid;
            out confidence;
        }
        then assign finalPitch := applyPitchCal.calibratedAngle;
        then assign finalRoll := applyRollCal.calibratedAngle;
        then assign valid := validate.isValid;
        then assign conf := validate.confidence;
        then done;
    }
    
    action def ShowTiltData {
        in pitch : AngleDegrees;
        in roll : AngleDegrees;
        in valid : Boolean;
    }
    
    action def MeasureInclination {
        in updateRate : FrequencyValue;
        in measurementRange : AngleDegrees;
        in calibration : CalibrationData;
        out currentPitch : AngleDegrees;
        out currentRoll : AngleDegrees;
        out measurementValid : Boolean;
        
        first start;
        then merge continueMeasurement;
        then action acquire : AcquireAcceleration {
            out xAccel;
            out yAccel;
            out zAccel;
            out temp;
        }
        then action calculate : CalculateTiltAngles {
            in rawX = acquire.xAccel;
            in rawY = acquire.yAccel;
            in rawZ = acquire.zAccel;
            in cutoff = 10.0[Hz];
            in calibData = calibration;
            in range = measurementRange;
            out finalPitch;
            out finalRoll;
            out valid;
            out conf;
        }
        then action display : ShowTiltData {
            in pitch = calculate.finalPitch;
            in roll = calculate.finalRoll;
            in valid = calculate.valid;
        }
        then assign currentPitch := calculate.finalPitch;
        then assign currentRoll := calculate.finalRoll;
        then assign measurementValid := calculate.valid;
        then continueMeasurement;
    }
    
    action def InitializeSensors;
    action def PerformCalibration;
    
    state def InclinometerStates {
        entry; then powerOff;
        
        state powerOff {
            entry assign statusMessage := "Power Off";
        }
        
        transition powerOff_to_initialization
            first powerOff
            accept PowerOnCommand
            then initialization;
        
        state initialization {
            entry assign statusMessage := "Initializing";
            do action initSensors : InitializeSensors;
        }
        
        transition initialization_to_calibration
            first initialization
            if initializationComplete
            then calibration;
        
        state calibration {
            entry assign statusMessage := "Calibrating";
            do action performCal : PerformCalibration;
        }
        
        transition calibration_to_operational
            first calibration
            if calibrationSuccessful
            then operational;
        
        transition calibration_to_error
            first calibration
            if calibrationFailed
            then error;
        
        state operational {
            entry assign statusMessage := "Operational";
            do action continuousMeasurement : MeasureInclination;
        }
        
        transition operational_to_powerOff
            first operational
            accept PowerOffCommand
            then powerOff;
        
        transition operational_to_error
            first operational
            if sensorFailureDetected
            then error;
        
        transition operational_to_calibration
            first operational
            accept RecalibrateCommand
            then calibration;
        
        state error {
            entry assign statusMessage := "Error";
        }
        
        transition error_to_initialization
            first error
            accept ResetCommand
            then initialization;
        
        transition error_to_powerOff
            first error
            accept PowerOffCommand
            then powerOff;
        
        attribute statusMessage : String;
        attribute initializationComplete : Boolean;
        attribute calibrationSuccessful : Boolean;
        attribute calibrationFailed : Boolean;
        attribute sensorFailureDetected : Boolean;
    }
    
    part inclinometerDevice : Inclinometer {
        doc /* 
            Primary inclinometer device instance for measuring tilt angles
            in construction, surveying, and industrial alignment applications.
            Provides continuous real-time measurement of pitch and roll angles
            with high accuracy and reliability.
        */
        
        measurementRange = 90.0;
        accuracy = 0.1;
        updateRate = 100.0[Hz];
        
        state operatingStates : InclinometerStates;
        
        perform action operate : MeasureInclination {
            in updateRate = inclinometerDevice.updateRate;
            in measurementRange = inclinometerDevice.measurementRange;
            in calibration = inclinometerDevice.currentCalibration;
            out currentPitch;
            out currentRoll;
            out measurementValid;
        }
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* The inclinometer shall measure tilt angles with specified accuracy */
        subject device : Inclinometer;
        require constraint {
            device.accuracy <= 0.1
        }
    }
    
    requirement def MeasurementRangeRequirement {
        doc /* The inclinometer shall measure angles within full operational range */
        subject device : Inclinometer;
        require constraint {
            device.measurementRange >= 90.0
        }
    }
    
    requirement def UpdateRateRequirement {
        doc /* The inclinometer shall provide measurements at minimum update rate */
        subject device : Inclinometer;
        require constraint {
            device.updateRate >= 50.0[Hz]
        }
    }
    
    requirement def CalibrationRequirement {
        doc /* The inclinometer shall support field calibration for offset correction */
        subject device : Inclinometer;
    }
    
    requirement systemRequirements {
        doc /* 
            The inclinometer system shall accurately measure tilt angles relative
            to Earth's gravity for precision leveling and alignment applications.
            The system must provide reliable, continuous measurements with high
            accuracy and support field calibration.
        */
        
        subject inclinometerSystem : Inclinometer;
        
        require accuracyReq : MeasurementAccuracyRequirement {
            subject device = inclinometerSystem;
        }
        
        require rangeReq : MeasurementRangeRequirement {
            subject device = inclinometerSystem;
        }
        
        require updateReq : UpdateRateRequirement {
            subject device = inclinometerSystem;
        }
        
        require calibReq : CalibrationRequirement {
            subject device = inclinometerSystem;
        }
    }
}

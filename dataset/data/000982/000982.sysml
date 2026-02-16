package AuxanometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def GrowthRate :> ISQ::SpeedValue {
        doc /* Rate of plant growth measured in length per unit time */
    }
    
    attribute def DisplacementValue :> ISQ::LengthValue {
        doc /* Vertical displacement measured by the auxanometer */
    }
    
    attribute def AngularDisplacement :> Real {
        doc /* Angular displacement of the pulley or lever in radians */
    }
    
    item def GrowthMeasurement {
        attribute timestamp : ISQ::TimeValue;
        attribute displacement : DisplacementValue;
        attribute rate : GrowthRate;
    }
    
    item def PlantSpecimen {
        attribute initialHeight : ISQ::LengthValue;
        attribute currentHeight : ISQ::LengthValue;
    }
    
    item def CalibrateCommand;
    item def StopCommand;
    item def PauseCommand;
    item def ResumeCommand;
    
    attribute def CalibrationComplete : Boolean;
    
    port def MechanicalInputPort {
        in verticalDisplacement : DisplacementValue;
    }
    
    port def MechanicalOutputPort {
        out amplifiedDisplacement : DisplacementValue;
    }
    
    port def SensorPort {
        out angularPosition : AngularDisplacement;
    }
    
    port def DataOutputPort {
        out measurement : GrowthMeasurement;
    }
    
    part def AttachmentPoint {
        doc /* Point of attachment to the growing plant */
        attribute contactForce : ISQ::ForceValue;
        port output : MechanicalOutputPort;
    }
    
    part def PulleyMechanism {
        doc /* Converts linear plant growth into rotational motion */
        attribute pulleyRadius : ISQ::LengthValue;
        attribute rotationAngle : AngularDisplacement;
        port input : MechanicalInputPort;
        port output : SensorPort;
    }
    
    part def LeverArm {
        doc /* Mechanical amplification system for small displacements */
        attribute leverRatio : Real;
        attribute pivotPosition : ISQ::LengthValue;
        port input : MechanicalInputPort;
        port output : MechanicalOutputPort;
    }
    
    part def RotaryEncoder {
        doc /* Measures angular displacement of the pulley */
        attribute resolution : AngularDisplacement;
        attribute currentReading : AngularDisplacement;
        port input : SensorPort;
    }
    
    part def GraduatedScale {
        doc /* Visual scale for manual reading of displacement */
        attribute minValue : DisplacementValue;
        attribute maxValue : DisplacementValue;
        attribute graduationInterval : DisplacementValue;
    }
    
    part def PointerIndicator {
        doc /* Visual indicator showing current displacement on scale */
        attribute currentPosition : DisplacementValue;
    }
    
    part def DataAcquisitionUnit {
        doc /* Processes sensor data and calculates growth metrics */
        attribute samplingRate : ISQ::FrequencyValue;
        attribute storedMeasurements : GrowthMeasurement[*] ordered;
        port sensorInput : SensorPort;
        port dataOutput : DataOutputPort;
    }
    
    part def RecordingDevice {
        doc /* Stores growth measurements over time */
        attribute storageCapacity : Real;
        attribute recordingInterval : ISQ::TimeValue;
        attribute measurements : GrowthMeasurement[*] ordered;
        port input : DataOutputPort;
    }
    
    action def InitializeMeasurement {
        doc /* Set baseline reference for growth measurement */
        in plantHeight : ISQ::LengthValue;
        in startTime : ISQ::TimeValue;
        out baselineDisplacement : DisplacementValue;
    }
    
    action def ConvertDisplacement {
        doc /* Convert angular displacement to linear growth */
        in angularPosition : AngularDisplacement;
        in pulleyRadius : ISQ::LengthValue;
        out linearDisplacement : DisplacementValue;
    }
    
    action def CalculateGrowthRate {
        doc /* Compute growth rate from displacement measurements */
        in currentMeasurement : GrowthMeasurement;
        in previousMeasurement : GrowthMeasurement;
        out growthRate : GrowthRate;
    }
    
    action def RecordData {
        doc /* Store measurement with timestamp */
        in displacement : DisplacementValue;
        in timestamp : ISQ::TimeValue;
        in rate : GrowthRate;
        out measurement : GrowthMeasurement;
    }
    
    action def MonitorGrowth {
        doc /* Continuous monitoring cycle for plant growth */
        in samplingInterval : ISQ::TimeValue;
        in pulleyRadius : ISQ::LengthValue;
        out measurements : GrowthMeasurement[*];
        
        private attribute previousDisplacement : DisplacementValue := 0.0 [mm];
        private attribute previousTime : ISQ::TimeValue := 0.0 [s];
        
        first start;
        then action initialize : InitializeMeasurement {
            in plantHeight;
            in startTime;
            out baselineDisplacement;
        }
        then merge continueMeasuring;
        then action convert : ConvertDisplacement {
            in angularPosition;
            in pulleyRadius = MonitorGrowth::pulleyRadius;
            out linearDisplacement;
        }
        then action calculateRate : CalculateGrowthRate {
            in currentMeasurement;
            in previousMeasurement;
            out growthRate;
        }
        then action record : RecordData {
            in displacement = convert.linearDisplacement;
            in timestamp;
            in rate = calculateRate.growthRate;
            out measurement;
        }
        then assign previousDisplacement := convert.linearDisplacement;
        then assign previousTime := record.measurement.timestamp;
        then decide;
            if record.measurement.rate >= 0.0 [mm/h] then continueMeasuring;
            if record.measurement.rate < 0.0 [mm/h] then errorHandling;
        action errorHandling;
        then continueMeasuring;
    }
    
    state def AuxanometerStates {
        entry; then idle;
        
        state idle {
            doc /* System ready but not measuring */
        }
        
        transition idle_to_calibrating
            first idle
            accept calibrateCmd : CalibrateCommand
            then calibrating;
        
        state calibrating {
            doc /* Establishing measurement baseline */
        }
        
        transition calibrating_to_measuring
            first calibrating
            if calibrationComplete : CalibrationComplete
            then measuring;
        
        state measuring {
            doc /* Actively monitoring plant growth */
            entry action startMeasurement : MonitorGrowth;
        }
        
        transition measuring_to_idle
            first measuring
            accept stopCmd : StopCommand
            then idle;
        
        transition measuring_to_paused
            first measuring
            accept pauseCmd : PauseCommand
            then paused;
        
        state paused {
            doc /* Measurement temporarily suspended */
        }
        
        transition paused_to_measuring
            first paused
            accept resumeCmd : ResumeCommand
            then measuring;
        
        transition paused_to_idle
            first paused
            accept stopCmd2 : StopCommand
            then idle;
    }
    
    requirement def MeasurementPrecisionRequirement {
        doc /* The auxanometer shall measure plant growth with specified precision */
        subject auxanometer : Auxanometer;
        require constraint {
            auxanometer.encoder.resolution <= 0.01
        }
    }
    
    requirement def SamplingRateRequirement {
        doc /* The system shall acquire measurements at specified intervals */
        subject system : Auxanometer;
        require constraint {
            system.dataAcquisition.samplingRate >= 0.1 [Hz]
        }
    }
    
    requirement def DataStorageRequirement {
        doc /* The system shall store continuous measurements for specified duration */
        subject recorder : RecordingDevice;
        require constraint {
            recorder.storageCapacity >= 10000.0
        }
    }
    
    requirement def AmplificationRequirement {
        doc /* The mechanical system shall amplify small displacements for accurate measurement */
        subject lever : LeverArm;
        require constraint {
            lever.leverRatio >= 5.0
        }
    }
    
    part def Auxanometer {
        doc /* 
            An auxanometer is a precision instrument used to measure and record 
            the rate of plant growth over time. It operates by detecting minute 
            vertical displacements of a growing plant and converting these movements 
            into measurable data through a mechanical amplification system.
            
            The primary function is to continuously monitor plant elongation growth 
            by mechanically coupling to the plant apex, amplifying small vertical 
            movements through a lever or pulley mechanism, converting the amplified 
            displacement into rotational motion, measuring this motion with high 
            precision sensors, and recording the data to calculate growth rates 
            for botanical research and agricultural applications.
        */
        
        attribute measurementInterval : ISQ::TimeValue = 60.0 [s];
        attribute totalGrowth : DisplacementValue;
        attribute averageGrowthRate : GrowthRate;
        
        part plant : PlantSpecimen {
            attribute initialHeight = 100.0 [mm];
            attribute currentHeight = 100.0 [mm];
        }
        
        part attachment : AttachmentPoint {
            attribute contactForce = 0.01 [N];
        }
        
        part lever : LeverArm {
            attribute leverRatio = 10.0;
            attribute pivotPosition = 50.0 [mm];
        }
        
        part pulley : PulleyMechanism {
            attribute pulleyRadius = 25.0 [mm];
            attribute rotationAngle = 0.0;
        }
        
        part encoder : RotaryEncoder {
            attribute resolution = 0.01;
            attribute currentReading = 0.0;
        }
        
        part scale : GraduatedScale {
            attribute minValue = 0.0 [mm];
            attribute maxValue = 500.0 [mm];
            attribute graduationInterval = 1.0 [mm];
        }
        
        part pointer : PointerIndicator {
            attribute currentPosition = 0.0 [mm];
        }
        
        part dataAcquisition : DataAcquisitionUnit {
            attribute samplingRate = 1.0 [Hz];
        }
        
        part recorder : RecordingDevice {
            attribute storageCapacity = 100000.0;
            attribute recordingInterval = 60.0 [s];
        }
        
        connection attachmentToLever connect attachment.output to lever.input;
        connection leverToPulley connect lever.output to pulley.input;
        connection pulleyToEncoder connect pulley.output to encoder.input;
        connection encoderToDAQ connect encoder.input to dataAcquisition.sensorInput;
        connection daqToRecorder connect dataAcquisition.dataOutput to recorder.input;
        
        perform action monitoring : MonitorGrowth {
            in samplingInterval = Auxanometer::measurementInterval;
            in pulleyRadius = pulley.pulleyRadius;
            out measurements;
        }
        
        exhibit state operatingStates : AuxanometerStates;
    }
    
    part auxanometerSystem : Auxanometer {
        doc /* Complete auxanometer system for automated plant growth measurement */
        
        satisfy measurementPrecisionReq : MeasurementPrecisionRequirement {
            subject auxanometer = auxanometerSystem;
        }
        
        satisfy samplingRateReq : SamplingRateRequirement {
            subject system = auxanometerSystem;
        }
        
        satisfy dataStorageReq : DataStorageRequirement {
            subject recorder = auxanometerSystem.recorder;
        }
        
        satisfy amplificationReq : AmplificationRequirement {
            subject lever = auxanometerSystem.lever;
        }
    }
}

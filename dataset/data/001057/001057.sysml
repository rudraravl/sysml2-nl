package 'Fluxgate Compass System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MagneticFieldStrength :> ISQ::MagneticFluxDensityValue {
        doc /* Magnetic field strength measured in Tesla */
    }
    
    attribute def CompassHeading :> ISQ::PlaneAngleValue {
        doc /* Compass heading angle in degrees from magnetic north */
    }
    
    attribute def ExcitationFrequency :> ISQ::FrequencyValue {
        doc /* Frequency of the AC excitation signal applied to drive coils */
    }
    
    attribute def SensorVoltage :> ISQ::VoltageValue {
        doc /* Voltage output from sensor pickup coils */
    }
    
    attribute def CalibrationData {
        attribute offsetX : MagneticFieldStrength;
        attribute offsetY : MagneticFieldStrength;
        attribute offsetZ : MagneticFieldStrength;
        attribute scaleFactor : Real;
    }
    
    port def MagneticFieldPort {
        in fieldX : MagneticFieldStrength;
        in fieldY : MagneticFieldStrength;
        in fieldZ : MagneticFieldStrength;
    }
    
    port def HeadingOutputPort {
        out heading : CompassHeading;
        out accuracy : ISQ::PlaneAngleValue;
    }
    
    port def PowerPort {
        in voltage : ISQ::VoltageValue;
        in current : ISQ::ElectricCurrentValue;
    }
    
    port def ExcitationPort {
        out driveSignal : ISQ::VoltageValue;
        out frequency : ExcitationFrequency;
    }
    
    port def SensorOutputPort {
        out xAxisVoltage : SensorVoltage;
        out yAxisVoltage : SensorVoltage;
        out zAxisVoltage : SensorVoltage;
    }
    
    part def ExcitationCircuit {
        doc /* Generates AC excitation signal to drive fluxgate sensor cores */
        
        port powerIn : PowerPort;
        port excitationOut : ExcitationPort;
        
        attribute driveFrequency : ExcitationFrequency;
        attribute driveAmplitude : ISQ::VoltageValue;
        
        part oscillator {
            attribute frequency : ISQ::FrequencyValue;
            attribute stability : Real;
        }
        
        part amplifier {
            attribute gain : Real;
            attribute bandwidth : ISQ::FrequencyValue;
        }
    }
    
    part def FluxgateSensor {
        doc /* Core fluxgate sensor with ferromagnetic cores and pickup coils */
        
        port magneticInput : MagneticFieldPort;
        port excitationIn : ExcitationPort;
        port sensorOut : SensorOutputPort;
        
        attribute sensitivity : Real;
        attribute noiseLevel : MagneticFieldStrength;
        
        part xAxisCore {
            attribute material : String;
            attribute permeability : Real;
            part driveCoil {
                attribute turns : Integer;
                attribute inductance : ISQ::InductanceValue;
            }
            part pickupCoil {
                attribute turns : Integer;
                attribute resistance : ISQ::ResistanceValue;
            }
        }
        
        part yAxisCore {
            attribute material : String;
            attribute permeability : Real;
            part driveCoil {
                attribute turns : Integer;
                attribute inductance : ISQ::InductanceValue;
            }
            part pickupCoil {
                attribute turns : Integer;
                attribute resistance : ISQ::ResistanceValue;
            }
        }
        
        part zAxisCore {
            attribute material : String;
            attribute permeability : Real;
            part driveCoil {
                attribute turns : Integer;
                attribute inductance : ISQ::InductanceValue;
            }
            part pickupCoil {
                attribute turns : Integer;
                attribute resistance : ISQ::ResistanceValue;
            }
        }
    }
    
    part def SignalProcessor {
        doc /* Processes raw sensor signals to extract magnetic field components */
        
        port sensorIn : SensorOutputPort;
        port fieldOut {
            out fieldX : MagneticFieldStrength;
            out fieldY : MagneticFieldStrength;
            out fieldZ : MagneticFieldStrength;
        }
        port powerIn : PowerPort;
        
        attribute samplingRate : ISQ::FrequencyValue;
        attribute filterCutoff : ISQ::FrequencyValue;
        
        part amplifier {
            attribute gain : Real;
            attribute inputImpedance : ISQ::ResistanceValue;
        }
        
        part analogToDigitalConverter {
            attribute resolution : Integer;
            attribute conversionRate : ISQ::FrequencyValue;
        }
        
        part digitalFilter {
            attribute filterOrder : Integer;
            attribute filterType : String;
        }
    }
    
    part def HeadingCalculator {
        doc /* Computes compass heading from calibrated magnetic field vector */
        
        port fieldIn {
            in fieldX : MagneticFieldStrength;
            in fieldY : MagneticFieldStrength;
            in fieldZ : MagneticFieldStrength;
        }
        port headingOut : HeadingOutputPort;
        port powerIn : PowerPort;
        
        attribute calibration : CalibrationData;
        attribute declination : ISQ::PlaneAngleValue;
        
        part microprocessor {
            attribute clockSpeed : ISQ::FrequencyValue;
            attribute memorySize : Integer;
        }
    }
    
    part def CalibrationModule {
        doc /* Manages sensor calibration and environmental compensation */
        
        attribute hardIronOffsetX : MagneticFieldStrength;
        attribute hardIronOffsetY : MagneticFieldStrength;
        attribute hardIronOffsetZ : MagneticFieldStrength;
        attribute softIronM11 : Real;
        attribute softIronM12 : Real;
        attribute softIronM13 : Real;
        attribute softIronM21 : Real;
        attribute softIronM22 : Real;
        attribute softIronM23 : Real;
        attribute softIronM31 : Real;
        attribute softIronM32 : Real;
        attribute softIronM33 : Real;
        attribute temperatureCoefficient : Real;
        
        part temperatureSensor {
            attribute minRange : ISQ::TemperatureValue;
            attribute maxRange : ISQ::TemperatureValue;
            attribute accuracy : ISQ::TemperatureValue;
        }
    }
    
    action def GenerateExcitation {
        in powerSupply : ISQ::VoltageValue;
        in targetFrequency : ExcitationFrequency;
        out driveSignal : ISQ::VoltageValue;
        out actualFrequency : ExcitationFrequency;
    }
    
    action def SenseField {
        in driveSignal : ISQ::VoltageValue;
        in ambientFieldX : MagneticFieldStrength;
        in ambientFieldY : MagneticFieldStrength;
        in ambientFieldZ : MagneticFieldStrength;
        out xVoltage : SensorVoltage;
        out yVoltage : SensorVoltage;
        out zVoltage : SensorVoltage;
    }
    
    action def ProcessSignals {
        in xVoltage : SensorVoltage;
        in yVoltage : SensorVoltage;
        in zVoltage : SensorVoltage;
        out fieldX : MagneticFieldStrength;
        out fieldY : MagneticFieldStrength;
        out fieldZ : MagneticFieldStrength;
    }
    
    action def ApplyCalibration {
        in rawFieldX : MagneticFieldStrength;
        in rawFieldY : MagneticFieldStrength;
        in rawFieldZ : MagneticFieldStrength;
        in calibrationData : CalibrationData;
        out correctedFieldX : MagneticFieldStrength;
        out correctedFieldY : MagneticFieldStrength;
        out correctedFieldZ : MagneticFieldStrength;
    }
    
    action def ComputeHeading {
        in fieldX : MagneticFieldStrength;
        in fieldY : MagneticFieldStrength;
        in declination : ISQ::PlaneAngleValue;
        out heading : CompassHeading;
        out accuracy : ISQ::PlaneAngleValue;
    }
    
    action def DetermineHeading {
        doc /* 
            Primary action to determine magnetic heading from Earth's magnetic field.
            The fluxgate compass measures the ambient magnetic field vector by 
            periodically saturating ferromagnetic cores with an AC excitation signal,
            detecting the resulting second harmonic voltage induced in pickup coils,
            processing these signals to extract field components, applying calibration
            corrections, and computing the compass heading angle relative to magnetic north.
        */
        
        in ambientFieldX : MagneticFieldStrength;
        in ambientFieldY : MagneticFieldStrength;
        in ambientFieldZ : MagneticFieldStrength;
        in calibration : CalibrationData;
        in magneticDeclination : ISQ::PlaneAngleValue;
        in powerSupply : ISQ::VoltageValue;
        out compassHeading : CompassHeading;
        out headingAccuracy : ISQ::PlaneAngleValue;
        
        first start;
        
        then action excite : GenerateExcitation {
            in powerSupply = powerSupply;
            in targetFrequency : ExcitationFrequency;
            out driveSignal : ISQ::VoltageValue;
            out actualFrequency : ExcitationFrequency;
        }
        
        then action sense : SenseField {
            in driveSignal = excite.driveSignal;
            in ambientFieldX = ambientFieldX;
            in ambientFieldY = ambientFieldY;
            in ambientFieldZ = ambientFieldZ;
            out xVoltage : SensorVoltage;
            out yVoltage : SensorVoltage;
            out zVoltage : SensorVoltage;
        }
        
        then action process : ProcessSignals {
            in xVoltage = sense.xVoltage;
            in yVoltage = sense.yVoltage;
            in zVoltage = sense.zVoltage;
            out fieldX : MagneticFieldStrength;
            out fieldY : MagneticFieldStrength;
            out fieldZ : MagneticFieldStrength;
        }
        
        then action calibrate : ApplyCalibration {
            in rawFieldX = process.fieldX;
            in rawFieldY = process.fieldY;
            in rawFieldZ = process.fieldZ;
            in calibrationData = calibration;
            out correctedFieldX : MagneticFieldStrength;
            out correctedFieldY : MagneticFieldStrength;
            out correctedFieldZ : MagneticFieldStrength;
        }
        
        then action calculate : ComputeHeading {
            in fieldX = calibrate.correctedFieldX;
            in fieldY = calibrate.correctedFieldY;
            in declination = magneticDeclination;
            out heading : CompassHeading;
            out accuracy : ISQ::PlaneAngleValue;
        }
        
        then assign compassHeading := calculate.heading;
        then assign headingAccuracy := calculate.accuracy;
        
        then done;
    }
    
    attribute def PowerOnEvent;
    attribute def SelfTestPassedEvent;
    attribute def CalibrationLoadedEvent;
    attribute def PauseCommandEvent;
    attribute def ResumeCommandEvent;
    attribute def PowerOffEvent;
    
    action def PerformSelfTest;
    action def LoadCalibration;
    
    state def FluxgateCompassStateMachine {
        entry; then idle;
        
        state idle;
        
        accept powerOn : PowerOnEvent
            then initializing;
        
        state initializing {
            entry action performSelfTest : PerformSelfTest;
        }
        
        accept selfTestPassed : SelfTestPassedEvent
            then calibrating;
        
        state calibrating {
            entry action loadCalibration : LoadCalibration;
        }
        
        accept calibrationLoaded : CalibrationLoadedEvent
            then measuring;
        
        state measuring {
            do action measureHeading : DetermineHeading;
        }
        
        accept pauseCommand : PauseCommandEvent
            then standby;
        
        state standby;
        
        accept resumeCommand : ResumeCommandEvent
            then measuring;
        
        accept powerOffFromMeasuring : PowerOffEvent
            then idle;
        
        accept powerOffFromStandby : PowerOffEvent
            then idle;
    }
    
    part def FluxgateCompassSystem {
        doc /* 
            A fluxgate compass system that determines magnetic heading by measuring
            the Earth's magnetic field vector. The system operates by applying an
            alternating excitation current to ferromagnetic cores, which periodically
            drives them into saturation. The ambient magnetic field causes asymmetry
            in the saturation cycles, inducing a second harmonic voltage in pickup
            coils proportional to the field strength along each axis. These signals
            are amplified, filtered, digitized, and processed to extract the three-axis
            magnetic field components. After applying calibration corrections to
            compensate for hard and soft iron distortions, the system computes the
            compass heading angle relative to magnetic north. The primary function
            is to provide accurate, continuous heading information for navigation
            and orientation applications in vehicles, vessels, and portable devices.
        */
        
        port magneticFieldInput : MagneticFieldPort;
        port headingOutput : HeadingOutputPort;
        port systemPower : PowerPort;
        
        attribute minOperatingTemp : ISQ::TemperatureValue;
        attribute maxOperatingTemp : ISQ::TemperatureValue;
        attribute measurementRange : MagneticFieldStrength;
        attribute resolution : ISQ::PlaneAngleValue;
        attribute updateRate : ISQ::FrequencyValue;
        
        part excitationCircuit : ExcitationCircuit;
        part sensor : FluxgateSensor;
        part signalProcessor : SignalProcessor;
        part headingCalculator : HeadingCalculator;
        part calibrationModule : CalibrationModule;
        
        connection powerToExcitation connect systemPower to excitationCircuit.powerIn;
        connection powerToProcessor connect systemPower to signalProcessor.powerIn;
        connection powerToCalculator connect systemPower to headingCalculator.powerIn;
        
        connection excitationToSensor connect excitationCircuit.excitationOut to sensor.excitationIn;
        connection fieldToSensor connect magneticFieldInput to sensor.magneticInput;
        connection sensorToProcessor connect sensor.sensorOut to signalProcessor.sensorIn;
        connection processorToCalculator connect signalProcessor.fieldOut to headingCalculator.fieldIn;
        connection calculatorToOutput connect headingCalculator.headingOut to headingOutput;
    }
    
    part fluxgateCompassSystem : FluxgateCompassSystem {
        doc /* Complete fluxgate compass system instance */
        
        perform action determineHeading[*] ordered references DetermineHeading;
        
        part excitationCircuit : ExcitationCircuit {
            perform determineHeading.excite;
        }
        
        part sensor : FluxgateSensor {
            perform determineHeading.sense;
        }
        
        part signalProcessor : SignalProcessor {
            perform determineHeading.process;
        }
        
        part headingCalculator : HeadingCalculator {
            perform determineHeading.calibrate;
            perform determineHeading.calculate;
        }
        
        part calibrationModule : CalibrationModule;
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def EnvironmentalRequirement;
    
    requirement <'R1'> provideMagneticHeading : FunctionalRequirement {
        doc /* 
            The fluxgate compass system shall measure the Earth's magnetic field
            and compute the magnetic heading angle relative to magnetic north.
        */
        subject fluxgateCompassSystem;
    }
    
    requirement <'R2'> headingAccuracy : PerformanceRequirement {
        doc /* 
            The system shall provide heading measurements with an accuracy
            of ±1.0 degree RMS under nominal operating conditions.
        */
        subject fluxgateCompassSystem.headingOutput;
    }
    
    requirement <'R3'> updateRate : PerformanceRequirement {
        doc /* 
            The system shall provide heading updates at a minimum rate
            of 10 Hz during continuous operation.
        */
        subject fluxgateCompassSystem;
    }
    
    requirement <'R4'> operatingTemperature : EnvironmentalRequirement {
        doc /* 
            The system shall operate over a temperature range of
            -40°C to +85°C.
        */
        subject fluxgateCompassSystem;
    }
    
    requirement <'R5'> powerConsumption : PerformanceRequirement {
        doc /* 
            The system shall consume no more than 500 mW of power
            during normal operation.
        */
        subject fluxgateCompassSystem.systemPower;
    }
    
    requirement systemGoal {
        doc /* High-level system requirements for the fluxgate compass */
        require provideMagneticHeading;
        require headingAccuracy;
        require updateRate;
        require operatingTemperature;
        require powerConsumption;
    }
}

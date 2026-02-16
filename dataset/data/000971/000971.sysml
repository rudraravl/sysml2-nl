package AltimeterSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PressureMeasurement;
    attribute def TemperatureMeasurement;
    attribute def CalibrationSetting;
    attribute def AltitudeWarning;
    
    alias Altitude for ISQ::LengthValue;
    alias Pressure for ISQ::PressureValue;
    alias Temperature for ISQ::ThermodynamicTemperatureValue;
    alias Voltage for ISQ::VoltageValue;
    alias Energy for ISQ::EnergyValue;
    
    port def PressurePort {
        in staticPressure : Pressure;
        in ambientTemperature : Temperature;
    }
    
    port def AltitudePort {
        out altitude : Altitude;
        out dataValid : Boolean;
    }
    
    port def CalibrationPort {
        in barometerSetting : Pressure;
        out calibrationComplete : Boolean;
    }
    
    port def PowerPort {
        in voltage : Voltage;
    }
    
    item def AtmosphericData {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }
    
    item def ElectricalPower {
        attribute voltage : Voltage;
    }
    
    action def SenseAtmosphericPressure {
        in atmosphericConditions : AtmosphericData;
        out measuredPressure : Pressure;
        out measuredTemperature : Temperature;
    }
    
    action def ApplyCalibration {
        in rawPressure : Pressure;
        in barometerSetting : Pressure;
        out calibratedPressure : Pressure;
    }
    
    action def ComputeBarometricAltitude {
        in calibratedPressure : Pressure;
        in temperature : Temperature;
        out altitude : Altitude;
    }
    
    action def ValidateAltitudeData {
        in altitude : Altitude;
        in pressure : Pressure;
        out isValid : Boolean;
    }
    
    action def CheckAltitudeLimits {
        in currentAltitude : Altitude;
        in minimumAltitude : Altitude;
        in maximumAltitude : Altitude;
        out warning : AltitudeWarning;
    }
    
    action def DisplayAltitude {
        in altitude : Altitude;
        in valid : Boolean;
    }
    
    part def PressureTransducer {
        port atmosphericInput : PressurePort;
        port powerInput : PowerPort;
        
        attribute sensorPressure : Pressure;
        attribute sensorTemperature : Temperature;
        
        perform action sense : SenseAtmosphericPressure;
    }
    
    part def ComputerModule {
        port pressureInput : PressurePort;
        port calibrationInput : CalibrationPort;
        port altitudeOutput : AltitudePort;
        port powerInput : PowerPort;
        
        attribute referencePressure : Pressure;
        attribute computedAltitude : Altitude;
        
        perform action calibrate : ApplyCalibration;
        perform action calculate : ComputeBarometricAltitude;
        perform action validate : ValidateAltitudeData;
    }
    
    part def IndicatorDisplay {
        port altitudeInput : AltitudePort;
        port powerInput : PowerPort;
        
        attribute displayedAltitude : Altitude;
        attribute displayBrightness : Real;
        
        perform action displayUpdate : DisplayAltitude;
    }
    
    part def WarningSystem {
        port altitudeMonitor : AltitudePort;
        port powerInput : PowerPort;
        
        attribute minSafeAltitude : Altitude;
        attribute maxOperatingAltitude : Altitude;
        attribute warningActive : Boolean;
        
        perform action monitor : CheckAltitudeLimits;
    }
    
    part def PowerSupply {
        port powerOutput : PowerPort;
        
        attribute outputVoltage : Voltage;
        attribute capacity : Energy;
    }
    
    action def DetermineAltitude {
        in atmosphericData : AtmosphericData;
        in barometerSetting : Pressure;
        out altitude : Altitude;
        out valid : Boolean;
        
        first start;
        then merge measurementCycle;
        
        action measureAtmosphere : SenseAtmosphericPressure {
            in atmosphericConditions = atmosphericData;
            out measuredPressure : Pressure;
            out measuredTemperature : Temperature;
        }
        
        then action calibratePressure : ApplyCalibration {
            in rawPressure = measureAtmosphere.measuredPressure;
            in barometerSetting = barometerSetting;
            out calibratedPressure : Pressure;
        }
        
        then action calculateAltitude : ComputeBarometricAltitude {
            in calibratedPressure = calibratePressure.calibratedPressure;
            in temperature = measureAtmosphere.measuredTemperature;
            out altitude : Altitude;
        }
        
        then action validateData : ValidateAltitudeData {
            in altitude = calculateAltitude.altitude;
            in pressure = calibratePressure.calibratedPressure;
            out isValid : Boolean;
        }
        
        then decide;
            if validateData.isValid then outputAltitude;
            if not validateData.isValid then flagError;
        
        action outputAltitude {
            then assign altitude := calculateAltitude.altitude;
            then assign valid := true;
        }
        then measurementCycle;
        
        action flagError {
            then assign valid := false;
        }
        then measurementCycle;
    }
    
    part def Altimeter {
        doc /* 
            An altimeter system that measures atmospheric pressure and converts it to 
            altitude above a reference pressure level, providing critical altitude information 
            for aircraft navigation, terrain awareness, and flight safety operations.
        */
        
        part sensor : PressureTransducer;
        part computer : ComputerModule;
        part display : IndicatorDisplay;
        part warning : WarningSystem;
        part power : PowerSupply;
        
        attribute standardPressure : Pressure;
        attribute currentBarometerSetting : Pressure;
        
        connect sensor.atmosphericInput to computer.pressureInput;
        connect computer.altitudeOutput to display.altitudeInput;
        connect computer.altitudeOutput to warning.altitudeMonitor;
        
        connection powerDistribution {
            end powerSource : power.powerOutput;
            end sensorPower : sensor.powerInput;
            end computerPower : computer.powerInput;
            end displayPower : display.powerInput;
            end warningPower : warning.powerInput;
        }
        
        perform action determineAltitude : DetermineAltitude[*] ordered;
        
        state machine AltimeterOperation {
            initial state PowerOff;
            
            state Initializing {
                entry action performSelfTest;
            }
            
            state Operating {
                entry perform determineAltitude;
                
                state Measuring;
                state Calibrating;
                
                transition first from Measuring to Calibrating;
                transition then from Calibrating to Measuring;
            }
            
            state Fault {
                entry action activateWarning;
            }
            
            transition first from PowerOff to Initializing;
            transition then from Initializing to Operating;
            transition then from Initializing to Fault;
            transition then from Operating to Fault;
            transition then from Fault to Initializing;
            transition then from Operating to PowerOff;
        }
    }
    
    part altimeter : Altimeter;
    
    requirement <'ALT-REQ-001'> accuracyRequirement {
        doc /* 
            The altimeter shall measure altitude with an accuracy of +/- 30 feet 
            within the operating range of -1000 feet to 50000 feet above the reference pressure level.
        */
        
        subject alt : Altimeter;
        
        require constraint {
            maxError : Altitude;
            minAltitude : Altitude;
            maxAltitude : Altitude;
        }
    }
    
    requirement <'ALT-REQ-002'> updateRateRequirement {
        doc /* 
            The altimeter shall update altitude readings at a minimum rate of 
            5 times per second to provide timely information for flight operations.
        */
        
        require constraint {
            updateFrequency : Real;
            updateFrequency >= 5.0
        }
    }
    
    requirement <'ALT-REQ-003'> calibrationRequirement {
        doc /* 
            The altimeter shall support barometric pressure calibration adjustments 
            to compensate for local atmospheric pressure variations.
        */
        
        subject alt : Altimeter;
    }
    
    requirement <'ALT-REQ-004'> warningRequirement {
        doc /* 
            The altimeter shall generate warnings when altitude falls below 
            minimum safe altitude or exceeds maximum operating altitude limits.
        */
        
        require constraint {
            warningLatency : ISQ::TimeValue;
        }
    }
    
    requirement <'ALT-REQ-005'> environmentalRequirement {
        doc /* 
            The altimeter shall operate reliably in environmental conditions 
            typical of aircraft operations including temperature and pressure extremes.
        */
        
        assume constraint operatingConditions {
            temperature : Temperature;
            pressure : Pressure;
        }
    }
    
    requirement primaryMission {
        doc /* 
            The altimeter system shall continuously measure atmospheric pressure and 
            convert it to altitude information, providing accurate, real-time altitude 
            data to support safe aircraft navigation and terrain avoidance operations.
        */
        
        require accuracyRequirement;
        require updateRateRequirement;
        require calibrationRequirement;
        require warningRequirement;
        require environmentalRequirement;
    }
}

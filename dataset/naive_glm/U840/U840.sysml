package PyrometerSystem {
    import ScalarValues::*;
    
    // ---- Units ----
    unit K;
    unit degC;
    unit W_per_m2;
    unit V;
    unit A;
    unit nm;
    unit um;
    unit mm;
    unit Hz;
    unit s;
    unit ms;
    unit one;
    unit V_per_Wm2;
    unit J;
    unit J_s;
    unit m_s;
    
    // ---- Value types ----
    attribute def Temperature :> Real { unit K; }
    attribute def TemperatureCelsius :> Real { unit degC; }
    attribute def Irradiance :> Real { unit W_per_m2; }
    attribute def Voltage :> Real { unit V; }
    attribute def Current :> Real { unit A; }
    attribute def Wavelength :> Real { unit nm; }
    attribute def WavelengthMicro :> Real { unit um; }
    attribute def Length :> Real { unit mm; }
    attribute def Emissivity :> Real { unit one; }
    attribute def Frequency :> Real { unit Hz; }
    attribute def Duration :> Real { unit s; }
    attribute def DurationMs :> Real { unit ms; }
    attribute def Dimensionless :> Real { unit one; }
    attribute def Sensitivity :> Real { unit V_per_Wm2; }
    attribute def Energy :> Real { unit J; }
    attribute def PlanckConstant :> Real { unit J_s; }
    attribute def BoltzmannConstant :> Real { unit J/K; }
    attribute def SpeedOfLight :> Real { unit m_s; }
    
    // ---- Item definitions ----
    item def InfraredRadiation {
        attribute wavelength : Wavelength;
        attribute irradiance : Irradiance;
        attribute sourceTemperature : Temperature;
    }
    
    item def RawSignal {
        attribute voltage : Voltage;
        attribute timestamp : Duration;
        attribute saturated : Boolean;
    }
    
    item def ProcessedSignal {
        attribute voltage : Voltage;
        attribute calibrated : Boolean;
        attribute noiseLevel : Voltage;
        attribute timestamp : Duration;
    }
    
    item def TemperatureReading {
        attribute temperature : Temperature;
        attribute confidence : Dimensionless;
        attribute valid : Boolean;
        attribute lowSignal : Boolean;
        attribute outOfRange : Boolean;
        attribute timestamp : Duration;
    }
    
    item def DisplayData {
        attribute temperature : TemperatureCelsius;
        attribute valid : Boolean;
        attribute warning : Boolean;
        attribute timestamp : Duration;
    }
    
    item def CalibrationRecord {
        attribute offset : Voltage;
        attribute gain : Dimensionless;
        attribute timestamp : Duration;
    }
    
    // ---- Port definitions ----
    port def RadiationPort {
        out item radiation : InfraredRadiation;
    }
    
    port def RawSignalPort {
        out item signal : RawSignal;
    }
    
    port def ProcessedSignalPort {
        out item signal : ProcessedSignal;
    }
    
    port def TemperaturePort {
        out item reading : TemperatureReading;
    }
    
    port def DisplayPort {
        out item data : DisplayData;
    }
    
    port def CommandPort {
        in attribute start : Boolean;
        in attribute stop : Boolean;
        in attribute calibrate : Boolean;
        in attribute reset : Boolean;
        in attribute emissivity : Emissivity;
        in attribute refreshRate : Frequency;
    }
    
    port def StatusPort {
        out attribute state : String;
        out attribute faultCode : Integer;
        out attribute ready : Boolean;
    }
    
    // ---- Action definitions ----
    action def FocusRadiation {
        in item incoming : InfraredRadiation;
        out item focused : InfraredRadiation;
    }
    
    action def ConvertRadiation {
        in item radiation : InfraredRadiation;
        out item signal : RawSignal;
    }
    
    action def ProcessSignal {
        in item raw : RawSignal;
        in item calibration : CalibrationRecord;
        out item processed : ProcessedSignal;
    }
    
    action def ComputeTemperature {
        in item signal : ProcessedSignal;
        in attribute emissivity : Emissivity;
        out item reading : TemperatureReading;
    }
    
    action def UpdateDisplay {
        in item reading : TemperatureReading;
        in attribute refreshRate : Frequency;
        out item data : DisplayData;
    }
    
    action def RunCalibration {
        out item record : CalibrationRecord;
    }
    
    // ---- Part definitions ----
    part def OpticalSystem {
        port radiationIn : RadiationPort;
        port radiationOut : RadiationPort;
        attribute focalLength : Length = 50;
        attribute aperture : Length = 25;
        attribute transmittance : Dimensionless = 0.92;
        attribute fieldOfView : Dimensionless = 0.0175;
        
        perform action focus : FocusRadiation {
            in item incoming = radiationIn.radiation;
            out item focused = radiationOut.radiation;
        }
    }
    
    part def InfraredDetector {
        port radiationIn : RadiationPort;
        port signalOut : RawSignalPort;
        attribute sensitivity : Sensitivity = 1.0e-3;
        attribute minWavelength : Wavelength = 800;
        attribute maxWavelength : Wavelength = 14000;
        attribute responseTime : DurationMs = 10;
        attribute darkCurrent : Current = 1.0e-9;
        
        perform action convert : ConvertRadiation {
            in item radiation = radiationIn.radiation;
            out item signal = signalOut.signal;
        }
    }
    
    part def SignalProcessor {
        port signalIn : RawSignalPort;
        port signalOut : ProcessedSignalPort;
        attribute gain : Dimensionless = 1000;
        attribute noiseFloor : Voltage = 1.0e-6;
        attribute bandwidth : Frequency = 1000;
        attribute calibrationRecord : CalibrationRecord;
        
        perform action process : ProcessSignal {
            in item raw = signalIn.signal;
            in item calibration = calibrationRecord;
            out item processed = signalOut.signal;
        }
    }
    
    part def TemperatureComputer {
        port signalIn : ProcessedSignalPort;
        port readingOut : TemperaturePort;
        port commandIn : CommandPort;
        attribute emissivity : Emissivity = 0.95;
        attribute planckConstant : PlanckConstant = 6.62607015e-34;
        attribute boltzmannConstant : BoltzmannConstant = 1.380649e-23;
        attribute speedOfLight : SpeedOfLight = 2.99792458e8;
        attribute minValidTemperature : Temperature = 273.15;
        attribute maxValidTemperature : Temperature = 3273.15;
        attribute minValidSignal : Voltage = 1.0e-5;
        
        perform action compute : ComputeTemperature {
            in item signal = signalIn.signal;
            in attribute emissivity = commandIn.emissivity;
            out item reading = readingOut.reading;
        }
    }
    
    part def DisplayController {
        port readingIn : TemperaturePort;
        port displayOut : DisplayPort;
        attribute refreshRate : Frequency = 4;
        attribute backlightOn : Boolean = true;
        attribute contrast : Dimensionless = 0.7;
        
        perform action update : UpdateDisplay {
            in item reading = readingIn.reading;
            in attribute refreshRate = refreshRate;
            out item data = displayOut.data;
        }
    }
    
    // ---- State machine ----
    state def OperationalState {
        entry;
        exit;
        
        state idle {
            entry { /* powered on, not measuring */ }
        }
        
        state measuring {
            entry { /* begin continuous measurement cycle */ }
            do { /* capture radiation, compute temperature, update display */ }
        }
        
        state calibration {
            entry { /* run internal calibration routine */ }
            do { /* generate calibration record */ }
        }
        
        state fault {
            entry { /* latch fault condition */ }
        }
        
        transition from idle to measuring
            when commandIn.start;
        
        transition from measuring to idle
            when commandIn.stop;
        
        transition from idle to calibration
            when commandIn.calibrate;
        
        transition from calibration to idle
            when calibration.complete;
        
        transition from measuring to fault
            when readingOut.reading.valid == false;
        
        transition from calibration to fault
            when calibration.error;
        
        transition from fault to idle
            when commandIn.reset;
    }
    
    // ---- Top-level pyrometer ----
    part def Pyrometer {
        port commandIn : CommandPort;
        port displayOut : DisplayPort;
        port statusOut : StatusPort;
        
        part opticalSystem : OpticalSystem;
        part detector : InfraredDetector;
        part processor : SignalProcessor;
        part computer : TemperatureComputer;
        part display : DisplayController;
        
        // Internal connections
        connect opticalSystem.radiationOut to detector.radiationIn;
        connect detector.signalOut to processor.signalIn;
        connect processor.signalOut to computer.signalIn;
        connect computer.readingOut to display.readingIn;
        
        // Command distribution
        connect commandIn to computer.commandIn;
        
        // Display output
        connect display.displayOut to displayOut;
        
        // State behavior
        exhibit stateBehavior : OperationalState;
        
        // Overall measurement latency
        attribute measurementLatency : DurationMs = 50;
    }
    
    // ---- Requirements ----
    requirement def MeasurementAccuracyRequirement {
        doc "The pyrometer shall measure object temperature within ±2% of true value across its operating range."
        attribute accuracy : Dimensionless = 0.02;
        attribute operatingRangeMin : Temperature = 273.15;
        attribute operatingRangeMax : Temperature = 3273.15;
    }
    
    requirement def ResponseTimeRequirement {
        doc "The pyrometer shall provide a temperature reading within 100 ms of radiation capture."
        attribute maxResponseTime : DurationMs = 100;
    }
    
    requirement def WavelengthRangeRequirement {
        doc "The infrared detector shall be sensitive to wavelengths between 0.8 µm and 14 µm."
        attribute minWavelength : WavelengthMicro = 0.8;
        attribute maxWavelength : WavelengthMicro = 14.0;
    }
    
    requirement def OperationalStateRequirement {
        doc "The pyrometer shall support idle, measuring, calibration, and fault operational states with user-triggered transitions."
    }
    
    requirement def NonContactRequirement {
        doc "The pyrometer shall measure temperature without physical contact with the target object."
    }
    
    requirement def EmissivityCompensationRequirement {
        doc "The temperature computer shall apply user-defined emissivity to correct temperature calculations per Planck's Radiation Law."
        attribute emissivityMin : Emissivity = 0.1;
        attribute emissivityMax : Emissivity = 1.0;
    }
    
    requirement def SignalQualityRequirement {
        doc "The temperature computer shall flag readings as invalid when signal is below minimum threshold or outside valid temperature range."
        attribute minSignal : Voltage = 1.0e-5;
    }
    
    requirement def DisplayRefreshRequirement {
        doc "The display controller shall refresh the temperature display at a user-configurable rate, default 4 Hz."
        attribute defaultRefreshRate : Frequency = 4;
    }
    
    requirement pyrometerAccuracy : MeasurementAccuracyRequirement;
    requirement pyrometerResponseTime : ResponseTimeRequirement;
    requirement detectorWavelengthRange : WavelengthRangeRequirement;
    requirement operationalStates : OperationalStateRequirement;
    requirement nonContact : NonContactRequirement;
    requirement emissivityCompensation : EmissivityCompensationRequirement;
    requirement signalQuality : SignalQualityRequirement;
    requirement displayRefresh : DisplayRefreshRequirement;
    
    // ---- Satisfy relationships ----
    satisfy pyrometerAccuracy by Pyrometer;
    satisfy pyrometerResponseTime by Pyrometer;
    satisfy detectorWavelengthRange by InfraredDetector;
    satisfy operationalStates by Pyrometer;
    satisfy nonContact by Pyrometer;
    satisfy emissivityCompensation by TemperatureComputer;
    satisfy signalQuality by TemperatureComputer;
    satisfy displayRefresh by DisplayController;
}

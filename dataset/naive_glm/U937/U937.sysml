package VibratingStructureGyroscope {
    import ScalarValues::*;
    
    // --- Value Types ---
    attribute def AngularRate :> Real { unit = "rad/s"; }
    attribute def Temperature :> Real { unit = "degC"; }
    attribute def Capacitance :> Real { unit = "pF"; }
    attribute def Voltage :> Real { unit = "V"; }
    attribute def Frequency :> Real { unit = "kHz"; }
    attribute def Amplitude :> Real { unit = "nm"; }
    
    // --- Data Structures ---
    attribute def DriveCommand {
        attribute amplitude : Voltage;
        attribute frequency : Frequency;
    }
    
    attribute def CapacitanceReading {
        attribute deltaCap : Capacitance;
    }
    
    attribute def AnalogSignal {
        attribute voltage : Voltage;
    }
    
    attribute def DigitalData {
        attribute value : Real;
    }
    
    attribute def TemperatureReading {
        attribute value : Temperature;
    }
    
    // --- Ports ---
    port def DrivePort {
        in driveCmd : DriveCommand;
    }
    
    port def CapPort {
        in capRead : CapacitanceReading;
    }
    
    port def AnalogPort {
        in signal : AnalogSignal;
    }
    
    port def DigitalPort {
        in data : DigitalData;
    }
    
    port def TempPort {
        in tempReading : TemperatureReading;
    }
    
    // --- Actions ---
    action def VibratePrimaryAction {
        in driveCmd : DriveCommand;
        out amplitude : Amplitude;
    }
    
    action def InduceCoriolisAction {
        in angularRate : AngularRate;
        out secondaryAmplitude : Amplitude;
    }
    
    action def ApplyElectrostaticForceAction {
        in cmd : DriveCommand;
        out actuation : DriveCommand;
    }
    
    action def ConvertMotionToCapacitanceAction {
        in motion : Amplitude;
        out capRead : CapacitanceReading;
    }
    
    action def AmplifyAndFilterAction {
        in signal : AnalogSignal;
        out processed : AnalogSignal;
    }
    
    action def MeasureTemperatureAction {
        out tempRead : TemperatureReading;
    }
    
    action def ProcessSignalAction {
        in signal : AnalogSignal;
        in temp : TemperatureReading;
        in calData : DigitalData [*];
        out rate : DigitalData;
    }
    
    // --- Requirements ---
    requirement def MeasureAngularRateRequirement {
        doc { The system shall measure the rate of angular rotation. }
    }
    
    requirement def CoriolisEffectRequirement {
        doc { The system shall utilize the Coriolis effect to induce a secondary vibration proportional to the rate of rotation. }
    }
    
    requirement def VacuumPackagingRequirement {
        doc { The mechanical structure shall be housed within a sealed vacuum package to prevent air dampening. }
    }
    
    requirement def TemperatureCompensationRequirement {
        doc { The DSP shall compensate for measurement inaccuracies using real-time temperature readings. }
    }
    
    requirement def OperatingStatesRequirement {
        doc { The system shall operate through initialization, warm-up, normal operation, calibration, and fault states. }
    }
    
    // --- Components ---
    part def ResonantMass {
        attribute naturalFrequency : Frequency = 10.0;
        attribute primaryAmplitude : Amplitude;
        attribute secondaryAmplitude : Amplitude;
        
        port driveInterface : DrivePort;
        port senseInterface : ~CapPort;
        
        action vibrate : VibratePrimaryAction;
        action coriolis : InduceCoriolisAction;
    }
    
    part def DriveElectrodes {
        port controlInterface : DrivePort;
        port actuationInterface : ~DrivePort;
        
        action applyForce : ApplyElectrostaticForceAction;
    }
    
    part def SenseElectrodes {
        port mechanicalInterface : CapPort;
        port electricalInterface : ~AnalogPort;
        
        action convertMotion : ConvertMotionToCapacitanceAction;
    }
    
    part def DriveLoopElectronics {
        port driveOutput : ~DrivePort;
        
        action maintainResonance {
            // Logic to lock frequency and maintain constant amplitude
        }
    }
    
    part def SenseElectronics {
        port senseInput : AnalogPort;
        port processedOutput : ~AnalogPort;
        
        action amplifyAndFilter : AmplifyAndFilterAction;
    }
    
    part def TemperatureSensor {
        port tempOutput : ~TempPort;
        
        action measureTemp : MeasureTemperatureAction;
    }
    
    part def DSP {
        port analogInput : AnalogPort;
        port tempInput : TempPort;
        port digitalOutput : ~DigitalPort;
        
        attribute calibrationData : DigitalData [*];
        
        action process : ProcessSignalAction;
    }
    
    part def VacuumPackage {
        part resonantMass : ResonantMass;
        part driveElectrodes : DriveElectrodes;
        part senseElectrodes : SenseElectrodes;
    }
    
    // --- Top Level Assembly ---
    part def VibratingStructureGyroscope {
        satisfy MeasureAngularRateRequirement;
        satisfy CoriolisEffectRequirement;
        satisfy VacuumPackagingRequirement;
        satisfy TemperatureCompensationRequirement;
        satisfy OperatingStatesRequirement;
        
        attribute measuredRate : AngularRate;
        attribute currentTemp : Temperature;
        
        attribute powerApplied : Boolean;
        attribute selfTestPassed : Boolean;
        attribute selfTestFailed : Boolean;
        attribute vibrationLocked : Boolean;
        attribute calibrationRequested : Boolean;
        attribute calibrationComplete : Boolean;
        attribute errorDetected : Boolean;
        
        port powerInput : DrivePort;
        port rateOutput : DigitalPort;
        
        part sealedVacuumPackage : VacuumPackage;
        part driveLoopElectronics : DriveLoopElectronics;
        part senseElectronics : SenseElectronics;
        part temperatureSensor : TemperatureSensor;
        part digitalSignalProcessor : DSP;
        
        connection driveCmdFlow connect driveLoopElectronics.driveOutput to sealedVacuumPackage.driveElectrodes.controlInterface;
        connection actuationFlow connect sealedVacuumPackage.driveElectrodes.actuationInterface to sealedVacuumPackage.resonantMass.driveInterface;
        connection capFlow connect sealedVacuumPackage.resonantMass.senseInterface to sealedVacuumPackage.senseElectrodes.mechanicalInterface;
        connection signalFlow connect sealedVacuumPackage.senseElectrodes.electricalInterface to senseElectronics.senseInput;
        connection processedSignalFlow connect senseElectronics.processedOutput to digitalSignalProcessor.analogInput;
        connection tempFlow connect temperatureSensor.tempOutput to digitalSignalProcessor.tempInput;
        connection powerFlow connect powerInput to driveLoopElectronics.driveOutput;
        connection outputFlow connect digitalSignalProcessor.digitalOutput to rateOutput;
        
        state machine OperatingStates {
            state off;
            state initialization;
            state warmUp;
            state normalOperation;
            state calibration;
            state fault;
            
            transition off to initialization when powerApplied;
            transition initialization to warmUp when selfTestPassed;
            transition initialization to fault when selfTestFailed;
            transition warmUp to normalOperation when vibrationLocked;
            transition normalOperation to calibration when calibrationRequested;
            transition calibration to normalOperation when calibrationComplete;
            
            transition initialization to fault when errorDetected;
            transition warmUp to fault when errorDetected;
            transition normalOperation to fault when errorDetected;
            transition calibration to fault when errorDetected;
        }
    }
}

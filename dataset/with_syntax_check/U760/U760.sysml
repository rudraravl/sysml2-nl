package MachmeterSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MachNumber :> Real;
    
    item def PressureData {
        attribute totalPressure : PressureValue;
        attribute staticPressure : PressureValue;
    }
    
    item def TemperatureData {
        attribute ambientTemperature : ThermodynamicTemperatureValue;
    }
    
    item def MachData {
        attribute machNumber : MachNumber;
        attribute isValid : Boolean;
    }
    
    attribute def PowerCommand;
    attribute def CalibrationCommand;
    
    port def PressureInputPort {
        in pressureData : PressureData;
    }
    
    port def TemperatureInputPort {
        in temperatureData : TemperatureData;
    }
    
    port def MachOutputPort {
        out machData : MachData;
    }
    
    part def PitotStaticProbe {
        port pressureOut : PressureInputPort;
        
        perform action sensePressure {
            out totalP : PressureValue;
            out staticP : PressureValue;
        }
    }
    
    part def TemperatureProbe {
        port temperatureOut : TemperatureInputPort;
        
        perform action senseTemperature {
            out ambientTemp : ThermodynamicTemperatureValue;
        }
    }
    
    part def MachComputationUnit {
        port pressureIn : PressureInputPort;
        port temperatureIn : TemperatureInputPort;
        port machOut : MachOutputPort;
        
        attribute currentMach : MachNumber;
        attribute dataValid : Boolean;
        attribute gamma : Real = 1.4;
        
        perform action computeMachContinuously references computeMachNumber;
    }
    
    part def CockpitDisplay {
        port machIn : MachOutputPort;
        
        attribute displayedMach : MachNumber;
        attribute alertActive : Boolean;
        
        perform action updateDisplay {
            in machData : MachData;
        }
    }
    
    action def CalculateSoundSpeed {
        in temperature : ThermodynamicTemperatureValue;
        out soundSpeed : SpeedValue;
    }
    
    action def CalculateMachFromPressure {
        in totalPressure : PressureValue;
        in staticPressure : PressureValue;
        in gamma : Real;
        out mach : MachNumber;
        out valid : Boolean;
    }
    
    action def ValidatePressureInputs {
        in totalPressure : PressureValue;
        in staticPressure : PressureValue;
        out isValid : Boolean;
    }
    
    action computeMachNumber {
        first start;
        then merge continuousLoop;
        
        then action acquireData {
            out pressureData : PressureData;
            out temperatureData : TemperatureData;
        }
        
        then action validateInputs : ValidatePressureInputs {
            in totalPressure = acquireData.pressureData.totalPressure;
            in staticPressure = acquireData.pressureData.staticPressure;
            out isValid : Boolean;
        }
        
        then decide;
            if validateInputs.isValid then calculateMach;
            if not validateInputs.isValid then handleInvalid;
        
        action calculateMach : CalculateMachFromPressure {
            in totalPressure = acquireData.pressureData.totalPressure;
            in staticPressure = acquireData.pressureData.staticPressure;
            in gamma = 1.4;
            out mach : MachNumber;
            out valid : Boolean;
        }
        then outputMach;
        
        action handleInvalid {
            out mach : MachNumber = 0.0;
            out valid : Boolean = false;
        }
        then outputMach;
        
        action outputMach {
            in mach : MachNumber;
            in valid : Boolean;
            out machData : MachData;
        }
        
        then continuousLoop;
    }
    
    state def MachmeterOperationalStates {
        entry; then off;
        
        state off;
        
        transition powerUp
            first off
            accept powerOn : PowerCommand
            then initializing;
        
        state initializing;
        
        transition initComplete
            first initializing
            then operational;
        
        state operational {
            state normal;
            
            state subsonic;
            state transonic;
            state supersonic;
            
            transition toSubsonic
                first normal
                then subsonic;
            
            transition toTransonic
                first normal
                then transonic;
            
            transition toSupersonic
                first normal
                then supersonic;
            
            transition backToNormal1
                first subsonic
                then normal;
            
            transition backToNormal2
                first transonic
                then normal;
            
            transition backToNormal3
                first supersonic
                then normal;
        }
        
        transition powerDown
            first operational
            accept powerOff : PowerCommand
            then off;
    }
    
    part def Machmeter {
        doc /* 
            A Machmeter is an aircraft flight instrument that measures and displays 
            the ratio of the aircraft's true airspeed to the local speed of sound, 
            known as the Mach number. The system continuously monitors pressure and 
            temperature data from external probes, computes the Mach number using 
            aerodynamic equations, and presents the result to the flight crew.
        */
        
        part pitotStatic : PitotStaticProbe;
        part temperatureProbe : TemperatureProbe;
        part computationUnit : MachComputationUnit;
        part display : CockpitDisplay;
        
        connection pressureFlow connect pitotStatic.pressureOut to computationUnit.pressureIn;
        connection temperatureFlow connect temperatureProbe.temperatureOut to computationUnit.temperatureIn;
        connection machFlow connect computationUnit.machOut to display.machIn;
        
        attribute operationalState : MachmeterOperationalStates;
        
        perform action operateMachmeter {
            first start;
            then accept powerOn : PowerCommand;
            then action initialize;
            then loop {
                action measureAndCompute {
                    action samplePressure : PitotStaticProbe::sensePressure {
                        out totalP : PressureValue;
                        out staticP : PressureValue;
                    }
                    flow samplePressure.totalP to computationUnit.pressureIn.pressureData.totalPressure;
                    flow samplePressure.staticP to computationUnit.pressureIn.pressureData.staticPressure;
                    
                    then action sampleTemp : TemperatureProbe::senseTemperature {
                        out ambientTemp : ThermodynamicTemperatureValue;
                    }
                    flow sampleTemp.ambientTemp to computationUnit.temperatureIn.temperatureData.ambientTemperature;
                    
                    then action compute : MachComputationUnit::computeMachContinuously;
                    
                    then action show : CockpitDisplay::updateDisplay {
                        in machData = computationUnit.machOut.machData;
                    }
                }
                then accept continueOrStop;
                    if continueOrStop == powerOff then exitLoop;
            }
            action exitLoop;
            then done;
        }
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    
    requirement <'REQ-001'> primaryFunction : FunctionalRequirement {
        doc /* 
            The Machmeter system shall continuously measure and display the aircraft's 
            Mach number by processing total pressure, static pressure, and ambient 
            temperature inputs to compute the ratio of true airspeed to the speed of sound.
        */
        subject machmeterSystem;
    }
    
    requirement <'REQ-002'> accuracyRequirement : PerformanceRequirement {
        doc /* 
            The displayed Mach number shall be accurate to within ±0.02 Mach across 
            the operational flight envelope from Mach 0.3 to Mach 2.5.
        */
        subject machmeterSystem;
    }
    
    requirement <'REQ-003'> updateRateRequirement : PerformanceRequirement {
        doc /* 
            The Machmeter shall update the displayed Mach number at a minimum rate 
            of 10 Hz to provide real-time feedback to the flight crew.
        */
        subject machmeterSystem;
    }
    
    requirement <'REQ-004'> validationRequirement : SafetyRequirement {
        doc /* 
            The system shall validate all pressure inputs and indicate invalid data 
            conditions to prevent display of erroneous Mach numbers.
        */
        subject machmeterSystem;
    }
    
    requirement <'REQ-005'> operationalRangeRequirement : PerformanceRequirement {
        doc /* 
            The Machmeter shall operate correctly across altitude ranges from sea level 
            to 60,000 feet and temperature ranges from -60°C to +50°C.
        */
        subject machmeterSystem;
    }
    
    part machmeterSystem : Machmeter {
        satisfy primaryFunction;
        satisfy accuracyRequirement;
        satisfy updateRateRequirement;
        satisfy validationRequirement;
        satisfy operationalRangeRequirement;
    }
}
